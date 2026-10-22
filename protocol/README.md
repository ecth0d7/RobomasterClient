# RoboMaster 比赛协议编解码插件 (protocol)

## 插件定位与接口角色
`protocol/` 目录包含系统通信协议编解码实现，提供两个真实插件 ID：
1. **`protocol.rm2026.v2`**：RoboMaster 2026 V2.0.0 正式协议插件，实现 Protobuf 消息序列化、反序列化及字段合法性校验，角色为 `role: "protocol"`。
2. **`protocol.terminal.local.v1`**：项目本地观测 JSON 适配器（非官方协议）。**该插件仅作为缺失字段的可选本地补充调试工具，绝不冒充官方比赛协议，亦不具备下发机器人控制指令的权限**（`robotCommands: false`, `officialProtocol: false`）。


## 依赖与启用条件
- **依赖项**：Google Protocol Buffers 运行时及根据官方 .proto 文件生成的编解码结构体。
- **启用入口**：客户端启动配置选项 `--protocol-plugin=protocol.rm2026.v2`。该端点为原生核心端点，**随启动配置加载，运行期更换需重启程序**。

## 配置字段说明
协议插件在客户端命令行中配置对应插件标识：

| 配置项 | CLI 选项 | 默认值 | 约束与说明 |
| :--- | :--- | :--- | :--- |
| `protocol-plugin` | `--protocol-plugin` | `protocol.rm2026.v2` | 指定加载的协议插件 ID，可选 `protocol.rm2026.v2` 或 `protocol.terminal.local.v1` |

### 最小配置命令
使用官方 2026 协议启动：
```bash
./RoboMasterMqttTest --protocol-plugin=protocol.rm2026.v2
```
切换至本地观测测试协议（用于项目本地观测，不用于连接官方选手端）：
```bash
./RoboMasterMqttTest --protocol-plugin=protocol.terminal.local.v1
```

## 使用与判断成功
- **成功判断**：连接 MQTT 服务后，遥测状态簿（TelemetryStore）能正确解析出各数据分组（如 `robotDynamic`、`robotStatic` 等），并且修订版本号（revision）随入站消息递增。

## 停用、缺失与限制
- **异常阻断**：当选定不受支持或损坏的协议插件时，客户端在初始化阶段直接报错退出，防止向赛场网络发送畸形字节流。
- **权限安全限制**：若激活 `protocol.terminal.local.v1`，底层强制屏蔽一切载具遥控指令生成（`allowed = false`），杜绝本地调试数据干扰赛事实体。

## 配置文档交付约定
本说明随源码与分发物交付。若制作 `rmplugin.json` 扩展包，将 `README.md` 列入 `robomaster_package_extension(... FILES ...)`。现有清单不新增 `documentation` 键；缺少说明的旧包仍可加载。统一要求见项目技术手册第 8 章。
