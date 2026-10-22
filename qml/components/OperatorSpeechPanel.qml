import QtQuick
import QtQuick.Controls
import "OperatorDiagnostics.js" as Diagnostics

OperatorPanelFrame {
    id: root
    property var services: null
    property int clientID: 3
    property bool connected: false
    property bool previewOnly: false
    property int detailsTab: 0
    property string feedback: ""
    readonly property var details: services?.speechDetails ?? ({})
    readonly property var audio: details.last_audio ?? ({})
    readonly property bool active: details.active === true
    readonly property bool hasAudio: Object.keys(audio).length > 0
    readonly property string action: details.playback === true ? "播报" : details.playback === false ? "合成" : "提交"
    readonly property string output: details.playback === true ? "合成后播放" : details.playback === false ? "仅合成" : "未提供输出方式"
    readonly property bool validText: editor.text.trim().length > 0 && editor.text.length <= 280
    readonly property var priorityCodes: ["info", "caution", "urgent"]
    readonly property var serviceRows: [
        {label: "服务启用", value: Diagnostics.boolean(details.active, "是", "否")},
        {label: "当前任务", value: Diagnostics.boolean(details.busy, "处理中", "空闲")},
        {label: "输出方式", value: output},
        {label: "等待数量", value: Diagnostics.number(details.queued), numeric: true},
        {label: "丢弃累计", value: Diagnostics.number(details.dropped), numeric: true},
        {label: "按键取消能力", value: Diagnostics.boolean(details.keyed_cancellation, "支持", "未提供能力")}
    ]
    readonly property var audioRows: [
        {label: "音频格式", value: audio.format ?? "—"},
        {label: "采样率", value: Diagnostics.number(audio.sample_rate, " Hz"), numeric: true},
        {label: "声道数", value: Diagnostics.number(audio.channels), numeric: true},
        {label: "位深", value: Diagnostics.number(audio.bit_depth, " bit"), numeric: true},
        {label: "PCM 帧数", value: Diagnostics.number(audio.frames), numeric: true},
        {label: "音频时长", value: typeof audio.duration_ms === "number" && Number.isFinite(audio.duration_ms) ? audio.duration_ms.toFixed(1) + " ms" : "—", numeric: true}
    ]
    signal narrationIntent(string text, string priority, string key)
    signal exampleIntent
    signal stopIntent
    signal layoutRequested
    signal servicesRequested
    title: "语音播报"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1360
    height: 740
    onClientIDChanged: { if (editor) editor.clear(); feedback = ""; }
    function setText(text) { editor.text = text; }
    function narrationKey(text, priority) {
        // 同一优先级与文本使用稳定键，让宿主去重；不把计时或队列策略放进 UI。
        let hash = 2166136261;
        for (let i = 0; i < text.length; ++i) hash = Math.imul(hash ^ text.charCodeAt(i), 16777619) >>> 0;
        return "operator:" + priority + ":" + hash.toString(16);
    }
    function narrate() {
        if (!active || !connected || !validText) return;
        const text = editor.text.trim(), priority = priorityCodes[prioritySelect.currentIndex];
        feedback = "";
        narrationIntent(text, priority, narrationKey(text, priority));
    }
    Rectangle {
        width: parent.width; height: 100; color: "#202a25"; border.color: Theme.line
        OperatorText { x: 14; y: 8; width: 330; height: 24; text: "引擎 / 音色"; size: 11; color: Theme.muted }
        OperatorText { x: 14; y: 36; width: 330; height: 26; text: String(root.details.engine ?? "—"); textFormat: Text.PlainText; size: 16 }
        OperatorText { x: 14; y: 68; width: 330; height: 24; text: String(root.details.voice ?? "—"); textFormat: Text.PlainText; size: 12; color: Theme.muted }
        OperatorText { x: 368; y: 8; width: parent.width - 670; height: 24; text: "服务反馈"; size: 11; color: Theme.muted }
        OperatorText { x: 368; y: 36; width: parent.width - 670; height: 54; text: root.services?.speechStatus ?? "未提供语音服务状态"; textFormat: Text.PlainText; wrapMode: Text.WordWrap; size: 13; color: Theme.muted }
        OperatorText { x: parent.width - 272; y: 8; width: 258; height: 24; text: "当前输出"; size: 11; color: Theme.muted }
        OperatorText { x: parent.width - 272; y: 36; width: 258; height: 26; text: root.output; size: 15 }
        OperatorText { x: parent.width - 272; y: 68; width: 258; height: 24; text: "等待 " + Diagnostics.number(root.details.queued) + " · 丢弃 " + Diagnostics.number(root.details.dropped); size: 11; color: Theme.muted }
    }
    OperatorSection {
        y: 116; width: (parent.width - 22) / 2; height: parent.height - y - 50
        title: "自定义文本"
        OperatorText { width: parent.width - 118; height: 24; text: editor.text.length > 280 ? "文本超过长度上限" : "文本 · 不超过 280"; size: 12; color: editor.text.length > 280 ? Theme.warning : Theme.muted }
        OperatorText { x: parent.width - 108; width: 108; height: 24; text: editor.text.length + " / 280"; numeric: true; horizontalAlignment: Text.AlignRight; size: 11; color: editor.text.length > 280 ? Theme.warning : Theme.muted }
        ScrollView {
            id: editScroll
            y: 34; width: parent.width; height: 110; clip: true; contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            OperatorTextArea { id: editor; width: editScroll.availableWidth; height: Math.max(editScroll.availableHeight, implicitHeight); label: "语音文本"; placeholderText: "填写需要朗读或合成的文本"; onTextChanged: root.feedback = "" }
        }
        OperatorText { y: 156; width: 120; height: 38; text: "请求优先级"; size: 12; color: Theme.muted }
        OperatorSelect { id: prioritySelect; x: 132; y: 156; width: parent.width - 132; label: "语音请求优先级"; model: ["一般", "注意", "优先"]; currentIndex: 0 }
        OperatorText { y: 208; width: parent.width; height: 42; text: "队列、去重和优先级由当前服务处理。未启用播放时仅合成，不会发出声音。"; wrapMode: Text.WordWrap; size: 11; color: Theme.muted }
        Row {
            y: 264; width: parent.width; spacing: 12
            OperatorButton { width: (parent.width - 12) / 2; text: root.previewOnly ? "演示示例文本" : root.details.playback === true ? "语音试音" : "示例文本合成"; enabled: root.active; onClicked: { root.feedback = ""; root.exampleIntent(); } }
            OperatorButton { width: (parent.width - 12) / 2; text: (root.previewOnly ? "演示" : "") + root.action + "文本"; primary: true; enabled: root.active && root.connected && root.validText; onClicked: root.narrate() }
        }
        OperatorButton { objectName: "speechStopControl"; y: 316; width: parent.width; text: "停止并清空队列"; enabled: root.active; onClicked: { root.feedback = ""; root.stopIntent(); } }
        OperatorText { y: 366; width: parent.width; height: parent.height - y; text: root.feedback || (!root.connected ? "自定义文本需先连接比赛服务。" : !root.active ? "请先启用语音服务；当前入口停用。" : editor.text.length > 280 ? "请将文本缩短至 280 以内；当前不会提交。" : !root.validText ? "请输入非空文本。" : "提交只发出语音请求，不发送机器人操作指令。"); wrapMode: Text.WordWrap; size: 11; color: root.feedback ? Theme.green : Theme.muted }
    }
    OperatorSection {
        x: (parent.width + 22) / 2; y: 116; width: (parent.width - 22) / 2; height: parent.height - y - 50
        title: "服务与音频信息"
        Row {
            width: parent.width; spacing: 12
            OperatorButton { width: (parent.width - 12) / 2; text: "服务 / 队列"; primary: root.detailsTab === 0; onClicked: { root.detailsTab = 0; detailScroll.contentItem.contentY = 0; } }
            OperatorButton { width: (parent.width - 12) / 2; text: "最近音频"; primary: root.detailsTab === 1; onClicked: { root.detailsTab = 1; detailScroll.contentItem.contentY = 0; } }
        }
        OperatorScrollableColumn {
            id: detailScroll
            y: 54; width: parent.width; height: parent.height - y
            OperatorDiagnosticTable { visible: root.detailsTab === 0; width: parent.width; title: "当前服务公开状态"; rows: root.serviceRows }
            OperatorText { visible: root.detailsTab === 0; width: parent.width; height: 52; text: "等待数量与丢弃累计是服务计数，不是逐条队列列表或播放进度。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
            OperatorDiagnosticTable { visible: root.detailsTab === 1 && root.hasAudio; width: parent.width; title: "最近音频参数"; rows: root.audioRows }
            OperatorText { visible: root.detailsTab === 1; width: parent.width; height: root.hasAudio ? 52 : 250; text: root.hasAudio ? "时长是音频本身长度，不是合成耗时；最近参数不表示当前正在播放。" : "尚未提供最近音频参数。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; horizontalAlignment: root.hasAudio ? Text.AlignLeft : Text.AlignHCenter; size: 12; color: Theme.muted }
        }
    }
    OperatorText { y: parent.height - 38; width: parent.width - 416; height: 38; text: root.previewOnly ? "离线绘制样例 · 演示不合成、不播放" : "文本语音与模型建议语音分别提交"; size: 11; color: Theme.muted }
    Row {
        x: parent.width - 404; y: parent.height - 38; spacing: 12
        OperatorButton { width: 196; text: "服务详情"; onClicked: root.servicesRequested() }
        OperatorButton { width: 196; text: "返回面板库"; onClicked: root.layoutRequested() }
    }
}
