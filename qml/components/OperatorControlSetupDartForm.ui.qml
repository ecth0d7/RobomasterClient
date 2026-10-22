import QtQuick

// One stable, editable drawing row. The wrapper owns permission and draft changes.
Item {
    id: root
    objectName: "controlSetupDartEntryForm"
    implicitWidth: 320
    implicitHeight: root.controlHeight
    width: implicitWidth
    height: implicitHeight
    property alias checkControl: checkBox
    property string text: "未提供历史飞镖入口"
    property bool checked: false
    property bool editable: false
    property real controlHeight: 38
    property real inputSize: 14
    property color textColor: Theme.text
    property string fontFamily: Theme.fontFamily

    OperatorCheckBox {
        id: checkBox
        anchors.fill: parent
        text: root.text
        checked: root.checked
        enabled: root.editable
        textColor: root.textColor
        font.family: root.fontFamily
        font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
    }
}
