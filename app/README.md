# 应用程序核心、策略与综合服务 (app)

## 目录定位与插件角色
`app/` 目录是客户端的主应用程序容器与业务中枢，包含界面主窗口、各子系统协调服务（`ServiceHub`）以及核心操作员策略插件：
- **真实插件 ID**：**`policy.operator`**（角色：`role: "policy"`，实现 `ExtensionPlugin` 接口，元数据位于 `src/operator-policy.json`）。
- **目录角色属性**：**本目录主体为宿主应用程序（Host Application）而非独立可加载插件包**，内置提供了针对操作员输入、飞镖激活、装配任务与通用控制的权限防线（`OperatorActions`）。


## 依赖与可选服务启用条件
- **基础环境依赖**：Qt 6 Quick / GUI / Network 原生框架。
- **核心端点与重启约束**：原生核心端点（`--policy-plugin=policy.operator` 等）随启动配置加载，更换核心插件必须重启客户端。
- **可选服务与阶段锁控制**：
  系统集成的外部可选服务（决策建议 `decision`、语音播报 `speech`、实验室桥接 `bridge`）默认关闭，受比赛准备阶段锁与 `ServiceHub` 严格审查：
  - 按 `Ctrl+Shift+E` 打开「插件管理」面板，可在可视化界面中查看并启停可选服务；
  - **特别注意：在界面启用对象仅代表本地配置装配就绪，绝不等于后端真实连接成功**；
  - 阶段锁限制管理页的配置变更与启停；不能据此推断所有已启用服务在阶段切换时都会被自动关闭。

## 视觉与专用子系统特别说明
- **YOLO 目标检测与吊射运动拖影**：默认保持关闭。可在「插件管理」面板填入视觉配置 JSON 后点击对应行显式启用。
- **进程与模型共用机制**：YOLO 目标检测与吊射运动拖影**共用同一个 `battlefield` 背景计算进程**。对任一功能进行启停操作，都会导致整个后台进程重启、清空全部旧历史观测，且本地模型权重会被重新加载。
- **模型配置约束**：整机 YOLO 采用 yolo-v5 架构与固定的五类别配置：仅启用 `car` 与 `watcher`（`true`），其余类别（`armor`, `ignore`, `base`）一律固定为 `false`。由于纯视觉检测无法获取权威硬件信号，无阵营编号信息时目标属性一律保持 `unknown`。
- **吊射候选与虚线外推机制**：吊射检测仅基于运动像素拖影与高亮候选区域计算，**绝非稳定的真实弹丸物理分类器，亦不代表物理弹道仿真**；界面渲染的紫色虚线仅代表基于当前图像矢量的 150 ms 短暂几何外推，切勿夸大其预测精度或实时性。
- **本地依赖与权重**：相关 Python 解释器环境与 ONNX 权重文件必须在运行机器上由维护人员自行配置，项目仓库不包含任何权重文件。
- **接收端协同模式**：车端或友方接收端完全可以不开启本地 YOLO，只需配置并连接已授权的通信通道，即可同步查看对端发来的观测快照。

## 语音 (Speech) 与大模型决策 (Decision) 服务约束
- **eSpeak 限制**：`speech.espeak` 插件依赖系统安装的可执行程序（`espeak-ng`），仅有系统库文件无法运行。**本机当前尚未安装该可执行程序，不得声称已成功播出**。语音语言 `speech-voice` 默认值为 `"cmn"`，音频设备回放 `--speech-play` 默认为 `false`（不输出至声卡）。
- **Piper HTTP 限制**：客户端 `speech.piper-http` 要求运维人员在本地独立启动 HTTP 服务。接口必须支持接收 `POST` JSON `{"text": "...", "voice": "..."}` 并返回标准 WAV 音频流。客户端请求 endpoint 受到安全沙箱限制，**仅允许连接环回地址（loopback，如 127.0.0.1）**；界面勾选启用仅代表本地端点对象实例化完毕。
- **Codex / 模型决策约束**：Codex 决策服务（`decision.codex`）必须通过专用的 `auth_home` 机制引用机器上预先建立的合法认证，严禁自动登录、自动复制凭据，系统会严格校验并拒绝任何未知配置字段或附加命令参数。切换模型提供者时必须手动清理残留的旧 HTTP 字段。大模型所输出的内容**仅作为只读战术建议呈现给操作手，底层机制严禁其自动生成或触发任何比赛控制指令**。

