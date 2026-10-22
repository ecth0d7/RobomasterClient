import QtQuick

// A catalog capability's description/reference, without inferred telemetry.
Item {
    id: root
    objectName: "seasonCapabilityForm"
    implicitWidth: 920
    implicitHeight: section.height
    width: implicitWidth
    height: implicitHeight
    property string heading: "规则机制 · 未接通目录"
    property string summaryText: "Designer绘制参考 · 尚未提供已核实的机制说明。"
    property string referenceText: "版本、状态与规则页码等待目录提供。"
    property real formSpacing: 12
    property real referenceMinimumHeight: 28
    property real contentMargin: 14
    property real bodyTop: 47
    property real titleSize: 14
    property real noteSize: 11
    property real inputSize: 13
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    OperatorSection {
        id: section
        width: root.width
        height: contentColumn.implicitHeight + bodyTop + contentMargin
        title: root.heading
        contentMargin: root.contentMargin
        bodyTop: root.bodyTop
        titleSize: root.titleSize
        titleColor: root.textColor
        surfaceColor: root.surfaceColor
        outlineColor: root.separatorColor
        fontFamily: root.fontFamily
        Column {
            id: contentColumn
            width: parent.width
            spacing: root.formSpacing
            OperatorText {
                width: parent.width
                height: implicitHeight
                text: root.summaryText
                size: root.inputSize
                color: root.textColor
                font.family: root.fontFamily
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
            OperatorText {
                width: parent.width
                height: Math.max(root.referenceMinimumHeight, implicitHeight)
                text: root.referenceText
                size: root.noteSize
                color: root.mutedColor
                font.family: root.fontFamily
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
        }
    }
}
