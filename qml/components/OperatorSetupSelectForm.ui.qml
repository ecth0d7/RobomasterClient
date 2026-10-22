import QtQuick

// Shared label/select/hint drawing. Selection intent belongs to the wrapper.
Item {
    id: root
    implicitWidth: 360
    implicitHeight: select.y + select.height + root.hintGap + note.height
    height: implicitHeight
    property alias selectControl: select
    property string label: ""
    property string hint: ""
    property string error: ""
    property var choices: []
    property int selectedIndex: -1
    property string selectionText: "尚未选择"
    property bool editable: false
    property real fieldSpacing: 8
    property real labelHeight: 26
    property real labelGap: 4
    property real controlHeight: 38
    property real hintGap: root.fieldSpacing
    property real minimumHintHeight: 26
    property real hintBottomPadding: 4
    property real noteSize: 11
    property real labelSize: 12
    property real inputSize: 14
    property real hintSize: root.noteSize
    property string fontFamily: Theme.fontFamily
    property string inputFontFamily: root.fontFamily
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color secondaryTextColor: root.mutedColor
    property color warningColor: Theme.warning
    property color inputSurfaceColor: "#232c27"
    property color inputBorderColor: Theme.line

    OperatorText {
        id: labelText
        width: parent.width
        height: Math.max(root.labelHeight, implicitHeight)
        text: root.label
        size: root.labelSize
        color: root.secondaryTextColor
        font.family: root.fontFamily
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
    OperatorSelect {
        id: select
        y: labelText.height + root.labelGap
        width: parent.width
        height: root.controlHeight
        label: root.label
        model: root.choices
        currentIndex: root.selectedIndex
        displayText: root.selectionText
        emptyText: root.selectionText
        enabled: root.editable
        textColor: root.textColor
        backgroundColor: root.inputSurfaceColor
        borderColor: root.inputBorderColor
        font.family: root.inputFontFamily
        font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
    }
    OperatorText {
        id: note
        y: select.y + select.height + root.hintGap
        width: parent.width
        height: Math.max(root.minimumHintHeight,
                         implicitHeight + root.hintBottomPadding)
        text: root.error || root.hint
        size: root.hintSize
        font.family: root.fontFamily
        color: root.error ? root.warningColor : root.secondaryTextColor
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
}
