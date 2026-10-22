import QtQuick
import QtQuick.Controls
import "OperatorProtocolData.js" as ProtocolData

ListView {
    id: root
    property var values: []
    property var field: ({})
    property var schema: []
    readonly property bool objects: values.length > 0 && ProtocolData.isObject(values[0])
    property real maximumHeight: Math.min(values.length, objects ? 3 : 6) * (objects ? 150 : 38)
    height: Math.min(maximumHeight, contentHeight > 0 ? contentHeight : maximumHeight)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    // 固定数量时保留委托，仅更新其值；大量数组使用 ListView 按可见范围创建条目。
    model: values.length
    delegate: Item {
        required property int index
        readonly property var value: root.values[index]
        width: ListView.view.width - 14
        height: Math.max(38, valueText.implicitHeight + 18)
        Rectangle { anchors.fill: parent; color: index % 2 ? "#202b26" : "#26332c" }
        OperatorText { x: 8; y: 7; width: 48; height: 24; text: "[" + index + "]"; size: 11; numeric: true; color: Theme.muted }
        OperatorText {
            id: valueText
            x: 66
            y: 7
            width: parent.width - 78
            height: implicitHeight
            text: ProtocolData.isObject(parent.value) ? ProtocolData.detail(parent.value, root.field, root.schema)
                                                     : ProtocolData.display(parent.value, root.field)
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            size: 12
            numeric: !ProtocolData.isObject(parent.value)
        }
    }
    ScrollBar.vertical: ScrollBar {
        id: bar
        width: 8
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle { implicitWidth: 6; implicitHeight: 40; radius: 3; color: bar.pressed ? Theme.text : Theme.muted }
        background: Rectangle { color: "#14201a"; radius: 3 }
    }
}
