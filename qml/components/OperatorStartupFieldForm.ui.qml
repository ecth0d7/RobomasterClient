import QtQuick

// Shared label/input/hint drawing. Ordinary wrappers own edits and services.
Item {
    id: root
    implicitWidth: 360
    implicitHeight: input.y + input.height + root.hintGap + note.height
    height: implicitHeight
    property alias inputControl: input
    property string label: ""
    property string value: ""
    property string hint: ""
    property string error: ""
    property bool editable: false
    property int maximumLength: 512
    property real labelHeight: 26
    property real labelGap: 4
    property real controlHeight: 38
    property real hintGap: 8
    property real minimumHintHeight: 26
    property real hintBottomPadding: 4
    property real labelSize: 12
    property real inputSize: 14
    property real hintSize: 11
    property string fontFamily: Theme.fontFamily
    property string inputFontFamily: root.fontFamily
    property color textColor: Theme.text
    property color secondaryTextColor: Theme.muted
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
    OperatorInput {
        id: input
        y: labelText.height + root.labelGap
        width: parent.width
        height: root.controlHeight
        label: root.label
        enabled: root.editable
        text: root.value
        maximumLength: root.maximumLength
        color: enabled ? root.textColor : root.secondaryTextColor
        backgroundColor: root.inputSurfaceColor
        borderColor: root.inputBorderColor
        font.family: root.inputFontFamily
        font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
    }
    OperatorText {
        id: note
        y: input.y + input.height + root.hintGap
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
