import QtQuick

// Drawing shell for exact per-field grants. The ordinary editor supplies
// stable count-based delegates and handles all draft mutations.
Item {
    id: root
    objectName: "teamSetupGrantForm"
    implicitWidth: 1300
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property alias addControl: addButton
    property string label: "允许共享的字段"
    property int entryCount: 0
    property Component rowDelegate: null
    readonly property real rowDelegateWidth: contentColumn.width
    property bool addEnabled: false
    property real sectionSpacing: 10
    property real fieldSpacing: 8
    property real columnGap: 12
    property real fieldBreakpoint: 600
    property real purposeWideBreakpoint: 760
    property real purposeCompactBreakpoint: 420
    property real purposeSpacing: 8
    property real addWidth: 210
    property real removeWidth: 156
    property real controlHeight: 38
    property real labelHeight: 26
    property real labelGap: 4
    property real hintGap: 8
    property real minimumHintHeight: 26
    property real hintBottomPadding: 4
    property real labelSize: 12
    property real noteSize: 12
    property real inputSize: 14
    property real hintSize: 11
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color secondaryTextColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property color inputSurfaceColor: "#232c27"
    property string fontFamily: Theme.fontFamily
    property string inputFontFamily: root.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.sectionSpacing
        OperatorText {
            width: parent.width
            height: implicitHeight
            text: root.label + " · 精确匹配来源与数据项；未勾选用途的字段不会被授权使用。"
            size: root.noteSize
            color: root.secondaryTextColor
            font.family: root.fontFamily
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        Repeater { model: root.entryCount; delegate: root.rowDelegate }
        OperatorButton {
            id: addButton
            width: Math.min(root.addWidth, parent.width)
            height: root.controlHeight
            text: "添加明确字段"
            enabled: root.addEnabled
            textColor: root.textColor
            font.family: root.fontFamily
            font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
        }
    }
}
