import QtQuick

Item {
    id: root
    property var message: null
    property bool connected: false
    property bool previewOnly: false
    property string feedback: ""
    property string errorField: ""
    property var values: ({})
    property var included: ({})
    signal submitRequested(string topic, var fields)
    onMessageChanged: { values = ({}); included = ({}); feedback = ""; errorField = ""; }
    function setField(name, value, include) {
        const next = Object.assign({}, values);
        const flags = Object.assign({}, included);
        next[name] = value;
        flags[name] = include;
        values = next;
        included = flags;
    }
    function submit() {
        if (!connected || previewOnly || !message) return;
        errorField = "";
        const fields = {};
        for (const field of message.fields) {
            if (included[field.name] !== true) continue;
            const text = String(values[field.name] ?? "").trim();
            if (field.type === "bool") fields[field.name] = values[field.name] === true;
            else if (field.type === "bytes") {
                const hex = text.replace(/\s/g, "");
                if (!/^(?:[0-9a-fA-F]{2})*$/.test(hex)) { errorField = field.name; feedback = field.title + "：请输入成对十六进制字节"; return; }
                fields[field.name] = hex;
            } else {
                const number = Number(text);
                if (!text || !Number.isFinite(number) || (field.type !== "float" && !Number.isInteger(number))) {
                    errorField = field.name; feedback = field.title + "：请输入有效" + field.type + "数值"; return;
                }
                fields[field.name] = number;
            }
        }
        if (Object.keys(fields).length === 0) { feedback = "请勾选至少一个发送字段"; return; }
        feedback = "正在提交…";
        submitRequested(message.topic, fields);
    }
    OperatorScrollableColumn {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: feedbackText.top
        anchors.bottomMargin: 12
        Repeater {
            model: root.message?.fields ?? []
            delegate: Item {
                id: row
                required property var modelData
                width: parent.width
                height: modelData.note || root.errorField === modelData.name ? 104 : 76
                OperatorCheckBox {
                    id: includeField
                    width: 250
                    text: row.modelData.title
                    checked: root.included[row.modelData.name] === true
                    onToggled: root.setField(row.modelData.name, root.values[row.modelData.name] ?? (row.modelData.type === "bool" ? false : ""), checked)
                }
                OperatorText {
                    y: 40; width: 250; height: 28; size: 11; color: Theme.muted
                    text: row.modelData.name + " · " + row.modelData.type
                }
                OperatorInput {
                    x: 270; width: parent.width - x; height: 38
                    visible: row.modelData.type !== "bool"
                    enabled: includeField.checked
                    label: row.modelData.title + "（" + row.modelData.name + "）"
                    text: String(root.values[row.modelData.name] ?? "")
                    placeholderText: row.modelData.type === "bytes" ? "十六进制，如 00 01 ff；空值表示空字节" : "输入数值，0 是有效值"
                    onTextEdited: root.setField(row.modelData.name, text, includeField.checked)
                }
                OperatorCheckBox {
                    x: 270; width: parent.width - x
                    visible: row.modelData.type === "bool"
                    enabled: includeField.checked
                    text: checked ? "true · 是／按下" : "false · 否／松开"
                    checked: root.values[row.modelData.name] === true
                    onToggled: root.setField(row.modelData.name, checked, includeField.checked)
                }
                OperatorText {
                    y: 72; width: parent.width; height: 32; size: 11; color: root.errorField === row.modelData.name ? Theme.warning : Theme.muted
                    text: root.errorField === row.modelData.name ? root.feedback : row.modelData.note; wrapMode: Text.WordWrap; textFormat: Text.PlainText
                }
            }
        }
    }
    OperatorText {
        id: feedbackText
        anchors.left: parent.left; anchors.right: sendButton.left; anchors.rightMargin: 16
        anchors.bottom: parent.bottom; height: 64; size: 12
        text: root.feedback || (!root.connected ? "连接本机服务器后可发送" : "未勾选字段将被省略；0、false、空字节会按原值发送。")
        wrapMode: Text.WordWrap; textFormat: Text.PlainText
    }
    OperatorButton {
        id: sendButton
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
        width: 190; text: "发送到 MQTT 服务器"
        enabled: root.connected && !root.previewOnly && root.message !== null
        primary: true
        onClicked: root.submit()
    }
}
