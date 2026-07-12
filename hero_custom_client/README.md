# HNU 英雄机器人自定义客户端

这是一个独立于仓库原客户端的 Qt/QML 应用，只实现英雄副屏当前需要的两个 MQTT topic：

- 订阅 `CustomByteBlock`：解析 HNU-TLM 46B 遥测和 HNU-VID H.264 分片。
- 发布 `CustomControl`：发送固定 30B 的 trim step、trim reset 和 1Hz heartbeat。

客户端不解析比赛全局信息，不发送键鼠数据，也不参与 SEASKY `0x0001/0x0002`。最终发射安全裁决仍属于视觉安全链和电控。

## 构建

在 Qt Creator 中直接打开本目录的 `CMakeLists.txt`，或执行：

```bash
cmake -S hero_custom_client -B build-hero -DCMAKE_PREFIX_PATH=/path/to/Qt/6.x/gcc_64
cmake --build build-hero -j
```

## UI 内容

- MQTT 与视觉遥测在线状态。
- HNU-VID 落点观察视频。
- DEPLOY/RK45、安全条件、距离、高度、弹速、TOF 和误差遥测。
- 以车端 HNU-TLM 回传为真值的 pitch trim。
- `-4/-2/-1/+1/+2/+4` 步进和清零控制。
- 每客户端独立持久化的命令序号。

## Pitch Trim 操作

每一步对应 `0.05°`，可以使用界面按钮或键盘快捷键操作：

| 操作 | 向上微调 | 向下微调 |
|---|---:|---:|
| 普通方向键 | `↑`：`+1` 步 | `↓`：`-1` 步 |
| Shift + 方向键 | `Shift+↑`：`+2` 步 | `Shift+↓`：`-2` 步 |
| Ctrl + 方向键 | `Ctrl+↑`：`+4` 步 | `Ctrl+↓`：`-4` 步 |
| 鼠标按钮 | `+1/+2/+4` | `-1/-2/-4` |

点击“清零 Pitch Trim”会发送 `trim_reset`。客户端连接 MQTT 后还会自动每秒发送一次 heartbeat。

### UI 操作反馈

- 鼠标按下时，按钮会缩放并变色。
- 键盘操作会高亮对应的步进按钮。
- 上调显示 `▲` 动画，下调显示 `▼` 动画。
- 命令满足发送条件时显示绿色反馈。
- 命令被客户端安全条件阻止时显示红色反馈，并显示具体原因。
- UI 当前 trim 数值只使用 HNU-TLM 中机器人回传的 `pitch_trim_deg`，不会把本地按键累计值当作真实值。
- 本地期望值与机器人回传值不一致时，界面会显示红色提示。

### Trim 安全条件

客户端不会通过 trim 操作绕过视觉或电控安全条件：

- 只有 HNU-TLM 报告 `mode == 4`（DEPLOY）时才发送 `trim_step`。
- MQTT 未连接时不发送命令。
- 两次成功步进之间至少间隔 `0.2s`。
- 单条命令参数限制为 `[-4,+4]`，且不能为 `0`。
- RK45 解算失败、雷达过期、核心丢失或状态机未就绪时，是否接受 trim 仍由视觉侧裁决。
- 最终是否发弹仍由电控的热量、弹速和发射机构安全门控裁决。

按钮在 MQTT 未连接或 `0.2s` 冷却期间会暂时禁用。非 DEPLOY 模式下按钮仍可点击以显示原因，但客户端不会发送 `trim_step`。

## 状态排查

如果按键后回传 trim 没有变化，请依次检查：

1. 顶部 MQTT 状态是否为“已连接”。
2. 视觉遥测是否在线。
3. 当前模式是否为 `DEPLOY`。
4. 是否触发了 `0.2s` 操作限频。
5. 是否已经到达视觉侧 trim 限幅。
6. RK45、雷达、核心检测和状态机安全条件是否满足。

