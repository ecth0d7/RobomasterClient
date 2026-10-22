import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "OperatorDecisionData.js" as Decision
import "OperatorDecisionPolicy.js" as Policy
import "OperatorTeamAggregationData.js" as Team

Rectangle {
    id: root
    property var services: null
    property var preferences: null
    property bool connected: false
    property bool previewOnly: false
    property bool designPlaceholder: false
    readonly property var advice: services?.advice ?? ({})
    readonly property var trace: services?.decisionTrace ?? ({})
    readonly property var settings: preferences?.current ?? Policy.defaults()
    readonly property bool busy: services?.decisionDetails?.busy === true
    readonly property string health: services?.decisionDetails?.health ?? "unknown"
    readonly property bool offlineSample: previewOnly || trace.origin === "offline-preview" || trace.trust === "offline-sample"
    // 来源依赖由宿主核验；只有纯本机感知输入才能明确不依赖选手端链路。
    readonly property bool playerRequired: trace.requires_player_client !== false
    readonly property bool inputConnected: playerRequired ? connected : services?.decisionInputSourcesAvailable === true
    readonly property bool sourceProof: trace.sources_verified === true && (!playerRequired || trace.player_export_verified === true)
    readonly property bool fresh: inputConnected && !busy && advice.fresh === true && services?.decisionInputFresh === true
    readonly property bool traced: typeof trace.snapshot_id === "string" && trace.snapshot_id.length > 0 && typeof trace.sender_id === "string" && trace.sender_id.length > 0
    readonly property bool fallback: settings.inputMode === "team" && trace.input_mode === "local" && settings.teamFallback === "local" && typeof trace.degradation_reason === "string" && trace.degradation_reason.length > 0
    readonly property bool routeMatches: trace.input_mode === settings.inputMode || fallback
    readonly property bool teamProof: trace.input_mode !== "team" || previewOnly || trace.aggregation_verified === true && trace.view_revision_current === true
    readonly property bool usable: fresh && traced && routeMatches && teamProof && (previewOnly || !offlineSample && sourceProof && trace.sender_verified === true && trace.input_revision_current === true)
    readonly property bool hasAdvice: Object.keys(advice).length > 0
    readonly property string phaseLabel: !inputConnected ? playerRequired ? "选手端链路失联" : "感知数据源不可用" : health === "timeout" ? "模型超时" : health === "error" || health === "unavailable" ? "模型失联" : health === "disabled" ? "模型未启用" : busy ? "正在更新建议" : hasAdvice && !fresh ? "建议已失效" : hasAdvice && !routeMatches ? "等待所选范围的有效建议" : hasAdvice && !usable ? "建议追踪 / 来源确认不足" : usable ? Decision.priority(advice.priority) : "等待有效建议"
    readonly property string state: offlineSample ? "离线样例 · " + phaseLabel : phaseLabel
    property color priorityColor: !usable ? Theme.muted : advice.priority === "urgent" ? Theme.red : advice.priority === "caution" ? Theme.warning : Theme.green
    readonly property real hudScale: Window.window?.ui?.layoutScale ?? 1
    readonly property bool compact: settings.adviceDensity !== "standard"
    readonly property string summary: designPlaceholder ? "有效建议的简短摘要显示在此处。" : typeof (advice.hud_summary ?? advice.summary) === "string" ? (advice.hud_summary ?? advice.summary) : ""
    readonly property string reason: designPlaceholder ? "关键依据；完整内容在详情查看。" : typeof (advice.key_reason ?? advice.rationale) === "string" ? (advice.key_reason ?? advice.rationale) : ""
    readonly property string senderLabel: typeof trace.sender_label === "string" && trace.sender_label.length > 0
        ? trace.sender_label : "来源节点 · 见详情"
    // verified标记表示宿主核对了已声明的路径，不能据此宣称导出者身份已认证。
    readonly property string sourceLabel: trace.source_verification === "operator_confirmation"
        ? "选手端人工确认" : playerRequired ? "来源确认见详情" : "本地来源见详情"
    readonly property bool displayable: usable && summary.trim().length > 0 && reason.trim().length > 0
    // 高度只由视口和赛前密度决定，出现、失效、加载均不改变邻近控件的位置。
    property real summaryHeight: Math.max(32, 24 / Math.max(0.1, hudScale))
    property real reasonHeight: compact ? Math.max(20, 12 / Math.max(0.1, hudScale)) : Math.max(32, 24 / Math.max(0.1, hudScale))
    property real metaHeight: Math.max(18, 11 / Math.max(0.1, hudScale))
    property real sourceTop: 38 + summaryHeight + 4 + reasonHeight + 4
    property real reservedHeight: sourceTop + 3 * metaHeight + 8
    signal detailsRequested
    width: 340
    height: reservedHeight
    visible: designPlaceholder || displayable
    color: Theme.hudSurface
    OperatorOutline {}
    Rectangle { width: 3; height: parent.height; color: root.priorityColor }
    OperatorText { x: 10; y: 8; width: parent.width - 82; height: 24; text: root.designPlaceholder ? "Designer · 建议布局参考" : root.state; size: 12; color: root.priorityColor; textFormat: Text.PlainText }
    Button {
        x: parent.width - 66; y: 7; width: 56; height: 26
        Accessible.name: "查看建议依据与输入追踪"
        contentItem: OperatorText { text: "详情"; size: 10; horizontalAlignment: Text.AlignHCenter }
        background: Rectangle { color: parent.hovered ? Theme.hudHover : "transparent"; OperatorOutline { color: parent.parent.activeFocus ? Theme.green : Theme.hudBorder } }
        onClicked: root.detailsRequested()
    }
    OperatorText {
        x: 10; y: 38; width: parent.width - 20; height: root.summaryHeight
        text: root.summary
        textFormat: Text.PlainText; wrapMode: Text.WordWrap; elide: Text.ElideNone; maximumLineCount: 2; size: 13; color: Theme.text
    }
    OperatorText { x: 10; y: 38 + root.summaryHeight + 4; width: parent.width - 20; height: root.reasonHeight; text: "依据：" + root.reason; textFormat: Text.PlainText; wrapMode: root.compact ? Text.NoWrap : Text.WordWrap; elide: root.compact ? Text.ElideRight : Text.ElideNone; maximumLineCount: root.compact ? 1 : 2; size: 11; color: Theme.muted }
    OperatorText { x: 10; y: root.sourceTop; width: parent.width - 20; height: root.metaHeight; text: root.designPlaceholder ? "来源机器人 · 建议接收年龄" : root.senderLabel + " · 建议接收 " + Decision.number(root.trace.received_age_ms) + "ms"; textFormat: Text.PlainText; size: 10; color: Theme.muted }
    OperatorText {
        x: 10; y: root.sourceTop + 2 * root.metaHeight; width: parent.width - 20; height: root.metaHeight
        text: root.designPlaceholder ? "语音 / 共享状态 · 布局参考" : (root.settings.voiceEnabled ? "语音未接通" : "语音关") + " · " + (root.settings.shareEnabled ? "共享未接通" : "共享关")
        textFormat: Text.PlainText; size: 10; color: Theme.muted
    }
    OperatorText {
        x: 10; y: root.sourceTop + root.metaHeight; width: parent.width - 20; height: root.metaHeight
        text: root.designPlaceholder ? "输入范围 · 输入快照年龄 · 来源人工确认" : (root.fallback ? "降级本机" : root.trace.input_mode === "team" ? "队伍 v" + Team.number(root.trace.team_view_revision) : "本机") + " · 输入 " + Decision.number(root.trace.snapshot_age_ms) + "ms · " + root.sourceLabel
        textFormat: Text.PlainText; size: 10; color: root.fallback ? Theme.warning : Theme.muted
    }
}
