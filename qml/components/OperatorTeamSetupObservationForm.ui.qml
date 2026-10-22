import QtQuick

// Source lineage is a native readout. This Form cannot certify a measurement,
// refresh a lifetime, publish a value, feed a model or issue a robot command.
Item {
    id: root
    implicitWidth: 1000
    implicitHeight: observationSection.height
    width: implicitWidth
    height: implicitHeight
    property string heading: "共享观测 · Designer绘制参考，未接通"
    property string valueText: "未接通：没有已提交观测值"
    property string sourceText: "来源未提供"
    property string typeText: "验证状态未提供"
    property string timeText: "时间未提供"
    property string lifetimeText: "寿命未提供"
    property string lineageText: "来源会话未提供"
    property string proofText: "签名证明未核验"
    property string permissionText: "没有用途授权；不授予官方权威或自动动作。"
    property string frameText: ""
    property real fieldSpacing: 8
    property real contentMargin: 14
    property real bodyTop: 47
    property real sectionTitleSize: 14
    property real noteSize: 12
    property real valueSize: 13
    property color valueColor: Theme.text
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily
    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    OperatorSection {
        id: observationSection
        width: root.width
        height: facts.implicitHeight + bodyTop + contentMargin
        title: root.heading
        titleSize: root.sectionTitleSize
        titleColor: root.textColor
        fontFamily: root.fontFamily
        contentMargin: root.contentMargin
        bodyTop: root.bodyTop
        surfaceColor: root.surfaceColor
        outlineColor: root.separatorColor
        Column {
            id: facts
            width: parent.width
            spacing: root.fieldSpacing
            OperatorText { width: parent.width; height: implicitHeight; text: root.valueText; size: root.valueSize; color: root.valueColor; font.family: root.fontFamily; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; text: root.sourceText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; text: root.typeText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; text: root.timeText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; text: root.lifetimeText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; text: root.lineageText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; text: root.proofText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; text: root.permissionText; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
            OperatorText { width: parent.width; height: implicitHeight; visible: root.frameText.length > 0; text: root.frameText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
        }
    }
}
