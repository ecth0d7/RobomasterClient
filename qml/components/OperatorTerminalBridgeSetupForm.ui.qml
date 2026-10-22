import QtQuick
import QtQuick.Layouts

// 可视化绘制层。真实配置、保存和启停由行为包装与原生宿主接线。
Item {
    id: root
    implicitWidth: 1300
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property alias providerControl: providerSelect
    property alias refreshControl: refreshButton
    property alias saveControl: saveButton
    property alias enableControl: enableButton
    property alias stopControl: stopButton
    property alias undoControl: undoButton
    property alias bindControl: bindInput
    property alias listenPortControl: listenPortInput
    property alias peerControl: peerInput
    property alias tokenEnvControl: tokenEnvInput
    property alias listenControl: listenCheck
    property alias snapshotControl: snapshotCheck
    property alias eventsControl: eventsCheck
    property var providerTitles: []
    property int providerIndex: -1
    property string providerEmptyText: "Designer绘制参考 · 原生桥接目录未接通"
    property string bindValue: ""
    property string listenPortValue: ""
    property string peerValue: ""
    property string tokenEnvValue: ""
    property bool listenValue: false
    property bool snapshotsValue: false
    property bool eventsValue: false
    property bool configurationEditable: false
    property bool providerEditable: false
    property bool canRefresh: false
    property bool canSave: false
    property bool canEnable: false
    property bool canStop: false
    property bool canUndo: false
    property string statusText: "Designer绘制参考 · 没有创建桥接端点、监听端口或来源数据。"
    property string reviewMessage: "尚未接通原生宿主；本表单不连接、不保存秘密或注入数据。"
    property string validationMessage: ""
    property string lockMessage: ""
    property var identityRows: [{label: "原生宿主", value: "未接通", detail: true}]
    property var bridgeRows: [{label: "实际传输", value: "未报告", detail: true}]
    property real sectionSpacing: 16
    property real formSpacing: 12
    property real columnGap: 16
    property real breakpoint: 760
    property real fieldSpacing: 8
    property real actionSpacing: 12
    property real actionWidth: 190
    property real labelHeight: 24
    property real controlHeight: 38
    property real labelSize: 12
    property real inputSize: 14
    property real noteSize: 12
    property real sectionTitleSize: 14
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property string fontFamily: Theme.fontFamily

    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
        z: -1
    }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.sectionSpacing
        OperatorText {
            width: parent.width
            height: implicitHeight
            text: "仅用于赛外实验室调试。此桥接交换历史schema1快照／事件，不是schema3队内汇总或2027官方数据入口。明文TCP与共享令牌不证明可信队友身份；不直接向AI或机器人发送动作。"
            size: root.noteSize
            color: root.warningColor
            font.family: root.fontFamily
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
        OperatorSection {
            id: providerSection
            width: parent.width
            height: providerColumn.implicitHeight + bodyTop + contentMargin
            surfaceColor: root.surfaceColor
            titleSize: root.sectionTitleSize
            title: "实验室桥接提供者 · 保存与启用分开"
            Column {
                id: providerColumn
                width: parent.width
                spacing: root.formSpacing
                OperatorText {
                    width: parent.width
                    height: root.labelHeight
                    text: "准确的原生桥接提供者"
                    size: root.labelSize
                    color: root.mutedColor
                    font.family: root.fontFamily
                }
                OperatorSelect {
                    id: providerSelect
                    objectName: "terminalBridgeProviderSelect"
                    width: parent.width
                    height: root.controlHeight
                    label: "实验室桥接提供者"
                    model: root.providerTitles
                    currentIndex: root.providerIndex
                    displayText: root.providerIndex >= 0 && root.providerIndex < root.providerTitles.length ? root.providerTitles[root.providerIndex] : root.providerEmptyText
                    emptyText: root.providerEmptyText
                    enabled: root.providerEditable
                    font.family: root.fontFamily
                }
                Flow {
                    width: parent.width
                    spacing: root.actionSpacing
                    OperatorButton { id: saveButton; objectName: "terminalBridgeSave"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "保存桥接配置"; primary: true; enabled: root.canSave; font.family: root.fontFamily }
                    OperatorButton { id: enableButton; objectName: "terminalBridgeEnable"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "启用已保存桥接"; enabled: root.canEnable; font.family: root.fontFamily }
                    OperatorButton { id: stopButton; objectName: "terminalBridgeStop"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "停止本宿主桥接"; enabled: root.canStop; font.family: root.fontFamily }
                    OperatorButton { id: undoButton; objectName: "terminalBridgeUndo"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "撤销修改"; enabled: root.canUndo; font.family: root.fontFamily }
                    OperatorButton { id: refreshButton; objectName: "terminalBridgeRefreshProviders"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "刷新提供者目录"; enabled: root.canRefresh; font.family: root.fontFamily }
                }
                OperatorText { width: parent.width; height: implicitHeight; text: root.statusText; size: root.noteSize; color: root.textColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorText { width: parent.width; height: implicitHeight; visible: root.reviewMessage.length > 0; text: root.reviewMessage; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorText { width: parent.width; height: implicitHeight; visible: root.lockMessage.length > 0; text: root.lockMessage; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorDiagnosticTable { width: parent.width; title: "准确选择与当前所有权"; rows: root.identityRows }
            }
        }
        OperatorSection {
            id: connectionSection
            width: parent.width
            height: connectionColumn.implicitHeight + bodyTop + contentMargin
            surfaceColor: root.surfaceColor
            titleSize: root.sectionTitleSize
            title: "训练连接参数 · 明文TCP"
            Column {
                id: connectionColumn
                width: parent.width
                spacing: root.formSpacing
                OperatorCheckBox {
                    id: listenCheck
                    objectName: "terminalBridgeListen"
                    width: parent.width
                    height: root.controlHeight
                    text: "启用后监听本机地址"
                    checked: root.listenValue
                    enabled: root.configurationEditable
                    font.family: root.fontFamily
                }
                GridLayout {
                    width: parent.width
                    columns: width >= root.breakpoint ? 2 : 1
                    columnSpacing: root.columnGap
                    rowSpacing: root.formSpacing
                    Column {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        spacing: root.fieldSpacing
                        OperatorText { width: parent.width; height: root.labelHeight; text: "监听数字地址"; size: root.labelSize; color: root.mutedColor; font.family: root.fontFamily }
                        OperatorInput { id: bindInput; objectName: "terminalBridgeBind"; width: parent.width; height: root.controlHeight; label: "监听IPv4或IPv6数字地址"; text: root.bindValue; maximumLength: 256; enabled: root.configurationEditable; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                        OperatorText { width: parent.width; height: implicitHeight; text: "使用真实IPv4／IPv6数字地址。非回环监听须在启用时提供实际共享令牌。"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    }
                    Column {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        spacing: root.fieldSpacing
                        OperatorText { width: parent.width; height: root.labelHeight; text: "请求监听端口"; size: root.labelSize; color: root.mutedColor; font.family: root.fontFamily }
                        OperatorInput { id: listenPortInput; objectName: "terminalBridgeListenPort"; width: parent.width; height: root.controlHeight; label: "监听端口，0至65535"; text: root.listenPortValue; maximumLength: 5; enabled: root.configurationEditable; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                        OperatorText { width: parent.width; height: implicitHeight; text: "0表示启用监听时由系统分配；实际打开的端口在下方单独报告。"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    }
                    Column {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        spacing: root.fieldSpacing
                        OperatorText { width: parent.width; height: root.labelHeight; text: "明确的外连对端 · 可留空"; size: root.labelSize; color: root.mutedColor; font.family: root.fontFamily }
                        OperatorInput { id: peerInput; objectName: "terminalBridgePeer"; width: parent.width; height: root.controlHeight; label: "tcp://主机:端口，不含账号或路径"; text: root.peerValue; maximumLength: 2048; enabled: root.configurationEditable; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                        OperatorText { width: parent.width; height: implicitHeight; text: "需要外连时填写实际tcp://主机:端口，不预填服务器。关闭监听时须配置对端。"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    }
                    Column {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        spacing: root.fieldSpacing
                        OperatorText { width: parent.width; height: root.labelHeight; text: "共享令牌的环境变量名"; size: root.labelSize; color: root.mutedColor; font.family: root.fontFamily }
                        OperatorInput { id: tokenEnvInput; objectName: "terminalBridgeTokenEnv"; width: parent.width; height: root.controlHeight; label: "保存共享令牌的环境变量名，不是令牌值"; text: root.tokenEnvValue; maximumLength: 96; enabled: root.configurationEditable; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                        OperatorText { width: parent.width; height: implicitHeight; text: "只保存变量名；实际值由原生宿主在启用时读取，不回显、不写入设置。令牌不提供TLS或队友身份认证。"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    }
                }
                OperatorText { width: parent.width; height: implicitHeight; visible: root.validationMessage.length > 0; text: root.validationMessage; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
        OperatorSection {
            id: exportSection
            width: parent.width
            height: exportColumn.implicitHeight + bodyTop + contentMargin
            surfaceColor: root.surfaceColor
            titleSize: root.sectionTitleSize
            title: "允许导出的历史数据 · 默认关闭"
            Column {
                id: exportColumn
                width: parent.width
                spacing: root.formSpacing
                OperatorCheckBox { id: snapshotCheck; objectName: "terminalBridgeExportSnapshots"; width: parent.width; height: root.controlHeight; text: "允许导出历史schema1遥测快照"; checked: root.snapshotsValue; enabled: root.configurationEditable; font.family: root.fontFamily }
                OperatorCheckBox { id: eventsCheck; objectName: "terminalBridgeExportEvents"; width: parent.width; height: root.controlHeight; text: "允许导出历史schema1事件"; checked: root.eventsValue; enabled: root.configurationEditable; font.family: root.fontFamily }
                OperatorText { width: parent.width; height: implicitHeight; text: "两个开关分别授权实际导出。收到的实验室来源仍未认证、未校验生产时钟，不混入schema3队伍视图或模型输入；导出接纳也不等于远端送达。"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
        OperatorDiagnosticTable {
            width: parent.width
            title: "实际传输与来源状态 · 不作为可信证明"
            rows: root.bridgeRows
        }
    }
}
