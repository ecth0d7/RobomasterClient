import QtQuick

// Frozen provenance readout. No adapter, verifier or suggestion is created here.
Item {
    id: root
    implicitWidth: 1000
    implicitHeight: recordSection.height
    width: implicitWidth
    height: implicitHeight
    property string heading: "实际输入来源 · 尚未采集"
    property string sourceText: "未接通来源记录"
    property string timeText: "产生与接收时间未报告"
    property string clockText: "时钟与测量置信度未核验"
    property string lifetimeText: "寿命未报告"
    property string identityText: "没有实际输入身份"
    property string teamText: ""
    property string boundaryText: "此项为模型实际使用的来源记录；接纳和签名不证明测量绝对准确，不授予官方遥测权威或机器人动作权限。"
    property real fieldSpacing: 8
    property real contentMargin: 14
    property real bodyTop: 47
    property real titleSize: 14
    property real noteSize: 12
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily
    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    OperatorSection {
        id: recordSection
        width: root.width
        height: facts.implicitHeight + bodyTop + contentMargin
        title: root.heading
        titleSize: root.titleSize
        fontFamily: root.fontFamily
        contentMargin: root.contentMargin
        bodyTop: root.bodyTop
        surfaceColor: root.surfaceColor
        outlineColor: root.separatorColor
        Column {
            id: facts
            parent: recordSection.sectionBody
            width: parent.width
            spacing: root.fieldSpacing
            OperatorAdviceSetupNoteForm { width: parent.width; text: root.sourceText; size: root.noteSize; color: root.mutedColor; fontFamily: root.fontFamily }
            OperatorAdviceSetupNoteForm { width: parent.width; text: root.timeText; size: root.noteSize; color: root.mutedColor; fontFamily: root.fontFamily }
            OperatorAdviceSetupNoteForm { width: parent.width; text: root.clockText; size: root.noteSize; color: root.mutedColor; fontFamily: root.fontFamily }
            OperatorAdviceSetupNoteForm { width: parent.width; text: root.lifetimeText; size: root.noteSize; color: root.mutedColor; fontFamily: root.fontFamily }
            OperatorAdviceSetupNoteForm { width: parent.width; text: root.identityText; size: root.noteSize; color: root.mutedColor; fontFamily: root.fontFamily }
            OperatorAdviceSetupNoteForm { width: parent.width; visible: root.teamText.length > 0; text: root.teamText; size: root.noteSize; color: root.mutedColor; fontFamily: root.fontFamily }
            OperatorAdviceSetupNoteForm { width: parent.width; text: root.boundaryText; size: root.noteSize; color: root.warningColor; fontFamily: root.fontFamily }
        }
    }
}
