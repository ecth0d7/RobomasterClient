import QtQuick

// One shortcut readout. Recording, assignment and navigation live in Help.qml.
Item {
    id: root
    implicitWidth: 1044
    implicitHeight: Math.max(root.minimumHeight,
                             keyScope.y + keyScope.height + root.verticalMargin,
                             description.y + description.height + root.verticalMargin,
                             actions.y + actions.implicitHeight + root.verticalMargin)
    width: implicitWidth
    height: implicitHeight
    property alias changeControl: changeButton
    property alias resetControl: resetButton
    property alias openControl: openButton
    property string bindingText: "未接通"
    property string scopeText: "范围未提供"
    property string titleText: "快捷键未提供"
    property string descriptionText: "Designer绘制参考 · 没有当前快捷键或录入状态。"
    property string changeText: "改键"
    property string changeAccessibleName: "修改快捷键"
    property bool changeEnabled: false
    property bool resetEnabled: false
    property bool openVisible: false
    property bool openEnabled: false
    property bool recording: false
    property real minimumHeight: 84
    property real compactBreakpoint: 760
    readonly property bool wide: width >= compactBreakpoint
    property real horizontalMargin: 12
    property real verticalMargin: 9
    property real keyColumnWidth: 176
    property real keyHeight: 30
    property real scopeGap: 4
    property real scopeHeight: 25
    property real separatorGap: 12
    property real separatorTop: 12
    property real separatorWidth: 1
    property real separatorHeight: 60
    property real borderThickness: 1
    property real descriptionGap: 15
    property real descriptionActionGap: 16
    property real descriptionTop: 8
    property real titleHeight: 28
    property real descriptionTextGap: 2
    property real descriptionMinimumHeight: 36
    property real compactGap: 8
    property real actionWidth: 142
    property real shortActionWidth: 66
    property real actionColumnGap: 10
    property real actionRowGap: 6
    property real controlHeight: 30
    property real bindingSize: 14
    property real titleSize: 14
    property real noteSize: 11
    property real inputSize: 14
    property color surfaceColor: Theme.hudSurface
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color borderColor: Theme.hudBorder
    property color separatorColor: Theme.line
    property color recordingColor: Theme.green
    property color bindingColor: Theme.muted
    property string fontFamily: Theme.fontFamily
    property string numberFamily: Theme.numberFamily
    Rectangle { anchors.fill: parent; color: root.surfaceColor }
    OperatorOutline { color: root.recording ? root.recordingColor : root.borderColor; thickness: root.borderThickness }
    OperatorText {
        id: binding
        x: root.horizontalMargin
        y: root.verticalMargin
        width: root.wide ? root.keyColumnWidth : Math.max(0, root.width - root.horizontalMargin * 2)
        height: Math.max(root.keyHeight, implicitHeight)
        text: root.bindingText
        numeric: true
        size: root.bindingSize
        color: root.bindingColor
        font.family: root.numberFamily
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WrapAnywhere
        elide: Text.ElideNone
    }
    OperatorText {
        id: keyScope
        x: binding.x
        y: binding.y + binding.height + root.scopeGap
        width: binding.width
        height: Math.max(root.scopeHeight, implicitHeight)
        text: root.scopeText
        size: root.noteSize
        color: root.mutedColor
        font.family: root.fontFamily
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WrapAnywhere
        elide: Text.ElideNone
    }
    Rectangle {
        id: divider
        x: root.horizontalMargin + root.keyColumnWidth + root.separatorGap
        y: root.separatorTop
        width: root.separatorWidth
        height: root.separatorHeight
        visible: root.wide
        color: root.separatorColor
    }
    OperatorText {
        id: title
        x: root.wide ? divider.x + divider.width + root.descriptionGap : root.horizontalMargin
        y: root.wide ? root.descriptionTop : keyScope.y + keyScope.height + root.compactGap
        width: Math.max(0, root.wide ? actions.x - x - root.descriptionActionGap : root.width - root.horizontalMargin * 2)
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
        y: title.y + title.height + root.descriptionTextGap
        width: title.width
        height: Math.max(root.descriptionMinimumHeight, implicitHeight)
        text: root.descriptionText
        size: root.noteSize
        color: root.mutedColor
        font.family: root.fontFamily
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
    Column {
        id: actions
        x: root.wide ? root.width - root.actionWidth - root.horizontalMargin : root.horizontalMargin
        y: root.wide ? root.verticalMargin : description.y + description.height + root.compactGap
        width: root.actionWidth
        spacing: root.actionRowGap
        Row {
            width: parent.width
            spacing: root.actionColumnGap
            OperatorButton {
                id: changeButton
                width: root.shortActionWidth
                height: root.controlHeight
                text: root.changeText
                enabled: root.changeEnabled
                primary: root.recording
                Accessible.name: root.changeAccessibleName
                textColor: root.textColor
                font.family: root.fontFamily
                font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
            }
            OperatorButton {
                id: resetButton
                width: root.shortActionWidth
                height: root.controlHeight
                text: "默认"
                enabled: root.resetEnabled
                textColor: root.textColor
                font.family: root.fontFamily
                font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
            }
        }
        OperatorButton {
            id: openButton
            width: root.actionWidth
            height: root.controlHeight
            text: "打开对应界面"
            visible: root.openVisible
            enabled: root.openEnabled
            textColor: root.textColor
            font.family: root.fontFamily
            font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
        }
    }
}
