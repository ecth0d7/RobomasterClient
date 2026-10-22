import QtQuick

Item {
    id: root
    implicitWidth: 360
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property alias selectControl: select
    property string label: "明确选择"
    property string hint: ""
    property var choices: []
    property int selectedIndex: -1
    property string selectionText: "尚未选择"
    property bool editable: false
    property real fieldSpacing: 8
    property real controlHeight: 38
    property real noteSize: 12
    property real inputSize: 14
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property string fontFamily: Theme.fontFamily
    Column {
        id: contentColumn
        width: root.width
        spacing: root.fieldSpacing
        OperatorAdviceSetupNoteForm { width: parent.width; text: root.label; size: root.noteSize; color: root.mutedColor; fontFamily: root.fontFamily }
        OperatorSelect {
            id: select
            width: parent.width
            height: root.controlHeight
            label: root.label
            model: root.choices
            currentIndex: root.selectedIndex
            displayText: root.selectionText
            emptyText: root.selectionText
            enabled: root.editable
            textColor: root.textColor
            font.family: root.fontFamily
            font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
        }
        OperatorAdviceSetupNoteForm { width: parent.width; visible: root.hint.length > 0; text: root.hint; size: root.noteSize; color: root.mutedColor; fontFamily: root.fontFamily }
    }
}
