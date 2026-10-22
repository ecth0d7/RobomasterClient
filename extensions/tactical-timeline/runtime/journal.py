"""Bounded human annotations, separate from measured/fused robot positions."""
import collections
import json
import math
import secrets
import time
from contract import observation, utc_ms

SOURCE = "operator.tactical"
UNIT = "rm.tactical.mark/1"
INTENTS = {"observe", "defend", "rally"}


class Journal:
    def __init__(self, config):
        self.frame = config["frame_id"]
        self.events = collections.OrderedDict()
        self.rejected = 0
        self.last_created = 0
        self.status = "人工标注已启用；共享需接收端明确授权"

    def close(self):
        self.events.clear()

    def create(self, message):
        if time.monotonic()-self.last_created < .5:
            raise ValueError("annotation rate")
        text, intent = message.get("text"), message.get("intent")
        if not isinstance(text, str) or not 1 <= len(text.strip()) <= 64 or any(ord(c)<32 for c in text):
            raise ValueError("annotation text")
        if intent not in INTENTS:
            raise ValueError("annotation intent")
        value = {"v":1, "intent":intent, "text":text.strip()}
        if message.get("position") is not None:
            p = message["position"]
            height = 16 if self.frame == "field.2027" else 15
            if self.frame not in ("field.2026", "field.2027", "rmuc2027.regional.field.v1") or not isinstance(p,list) or len(p)!=2 or any(type(n) not in (int,float) or not math.isfinite(n) for n in p) or not (0<=p[0]<=28 and 0<=p[1]<=height):
                raise ValueError("annotation coordinates")
            value["point"] = p
        self.last_created = time.monotonic()
        return observation({"source_id":SOURCE, "target_id":"mark:"+secrets.token_hex(10),
            "sequence":1, "stamp_ms":utc_ms(), "ttl_ms":5000, "kind":"sensor", "team":"unknown",
            "frame_id":self.frame, "confidence":1., "label":"人工标注", "value":json.dumps(value,ensure_ascii=False,separators=(",",":")), "data_type":"text", "unit":UNIT})

    def accept(self, item, origin):
        try:
            clean = {k:v for k,v in item.items() if k not in ("origin", "deadline")}
            observation(clean)
            if clean["source_id"]!=SOURCE or clean["kind"]!="sensor" or clean.get("unit")!=UNIT or clean.get("data_type")!="text" or clean["frame_id"]!=self.frame:
                raise ValueError("annotation contract")
            value=json.loads(clean["value"])
            if not isinstance(value,dict) or not {"v","intent","text"}<=value.keys() or value.keys()-{"v","intent","text","point"} or type(value["v"]) is not int or value["v"]!=1 or value["intent"] not in INTENTS or not isinstance(value["text"],str) or not 1<=len(value["text"].strip())<=64 or any(ord(c)<32 for c in value["text"]):
                raise ValueError("annotation payload")
            if "point" in value:
                p=value["point"];height=16 if self.frame=="field.2027" else 15
                if not isinstance(p,list) or len(p)!=2 or any(type(n) not in (int,float) or not math.isfinite(n) for n in p) or not (0<=p[0]<=28 and 0<=p[1]<=height):raise ValueError("annotation point")
            self.prune()
            key=origin+"/"+clean["target_id"]
            # 同一人工事件只接纳一次；转发或重新接收不能更新其时间和有效期。
            if key in self.events:return False
            if len(self.events)>=128:raise ValueError("annotation capacity")
            self.events[key]={"id":key,"origin":origin,"text":value["text"],"intent":value["intent"],
                "point":value.get("point"),"frame_id":self.frame,"stamp_ms":clean["stamp_ms"],
                "expires_ms":clean["stamp_ms"]+clean["ttl_ms"],"offline":False,
                "retire_at":time.monotonic()+60}
            return True
        except (ValueError,TypeError,KeyError):
            self.rejected+=1
            return False

    def prune(self):
        now=time.monotonic()
        self.events=collections.OrderedDict((k,v) for k,v in self.events.items() if v["retire_at"]>now)

    def disconnected(self, origin):
        for item in self.events.values():
            if item["origin"]==origin:item["offline"]=True

    def details(self):
        self.prune()
        return {"enabled":True,"status":self.status,"rejected":self.rejected,"capacity":128,
            "events":[{k:v for k,v in item.items() if k!="retire_at"} for item in reversed(self.events.values())]}
