import QtQuick

// Preformatted project-planning text; no field or producer state is invented.
Item {
    id: root
    objectName: "seasonOpportunityForm"
    implicitWidth: 1300
    implicitHeight: section.height
    width: implicitWidth
    height: implicitHeight
    property string heading: "数据机会 · 未接通目录"
    property string sourceText: "Designer绘制参考 · 没有提供来源规划。"
    property string refreshText: "尚未提供采集／刷新方式。"
    property string trustText: "尚未提供可信度／时序说明。"
    property string useText: "候选字段与生产接入状态等待目录提供；本Form不接通生产数据。"
    property real formSpacing: 7
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
            OperatorText { width: parent.width; height: implicitHeight; text: root.sourceText; size: root.inputSize; color: root.textColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; text: root.refreshText; size: root.inputSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; text: root.trustText; size: root.inputSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; text: root.useText; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        }
    }
}
