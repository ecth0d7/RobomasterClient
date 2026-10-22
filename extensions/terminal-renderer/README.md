# 终端二维归一化场景渲染插件 (extensions/terminal-renderer)

## 插件清单与架构定位
本目录包含终端二维渲染投影扩展插件，实现 `ExtensionPlugin` 接口，角色定义为 `terminal-renderer`：
- `renderer.terminal.2d.v1`：负责将接收到的场景对象投影为受限且归一化的二维视图（Normalized 2D）。

本插件完全独立于游戏引擎（无 UE 依赖），不冒充任何官方协议指令，也不直接发送车辆执行指令；仅作为辅助态势的归一化屏幕空间投影器。

## 依赖与启用条件
1. **运行依赖**：完全依赖客户端自身的 Qt 图元系统，不需要外部专用显卡加速或三维渲染引擎支持。
2. **启用入口**：
   - 通过专用终端壳层的呈现配置页选择提供者，由 `TerminalSceneHost` 启用。普通2026插件管理页不提供此入口；它也不是M键2027三维地图插件。
   - 由原生宿主在可编辑阶段装配，使用当前赛季上下文。启用后若尚未传入场景数据，其状态维持为 `waiting_scene`。

## 配置字段说明
插件配置必须严格匹配 Schema 1 规范，字段列表如下：

| 字段名 | 类型 | 默认值 | 约束说明 |
| :--- | :--- | :--- | :--- |
| `schema` | 整数 | `1` | 严格匹配版本号 1，禁止修改 |
| `context` | 对象 | `{}` | 严格三个字段：`profile_id`、`field_profile_id`、`capability_revision`，均取当前宿主值 |

场景输入数据帧内部包含严格的坐标系与尺寸定义（`width_m`, `height_m`, 标定状态），待处理输入场景限制为64 KiB，输出投影限制为128 KiB。

## 最小配置与使用示例
无需手写跨赛季的上下文JSON。原生宿主实际传入如下参数；这是C++装配示例，`currentHostContext` 必须取当前宿主：

```cpp
QVariantMap configuration{{"schema", 1}, {"context", currentHostContext}};
```

**使用与状态判断**：
- 调用插件运行接口后，查询状态字典：若 `active: true` 且 `state: "projecting"`，表示已成功接收上游场景并正确计算 2D 投影点。
- 坐标系遵循屏幕顶部左上角为原点、Y 轴向下、顺时针角度规则（`screen-top-left-y-down-heading-clockwise`）。
- 状态属性中 `automatic_actions_allowed: false`、`authoritative: false` 恒成立，确保不干预操作指令。

## 停用、缺失与异常处理
- **数据超限**：输入场景序列化大小超过64 KiB或投影输出超过128 KiB 时，解析器直接拒绝当前帧，并设置 `last_error`，不截断或显示残缺数据。
- **时钟与版本跳变**：若输入场景的 `produced_at_ms` 超前于系统时间，或 `revision` 不大于已处理版本，则丢弃该帧不予渲染。
- **停用行为**：在终端呈现配置页停用后，状态即刻切换为 `stopped`，内部清空场景缓存，释放投影计算资源。

关于场景坐标投影数学规约与视口定义，请参阅 [TECHNICAL.md](../../docs/TECHNICAL.md)。

## 配置文档交付约定
本说明随源码与分发物交付。若制作 `rmplugin.json` 扩展包，将 `README.md` 列入 `robomaster_package_extension(... FILES ...)`。现有清单不新增 `documentation` 键；缺少说明的旧包仍可加载。统一要求见项目技术手册第 8 章。
