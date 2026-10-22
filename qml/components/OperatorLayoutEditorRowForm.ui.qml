import QtQuick

// 一个真实条目的外观；显隐偏好和面板路由由普通QML包装处理。
Item {
    id: root
    property alias toggleControl: toggle
    property alias openControl: openButton
    property bool panelMode: false
    property bool checkedValue: false
    property bool toggleEnabled: false
    property bool openEnabled: false
    property bool stateWarning: false
    property int rowIndex: 0
    property string titleText: "Designer绘制参考 · 条目未接通"
    property string detailText: ""
    property string stateText: ""
    property real leftInset: 10
    property real rightInset: 10
    property real actionWidth: 88
    property real actionGap: 18
    property real actionHeight: 34
    property real controlHeight: 38
    property real panelMinimumHeight: 62
    property real hudMinimumHeight: 48
    property real textSpacing: 2
    property real titleTop: 6
    property real bottomInset: 7
    property real titleMinimumHeight: 25
    property real detailMinimumHeight: 22
    property real stateWidth: 88
    property real breakpoint: 420
    property real titleSize: 13
    property real noteSize: 11
    property real widgetSize: 12
    property real toggleTextPadding: 8
    property color evenSurface: "#26332e"
    property color oddSurface: "#202b27"
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property string fontFamily: Theme.fontFamily
    readonly property bool stacked: root.width < root.breakpoint
    implicitWidth: 548
    implicitHeight: root.panelMode ? Math.max(
                                         root.panelMinimumHeight,
                                         panelTexts.y + panelTexts.implicitHeight
                                         + (root.stacked ? root.actionGap + root.actionHeight : 0)
                                         + root.bottomInset) : Math.max(
                                         root.hudMinimumHeight,
                                         root.stacked ? toggle.height + root.textSpacing
                                                        + stateLabel.implicitHeight
                                                        + root.bottomInset : toggle.height)
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        color: root.rowIndex % 2 === 0 ? root.evenSurface : root.oddSurface
        z: -1
    }
    OperatorCheckBox {
        id: toggle
        x: root.leftInset
        y: root.stacked ? 0 : (root.height - height) / 2
        width: Math.max(0, root.width - root.leftInset - root.rightInset
                        - (root.stacked ? 0 : root.stateWidth + root.actionGap))
        height: Math.max(root.controlHeight,
                         toggleTitle.implicitHeight + root.toggleTextPadding)
        visible: !root.panelMode
        text: root.titleText
        enabled: root.toggleEnabled
        checked: root.checkedValue
        textColor: root.textColor
        font.family: root.fontFamily
        font.pixelSize: Math.max(root.widgetSize, 9.5 / Math.max(0.1, hudScale))
        contentItem: OperatorText {
            id: toggleTitle
            leftPadding: toggle.indicatorSize + toggle.textSpacing
            text: root.titleText
            font: toggle.font
            color: root.textColor
            opacity: toggle.enabled ? 1 : toggle.disabledOpacity
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
    }
    OperatorText {
        id: stateLabel
        x: root.stacked ? root.leftInset : root.width - root.rightInset - root.stateWidth
        y: root.stacked ? toggle.height + root.textSpacing : 0
        width: Math.max(
                   0,
                   root.stacked ? root.width - root.leftInset - root.rightInset : root.stateWidth)
        height: root.stacked ? implicitHeight : root.height
        visible: !root.panelMode
        text: root.stateText
        size: root.noteSize
        color: root.stateWarning ? root.warningColor : root.mutedColor
        font.family: root.fontFamily
        horizontalAlignment: root.stacked ? Text.AlignLeft : Text.AlignRight
        wrapMode: root.stacked ? Text.Wrap : Text.NoWrap
        elide: root.stacked ? Text.ElideNone : Text.ElideRight
    }
    Column {
        id: panelTexts
        x: root.leftInset
        y: root.titleTop
        width: Math.max(
                   0, root.width - root.leftInset - root.rightInset
                   - (root.stacked ? 0 : root.actionWidth + root.actionGap))
        spacing: root.textSpacing
        visible: root.panelMode
        OperatorText {
            width: parent.width
            height: Math.max(root.titleMinimumHeight, implicitHeight)
            text: root.titleText
            size: root.titleSize
            color: root.textColor
            font.family: root.fontFamily
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        OperatorText {
            width: parent.width
            height: Math.max(root.detailMinimumHeight, implicitHeight)
            visible: root.detailText.length > 0
            text: root.detailText
            size: root.noteSize
            color: root.mutedColor
            font.family: root.fontFamily
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
    }
    OperatorButton {
        id: openButton
        x: root.stacked ? root.leftInset : root.width - root.rightInset - width
        y: root.stacked ? panelTexts.y + panelTexts.implicitHeight
                          + root.actionGap : (root.height - height) / 2
        width: Math.min(root.actionWidth,
                        Math.max(0,
                                 root.width - root.leftInset - root.rightInset))
        height: root.actionHeight
        visible: root.panelMode
        enabled: root.openEnabled
        text: "打开"
        Accessible.name: "打开" + root.titleText
        font.family: root.fontFamily
        textColor: root.textColor
    }
}
