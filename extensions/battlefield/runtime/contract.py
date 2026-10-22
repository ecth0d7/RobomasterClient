"""Versioned display-only observations; no official command encoding exists here."""
import hashlib
import hmac
import json
import math
import re
import time

SCHEMA = "rm.situation/1"
MAX_BYTES = 49152
ID = re.compile(r"[A-Za-z0-9_.:-]{1,96}\Z")


def utc_ms():
    return int(time.time() * 1000)


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def decode(raw):
    if len(raw) > MAX_BYTES:
        raise ValueError("packet too large")
    def pairs(items):
        result = {}
        for k, v in items:
            if k in result:
                raise ValueError("duplicate JSON key")
            result[k] = v
        return result
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=lambda _: (_ for _ in ()).throw(ValueError("nonfinite JSON")))


def identifier(value):
    return isinstance(value, str) and ID.fullmatch(value) is not None


def number(value, low=-1e6, high=1e6):
    return type(value) in (int, float) and math.isfinite(value) and low <= value <= high


def integer(value, low, high):
    return type(value) is int and low <= value <= high


def observation(value, now=None):
    now = utc_ms() if now is None else now
    required = {"source_id", "target_id", "sequence", "stamp_ms", "ttl_ms", "kind", "team", "frame_id", "confidence"}
    allowed = required | {"position", "heading", "bbox", "uncertainty_m", "calibration_id", "estimated", "label", "value", "data_type", "unit", "image_trail"}
    if not isinstance(value, dict) or not required <= value.keys() or value.keys() - allowed:
        raise ValueError("observation fields")
    if not all(identifier(value[k]) for k in ("source_id", "target_id", "frame_id")):
        raise ValueError("observation identity")
    if value["kind"] not in ("vision", "radar", "odometry", "position", "sensor", "telemetry") or value["team"] not in ("red", "blue", "unknown"):
        raise ValueError("observation kind/team")
    if not integer(value["sequence"], 1, 2**53-1) or not integer(value["stamp_ms"], 1, 2**53-1) or not integer(value["ttl_ms"], 50, 5000):
        raise ValueError("observation time/sequence")
    # No renewal by forwarding. Wall-clock agreement is explicitly required on the team plane.
    if value["stamp_ms"] > now + 250 or value["stamp_ms"] + value["ttl_ms"] <= now:
        raise ValueError("expired/future observation")
    if not number(value["confidence"], 0, 1):
        raise ValueError("observation confidence")
    if "position" not in value and "bbox" not in value and "value" not in value:
        raise ValueError("observation has no measurement")
    if "value" in value:
        v, t = value["value"], value.get("data_type")
        valid = (t == "scalar" and number(v)) or (t == "boolean" and type(v) is bool) or (t == "text" and isinstance(v, str) and len(v) <= 300) or (t == "vector" and isinstance(v, list) and 1 <= len(v) <= 16 and all(number(n) for n in v))
        if not valid or not isinstance(value.get("unit"), str) or len(value["unit"]) > 32:
            raise ValueError("typed sensor value/unit")
    if "position" in value:
        p = value["position"]
        if not isinstance(p, list) or len(p) != 2 or not all(number(x, -200, 200) for x in p):
            raise ValueError("position metres")
        if not number(value.get("uncertainty_m"), .01, 100):
            raise ValueError("position uncertainty required")
    if "bbox" in value:
        b = value["bbox"]
        if not isinstance(b, list) or len(b) != 4 or not all(number(x, 0, 1) for x in b) or min(b[2:]) <= 0 or b[0]+b[2] > 1.001 or b[1]+b[3] > 1.001:
            raise ValueError("normalized bounding box")
    if "image_trail" in value:
        points = value["image_trail"]
        if value["kind"] != "vision" or "bbox" not in value or not value["frame_id"].startswith("camera.") or not isinstance(points, list) or not 2 <= len(points) <= 12:
            raise ValueError("image trail scope/capacity")
        previous = 0
        for point in points:
            if not isinstance(point, list) or len(point) != 3 or not all(number(v,0,1) for v in point[:2]) or not integer(point[2], max(1,value["stamp_ms"]-2000),value["stamp_ms"]) or point[2] <= previous:
                raise ValueError("image trail coordinates/time")
            previous = point[2]
    if value.get("heading") is not None and not number(value["heading"], -math.pi, math.pi):
        raise ValueError("heading radians")
    if "estimated" in value and type(value["estimated"]) is not bool:
        raise ValueError("estimated flag")
    if "calibration_id" in value and not identifier(value["calibration_id"]):
        raise ValueError("calibration identity")
    if "label" in value and (not isinstance(value["label"], str) or len(value["label"]) > 80 or any(ord(c) < 32 for c in value["label"])):
        raise ValueError("label")
    return dict(value)


