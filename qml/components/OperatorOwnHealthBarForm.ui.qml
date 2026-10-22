import QtQuick

// 本机生命槽的可编辑绘制；来源、时效与补间由包装层投影，未提供数据时不画数值。
Item {
    id: root
    property bool drawingBackgroundVisible: true
    property color drawingBackgroundColor: Theme.hudSolid
    Rectangle { anchors.fill: parent; visible: root.drawingBackgroundVisible; color: root.drawingBackgroundColor; z: -1 }
    property bool blue: false
    property real leftInsetTop: 0
    property real leftInsetBottom: 0
    property string directory: "../resources/player/my_robot/" + (root.blue ? "blue" : "red") + "_statusbar_blood_"
    property bool lowHealth: false
    property url backgroundSource: root.directory + "background.png"
    property url fillSource: root.directory + (root.lowHealth ? "slid_low" : "slid") + ".png"
    // Creator 的属性栏不提供 rect 数值编辑器；分别开放源图像素坐标与尺寸。
    property real backgroundClipX: 2
    property real backgroundClipY: 2
    property real backgroundClipWidth: 357
    property real backgroundClipHeight: 40
    property rect backgroundClipRect: Qt.rect(root.backgroundClipX, root.backgroundClipY, root.backgroundClipWidth, root.backgroundClipHeight)
    property real fillClipX: 20
    property real fillClipY: 12
    property real fillClipWidth: 320
    property real fillClipHeight: 40
    property rect fillClipRect: Qt.rect(root.fillClipX, root.fillClipY, root.fillClipWidth, root.fillClipHeight)
    property url fillMaskSource: root.backgroundSource
    // 默认继续跟随背景实体裁区；覆盖既有 rect API 时也保持原遮罩联动。
    property real fillMaskClipX: root.backgroundClipRect.x
    property real fillMaskClipY: root.backgroundClipRect.y
    property real fillMaskClipWidth: root.backgroundClipRect.width
    property real fillMaskClipHeight: root.backgroundClipRect.height
    property rect fillMaskClipRect: Qt.rect(root.fillMaskClipX, root.fillMaskClipY, root.fillMaskClipWidth, root.fillMaskClipHeight)
    property real backgroundOpacity: 0.22
    property real fillOpacity: 0.35
    property real fillFraction: 0
    property bool fillVisible: false
    property real fillSlantWidth: root.width * 20 / 357
    property real backgroundLeftMargin: 0
    property real backgroundTopMargin: 0
    property real backgroundRightMargin: 0
    property real backgroundBottomMargin: 0
    property real fillLeftMargin: 0
    property real fillTopMargin: 0
    property real fillRightMargin: 0
    property real fillBottomMargin: 0
    property bool readingVisible: false
    property string readingText: ""
    property string readingFontFamily: Theme.numberFamily
    property bool readingBold: true
    property real readingSize: Math.min(24, root.height * 0.48)
    property color readingColor: Theme.muted
    property real readingLeftPadding: 8
    property real readingRightPadding: 18
    property real readingMarkerGap: 24
    property real readingLeftMargin: Math.max(root.leftInsetTop, root.leftInsetBottom) + root.readingLeftPadding
    property real readingRightMargin: root.markerWidth > 0 ? root.markerWidth + root.readingMarkerGap : root.readingRightPadding
    property bool markerVisible: false
    property string markerText: ""
    property real markerWidth: root.markerText ? Math.max(26, root.markerText.length * 18 + 8) : 0
    property real markerRightMargin: 18
    property real markerTop: 0
    property real markerHeight: root.height
    property string markerFontFamily: Theme.fontFamily
    property real markerSize: 10
    property color markerColor: Theme.muted
    property alias backgroundControl: background
    property alias fillControl: filling
    property alias readingControl: reading
    property alias markerControl: marker
    // 独立打开 Form 时有可见槽位；正式 HUD 仍由父级明确提供原宽高。
    implicitWidth: 357
    implicitHeight: 50
    width: root.implicitWidth
    height: root.implicitHeight
    clip: true
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
    OperatorText {
        id: reading
        anchors.fill: parent
        anchors.leftMargin: root.readingLeftMargin
        anchors.rightMargin: root.readingRightMargin
        visible: root.readingVisible
        text: root.readingText
        numeric: true
        font.bold: root.readingBold
        font.family: root.readingFontFamily
        size: root.readingSize
        horizontalAlignment: Text.AlignHCenter
        clip: true
        color: root.readingColor
    }
    OperatorText {
        id: marker
        // 末端斜线在文本高度内仍向左收，状态字保留原槽内边距。
        x: root.width - root.markerWidth - root.markerRightMargin
        y: root.markerTop
        width: root.markerWidth
        height: root.markerHeight
        visible: root.markerVisible
        text: root.markerText
        font.family: root.markerFontFamily
        size: root.markerSize
        clip: true
        horizontalAlignment: Text.AlignHCenter
        color: root.markerColor
    }
}
