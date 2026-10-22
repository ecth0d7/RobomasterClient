# 态势运行环境插件 (extensions/battlefield)

## 插件概述与角色定位
本目录提供 RoboMaster 2026 态势运行环境宿主插件。该插件在 Qt 客户端中作为原生扩展加载，用于生命周期管理与异步数据分发。

- **插件 ID**：`situation.process.v1`
- **接口契约**：实现 `ExtensionPlugin` 接口，角色定义为 `battlefield`（遵循 `rm.situation.config/1`、`rm.situation/1`、`rm.situation.view/1`、`rm.situation.fused/1` 契约）。
- **独立性说明**：本模块为**宿主插件与独立 Python 运行时进程（`battlefield`）的结合体**。按显式配置启动时加载宿主端点，具体的目标检测、融合与通信均运行在独立的 Python 子进程中。该目录不是单一的即插即用 QML 插件包，不可脱离宿主或在无 Python 环境下独立运行。

## 依赖与启用条件
- **依赖项**：
  - 系统环境：Python 3.10+ 标准库（含 `sqlite3`），无需另外运行数据库服务。
  - 视觉检测依赖：`numpy`、`opencv-python-headless`、`onnxruntime`（需在机器上另行配置，仓库不自带权重）。
  - 语音模块依赖：`libespeak-ng`（含数据包）及音频播放工具 `paplay`。
- **启用条件**：
  - 默认情况下视觉 (`vision`) 和吊射 (`projectile`) 处于关闭状态。
  - 必须显式确认 `display_only_confirmed: true`，本插件仅用于显示与组网同步，严禁产生比赛控制指令。