def sign(body, key):
    return hmac.new(key, canonical(body), hashlib.sha256).hexdigest()


def verify(body, signature, key):
    return isinstance(signature, str) and len(signature) == 64 and hmac.compare_digest(sign(body, key), signature)


def fused_scene(value):
    required = {"schema", "frame_id", "revision", "stamp_ms", "expires_ms", "tracks", "omitted_tracks"}
    now = utc_ms()
    if not isinstance(value, dict) or set(value) != required or value["schema"] != "rm.situation.fused/1" or not identifier(value["frame_id"]):
        raise ValueError("fused scene schema")
    if not integer(value["revision"], 1, 2**53-1) or not integer(value["stamp_ms"], now-3000, now+250) or not integer(value["expires_ms"], now+1, min(now+3250, value["stamp_ms"]+3000)):
        raise ValueError("fused scene time")
    if not isinstance(value["tracks"], list) or len(value["tracks"]) > 32 or not integer(value["omitted_tracks"], 0, 2048):
        raise ValueError("fused scene capacity")
    for t in value["tracks"]:
        keys = {"id", "position", "heading", "team", "confidence", "stamp_ms", "expires_ms", "state", "conflict", "evidence", "trail"}
        if not isinstance(t, dict) or set(t) != keys or not identifier(t["id"]) or type(t["conflict"]) is not bool or t["team"] not in ("red", "blue", "unknown") or not number(t["confidence"], 0, 1):
            raise ValueError("fused track fields")
        if not integer(t["stamp_ms"], 1, now+250) or not integer(t["expires_ms"], 1, min(now+5250, t["stamp_ms"]+5000)) or t["state"] not in ("conflict", "fused_estimate", "observation"):
            raise ValueError("fused track time/state")
        position = t["position"]
        if t["conflict"]:
            if position is not None:
                raise ValueError("conflicting fused position must remain unknown")
        elif not isinstance(position, list) or len(position) != 2 or not all(number(x, -200, 200) for x in position):
            raise ValueError("fused position")
        if t["heading"] is not None and not number(t["heading"], -math.pi, math.pi):
            raise ValueError("fused heading")
        if not isinstance(t["evidence"], list) or not 1 <= len(t["evidence"]) <= 4:
            raise ValueError("fused evidence capacity")
        for e in t["evidence"]:
            if not isinstance(e, dict) or set(e) != {"id", "kind", "stamp_ms", "confidence", "position"} or not isinstance(e["id"], str) or not 1 <= len(e["id"]) <= 300 or any(ord(c) < 32 for c in e["id"]) or not identifier(e["kind"]) or not integer(e["stamp_ms"], 1, now+250) or not number(e["confidence"], 0, 1):
                raise ValueError("fused evidence")
            if not isinstance(e["position"], list) or len(e["position"]) != 2 or not all(number(v, -200, 200) for v in e["position"]):
                raise ValueError("fused evidence position")
        if not isinstance(t["trail"], list) or len(t["trail"]) > 8:
            raise ValueError("fused trail capacity")
        for point in t["trail"]:
            if not isinstance(point, dict) or set(point) != {"position", "stamp_ms"} or not integer(point["stamp_ms"], 1, now+250) or not isinstance(point["position"], list) or len(point["position"]) != 2 or not all(number(v, -200, 200) for v in point["position"]):
                raise ValueError("fused trail")
    return value
