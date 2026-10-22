import QtQuick

// A single preformatted roster row. Rule numbers are labels rather than
// invented login IDs; no count/role default is presented as a real roster.
Item {
    id: root
    objectName: "seasonRoleForm"
    implicitWidth: 320
    implicitHeight: Math.max(root.rowHeight, countTextItem.y + countTextItem.height + root.separatorHeight)
    width: implicitWidth
    height: implicitHeight
    property string numberText: "—"
    property string titleText: "未接通角色目录"
    property string countText: "Designer绘制参考"
    property real numberWidth: 76
    property real columnGap: 4
    property real rowHeight: 49
    property real titleHeight: 28
    property real countTop: 27
    property real countHeight: 20
    property real numberSize: 17
    property real inputSize: 14
    property real countSize: 11
    property real noteSize: 12
    property real titleSize: 14
    property real separatorHeight: 1
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily
    property string numberFamily: Theme.numberFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    OperatorText {
        width: root.numberWidth
        height: root.titleHeight
        text: root.numberText
        numeric: true
        size: root.numberSize
        color: root.mutedColor
        font.family: root.numberFamily
    }
    OperatorText {
        x: root.numberWidth + root.columnGap
        width: Math.max(0, root.width - x)
        height: root.titleHeight
        text: root.titleText
        size: root.inputSize
        color: root.textColor
        font.family: root.fontFamily
    }
    OperatorText {
        id: countTextItem
        x: root.numberWidth + root.columnGap
        y: root.countTop
        width: Math.max(0, root.width - x)
        height: Math.max(root.countHeight, implicitHeight)
        text: root.countText
        size: root.countSize
        color: root.mutedColor
        font.family: root.fontFamily
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
    Rectangle { y: parent.height - height; width: parent.width; height: root.separatorHeight; color: root.separatorColor }
}
