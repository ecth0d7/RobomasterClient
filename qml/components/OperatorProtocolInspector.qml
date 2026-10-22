import QtQuick
import QtQuick.Controls
import "OperatorProtocolSchema.js" as ProtocolSchema
import "OperatorProtocolData.js" as ProtocolData
import "OperatorData.js" as Data

OperatorPanelFrame {
    id: root
    property var telemetry: null
    property var schema: ProtocolSchema.messages
    property bool previewOnly: false
    property bool connected: false
    property alias commandFeedback: commandEditor.feedback
    property alias commandEditorObject: commandEditor
    signal commandIntent(string topic, var fields)
    property int directionTab: 0
    property string selectedTopic: "GameStatus"
    property var extraMessages: []
    property var extraFieldKeys: []
    readonly property var availableMessages: schema.filter(message => message.direction === (directionTab === 0 ? "receive" : "send")).concat(directionTab === 0 ? extraMessages : [])
    readonly property var filteredMessages: {
        const query = search.text.trim().toLowerCase();
        return availableMessages.filter(message => !query || (message.title + " " + message.topic).toLowerCase().includes(query)
                                        || message.fields.some(field => (field.title + " " + field.name).toLowerCase().includes(query)));
    }
    readonly property var selectedMessage: filteredMessages.find(message => message.topic === selectedTopic) ?? filteredMessages[0] ?? null
    readonly property var currentData: visible && selectedMessage?.direction === "receive" ? telemetry?.[selectedMessage.group] ?? ({}) : ({})
    readonly property string groupState: visible && selectedMessage?.direction === "receive" ? telemetry?.freshness?.[selectedMessage.group] ?? "missing" : "definition"
    signal layoutRequested
    title: "2026 MQTT 字段收发"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1440
    height: 780
    onFilteredMessagesChanged: if (!filteredMessages.some(message => message.topic === selectedTopic)) selectedTopic = filteredMessages[0]?.topic ?? ""
    onSelectedMessageChanged: Qt.callLater(resetFieldScroll)
    onCurrentDataChanged: refreshExtraFields()
    onTelemetryChanged: refreshExtraMessages()
    onSchemaChanged: refreshExtraMessages()
    Component.onCompleted: refreshExtraMessages()
    onVisibleChanged: if (visible) { refreshExtraMessages(); refreshExtraFields(); }
    function resetFieldScroll() {
        if (fields.contentItem) fields.contentItem.contentY = 0;
    }
    function refreshExtraMessages() {
        if (!visible) return;
        const keys = Object.keys(telemetry?.freshness ?? {}).filter(key => !schema.some(message => message.group === key)).sort();
        if (JSON.stringify(keys) !== JSON.stringify(extraMessages.map(message => message.group)))
            extraMessages = keys.map(key => ({topic: key, title: key, group: key, direction: "receive", fields: []}));
    }
    function refreshExtraFields() {
        const keys = ProtocolData.extraFields(currentData, selectedMessage?.fields ?? []);
        // 收到同一组新数值时不重建字段控件；只有字段集合变化才更换额外字段列表。
        if (JSON.stringify(keys) !== JSON.stringify(extraFieldKeys)) extraFieldKeys = keys;
    }
    Connections {
        target: root.telemetry
        ignoreUnknownSignals: true
        function onFreshnessChanged() { root.refreshExtraMessages(); }
    }
    Item {
        width: 340
        height: parent.height - 56
        Row {
            width: parent.width
            spacing: 12
            OperatorButton { width: (parent.width - 12) / 2; text: "接收遥测 · " + root.schema.filter(message => message.direction === "receive").length; primary: root.directionTab === 0; onClicked: { root.directionTab = 0; fields.contentItem.contentY = 0; } }
            OperatorButton { width: (parent.width - 12) / 2; text: "编辑发送 · " + root.schema.filter(message => message.direction === "send").length; primary: root.directionTab === 1; onClicked: { root.directionTab = 1; fields.contentItem.contentY = 0; } }
        }
        OperatorInput { id: search; y: 52; width: parent.width; label: "搜索协议消息或字段"; placeholderText: "名称、消息或字段" }
        OperatorText { y: 94; width: parent.width; height: 24; text: "匹配 " + root.filteredMessages.length + " 条消息"; size: 11; color: Theme.muted }
        OperatorScrollableColumn {
            y: 122
            width: parent.width
            height: parent.height - y
            entrySpacing: 6
            OperatorText { width: parent.width; height: 80; visible: root.filteredMessages.length === 0; text: "没有匹配的消息\n修改或清空搜索内容"; wrapMode: Text.WordWrap; size: 12; color: Theme.muted }
            Repeater {
                model: root.filteredMessages
                Button {
                    id: messageButton
                    required property var modelData
                    width: parent.width
                    height: 68
                    Accessible.name: modelData.title + " " + modelData.topic
                    contentItem: Item {
                        OperatorText { y: 2; width: parent.width; height: 28; text: messageButton.modelData.title; textFormat: Text.PlainText; size: 13 }
                        OperatorText { y: 32; width: parent.width; height: 24; text: messageButton.modelData.topic; textFormat: Text.PlainText; size: 11; color: Theme.muted }
                    }
                    background: Rectangle {
                        color: root.selectedMessage?.topic === messageButton.modelData.topic ? "#345c4d" : messageButton.hovered ? "#34443b" : "#222c26"
                        border.color: messageButton.activeFocus ? Theme.green : root.selectedMessage?.topic === messageButton.modelData.topic ? "#699780" : "#344339"
                    }
                    onClicked: { root.selectedTopic = modelData.topic; fields.contentItem.contentY = 0; }
                }
            }
        }
    }
    Item {
        x: 356
        width: parent.width - x
        height: parent.height - 56
        OperatorText { width: parent.width - 120; height: 32; text: root.selectedMessage?.title ?? "没有匹配消息"; textFormat: Text.PlainText; size: 17 }
        OperatorText {
            x: parent.width - 108; width: 108; height: 32
            text: ({fresh: "分组有效", stale: "分组旧数据", missing: "尚未收到", definition: "发送字段定义"})[root.groupState] ?? "未知状态"
            color: root.groupState === "fresh" ? Theme.green : root.groupState === "stale" ? Theme.warning : Theme.muted
            size: 11; horizontalAlignment: Text.AlignRight
        }
        OperatorText { y: 36; width: parent.width; height: 26; text: root.selectedMessage ? root.selectedMessage.topic + " · " + root.selectedMessage.fields.length + " 个定义字段" : ""; textFormat: Text.PlainText; size: 12; color: Theme.muted }
        OperatorText {
            y: 68; width: parent.width; height: 48
            text: root.directionTab === 0 ? "零、false 和空数组保留原值；未收到显示 —。数组、字节与长文本可展开查看。" : "勾选并编辑要发送的字段；使用当前机器人身份、协议校验、权限和发送频率。执行结果查看回传遥测与服务器接收记录。"
            wrapMode: Text.WordWrap; size: 11; color: Theme.muted
        }
        OperatorProtocolCommandEditor {
            id: commandEditor
            objectName: "protocolCommandEditor"
            y: 122
            width: parent.width
            height: parent.height - y
            visible: root.directionTab === 1
            message: root.directionTab === 1 ? root.selectedMessage : null
            connected: root.connected
            previewOnly: root.previewOnly
            onSubmitRequested: (topic, values) => root.commandIntent(topic, values)
        }
        OperatorScrollableColumn {
            id: fields
            visible: root.directionTab === 0
            y: 122
            width: parent.width
            height: parent.height - y
            entrySpacing: 8
            Repeater {
                model: root.selectedMessage?.fields ?? []
                OperatorProtocolField {
                    required property var modelData
                    width: parent.width
                    field: modelData
                    value: root.currentData[modelData.name]
                    schema: root.schema
                    fieldState: root.directionTab === 1 ? "definition" : Data.state(root.telemetry, root.selectedMessage?.group, modelData.name)
                }
            }
            Repeater {
                model: root.extraFieldKeys
                OperatorProtocolField {
                    required property string modelData
                    width: parent.width
                    field: ({name: modelData, title: modelData, type: "扩展字段", cardinality: "singular", note: "状态接口提供的额外字段"})
                    value: root.currentData[modelData]
                    schema: root.schema
                    fieldState: Data.state(root.telemetry, root.selectedMessage?.group, modelData)
                }
            }
        }
    }
    OperatorText { y: parent.height - 38; width: parent.width - 220; height: 38; text: root.previewOnly ? "离线绘制样例 · 未连接服务" : "2026 V2.0.0 · 25类接收 / 11类发送 · 当前会话"; size: 11; color: Theme.muted }
    OperatorButton { x: parent.width - 200; y: parent.height - 38; width: 200; text: "返回面板库"; onClicked: root.layoutRequested() }
}
