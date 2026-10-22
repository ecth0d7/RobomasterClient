import QtQuick
import QtQuick.Controls

// 2026手册第09页。外框沿用选手端素材，所有内容留在发光框的内槽。
Item {
    id: root
    property bool robotOffline: false
    property bool complete: false
    property bool progressKnown: false
    property real progress: 0
    property string cost: "—"
    property bool paidAllowed: false
    property bool freeAllowed: false
    property string paidReason: ""
    property string freeReason: ""
    signal requested(string kind)
    implicitWidth: 450
    implicitHeight: 210
    width: implicitWidth
    height: implicitHeight
    readonly property color accent: robotOffline ? Theme.warning : Theme.actionGreen

    // 原发光框中间已有约50%透明底，再叠一层会遮住大部分图传。
    BorderImage {
        anchors.fill: parent
        source: root.robotOffline ? "../resources/player/gamephase/MaskTips-Ad-Yellow-320.png"
                                  : "../resources/player/gamephase/MaskTips-Ad-320.png"
        border { left: 22; right: 22; top: 10; bottom: 10 }
    }
    OperatorText {
        x: 36; y: 20; width: parent.width - 72; height: 34
        text: root.robotOffline ? "机器人离线，复活暂停" : root.complete ? "复活读条完成" : "复活中"
        horizontalAlignment: Text.AlignHCenter
        size: 22; minimumSize: 0; color: root.accent
    }
    Rectangle {
        x: 96; y: 65; width: parent.width - 192; height: 7
        color: "#99595652"
        Rectangle {
            width: parent.width * root.progress; height: parent.height
            color: root.accent
            visible: root.progressKnown
        }
    }
    Row {
        x: 50; y: 88; spacing: 12
        Repeater {
            model: ["paid", "free"]
            Button {
                id: action
                required property string modelData
                readonly property bool paid: modelData === "paid"
                objectName: paid ? "respawnPaidButton" : "respawnFreeButton"
                width: 169; height: 36
                enabled: paid ? root.paidAllowed : root.freeAllowed
                text: paid ? root.cost + "  立即复活 [F1]" : "免费复活 [Y]"
                Accessible.name: text
                background: Rectangle {
                    color: action.down ? "#6950a47c" : action.hovered ? "#323c6856" : "#182a352d"
                    border.width: 1
                    border.color: action.enabled ? "#89b9c9b7" : "#5463635b"
                }
                contentItem: OperatorText {
                    text: action.text; size: 13; minimumSize: 0
                    horizontalAlignment: Text.AlignHCenter
                    color: action.enabled ? root.accent : "#8b9189"
                }
                ToolTip.visible: hovered && !enabled
                ToolTip.text: paid ? root.paidReason : root.freeReason
                onClicked: root.requested(modelData)
            }
        }
    }
    Rectangle {
        x: 50; y: 150; width: 36; height: 18; radius: 2; color: "#d09e38"
        OperatorText { anchors.fill: parent; text: "TIPS"; size: 11; minimumSize: 0; horizontalAlignment: Text.AlignHCenter }
    }
    OperatorText {
        x: 96; y: 143; width: parent.width - x - 44; height: 42
        size: 12; minimumSize: 0; wrapMode: Text.Wrap; elide: Text.ElideNone
        text: "可消耗金币兑换立即复活，或在复活读条完成后确认免费复活。"
        color: "#c4d1c0"
    }
    OperatorActionShortcut { scopeItem: root; actionId: "respawnPaid"; available: root.visible && root.paidAllowed; onActivated: root.requested("paid") }
    OperatorActionShortcut { scopeItem: root; actionId: "respawnFree"; available: root.visible && root.freeAllowed; onActivated: root.requested("free") }
}
