import QtQuick

Item {
    id: root
    default property alias sectionContent: body.data
    property alias sectionBody: body
    property string title: ""
    property real contentMargin: 14
    property real titleTop: 9
    property real titleHeight: 25
    property real titleSize: 14
    property string fontFamily: Theme.fontFamily
    property real bodyTop: 47
    property color outlineColor: Theme.line
    property color titleColor: Theme.text
    property color surfaceColor: "transparent"
    implicitWidth: 286
    implicitHeight: 338
    width: implicitWidth
    height: implicitHeight
    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    OperatorOutline { color: root.outlineColor }
    Rectangle { x:root.contentMargin;y:root.bodyTop-9;width:Math.max(0,parent.width-2*root.contentMargin);height:1;color:Theme.line }
    OperatorText { x: root.contentMargin; y: root.titleTop; width: parent.width - 2 * root.contentMargin; height: root.titleHeight; text: root.title; size: root.titleSize; color: root.titleColor; font.family: root.fontFamily; font.bold: true }
    Item { id: body; x: root.contentMargin; y: root.bodyTop; width: parent.width - 2 * root.contentMargin; height: parent.height - y - root.contentMargin }
}
