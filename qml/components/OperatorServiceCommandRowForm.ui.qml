import QtQuick

Item {
    id: root
    property string titleText: "操作记录未提供"
    property string resultText: "未知"
    property string timeText: "时间／序号未提供"
    property string reasonText: "未提供原因"
    property color resultColor: Theme.muted
    property real minimumHeight: 92
    property real bottomPadding: 12
    property real titleHeight: 28
    property real titleFraction: 0.65
    property real resultLeftFraction: 0.67
    property real timeTop: 29
    property real timeHeight: 24
    property real reasonTop: 58
    property real titleSize: 13
    property real noteSize: 11
    property real separatorHeight: 1
    property real separatorOpacity: 0.35
    property string fontFamily: Theme.fontFamily
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color separatorColor: Theme.line
    implicitWidth: 400
    implicitHeight: Math.max(root.minimumHeight, root.reasonTop + reason.implicitHeight + root.bottomPadding)
    width: root.implicitWidth; height: root.implicitHeight
    Rectangle { y: root.height - height; width: root.width; height: root.separatorHeight; color: root.separatorColor; opacity: root.separatorOpacity; Accessible.ignored: true }
    OperatorText { width: root.width * root.titleFraction; height: root.titleHeight; text: root.titleText; size: root.titleSize; color: root.textColor; font.family: root.fontFamily }
    OperatorText { x: root.width * root.resultLeftFraction; width: root.width * (1 - root.resultLeftFraction); height: root.titleHeight; text: root.resultText; size: root.noteSize; color: root.resultColor; font.family: root.fontFamily; horizontalAlignment: Text.AlignRight }
    OperatorText { y: root.timeTop; width: root.width; height: root.timeHeight; text: root.timeText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily }
    OperatorText { id: reason; y: root.reasonTop; width: root.width; height: implicitHeight; text: root.reasonText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
}
