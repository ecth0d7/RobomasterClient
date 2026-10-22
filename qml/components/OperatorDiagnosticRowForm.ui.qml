import QtQuick

// 单条诊断绘制。字段值／类型与来源由调用包装提供。
Item {
    id: root
    property bool drawingBackgroundVisible: true
    property color drawingBackgroundColor: Theme.hudSolid
    Rectangle { anchors.fill: parent; visible: root.drawingBackgroundVisible; color: root.drawingBackgroundColor; z: -1 }
    property string labelText: "未提供字段"
    property string valueText: "—"
    property bool detail: false
    property bool numeric: false
    property bool showSeparator: true
    property real rowHeight: 40
    property real detailMinimumHeight: 74
    property real labelHeight: 30
    property real detailValueTop: 32
    property real detailBottomPadding: 6
    property real labelFraction: 0.42
    property real valueLeftFraction: 0.44
    property real separatorHeight: 1
    property real separatorOpacity: 0.35
    property real labelSize: 11
    property real valueSize: 12
    property string fontFamily: Theme.fontFamily
    property string numericFontFamily: Theme.numberFamily
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color separatorColor: Theme.line
    implicitWidth: 258
    implicitHeight: root.detail ? Math.max(root.detailMinimumHeight, value.implicitHeight + root.detailValueTop + root.detailBottomPadding) : root.rowHeight
    width: root.implicitWidth
    height: root.implicitHeight
    Rectangle {
        y: root.height - height
        width: root.width; height: root.separatorHeight
        visible: root.showSeparator
        color: root.separatorColor; opacity: root.separatorOpacity
        Accessible.ignored: true
    }
    OperatorText {
        width: root.detail ? root.width : root.width * root.labelFraction
        height: root.labelHeight
        text: root.labelText
        size: root.labelSize; color: root.mutedColor; font.family: root.fontFamily
    }
    OperatorText {
        id: value
        x: root.detail ? 0 : root.width * root.valueLeftFraction
        y: root.detail ? root.detailValueTop : 0
        width: root.detail ? root.width : root.width * (1 - root.valueLeftFraction)
        height: root.detail ? implicitHeight : root.labelHeight
        text: root.valueText
        textFormat: Text.PlainText
        size: root.valueSize; color: root.textColor
        font.family: root.numeric ? root.numericFontFamily : root.fontFamily
        numeric: root.numeric
        horizontalAlignment: root.detail ? Text.AlignLeft : Text.AlignRight
        wrapMode: root.detail ? Text.WordWrap : Text.NoWrap
        elide: root.detail ? Text.ElideNone : Text.ElideRight
    }
}
