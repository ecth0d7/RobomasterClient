#!/usr/bin/env python3
"""Optional process plugin. stdin/stdout are a bounded native-host protocol."""
import json
import math
import os
from pathlib import Path
import select
import signal
import socket
import sys
import time
import traceback
from contract import canonical, decode, identifier, integer, observation, utc_ms
from fusion import Fusion
from optional_services import ModelService as Advisor, VoiceService as VoiceQueue, JournalService
from network import TeamLink
from image_feature_process import VisionProcess as Vision, ProjectileProcess as Projectile


class Runtime:
    def __init__(self, config):
        boolean_groups = {"": ["display_only_confirmed", "share_official", "share_vision", "share_fused"],
            "team": ["enabled", "trusted_lan_confirmed", "relay"],
            "model": ["enabled", "external_data_consent", "automatic", "structured_output"],
            "voice": ["enabled", "muted", "synthesize_only", "send_team", "receive_team", "automatic_advice"],
            "journal": ["enabled"], "vision": ["enabled"], "projectile": ["enabled", "share"], "viewer": ["enabled"]}
        for section, keys in boolean_groups.items():
            values = config.get(section, {}) if section else config
            if not isinstance(values, dict) or any(k in values and type(values[k]) is not bool for k in keys):
                raise ValueError("configuration consent/enabled fields must be JSON booleans")
        calibration = config.get("vision", {}).get("calibration", {})
        if not isinstance(calibration, dict) or any(k in calibration and type(calibration[k]) is not bool for k in ("acknowledged", "fixed_camera_confirmed")):
            raise ValueError("calibration consent must be boolean")
        if config.get("schema") != "rm.situation.config/1" or not all(identifier(config.get(k)) for k in ("node_id", "team_id", "match_id", "frame_id")):
            raise ValueError("configuration scope/schema")
        if not config.get("display_only_confirmed", False):
            raise ValueError("display-only operation must be confirmed")
        self.config = config
        self.fusion = Fusion(config["frame_id"], float(config.get("conflict_m", 2)))
        model = dict(config.get("model", {}))
        model["node_id"] = config["node_id"]
        self.model = Advisor(model)
        self.voice = VoiceQueue(config.get("voice", {}))
        self.vision = Vision(dict(config.get("vision", {}), node_id=config["node_id"]))
        projectile = config.get("projectile", {})
        roi = projectile.get("roi", [.04,.04,.92,.92])
        if not isinstance(roi,list) or len(roi)!=4 or not all(type(v) in (int,float) and math.isfinite(v) and 0<=v<=1 for v in roi) or min(roi[2:])<=0 or roi[0]+roi[2]>1 or roi[1]+roi[3]>1 or projectile.get("color","bright") not in ("green","red","bright"):
            raise ValueError("projectile ROI/color")
        exclusions = projectile.get("exclude_regions", [])
        if not isinstance(exclusions,list) or len(exclusions)>16 or any(not isinstance(r,list) or len(r)!=4 or not all(type(v) in (int,float) and math.isfinite(v) and 0<=v<=1 for v in r) or min(r[2:])<=0 or r[0]+r[2]>1 or r[1]+r[3]>1 for r in exclusions):
            raise ValueError("projectile excluded regions")
        self.projectile = Projectile(projectile) if Projectile is not None else None
        link = dict(config.get("team", {}))
        link.update({k: config[k] for k in ("node_id", "team_id", "match_id")})
        if link.get("enabled") and link.get("bind", "127.0.0.1") != "127.0.0.1" and not link.get("trusted_lan_confirmed", False):
            raise ValueError("unencrypted team transport requires explicit trusted-LAN acknowledgement")
        self.team = TeamLink(link, self.received, self.disconnected)
        self.journal_controls = 0
        self.journal = JournalService(dict(config.get("journal", {}), frame_id=config["frame_id"]))
        self.last_official, self.sequence = {}, 0
        self.running = True
        self.revision = 0
        self.last_snapshot = 0
        self.last_auto = 0
        self.last_advice = None
        self.peer_scenes = {}
        self.last_fused_push = 0
        self.started = time.monotonic()
        self.viewer = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) if config.get("viewer", {}).get("enabled", False) else None
        if self.viewer:
            self.viewer.setblocking(False)
            if not integer(config["viewer"].get("port"), 1024, 65535):
                raise ValueError("viewer port")

    def close(self):
        self.journal.close()
        self.fusion.close()
        self.team.close()
        if self.viewer:
            self.viewer.close()
        self.vision.close()
        if self.projectile:
            self.projectile.close()
        self.model.close()
        self.voice.close()

    def received(self, kind, payload, node, grant):
        if kind == "observation":
            if payload.get("source_id")=="operator.tactical": self.journal.accept(payload, node)
            else: self.fusion.accept(payload, node)
        elif kind == "voice" and self.config.get("voice", {}).get("receive_team", False):
            self.voice.submit(payload["text"], payload["priority"], payload["id"], payload["expires_ms"], node)
        elif kind == "fused_view":
            if payload["frame_id"] != self.config["frame_id"]:
                self.fusion.rejected += 1
                return
            scene = dict(payload)
            scene["node_id"] = node
            scene["deadline"] = time.monotonic()+min(3000, scene["expires_ms"]-utc_ms())/1000
            scene["tracks"] = [dict(t, deadline=time.monotonic()+max(0, t["expires_ms"]-utc_ms())/1000) for t in payload["tracks"]]
            self.peer_scenes[node] = scene

    def disconnected(self, node):
        self.journal.disconnected(node)
        self.fusion.retire(node)
        self.voice.clear(node)
        self.peer_scenes.pop(node, None)

    def peer_views(self):
        now = time.monotonic()
        self.peer_scenes = {node: s for node, s in self.peer_scenes.items() if s["deadline"] > now}
        result = []
        for node, scene in self.peer_scenes.items():
            tracks = []
            for stored in scene["tracks"]:
                if stored["deadline"] <= now:
                    continue
                t = {k: v for k, v in stored.items() if k not in ("deadline", "expires_ms")}
                t["remaining_ms"] = int((stored["deadline"]-now)*1000)
                tracks.append(t)
            result.append({"node_id": node, "frame_id": scene["frame_id"], "stamp_ms": scene["stamp_ms"],
                           "remaining_ms": int((scene["deadline"]-now)*1000), "tracks": tracks,
                           "omitted_tracks": scene["omitted_tracks"], "state": "peer_fused_estimate"})
        return result

    def share_fused(self, tracks):
        if not self.config.get("share_fused", False) or time.monotonic()-self.last_fused_push < 1:
            return
        self.last_fused_push = time.monotonic()
        now = utc_ms()
        compact_tracks = []
        for original in tracks[:32]:
            t = {k: original[k] for k in ("id", "position", "heading", "team", "confidence", "stamp_ms", "state", "conflict")}
            t["expires_ms"] = now+original["remaining_ms"]
            t["evidence"] = [{k: e[k] for k in ("id", "kind", "stamp_ms", "confidence", "position")} for e in original["evidence"][:4]]
            t["trail"] = original["trail"][-8:]
            compact_tracks.append(t)
        scene = {"schema": "rm.situation.fused/1", "frame_id": self.config["frame_id"], "revision": max(1,self.revision),
                 "stamp_ms": now, "expires_ms": now+2000, "tracks": compact_tracks, "omitted_tracks": max(0, len(tracks)-len(compact_tracks))}
        while len(canonical(scene)) > 32000 and scene["tracks"]:
            scene["tracks"].pop();scene["omitted_tracks"] += 1
        self.team.send("fused_view", scene)

    def local(self, item, share=True):
        if self.fusion.accept(item, self.config["node_id"]):
            if share:
                self.team.send("observation", item)

    def official(self, message):
        if not message.get("connected", False):
            origin = self.config["node_id"]
            self.fusion.samples = {k: v for k, v in self.fusion.samples.items() if not (k[0] == origin and v["source_id"].startswith("official."))}
            return
        # The host supplies read-only values and ingress ages. Re-reading a field does not renew it.
        values, metadata = message.get("groups", {}), message.get("observations", {})
        # 元数据年龄在宿主截取，进程管道等待也必须消耗有效期；旧宿主未附时间时沿用原合同。
        captured = message.get("captured_ms", utc_ms())
        delay = utc_ms()-captured if type(captured) is int else -1
        if delay < 0: delay = 5000
        metadata = {g: {f: dict(m, received_age_ms=m.get("received_age_ms", 0)+delay,
                        remaining_ms=max(0, m.get("remaining_ms", 0)-delay))
                        for f, m in fields.items()} for g, fields in metadata.items()}
        camp = "blue" if message.get("robot_id", 0) > 100 else "red"
        opposite = "red" if camp == "blue" else "blue"
        static = values.get("robotStatic", {})
        subject = metadata.get("robotStatic", {}).get("robot_id", {})
        own = type(static.get("robot_id")) is int and static["robot_id"] == message.get("robot_id") and subject.get("ingress_clock_verified") and subject.get("remaining_ms", 0) > 0
        if own:
            for group, fields in {"robotDynamic": {"current_health": "HP", "current_heat": "heat", "remaining_ammo": "rounds"},
                                  "robotStatic": {"max_health": "HP", "max_heat": "heat", "alive_state": "enum"}}.items():
                for field, unit in fields.items():
                    meta = metadata.get(group, {}).get(field, {})
                    revision = (meta.get("observation_session_id"), meta.get("observation_revision"))
                    key = group+"."+field
                    value = values.get(group, {}).get(field)
                    if type(value) not in (int, float) or not meta.get("ingress_clock_verified") or meta.get("remaining_ms", 0) <= 0 or revision == self.last_official.get(key):
                        continue
                    self.last_official[key] = revision
                    self.sequence += 1
                    self.local({"source_id": "official.telemetry", "target_id": camp+":"+str(message["robot_id"]%100)+"."+field,
                                "sequence": self.sequence, "stamp_ms": utc_ms()-int(meta.get("received_age_ms", 0)),
                                "ttl_ms": min(5000, int(meta.get("lifetime_ms", 1000))), "kind": "telemetry", "team": camp,
                                "frame_id": "none", "confidence": .9, "value": value, "data_type": "scalar", "unit": unit,
                                "label": "本机回传 "+field}, self.config.get("share_official", False))
        group = "radar"
        m = metadata.get(group, {}).get("radar_single_robot_info", {})
        entries = values.get(group, {}).get("radar_single_robot_info", [])
        revision = (m.get("observation_session_id"), m.get("observation_revision"))
        if m.get("ingress_clock_verified") and m.get("remaining_ms", 0) > 0 and revision != self.last_official.get(group) and isinstance(entries, list) and len(entries) == 12:
            self.last_official[group] = revision
            order = [(side, role) for side in (opposite, camp) for role in (1, 2, 3, 4, 6, 7)]
            for (side, role), entry in zip(order, entries):
                if type(entry.get("target_pos_x")) is not int or type(entry.get("target_pos_y")) is not int:
                    continue
                x, y = entry["target_pos_x"]/100., entry["target_pos_y"]/100.
                # Protocol zero/zero is not a reliable measured target position.
                if not 0 <= x <= 28 or not 0 <= y <= 15 or x == y == 0:
                    continue
                age = int(m.get("received_age_ms", 0))
                self.sequence += 1
                self.local({"source_id": "official.radar", "target_id": side+":"+str(role), "team": side,
                            "sequence": self.sequence, "stamp_ms": utc_ms()-age, "ttl_ms": min(5000, int(m.get("lifetime_ms", 1000))),
                            "kind": "radar", "frame_id": "field.2026", "confidence": .75,
                            "position": [x, y], "uncertainty_m": .5, "estimated": False,
                            "label": "雷达回传；接收时间，非传感器采样时间"}, self.config.get("share_official", False))

    def command(self, message):
        kind = message.get("kind")
        if kind == "journal_control":
            self.journal_controls += 1
            if type(message.get("enabled")) is not bool: return
            self.journal.close()
            self.journal = JournalService({"enabled":message["enabled"], "frame_id":self.config["frame_id"]})
        elif kind == "journal_mark":
            item=self.journal.create(message)
            if item and self.journal.accept(item,self.config["node_id"]) and message.get("share") is True:
                self.team.send("observation",item)
        elif kind == "configure_modules":
            self.configure_modules(message)
        elif kind == "hero_frame":
            if self.projectile:
                self.projectile.submit(message)
        elif kind == "hero_stream_reset":
            if self.projectile:
                self.projectile.reset()
            origin = self.config["node_id"]
            self.fusion.samples = {k:v for k,v in self.fusion.samples.items() if not (k[0]==origin and v["source_id"]=="video.hero.projectile")}
        elif kind == "frame":
            frame = dict(message)
            projection = self.config.get('vision', {}).get('projection', {})
            live = self.fusion.live()
            if projection.get('pose_source_id'):
                frame['observer'] = None
            # Only explicitly selected, accepted sensor sources can supply pose/angles.
            # Keep their original timestamps and deadline; frame delivery never renews them.
            for sample in live:
                if sample.get('kind') != 'odometry':
                    continue
                expires = sample['stamp_ms']+sample['ttl_ms']
                if projection.get('pose_source_id') and sample['origin'] == projection.get('pose_node_id') and sample['target_id'] == projection.get('pose_target_id') and sample['source_id'] == projection['pose_source_id'] and sample['frame_id'] == projection.get('frame_id') and 'position' in sample and 'heading' in sample:
                    frame['observer'] = dict(position=sample['position'], heading_rad=sample['heading'],
                        uncertainty_m=sample['uncertainty_m'], frame_id=sample['frame_id'], stamp_ms=sample['stamp_ms'], expires_ms=expires,
                        robot_id=(message.get('observer') or {}).get('robot_id'))
                if projection.get('gimbal_source_id') and sample['origin'] == projection.get('gimbal_node_id') and sample['target_id'] == projection.get('gimbal_target_id', 'camera.main') and sample['source_id'] == projection['gimbal_source_id'] and sample.get('frame_id') == 'robot.body' and sample.get('data_type') == 'vector' and sample.get('unit') == 'deg' and len(sample.get('value', [])) == 3:
                    frame['camera_attitude'] = dict(value=sample['value'], stamp_ms=sample['stamp_ms'], expires_ms=expires)
            self.vision.submit(frame)
        elif kind == "stream_reset":
            self.vision.reset()
            origin = self.config["node_id"]
            self.fusion.samples = {k: v for k, v in self.fusion.samples.items() if not (k[0] == origin and v["source_id"] == "video.main")}
        elif kind == "official":
            self.official(message)
        elif kind == "analyze":
            self.model.request(self.fusion.snapshot(), str(message.get("question", "")), self.fusion.live())
        elif kind == "mute":
            self.voice.mute(bool(message.get("value", True)))
        elif kind == "cancel_voice":
            self.voice.clear()
        elif kind == "announce":
            peer = message.get("peer_node", "")
            source = next((s["tracks"] for s in self.peer_views() if s["node_id"] == peer), []) if peer else self.fusion.snapshot()
            selected = next((t for t in source if t["id"] == message.get("target_id")), None)
            if selected:
                if selected["conflict"]:
                    text = selected["id"]+"位置来源冲突，请核对。"
                else:
                    x, y = selected["position"]
                    text = f'{selected["id"]}，估计位置{x:.1f}米，{y:.1f}米，置信度{selected["confidence"]:.0%}。'
                if peer:
                    text = "来自"+peer+"的融合推断。"+text
                self.announce(text[:300], "caution" if selected["conflict"] else "info", "track:"+peer+":"+selected["id"], utc_ms()+selected["remaining_ms"])
        elif kind == "speak_advice":
            a = self.model.advice
            if a and a["expires_ms"] > utc_ms():
                self.announce("模型建议。"+a["text"], a["priority"], "advice:"+str(a["stamp_ms"]), a["expires_ms"], "model")
        elif kind == "stop":
            self.running = False

    def configure_modules(self, message):
        if any(type(message.get(k)) is not bool for k in ("vision", "projectile", "share")):
            raise ValueError("module flags")
        model_file = message.get("model_file", "")
        if not isinstance(model_file, str) or len(model_file) > 4096:
            raise ValueError("module model file")
        for key in ("vision_configuration", "projectile_configuration"):
            if key in message and not isinstance(message[key], dict): raise ValueError("module configuration")
        vision = dict(message.get("vision_configuration", self.config.get("vision", {})), enabled=message["vision"])
        if model_file:
            vision["model_file"] = model_file
        projectile = dict(message.get("projectile_configuration", self.config.get("projectile", {})), enabled=message["projectile"], share=message["share"])
        for name, config, factory in (("vision", vision, Vision), ("projectile", projectile, Projectile)):
            old = getattr(self, name)
            # Sharing changes do not unload weights or reset a running task.
            old_config = {k:v for k,v in old.config.items() if k not in ("node_id", "share")}
            next_config = {k:v for k,v in config.items() if k not in ("node_id", "share")}
            if old_config != next_config:
                sequence = old.sequence
                old.close()
                setattr(self, name, factory(dict(config, node_id=self.config["node_id"]), sequence))
                source = "video.main" if name == "vision" else "video.hero.projectile"
                self.fusion.samples = {k:v for k,v in self.fusion.samples.items()
                    if not (k[0] == self.config["node_id"] and v["source_id"] == source)}
            self.config[name] = config
        self.config["share_vision"] = message["share"]

    def announce(self, text, priority, key, expires_ms, origin="local"):
        self.voice.submit(text, priority, key, expires_ms, origin)
        if self.config.get("voice", {}).get("send_team", False):
            # Receiver synthesizes locally using its own mute, priority, expiry and device policy.
            import hashlib
            ident = hashlib.sha256(key.encode()).hexdigest()[:32]
            self.team.send("voice", {"id": ident, "text": text, "priority": priority, "expires_ms": min(expires_ms, utc_ms()+5000)})

    def tick(self):
        self.team.poll()
        for item in self.vision.poll():
            self.local(item, self.config.get("share_vision", False))
        if self.projectile:
            for item in self.projectile.poll():
                self.local(item, self.config.get("projectile", {}).get("share", False))
        tracks = self.fusion.snapshot()
        self.share_fused(tracks)
        previous_advice = bool(self.model.advice)
        self.model.poll(tracks, self.fusion.live())
        if previous_advice and not self.model.advice:
            self.voice.clear("model")
        if self.config.get("model", {}).get("automatic", False) and time.monotonic()-self.last_auto > 3:
            self.model.request(tracks, observations=self.fusion.live())
            self.last_auto = time.monotonic()
        a = self.model.advice
        if a and a["stamp_ms"] != self.last_advice:
            self.last_advice = a["stamp_ms"]
            if self.config.get("voice", {}).get("automatic_advice", False):
                self.announce("模型建议。"+a["text"], a["priority"], "advice:"+str(a["stamp_ms"]), a["expires_ms"], "model")
        self.voice.poll()
        if time.monotonic()-self.last_snapshot >= .2:
            self.last_snapshot = time.monotonic()
            self.revision += 1
            boxes = []
            for track in self.vision.tracks:
                box = dict(track)
                box["confidence"] *= math.exp(-box.get("age_ms", 0)/1500.)
                boxes.append(box)
            sources = [{k: v for k, v in s.items() if k != "deadline"} for s in self.fusion.live()]
            result = {"schema": "rm.situation.view/1", "node_id": self.config["node_id"], "revision": self.revision, "stamp_ms": utc_ms(),
                      "frame_id": self.config["frame_id"], "tracks": tracks, "boxes": boxes, "advice": self.model.advice,
                      "projectile": self.projectile.details() if self.projectile else {"tracks":[],"status":"可选弹丸模块未安装"},
                      "model_status": self.model.status, "vision": self.vision.details(), "voice": self.voice.details(),
                      "model_input": self.model.input_trace,
                      "model_details": {k: self.model.config.get(k) for k in ("enabled", "provider", "model", "strategy")},
                      "journal": dict(self.journal.details(), controls_received=self.journal_controls), "peer_views": self.peer_views(),
                      "team": self.team.details(), "observations": sources[:512], "omitted_tracks": self.fusion.omitted_tracks, "capacity_rejected": self.fusion.capacity_rejected, "replay_history": self.fusion.sequences.details(), "accepted": self.fusion.accepted,
                      "rejected": self.fusion.rejected, "uptime_s": int(time.monotonic()-self.started), "display_only": True}
            emit(result)
            if self.viewer:
                # Local 3D viewers consume the same estimates and evidence, never send commands back.
                view = {k: result[k] for k in ("schema", "revision", "stamp_ms", "frame_id", "tracks", "display_only")}
                raw = canonical(view)
                if len(raw) <= 49152:
                    try:
                        self.viewer.sendto(raw, ("127.0.0.1", self.config["viewer"]["port"]))
                    except OSError:
                        pass


