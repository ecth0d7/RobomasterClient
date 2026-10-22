import QtQuick
import QtQuick.Controls
import "OperatorByteData.js" as Bytes
import "OperatorData.js" as Data

OperatorPanelFrame {
    id: root
    property var telemetry: null
    property int clientID: 3
    property bool previewOnly: false
    property bool submissionAvailable: false
    property string unavailableReason: "生产发送入口未接通"
    property string feedback: ""
    readonly property string receiveState: Data.state(telemetry, "customByteBlock", "data")
    // 部署视频也走这条高频字节流。关闭的查看器不应继续拆字节、
    // 格式化并更新所有行；重开时绑定直接读取最新原始缓存。
    readonly property var receiveValue: visible ? Bytes.received(telemetry?.customByteBlock?.data)
                                               : ({valid: false, count: null, bytes: [], hex: "", error: ""})
    readonly property var draft: Bytes.parse(editor.text, formatSelect.currentIndex, 30)
    property real columnWidth: (bodyWidth - 22) / 2
    property real bodyWidth: width - 2 * contentMargin
    signal byteIntent(var fields)
    signal layoutRequested
    title: "自定义字节"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1360
    height: 720
    onClientIDChanged: { if (editor) editor.clear(); feedback = ""; }
    function copyReceivedToDraft() {
        if (receiveState === "missing" || !receiveValue.valid || receiveValue.count > 30) return;
        formatSelect.currentIndex = 0;
        editor.text = Bytes.spaced(receiveValue.hex);
        feedback = receiveState === "stale" ? "已复制旧数据到草稿，请核对内容；尚未发送。" : "已复制到编辑草稿；尚未发送。";
    }
    function copyReceivedHex() {
        if (receiveState === "missing" || !receiveValue.valid || receiveValue.count === 0) return;
        receiveCopy.selectAll();
        receiveCopy.copy();
        receiveCopy.deselect();
        feedback = "已复制接收内容的十六进制；不会自动发送。";
    }
    function setDraft(format, text) {
        formatSelect.currentIndex = format;
        editor.text = text;
    }
    function submitDraft() {
        if (!draft.valid) return;
        if (previewOnly) feedback = "离线演示：草稿已确认，未发送数据。";
        else if (submissionAvailable) byteIntent({data: draft.hex});
    }
    Item {
        width: root.columnWidth
        height: parent.height - 56
        OperatorText { width: parent.width; height: 30; text: "机器人 → 客户端"; size: 17 }
        OperatorText { y: 34; width: parent.width; height: 28; text: "CustomByteBlock · 接收上限 300 字节"; size: 12; color: Theme.muted }
        Rectangle {
            y: 76; width: parent.width; height: 66
            color: "#202a25"; border.color: Theme.line
            OperatorText { x: 12; y: 10; width: parent.width - 140; height: 28; text: root.receiveState === "missing" || !root.receiveValue.valid ? "— 字节" : root.receiveValue.count + " 字节"; numeric: true; size: 17 }
            OperatorText { x: parent.width - 130; y: 10; width: 118; height: 28; text: root.receiveState !== "missing" && !root.receiveValue.valid ? "格式异常" : ({fresh: "有效", stale: "旧数据", missing: "尚未收到"})[root.receiveState] ?? "未知状态"; horizontalAlignment: Text.AlignRight; size: 12; color: root.receiveState !== "missing" && !root.receiveValue.valid || root.receiveState === "stale" ? Theme.warning : root.receiveState === "fresh" ? Theme.green : Theme.muted }
        }
        Row {
            y: 156; width: parent.width; spacing: 12
            OperatorText { width: 58; height: 26; text: "偏移"; size: 11; color: Theme.muted }
            OperatorText { width: parent.width - 204; height: 26; text: "十六进制 · 每行 8 字节"; size: 11; color: Theme.muted }
            OperatorText { width: 122; height: 26; text: "ASCII"; size: 11; color: Theme.muted }
        }
        Rectangle {
            y: 186; width: parent.width; height: parent.height - y - 90
            color: "#1b241f"; border.color: Theme.line
            ListView {
                id: receiveList
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                model: root.receiveState !== "missing" && root.receiveValue.valid ? Math.ceil(root.receiveValue.count / 8) : 0
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    required property int index
                    readonly property var rowBytes: root.receiveValue.bytes.slice(index * 8, index * 8 + 8)
                    width: ListView.view.width - 12
                    height: 40
                    Rectangle { anchors.fill: parent; color: parent.index % 2 ? "#202a25" : "#28332d" }
                    OperatorText { x: 4; width: 58; height: parent.height; text: (parent.index * 8).toString(16).padStart(4, "0"); size: 12; numeric: true; color: Theme.muted }
                    OperatorText { x: 70; width: parent.width - 196; height: parent.height; text: parent.rowBytes.map(value => value.toString(16).padStart(2, "0")).join(" "); size: 12; numeric: true }
                    OperatorText { x: parent.width - 118; width: 114; height: parent.height; text: Bytes.ascii(parent.rowBytes); textFormat: Text.PlainText; size: 12; numeric: true; color: Theme.muted }
                }
                ScrollBar.vertical: ScrollBar {
                    id: receiveBar
                    width: 8
                    policy: receiveList.contentHeight > receiveList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    contentItem: Rectangle { implicitWidth: 6; implicitHeight: 40; radius: 3; color: receiveBar.pressed ? Theme.green : Theme.muted }
                    background: Rectangle { color: "#14201a"; radius: 3 }
                }
            }
            OperatorText {
                anchors.fill: parent; anchors.margins: 18
                visible: receiveList.count === 0
                text: root.receiveState === "missing" ? "尚未收到自定义数据。" : root.receiveValue.valid ? "已收到空载荷 · 0 字节" : root.receiveValue.error
                wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; size: 13; color: Theme.muted
            }
        }
        OperatorText { y: parent.height - 78; width: parent.width; height: 34; text: "不可打印字节显示 ·；ASCII 只作观察，不自动解读业务协议。"; wrapMode: Text.WordWrap; size: 11; color: Theme.muted }
        Row {
            y: parent.height - 38; spacing: 12
            OperatorButton { width: 220; text: "复制到编辑草稿"; enabled: root.receiveState !== "missing" && root.receiveValue.valid && root.receiveValue.count <= 30; onClicked: root.copyReceivedToDraft() }
            OperatorButton { width: 190; text: "复制十六进制"; enabled: root.receiveState !== "missing" && root.receiveValue.valid && root.receiveValue.count > 0; onClicked: root.copyReceivedHex() }
        }
    }
    Item {
        x: root.columnWidth + 22
        width: root.columnWidth
        height: parent.height - 56
        OperatorText { width: parent.width; height: 30; text: "客户端 → 机器人"; size: 17 }
        OperatorText { y: 34; width: parent.width; height: 28; text: "CustomControl · 发送上限 30 字节"; size: 12; color: Theme.muted }
        OperatorSelect { id: formatSelect; y: 76; width: parent.width - 126; label: "自定义数据输入格式"; model: ["十六进制", "十进制字节", "文本 · UTF-8"]; currentIndex: 0; onActivated: root.feedback = "" }
        OperatorText { x: parent.width - 116; y: 76; width: 116; height: 38; text: (root.draft.count ?? "—") + " / 30 字节"; numeric: true; horizontalAlignment: Text.AlignRight; size: 12; color: root.draft.valid ? Theme.muted : Theme.warning }
        ScrollView {
            id: editorScroll
            y: 130; width: parent.width; height: 150
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            OperatorTextArea {
                id: editor
                width: editorScroll.availableWidth
                height: Math.max(editorScroll.availableHeight, implicitHeight)
                label: "自定义发送内容"
                numeric: formatSelect.currentIndex !== 2
                placeholderText: formatSelect.currentIndex === 0 ? "例如 01 02 03 04" : formatSelect.currentIndex === 1 ? "例如 1 2 3 255" : "输入文本，按 UTF-8 字节计数"
                onTextChanged: root.feedback = ""
            }
        }
        OperatorText { y: 294; width: parent.width; height: 44; text: root.draft.valid ? formatSelect.currentIndex === 2 ? "文本按 UTF-8 编码；字节数可能多于字符数。" : "每项是一字节；格式化后的内容在下方显示。" : root.draft.error; wrapMode: Text.WordWrap; size: 12; color: root.draft.valid ? Theme.muted : Theme.warning }
        OperatorText { y: 346; width: parent.width; height: 26; text: "待提交的十六进制内容"; size: 13 }
        ScrollView {
            id: draftScroll
            y: 382; width: parent.width; height: 110
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            OperatorTextArea { width: draftScroll.availableWidth; height: Math.max(draftScroll.availableHeight, implicitHeight); readOnly: true; numeric: true; label: "待提交十六进制"; text: root.draft.valid ? root.draft.count ? Bytes.spaced(root.draft.hex) : "空载荷 · 0 字节" : "输入有效内容后显示" }
        }
        OperatorText { y: 506; width: parent.width; height: parent.height - y; text: root.feedback || (!root.previewOnly && !root.submissionAvailable ? root.unavailableReason : "") || "编辑草稿与接收数据独立；请确认自定义数据的业务约定。"; wrapMode: Text.WordWrap; size: 12; color: root.feedback ? Theme.green : Theme.muted }
    }
    OperatorText { y: parent.height - 38; width: parent.width - 416; height: 38; text: root.previewOnly ? "离线绘制样例 · 预览提交不发送数据" : "数据按自定义业务约定解释"; size: 11; color: Theme.muted }
    Row {
        x: parent.width - 404; y: parent.height - 38; spacing: 12
        OperatorButton { width: 130; text: "返回面板库"; onClicked: root.layoutRequested() }
        OperatorButton { width: 120; text: "清空草稿"; onClicked: editor.clear() }
        OperatorButton { width: 130; text: root.previewOnly ? "预览提交" : "提交数据"; primary: true; enabled: root.draft.valid && (root.previewOnly || root.submissionAvailable); onClicked: root.submitDraft() }
    }
    // 使用 Qt 的纯文本复制接口，避免引入特定操作系统的剪贴板插件。
    OperatorTextArea { id: receiveCopy; visible: false; readOnly: true; text: root.receiveValue.valid ? Bytes.spaced(root.receiveValue.hex) : "" }
}
