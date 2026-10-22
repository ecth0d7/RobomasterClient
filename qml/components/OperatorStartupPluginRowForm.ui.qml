import QtQuick

// A core-role selector only; metadata, choice mapping and edits belong to the wrapper.
Item {
    id: root
    objectName: "startupPluginRowForm"
    implicitWidth: 600
    implicitHeight: selection.implicitHeight
    height: implicitHeight
    property alias selectControl: selection.selectControl
    property string titleText: "插件角色未接通"
    property string selectionLabel: "下次启动插件"
    property string draftText: "草稿ID：未提供"
    property var choices: []
    property int selectedIndex: -1
    property string selectionText: "本地发现清单尚未公开"
    property bool inputEditable: false
    property real labelHeight: 26
    property real labelGap: 4
    property real controlHeight: 38
    property real hintGap: 8
    property real minimumHintHeight: 26
    property real hintBottomPadding: 4
    property real labelSize: 12
    property real inputSize: 14
    property real noteSize: 11
    property string fontFamily: Theme.fontFamily
    property string inputFontFamily: root.fontFamily
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color inputSurfaceColor: "#232c27"
    property color inputBorderColor: Theme.line

    OperatorSetupSelectForm {
        id: selection
        width: parent.width
        label: root.titleText
        hint: root.draftText
        choices: root.choices
        selectedIndex: root.selectedIndex
        selectionText: root.selectionText
        editable: root.inputEditable
        labelHeight: root.labelHeight
        labelGap: root.labelGap
        controlHeight: root.controlHeight
        hintGap: root.hintGap
        minimumHintHeight: root.minimumHintHeight
        hintBottomPadding: root.hintBottomPadding
        labelSize: root.labelSize
        inputSize: root.inputSize
        noteSize: root.noteSize
        fontFamily: root.fontFamily
        inputFontFamily: root.inputFontFamily
        textColor: root.textColor
        mutedColor: root.mutedColor
        warningColor: root.warningColor
        inputSurfaceColor: root.inputSurfaceColor
        inputBorderColor: root.inputBorderColor
        selectControl.label: root.selectionLabel
    }
}
