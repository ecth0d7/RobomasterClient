# HNU 英雄机器人自定义客户端

这是面向英雄机器人副屏的独立 Qt/QML 客户端。它只负责当前 Jetson 自定义客户端链路，不承载比赛全局信息，也不改变电控现有的 SEASKY 协议。

正式链路如下：

```text
图传发送端串口（921600 8N1）
        │
        ▼
      Jetson ── 0x0310 / CustomByteBlock ──► 本客户端（遥测、H.264 视频）
        ▲
        └────── 0x0311 / CustomControl ◄──── 本客户端（trim、reset、heartbeat）

      Jetson ── SEASKY 0x0001 ──► 电控（最终 yaw / pitch / target_state）
      Jetson ◄─ SEASKY 0x0002 ─── 电控（work_mode 等状态）
```

## 功能边界

- 订阅 MQTT topic `CustomByteBlock`，解析 protobuf 外壳中的 raw payload。
- 解析 46B `HNU-TLM` 遥测，并显示模式、RK45、安全链、距离、高度、弹速、TOF、误差和 `pitch_trim_deg`。
- 按 `frame_id / slice_id / frame_total` 重组 `HNU-VID`，将 H.264 帧送入 FFmpeg 解码并全屏铺底显示。
- 发布 MQTT topic `CustomControl`，发送固定 30B `HNU-CMD`：`trim_step`、`trim_reset` 和 1Hz heartbeat。
- 持久化每个 MQTT Client ID 的命令序号，防止客户端重启后复用旧序号。
- MQTT 网络循环运行在 libmosquitto 后台线程，连接失败不会阻塞 QML 主线程或停留在登录页。

客户端不解析比赛服务器其他 topic，不直接参与 `0x0001/0x0002`，也没有最终开火裁决权。

## 目录结构

```text
hero_custom_client/
├── CMakeLists.txt
├── main.cpp                       # 注册后端、视频 Provider，并启用软件场景图
├── protobuf/
│   └── hero_custom_client.proto   # 两个 MQTT topic 的 protobuf 外壳
├── include/                       # C++ 接口
├── src/
│   ├── HeroClient.cpp             # MQTT、heartbeat、视频分片重组
│   ├── HeroProtocol.cpp           # HNU-TLM / HNU-CMD raw 协议
│   ├── H264Decoder.cpp            # FFmpeg H.264 解码与 RGB 转换
│   └── VideoImageProvider.cpp     # 将最新画面提供给 QML
├── qml/
│   ├── HeroMain.qml               # HUD、窗口控制与操作交互
│   ├── Theme.qml                  # 全局颜色、间距、圆角与动效令牌
│   └── icons/                     # 本地 SVG 图标与许可证
└── qml.qrc

hero_test_server/                  # 与正式客户端分离的最小联调服务器
├── CMakeLists.txt
└── main.cpp
```

`hero_test_server` 是仓库根目录下的兄弟工程，不会被正式客户端构建或打包。

## UI 布局与交互

视频流始终位于最底层并按窗口裁切铺满，准星固定在画面几何中心。HUD 的信息层级按操作顺序安排：

- 顶部：DEPLOY 模式、MQTT 状态、视觉遥测在线状态。
- 左侧：目标与 RK45 解算，其下是武器和云台反馈。
- 中央：准星、开火请求和 RK45 结果，只显示最关键状态。
- 右侧：核心、雷达、RK45、Yaw、FULL ADJUST、视觉开火许可组成的安全链。
- 底部：车端回传的 pitch trim 真值、固定上下调按钮、步长选择和清零。

数据标签和值使用固定列宽，遥测内容变化时只更新文字和颜色，不改变控件位置或大小。面板内部使用 `RowLayout/ColumnLayout`，可随窗口尺寸稳定排版。阴影使用普通半透明矩形模拟，不依赖 GPU shader。

HUD 采用适合视频叠加的“液态玻璃”视觉：圆角玻璃面板由透明渐变、内侧反光边、顶部高光和柔和投影组成，状态与按钮使用胶囊形态。这里没有启用实时背景模糊或 `MultiEffect`；这种实现既保留玻璃层次，也兼容当前 Software scene graph，避免 Linux 分数缩放全屏下重新出现黑屏。

### Pitch Trim 按钮

底部使用类似 OBS 键盘映射提示的两个方向键帽：键帽内部只显示 `↓/↑`，方向名称、当前步数和对应角度固定显示在键帽右侧。先选择 `1/2/4` 步，再点击方向；每步为 `0.05°`。

- 按下时键帽下沉、底沿变薄并高亮。
- 命令满足发送条件时，对应方向按钮绿色高亮。
- 命令因断线、非 DEPLOY 或限频而未发送时，按钮红色高亮并显示原因。
- 键盘操作也会高亮对应方向，并同步界面的步长选择。
- UI 不在本地累加 trim；主数值始终以 HNU-TLM 回传的 `pitch_trim_deg` 为准。
- 命令发送后预留 600ms 遥测回环时间，避免旧遥测帧造成“不一致”提示闪烁。

### 快捷键

| 按键 | 功能 | UI 反馈 |
|---|---|---|
| `↑` / `↓` | 上调 / 下调 1 步 | 对应方向按钮高亮，步长切到 1 |
| `Shift + ↑/↓` | 上调 / 下调 2 步 | 对应方向按钮高亮，步长切到 2 |
| `Ctrl + ↑/↓` | 上调 / 下调 4 步 | 对应方向按钮高亮，步长切到 4 |
| `Enter` / 小键盘 `Enter` | 发送 `trim_reset` | 清零按钮短暂显示“清零 ✓” |
| `Esc` | 退出全屏，恢复普通窗口 | 不关闭程序 |
| 双击顶部拖动区 | 普通窗口 / 真全屏切换 | 保持键盘焦点在主画面 |

