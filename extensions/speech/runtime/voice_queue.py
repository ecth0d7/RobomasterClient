import collections
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
from contract import canonical, utc_ms

PRIORITIES = {"info": 0, "caution": 1, "urgent": 2}


class VoiceQueue:
    def __init__(self, config):
        self.config = config
        self.enabled = bool(config.get("enabled", False))
        self.muted = bool(config.get("muted", False))
        self.queue, self.recent = [], collections.OrderedDict()
        self.process = None
        self.active = None
        self.phase = "idle"
        self.status = "未启用语音" if not self.enabled else "语音就绪"
        self.directory = tempfile.TemporaryDirectory(prefix="rm-voice-")
        self.path = str(Path(self.directory.name)/"utterance.wav")
        self.played = self.synthesized = self.dropped = self.interrupts = self.failed = 0

    def close(self):
        self.clear()
        if self.process:
            self.process.kill()
            self.process.wait(timeout=1)
            self.process = None
        self.directory.cleanup()

    def _cancel(self):
        if self.process:
            self.process.kill()
            # Reap asynchronously on the next poll; no stale utterance is restarted.
            self.phase = "retiring"
        self.active = None

    def clear(self, origin=None):
        self.queue = [x for x in self.queue if origin is not None and x["origin"] != origin]
        if self.active and (origin is None or self.active["origin"] == origin):
            self._cancel()

    def mute(self, value):
        self.muted = bool(value)
        if self.muted:
            self.clear()
        self.status = "已静音" if self.muted else "语音就绪"

    def submit(self, text, priority="info", key="", expires_ms=None, origin="local"):
        if not self.enabled or self.muted or not isinstance(text, str) or not 1 <= len(text) <= 300 or any(ord(c)<32 and c not in "\n\t" for c in text) or priority not in PRIORITIES:
            self.dropped += 1
            return False
        expires = min(expires_ms or utc_ms()+5000, utc_ms()+5000)
        content_key = origin+":"+priority+":text:"+hashlib.sha256(text.encode()).hexdigest()
        key = origin+":"+priority+":event:"+key if key else content_key
        if expires <= utc_ms() or any(k in self.recent and time.monotonic()-self.recent[k] < 10 for k in (key, content_key)):
            self.dropped += 1
            return False
        self.recent[key] = time.monotonic()
        self.recent[content_key] = time.monotonic()
        while len(self.recent) > 256:
            self.recent.popitem(last=False)
        item = {"text": text, "priority": priority, "key": key, "expires_ms": expires, "origin": origin}
        if self.active and PRIORITIES[priority] > PRIORITIES[self.active["priority"]]:
            self.interrupts += 1
            self._cancel()
        self.queue.append(item)
        self.queue.sort(key=lambda x: -PRIORITIES[x["priority"]])
        if len(self.queue) > 16:
            self.queue.pop()
            self.dropped += 1
        return True

    def poll(self):
        self.queue = [x for x in self.queue if x["expires_ms"] > utc_ms()]
        if self.active and self.active["expires_ms"] <= utc_ms():
            self._cancel()
        if self.process:
            code = self.process.poll()
            if code is None:
                return
            self.process = None
            if self.phase == "retiring":
                self.phase = "idle"
            elif code:
                self.failed += 1
                self.active = None
                self.phase = "idle"
                self.status = "语音设备或合成不可用；本条已丢弃"
            elif self.phase == "synthesis" and self.active:
                self.synthesized += 1
                if self.config.get("synthesize_only", False):
                    self.active = None
                    self.phase = "idle"
                    self.status = "已合成；配置为不播放"
                else:
                    player = shutil.which("paplay")
                    if not player:
                        self.failed += 1
                        self.active = None
                        self.phase = "idle"
                        self.status = "未找到音频播放器；本条已丢弃"
                    else:
                        args = [player]
                        device = self.config.get("device", "")
                        if device:
                            args.append("--device="+device)
                        args.append(self.path)
                        self.process = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        self.phase = "playback"
            elif self.phase == "playback":
                self.played += 1
                self.active = None
                self.phase = "idle"
                self.status = "播报完成"
        if not self.process and not self.active and self.queue and not self.muted:
            self.active = self.queue.pop(0)
            self.phase = "synthesis"
            self.status = "合成中"
            self.process = subprocess.Popen([sys.executable, str(Path(__file__).with_name("speech_render.py"))],
                                            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.process.stdin.write(canonical({"text": self.active["text"], "output": self.path, "voice": self.config.get("voice", "cmn")}))
            self.process.stdin.close()

    def details(self):
        return {"enabled": self.enabled, "muted": self.muted, "phase": self.phase, "queued": len(self.queue),
                "synthesized": self.synthesized, "played": self.played, "failed": self.failed,
                "dropped": self.dropped, "interrupts": self.interrupts, "status": self.status}
