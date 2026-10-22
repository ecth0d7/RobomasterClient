# 插件包与扩展运行时契约 (plugins)

## 插件定位与接口角色
`plugins/` 目录提供客户端扩展包（QML Package）的验证器、服务访问控制及总线分发宿主库（`PackageValidation` 与 `PluginPackageRuntime`）。**本目录为宿主核心支撑库，而非可独立运行的原生插件（Native Plugin）**。它定义了扩展包进入运行时的合法性边界、事件包络（Envelope）格式以及接收时间与队列年龄封装。


技术架构与设计规范可参阅 [TECHNICAL.md](../docs/TECHNICAL.md)。

原生动态库与宿主同进程运行，不构成操作系统沙箱；代码错误仍可能影响客户端。

## 依赖与启用条件
- **宿主依赖**：依赖 Qt Core / QML 运行时与客户端底层数据总线。
- **启用入口**：在界面按下快捷键 `Ctrl+Shift+E` 打开「插件管理」面板，或在启动配置中指定 `--package-dir` 与 `--package-config`。所有新发现的扩展包默认处于未激活状态，必须经过操作员显式审核并点击启用。
- **访问约束**：扩展包仅允许声明合法的 defaults 与 schema，单个消息包络体积上限为 4 KiB，队列最多 64 条、总计 256 KiB。系统严禁扩展包伪造官方下发凭据或越权产生比赛控制指令。

## 配置字段说明
扩展包的配置描述符在清单的 `configuration` 对象中定义，由 `defaults` 与 `schema` 两部分组成：

| 字段名 | 类型 | 默认值 | 约束与说明 |
| :--- | :--- | :--- | :--- |
| `defaults` | Object | `{}` | 必填，扩展包初始配置键值对，必须严格符合 schema 声明 |
| `schema` | Object | `{}` | 必填，字段类型与取值范围校验规则 |
| `services.required` | Array | `[]` | 必填外部依赖服务列表，不得与 `optional` 或 `exports` 重叠 |
| `services.optional` | Array | `[]` | 可选依赖服务列表 |
| `services.exports` | Array | `[]` | 扩展包向总线暴露的服务接口标识 |

### 扩展包清单示例（rmplugin.json）
```json
{
  "schema": 1,
  "id": "example.viewer",
  "version": "1.0.0",
  "apiMajor": 1,
  "entry": "Main.qml",
  "services": {
    "exports": [],
    "required": [
      "terminal.data@3"
    ],
    "optional": []
  },
  "channels": {
    "publish": [
      "example.viewer.events@1"
    ],
    "subscribe": []
  },
  "panels": [
    {
      "id": "main",
      "title": "状态查看",
      "entry": "Panel.qml"
    }
  ],
  "configuration": {
    "defaults": {
      "title": "状态查看"
    },
    "schema": {
      "type": "object",
      "properties": {
        "title": {
          "type": "string",
          "minLength": 1,
          "maxLength": 80
        }
      },
      "required": [
        "title"
      ],
      "additionalProperties": false
    }
  }
}
```

## 使用与状态判断
1. 将插件包解压或放置于 `--package-dir` 指定目录。
2. 启动客户端，按 `Ctrl+Shift+E` 进入「插件管理」；
3. 检查列表中该插件状态，若清单校验合法且无服务命名冲突，勾选「启用」；
4. 状态判断：包络总线开始分发标记为 `publisher: <packageId>` 的消息包，且消息未被截断（载荷 ≤ 4 KiB），表明扩展正常运行。

## 停用、缺失与异常处理
- **停用操作**：在 `Ctrl+Shift+E` 管理界面取消勾选对应插件，或重置 `--package-config` 配置文件，热卸载 QML 视图树。
- **缺失处理**：若缺少 `services.required` 中的依赖服务，扩展包拒绝装载并向状态栏报错。
- **异常限制**：所有扩展包发布的数据包络中，系统强制锁定 `authoritative: false` 与 `execution_allowed: false`，杜绝插件越权模拟官方裁判系统指令。

## 配置文档交付约定
本说明随源码与分发物交付。若制作 `rmplugin.json` 扩展包，将 `README.md` 列入 `robomaster_package_extension(... FILES ...)`。现有清单不新增 `documentation` 键；缺少说明的旧包仍可加载。统一要求见项目技术手册第 8 章。
