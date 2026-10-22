import QtQuick

Rectangle {
    id: root
    property var fact: ({})
    width: 156
    height: 88
    color: "#202a25"
    border.color: Theme.line
    OperatorText { x: 8; y: 6; width: parent.width - 16; height: 20; text: root.fact.title ?? ""; size: 10; color: Theme.muted }
    OperatorText { x: 8; y: 29; width: parent.width - 16; height: 30; text: root.fact.value ?? "—"; size: 20; numeric: true }
    OperatorText { x: 8; y: 64; width: parent.width - 16; height: 20; text: root.fact.detail ?? ""; size: 10; numeric: true; color: Theme.muted }
}
