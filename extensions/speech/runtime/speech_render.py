"""One isolated eSpeak NG synthesis; raw text is read from stdin, never a shell."""
import ctypes
import ctypes.util
import json
import sys
import wave


def main():
    request = json.loads(sys.stdin.buffer.read(8192))
    text, output = request["text"], request["output"]
    if not isinstance(text, str) or not 1 <= len(text) <= 300:
        raise ValueError("text length")
    path = ctypes.util.find_library("espeak-ng")
    if not path:
        raise RuntimeError("eSpeak NG library unavailable")
    library = ctypes.CDLL(path)
    library.espeak_Initialize.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_char_p, ctypes.c_int]
    rate = library.espeak_Initialize(1, 0, None, 0)
    if rate <= 0:
        raise RuntimeError("eSpeak NG data unavailable")
    library.espeak_SetVoiceByName.argtypes = [ctypes.c_char_p]
    if library.espeak_SetVoiceByName(request.get("voice", "cmn").encode()) != 0:
        raise RuntimeError("voice unavailable")
    pcm = bytearray()
    callback_type = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.POINTER(ctypes.c_short), ctypes.c_int, ctypes.c_void_p)
    @callback_type
    def callback(samples, count, events):
        if count > 0 and samples:
            if len(pcm)+count*2 > rate*2*30:
                return 1
            pcm.extend(ctypes.string_at(samples, count*2))
        return 0
    library.espeak_SetSynthCallback.argtypes = [callback_type]
    library.espeak_SetSynthCallback(callback)
    library.espeak_Synth.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_uint, ctypes.c_int,
                                    ctypes.c_uint, ctypes.c_uint, ctypes.c_void_p, ctypes.c_void_p]
    encoded = ctypes.create_string_buffer(text.encode("utf-8"))
    if library.espeak_Synth(encoded, len(encoded), 0, 1, 0, 1, None, None) != 0:
        raise RuntimeError("synthesis failed")
    library.espeak_Synchronize()
    library.espeak_Terminate()
    if not pcm:
        raise RuntimeError("empty audio")
    with wave.open(output, "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(rate)
        stream.writeframes(pcm)


if __name__ == "__main__":
    main()