命令即使被视觉侧拒绝也会消耗并持久化序号，客户端不会使用相同序号重发。最终显示应始终以 HNU-TLM 回传为准。

## 本地联调测试服务器

`test_server` 提供了一个仅用于联调的最小服务器。它同时实现：

- 监听 `0.0.0.0:3333` 的最小 MQTT 3.1.1 Broker。
- `CONNECT/CONNACK`、`SUBSCRIBE/SUBACK`、QoS 1 `PUBLISH/PUBACK` 和心跳响应。
- 10Hz HNU-TLM 模拟遥测，默认处于 DEPLOY 模式。
- `core_ok`、`radar_fresh`、`deploy_solved`、`yaw_converged` 和 `fire_allowed` 模拟状态。
- 实时生成的 H.264 彩色测试视频，并按 HNU-VID 规则分片。
- HNU-CMD 长度、magic 和 CRC16 检查。
- 命令序号防重放检查。
- `trim_step`、`trim_reset` 和 heartbeat 处理。
- `trim_step` 的 0.2 秒限频与 `[-1.0,+1.0]°` 限幅。
- heartbeat 超过 2 秒后的 trim 自动清零。

它不实现比赛服务器、裁判系统或其他 MQTT topic，不能作为正式比赛服务器使用。

### 构建测试服务器

```bash
cmake -S hero_custom_client/test_server \
      -B hero_custom_client/test_server/build
cmake --build hero_custom_client/test_server/build -j
```

### 启动测试服务器

```bash
./hero_custom_client/test_server/build/HeroProtocolTestServer
```

正常启动后会显示：

```text
英雄协议测试服务器监听 "0.0.0.0" 3333
模拟状态: DEPLOY, RK45 SUCCESS, fire_allowed=true
连接客户端后自动发布 HNU-TLM 10Hz 与 HNU-VID 5fps
```

如果客户端和测试服务器在同一台电脑，将客户端 Broker 地址填写为 `127.0.0.1`。如果在不同电脑，填写测试服务器所在电脑的局域网 IP，并确认防火墙允许 TCP 3333。

### 联调顺序

1. 启动测试服务器，再启动 `HeroCustomClient`。
2. 客户端连接 `127.0.0.1:3333`，顶部 MQTT 状态应变为“已连接”。
3. 服务器终端应打印 `已订阅 CustomByteBlock`。
4. 客户端视觉遥测状态应变为在线，并持续显示 DEPLOY、距离、高度、弹速、TOF 和 trim。
5. 视频区域应显示持续变化的 H.264 彩色测试画面。
6. 点击 `+1/+2/+4`，服务器应打印 `trim_step`，客户端回传 trim 随后增加。
7. 点击清零，服务器应打印 `trim_reset`，客户端回传 trim 回到 `0.00°`。
8. 先把 trim 调成非零，再点击“暂停 Heartbeat（仅联调）”。MQTT 和 HNU-TLM 订阅会继续保持；超过 2 秒后，服务器打印自动清零日志，客户端 `pitch_trim_deg` 应回到 `0.00°`。
9. 点击“恢复 Heartbeat”后，客户端会立即发送一次 heartbeat，并恢复 1Hz 定时发送。

### 无界面自动测试

客户端还提供仅供联调使用的环境变量入口：

```bash
QT_QPA_PLATFORM=offscreen \
HERO_TEST_AUTOCONNECT=1 \
HERO_TEST_HOST=127.0.0.1 \
timeout 7s ./hero_custom_client/build/HeroCustomClient
```

自动测试会依次连接、发送 `trim_step +2`、发送 reset、发送 `trim_step +1`，然后仅暂停 heartbeat，保持 MQTT 和遥测订阅。服务器终端应能看到完整命令以及 2 秒超时自动清零日志，客户端仍能收到 trim 回到 0 的 HNU-TLM。

“暂停 Heartbeat”按钮仅用于本地协议联调。正式比赛运行时应保持 heartbeat 开启。
