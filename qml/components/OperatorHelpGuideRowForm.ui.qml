import QtQuick

Item {
    id: root
    implicitWidth: 1044
    implicitHeight: Math.max(root.minimumHeight,
                             description.y + description.height + root.bottomPadding,
                             key.height + root.bottomPadding)
    width: implicitWidth
    height: implicitHeight
    property string keyText: "未接通"
    property string titleText: "操作说明未提供"
    property string descriptionText: "Designer绘制参考 · 没有当前输入状态。"
    property real minimumHeight: 80
    property real compactBreakpoint: 620
    property real keyWidth: 180
    property real columnGap: 14
    property real titleHeight: 30
    property real descriptionGap: 2
    property real descriptionMinimumHeight: 44
    property real bottomPadding: 4
    property real keySize: 14
    property real titleSize: 14
    property real noteSize: 12
    property color surfaceColor: "transparent"
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property string fontFamily: Theme.fontFamily
    property string numberFamily: Theme.numberFamily
    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    OperatorText {
        id: key
        width: root.width >= root.compactBreakpoint ? root.keyWidth : root.width
        height: Math.max(root.titleHeight, implicitHeight)
        text: root.keyText
        numeric: true
        size: root.keySize
        color: root.textColor
        font.family: root.numberFamily
        wrapMode: Text.WrapAnywhere
        elide: Text.ElideNone
    }
    OperatorText {
        id: title
        x: root.width >= root.compactBreakpoint ? root.keyWidth + root.columnGap : 0
        y: root.width >= root.compactBreakpoint ? 0 : key.height + root.descriptionGap
        width: Math.max(0, root.width - x)
        height: Math.max(root.titleHeight, implicitHeight)
        text: root.titleText
        size: root.titleSize
        color: root.textColor
        font.family: root.fontFamily
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
    OperatorText {
        id: description
        x: title.x
        y: title.y + title.height + root.descriptionGap
        width: title.width
        height: Math.max(root.descriptionMinimumHeight, implicitHeight)
        text: root.descriptionText
        size: root.noteSize
        color: root.mutedColor
        font.family: root.fontFamily
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
}
