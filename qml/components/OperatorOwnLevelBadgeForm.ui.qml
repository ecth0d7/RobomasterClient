import QtQuick

// 等级贴图和异常标记的实际绘制；收到的等级与来源资格留在包装层。
Item {
    id: root
    property bool present: false
    property bool blue: false
    property bool glyphVisible: false
    property bool live: false
    property bool invalid: false
    property bool warning: false
    property int levelValue: 0
    property string markerText: ""
    property string descriptionText: "等级来源未提供"
    property real assetScale: 1
    property real badgeSize: 36
    property real textInset: 2
    property real fallbackSize: 10
    property real markerSize: 9
    property real markerHeight: 22
    property real retainedOpacity: 0.4
    property color surfaceColor: Theme.hudSurface
    property color outlineColor: Theme.hudBorder
    property color warningColor: Theme.warning
    property color mutedColor: Theme.muted
    property real outlineWidth: 1 / Math.min(1, Math.max(0.1, marker.hudScale))
    property string fontFamily: Theme.fontFamily
    // 独立属性绑定可先后更新；等级尚未到位时不请求不存在的0号贴图。
    property url glyphSource: root.glyphVisible && root.levelValue >= 1 && root.levelValue <= 10
        ? "../resources/player/my_robot/" + (root.blue ? "blue" : "red") + "_statusbar_level_" + root.levelValue + ".png" : ""
    property alias glyphControl: glyph
    property alias markerControl: marker
    implicitWidth: root.badgeSize * root.assetScale
    implicitHeight: root.badgeSize * root.assetScale
    width: implicitWidth
    height: implicitHeight
    visible: root.present
    Accessible.role: Accessible.StaticText
    Accessible.name: root.descriptionText

    Rectangle {
        anchors.fill: parent
        visible: !root.glyphVisible
        color: root.surfaceColor
        radius: width / 2
        border.color: root.outlineColor
        border.width: root.outlineWidth
        OperatorText {
            anchors.fill: parent
            anchors.margins: root.textInset
            text: root.invalid ? "等级\n异常" : root.markerText
            size: root.fallbackSize
            clip: true
            horizontalAlignment: Text.AlignHCenter
            color: root.warning ? root.warningColor : root.mutedColor
            font.family: root.fontFamily
        }
    }
    Image {
        id: glyph
        anchors.fill: parent
        visible: root.glyphVisible
        source: root.glyphSource
        fillMode: Image.PreserveAspectFit
        mipmap: true
        opacity: root.live ? 1 : root.retainedOpacity
        Accessible.ignored: true
    }
    OperatorText {
        id: marker
        x: 0
        y: parent.height - root.markerHeight
        width: parent.width
        height: root.markerHeight
        clip: true
        visible: root.glyphVisible && root.markerText.length > 0
        text: root.markerText
        size: root.markerSize
        horizontalAlignment: Text.AlignHCenter
        color: root.warning ? root.warningColor : root.mutedColor
        font.family: root.fontFamily
    }
}
