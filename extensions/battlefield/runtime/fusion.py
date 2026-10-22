"""Conservative fusion: matching identity/frame only, disagreement stays visible."""
import collections
import math
import hashlib
import time
from contract import observation, utc_ms
from sequence_history import SequenceHistory


class Fusion:
    def __init__(self, frame_id="field.2026", conflict_m=2.0):
        self.frame_id, self.conflict_m = frame_id, conflict_m
        self.samples, self.trails = {}, {}
        self.sequences = SequenceHistory()
        self.rejected, self.accepted = 0, 0
        self.capacity_rejected = self.omitted_tracks = 0

    def accept(self, sample, origin, now=None):
        try:
            item = observation(sample, now)
            key = (origin, item["source_id"], item["target_id"])
            if key not in self.samples and len(self.samples) >= 512:
                raise ValueError("active observation capacity")
            self.sequences.accept(key, item["sequence"])
            # Preserve original age, then expire on a local monotonic deadline.
            remaining = min(item["ttl_ms"], item["stamp_ms"]+item["ttl_ms"]-(utc_ms() if now is None else now))
            item.update(origin=origin, deadline=time.monotonic()+remaining/1000)
            self.samples[key] = item
            self.accepted += 1
            return True
        except (ValueError, TypeError) as error:
            if "capacity" in str(error):self.capacity_rejected += 1
            self.rejected += 1
            return False

    def retire(self, origin):
        self.samples = {k: v for k, v in self.samples.items() if k[0] != origin}
        self.sequences.retire(origin)
        # Authenticated transport session tombstones reject the retired network session.

    def clear(self):
        self.samples.clear()
        self.sequences.clear()
        self.trails.clear()

    def close(self):
        self.sequences.close()

    def live(self):
        now = time.monotonic()
        self.samples = {k: v for k, v in self.samples.items() if v["deadline"] > now}
        return list(self.samples.values())

    def snapshot(self):
        groups = collections.defaultdict(list)
        for item in self.live():
            if "position" in item and item["frame_id"] == self.frame_id:
                target = item['target_id']
                if target == 'unknown' or target.startswith('vision:'):
                    # Camera-local track numbers are never global robot identities.
                    scope = item['origin']+'/'+item['source_id']+'/'+target
                    target = 'anonymous:'+hashlib.sha256(scope.encode()).hexdigest()[:24]
                groups[target].append(item)
        tracks = []
        self.omitted_tracks = max(0, len(groups)-256)
        active = set()
        for target, values in list(groups.items())[:256]:
            values = sorted(values, key=lambda v: -v["stamp_ms"])[:16]
            active.add(target)
            positions = [v["position"] for v in values]
            conflict = any(math.dist(a, b) > self.conflict_m for a in positions for b in positions)
            teams = {v["team"] for v in values if v["team"] != "unknown"}
            conflict |= len(teams) > 1
            weights = [max(.001, v["confidence"])/max(.01, v["uncertainty_m"])**2 for v in values]
            position = None if conflict else [sum(p[j]*w for p, w in zip(positions, weights))/sum(weights) for j in range(2)]
            headings = [(v["heading"], w) for v, w in zip(values, weights) if v.get("heading") is not None]
            sin_sum = sum(math.sin(a)*w for a, w in headings)
            cos_sum = sum(math.cos(a)*w for a, w in headings)
            heading = math.atan2(sin_sum, cos_sum) if headings and math.hypot(sin_sum, cos_sum) > .01 else None
            deadline = min(v["deadline"] for v in values)
            trail = self.trails.setdefault(target, collections.deque(maxlen=12))
            stamp = max(v["stamp_ms"] for v in values)
            if position and (not trail or stamp > trail[-1]["stamp_ms"]):
                trail.append({"position": position, "stamp_ms": stamp})
            while trail and utc_ms()-trail[0]["stamp_ms"] > 5000:
                trail.popleft()
            evidence = [{"id": v["origin"]+"/"+v["source_id"]+"/"+v["target_id"], "sequence": v["sequence"],
                         "stamp_ms": v["stamp_ms"], "kind": v["kind"], "confidence": v["confidence"],
                         "position": v["position"], "estimated": v.get("estimated", False),
                         "calibration_id": v.get("calibration_id", ""), "uncertainty_m": v["uncertainty_m"], "remaining_ms": max(0, int((v["deadline"]-time.monotonic())*1000))} for v in values]
            tracks.append({"id": target, "position": position, "heading": None if conflict else heading,
                           "team": next(iter(teams)) if len(teams) == 1 else "unknown", "conflict": bool(conflict),
                           "confidence": min(.95, max(v["confidence"] for v in values)), "stamp_ms": stamp,
                           "remaining_ms": max(0, int((deadline-time.monotonic())*1000)), "evidence": evidence,
                           "uncertainty_m": None if conflict else max(math.dist(v['position'], position)+v['uncertainty_m'] for v in values),
                           "state": "conflict" if conflict else "fused_estimate" if len(values)>1 else "observation",
                           "trail": list(trail) if not conflict else []})
        self.trails = {k: v for k, v in self.trails.items() if k in active}
        return tracks
