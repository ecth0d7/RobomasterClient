# RoboMasterClient

基于 Qt 6 / C++ / QML 的 RoboMaster 自定义客户端，支持官方 MQTT 消息、UDP H.264 / HEVC 视频、机器人操作面板，以及按需启用的整机识别、队内共享、语音播报和战场态势。

完整说明见 [技术与操作手册](docs/TECHNICAL.md)。当前官方消息映射以 2026 赛季协议为准；2027 规则与场地展示的接入边界见[赛季能力](docs/TECHNICAL.md#laboratory-2027)。

## 常用快捷键

| 按键 | 用途 |
| --- | --- |
| P / H | 设置 / 按角色打开兑换、工程或空中支援 |
| 按住 Tab / F12 | 机器人状态 / 操作帮助，松开关闭 |
| M / F11 | 大地图 / 全屏切换 |
| Ctrl+Shift+L | MQTT、UDP 与机器人身份，比赛中也可修改 |
| Ctrl+Shift+I | 开启或释放原始键鼠捕获 |
| Ctrl+Shift+K | 查看和修改快捷键 |
| Ctrl+Shift+E | 服务与插件启停 |

[完整快捷键表](docs/TECHNICAL.md#shortcuts)按角色和面板说明哪些按键只选择、哪些需要确认、哪些会直接发送请求；[地图操作](docs/TECHNICAL.md#maps)说明长按滑动标注。

## 构建与启动

以下为 Linux 的构建与启动方式。先准备 Qt 6.5 及以上、C++17 编译器、CMake、Protobuf、libmosquitto 和 FFmpeg；详细要求见[构建依赖](docs/TECHNICAL.md#configuration)。使用随附预设需要 CMake 3.21 及以上。

### 1. 进入项目根目录

首次下载源码时，在希望保存项目的目录打开终端：

```bash
git clone https://github.com/ecth0d7/RobomasterClient.git
cd RobomasterClient
```

如果已有源码，直接在该项目文件夹打开终端即可。**项目根目录就是同时包含 `CMakeLists.txt`、`CMakePresets.json` 和本 README 的目录。**下面的配置、编译与启动命令都在这里执行。

### 2. 配置并编译

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel 4
```

CMake 会在当前项目内创建普通的 `build/` 目录。可执行文件、复制后的 QML 界面和插件都输出到这个构建目录，不需要另外创建外部工作区或符号链接。`build/` 已被 Git 忽略，不会上传构建产物。

若 CMake 提示找不到 Qt，请先设置 `QT_PREFIX` 为你的 Qt 安装前缀（该目录中应包含 `lib/cmake/Qt6/Qt6Config.cmake`），然后在项目根目录重新配置：

```bash
export QT_PREFIX="/path/to/Qt/6.x/gcc_64"  # 替换为实际的 Qt 安装前缀
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$QT_PREFIX"
cmake --build build --parallel 4
```

也可以用预设执行同样的 Release 构建，输出仍为项目内的 `build/`：

```bash
cmake --preset release
cmake --build --preset release
```

### 3. 启动客户端

编译完成后，**仍在项目根目录**执行：

```bash
./build/RoboMasterMqttTest
```

如果终端已经位于 `build/` 目录，使用：

```bash
./RoboMasterMqttTest
```

程序启动后，按 **Ctrl+Shift+L** 打开连接面板，填写 MQTT 目标、UDP 监听参数和机器人身份，再点击连接。退出时关闭程序窗口；通过终端启动时也可以按 **Ctrl+C**。

修改源码后的常用操作为：在项目根目录执行 `cmake --build build --parallel 4`，完成后再运行 `./build/RoboMasterMqttTest`。修改构建配置或新增源码文件时，先重新执行配置命令。

可选图像计算、语音与三维能力的依赖按需交付，缺失时不阻断基础 MQTT、UDP 与 QML 界面。

[构建与配置](docs/TECHNICAL.md#configuration) · [插件使用](docs/TECHNICAL.md#management) · [扩展 SDK](docs/TECHNICAL.md#authoring) · [175 个协议字段](docs/TECHNICAL.md#fields) · [故障排查](docs/TECHNICAL.md#troubleshooting)
