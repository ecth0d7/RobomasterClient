"""Private image-worker loop. No external transport or robot command API."""
import json
import os
import select
import signal
import sys
import time
from contract import canonical, utc_ms


def run(factory, vision=False):
    service = None
    pending = bytearray()
    serial = 0
    last_state = 0
    running = True
    def stop(*_):
        nonlocal running
        running = False
    def emit(value):
        nonlocal pending
        if pending:
            try: del pending[:os.write(sys.stdout.fileno(), pending)]
            except BlockingIOError: return
        if pending: return
        pending.extend(canonical(value)+b"\n")
        try: del pending[:os.write(sys.stdout.fileno(), pending)]
        except BlockingIOError: pass
    def state(samples=(), failed=False):
        details = service.details() if service else {"status": "计算插件未初始化"}
        return {"schema":"rm.image.feature/1", "stamp_ms":utc_ms(), "serial":serial,
            "failed":failed, "busy":service.future is not None if service else False,
            "details":details, "tracks":service.tracks if vision and service else details.get("tracks", []), "samples":samples}
    try:
        if sys.platform.startswith("linux"):
            # EOF is the portable cooperative exit. A Linux parent-death guard
            # also covers a coordinator SIGKILL during a stuck native call.
            import ctypes
            expected_parent = int(sys.argv[1]) if len(sys.argv)>1 else os.getppid()
            libc = ctypes.CDLL(None, use_errno=True)
            libc.prctl.argtypes = [ctypes.c_int, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_ulong]
            if libc.prctl(1, signal.SIGKILL, 0, 0, 0) != 0 or os.getppid()!=expected_parent:
                raise RuntimeError("worker parent lifetime")
        first = sys.stdin.buffer.readline(131073)
        if len(first) > 131072: raise ValueError("configuration limit")
        config = json.loads(first)
        if config.get("kind") != "configuration": raise ValueError("configuration schema")
        os.set_blocking(sys.stdout.fileno(), False)
        service = factory(config["configuration"])
        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        fd = sys.stdin.fileno()
        os.set_blocking(fd, False)
        buffer = bytearray()
        while running:
            readable, _, _ = select.select([fd], [], [], .02)
            changed = False
            if readable:
                raw = os.read(fd, 65536)
                if not raw: break
                buffer.extend(raw)
                if len(buffer) > 1024*1024: raise ValueError("frame limit")
                while b"\n" in buffer:
                    line, _, rest = buffer.partition(b"\n"); buffer = bytearray(rest)
                    message = json.loads(line)
                    if message.get("kind") != "frame": raise ValueError("worker method")
                    serial = message["serial"]
                    service.submit(message["frame"])
                    changed = True
            had_future = service.future is not None
            samples = service.poll()
            if samples or changed or had_future and service.future is None or time.monotonic()-last_state >= .1:
                emit(state(samples)); last_state = time.monotonic()
    except Exception:
        # Errors are scoped and bounded; do not expose paths, credentials or a
        # model/server response body through the host's status channel.
        try:
            os.set_blocking(sys.stdout.fileno(), False)
            emit(state(failed=True))
        except Exception: pass
    finally:
        if service: service.close()
