import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "OperatorProtocolData.js" as ProtocolData

Rectangle {
    id: root
    property var field: ({})
    property var value
    property string fieldState: "missing"
    property var schema: []
    property bool expanded: false
    readonly property bool arrayValue: ProtocolData.isArray(value)
    readonly property bool canExpand: arrayValue && value.length > 0 || ProtocolData.isObject(value)
                                     || typeof value === "string" && value.length > 0
                                     || field.note?.length > 0 || ProtocolData.unsafeInteger(value, field)
    property color stateColor: fieldState === "fresh" ? Theme.green : fieldState === "stale" ? Theme.warning : Theme.muted
    width: 980
    height: expanded ? detailColumn.implicitHeight + 92 : 80
    color: "#202a25"
    border.color: expanded ? Theme.line : "#403e4c43"
    OperatorText { x: 12; y: 8; width: parent.width * 0.38 - 16; height: 28; text: root.field.title ?? root.field.name; size: 13; textFormat: Text.PlainText }
    OperatorText {
        x: parent.width * 0.4; y: 8; width: parent.width * 0.6 - 126; height: 28
        text: ProtocolData.display(root.value, root.field)
        size: 13; textFormat: Text.PlainText
        numeric: typeof root.value === "number" || root.field.type === "bytes"
    }
    OperatorText {
        x: parent.width - 108; y: 8; width: 96; height: 28
        text: ({fresh: "有效", stale: "旧数据", missing: "未收到", definition: "字段定义"})[root.fieldState] ?? "未知"
        color: root.stateColor; size: 11; horizontalAlignment: Text.AlignRight
    }
    OperatorText {
        x: 12; y: 42; width: parent.width - 136; height: 26
        text: (root.field.number !== undefined ? "#" + root.field.number + " · " : "") + root.field.name
              + " · " + root.field.type + (root.field.cardinality === "repeated" ? "[]" : "")
        textFormat: Text.PlainText; size: 11; color: Theme.muted
    }
    OperatorButton {
        x: parent.width - 108; y: 40; width: 96; height: 30
        visible: root.canExpand
        text: root.expanded ? "收起" : "展开"
        Accessible.name: (root.expanded ? "收起" : "展开") + (root.field.title ?? root.field.name)
        onClicked: root.expanded = !root.expanded
    }
    Column {
        id: detailColumn
        x: 12
        y: 82
        width: parent.width - 24
        spacing: 8
        visible: root.expanded
        OperatorText {
            width: parent.width
            height: implicitHeight
            visible: root.field.note?.length > 0
            text: root.field.note ?? ""
            wrapMode: Text.WordWrap; elide: Text.ElideNone; textFormat: Text.PlainText
            size: 11; color: Theme.muted
        }
        OperatorText {
            width: parent.width
            height: implicitHeight
            visible: ProtocolData.unsafeInteger(root.value, root.field)
            text: "当前接口将此整数提供为浮点数，无法恢复精确值。请使用提供精确整数字符串的状态接口。"
            wrapMode: Text.WordWrap; elide: Text.ElideNone; textFormat: Text.PlainText
            size: 11; color: Theme.warning
        }
        OperatorProtocolArray {
            width: parent.width
            visible: root.arrayValue && root.value.length > 0
            values: root.arrayValue ? root.value : []
            field: root.field
            schema: root.schema
        }
        ScrollView {
            id: rawScroll
            width: parent.width
            height: Math.min(220, rawText.implicitHeight)
            visible: !root.arrayValue && (ProtocolData.isObject(root.value) || typeof root.value === "string" && root.value.length > 0)
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            TextArea {
                id: rawText
                width: rawScroll.availableWidth
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                text: ProtocolData.detail(root.value, root.field, root.schema)
                font.family: root.field.type === "bytes" ? Theme.numberFamily : Theme.fontFamily
                font.pixelSize: Math.max(12, 9.5 / Math.max(0.1, Window.window?.ui?.layoutScale ?? 1))
                color: Theme.text
                selectionColor: Theme.green
                selectedTextColor: "#1a2421"
                background: Rectangle { color: "#1b241f"; border.color: Theme.line }
            }
        }
    }
}
