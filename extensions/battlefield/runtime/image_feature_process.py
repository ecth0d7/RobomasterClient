"""Bounded, independently owned image workers; no network or robot command API.

Only JSON crosses a private socket pair. Native inference libraries are imported in
the child, so an import failure or native crash cannot kill the coordinator.
"""
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import time
from contract import canonical, utc_ms


class ImageFeatureProcess:
    def __init__(self, config, feature, sequence=0):
        self.config = dict(config)
        self.feature = feature
        self.sequence = sequence
        self.process = None
        self.channel = None
        self.tracks = []
        self._state = {}
        self._samples = []
        self._input = bytearray()
        self._output = bytearray()
        self._serial = self._ack = 0
        self._busy = False
        self._ready = False
        self._last_seen = time.monotonic()
        self._submitted_at = None
        self.dropped = 0
        self.failed = False
        self.status = "未启用视觉" if feature == "yolo-vision" else "弹丸跟踪未启用"
        if self.config.get("enabled", False):
            self._start()

    def _start(self):
        self._ready = False
        entry = Path(__file__).resolve().parents[2]/self.feature/"runtime"/"worker.py"
        if not entry.is_file():
            self._fail("可选计算插件未安装")
            return
        try:
            parent, child = socket.socketpair()
            self.channel = parent
            for endpoint in (parent, child):
                endpoint.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 1024*1024)
                endpoint.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1024*1024)
            # Image workers need runtime/library settings, not model-provider
            # tokens or team HMAC environment variables. Same-user filesystem
            # access remains possible; this is not an OS permission sandbox.
            runtime_keys = ("PATH", "HOME", "TMPDIR", "TMP", "TEMP", "SystemRoot", "WINDIR",
                "LANG", "LC_ALL", "XDG_CACHE_HOME", "LD_LIBRARY_PATH", "CUDA_VISIBLE_DEVICES",
                "OMP_NUM_THREADS", "MKL_NUM_THREADS")
            environment = {key:os.environ[key] for key in runtime_keys if key in os.environ}
            environment["PYTHONNOUSERSITE"] = "1"
            self.process = subprocess.Popen([sys.executable, "-B", "-u", str(entry), str(os.getpid())],
                stdin=child, stdout=child, stderr=subprocess.DEVNULL,
                bufsize=0, env=environment, start_new_session=os.name == "posix")
            child.close()
            parent.setblocking(False)
            self.status = "正在启动独立计算进程"
            self._send({"kind": "configuration", "configuration": self.config})
        except (OSError, ValueError):
            if "child" in locals(): child.close()
            self._fail("独立计算进程启动失败")

    def _terminate(self):
        process, self.process = self.process, None
        if process:
            # Each worker owns a process group; no unrelated desktop/server
            # process is addressed. There are no unbounded shutdown waits.
            if process.poll() is None:
                try:
                    if os.name == "posix": os.killpg(process.pid, signal.SIGTERM)
                    else: process.terminate()
                    process.wait(timeout=.2)
                except subprocess.TimeoutExpired:
                    if os.name == "posix": os.killpg(process.pid, signal.SIGKILL)
                    else: process.kill()
                    process.wait(timeout=.2)
                except ProcessLookupError:
                    pass
            for stream in (process.stdin, process.stdout):
                if stream: stream.close()
        if self.channel:
            self.channel.close()
            self.channel = None
        self._input.clear()
        self._output.clear()

    def _fail(self, status):
        self.failed = True
        self.status = status+"；其它插件继续运行，重新启停可重试"
        self._terminate()
        self.tracks = []
        self._state = {}
        self._samples.clear()
        self._busy = False

    def close(self):
        self._terminate()
        self.tracks = []
        self._state = {}
        self._samples.clear()

    def reset(self):
        # Preserve the outbound source sequence across image sessions. Peers'
        # anti-replay watermarks must not be reset just to restart a detector.
        self.close()
        self._serial = self._ack = 0
        self._busy = False
        self._submitted_at = None
        if self.config.get("enabled", False) and not self.failed:
            self._last_seen = time.monotonic()
            self._start()

    def _flush(self):
        if not self.process or not self._input: return
        try:
            count = self.channel.send(self._input)
            del self._input[:count]
        except BlockingIOError:
            pass
        except (OSError, ValueError):
            self._fail("独立计算进程输入已断开")

    def _send(self, message):
        raw = canonical(message)+b"\n"
        if not self.process or len(raw) > 1024*1024 or len(self._input)+len(raw) > 1024*1024:
            self.dropped += 1
            return False
        self._input.extend(raw)
        self._flush()
        return self.process is not None

    def _pump(self):
        if not self.process: return
        if self.process.poll() is not None:
            self._fail("独立计算进程已退出")
            return
        self._flush()
        if not self.process: return
        try:
            for _ in range(32):
                try: raw = self.channel.recv(65536)
                except BlockingIOError: break
                if not raw: break
                self._output.extend(raw)
                if len(self._output) > 2*1024*1024:
                    raise ValueError("worker output limit")
                while b"\n" in self._output:
                    line, _, rest = self._output.partition(b"\n")
                    self._output = bytearray(rest)
                    state = json.loads(line)
                    if state.get("schema") != "rm.image.feature/1" or not isinstance(state.get("details"), dict):
                        raise ValueError("worker schema")
                    stamp = state.get("stamp_ms")
                    if type(stamp) is not int or not 0 <= utc_ms()-stamp <= 1500:
                        continue
                    self._last_seen = time.monotonic()
                    if state.get("failed"):
                        self._fail("独立计算插件初始化失败")
                        return
                    self._ready = True
                    self._state = state["details"]
                    self.status = str(self._state.get("status", "独立计算进程运行中"))[:240]
                    self.tracks = state.get("tracks", [])[:64]
                    self._ack = state.get("serial", 0)
                    self._busy = state.get("busy") is True
                    if self._ack >= self._serial and not self._busy:
                        self._submitted_at = None
                    for sample in state.get("samples", [])[:64]:
                        if len(self._samples) >= 64: break
                        if not isinstance(sample, dict): raise ValueError("worker observation")
                        self.sequence += 1
                        sample["sequence"] = self.sequence
                        self._samples.append(sample)
            if time.monotonic()-self._last_seen > 3 or self._submitted_at and time.monotonic()-self._submitted_at > 3:
                self._fail("独立计算进程超时")
        except (OSError, ValueError, TypeError, KeyError, AttributeError, OverflowError):
            self._fail("独立计算进程输出无效")

    def submit(self, frame):
        self._pump()
        if not self.config.get("enabled", False) or not self.process or not self._ready: return
        if self._busy or self._serial > self._ack or self._input:
            self.dropped += 1
            return
        self._serial += 1
        if self._send({"kind": "frame", "serial": self._serial, "frame": frame}):
            self._submitted_at = time.monotonic()

    def poll(self):
        self._pump()
        now = utc_ms()
        limit = 1500 if self.feature == "yolo-vision" else 450
        self.tracks = [t for t in self.tracks if 0 <= now-t.get("stamp_ms", 0) <= limit]
        for track in self.tracks:
            track["age_ms"] = now-track["stamp_ms"]
            track["occluded"] = track["age_ms"] > 500
        samples, self._samples = self._samples, []
        return [s for s in samples if type(s.get("stamp_ms")) is int and type(s.get("ttl_ms")) is int
                and s["stamp_ms"] <= now < s["stamp_ms"]+s["ttl_ms"]]

    def details(self):
        result = dict(self._state, status=self.status, worker_pid=self.process.pid if self.process else 0,
            isolated_process=True, worker_failed=self.failed, ipc_dropped=self.dropped)
        if self.feature == "hero-projectile":
            result["tracks"] = self.tracks
            if not 0 <= utc_ms()-result.get("trail_stamp_ms", 0) <= 450:
                result.update(trail_image="", trail_pixels=0)
        return result


class VisionProcess(ImageFeatureProcess):
    def __init__(self, config, sequence=0): super().__init__(config, "yolo-vision", sequence)


class ProjectileProcess(ImageFeatureProcess):
    def __init__(self, config, sequence=0): super().__init__(config, "hero-projectile", sequence)
