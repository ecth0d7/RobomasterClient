import QtQuick

// 分区正文与状态点；同名包装保持外框和实际字段接线。
Item {
    id: root
    property string statusText: "状态未提供"
    property color stateColor: Theme.muted
    property int rowCount: 0
    property Component rowDelegate: null
    property real stateRightInset: 8
    property real stateTop: -29
    property real stateSize: 7
    property real stateRadius: 3.5
    property real statusHeight: 52
    property real statusSize: 13
    property real rowsTop: 60
    property real rowSpacing: 2
    property real rowHeight: 24
    property real labelSize: 11
    property real valueSize: 12
    property real labelFraction: 0.42
    property real valueLeftFraction: 0.44
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property string fontFamily: Theme.fontFamily
    property string numericFontFamily: Theme.numberFamily
    implicitWidth: 258
    implicitHeight: Math.max(root.statusHeight, root.rowsTop + lines.implicitHeight)
    width: root.implicitWidth
    height: root.implicitHeight
    Rectangle {
        x: root.width - root.stateRightInset
        y: root.stateTop
        width: root.stateSize; height: root.stateSize; radius: root.stateRadius
        color: root.stateColor
        Accessible.ignored: true
    }
    OperatorText {
        width: root.width; height: root.statusHeight
        text: root.statusText; size: root.statusSize
        font.family: root.fontFamily; color: root.stateColor
        wrapMode: Text.WordWrap; elide: Text.ElideRight
    }
    Column {
        id: lines
        y: root.rowsTop; width: root.width; spacing: root.rowSpacing
        Repeater { model: root.rowCount; delegate: root.rowDelegate }
    }
}
