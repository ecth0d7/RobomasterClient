import QtQuick

// 单个实际观测的纯文本绘制；没有默认数值、时间戳或伪造的传感器身份。
Item {
    id: root
    objectName: "seasonLocalObservationForm"
    implicitWidth: 1000
    implicitHeight: observationColumn.y + observationColumn.implicitHeight + root.contentMargin
    width: implicitWidth
    height: implicitHeight
    property string titleText: "Designer绘制参考 · 未接通本地观测"
    property string identityText: "没有真实来源身份。"
    property string valueText: "没有观测值或置信度。"
    property string timingText: "没有序号、接收年龄或剩余寿命。"
    property string verificationText: "没有验证／标定结果，不授予模型或动作权限。"
    property real sectionSpacing: 12
    property real formSpacing: 12
    property real fieldSpacing: 6
    property real contentMargin: 14
    property real bodyTop: 47
    property real titleTop: 9
    property real sectionTitleSize: 14
    property real identitySize: 13
    property real noteSize: 12
    property real inputSize: 14
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    OperatorOutline { color: root.separatorColor }
    OperatorText {
        id: heading
        x: root.contentMargin
        y: root.titleTop
        width: Math.max(0, root.width - root.contentMargin * 2)
        height: implicitHeight
        text: root.titleText
        size: root.sectionTitleSize
        color: root.textColor
        font.family: root.fontFamily
        font.bold: true
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }
    Column {
        id: observationColumn
        x: root.contentMargin
        y: Math.max(root.bodyTop, heading.y + heading.height + root.fieldSpacing)
        width: Math.max(0, root.width - root.contentMargin * 2)
        spacing: root.fieldSpacing
        OperatorText { width: parent.width; height: implicitHeight; text: root.identityText; size: root.identitySize; color: root.textColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: implicitHeight; text: root.valueText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: implicitHeight; text: root.timingText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: implicitHeight; text: root.verificationText; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
    }
}
