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

## 构建

依赖 Qt 6.5 及以上、C++17、CMake、Protobuf、libmosquitto 和 FFmpeg。使用随附预设需要 CMake 3.21 及以上。提供可用的 Qt 安装前缀后执行：

```bash
cmake --preset release -DCMAKE_PREFIX_PATH="$QT_PREFIX"
cmake --build --preset release
```

可执行文件名为 `RoboMasterMqttTest`，输出位置由预设和 CMake 配置结果确定。可选图像计算、语音与三维能力的依赖按需交付，缺失时不阻断基础 MQTT、UDP 与 QML 界面。

[构建与配置](docs/TECHNICAL.md#configuration) · [插件使用](docs/TECHNICAL.md#management) · [扩展 SDK](docs/TECHNICAL.md#authoring) · [175 个协议字段](docs/TECHNICAL.md#fields) · [故障排查](docs/TECHNICAL.md#troubleshooting)
