import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// 完整链路页绘制。所有配置、确认与发送行为由普通QML包装和原生Gateway处理。
Item {
    id: root
    objectName: "terminalLinkPageForm"
    implicitWidth: 1300
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property alias planeControl: providerSection.planeControl
    property alias providerControl: providerSection.providerControl
    property alias refreshControl: providerSection.refreshControl
    property alias hostControl: hostField.inputControl
    property alias portControl: portField.inputControl
    property alias clientIdControl: clientIdField.inputControl
    property alias receiveTopicsControl: receiveTopicsInput
    property alias sendTopicsControl: sendTopicsInput
    property alias bindAddressControl: bindAddressField.inputControl
    property alias bindPortControl: bindPortField.inputControl
    property alias peerAddressControl: peerAddressField.inputControl
    property alias peerPortControl: peerPortField.inputControl
    property alias saveControl: saveButton
    property alias enableControl: enableButton
    property alias stopControl: stopButton
    property alias undoControl: undoButton
    property alias mockControl: mockButton
    property alias channelControl: channelSelect.selectControl
    property alias packageChannelControl: packageChannelInput
    property alias payloadControl: payloadInput
    property alias confirmationControl: confirmationCheck
    property alias sendControl: sendButton
    property var planeTitles: []
    property var providerTitles: []
    property int planeSelectedIndex: -1
    property int providerSelectedIndex: -1
    property bool planeEditable: false
    property bool providerEditable: false
    property bool refreshEnabled: false
    property bool configurationEditable: false
    property bool showPackage: false
    property bool showMqtt: false
    property bool showUdp: false
    property bool showLoopback: false
    property bool packageWarningVisible: false
    property string providerEmptyText: "Designer绘制参考 · 原生提供者未接通"
    property string dirtyMessage: ""
    property string lockMessage: "Designer绘制参考 · 原生链路宿主未接通"
    property string unsavedMessage: "没有保存或启用真实链路；本表单不连接、不发送。"
    property var providerStatusRows: [{label: "原生链路宿主", value: "未接通", detail: true}]
    property var packageIdentityRows: []
    property var transferRows: [{label: "实际收发", value: "未报告", detail: true}]
    property string hostValue: ""
    property string portValue: ""
    property string clientIdValue: ""
    property string receiveTopicsValue: ""
    property string sendTopicsValue: ""
    property string bindAddressValue: ""
    property string bindPortValue: ""
    property string peerAddressValue: ""
    property string peerPortValue: ""
    property string validationMessage: ""
    property string statusText: "Designer绘制参考 · 未创建传输端点或接收包。"
    property bool statusEmphasized: false
    property bool saveEnabled: false
    property bool enableEnabled: false
    property bool stopEnabled: false
    property bool undoEnabled: false
    property bool mockEnabled: false
    property var channelTitles: []
    property int channelSelectedIndex: -1
    property string channelSelectionText: "明确选择已保存配置允许的发送通道"
    property string packageChannelValue: ""
    property string payloadValue: ""
    property bool channelEditable: false
    property bool confirmationValue: false
    property bool confirmationEnabled: false
    property bool sendEnabled: false
    property int packetCount: 0
    property Component packetDelegate: null
    readonly property real packetDelegateWidth: packetColumn.width
    property real sectionSpacing: 16
    property real formSpacing: 12
    property real formColumnGap: 12
    property real fieldSpacing: 8
    property real actionWidth: 190
    property real stopWidth: 156
    property real undoWidth: 180
    property real mockWidth: 230
    property real sendWidth: 260
    property real refreshWidth: 210
    property real topicHeight: 106
    property real payloadHeight: 106
    property real controlHeight: 38
    property real fieldLabelHeight: 26
    property real fieldLabelGap: 4
    property real fieldHintGap: 8
    property real fieldHintMinimumHeight: 26
    property real fieldHintBottomPadding: 4
    property real sectionContentMargin: 14
    property real sectionBodyTop: 47
    property real providerBreakpoint: 760
    property real mqttWideBreakpoint: 1040
    property real mqttBreakpoint: 650
    property real udpBreakpoint: 760
    property real sectionTitleSize: 14
    property real introSize: 13
    property real labelSize: 12
    property real noteSize: 12
    property real inputSize: 14
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property color inputSurfaceColor: "#232c27"
    property string fontFamily: Theme.fontFamily
    property string inputFontFamily: root.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.sectionSpacing
        OperatorText { width: parent.width; height: implicitHeight; size: root.introSize; color: root.warningColor; font.family: root.fontFamily; text: "三个平面独立保存与启停。这里处理真实原始字节，不猜测2027官方字段；未分类数据不冒充裁判遥测。当前仅允许明确训练用途，正式绑定由独立协议适配器核验。"; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        OperatorTerminalLinkSetupForm {
            id: providerSection
            objectName: "terminalLinkProviderSection"
            width: parent.width
            planeTitles: root.planeTitles
            providerTitles: root.providerTitles
            planeIndex: root.planeSelectedIndex
            providerIndex: root.providerSelectedIndex
            planeEditable: root.planeEditable
            providerEditable: root.providerEditable
            refreshEnabled: root.refreshEnabled
            providerEmptyText: root.providerEmptyText
            dirtyMessage: root.dirtyMessage
            lockMessage: root.lockMessage
            unsavedMessage: root.unsavedMessage
            statusRows: root.providerStatusRows
            formSpacing: root.formSpacing
            columnGap: root.formColumnGap
            breakpoint: root.providerBreakpoint
            labelHeight: root.fieldLabelHeight
            labelGap: root.fieldLabelGap
            fieldSpacing: root.fieldSpacing
            hintGap: root.fieldHintGap
            minimumHintHeight: root.fieldHintMinimumHeight
            hintBottomPadding: root.fieldHintBottomPadding
            refreshWidth: root.refreshWidth
            controlHeight: root.controlHeight
            labelSize: root.labelSize
            noteSize: root.noteSize
            inputSize: root.inputSize
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            surfaceColor: root.surfaceColor
            titleColor: root.textColor
            textColor: root.textColor
            labelColor: root.mutedColor
            warningColor: root.warningColor
            separatorColor: root.separatorColor
            outlineColor: root.separatorColor
            inputSurfaceColor: root.inputSurfaceColor
            inputFontFamily: root.inputFontFamily
        }
        OperatorSection {
            id: packageSection
            objectName: "terminalLinkPackageSection"
            visible: root.showPackage
            width: parent.width
            height: packageColumn.implicitHeight + bodyTop + contentMargin
            title: "社区传输能力 · 精确身份"
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            titleColor: root.textColor
            outlineColor: root.separatorColor
            Column {
                id: packageColumn
                parent: packageSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorDiagnosticTable { width: parent.width; title: "当前编辑的预期提供者"; rows: root.packageIdentityRows; fontFamily: root.fontFamily; titleSize: root.sectionTitleSize; titleColor: root.textColor; textColor: root.textColor; mutedColor: root.mutedColor; separatorColor: root.separatorColor; outlineColor: root.separatorColor; labelSize: root.noteSize; valueSize: root.inputSize; contentMargin: root.sectionContentMargin; bodyTop: root.sectionBodyTop }
                OperatorText { width: parent.width; height: implicitHeight; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; text: "包专有的地址、凭据引用和通道允许列表在插件包管理中配置。本页只选择已审阅的原生工厂；保存时由宿主重新核验完整身份，未就绪时保留原选择。"; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorText { width: parent.width; height: implicitHeight; visible: root.packageWarningVisible; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; text: "插件缺失、依赖丢失或配置变化。先检查插件管理，再从目录明确选择当前能力；恢复后不会自动启用旧会话。"; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
        OperatorSection {
            id: mqttSection
            objectName: "terminalLinkMqttSection"
            visible: root.showMqtt
            width: parent.width
            height: mqttColumn.implicitHeight + bodyTop + contentMargin
            title: "MQTT原始字节 · 明确地址与收发主题"
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            titleColor: root.textColor
            outlineColor: root.separatorColor
            Column {
                id: mqttColumn
                parent: mqttSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                GridLayout {
                    width: parent.width
                    columns: width >= root.mqttWideBreakpoint ? 3 : width >= root.mqttBreakpoint ? 2 : 1
                    columnSpacing: root.formColumnGap
                    rowSpacing: root.fieldSpacing
            OperatorStartupFieldForm {
                id: hostField
                inputControl.objectName: "terminalLinkMqttHost"
                label: "消息服务器地址"
                maximumLength: 253
                value: root.hostValue
                hint: "由实际训练源提供，不预设2027赛事服务器。"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                editable: root.configurationEditable
                labelHeight: root.fieldLabelHeight
                labelGap: root.fieldLabelGap
                controlHeight: root.controlHeight
                hintGap: root.fieldHintGap
                minimumHintHeight: root.fieldHintMinimumHeight
                hintBottomPadding: root.fieldHintBottomPadding
                labelSize: root.labelSize
                inputSize: root.inputSize
                hintSize: root.noteSize
                fontFamily: root.fontFamily
                inputFontFamily: root.inputFontFamily
                textColor: root.textColor
                secondaryTextColor: root.mutedColor
                warningColor: root.warningColor
                inputSurfaceColor: root.inputSurfaceColor
                inputBorderColor: root.separatorColor
            }
            OperatorStartupFieldForm {
                id: portField
                inputControl.objectName: "terminalLinkMqttPort"
                label: "端口"
                maximumLength: 5
                value: root.portValue
                hint: "1–65535，由真实部署提供。"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                editable: root.configurationEditable
                labelHeight: root.fieldLabelHeight
                labelGap: root.fieldLabelGap
                controlHeight: root.controlHeight
                hintGap: root.fieldHintGap
                minimumHintHeight: root.fieldHintMinimumHeight
                hintBottomPadding: root.fieldHintBottomPadding
                labelSize: root.labelSize
                inputSize: root.inputSize
                hintSize: root.noteSize
                fontFamily: root.fontFamily
                inputFontFamily: root.inputFontFamily
                textColor: root.textColor
                secondaryTextColor: root.mutedColor
                warningColor: root.warningColor
                inputSurfaceColor: root.inputSurfaceColor
                inputBorderColor: root.separatorColor
            }
            OperatorStartupFieldForm {
                id: clientIdField
                inputControl.objectName: "terminalLinkMqttClientId"
                label: "本地客户端标识"
                maximumLength: 96
                value: root.clientIdValue
                hint: "项目链路标识，不冒充官方登录ID。"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                editable: root.configurationEditable
                labelHeight: root.fieldLabelHeight
                labelGap: root.fieldLabelGap
                controlHeight: root.controlHeight
                hintGap: root.fieldHintGap
                minimumHintHeight: root.fieldHintMinimumHeight
                hintBottomPadding: root.fieldHintBottomPadding
                labelSize: root.labelSize
                inputSize: root.inputSize
                hintSize: root.noteSize
                fontFamily: root.fontFamily
                inputFontFamily: root.inputFontFamily
                textColor: root.textColor
                secondaryTextColor: root.mutedColor
                warningColor: root.warningColor
                inputSurfaceColor: root.inputSurfaceColor
                inputBorderColor: root.separatorColor
            }
                }
                GridLayout {
                    width: parent.width
                    columns: width >= root.mqttBreakpoint ? 2 : 1
                    columnSpacing: root.formColumnGap
                    rowSpacing: root.fieldSpacing
                    Column {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        spacing: root.fieldSpacing
                        OperatorText { width: parent.width; height: implicitHeight; text: "接收主题 · 每行一个，最多32项"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                        ScrollView {
                            id: receiveScroll
                            width: parent.width
                            height: root.topicHeight
                            clip: true
                            contentWidth: availableWidth
                            OperatorTextArea { id: receiveTopicsInput; objectName: "terminalLinkReceiveTopics"; width: receiveScroll.availableWidth; label: "接收主题允许列表"; readOnly: !root.configurationEditable; text: root.receiveTopicsValue; color: root.textColor; backgroundColor: root.inputSurfaceColor; borderColor: root.separatorColor; font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                        }
                    }
                    Column {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        spacing: root.fieldSpacing
                        OperatorText { width: parent.width; height: implicitHeight; text: "发送主题 · 与接收列表分开"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                        ScrollView {
                            id: sendScroll
                            width: parent.width
                            height: root.topicHeight
                            clip: true
                            contentWidth: availableWidth
                            OperatorTextArea { id: sendTopicsInput; objectName: "terminalLinkSendTopics"; width: sendScroll.availableWidth; label: "发送主题允许列表"; readOnly: !root.configurationEditable; text: root.sendTopicsValue; color: root.textColor; backgroundColor: root.inputSurfaceColor; borderColor: root.separatorColor; font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                        }
                    }
                }
                OperatorText { width: parent.width; height: implicitHeight; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; text: "仅使用明确主题，不使用通配符或回环转发。QoS 0本地提交不证明远端收到，更不证明机器人执行。"; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
        OperatorSection {
            id: udpSection
            objectName: "terminalLinkUdpSection"
            width: parent.width
            visible: root.showUdp
            height: udpColumn.implicitHeight + bodyTop + contentMargin
            title: "UDP原始数据报 · 独立对端"
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            titleColor: root.textColor
            outlineColor: root.separatorColor
            GridLayout {
                id: udpColumn
                parent: udpSection.sectionBody
                width: parent.width
                columns: width >= root.udpBreakpoint ? 2 : 1
                columnSpacing: root.formColumnGap
                rowSpacing: root.fieldSpacing
            OperatorStartupFieldForm {
                id: bindAddressField
                inputControl.objectName: "terminalLinkUdpBindAddress"
                label: "本机绑定数字IP"
                maximumLength: 64
                value: root.bindAddressValue
                hint: "明确填写本机地址，不套用2026图传包头。"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                editable: root.configurationEditable
                labelHeight: root.fieldLabelHeight
                labelGap: root.fieldLabelGap
                controlHeight: root.controlHeight
                hintGap: root.fieldHintGap
                minimumHintHeight: root.fieldHintMinimumHeight
                hintBottomPadding: root.fieldHintBottomPadding
                labelSize: root.labelSize
                inputSize: root.inputSize
                hintSize: root.noteSize
                fontFamily: root.fontFamily
                inputFontFamily: root.inputFontFamily
                textColor: root.textColor
                secondaryTextColor: root.mutedColor
                warningColor: root.warningColor
                inputSurfaceColor: root.inputSurfaceColor
                inputBorderColor: root.separatorColor
            }
            OperatorStartupFieldForm {
                id: bindPortField
                inputControl.objectName: "terminalLinkUdpBindPort"
                label: "本机绑定端口"
                maximumLength: 5
                value: root.bindPortValue
                hint: "0–65535；0由系统分配临时端口。"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                editable: root.configurationEditable
                labelHeight: root.fieldLabelHeight
                labelGap: root.fieldLabelGap
                controlHeight: root.controlHeight
                hintGap: root.fieldHintGap
                minimumHintHeight: root.fieldHintMinimumHeight
                hintBottomPadding: root.fieldHintBottomPadding
                labelSize: root.labelSize
                inputSize: root.inputSize
                hintSize: root.noteSize
                fontFamily: root.fontFamily
                inputFontFamily: root.inputFontFamily
                textColor: root.textColor
                secondaryTextColor: root.mutedColor
                warningColor: root.warningColor
                inputSurfaceColor: root.inputSurfaceColor
                inputBorderColor: root.separatorColor
            }
            OperatorStartupFieldForm {
                id: peerAddressField
                inputControl.objectName: "terminalLinkUdpPeerAddress"
                label: "唯一对端数字IP"
                maximumLength: 64
                value: root.peerAddressValue
                hint: "收发绑定明确对端，其他来源由插件拒绝。"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                editable: root.configurationEditable
                labelHeight: root.fieldLabelHeight
                labelGap: root.fieldLabelGap
                controlHeight: root.controlHeight
                hintGap: root.fieldHintGap
                minimumHintHeight: root.fieldHintMinimumHeight
                hintBottomPadding: root.fieldHintBottomPadding
                labelSize: root.labelSize
                inputSize: root.inputSize
                hintSize: root.noteSize
                fontFamily: root.fontFamily
                inputFontFamily: root.inputFontFamily
                textColor: root.textColor
                secondaryTextColor: root.mutedColor
                warningColor: root.warningColor
                inputSurfaceColor: root.inputSurfaceColor
                inputBorderColor: root.separatorColor
            }
            OperatorStartupFieldForm {
                id: peerPortField
                inputControl.objectName: "terminalLinkUdpPeerPort"
                label: "唯一对端端口"
                maximumLength: 5
                value: root.peerPortValue
                hint: "1–65535，由真实训练源提供。"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                Layout.alignment: Qt.AlignTop
                editable: root.configurationEditable
                labelHeight: root.fieldLabelHeight
                labelGap: root.fieldLabelGap
                controlHeight: root.controlHeight
                hintGap: root.fieldHintGap
                minimumHintHeight: root.fieldHintMinimumHeight
                hintBottomPadding: root.fieldHintBottomPadding
                labelSize: root.labelSize
                inputSize: root.inputSize
                hintSize: root.noteSize
                fontFamily: root.fontFamily
                inputFontFamily: root.inputFontFamily
                textColor: root.textColor
                secondaryTextColor: root.mutedColor
                warningColor: root.warningColor
                inputSurfaceColor: root.inputSurfaceColor
                inputBorderColor: root.separatorColor
            }
            }
        }
        OperatorText { width: parent.width; height: implicitHeight; visible: root.showLoopback; text: "本机回环不打开网络。显式保存并启用后，可手动发送三个明确标记mock的观测，经过编码、插件队列、接收与总线接纳；不伪装为真实设备或赛事数据。"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: implicitHeight; visible: root.validationMessage.length > 0; text: root.validationMessage; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        Flow {
            width: parent.width
            spacing: root.formSpacing
            OperatorButton { id: saveButton; objectName: "terminalLinkSave"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "保存所选链路配置"; enabled: root.saveEnabled; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: enableButton; objectName: "terminalLinkEnable"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "启用已保存插件"; primary: true; enabled: root.enableEnabled; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: stopButton; objectName: "terminalLinkStop"; width: Math.min(root.stopWidth, parent.width); height: root.controlHeight; text: "停用此链路"; enabled: root.stopEnabled; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: undoButton; objectName: "terminalLinkUndo"; width: Math.min(root.undoWidth, parent.width); height: root.controlHeight; text: "撤销未保存修改"; enabled: root.undoEnabled; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: mockButton; objectName: "terminalLinkSendMock"; width: Math.min(root.mockWidth, parent.width); height: root.controlHeight; text: "发送mock并接收入总线"; enabled: root.mockEnabled; font.family: root.fontFamily; textColor: root.textColor }
        }
        OperatorText { width: parent.width; height: implicitHeight; text: root.statusText; color: root.statusEmphasized ? root.textColor : root.mutedColor; size: root.noteSize; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        OperatorSection {
            id: sendingSection
            objectName: "terminalLinkSendingSection"
            width: parent.width
            height: sendColumn.implicitHeight + bodyTop + contentMargin
            title: "手动发送 · 已保存训练对端"
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            titleColor: root.textColor
            outlineColor: root.separatorColor
            Column {
                id: sendColumn
                parent: sendingSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorSetupSelectForm {
                    id: channelSelect
                    width: parent.width
                    visible: !root.showPackage
                    label: "已保存配置允许的发送通道"
                    choices: root.channelTitles
                    selectedIndex: root.channelSelectedIndex
                    selectionText: root.channelSelectionText
                    editable: root.channelEditable
                    fieldSpacing: root.fieldSpacing
                    labelHeight: root.fieldLabelHeight
                    labelGap: root.fieldLabelGap
                    controlHeight: root.controlHeight
                    hintGap: root.fieldHintGap
                    minimumHintHeight: root.fieldHintMinimumHeight
                    hintBottomPadding: root.fieldHintBottomPadding
                    labelSize: root.labelSize
                    noteSize: root.noteSize
                    inputSize: root.inputSize
                    textColor: root.textColor
                    mutedColor: root.mutedColor
                    warningColor: root.warningColor
                    inputSurfaceColor: root.inputSurfaceColor
                    inputBorderColor: root.separatorColor
                    fontFamily: root.fontFamily
                    inputFontFamily: root.inputFontFamily
                }
                OperatorInput { id: packageChannelInput; objectName: "terminalLinkPackageChannel"; width: parent.width; height: root.controlHeight; visible: root.showPackage; label: "插件已审阅允许列表中的明确通道"; placeholderText: "填写实际允许的通道，不预设名称"; maximumLength: 256; enabled: root.configurationEditable; text: root.packageChannelValue; color: root.textColor; backgroundColor: root.inputSurfaceColor; borderColor: root.separatorColor; font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                OperatorText { width: parent.width; height: implicitHeight; visible: root.showPackage; text: "通道名称须来自该插件的实际配置。这里不生成通道或绕过允许列表；端点仍独立核验已审阅配置。未绑定明确通道的规范观测不会猜测发送路径。"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorText { width: parent.width; height: implicitHeight; text: "原始字节十六进制 · 最多64KiB"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                ScrollView {
                    id: payloadScroll
                    width: parent.width
                    height: root.payloadHeight
                    clip: true
                    contentWidth: availableWidth
                    OperatorTextArea { id: payloadInput; objectName: "terminalLinkSendPayload"; width: payloadScroll.availableWidth; label: "原始字节十六进制；最多64KiB"; readOnly: !root.configurationEditable; text: root.payloadValue; color: root.textColor; backgroundColor: root.inputSurfaceColor; borderColor: root.separatorColor; font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                }
                OperatorCheckBox { id: confirmationCheck; objectName: "terminalLinkSendConfirmation"; width: parent.width; height: root.controlHeight; text: "确认向当前训练对端提交这些字节；本地提交不代表送达或执行"; checked: root.confirmationValue; enabled: root.confirmationEnabled; font.family: root.fontFamily; textColor: root.textColor }
                OperatorButton { id: sendButton; objectName: "terminalLinkSendRaw"; width: Math.min(root.sendWidth, parent.width); height: root.controlHeight; text: "发送明确通道的原始字节"; enabled: root.sendEnabled; font.family: root.fontFamily; textColor: root.textColor }
                OperatorText { width: parent.width; height: implicitHeight; text: "修改载荷、通道、配置或链路会话后需重新确认。锁定期间主题与载荷均只读；没有保存配置或存在未保存改动时不启用、不发送。"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
        OperatorDiagnosticTable { objectName: "terminalLinkTransferStatus"; width: parent.width; title: "实际收发与映射状态"; rows: root.transferRows; fontFamily: root.fontFamily; titleSize: root.sectionTitleSize; titleColor: root.textColor; textColor: root.textColor; mutedColor: root.mutedColor; separatorColor: root.separatorColor; outlineColor: root.separatorColor; labelSize: root.noteSize; valueSize: root.inputSize; contentMargin: root.sectionContentMargin; bodyTop: root.sectionBodyTop }
        Column {
            id: packetColumn
            objectName: "terminalLinkReceivedPackets"
            width: parent.width
            spacing: root.sectionSpacing
            visible: root.packetCount > 0
            Repeater { model: root.packetCount; delegate: root.packetDelegate }
        }
    }
}