## 配置字段说明
操作员策略与本地偏好设置支持如下字段与规则：

| 配置项 | 来源 | 默认值 | 约束与说明 |
| :--- | :--- | :--- | :--- |
| `dart_operator_authorized` | 策略对象 | `false` | 布尔值，是否确认云台手具备飞镖控制权限 |
| `rune_activation_allowed` | 策略对象 | `false` | 布尔值，是否确认能量机关激活权限与场景 |
| `map_team_mark_allowed` | 策略对象 | `false` | 布尔值，是否允许小地图队伍标记 |
| `sentry_support_allowed` | 策略对象 | `false` | 布尔值，是否允许哨兵辅助；**配置为 true 时必须同时配置 map_team_mark_allowed 为 true** |
| `rune_kind` | 策略对象 | `"small"` | 能量机关类型，仅接受 `"small"` 或 `"large"` |
| `orientation` | UI 偏好 | `0` | 界面方向偏好，取值 0 或 1 |
| `sensitivity` | UI 偏好 | `100` | 鼠标灵敏度，整数范围 25–200 |
| `volume` | UI 偏好 | `80` | 主音量，整数范围 0–100 |
| `ambience` | UI 偏好 | `50` | 环境音量，整数范围 0–100 |
| `windowMode` | UI 偏好 | `0` | 窗口模式，取值 0（窗口）、1（最大化）、2（全屏） |

> [!IMPORTANT]
> `assembly_context`（装配上下文）仅允许在比赛或调试运行中由操作员显式确认并临时注入内存，**绝对禁止作为赛前偏好写入持久化配置文件中**。

### 最小启动配置示例 (profile.json)
```json
{
  "schema": 1,
  "options": {
    "ui-view": "player-2026",
    "policy-plugin": "policy.operator"
  },
  "plugins": {
    "policy": {
      "operator_actions": {
        "dart_operator_authorized": false,
        "rune_activation_allowed": false,
        "map_team_mark_allowed": false,
        "sentry_support_allowed": false,
        "rune_kind": "small"
      }
    }
  }
}
```

## 使用流程与状态验证
1. 启动客户端，界面默认呈现操作员主 HUD 视图（`player-2026`）；
2. 若需调试外部服务，按下 `Ctrl+Shift+E` 打开管理界面，按需配置对应的视觉、语音或模型提供商配置并解锁启用；
3. 状态验证：在连接状态栏查看各通道指示灯。遥测与视频数据能在不依赖任何可选插件的情况下独立平稳运行（标准 MQTT、UDP 与 QML 界面保持解耦）。

## 停用、缺失与异常排错
- **可选插件缺失时的系统鲁棒性**：当 YOLO、eSpeak、Piper 或大模型决策服务未配置或缺失时，系统的标准 MQTT 遥测上报、UDP 视频解码及 QML 基础界面不受任何影响，继续正常履行比赛操作职能。
- **常见报错与阻止原因**：
  1. `哨兵云台手须同时明确配置地图云台手权限`：策略配置中开启了 `sentry_support_allowed` 但未将 `map_team_mark_allowed` 设为 `true`；
  2. `装配上下文只能在运行中确认，不能作为赛前偏好保存`：在持久化 UI 设置文件中手工写入了 `assembly_context` 字段；
  3. `连接目标正在切换，指令未发送`：通信后端正在切换目标机器人或重连 MQTT，操作指令被会话守卫直接丢弃。

## 配置文档交付约定
本说明随源码与分发物交付。若制作 `rmplugin.json` 扩展包，将 `README.md` 列入 `robomaster_package_extension(... FILES ...)`。现有清单不新增 `documentation` 键；缺少说明的旧包仍可加载。统一要求见项目技术手册第 8 章。