右上角窗口控制区默认隐藏；鼠标进入热区后显示最小化、全屏/还原、关闭按钮，移出后淡出。

## Trim 安全约束

- 客户端仅在 MQTT 已连接且 HNU-TLM 报告 `mode == 4`（DEPLOY）时发送 `trim_step`。
- 单条 `trim_step` 参数范围为 `[-4,+4]`，不能为 0；两次成功步进至少间隔 0.2s。
- trim 只能由视觉侧叠加在 RK45 成功解出的 pitch 上。
- RK45 失败、雷达过期、核心丢失、状态机未就绪等条件仍由视觉侧否决。
- 电控继续保留热量、弹速、发射机构安全等最终发射否决权。
- 客户端连接后每秒发送 heartbeat。停止 heartbeat 超过 2s 后自动清零 trim 的逻辑属于 Jetson/视觉接收端；测试服务器也实现了同样行为。客户端不会伪造或本地修改 HNU-TLM。

## 构建客户端

依赖 Qt 6.5+、CMake 3.19+、Protobuf、libmosquitto 和 FFmpeg 的 `libavcodec/libavutil/libswscale` 开发包。

在 Qt Creator 中打开 `hero_custom_client/CMakeLists.txt` 并选择 Qt 6 Kit，或在仓库根目录执行：

```bash
cmake -S hero_custom_client -B build-hero
cmake --build build-hero -j
./build-hero/HeroCustomClient
```

CMake 优先使用 Qt Creator Kit、`CMAKE_PREFIX_PATH` 或 `Qt6_DIR`。均未设置时，它会扫描 `$HOME/Qt/*/gcc_64` 和 `$HOME/Qt/*/linux_gcc_64`，不绑定用户名或具体 Qt 版本。

如果 Qt 安装在其他位置：

```bash
cmake -S hero_custom_client -B build-hero \
      -DCMAKE_PREFIX_PATH=/path/to/Qt/6.x/gcc_64
```

程序使用 Qt Quick Software scene graph。这是为 Linux X11 分数缩放环境保留的兼容方案，可避免 150% 显示比例下全屏后按键触发 OpenGL 重绘时出现左上角小画面和大面积黑屏。不要在 `main.cpp` 创建窗口之后再切换渲染后端，也不要随意加入依赖 shader 的 `MultiEffect/DropShadow`。

## 使用

1. 启动客户端。
2. Broker 默认填写 `192.168.12.1`，端口固定为 `3333`；Client ID 默认 `0x0101`。
3. 点击“确认身份并进入”。登录层立即关闭，不等待 MQTT 连接完成。
4. 通过顶部状态判断 MQTT 是否连通，通过“视觉遥测”判断 HNU-TLM 是否持续到达。
5. 只有进入 DEPLOY 后再执行 trim 操作。

## 本地联调服务器

`hero_test_server` 只用于完整验证当前两个 topic，提供最小 MQTT 3.1.1 Broker、10Hz HNU-TLM、HNU-VID 测试视频、命令检查、序号防重放、trim 限频/限幅，以及 heartbeat 超过 2s 后自动清零。它不是比赛服务器，不能用于正式部署。

构建与启动：

```bash
cmake -S hero_test_server -B build-hero-test
cmake --build build-hero-test -j
./build-hero-test/HeroProtocolTestServer
```

同机联调时将客户端 Broker 改为 `127.0.0.1`；跨设备时填写服务器所在电脑的局域网地址，并允许 TCP 3333。

建议按以下顺序验收：

1. MQTT 连接成功，并订阅 `CustomByteBlock`。
2. HNU-TLM 持续刷新，模式为 DEPLOY，数据字段显示合理。
3. HNU-VID 测试画面持续解码。
4. 点击上调/下调，服务器收到 30B `CustomControl`，回传 trim 随后改变。
5. 按 Enter，回传 trim 回到 0。
6. 先调成非零，再停止客户端 heartbeat；超过 2s 后服务器日志应显示自动清零，重连后回传值为 0。

## 常见排查

- **按键没有改变 trim**：依次检查 MQTT、视觉遥测、DEPLOY 模式、0.2s 限频、视觉 trim 限幅和安全链。
- **命令已发布但数值没变化**：最终结果以车端回传为准，视觉侧可能因 RK45、雷达、核心或状态机条件拒绝该命令。
- **等待视频**：检查 `CustomByteBlock` 中是否持续收到 magic `0x5A`、type `0x02`，以及分片的 frame/slice/seq 是否连续。
- **Qt6 找不到**：在 Qt Creator 选择正确 Kit，或显式传入 `CMAKE_PREFIX_PATH/Qt6_DIR`。
- **全屏黑屏**：确认 `main.cpp` 仍在创建 `QGuiApplication` 后、加载 QML 前调用 `QQuickWindow::setGraphicsApi(QSGRendererInterface::Software)`。

## 图标资源

HUD 的 target、gauge、shield-check、adjustments 图标采用 Tabler Icons 的 24×24 线框风格并随项目本地打包。Tabler Icons 使用 MIT License，许可证副本位于 `qml/icons/LICENSE.tabler-icons.txt`。窗口控制与准星继续复用原客户端 qrc 资源，避免运行时依赖网络。
