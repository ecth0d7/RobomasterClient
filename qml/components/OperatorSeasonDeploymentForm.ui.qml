import QtQuick

// 部署说明与文档列表的绘制。规则结论由包装传入，不在Form声明协议可用性。
Item {
    id: root
    objectName: "seasonDeploymentForm"
    implicitWidth: 1300
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property string flowTitle: "Designer绘制参考 · 原生规则路径未接通"
    property string flowText: "未提供已核实的数据接入路径。"
    property string localPathText: ""
    property string sharingText: ""
    property string competitionText: "Designer绘制参考 · 未读取比赛部署政策。"
    property string speechText: ""
    property string rendererText: ""
    property int documentCount: 0
    property Component documentDelegate: null
    readonly property real documentDelegateWidth: documentsColumn.width
    property real sectionSpacing: 16
    property real formSpacing: 12
    property real fieldSpacing: 8
    property real contentMargin: 14
    property real bodyTop: 47
    property real sectionTitleSize: 14
    property real flowSize: 17
    property real noteSize: 12
    property real inputSize: 13
    property real separatorHeight: 1
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property string fontFamily: Theme.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.sectionSpacing
        OperatorSection {
            id: flowSection
            objectName: "seasonDeploymentPathSection"
            width: parent.width
            height: flowColumn.implicitHeight + bodyTop + contentMargin
            title: root.flowTitle
            contentMargin: root.contentMargin
            bodyTop: root.bodyTop
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            titleColor: root.textColor
            outlineColor: root.separatorColor
            Column {
                id: flowColumn
                parent: flowSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorText { width: parent.width; height: implicitHeight; text: root.flowText; size: root.flowSize; color: root.textColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                Rectangle { width: parent.width; height: root.separatorHeight; color: root.separatorColor }
                OperatorText { width: parent.width; height: implicitHeight; visible: root.localPathText.length > 0; text: root.localPathText; size: root.inputSize; color: root.textColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorText { width: parent.width; height: implicitHeight; visible: root.sharingText.length > 0; text: root.sharingText; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
        OperatorSection {
            id: policySection
            objectName: "seasonDeploymentPolicySection"
            width: parent.width
            height: policyColumn.implicitHeight + bodyTop + contentMargin
            title: "比赛部署与模型／语音"
            contentMargin: root.contentMargin
            bodyTop: root.bodyTop
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            titleColor: root.textColor
            outlineColor: root.separatorColor
            Column {
                id: policyColumn
                parent: policySection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorText { width: parent.width; height: implicitHeight; text: root.competitionText; size: root.inputSize; color: root.textColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorText { width: parent.width; height: implicitHeight; visible: root.speechText.length > 0; text: root.speechText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorText { width: parent.width; height: implicitHeight; visible: root.rendererText.length > 0; text: root.rendererText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
        Column {
            id: documentsColumn
            objectName: "seasonDeploymentDocuments"
            width: parent.width
            spacing: root.sectionSpacing
            visible: root.documentCount > 0
            Repeater { model: root.documentCount; delegate: root.documentDelegate }
        }
    }
}
