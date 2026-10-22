import QtQuick

// 行集合只接受行为层已选定的条目；缺省没有状态和来源声明。
Item {
    id: root
    property int hintCount: 0
    property Component hintDelegate: null
    property int slotCount: 3
    property real slotGap: 8
    property real sourceGap: 18
    property real sourceWidth: 112
    property string sourceCaption: ""
    property color sourceColor: Theme.muted
    property real labelSize: 11
    property real sourceSize: 10
    property string fontFamily: Theme.fontFamily
    property alias hintRepeater: hints
    property alias sourceControl: source
    width: 354
    height: 24
    visible: root.hintCount > 0

    Repeater {
        id: hints
        model: root.hintCount
        delegate: root.hintDelegate
    }
    OperatorText {
        id: source
        x: parent.width + root.sourceGap
        width: root.sourceWidth
        height: parent.height
        text: root.sourceCaption
        font.family: root.fontFamily
        color: root.sourceColor
        size: root.sourceSize
        clip: true
    }
}
