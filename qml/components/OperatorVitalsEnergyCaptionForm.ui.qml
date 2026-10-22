import QtQuick

// 能量数字／单位的独立绘制，不从文字或槽长反推遥测。
Item {
    id: root
    property bool valuePresent: false
    property string captionText: ""
    property string descriptionText: "能量来源未提供"
    property color captionColor: Theme.muted
    property real captionWidth: 112
    property real captionHeight: 22
    property real captionSize: 11
    property string captionFontFamily: Theme.fontFamily
    implicitWidth: root.captionWidth
    implicitHeight: root.captionHeight
    width: implicitWidth
    height: implicitHeight
    visible: root.valuePresent
    clip: true
    Accessible.role: Accessible.StaticText
    Accessible.name: root.descriptionText
    OperatorText {
        anchors.fill: parent
        text: root.captionText
        color: root.captionColor
        size: root.captionSize
        font.family: root.captionFontFamily
        clip: true
        Accessible.ignored: true
    }
}
