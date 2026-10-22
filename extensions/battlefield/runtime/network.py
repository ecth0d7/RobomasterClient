"""Independent authenticated UDP team plane. It never opens an official socket."""
import collections
import os
import secrets
import socket
import time
from contract import SCHEMA, MAX_BYTES, canonical, decode, identifier, integer, sign, verify, utc_ms, observation, fused_scene


class TeamLink:
    def __init__(self, config, receive, disconnected):
        self.config, self.receive, self.disconnected = config, receive, disconnected
        self.node = config["node_id"]
        self.session, self.sequence = secrets.token_hex(12), 0
        self.key = os.environ.get(config.get("key_env", "SITUATION_NODE_KEY"), "").encode()
        self.peers, self.keys, self.last_seen = {}, {}, {}
        self.replays, self.seen = {}, collections.OrderedDict()
        self.sessions, self.retired_sessions = {}, set()
        self.accepted = self.rejected = self.sent = self.send_errors = 0
        self.last_heartbeat = 0
        self.socket = None
        if not config.get("enabled", False):
            return
        if len(self.key) < 32:
            raise ValueError("team node key must contain at least 32 bytes in its environment variable")
        for peer in config.get("peers", []):
            node = peer["node_id"]
            key = os.environ.get(peer["key_env"], "").encode()
            if not identifier(node) or node == self.node or node in self.peers or len(key) < 32:
                raise ValueError("invalid peer identity/key")
            address = (peer["host"], peer["port"])
            socket.inet_pton(socket.AF_INET, address[0])
            if not integer(address[1], 1024, 65535):
                raise ValueError("peer port")
            if len(peer.get("sources", [])) > 64 or not all(identifier(s) for s in peer.get("sources", [])):
                raise ValueError("peer source grant")
            for name, allowed in (("sources", None), ("frames", None), ("kinds", {"vision", "radar", "odometry", "position", "sensor", "telemetry"}), ("uses", {"fusion", "speech", "relay", "fused_view"})):
                values = peer.get(name, [])
                if not isinstance(values, list) or len(values) > 64 or not all(isinstance(v, str) and (v in allowed if allowed is not None else identifier(v)) for v in values):
                    raise ValueError("peer grants must be explicit bounded lists")
            if "sensor_only" in peer and type(peer["sensor_only"]) is not bool:
                raise ValueError("sensor_only must be boolean")
            self.peers[node], self.keys[node] = dict(peer), key
        if len(self.peers) > 32:
            raise ValueError("peer capacity")
        bind = config.get("bind", "127.0.0.1")
        socket.inet_pton(socket.AF_INET, bind)
        port = config.get("port", 45670)
        if not integer(port, 1024, 65535):
            raise ValueError("bind port")
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.setblocking(False)
        self.socket.bind((bind, port))

    def close(self):
        if self.socket:
            self.socket.close()
        self.socket = None

    def send(self, kind, payload):
        if not self.socket:
            return False
        self.sequence += 1
        body = {"schema": SCHEMA, "team_id": self.config["team_id"], "match_id": self.config["match_id"],
                "node_id": self.node, "session": self.session, "sequence": self.sequence,
                "stamp_ms": utc_ms(), "kind": kind, "payload": payload}
        packet = canonical({"body": body, "signature": sign(body, self.key)})
        if len(packet) > MAX_BYTES:
            return False
        self.seen[self.node+":"+self.session+":"+str(self.sequence)] = time.monotonic()
        return self._broadcast(packet)

    def _broadcast(self, packet, exclude=None):
        delivered = False
        for node, peer in self.peers.items():
            if node == exclude or peer.get("sensor_only", False):
                continue
            try:
                self.socket.sendto(packet, (peer["host"], peer["port"]))
                self.sent += 1
                delivered = True
            except OSError:
                self.send_errors += 1
        return delivered

    def poll(self):
        if not self.socket:
            return
        now = time.monotonic()
        if now-self.last_heartbeat >= 1:
            self.send("heartbeat", {})
            self.last_heartbeat = now
        for _ in range(32):
            try:
                packet, _address = self.socket.recvfrom(MAX_BYTES+1)
            except BlockingIOError:
                break
            except OSError:
                self.rejected += 1
                break
            try:
                wrapper = decode(packet)
                if not isinstance(wrapper, dict) or set(wrapper) != {"body", "signature"}:
                    raise ValueError("envelope")
                b = wrapper["body"]
                keys = {"schema", "team_id", "match_id", "node_id", "session", "sequence", "stamp_ms", "kind", "payload"}
                if not isinstance(b, dict) or set(b) != keys or b["schema"] != SCHEMA or b["team_id"] != self.config["team_id"] or b["match_id"] != self.config["match_id"]:
                    raise ValueError("scope")
                node = b["node_id"]
                peer = self.peers.get(node)
                if not peer or not verify(b, wrapper["signature"], self.keys[node]):
                    raise ValueError("authentication")
                if not identifier(b["session"]) or not integer(b["sequence"], 1, 2**53-1) or not integer(b["stamp_ms"], 1, 2**53-1) or not -250 <= utc_ms()-b["stamp_ms"] <= 3000:
                    raise ValueError("packet time")
                key = node+":"+b["session"]+":"+str(b["sequence"])
                replay_key = (node, b["session"])
                if replay_key in self.retired_sessions or key in self.seen or b["sequence"] <= self.replays.get(replay_key, 0):
                    raise ValueError("replay")
                if replay_key not in self.replays and len(self.replays) >= 128:
                    raise ValueError("session capacity; restart with a new match scope")
                kind, payload = b["kind"], b["payload"]
                if kind == "observation":
                    o = observation(payload)
                    if o["source_id"] not in peer.get("sources", []) or o["kind"] not in peer.get("kinds", []) or o["frame_id"] not in peer.get("frames", []) or "fusion" not in peer.get("uses", []):
                        raise ValueError("source/kind/use grant")
                elif kind == "voice":
                    if "speech" not in peer.get("uses", []) or peer.get("sensor_only", False):
                        raise ValueError("speech grant")
                    if not isinstance(payload, dict) or set(payload) != {"id", "text", "priority", "expires_ms"} or not identifier(payload["id"]) or not isinstance(payload["text"], str) or not 1 <= len(payload["text"]) <= 300 or payload["priority"] not in ("info", "caution", "urgent") or not integer(payload["expires_ms"], utc_ms()+1, utc_ms()+5000):
                        raise ValueError("voice message")
                elif kind == "fused_view":
                    scene = fused_scene(payload)
                    if "fused_view" not in peer.get("uses", []) or peer.get("sensor_only", False) or scene["frame_id"] not in peer.get("frames", []):
                        raise ValueError("fused view grant")
                elif kind == "heartbeat":
                    if payload != {}:
                        raise ValueError("heartbeat")
                else:
                    raise ValueError("message kind")
                self.replays[replay_key] = b["sequence"]
                previous = self.sessions.get(node)
                if previous and previous != b["session"]:
                    self.retired_sessions.add((node, previous))
                    self.disconnected(node)
                self.sessions[node] = b["session"]
                self.seen[key] = now
                self.last_seen[node] = now
                self.accepted += 1
                self.receive(kind, payload, node, peer)
                # Relay the original signed datagram. No restamping or widening of grants.
                if self.config.get("relay", False) and "relay" in peer.get("uses", []):
                    self._broadcast(packet, node)
            except (ValueError, TypeError, KeyError, OverflowError):
                self.rejected += 1
        for node, stamp in list(self.last_seen.items()):
            if now-stamp > 3:
                del self.last_seen[node]
                self.disconnected(node)
        while self.seen and (len(self.seen) > 4096 or now-next(iter(self.seen.values())) > 6):
            self.seen.popitem(last=False)

    def details(self):
        return {"enabled": self.socket is not None, "peers_online": sorted(self.last_seen), "received": self.accepted,
                "rejected": self.rejected, "sent": self.sent, "send_errors": self.send_errors,
                "security": "per-node HMAC; authenticated but not encrypted; keys belong only to reviewed peers"}
