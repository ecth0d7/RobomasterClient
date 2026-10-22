import QtQuick

// 队伍提供者的实际绘制层；配置与核验能力均由原生宿主提供。
OperatorSection {
    id: root
    property alias providerControl: providerSelect.selectControl
    property alias refreshControl: refreshButton
    property alias saveControl: saveButton
    property alias undoControl: undoButton
    property var providerTitles: []
    property int providerIndex: -1
    property bool providerEditable: false
    property bool refreshEnabled: false
    property bool saveEnabled: false
    property bool undoEnabled: false
    property string providerEmptyText: "Designer布局参考 · 未接通原生目录"
    property string statusText: "Designer布局参考 · 没有真实共享提供者"
    property string reviewMessage: "本表单不创建队友、网络连接或核验结果。"
    property string boundaryMessage: "提供者选择与共享身份分开；独立主机验签不采用插件自报的可信标记。"
    property var identityRows: [{label: "原生宿主", value: "未接通", detail: true}]
    property real formSpacing: 12
    property real actionSpacing: 12
    property real refreshWidth: 210
    property real saveWidth: 210
    property real undoWidth: 180
    property real labelHeight: 26
    property real labelGap: 4
    property real controlHeight: 38
    property real hintGap: 8
    property real minimumHintHeight: 26
    property real hintBottomPadding: 4
    property real labelSize: 12
    property real noteSize: 12
    property real inputSize: 14
    property color textColor: Theme.text
    property color labelColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property color inputSurfaceColor: "#232c27"
    property string inputFontFamily: root.fontFamily
    surfaceColor: Theme.hudSolid
    title: "队内共享提供者 · 独立选择与核验"
    width: 1300
    height: providerContent.implicitHeight + root.bodyTop + root.contentMargin

    Column {
        id: providerContent
        width: parent.width
        spacing: root.formSpacing
        OperatorSetupSelectForm {
            id: providerSelect
            selectControl.objectName: "terminalTeamProviderSelect"
            width: parent.width
            label: "已发现且匹配 terminal-team / terminal.team@3 的原生能力"
            choices: root.providerTitles
            selectedIndex: root.providerIndex
            selectionText: root.providerIndex >= 0 && root.providerIndex < root.providerTitles.length ? root.providerTitles[root.providerIndex] : root.providerEmptyText
            editable: root.providerEditable
            labelHeight: root.labelHeight
            labelGap: root.labelGap
            controlHeight: root.controlHeight
            hintGap: root.hintGap
            minimumHintHeight: root.minimumHintHeight
            hintBottomPadding: root.hintBottomPadding
            labelSize: root.labelSize
            noteSize: root.noteSize
            inputSize: root.inputSize
            fontFamily: root.fontFamily
            inputFontFamily: root.inputFontFamily
            textColor: root.textColor
            mutedColor: root.labelColor
            warningColor: root.warningColor
            inputSurfaceColor: root.inputSurfaceColor
            inputBorderColor: root.separatorColor
        }
        Flow {
            width: parent.width
            spacing: root.actionSpacing
            OperatorButton { id: refreshButton; objectName: "terminalTeamRefreshProviders"; width: Math.min(root.refreshWidth, parent.width); height: root.controlHeight; text: "刷新共享提供者目录"; enabled: root.refreshEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
            OperatorButton { id: saveButton; objectName: "terminalTeamSaveProvider"; width: Math.min(root.saveWidth, parent.width); height: root.controlHeight; text: "保存所选共享提供者"; primary: true; enabled: root.saveEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
            OperatorButton { id: undoButton; objectName: "terminalTeamUndoProvider"; width: Math.min(root.undoWidth, parent.width); height: root.controlHeight; text: "撤销提供者修改"; enabled: root.undoEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
        }
        OperatorText {
            width: parent.width; height: implicitHeight
            text: root.statusText; size: root.noteSize; color: root.labelColor; font.family: root.fontFamily
            wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        OperatorText {
            width: parent.width; height: implicitHeight; visible: root.reviewMessage.length > 0
            text: root.reviewMessage; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily
            wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        OperatorDiagnosticTable {
            width: parent.width
            title: "预期能力与独立宿主核验状态"
            rows: root.identityRows
            titleSize: root.titleSize
            titleColor: root.titleColor
            fontFamily: root.fontFamily
            labelSize: root.noteSize
            valueSize: root.inputSize
            textColor: root.textColor
            mutedColor: root.labelColor
            separatorColor: root.separatorColor
            outlineColor: root.separatorColor
            surfaceColor: root.surfaceColor
            contentMargin: root.contentMargin
            bodyTop: root.bodyTop
        }
        OperatorText {
            width: parent.width; height: implicitHeight
            text: root.boundaryMessage; size: root.noteSize; color: root.labelColor; font.family: root.fontFamily
            wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
    }
}
