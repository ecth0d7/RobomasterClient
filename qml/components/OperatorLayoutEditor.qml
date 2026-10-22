import QtQuick
import "OperatorLayout.js" as Layout
import "UiFormat.js" as Format

OperatorPanelFrame {
    id: root
    property var layoutState: null
    property int clientID: 0
    property bool previewOnly: false
    property bool nextSeason: false
    property bool panelsTab: false
    property bool hiddenOnly: false
    property var extensionPanels: []
    property string extensionFeedback: ""
    readonly property bool showingPanels: panelsTab || nextSeason
    readonly property int hiddenCount: Layout.widgets.filter(widget => !Layout.shown(layoutState?.current, widget.id)).length
    readonly property int restorableCount: Layout.widgets.filter(widget => !Layout.shown(layoutState?.current, widget.id) && (widget.id !== "advice" || layoutState?.adviceEditable === true)).length
    // Only native host catalog IDs are routed. Entry URLs are not a UI command.
    readonly property var extensionEntries: list(extensionPanels).filter(entry => entry
        && typeof entry.package_id === "string" && entry.package_id.length > 0
        && typeof entry.panel_id === "string" && entry.panel_id.length > 0).map(entry => ({
            kind: "extension", packageId: entry.package_id, panelId: entry.panel_id,
            title: typeof entry.title === "string" && entry.title.length > 0 ? entry.title : entry.panel_id,
            detail: "扩展 · " + entry.package_id + " / " + entry.panel_id
        }))
    readonly property var nextSeasonPanelIds: ["season", "packages", "scene", "settings", "startup", "services",
        "speech", "bridge", "aggregation", "provider", "sources", "team-config", "help"]
    readonly property var panelEntries: panels.filter(entry => !nextSeason || nextSeasonPanelIds.includes(entry.id)).concat(extensionEntries)
    readonly property var shownEntries: showingPanels ? panelEntries : Layout.widgets.filter(widget => !hiddenOnly || !Layout.shown(layoutState?.current, widget.id))
    signal openPanelRequested(string panel)
    signal openExtensionPanelRequested(string packageId, string panelId)
    title: "界面自定义"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    width: 620
    height: 660
    readonly property var panels: [
        {id: "season", title: "赛季与规则工作区", detail: "协议范围 / 能力 / 数据来源"},
        {id: "packages", title: "插件包管理", detail: "安装 / 配置 / 启用 / 移除"},
        {id: "scene", title: "场景与渲染提供者", detail: "二维 / 社区插件 / 标定 / 生命周期"},
        {id: "role", title: "当前机器人专属面板", detail: Format.role(clientID)},
        {id: "commands", title: "兑换／复活", detail: "远程／现场／复活资格"},
        {id: "status", title: "全局状态", detail: "双方机器人"},
        {id: "buffs", title: "自身增益", detail: "七类型 / 易伤 / 来源 / 时效"},
        {id: "injury", title: "模块与受伤信息", detail: "扣血来源"},
        {id: "dart", title: "飞镖云台手", detail: "独立授权／目标／闸门"},
        {id: "rune", title: "能量机关", detail: "总灯臂／来源／长按确认"},
        {id: "engineer", title: "科技核心装配", detail: "工程机器人"},
        {id: "air", title: "空中支援", detail: "空中机器人"},
        {id: "sentry", title: clientID % 100 === 9 ? "雷达位置／标识" : "哨兵命令", detail: clientID % 100 === 9 ? "只读官方位置／单位／来源" : "姿态／补给／复活 · 本机资格"},
        {id: "hero", title: "英雄部署", detail: "英雄机器人"},
        {id: "settings", title: "设置", detail: "身份 / 图传 / 声音"},
        {id: "startup", title: previewOnly ? "启动与连接配置" : "连接与身份",
            detail: previewOnly ? "导出 / 图传 / 绘制 / 核心插件" : "MQTT / UDP / 机器人身份"},
        {id: "services", title: "服务状态", detail: "互联 / 模型 / 语音"},
        {id: "details", title: "协议字段查看", detail: "全部字段 / 数组 / 字节"},
        {id: "map", title: "地图标记", detail: "坐标 / 目标 / 接收者"},
        {id: "custom", title: "自定义字节", detail: "接收 / 编辑 / 输入格式"},
        {id: "decision", title: "模型与策略配置", detail: "可随时修改 / 保存后应用"},
        {id: "decision-details", title: "建议与输入诊断", detail: "依据 / 来源 / 快照"},
        {id: "speech", title: "语音播报", detail: "文本 / 队列 / 音频参数"},
        {id: "bridge", title: "实验室互联", detail: "远端来源 / 快照 / 字段"},
        {id: "aggregation", title: "队伍数据汇总 · 可选插件", detail: "本机 / 队伍 / 来源 / 降级"},
        {id: "provider", title: "模型提供者配置", detail: "DeepSeek / HTTP / Codex / 运行边界"},
        {id: "sources", title: "本地传感器 / 视觉源", detail: "来源 / 适配器 / 生命周期 / 坐标"},
        {id: "team-config", title: "队伍身份与共享权限", detail: "可信成员 / 用途 / 语音责任"},
        {id: "help", title: "帮助", detail: "当前角色按键"}
    ]

    property alias headerGap: editorForm.headerGap
    property alias headingMinimumHeight: editorForm.headingMinimumHeight
    property alias descriptionMinimumHeight: editorForm.descriptionMinimumHeight
    property alias tabsGap: editorForm.tabsGap
    property alias tabSpacing: editorForm.tabSpacing
    property alias tabsBreakpoint: editorForm.tabsBreakpoint
    property alias controlHeight: editorForm.controlHeight
    property alias filterGap: editorForm.filterGap
    property alias filterMinimumHeight: editorForm.filterMinimumHeight
    property alias filterControlHeight: editorForm.filterControlHeight
    property alias listGap: editorForm.listGap
    property alias listBottomGap: editorForm.listBottomGap
    property alias listRightPadding: editorForm.listRightPadding
    property alias rowSpacing: editorForm.rowSpacing
    property alias footerSpacing: editorForm.footerSpacing
    property alias footerNoteMinimumHeight: editorForm.footerNoteMinimumHeight
    property alias footerButtonSpacing: editorForm.footerButtonSpacing
    property alias emptyInset: editorForm.emptyInset
    property alias emptyTopInset: editorForm.emptyTopInset
    property alias emptyMinimumHeight: editorForm.emptyMinimumHeight
    property alias scrollbarWidth: editorForm.scrollbarWidth
    property alias scrollbarMinimumSize: editorForm.scrollbarMinimumSize
    property alias scrollbarThumbWidth: editorForm.scrollbarThumbWidth
    property alias scrollbarThumbHeight: editorForm.scrollbarThumbHeight
    property alias scrollbarRadius: editorForm.scrollbarRadius
    property alias scrollbarActiveOpacity: editorForm.scrollbarActiveOpacity
    property alias scrollbarIdleOpacity: editorForm.scrollbarIdleOpacity
    property alias headingSize: editorForm.headingSize
    property alias descriptionSize: editorForm.descriptionSize
    property alias noteSize: editorForm.noteSize
    property alias emptySize: editorForm.emptySize
    property alias rowTitleSize: editorForm.rowTitleSize
    property alias rowNoteSize: editorForm.rowNoteSize
    property alias widgetSize: editorForm.widgetSize
    property alias rowLeftInset: editorForm.rowLeftInset
    property alias rowRightInset: editorForm.rowRightInset
    property alias rowActionWidth: editorForm.rowActionWidth
    property alias rowActionGap: editorForm.rowActionGap
    property alias rowActionHeight: editorForm.rowActionHeight
    property alias rowPanelMinimumHeight: editorForm.rowPanelMinimumHeight
    property alias rowHudMinimumHeight: editorForm.rowHudMinimumHeight
    property alias rowTextSpacing: editorForm.rowTextSpacing
    property alias rowTitleTop: editorForm.rowTitleTop
    property alias rowBottomInset: editorForm.rowBottomInset
    property alias rowTitleMinimumHeight: editorForm.rowTitleMinimumHeight
    property alias rowDetailMinimumHeight: editorForm.rowDetailMinimumHeight
    property alias rowStateWidth: editorForm.rowStateWidth
    property alias rowBreakpoint: editorForm.rowBreakpoint
    property alias rowToggleTextPadding: editorForm.rowToggleTextPadding
    property alias textColor: editorForm.textColor
    property alias mutedColor: editorForm.mutedColor
    property alias warningColor: editorForm.warningColor
    property alias rowEvenColor: editorForm.rowEvenColor
    property alias rowOddColor: editorForm.rowOddColor
    property alias scrollbarTrackColor: editorForm.scrollbarTrackColor
    property alias scrollbarThumbColor: editorForm.scrollbarThumbColor
    property alias scrollbarPressedColor: editorForm.scrollbarPressedColor
    property alias fontFamily: editorForm.fontFamily
    property alias listControl: editorForm.listControl
    function list(value) {
        // 原生availablePanels为Qt序列；先复制再筛选，不要求JS Array身份。
        return value !== null && typeof value === "object" && Number.isInteger(value.length) && value.length >= 0
            ? Array.from(value) : [];
    }
    function openEntry(index) {
        const entry = shownEntries[index];
        if (!showingPanels || !entry) return;
        // 条目entry URL从不进入导航；只提交原生目录已给出的结构化ID。
        if (entry.kind === "extension") openExtensionPanelRequested(entry.packageId, entry.panelId);
        else openPanelRequested(entry.id);
    }
    function setEntryShown(index, shown) {
        const entry = shownEntries[index];
        if (showingPanels || !entry || entry.id === "advice" && layoutState?.adviceEditable !== true) return;
        layoutState?.setShown(entry.id, shown);
    }
    OperatorLayoutEditorForm {
        id: editorForm
        anchors.fill: parent
        surfaceColor: root.surfaceColor
        showingPanels: root.showingPanels
        hudTabEnabled: !root.nextSeason
        hiddenOnlyValue: root.hiddenOnly
        restoreEnabled: root.restorableCount > 0
        headingText: root.nextSeason ? "2027 · 按能力开放面板" : Format.role(root.clientID) + " · 独立显示方案"
        descriptionText: root.previewOnly ? "离线设计预览 · 修改仅在本次窗口生效"
            : root.nextSeason ? "保留2026绘图参考；当前仅列出适用的基础工具与已就绪的扩展面板。"
            : "按机器人编号保存 · 红蓝阵营共用同一编号方案"
        hudTabText: root.nextSeason ? "2027 能力驱动界面" : "HUD 已启用 · " + (Layout.widgets.length - root.hiddenCount) + "/" + Layout.widgets.length
        panelsTabText: "面板库 · " + root.extensionEntries.length + " 个扩展"
        hiddenOnlyText: "只看已隐藏组件（" + root.hiddenCount + "）"
        feedbackText: root.extensionFeedback || "打开所需面板 · Esc 关闭 · Ctrl+Shift+U 返回此处"
        feedbackWarning: root.extensionFeedback.length > 0
        emptyVisible: !root.showingPanels && root.hiddenOnly && root.hiddenCount === 0
        emptyText: "所有 HUD 组件均已启用。\n有效数据出现时显示；取消筛选查看全部。"
        footerText: root.showingPanels ? "扩展启用且依赖就绪后列出；关闭面板后可从这里重新打开。"
            : root.layoutState?.adviceEditable === true ? "恢复组件仍遵守有效数据条件；建议设置仅赛前可改。"
            : "建议显示可随时修改；恢复全部保留已保存选择。"
        entryCount: root.shownEntries.length
        entryDelegate: Component {
            OperatorLayoutEditorRowForm {
                id: row
                required property int index
                readonly property var entry: root.shownEntries[index] ?? ({})
                objectName: "layoutEditorEntry_" + index
                width: editorForm.entryDelegateWidth
                rowIndex: index
                panelMode: root.showingPanels
                checkedValue: Layout.shown(root.layoutState?.current, entry.id)
                toggleEnabled: entry.id !== "advice" || root.layoutState?.adviceEditable === true
                openEnabled: root.showingPanels
                titleText: entry.title ?? ""
                detailText: entry.detail ?? ""
                stateText: entry.id === "advice" && root.layoutState?.adviceEditable !== true ? "当前不可编辑"
                    : Layout.shown(root.layoutState?.current, entry.id) ? entry.area ?? "" : "已隐藏"
                stateWarning: !Layout.shown(root.layoutState?.current, entry.id)
                leftInset: root.rowLeftInset
                rightInset: root.rowRightInset
                actionWidth: root.rowActionWidth
                actionGap: root.rowActionGap
                actionHeight: root.rowActionHeight
                controlHeight: root.controlHeight
                panelMinimumHeight: root.rowPanelMinimumHeight
                hudMinimumHeight: root.rowHudMinimumHeight
                textSpacing: root.rowTextSpacing
                titleTop: root.rowTitleTop
                bottomInset: root.rowBottomInset
                titleMinimumHeight: root.rowTitleMinimumHeight
                detailMinimumHeight: root.rowDetailMinimumHeight
                stateWidth: root.rowStateWidth
                breakpoint: root.rowBreakpoint
                titleSize: root.rowTitleSize
                noteSize: root.rowNoteSize
                widgetSize: root.widgetSize
                toggleTextPadding: root.rowToggleTextPadding
                evenSurface: root.rowEvenColor
                oddSurface: root.rowOddColor
                textColor: root.textColor
                mutedColor: root.mutedColor
                warningColor: root.warningColor
                fontFamily: root.fontFamily
                Connections { target: row.toggleControl; function onToggled() { root.setEntryShown(row.index, row.toggleControl.checked); } }
                Connections { target: row.openControl; function onClicked() { root.openEntry(row.index); } }
            }
        }
    }
    Connections { target: editorForm.hudTabControl; function onClicked() { if (!root.nextSeason) root.panelsTab = false; } }
    Connections { target: editorForm.panelsTabControl; function onClicked() { root.panelsTab = true; } }
    Connections { target: editorForm.hiddenOnlyControl; function onToggled() { root.hiddenOnly = editorForm.hiddenOnlyControl.checked; } }
    Connections { target: editorForm.restoreControl; function onClicked() { if (root.restorableCount > 0) root.layoutState?.resetRole(); } }
    Connections { target: editorForm.doneControl; function onClicked() { root.closeRequested(); } }
}
