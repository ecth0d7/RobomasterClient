import QtQuick

// 判罚的有效性和数量口径由行为层核验；Form 不生成判罚记录。
Item {
    id: root
    property real assetScale: 1
    property url iconSource: ""
    property string labelText: ""
    property color labelColor: Theme.warning
    property real iconLeft: 0
    property real iconTop: 2.4
    property real iconWidth: 20
    property real iconAspectRatio: 72 / 62
    property real labelLeft: 22
    property real labelTop: 2
    property real labelWidth: 26
    property real labelHeight: 24
    property real labelSize: 12
    property string fontFamily: Theme.fontFamily
    property alias iconControl: icon
    property alias labelControl: label
    width: 48 * assetScale
    height: 28 * assetScale
    visible: false

    Image {
        id: icon
        x: root.iconLeft * root.assetScale
        y: root.iconTop * root.assetScale
        width: root.iconWidth * root.assetScale
        height: root.iconWidth * root.iconAspectRatio * root.assetScale
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        mipmap: true
        Accessible.ignored: true
    }
    OperatorText {
        id: label
        x: root.labelLeft * root.assetScale
        y: root.labelTop * root.assetScale
        width: root.labelWidth * root.assetScale
        height: root.labelHeight * root.assetScale
        text: root.labelText
        font.family: root.fontFamily
        size: root.labelSize
        color: root.labelColor
        clip: true
    }
}
