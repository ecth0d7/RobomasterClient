import QtQuick

Item {
    id: root
    property string titleText: "遥测分组未提供"
    property string stateText: "未知"
    property string detailText: ""
    property color stateColor: Theme.muted
    property real rowHeight: 50
    property real titleHeight: 30
    property real detailTop: 28
    property real detailHeight: 22
    property real titleFraction: 0.58
    property real stateLeftFraction: 0.6
    property real separatorHeight: 1
    property real separatorOpacity: 0.35
    property real titleSize: 12
    property real detailSize: 11
    property string fontFamily: Theme.fontFamily
    property color textColor: Theme.text
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    implicitWidth: 400
    implicitHeight: root.rowHeight
    width: root.implicitWidth; height: root.implicitHeight
    Rectangle { y: root.height - height; width: root.width; height: root.separatorHeight; color: root.separatorColor; opacity: root.separatorOpacity; Accessible.ignored: true }
    OperatorText { width: root.width * root.titleFraction; height: root.titleHeight; text: root.titleText; size: root.titleSize; color: root.textColor; font.family: root.fontFamily }
    OperatorText { x: root.width * root.stateLeftFraction; width: root.width * (1 - root.stateLeftFraction); height: root.titleHeight; text: root.stateText; size: root.titleSize; color: root.stateColor; font.family: root.fontFamily; horizontalAlignment: Text.AlignRight }
    OperatorText { y: root.detailTop; width: root.width; height: root.detailHeight; text: root.detailText; size: root.detailSize; color: root.warningColor; font.family: root.fontFamily }
}
