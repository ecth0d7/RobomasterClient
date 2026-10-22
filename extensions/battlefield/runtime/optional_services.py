"""Optional service adapters keep absence and Python failures component-local.

Native image libraries use dedicated processes. Advice policy and voice queue
remain lightweight schedulers; HTTP/TTS backends keep their existing adapters.
This is exception/lifecycle isolation, not a native crash or resource sandbox.
"""
import importlib
from pathlib import Path
import sys


class OptionalService:
    def __init__(self, config, feature, module, name, label):
        self.config = dict(config)
        self.service = None
        self.failure = ""
        self.label = label
        if config.get("enabled") is not True:
            return
        folder = Path(__file__).resolve().parents[2]/feature/"runtime"
        try:
            if not (folder/(module+".py")).is_file(): raise ImportError("optional component absent")
            sys.path.insert(0, str(folder))
            self.service = getattr(importlib.import_module(module), name)(config)
        except Exception as error:
            self.failure = label+"不可用："+type(error).__name__+"；其它插件继续运行"

    @property
    def status(self):
        return self.failure or (self.service.status if self.service else "未启用"+self.label)

    def call(self, method, *args, **kwargs):
        if not self.service: return False
        try:
            return getattr(self.service, method)(*args, **kwargs)
        except Exception as error:
            self.failure = self.label+"已停用："+type(error).__name__+"；其它插件继续运行"
            self.close()
            return False

    def close(self):
        service, self.service = self.service, None
        if service:
            try: service.close()
            except Exception: pass


class ModelService(OptionalService):
    def __init__(self, config): super().__init__(config, "decision", "advice_model", "Advisor", "模型建议")
    @property
    def advice(self): return self.service.advice if self.service else {}
    @property
    def input_trace(self): return self.service.input_trace if self.service else {}
    def request(self, *args, **kwargs): return self.call("request", *args, **kwargs)
    def poll(self, *args, **kwargs): return self.call("poll", *args, **kwargs)


class VoiceService(OptionalService):
    def __init__(self, config): super().__init__(config, "speech", "voice_queue", "VoiceQueue", "队内语音")
    def submit(self, *args, **kwargs): return self.call("submit", *args, **kwargs)
    def clear(self, *args, **kwargs): return self.call("clear", *args, **kwargs)
    def mute(self, *args, **kwargs): return self.call("mute", *args, **kwargs)
    def poll(self): return self.call("poll")
    def details(self):
        value = self.call("details")
        return dict(value or {"enabled":False, "muted":True, "phase":"unavailable", "queued":0}, status=self.status)


class JournalService(OptionalService):
    def __init__(self, config): super().__init__(config, "tactical-timeline", "journal", "Journal", "战术时间线")
    def create(self, message):
        # 人工输入校验失败只拒绝本次请求，不能因此卸载整个插件。
        if not self.service: return None
        try: return self.service.create(message)
        except (ValueError, TypeError, KeyError): return None
    def accept(self, *args): return self.call("accept", *args)
    def disconnected(self, origin): return self.call("disconnected", origin)
    def details(self): return self.call("details") or {"enabled":False,"status":self.status,"events":[]}
