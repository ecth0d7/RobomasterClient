import QtQuick

// 共享面板的真实绘制层；焦点、快捷键和关闭动作由同名行为组件接线。
FocusScope {
    id: root
    default property alias panelContent: body.data
    property alias closeControl: panelClose
    property string title: ""
    property color accent: Theme.green
    property bool closeButton: true
    property url backgroundSource: ""
    property string iconAsset: ""
    // 原设置背景带透明边缘，正文留距按其可见框体增加，避免按钮压边。
    property real contentMargin: root.backgroundSource.toString().length > 0 ? 28 : 18
    property real headerCenterY: root.backgroundSource.toString().length > 0 ? 34 : 23
    property real headerHeight: 44
    property real titleHeight: 32
    property real titleSize: 17
    property real iconSize: 32
    property real iconTitleGap: 12
    property real closeSize: 32
    property real titleCloseGap: 12
    property real bodyTop: 60
    property real backgroundSlice: 28
    property color surfaceColor: Theme.hudSolid
    property color outlineColor: Theme.hudBorder
    property color headerColor: Theme.hudHover
    implicitWidth: 650
    implicitHeight: 440
    width: root.implicitWidth
    height: root.implicitHeight

    Rectangle {
        id: solidBackground
        anchors.fill: parent
        visible: true
        color: root.surfaceColor
        OperatorOutline { color: root.outlineColor }
    }
    BorderImage {
        id: imageBackground
        opacity: 0.12
        anchors.fill: parent
        source: root.backgroundSource
        visible: source.toString().length > 0
        border { left: root.backgroundSlice; right: root.backgroundSlice; top: root.backgroundSlice; bottom: root.backgroundSlice }
    }
    Rectangle {
        id: headerBackground
        x: 1
        y: 1
        width: parent.width - 2
        height: root.headerHeight
        visible: root.backgroundSource.toString().length === 0
        color: root.headerColor
    }
    Image {
        x:1;y:1;width:parent.width-2;height:root.headerHeight
        source:"../resources/laboratory/panel-grid.svg";fillMode:Image.Tile
        Accessible.ignored:true
    }
    Rectangle {x:1;y:1;width:3;height:root.headerHeight;color:Theme.accent}
    Rectangle {x:1;y:root.headerHeight;width:parent.width-2;height:1;color:Theme.line}
    OperatorPanelGlyph {
        id: headerGlyph
        x: root.contentMargin
        y: root.headerCenterY - height / 2
        width: root.iconSize
        height: root.iconSize
        asset: root.iconAsset
        visible: asset.length > 0
    }
    OperatorText {
        id: headerTitle
        // 外部设置底板带透明边缘；无图标标题也要位于正文留距内，不能压在可见框线上。
        x: root.contentMargin + (root.iconAsset.length ? root.iconSize + root.iconTitleGap : 0)
        y: root.headerCenterY - height / 2
        width: parent.width - x - root.contentMargin - root.closeSize - root.titleCloseGap
        height: root.titleHeight
        text: root.title
        color: root.accent
        size: root.titleSize
    }
    OperatorCloseButton {
        id: panelClose
        x: parent.width - root.contentMargin - width
        y: root.headerCenterY - height / 2
        width: root.closeSize
        height: root.closeSize
        objectName: "panelCloseControl"
        visible: root.closeButton
        closeLabel: "关闭" + root.title
    }
    Item {
        id: body
        x: root.contentMargin
        y: root.bodyTop
        width: parent.width - 2 * root.contentMargin
        height: parent.height - y - root.contentMargin
    }
}
