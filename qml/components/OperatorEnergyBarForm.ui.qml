import QtQuick

// 能量槽只绘制已投影的比例；补间和来源切换处理仍在 OperatorEnergyBar 中。
Item {
    id: root
    property bool drawingBackgroundVisible: true
    property color drawingBackgroundColor: Theme.hudSolid
    Rectangle { anchors.fill: parent; visible: root.drawingBackgroundVisible; color: root.drawingBackgroundColor; z: -1 }
    property real leftInsetTop: 0
    property real leftInsetBottom: 0
    property url backgroundSource: "../resources/player/my_robot/statusbar_energy_background.png"
    property url fillSource: "../resources/player/my_robot/statusbar_energy.png"
    // 只缩放原300×30图片的实体ROI，保留原槽与灰翼连接。
    // 源图裁区以独立数值开放，Creator 属性栏可直接编辑每一个像素坐标。
    property real backgroundClipX: 18
    property real backgroundClipY: 11
    property real backgroundClipWidth: 264
    property real backgroundClipHeight: 8
    property rect backgroundClipRect: Qt.rect(root.backgroundClipX, root.backgroundClipY, root.backgroundClipWidth, root.backgroundClipHeight)
    property real fillClipX: 18
    property real fillClipY: 11
    property real fillClipWidth: 264
    property real fillClipHeight: 8
    property rect fillClipRect: Qt.rect(root.fillClipX, root.fillClipY, root.fillClipWidth, root.fillClipHeight)
    property url fillMaskSource: root.backgroundSource
    // 仍与背景实体裁区同步；也兼容调用方直接覆盖既有 backgroundClipRect。
    property real fillMaskClipX: root.backgroundClipRect.x
    property real fillMaskClipY: root.backgroundClipRect.y
    property real fillMaskClipWidth: root.backgroundClipRect.width
    property real fillMaskClipHeight: root.backgroundClipRect.height
    property rect fillMaskClipRect: Qt.rect(root.fillMaskClipX, root.fillMaskClipY, root.fillMaskClipWidth, root.fillMaskClipHeight)
    property real backgroundOpacity: 0.22
    property real fillOpacity: 0.25
    property real fillFraction: 0
    property bool fillVisible: false
    property real fillSlantWidth: root.width * 4 / 264
    property real backgroundLeftMargin: 0
    property real backgroundTopMargin: 0
    property real backgroundRightMargin: 0
    property real backgroundBottomMargin: 0
    property real fillLeftMargin: 0
    property real fillTopMargin: 0
    property real fillRightMargin: 0
    property real fillBottomMargin: 0
    property alias backgroundControl: background
    property alias fillControl: filling
    // 独立 Form 提供中性槽位尺寸；正式实例由父级保留既有大小。
    implicitWidth: 264
    implicitHeight: 10
    width: root.implicitWidth
    height: root.implicitHeight
    OperatorSlantedFill {
        id: background
        anchors.fill: parent
        anchors.leftMargin: root.backgroundLeftMargin
        anchors.topMargin: root.backgroundTopMargin
        anchors.rightMargin: root.backgroundRightMargin
        anchors.bottomMargin: root.backgroundBottomMargin
        source: root.backgroundSource
        sourceClipRect: root.backgroundClipRect
        fraction: 1
        slantWidth: 0
        leftInsetTop: root.leftInsetTop
        leftInsetBottom: root.leftInsetBottom
        opacity: root.backgroundOpacity
    }
    OperatorSlantedFill {
        id: filling
        anchors.fill: parent
        anchors.leftMargin: root.fillLeftMargin
        anchors.topMargin: root.fillTopMargin
        anchors.rightMargin: root.fillRightMargin
        anchors.bottomMargin: root.fillBottomMargin
        source: root.fillSource
        sourceClipRect: root.fillClipRect
        maskSource: root.fillMaskSource
        maskClipRect: root.fillMaskClipRect
        slantWidth: root.fillSlantWidth
        leftInsetTop: root.leftInsetTop
        leftInsetBottom: root.leftInsetBottom
        fraction: root.fillFraction
        visible: root.fillVisible
        opacity: root.fillOpacity
    }
}
