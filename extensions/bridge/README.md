# 实验室 TCP 桥接插件 (extensions/bridge)

## 插件概述与角色定位
本目录包含用于实验室仿真环境的 TCP 遥测与数据桥接插件。

- **插件 ID**：`bridge.tcp`
- **接口契约**：实现 `ExtensionPlugin` 接口，角色定义为 `bridge`。
- **独立性说明**：属于可选原生 C++ 服务插件，由客户端动态库加载器直接加载。不可作为独立的外部应用执行。

## 依赖与启用条件
- **规则依赖**：强制要求开启实验室模式（`laboratory: true` 或启动参数 `--lab-bridge`）。该插件与官方比赛通信通道独立。
- **环境与认证**：必须通过环境变量提供共享认证 Token，不接受明文凭据。

## 启动入口与命令行选项
- **UI 入口**：`Ctrl+Shift+E` / 插件管理，或者在启动 Profile 中指定 `bridge` 插件角色配置。
- **CLI 参数**：
  - `--lab-bridge`：显式开启实验室桥接（`--no-lab-bridge` 可关闭）。
  - `--bridge-plugin=bridge.tcp`：指定使用本插件 ID。
  - `--bridge-bind=127.0.0.1`：监听绑定的本地 IP 地址。
  - `--bridge-port=8888`：监听端口号（设为 0 时自动挑选可用端口）。
  - `--bridge-peer=tcp://host:port`：上游远端对端地址。
  - `--bridge-token-env=ROBOMASTER_BRIDGE_TOKEN`：指定包含认证 Token 的环境变量名。
- **更换机制**：在准备阶段先停用服务，再保存匹配的桥接配置并显式启用；其它核心端点无需一并更换。

## 配置字段与约束
Profile 中的 `plugins.bridge` 或宿主校验字段如下：

| 字段名 | 类型 | 默认值 | 约束说明 |
| :--- | :--- | :--- | :--- |
| `provider_kind` | string | `"tcp"` | 目前限定为 `"tcp"` 或受保护的 `"package"` |
| `provider_options` | object | `{}` | 当 `provider_kind` 为 `"tcp"` 时，此对象必须为空，拒绝附加参数 |
| `bind` | string | `"127.0.0.1"` | 绑定的本地有效 IPv4/IPv6 文本地址，长度 ≤ 256 |
| `listen` | boolean | `true` | 是否监听本地端口 |
| `listen_port` | integer | `8888` | 监听端口 (0–65535) |
| `peer` | string | `""` | 对端地址，格式必须为严格的 `tcp://host:port`，严禁包含路径、查询或用户信息 |
| `token_env` | string | `"ROBOMASTER_BRIDGE_TOKEN"` | 凭据环境变量名（匹配正则 `^[A-Za-z_][A-Za-z0-9_]{0,95}$`） |
| `export_snapshots`| boolean | `false` | 是否导出当前态势快照 |
| `export_events` | boolean | `false` | 是否导出遥测事件流 |

> 约束：配置中必须保证 `listen == true` 或 `peer` 包含有效地址，至少启用监听或指定实际对端其一。

### 最小配置示例 (Profile plugins 片段)
```json
{
  "schema": 1,
  "options": {
    "lab-bridge": true,
    "bridge-plugin": "bridge.tcp",
    "bridge-bind": "127.0.0.1",
    "bridge-port": 8888,
    "bridge-token-env": "ROBOMASTER_BRIDGE_TOKEN"
  },
  "plugins": {
    "bridge": {
      "provider_kind": "tcp",
      "provider_options": {},
      "bind": "127.0.0.1",
      "listen": true,
      "listen_port": 8888,
      "peer": "",
      "token_env": "ROBOMASTER_BRIDGE_TOKEN",
      "export_snapshots": false,
      "export_events": false
    }
  }
}
```

## 使用验证与断连处理
1. 启动前设置环境变量：`export ROBOMASTER_BRIDGE_TOKEN="替换为本机专用随机凭据"`。
2. 启动客户端后，若监听成功，`TcpBridge` 将在绑定的端口接收对端连接；若是主动连接对端，则会异步尝试建立 TCP 握手并鉴权。
3. **断连处理**：若网络中断或 Token 验证不通过，连接被挂起或主动丢弃，缓冲数据被清空，重连机制遵循非阻塞异步调度，不会阻塞主控制回路。

## 常见限制与报错
- 若配置中携带直接的明文 `token` 字段或包含未知的命令行参数，校验将直接拒绝（报错：`实验室桥只接受明确提供者、公共地址和导出开关；不接受token值／附加命令`）。
- 详细协议规范参考 [TECHNICAL.md](../../docs/TECHNICAL.md)。

## 配置文档交付约定
本说明随源码与分发物交付。若制作 `rmplugin.json` 扩展包，将 `README.md` 列入 `robomaster_package_extension(... FILES ...)`。现有清单不新增 `documentation` 键；缺少说明的旧包仍可加载。统一要求见项目技术手册第 8 章。
