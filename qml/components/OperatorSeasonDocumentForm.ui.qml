import QtQuick

// The parent provides the actual version/status/date/source/archive rows.
// Empty Designer data never implies that a document or protocol is verified.
Item {
    id: root
    objectName: "seasonDocumentForm"
    implicitWidth: 1300
    implicitHeight: table.height
    width: implicitWidth
    height: implicitHeight
    property alias tableControl: table
    property string heading: "参考文件 · 未接通目录"
    property var rows: []
    property real contentMargin: 14
    property real bodyTop: 47
    property real titleSize: 14
    property real noteSize: 11
    property real inputSize: 12
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    OperatorDiagnosticTable {
        id: table
        width: root.width
        title: root.heading
        rows: root.rows
        contentMargin: root.contentMargin
        bodyTop: root.bodyTop
        titleSize: root.titleSize
        titleColor: root.textColor
        surfaceColor: root.surfaceColor
        outlineColor: root.separatorColor
        separatorColor: root.separatorColor
        textColor: root.textColor
        mutedColor: root.mutedColor
        fontFamily: root.fontFamily
        labelSize: root.noteSize
        valueSize: root.inputSize
    }
}
