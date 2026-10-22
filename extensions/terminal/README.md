# 专用终端数据链路插件 (extensions/terminal)

## 插件清单与架构定位
本目录提供轻量级专用终端通信链路插件，实现底层 `ExtensionPlugin` 接口，角色定义为 `terminal-link`：
- `terminal.link.loopback.v1`：基于内存受限队列的回环链路，不涉及任何官方协议与动作指令。
- `terminal.link.mqtt.v1`：显式指定的 MQTT 原始字节流传输链路，无官方协议包装与来源认证。
- `terminal.link.udp.v1`：显式点对点 UDP 原始数据报传输链路，无视频分包与官方协议逻辑。

这些插件由专用终端壳层的 `TerminalGateway` 装配，提供原始数据管道，不承担官方协议的编解码。普通2026选手端的MQTT与视频不使用它们；加载2027场地模型也不会自动切换到此终端链路。

## 依赖与启用条件
1. **运行环境**：
   - `terminal.link.mqtt.v1` 依赖可连通的 MQTT Broker。
   - `terminal.link.udp.v1` 需要系统开放指定的本地 UDP 端口及单播网络路由。
   - `terminal.link.loopback.v1` 无网络依赖。
2. **启用入口**：
   - 在专用终端壳层的链路配置页选择提供者；普通2026服务管理页不提供这些链路的启停入口。
   - 由 `TerminalGateway` 传入当前原生上下文及所选链路参数。启用对象仅代表本地初始化完成，不代表远端网络已通。

## 配置字段说明
配置通过 JSON 对象配置，禁止未知字段；三种链路均要求 `schema: 1` 及 `context`，后者严格包含当前宿主的 `profile_id`、`field_profile_id`、`capability_revision`，不得自行拼接版本。原始链路本身不提供队伍来源认证：

### 1. terminal.link.mqtt.v1 配置字段
| 字段名 | 类型 | 约束说明 |
| :--- | :--- | :--- |
| `host` | 字符串 | MQTT 服务器主机名或 IP，长度不超过 253，严禁空格及特殊符号 |
| `port` | 整数 | 服务端口号（1–65535） |
| `client_id` | 字符串 | 客户端标识符，受限字符，最长 96 位 |
| `receive_topics` | 字符串列表 | 明确允许接收的静态 Topic 列表，不支持通配符 |
| `send_topics` | 字符串列表 | 明确允许发送的静态 Topic 列表，不支持通配符 |

### 2. terminal.link.udp.v1 配置字段
| 字段名 | 类型 | 约束说明 |
| :--- | :--- | :--- |
| `bind_address` | 字符串 | 本地监听 IP 地址，允许本地通配绑定，禁止组播或广播地址 |
| `bind_port` | 整数 | 本地绑定端口（0–65535，0 表示随机可用端口） |
| `peer_address` | 字符串 | 目标对端 IP 地址，必须为明确单播地址，禁止 Any/全网广播/组播 |
| `peer_port` | 整数 | 目标对端端口（1–65535） |

### 3. terminal.link.loopback.v1 配置字段
无独立配置字段，仅需声明公共环境上下文 `context` 与 `schema: 1`。

## 最小配置与使用示例
以下是宿主开发者构造 UDP 服务参数的 C++ 示例；`currentHostContext` 必须取自当前原生宿主，不能作为独立启动 Profile 直接粘贴：

```cpp
QVariantMap config{{"schema", 1}, {"context", currentHostContext},
    {"bind_address", "127.0.0.1"}, {"bind_port", 9000},
    {"peer_address", "127.0.0.1"}, {"peer_port", 9001}};
```

普通操作员通过终端链路配置页填写地址与主题白名单。MQTT发送与接收主题不得重叠，避免自回环。

**使用与状态判断**：
在网关（TerminalGateway）状态中，若处于连接状态，通道显示为 `local`（回环）、`peer`（UDP）或发送主题名（MQTT）。链路收发统计计数递增且无报错记录即代表运行正常。

## 停用、缺失与异常处理
- **地址非法**：配置中填入广播地址（如 `255.255.255.255`）或 MQTT 主机名含无效控制字符时，配置直接报错拒绝生效。
- **网络中断**：MQTT 断线会自动触发重连状态；UDP 链路若对端不可达，不阻断主程序其他操作。
- **插件缺失**：若配置了第三方未注册包，网关回退至未就绪状态并保留已保存的配置摘要，不破坏其他原生功能。

关于网关契约与底层通道流转，请参考 [TECHNICAL.md](../../docs/TECHNICAL.md)。

## 配置文档交付约定
本说明随源码与分发物交付。若制作 `rmplugin.json` 扩展包，将 `README.md` 列入 `robomaster_package_extension(... FILES ...)`。现有清单不新增 `documentation` 键；缺少说明的旧包仍可加载。统一要求见项目技术手册第 8 章。
