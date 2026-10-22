import QtQuick
import QtQuick.Controls
import QtQuick.Window

TextArea {
    id: root
    property string label: ""
    property bool numeric: false
    readonly property real hudScale: Window.window?.ui?.layoutScale ?? 1
    property color backgroundColor: "#232c27"
    property color borderColor: Theme.line
    property color focusBorderColor: Theme.green
    property alias borderWidth: areaBackground.border.width
    property real cornerRadius: 2
    padding: 12
    font.family: numeric ? Theme.numberFamily : Theme.fontFamily
    font.pixelSize: Math.max(14, 9.5 / Math.max(0.1, hudScale))
    color: Theme.text
    placeholderTextColor: Theme.muted
    textFormat: TextEdit.PlainText
    wrapMode: TextEdit.Wrap
    selectByMouse: true
    selectionColor: Theme.green
    selectedTextColor: "#1a2421"
    Accessible.name: label
    background: Rectangle {
        id: areaBackground
        color: root.backgroundColor
        border.color: root.activeFocus ? root.focusBorderColor : root.borderColor
        radius: root.cornerRadius
    }
}