## 启动入口与生命周期
- **UI 入口**：快捷键 `Ctrl+Shift+E` 进入“插件管理”界面。
- **启用方式**：复制 `config/default.json` 为本机配置，填写所用Python解释器及功能参数。插件管理中的视觉配置框填写完整JSON文件路径，再点击YOLO或吊射行启用。只接收队友数据时，可按 `Ctrl+Shift+F9` 打开战场态势窗口，填文件路径并点击「加载并启动」，保持 `vision.enabled: false`。共享态势宿主行本身不单独启停。
- **生命周期机制**：协调器管理共享与融合，YOLO、吊射分别运行在独立图像进程中。仅变更 `vision`、`projectile`、`share_vision` 时可独立应用，保留队内会话和另一计算任务，出站序号继续递增。公共配置改变仍重启协调器。接收端可以关闭 YOLO，只配置并授权 `team` 通信。
- **独立性边界**：模型／语音 Python 实现分别位于 `decision/runtime`、`speech/runtime`，通过懒加载与普通异常捕获局部停用，其调度仍与协调器同进程。图像进程具有崩溃隔离但没有硬资源或同用户文件权限隔离，详见[架构与验收](../../docs/TECHNICAL.md#plugin-isolation)。

## 配置字段与约束
配置文件遵循 `rm.situation.config/1`，核心字段定义如下：

| 字段路径 | 类型 | 默认值 | 约束与说明 |
| :--- | :--- | :--- | :--- |
| `schema` | string | `"rm.situation.config/1"` | 必须为该固定版本字符串 |
| `python` | string | `"/usr/bin/python3"` | 本机 Python 3 执行路径 |
| `node_id` | string | `"operator-red-1"` | 1..96 字符，允许字母、数字及 `_ . : -` |
| `team_id` | string | `"local-team"` | 队伍标识符 |
| `match_id` | string | `"practice-01"` | 比赛标识符 |
| `frame_id` | string | `"field.2026"` | 坐标系标识符 |
| `display_only_confirmed` | boolean | `true` | 必须显式配置为 `true` 才能启动运行 |
| `share_vision` | boolean | `false` | 是否向组网节点共享本地视觉观测 |
| `share_fused` | boolean | `false` | 是否共享融合态势数据（间隔限流 ≥ 1s） |
| `vision.enabled` | boolean | `false` | 是否启用 YOLO 视觉推理 |
| `vision.model_file` | string | `""` | 本地 ONNX 模型文件路径（本机配置） |
| `vision.format` | string | `"yolo-v5"` | 检测格式，目前使用 `yolo-v5` 五类别配置 |
| `vision.confidence` | double | `0.55` | 检测置信度阈值 (0.0~1.0) |
| `vision.threads` | integer | `2` | ONNX 推理线程数 |
| `vision.labels` | array | 见默认文件 | 五类别映射：`car`与`watcher`的`robot=true`；`armor`、`ignore`、`base`的`robot=false`。无阵营编号时统一保持 `unknown` |
| `team.enabled` | boolean | `false` | 是否启用节点间 UDP 组网同步 |
| `team.bind` | string | `"127.0.0.1"` | 本机监听地址 |
| `team.port` | integer | `45670` | 本机组网端口 (1024–65535) |
| `team.key_env` | string | `"SITUATION_NODE_KEY"` | 节点通信凭据的环境变量名，密钥长度必须 ≥ 32 字节 |
| `model.enabled` | boolean | `false` | 是否启用决策建议模型（可选 rules/openai-compatible） |
| `model.endpoint` | string | `"http://127.0.0.1:11434/v1/chat/completions"`| 仅允许 loopback 协议或在同意外部数据时走 HTTPS |
| `model.key_env` | string | `"SITUATION_MODEL_KEY"`| 模型 API 密钥环境变量名 |

### 最小配置示例 (config/default.json)
```json
{
  "schema": "rm.situation.config/1",
  "python": "/usr/bin/python3",
  "node_id": "operator-red-1",
  "team_id": "local-team",
  "match_id": "practice-01",
  "frame_id": "field.2026",
  "display_only_confirmed": true,
  "share_official": false,
  "share_vision": false,
  "share_fused": false,
  "vision": {
    "enabled": false,
    "model_file": "",
    "format": "yolo-v5",
    "confidence": 0.55,
    "threads": 2,
    "calibration": {
      "acknowledged": false,
      "fixed_camera_confirmed": false,
      "id": "unconfigured",
      "frame_id": "field.2026",
      "anchor": "bbox-bottom-center",
      "homography": [],
      "uncertainty_m": 2.0
    },
    "labels": [
      {"label": "机器人整机", "robot": true, "team": "unknown", "target_id": "unknown"},
      {"label": "装甲板", "robot": false},
      {"label": "忽略区域", "robot": false},
      {"label": "哨兵整机候选", "robot": true, "team": "unknown", "target_id": "unknown"},
      {"label": "基地", "robot": false}
    ]
  }
}
```

## 可选移动视觉与序号历史

`vision.projection` 默认关闭，配置与启用入口见 [视觉插件说明](../yolo-vision/README.md)。位置候选和图像框均沿用现有认证共享链路；接收端可保持 YOLO 关闭。序号水位改由进程私有临时 SQLite 记录，上限 10 万键或 16MiB，先到生效；不遗忘旧序号以换取接收容量。容量与存储失败在本地视图显示，关闭进程清理临时数据库。未进行长时资源对照。

## 使用与状态判断
1. 在插件管理或态势窗口填写合法配置文件路径并启动，宿主将拉起后台 Python 子进程。
2. **成功判定**：客户端插件状态变更为正常运行，日志输出无异常退出，界面接收到心跳包或图层显示态势更新；若开启 YOLO，可在图层中看到对应类别的边界框识别。
3. **失败与断连处理**：若 Python 脚本崩溃或依赖项缺失，宿主会提示状态变更并停止接入，可再次点击启用尝试重新拉起。

## 限制与注意事项
- **精度声明**：YOLO 目标检测使用 yolo-v5 格式五分类，仅提供整机检测及哨兵整机候选；缺乏裁判系统车牌编号信息时，阵营和目标编号一律保持 `unknown`，严禁夸大其实时性与分类置信度。
- **文档链接**：更多技术规范请参阅 [TECHNICAL.md](../../docs/TECHNICAL.md)。

## 配置文档交付约定
本说明随源码与分发物交付。若制作 `rmplugin.json` 扩展包，将 `README.md` 列入 `robomaster_package_extension(... FILES ...)`。现有清单不新增 `documentation` 键；缺少说明的旧包仍可加载。统一要求见项目技术手册第 8 章。
