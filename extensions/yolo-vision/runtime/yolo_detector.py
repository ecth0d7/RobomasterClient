"""Optional ONNX robot/armor detector with bounded CPU work and image-space tracks."""
import concurrent.futures
import math
import hashlib
import secrets
import time
from contract import utc_ms
from ground_projection import GroundProjection
from onnx_detector import OnnxDetector, decode_frame
from body_identity import BodyIdentity


def iou(a, b):
    x, y = max(a[0], b[0]), max(a[1], b[1])
    right, bottom = min(a[0]+a[2], b[0]+b[2]), min(a[1]+a[3], b[1]+b[3])
    area = max(0, right-x)*max(0, bottom-y)
    return area/max(1e-9, a[2]*a[3]+b[2]*b[3]-area)


class Vision:
    def __init__(self, config):
        self.config = config
        self.pool = concurrent.futures.ThreadPoolExecutor(max_workers=1, thread_name_prefix="vision")
        self.future = None
        self.detector = OnnxDetector(config)
        self.identity = BodyIdentity(config.get("identity", {}), config.get("threads", 2))
        self.status = "等待普通UDP视频帧" if config.get("enabled",False) else "未启用视觉"
        self.tracks = []
        self._tracking = []
        self.filter_mode = config.get("filter", {}).get("mode", "enemy_and_unknown")
        if self.filter_mode not in ("enemy_and_unknown", "all"):
            raise ValueError("visual target filter")
        self.filtered_friendly = 0
        self.next_id = 1
        self.sequence = 0
        self.inference_ms = 0
        self.dropped = self.frames = 0
        self.jpeg_decodes = 0
        self.epoch = 0
        self.scope = hashlib.sha256(str(config.get('node_id', 'local')).encode()).hexdigest()[:12]
        self.session = secrets.token_hex(6)
        self.projection = GroundProjection(config.get('projection', {}))
        self.frame_context = {}

    def close(self):
        self.epoch += 1
        self.pool.shutdown(wait=False, cancel_futures=True)

    def reset(self):
        self.epoch += 1
        self.tracks = []
        self._tracking = []
        self.session = secrets.token_hex(6)
        self.frame_context = {}

    def submit(self, frame):
        if not self.config.get("enabled", False):
            return
        if self.future is not None or utc_ms()-frame.get("stamp_ms", 0) > 1500:
            self.dropped += 1
            return
        # Freeze pose/attitude at submission, not when asynchronous inference ends.
        self.frame_context = {k: frame.get(k) for k in ('observer', 'camera_attitude', 'client_id')}
        self.future = self.pool.submit(self._detect, dict(frame), self.epoch)

    def _detect(self, frame, epoch):
        start = time.monotonic()
        image = decode_frame(frame)
        self.jpeg_decodes += 1
        boxes = self.detector.infer(frame, image)
        self.identity.enrich(boxes, frame, image)
        return frame["stamp_ms"], epoch, boxes, (time.monotonic()-start)*1000

    def poll(self):
        now = utc_ms()
        self._tracking = [t for t in self._tracking if now-t["stamp_ms"] <= 1500]
        for track in self._tracking:
            track["age_ms"] = now-track["stamp_ms"]
            track["occluded"] = track["age_ms"] > 500
        self.tracks = self.visible_tracks(self._tracking)
        if self.future is None or not self.future.done():
            return []
        future, self.future = self.future, None
        try:
            stamp, epoch, boxes, self.inference_ms = future.result()
            if epoch != self.epoch or now-stamp > 1500:
                self.dropped += 1
                return []
            previous = list(self._tracking)
            used = set()
            result = []
            for box in boxes:
                matches = [(iou(box["bbox"], old["bbox"]), index, old) for index, old in enumerate(previous)
                           if index not in used and old.get("detected_team", old["team"]) == box["team"] and old.get("detected_target", old["target_id"]) == box["target_id"] and old.get("detected_label", old["label"]) == box["label"]]
                best = max(matches, key=lambda m: m[0]) if matches else None
                if best and best[0] >= .15:
                    _, index, old = best
                    used.add(index)
                    track_id, hits = old["track_id"], old["hits"]+1
                else:
                    track_id, hits = self.next_id, 1
                    self.next_id += 1
                box.update(detected_team=box["team"], detected_target=box["target_id"], detected_label=box["label"])
                self.identity.confirm(box, best[2] if best and best[0] >= .15 else None, stamp)
                box.update(track_id=track_id, hits=hits, confirmed=hits >= 3, stamp_ms=stamp, age_ms=now-stamp, occluded=False)
                result.append(box)
            self._tracking = result+[old for index, old in enumerate(previous) if index not in used and now-old["stamp_ms"] <= 500]
            self.tracks = self.visible_tracks(self._tracking)
            selected = self.visible_tracks(result)
            self.filtered_friendly += len(result)-len(selected)
            self.frames += 1
            self.status = ("装甲识别跟踪中；装甲框不代表整机" if self.config.get("format", "rp26-armor-v8") == "rp26-armor-v8"
                           else "整机识别跟踪中；阵营与编号以实际识别依据为准")
            samples = []
            for box in selected:
                if not box["confirmed"]:
                    continue
                self.sequence += 1
                target = box["target_id"] if box["target_id"] != "unknown" else "vision:"+self.scope+":"+self.session+":"+str(box["track_id"])
                item = {"source_id": "video.main", "target_id": target, "sequence": self.sequence, "stamp_ms": stamp,
                        "ttl_ms": 1500, "kind": "vision", "team": box["team"], "frame_id": "camera.main.normalized",
                        "bbox": box["bbox"], "confidence": box["confidence"], "label": box["label"], "estimated": True}
                estimate, reason = self.projection.project(box, self.frame_context.get('observer'), stamp,
                                                          self.frame_context.get('camera_attitude'))
                box['localization'] = dict(estimate or {}, status=reason, positioned=estimate is not None)
                if estimate:
                    item.update({k: estimate[k] for k in ('position', 'frame_id', 'uncertainty_m', 'calibration_id', 'estimated', 'ttl_ms')})
                calibration = self.config.get("calibration", {})
                if not self.config.get("projection", {}).get("enabled", False) and calibration.get("acknowledged", False) and calibration.get("fixed_camera_confirmed", False) and box["target_id"] != "unknown" and calibration.get("anchor") == "bbox-bottom-center":
                    h = calibration.get("homography", [])
                    if len(h) == 9 and all(isinstance(v, (int, float)) and math.isfinite(v) for v in h):
                        x = box["bbox"][0]+box["bbox"][2]/2
                        y = box["bbox"][1]+box["bbox"][3]
                        z = h[6]*x+h[7]*y+h[8]
                        if abs(z) > 1e-6:
                            item.update(position=[(h[0]*x+h[1]*y+h[2])/z, (h[3]*x+h[4]*y+h[5])/z],
                                        uncertainty_m=calibration.get("uncertainty_m", 2.), frame_id=calibration.get("frame_id", "unregistered"),
                                        calibration_id=calibration.get("id", "manual"))
                samples.append(item)
            return samples
        except Exception as error:
            self.status = "视觉不可用："+type(error).__name__
            self.tracks = []
            self._tracking = []
            return []

    def own_team(self):
        ident = self.frame_context.get("client_id")
        if ident is None: ident = (self.frame_context.get("observer") or {}).get("robot_id")
        if type(ident) is not int or ident not in (*range(1, 8), *range(101, 108)): return "unknown"
        return "blue" if ident > 100 else "red"

    def visible_tracks(self, tracks):
        own = self.own_team()
        if self.filter_mode == "all" or own == "unknown": return list(tracks)
        # Team is assigned only after the existing multi-frame identity check.
        # Unknown bodies remain unknown, including potential enemies.
        return [t for t in tracks if t.get("team") != own]

    def details(self):
        return {"status": self.status, "frames": self.frames, "jpeg_decodes": self.jpeg_decodes, "dropped": self.dropped, "inference_ms": round(self.inference_ms, 2),
                "target_filter": self.filter_mode, "observer_team": self.own_team(), "filtered_friendly": self.filtered_friendly,
                "detection_scope": "armor" if self.config.get("format", "rp26-armor-v8") == "rp26-armor-v8" else "whole_robot",
                "coordinate_boundary": "image observations; optional explicitly configured mobile ground estimate",
                "identity": self.identity.details(), "projection": self.projection.details(), "tracking_scope": self.scope+":"+self.session}
