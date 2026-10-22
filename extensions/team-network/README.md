# 队伍网络传输协议与证书管理模块 (extensions/team-network)

## 模块定位与接口属性
本目录为**底层基础宿主库与网络传输层实现**，不向系统注册直接由界面独立启动的插件 ID（无 `ExtensionPlugin` 元数据）。它为 `extensions/team-legacy` 和 `extensions/terminal-team` 提供统一的 mTLS 双向认证通道、凭据加载和网络心跳维护服务。

## 依赖与启用条件
1. **依赖环境**：依赖底层 Qt 网络库与系统 OpenSSL 加密套件，支持 TLS 双向认证。
2. **凭据约束**：
   - 需要合法的 CA 根证书文件（`ca_file`）、客户端证书文件（`certificate_file`）。
   - 签名私钥文件必须通过安全环境变量解出，不允许在配置文件中出现裸私钥内容。
3. **启用方式**：由上层队伍聚合服务在启动阶段按需初始化，普通参赛运行或只使用官方 MQTT 时该网络层保持休眠。

## 配置字段说明
网络层配置由上层服务转换为内部凭据参数，支持的严格字段包括：

| 字段名 | 类型 | 默认值 | 约束说明 |
| :--- | :--- | :--- | :--- |
| `contract_version` | 整数 | `2` | 协议契约版本号，仅支持 `2` 或 `3` |
| `endpoint` | 字符串 | 无 | 队伍端点地址，格式必须为 `mqtts://host:port`，严禁路径或查询串 |
| `team_id` | 字符串 | 无 | 队伍标识（ASCII 字符串） |
| `node_id` | 字符串 | 无 | 节点唯一标识 |
| `match_id` | 字符串 | 无 | 比赛场次 ID |
| `epoch` | 字符串 | 无 | 轮次标识纪元 |
| `session_id` | 字符串 | 无 | 当前网络会话 UUID |
| `robot_id` | 整数 | 无 | 契约版本为 2 时的机器人数值编号（0–4294967295） |
| `robot_key` | 字符串 | 无 | 契约版本为 3 时的语义机器人标识（如 `red/infantry/1`） |
| `ca_file` | 字符串 | 无 | CA 证书文件路径 |
| `certificate_file` | 字符串 | 无 | 本机客户端公钥证书文件路径 |
| `signing_key_file` | 字符串 | 无 | 由环境变量解析后的本地私钥路径 |
| `can_send` | 布尔 | `false` | 发送使能开关 |
| `can_aggregate` | 布尔 | `false` | 聚合使能开关 |
| `heartbeat_ms` | 整数 | `1000` | 心跳间隔（250–10000 毫秒） |
| `timeout_ms` | 整数 | `3000` | 连接超时（750–60000 毫秒），必须大于等于 3 倍心跳 |
| `peers` | 数组 | `[]` | 固定绑定的队伍成员节点列表，总成员数不超过 16（对端 ≤ 15） |

## 最小配置与使用说明
此模块没有可单独运行的启动配置，也不应把内部 `signing_key_file` 路径复制到操作员配置。普通2026客户端在「队伍整合配置」页使用 `networkEnabled`、`teamId`、`nodeId`、`endpoint`、`caFile`、`certificateFile`、`signingKeyFileEnv`、`heartbeatMs`、`timeoutMs` 等宿主字段；宿主检查权限、解析密钥路径环境变量，再转换为上表内部参数。完整前置条件见 [team-legacy配置说明](../team-legacy/README.md)。专用终端使用其自己的原生队伍配置页，不共用普通客户端配置结构。

**状态判断**：
上层模块调用 `m_network->details()` 获取实时运行状态。若 `connected: true` 说明 TLS 握手与 MQTT 订阅建立完毕；若处于重连状态，内部维持有限重试，绝不干扰官方通信。

## 常见限制与异常
- **端点不规范**：若包含 `http://`、非 `mqtts://` 协议头或附带 URL Path，配置直接校验失败。
- **证书过期或不匹配**：TLS 握手报错退出，网络层维持离线状态并记录内部错误，不上报未验证包。
- **时钟超差**：各节点接收包严格校验网络延迟与时间戳，一旦超时直接丢弃。

关于本传输层实现的整体上下文与交互契约，请参考 [TECHNICAL.md](../../docs/TECHNICAL.md)。

## 配置文档交付约定
本说明随源码与分发物交付。若制作 `rmplugin.json` 扩展包，将 `README.md` 列入 `robomaster_package_extension(... FILES ...)`。现有清单不新增 `documentation` 键；缺少说明的旧包仍可加载。统一要求见项目技术手册第 8 章。
