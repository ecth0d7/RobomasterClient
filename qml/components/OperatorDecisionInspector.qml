import QtQuick
import QtQuick.Controls
import "OperatorDecisionData.js" as Decision
import "UiFormat.js" as Format
import "OperatorTeamAggregationData.js" as Team

OperatorPanelFrame {
    id: root
    property var services: null
    property var preferences: null
    property int clientID: 3
    property bool previewOnly: false
    property bool preparationAllowed: false
    property int detailTab: 0
    property string feedback: ""
    property string resultSignature: ""
    readonly property var details: services?.decisionDetails ?? ({})
    readonly property var advice: services?.advice ?? ({})
    readonly property var input: services?.decisionInput ?? ({})
    readonly property var trace: services?.decisionTrace ?? ({})
    readonly property bool busy: details.busy === true
    readonly property bool hasAdvice: Object.keys(advice).length > 0
    readonly property bool hasInput: Object.keys(input).length > 0
    readonly property bool adviceFresh: hasAdvice && advice.fresh === true
    readonly property bool inputFresh: hasInput && services?.decisionInputFresh === true
    readonly property bool localFallbackAllowed: preferences?.current?.inputMode === "team"
        && preferences?.current?.teamFallback === "local" && services?.decisionCapabilities?.local_input === true
    readonly property bool scopeAvailable: preferences?.current?.inputMode !== "team"
        || services?.decisionCapabilities?.team_input === true || localFallbackAllowed
    readonly property bool requestAllowed: scopeAvailable && preparationAllowed && services?.decisionAvailable === true && !busy && question.text.length <= 500
    readonly property bool speechActive: services?.speechDetails?.active === true
    readonly property string speechAction: services?.speechDetails?.playback === true ? "朗读" : "合成"
    property color adviceColor: !adviceFresh ? Theme.warning : advice.priority === "urgent" ? Theme.red : advice.priority === "caution" ? Theme.warning : Theme.green
    readonly property string adviceState: previewOnly ? "离线样例 · " + (advice.fresh === true ? "有效期内" : "已失效") : advice.fresh !== true ? "建议失效或时效未提供" : trace.source_verification === "operator_confirmation" ? "有效期内 · 选手端来源人工确认" : "有效期内 · 查看来源与追踪状态"
    signal requestIntent(string question)
    signal cancelIntent
    signal speakAdviceIntent
    signal speakInputIntent
    signal layoutRequested
    signal servicesRequested
    title: "建议与输入 · 诊断"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1440
    height: 780
    onClientIDChanged: { if (question) question.clear(); feedback = ""; }
    onAdviceChanged: {
        const signature = String(advice.summary ?? "") + "\n" + String(advice.rationale ?? "");
        if (signature !== resultSignature) {
            resultSignature = signature;
            Qt.callLater(resetScroll);
        }
    }
    function resetScroll() { if (resultScroll.contentItem) resultScroll.contentItem.contentY = 0; }
    function setQuestion(text) { question.text = text; }
    function request() {
        if (!requestAllowed) return;
        feedback = "";
        requestIntent(question.text.trim());
    }
    function speech(kind) {
        if (previewOnly) { feedback = "离线绘制演示，不合成或播放语音。"; return; }
        if (kind === "advice" && adviceFresh && inputFresh && speechActive && services?.speechDetails?.keyed_cancellation === true) speakAdviceIntent();
        else if (kind === "input" && inputFresh && speechActive && services?.speechDetails?.keyed_cancellation === true) speakInputIntent();
    }
    Rectangle {
        width: parent.width; height: 100
        color: "#202a25"; border.color: Theme.line
        OperatorText { x: 14; y: 8; width: 330; height: 24; text: "当前模型"; size: 11; color: Theme.muted }
        OperatorText { x: 14; y: 36; width: 330; height: 28; text: String(root.details.model ?? "—"); textFormat: Text.PlainText; size: 16 }
        OperatorText { x: 14; y: 68; width: 330; height: 24; text: "接口 " + Decision.api(root.details.api) + " · 超时 " + Decision.number(root.details.timeout_ms) + " ms"; textFormat: Text.PlainText; size: 11; color: Theme.muted }
        OperatorText { x: 368; y: 8; width: parent.width - 720; height: 24; text: "服务反馈"; size: 11; color: Theme.muted }
        OperatorText { x: 368; y: 36; width: parent.width - 720; height: 54; text: root.services?.decisionStatus ?? "未提供模型服务状态"; textFormat: Text.PlainText; wrapMode: Text.WordWrap; size: 13; color: Theme.muted }
        OperatorText { x: parent.width - 328; y: 8; width: 314; height: 24; text: "当前任务"; size: 11; color: Theme.muted }
        OperatorText { x: parent.width - 328; y: 36; width: 268; height: 28; text: typeof root.details.busy === "boolean" ? root.busy ? "正在分析" : "空闲" : "未提供任务状态"; size: 15; color: root.busy ? Theme.green : Theme.text }
        OperatorText { x: parent.width - 328; y: 68; width: 314; height: 24; text: "输入快照 " + (root.hasInput ? root.inputFresh ? "有效" : "不可用" : "尚未生成"); size: 11; color: root.hasInput && !root.inputFresh ? Theme.warning : Theme.muted }
        Item {
            x: parent.width - 48; y: 38; width: 28; height: 28; visible: root.busy
            Row {
                anchors.centerIn: parent; spacing: 4
                Repeater {
                    model: 3
                    Rectangle {
                        id: busyDot
                        required property int index
                        width: 4; height: 16; color: Theme.green; opacity: 0.25
                        SequentialAnimation on opacity {
                            running: root.busy && root.visible && !Theme.reducedMotion; loops: Animation.Infinite
                            PauseAnimation { duration: busyDot.index * 120 }
                            NumberAnimation { from: 0.25; to: 1; duration: 200 }
                            NumberAnimation { to: 0.25; duration: 450 }
                            PauseAnimation { duration: 300 - busyDot.index * 120 }
                        }
                    }
                }
            }
        }
    }
    OperatorSection {
        y: 116; width: 520; height: parent.height - y - 50
        title: "本次分析"
        OperatorText { width: parent.width - 118; height: 24; text: question.text.length > 500 ? "关注点超过长度上限" : "关注点 · 可选"; size: 12; color: question.text.length > 500 ? Theme.warning : Theme.muted }
        OperatorText { x: parent.width - 108; width: 108; height: 24; text: question.text.length + " / 500"; numeric: true; horizontalAlignment: Text.AlignRight; size: 11; color: question.text.length > 500 ? Theme.warning : Theme.muted }
        ScrollView {
            id: questionScroll
            y: 34; width: parent.width; height: 84; clip: true; contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            OperatorTextArea { id: question; width: questionScroll.availableWidth; height: Math.max(questionScroll.availableHeight, implicitHeight); readOnly: root.busy || !root.preparationAllowed; label: "模型分析关注点"; placeholderText: "留空则分析当前操作重点"; onTextChanged: root.feedback = "" }
        }
        Row {
            y: 130; width: parent.width; spacing: 12
            OperatorButton { width: (parent.width - 12) / 2; text: root.previewOnly ? "演示分析" : "分析当前遥测"; primary: true; enabled: root.requestAllowed; onClicked: root.request() }
            OperatorButton { width: (parent.width - 12) / 2; text: root.services?.decisionConfiguration?.current?.autoAdvice === true ? "取消并暂停自动建议" : "取消本次请求"; enabled: root.busy; onClicked: root.cancelIntent() }
        }
        Rectangle { y: 184; width: parent.width; height: 1; color: Theme.line }
        OperatorText { y: 194; width: parent.width; height: 24; text: "本次输入快照 · " + (root.hasInput ? root.inputFresh ? "有效" : "不可用" : "尚未生成"); size: 13; color: root.hasInput && !root.inputFresh ? Theme.warning : Theme.text }
        OperatorText { y: 222; width: parent.width; height: 26; text: root.input.input_mode === "team" ? "队伍整合视图 · 下列读数仅为本机焦点" : root.hasInput ? "编号 " + Decision.number(root.input.client_id) + " · " + Format.role(root.input.client_id) : "分析后显示请求时的身份与数值"; size: 12; color: Theme.muted }
        Row {
            y: 258; width: parent.width; spacing: 8
            Repeater {
                model: Decision.facts(root.input)
                OperatorDecisionFact { required property var modelData; width: (parent.width - 16) / 3; fact: modelData }
            }
        }
        OperatorText { y: 354; width: parent.width; height: 28; text: root.hasInput ? root.inputFresh ? "这是请求时的输入，数值不会随实时 HUD 刷新。" : "本次输入不可用；数值仅供对照，请重新分析。" : "先生成请求快照；缺失数值保持 —。"; wrapMode: Text.WordWrap; size: 11; color: root.hasInput && !root.inputFresh ? Theme.warning : Theme.muted }
        Row {
            y: 392; width: parent.width; spacing: 12
            OperatorButton { width: (parent.width - 12) / 2; text: root.speechAction + "本次输入"; enabled: root.inputFresh && root.speechActive && root.services?.speechDetails?.keyed_cancellation === true; onClicked: root.speech("input") }
            OperatorButton { width: (parent.width - 12) / 2; text: "查看本次输入"; enabled: root.hasInput; onClicked: { root.detailTab = 1; root.resetScroll(); } }
        }
        OperatorText { y: 440; width: parent.width; height: 24; text: "快照随请求生成，不拿新数据补齐旧输入。"; size: 11; color: Theme.muted }
    }
    OperatorSection {
        x: 544; y: 116; width: parent.width - x; height: parent.height - y - 50
        title: "建议与依据"
        Row {
            width: parent.width; spacing: 12
            OperatorButton { width: (parent.width - 12) / 2; text: "模型建议"; primary: root.detailTab === 0; onClicked: { root.detailTab = 0; root.resetScroll(); } }
            OperatorButton { width: (parent.width - 12) / 2; text: "本次输入"; primary: root.detailTab === 1; onClicked: { root.detailTab = 1; root.resetScroll(); } }
        }
        OperatorScrollableColumn {
            id: resultScroll
            y: 54; width: parent.width; height: parent.height - y - 56
            OperatorText {
                visible: root.detailTab === 0 && !root.hasAdvice
                width: parent.width; height: 270
                text: root.busy ? "正在分析本次输入\n可取消当前请求" : root.details.active === false ? "模型服务未启用\n查看服务反馈和服务详情" : "尚无模型建议\n填写可选关注点，再分析当前遥测"
                wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; size: 16; color: Theme.muted
            }
            Rectangle {
                visible: root.detailTab === 0 && root.hasAdvice
                width: parent.width; height: 64; color: "#202a25"; border.color: root.adviceColor
                OperatorText { x: 12; y: 6; width: parent.width - 24; height: 26; text: root.adviceState + " · " + Decision.priority(root.advice.priority) + " · 关注 " + Decision.focus(root.advice.focus); textFormat: Text.PlainText; size: 14; color: root.adviceColor }
                OperatorText { x: 12; y: 35; width: parent.width - 24; height: 22; text: "初始有效期 " + Decision.number(root.advice.expires_in_ms) + " ms · 请求到结果 " + Decision.number(root.advice.based_on_age_ms) + " ms"; size: 11; color: Theme.muted }
            }
            OperatorText { visible: root.detailTab === 0 && root.hasAdvice; width: parent.width; height: implicitHeight; text: root.advice.summary ?? "未提供建议文本"; textFormat: Text.PlainText; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 20; color: root.adviceFresh ? Theme.text : Theme.muted }
            OperatorText { visible: root.detailTab === 0 && root.hasAdvice; width: parent.width; height: 26; text: "模型给出的依据"; size: 13; color: Theme.muted }
            OperatorText { visible: root.detailTab === 0 && root.hasAdvice; width: parent.width; height: implicitHeight; text: root.advice.rationale || "模型未提供依据文本"; textFormat: Text.PlainText; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 13; color: Theme.muted }
            OperatorDiagnosticTable {
                visible: root.detailTab === 0 && root.hasAdvice
                width: parent.width; title: "来源与快照追踪 · 不将策略当作权威遥测"
                rows: [
                    {label: "实际输入范围", value: Team.mode(root.services?.decisionTrace?.input_mode), detail: true},
                    {label: "队伍整合视图 / 版本", value: Team.text(root.services?.decisionTrace?.team_view_id) + " / " + Team.number(root.services?.decisionTrace?.team_view_revision), detail: true},
                    {label: "降级原因", value: root.services?.decisionTrace?.degradation_reason || "未降级或未提供", detail: true},
                    {label: "发送者", value: root.services?.decisionTrace?.sender_id ?? "未提供", detail: true},
                    {label: "输入快照", value: root.services?.decisionTrace?.snapshot_id ?? "未提供", detail: true},
                    {label: "输入快照年龄 · 毫秒", value: Decision.number(root.trace.snapshot_age_ms), detail: true},
                    {label: "建议接收年龄 · 毫秒", value: Decision.number(root.trace.received_age_ms), detail: true},
                    {label: "来源核对方式", value: root.trace.source_verification === "operator_confirmation" ? "操作手人工确认当前选手端导出路径" : root.trace.source_verification ?? "未提供", detail: true},
                    {label: "导出发布者密码学身份认证", value: root.trace.export_cryptographically_authenticated === true ? "已提供密码学认证" : root.trace.export_cryptographically_authenticated === false ? "未认证 · 操作手声明不等于密码学身份认证" : "未提供 · 不能视为已认证", detail: true},
                    {label: "建议标识", value: root.services?.decisionTrace?.advice_id ?? "未提供", detail: true},
                    {label: "生成模型", value: root.services?.decisionTrace?.model_source ?? "未提供", detail: true},
                    {label: "生成时间 · UTC 毫秒", value: Decision.number(root.services?.decisionTrace?.created_at_ms), detail: true},
                    {label: "可信类别", value: root.services?.decisionTrace?.trust ?? "未提供 / 未认证", detail: true}
                ]
            }
            OperatorText { visible: root.detailTab === 1; width: parent.width; height: 26; text: root.hasInput ? "请求快照 · " + (root.inputFresh ? "有效" : "不可用") : "尚无请求快照"; size: 14; color: root.inputFresh ? Theme.text : Theme.warning }
            OperatorText { visible: root.detailTab === 1 && root.hasInput; width: parent.width; height: implicitHeight; text: "请求时未提供或旧分组：" + Decision.groupList(root.input.unavailable_groups) + "\n主动省略分组：" + Decision.groupList(root.input.omitted_groups); textFormat: Text.PlainText; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 12; color: Theme.muted }
            OperatorText { visible: root.detailTab === 1 && root.hasInput; width: parent.width; height: implicitHeight; text: "未用于分析的字段：\n" + Decision.fieldList(root.input.unavailable_fields); textFormat: Text.PlainText; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 12; color: Theme.muted }
            OperatorTextArea { id: inputJson; visible: root.detailTab === 1 && root.hasInput; width: parent.width; height: implicitHeight; readOnly: true; numeric: true; label: "本次模型输入快照"; text: Decision.inputJson(root.input) }
        }
        Row {
            y: parent.height - 38; width: parent.width; spacing: 12
            OperatorButton { width: 220; visible: root.detailTab === 0; text: root.speechAction + "当前建议"; enabled: root.adviceFresh && root.inputFresh && root.speechActive && root.services?.speechDetails?.keyed_cancellation === true; onClicked: root.speech("advice") }
            OperatorButton { width: 220; visible: root.detailTab === 1; text: "复制本次输入"; enabled: root.hasInput; onClicked: { inputJson.selectAll(); inputJson.copy(); inputJson.deselect(); root.feedback = "本次输入已复制。"; } }
            OperatorText { width: parent.width - 232; height: 38; text: root.feedback || "建议不自动触发机器人指令"; wrapMode: Text.WordWrap; size: 11; color: root.feedback ? Theme.green : Theme.muted }
        }
    }
    OperatorText { y: parent.height - 38; width: parent.width - 416; height: 38; text: !root.scopeAvailable ? "队伍完整视图输入尚未接通 · 等待有效队伍输入" : root.previewOnly ? "离线绘制样例 · 演示分析不调用模型" : root.localFallbackAllowed && root.services?.decisionCapabilities?.team_input !== true ? "已允许队伍视图不可用时降为本机输入 · 实际范围见追踪" : "分析使用请求时的有效遥测快照"; size: 11; color: Theme.muted }
    Row {
        x: parent.width - 404; y: parent.height - 38; spacing: 12
        OperatorButton { width: 196; text: "服务详情"; onClicked: root.servicesRequested() }
        OperatorButton { width: 196; text: "返回面板库"; onClicked: root.layoutRequested() }
    }
}
