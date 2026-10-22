# Mosquitto MQTT 传输插件 (mqtt)

## 插件定位与接口角色
`mqtt/` 目录实现基于 libmosquitto 的后台事件循环与网络通信传输。插件导出真实插件 ID 为 **`mqtt.mosquitto`**，实现系统核心原生插件接口 `ClientPlugin`，角色定义为 `role: "mqtt"`。该插件是客户端与赛场数据服务进行双向遥测和控制交互的核心基础，不是宿主辅助库，属于随系统启动加载的原生动态库插件。


## 依赖与启用条件
- **外部依赖**：系统动态链接库 `libmosquitto.so` / 兼容版网络运行时。
- **启用方式**：随客户端启动显式加载，启动参数使用 `--mqtt-plugin=mqtt.mosquitto`（默认值）。
- **启动入口与生命周期**：作为原生核心端点，在客户端启动阶段完成加载与网络线程初始化。**核心端点在客户端运行期间不支持热更换，更换或重新配置必须重启客户端进程**。

## 配置字段说明
MQTT 通信主要由客户端全局启动参数与启动配置 Profile 中的网络字段驱动：

| 参数 / 字段名 | CLI 选项 | 默认值 | 约束与说明 |
| :--- | :--- | :--- | :--- |
| `host` | `--host` | `"127.0.0.1"` | MQTT 服务器 IP 或主机名，去除首尾空白字符 |
| `mqtt-port` | `--mqtt-port` | `3333` | MQTT 服务器网络通信端口，范围 1–65535 |
| `auto-login` | `--auto-login` | `false` | 布尔值，启动时是否自动向服务器建立连接 |
| `robot` | `--robot` | `"3"` | 自动登录的目标机器人编号（红方 1–9，蓝方 101–109） |

### 最小启动配置示例 (profile.json)
```json
{
  "schema": 1,
  "options": {
    "host": "127.0.0.1",
    "mqtt-port": "3333",
    "mqtt-plugin": "mqtt.mosquitto",
    "auto-login": true,
    "robot": "3"
  }
}
```
命令行直接启动命令：
```bash
./RoboMasterMqttTest --host=127.0.0.1 --mqtt-port=3333 --mqtt-plugin=mqtt.mosquitto
```

## 使用与状态判断
- **连接验证**：启动后检查操作终端顶栏，当网络连接图标变为已连接，且控制台收到订阅主题的入站心跳或遥测消息，证明 MQTT 线程正常工作。

## 停用、断连与常见排错
- **断连与重连**：当 MQTT 代理服务重启或网线拔出时，Mosquitto 插件后台线程将按回退时间尝试重连；重连期间 `ClientBackend` 将拦截控制指令，状态显示为「目标正在切换」或「未连接」。
- **常见报错**：
  1. `Cannot open startup profile`：检查 Profile 路径及是否超出 64 KiB 限制；
  2. 连接超时/拒绝：检查本机防火墙设置与 3333 端口状态，核实服务端进程是否处于监听中。

## 配置文档交付约定
本说明随源码与分发物交付。若制作 `rmplugin.json` 扩展包，将 `README.md` 列入 `robomaster_package_extension(... FILES ...)`。现有清单不新增 `documentation` 键；缺少说明的旧包仍可加载。统一要求见项目技术手册第 8 章。
