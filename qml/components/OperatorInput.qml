import QtQuick
import QtQuick.Controls
import QtQuick.Window

TextField {
    id: root
    property string label: ""
    readonly property real hudScale: Window.window?.ui?.layoutScale ?? 1
    property color backgroundColor: "#232c27"
    property color disabledBackgroundColor: "#1d2420"
    property color borderColor: Theme.line
    property color focusBorderColor: Theme.green
    property alias borderWidth: inputOutline.thickness
    implicitWidth: 300
    implicitHeight: 38
    padding: 10
    font.family: Theme.fontFamily
    font.pixelSize: Math.max(14, 9.5 / Math.max(0.1, hudScale))
    color: root.enabled ? Theme.text : Theme.muted
    placeholderTextColor: Theme.muted
    selectionColor: Theme.green
    selectedTextColor: "#1a2421"
    selectByMouse: true
    Accessible.name: label
    background: Rectangle {
        color: root.enabled ? root.backgroundColor : root.disabledBackgroundColor
        OperatorOutline { id: inputOutline; color: root.activeFocus ? root.focusBorderColor : root.borderColor }
    }
}
