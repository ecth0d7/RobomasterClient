import QtQuick

// 经验弧保持原图比例；只揭示已有曲线，不缩短贴图或在绘制层推断经验／等级。
Item {
    id: root
    property bool blue: false
    property real assetScale: 119 / 157
    property bool present: false
    property real referenceWidth: 32
    property real referenceHeight: 92
    property url backgroundSource: "../resources/player/my_robot/" + (root.blue ? "blue" : "red") + "_statusbar_expbar_bg.png"
    property url fillSource: "../resources/player/my_robot/statusbar_expbar.png"
    property real backgroundOpacity: 0.45
    property real fillOpacity: 0.35
    property bool imageMipmap: true
    property real fillFraction: 0
    property bool fillVisible: false
    property real arcLeft: 2
    property real arcTop: 2
    property real arcWidth: 23
    property real arcHeight: 88
    property string markerText: ""
    property bool markerVisible: root.markerText.length > 0
    property real markerWidth: 24
    property real markerHeight: 22
    property real markerRightMargin: 0
    property real markerBottomMargin: 0
    property string markerFontFamily: Theme.fontFamily
    property real markerSize: 10
    property color markerColor: Theme.muted
    property alias backgroundControl: background
    property alias fillRevealControl: reveal
    property alias fillControl: filling
    property alias markerControl: marker
    width: root.referenceWidth * root.assetScale
    height: root.referenceHeight * root.assetScale
    visible: root.present
    Image {
        id: background
        anchors.fill: parent
        source: root.backgroundSource
        fillMode: Image.PreserveAspectFit
        mipmap: root.imageMipmap
        opacity: root.backgroundOpacity
        Accessible.ignored: true
    }
    Item {
        id: reveal
        // 底部向上裁出原23×88曲线；源图位置与揭示高度共用同一比例。
        x: root.arcLeft * root.assetScale
        y: (root.arcTop + root.arcHeight * (1 - root.fillFraction)) * root.assetScale
        width: root.arcWidth * root.assetScale
        height: root.arcHeight * root.fillFraction * root.assetScale
        visible: root.fillVisible
        clip: true
        Image {
            id: filling
            y: -root.arcHeight * (1 - root.fillFraction) * root.assetScale
            width: root.arcWidth * root.assetScale
            height: root.arcHeight * root.assetScale
            source: root.fillSource
            fillMode: Image.PreserveAspectFit
            mipmap: root.imageMipmap
            opacity: root.fillOpacity
            Accessible.ignored: true
        }
    }
    OperatorText {
        id: marker
        x: Math.max(0, root.width - root.markerWidth - root.markerRightMargin)
        y: root.height - root.markerHeight - root.markerBottomMargin
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
