# RoboMaster Client

A Qt 6-based operator client for the RoboMaster competition, providing real-time robot control, battlefield status monitoring, and live video streaming. Communication with the RoboMaster server is handled over MQTT (Protobuf-encoded) and UDP.

---

## Features

- **MQTT Communication** — 24 receive handlers and 11 send handlers covering game status, robot telemetry, radar, rune, sentry, dart, air support, and more, all serialized with Protocol Buffers.
- **Live Video Streaming** — UDP-based H.264/H.265 video reception decoded via FFmpeg and rendered directly in QML.
- **Robot Control** — Keyboard and mouse input captured globally and forwarded to the robot as control commands.
- **Modular QML UI** — Component-split interface (main view, video display, MQTT data receiver/sender) built with Qt Quick / QuickControls2.
- **RoboServer** — A companion video-streaming server that captures a local camera, encodes frames, and transmits them to this client over UDP.

---

## Architecture

```
RobomasterClient/
├── main.cpp              # App entry: wires up MQTT, UDP, QML engine
├── mqtt/
│   ├── include/          # MqttClient, IMqttHandler, RecvHandlers, SendHandlers
│   ├── src/              # Handler implementations
│   └── protobuf/         # .proto schema → auto-generated C++ serialization
├── udp/
│   ├── include/          # VideoReceiver, VideoImageProvider
│   └── src/              # FFmpeg-backed decode + QML image provider
├── qml/
│   ├── components/       # Main.qml, UI.qml, UdpVideoDisplay.qml, MqttData*.qml
│   ├── include/          # GlobalInputFilter (keyboard/mouse capture)
│   ├── src/              # GlobalInputFilter implementation
│   └── qrc/              # Qt resource file
└── RoboServer/           # Standalone video-streaming server (separate binary)
```

**Default connection parameters** (configurable via the UI at runtime):

| Parameter | Default |
|-----------|---------|
| MQTT broker | `192.168.1.2:139` |
| UDP video port | `3334` |
| Client ID | `robomaster_server2client_001` |

---

## Prerequisites

| Dependency | Version |
|-----------|---------|
| Qt | 6.5+ (Core, Widgets, Network, Gui, Quick, QuickControls2, QuickLayouts) |
| FFmpeg | libavcodec / libavformat / libavutil / libswscale |
| Mosquitto | libmosquitto |
| Protobuf | any recent version |
| Compiler | GCC 9+ or Clang with C++17 support |
| Build tool | CMake 3.19+ |

On Ubuntu/Debian:

```bash
sudo apt install \
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
    libmosquitto-dev libprotobuf-dev protobuf-compiler \
    pkg-config cmake build-essential
```

---

## Building

### Option A — Qt Creator (recommended)

1. Open Qt Creator → **File > Open Project** → select `CMakeLists.txt` in the project root.
2. Choose a kit that uses Qt 6.5 or later. If Qt 6 is not detected automatically, add the CMake variable:
   ```
   Qt6_DIR = /path/to/Qt/6.x.x/gcc_64/lib/cmake/Qt6
   ```
3. Press **Ctrl+B** to build. Qt Creator resolves all dependencies and generates the Protobuf sources automatically.
4. Click **Run** (or **Ctrl+R**) to launch the client.

### Option B — Command line

```bash
# From the project root
mkdir -p build && cd build
cmake .. -DQt6_DIR=/path/to/Qt/6.x.x/gcc_64/lib/cmake/Qt6
make -j$(nproc)
./RoboMasterMqttTest
```

---

## Running the Client

```bash
./RoboMasterMqttTest
```

The application opens the main QML window. Use the login/settings panel to enter the MQTT broker address and client ID, then click **Connect**. Once connected, telemetry panels populate automatically and the video stream starts as soon as the RoboServer is reachable.

### Keyboard & Mouse Control

`GlobalInputFilter` captures all keyboard and mouse events globally (the window does not need focus for keyboard input). Captured input is packed into MQTT control messages and sent to the robot at the rate configured in `MqttDataSender.qml`.

> **Linux note:** The input capture requires read access to `/dev/input/*`. If input is not detected, run the client as a user in the `input` group:
> ```bash
> sudo usermod -aG input $USER   # log out and back in after this
> ```

---

## Building & Running RoboServer

RoboServer is a separate binary that streams video from a local camera to this client over UDP.

```bash
# From the project root
mkdir -p build && cd build
cmake ..
make -j$(nproc)
./sever
```

Make sure the UDP port used by RoboServer matches the port the client listens on (default `3334`), and that the video encoding format (H.264/H.265) and frame rate agree on both sides.

---

## Key Source Files

| File | Purpose |
|------|---------|
| [main.cpp](main.cpp) | Instantiates all handlers, wires the QML engine |
| [mqtt/include/MqttClient.h](mqtt/include/MqttClient.h) | Core MQTT connection & handler registry |
| [mqtt/include/MqttRecvHandlers.h](mqtt/include/MqttRecvHandlers.h) | All 24 receive-side message handlers |
| [mqtt/include/MqttSendHandlers.h](mqtt/include/MqttSendHandlers.h) | All 11 send-side command handlers |
| [udp/include/VideoReceiver.h](udp/include/VideoReceiver.h) | UDP socket + FFmpeg decode pipeline |
| [qml/components/UI.qml](qml/components/UI.qml) | Main UI layout |
| [RoboServer/main.cpp](RoboServer/main.cpp) | Video capture, encode, and UDP send |

---

## Notes

- The project is under active development; some UI panels are not yet fully implemented.
- Protobuf-generated sources are written to `CMAKE_CURRENT_BINARY_DIR` — this path is already added to the include search list in `CMakeLists.txt`.
- If FFmpeg linking fails, verify that `pkg-config` can locate the FFmpeg libraries (`pkg-config --libs libavcodec`).
- Ensure the MQTT broker port is not blocked by a firewall, and that the UDP video port is open in both directions between client and server.
