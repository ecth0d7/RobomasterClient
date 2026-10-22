import QtQuick

// Member presence is supplied by the accepted native team view, never inferred.
Item {
    id: root
    implicitWidth: 620
    implicitHeight: memberTable.height
    width: implicitWidth
    height: implicitHeight
    property string heading: "来源节点 · Designer绘制参考，未接通"
    property var rows: []
    property real sectionTitleSize: 14
    property real contentMargin: 14
    property real bodyTop: 47
    property real noteSize: 12
    property real inputSize: 14
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily
    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    OperatorDiagnosticTable {
        id: memberTable
        width: root.width
        title: root.heading
        rows: root.rows
        titleSize: root.sectionTitleSize
        titleColor: root.textColor
        contentMargin: root.contentMargin
        bodyTop: root.bodyTop
        labelSize: root.noteSize
        valueSize: root.inputSize
        surfaceColor: root.surfaceColor
        textColor: root.textColor
        mutedColor: root.mutedColor
        outlineColor: root.separatorColor
        separatorColor: root.separatorColor
        fontFamily: root.fontFamily
    }
}
