# 兼容型队伍共享聚合插件 (extensions/team-legacy)

## 插件清单与架构定位
本目录提供一套可选且经过身份认证的队内聚合服务原生插件：
- `team.aggregate.v2`：依据 Schema 2 规范处理队内数据汇总与分发，角色定义为 `aggregation`。

本插件为可选扩展模块，不是参赛必须的官方选手端协议。它与官方裁判系统 MQTT 和视频链路使用独立逻辑通道，仅用于特定队伍内部各节点间进行互信遥测共享。

## 依赖与启用条件
1. **运行依赖**：
   - 需要通过 mTLS 建立独立的队伍内部传输通道（端点协议固定为 `mqtts://`），严禁包含账号密码明文或查询路径。
   - 签名私钥必须通过环境变量传入文件路径，禁止直接将私钥内容或明文路径写入静态配置。
2. **启用入口**：
   - 本地端点必须通过启动配置或在准备阶段通过界面操作显式开启。
   - 启用插件实例仅建立本地数据结构和上下文，后端 MQTT 连接建立及对端数据校验需等待网络就绪与双向证书握手通过。

## 配置字段说明
普通2026客户端通过「服务与插件 → 队伍整合配置」填写，采用下列宿主字段；原生宿主会转换为插件内部的 snake_case 参数，二者不能混用。

| 字段 | 默认值 | 用途与约束 |
|---|---|---|
| `networkEnabled` | `false` | 全部必要身份、证书和授权完整后才启用 |
| `teamId`, `nodeId`, `matchId`, `epoch`, `configurationRevision` | 空 | 队伍、节点、比赛、轮次及配置版本，限64位ASCII字母、数字、点、横线、下划线 |
| `endpoint` | `mqtts://127.0.0.1:8883` | 显式mTLS端点；无账号、路径、查询串或片段 |
| `caFile`, `certificateFile` | 空 | 合法CA和本机公钥证书文件 |
| `signingKeyFileEnv` | `ROBOMASTER_NODE_SIGNING_KEY_FILE` | 保存私钥文件路径的环境变量名；不填路径值或密钥内容 |
| `heartbeatMs`, `timeoutMs` | `"1000"`, `"3000"` | 字符串整数；心跳500–5000ms，超时1500–30000ms且至少三次心跳 |
| `maxClockSkewMs`, `clocksSynchronized` | `"250"`, `false` | 时差0–1000ms；启用前必须如实确认时钟同步 |
| `publisherId`, `canSend`, `canAggregate` | 空、`false`、`false` | 指定汇总者及本机发送、聚合权限 |
| `peers` | `[]` | 固定可信对端及证书指纹，最多15个其他节点 |
| `permissions` | 各类别空对象 | `health/resources/position/objective/advice/sensorEvents/visionDiscoveries/derived`按用途显式授权；未授权项省略 |
| `teamWideSharingConfirmed` | `false` | 启用前明确确认全队共享边界 |
| `displayName`, `voiceNodeId`, `voiceOutputGroup`, `voiceOutputNodeId` | 空 | 节点显示名及可选播报输出选择 |
| `selfListen` | `false` | 是否监听本机输出 |

## 最小配置与使用示例

无可用证书或可信对端时保持 `networkEnabled: false`，普通MQTT与UDP照常运行。需要队内共享时，在原生配置页依次填完整身份、端点、CA/本机证书、私钥路径环境变量名和对端证书指纹，再按类别授予用途，确认时钟与全队共享后保存并显式启用。界面由完整默认配置生成，不能把只含几个键的JSON片段当作可运行配置。

只读显示通常只授予所需的 `hud`/`alerts` 用途；`localAi`、`externalAi`、`voice` 均须另行授权。操作员并不会因启用网络自动获得其他节点权限。

**使用与状态判断**：
1. 启动后，检查状态对象的 `connected` 是否为 `true`，`submissions_accepted` 计数是否正常递增。
2. 若作为汇总节点（`node_id == publisher_id`），确认本地生成带有签名证明的 `team-view` 周期切片。

## 停用、缺失与异常处理
- **权限未授予**：若 `can_send` 未启用而尝试推送数据，提交会被拒绝并提示「本节点未获共享发送权限」。
- **时钟与超时**：时钟漂移超过 `max_clock_skew_ms` 或消息到达延迟大于 `timeout_ms` 时，对端数据被标记为失效并自动丢弃，不计入视图。
- **网络中断**：连接丢失后，已接收的项目随着 `remaining_ms` 归零逐步转为 `withdrawn` 状态，不影响官方链路运行。

关于本插件数据契约细节与权限判定流，请参阅 [TECHNICAL.md](../../docs/TECHNICAL.md)。

## 配置文档交付约定
本说明随源码与分发物交付。若制作 `rmplugin.json` 扩展包，将 `README.md` 列入 `robomaster_package_extension(... FILES ...)`。现有清单不新增 `documentation` 键；缺少说明的旧包仍可加载。统一要求见项目技术手册第 8 章。