pending_output = bytearray()


def emit(value):
    # A stalled UI must not stop expiry, network draining or voice cancellation.
    global pending_output
    if pending_output:
        try:
            count = os.write(sys.stdout.fileno(), pending_output)
            del pending_output[:count]
        except BlockingIOError:
            return
    if pending_output:
        return
    pending_output.extend(canonical(value)+b"\n")
    try:
        count = os.write(sys.stdout.fileno(), pending_output)
        del pending_output[:count]
    except BlockingIOError:
        pass


def main():
    os.set_blocking(sys.stdout.fileno(), False)
    first = sys.stdin.buffer.readline(131073)
    if len(first) > 131072:
        raise ValueError("configuration too large")
    config = decode(first)
    runtime = Runtime(config)
    def stop(_number, _frame):
        runtime.running = False
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    emit({"schema": "rm.situation.ready/1", "pid": os.getpid()})
    buffer = bytearray()
    fd = sys.stdin.fileno()
    os.set_blocking(fd, False)
    try:
        while runtime.running:
            readable, _, _ = select.select([fd], [], [], .02)
            if readable:
                raw = os.read(fd, 131072)
                if not raw:
                    break
                buffer.extend(raw)
                if len(buffer) > 2*1024*1024:
                    raise ValueError("host input buffer overflow")
                for _ in range(16):
                    index = buffer.find(b"\n")
                    if index < 0:
                        break
                    raw = bytes(buffer[:index]); del buffer[:index+1]
                    try:
                        # Only native-host image messages exceed the team packet cap.
                        message = json.loads(raw) if len(raw) > 49152 else decode(raw)
                        runtime.command(message)
                    except (ValueError, TypeError, KeyError, OverflowError):
                        runtime.fusion.rejected += 1
            runtime.tick()
    finally:
        runtime.close()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        emit({"schema": "rm.situation.error/1", "error": type(error).__name__})
        sys.exit(1)
