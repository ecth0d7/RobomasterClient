import QtQuick
import QtQuick.Layouts

// Actual team-sharing drawing; drafts, permissions and native calls stay outside.
Item {
    id: root
    objectName: "terminalTeamSetupForm"
    implicitWidth: 1300
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property bool editorEditable: false
    property bool saveEnabled: false
    property bool enableEnabled: false
    property bool stopEnabled: false
    property bool undoEnabled: false
    property bool providerEditable: false
    property bool providerRefreshEnabled: false
    property bool providerSaveEnabled: false
    property bool providerUndoEnabled: false
    property bool canSendChecked: false
    property bool canAggregateChecked: false
    property bool confirmedChecked: false
    property bool clocksChecked: false
    property bool mockChecked: false
    property bool mockEditable: false
    property bool localFieldEditable: false
    property bool addObservedEnabled: false
    property bool addPeerEnabled: false
    property var providerTitles: []
    property var providerIdentityRows: []
    property var statusRows: []
    property var viewRows: []
    property var robotTitles: []
    property var localFieldTitles: []
    property int providerSelectedIndex: -1
    property int robotIndex: -1
    property int localFieldSelectedIndex: -1
    property int purposeCount: 0
    property int peerCount: 0
    property int memberCount: 0
    property int itemCount: 0
    property int formColumns: width >= 1040 ? 3 : width >= 650 ? 2 : 1
    property string providerStatusText: ""
    property string providerReviewText: ""
    property string statusText: ""
    property string lockText: ""
    property string teamText: ""
    property string matchText: ""
    property string epochText: ""
    property string nodeText: ""
    property string robotDisplay: "Designer绘制参考 · 未接通角色目录"
    property string robotHint: ""
    property string publisherText: ""
    property string endpointText: ""
    property string caText: ""
    property string certificateText: ""
    property string keyEnvText: ""
    property string heartbeatText: ""
    property string timeoutText: ""
    property string skewText: ""
    property string localFieldDisplay: "Designer绘制参考 · 没有本机观测字段"
    property string errorText: ""
    property string fontFamily: Theme.fontFamily
    property string introText: "可选队内共享先汇总、核验再形成统一数据视图。本机数据、官方选手端链路和其他插件独立运行；停用此插件不会停止它们。此处不配置官方赛事服务器，也不将共享数据变成官方遥测。"
    property string providerEmptyText: "当前提供者未发现；保留完整选择，不自动替换"
    property string providerBoundaryText: "插件只提供队伍通道实现。身份、字段用途、证书引用和连接参数仍使用下方唯一的宿主配置；插件专有实现参数在插件管理中保存。主机独立核验来源和发布者，插件自报verified、TLS或签名不替代宿主证明。"
    property real sectionSpacing: 16
    property real formSpacing: 12
    property real fieldSpacing: 8
    property real actionSpacing: 12
    property real columnGap: 12
    property real actionWidth: 190
    property real controlHeight: 38
    property real noteSize: 12
    property real introSize: 13
    property real inputSize: 14
    property real sectionTitleSize: 14
    property real sectionContentMargin: 14
    property real sectionBodyTop: 47
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property Component purposeDelegate: null
    property Component localGrantDelegate: null
    property Component peerDelegate: null
    property Component memberDelegate: null
    property Component itemDelegate: null
    readonly property real localGrantDelegateWidth: grantsSectionColumn.width
    readonly property real peerDelegateWidth: peersSectionColumn.width
    readonly property real purposeDelegateWidth: usesFlow.width >= 760 ? (usesFlow.width - root.fieldSpacing * 4) / 5 : usesFlow.width >= 420 ? (usesFlow.width - root.fieldSpacing) / 2 : usesFlow.width
    readonly property real memberDelegateWidth: root.width >= 900 ? (membersFlow.width - root.actionSpacing) / 2 : membersFlow.width
    readonly property real itemDelegateWidth: contentColumn.width
    property alias providerSpacing: teamProviderForm.formSpacing
    property alias providerNoteSize: teamProviderForm.noteSize
    property alias providerControl: teamProviderForm.providerControl
    property alias providerRefreshControl: teamProviderForm.refreshControl
    property alias providerSaveControl: teamProviderForm.saveControl
    property alias providerUndoControl: teamProviderForm.undoControl
    property alias saveControl: saveButton
    property alias enableControl: enableButton
    property alias stopControl: stopButton
    property alias undoControl: undoButton
    property alias teamControl: teamField.inputControl
    property alias matchControl: matchField.inputControl
    property alias epochControl: epochField.inputControl
    property alias nodeControl: nodeField.inputControl
    property alias robotControl: robotSelect.selectControl
    property alias publisherControl: publisherField.inputControl
    property alias canSendControl: canSendCheck
    property alias canAggregateControl: canAggregateCheck
    property alias confirmedControl: confirmedCheck
    property alias endpointControl: endpointField.inputControl
    property alias caControl: caField.inputControl
    property alias certificateControl: certificateField.inputControl
    property alias keyEnvControl: keyEnvField.inputControl
    property alias heartbeatControl: heartbeatField.inputControl
    property alias timeoutControl: timeoutField.inputControl
    property alias skewControl: skewField.inputControl
    property alias clocksControl: clocksCheck
    property alias mockControl: mockCheck
    property alias localFieldControl: localFieldSelect.selectControl
    property alias addObservedControl: addObservedButton
    property alias addPeerControl: addPeerButton
    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.sectionSpacing
        OperatorText {
            width: parent.width
            height: implicitHeight
            text: root.introText
            size: root.introSize
            color: root.warningColor
            font.family: root.fontFamily
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideNone
        }
        OperatorTerminalTeamProviderForm {
            id: teamProviderForm
            objectName: "terminalTeamProviderSection"
            width: parent.width
            providerTitles: root.providerTitles
            providerIndex: root.providerSelectedIndex
            providerEditable: root.providerEditable
            refreshEnabled: root.providerRefreshEnabled
            saveEnabled: root.providerSaveEnabled
            undoEnabled: root.providerUndoEnabled
            providerEmptyText: root.providerEmptyText
            statusText: root.providerStatusText
            reviewMessage: root.providerReviewText
            identityRows: root.providerIdentityRows
            boundaryMessage: root.providerBoundaryText
            formSpacing: root.formSpacing
            actionSpacing: root.actionSpacing
            noteSize: root.noteSize
            labelSize: root.noteSize
            inputSize: root.inputSize
            controlHeight: root.controlHeight
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            fontFamily: root.fontFamily
            labelColor: root.mutedColor
            textColor: root.textColor
            separatorColor: root.separatorColor
            warningColor: root.warningColor
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
        }
        Flow { width: parent.width; spacing: root.actionSpacing
            OperatorButton { id: saveButton; objectName: "teamSave"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "保存队内共享配置"; primary: true; enabled: root.saveEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
            OperatorButton { id: enableButton; objectName: "teamEnable"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "启用已保存的共享"; enabled: root.enableEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
            OperatorButton { id: stopButton; objectName: "teamStop"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "停止队内共享"; enabled: root.stopEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
            OperatorButton { id: undoButton; objectName: "teamUndo"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "撤销未保存修改"; enabled: root.undoEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
        }
        OperatorText {
            width: parent.width
            height: implicitHeight
            visible: root.lockText.length > 0
            text: root.lockText
            size: root.noteSize
            color: root.warningColor
            font.family: root.fontFamily
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideNone
        }
        OperatorText {
            width: parent.width
            height: implicitHeight
            text: root.statusText
            size: root.noteSize
            color: root.mutedColor
            font.family: root.fontFamily
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideNone
        }
        OperatorDiagnosticTable {
            objectName: "terminalTeamStatusTable"
            width: parent.width
            title: "真实连接与核验状态"
            rows: root.statusRows
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            fontFamily: root.fontFamily
            textColor: root.textColor
            mutedColor: root.mutedColor
            separatorColor: root.separatorColor
            outlineColor: root.separatorColor
            labelSize: root.noteSize
            valueSize: root.inputSize
        }
        OperatorSection {
            id: identitySection
            objectName: "terminalTeamIdentitySection"
            width: parent.width
            height: identitySectionColumn.implicitHeight + bodyTop + contentMargin
            title: "队伍与语义身份 · 本地配置"
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: identitySectionColumn
                parent: identitySection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                GridLayout {
                    width: parent.width
                    columns: root.formColumns
                    columnSpacing: root.columnGap
                    rowSpacing: root.fieldSpacing
                    OperatorStartupFieldForm {
                        id: teamField
                        objectName: "teamTeamField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "队伍标识"
                        value: root.teamText
                        hint: "各节点明确约定的同队标识。"
                        maximumLength: 64
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        inputBorderColor: root.separatorColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: matchField
                        objectName: "teamMatchField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "比赛／训练场次标识"
                        value: root.matchText
                        hint: "隔离不同场次的数据。"
                        maximumLength: 64
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        inputBorderColor: root.separatorColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: epochField
                        objectName: "teamEpochField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "本次共享轮次"
                        value: root.epochText
                        hint: "所有节点共同约定；停用、重启或启动失败后须换新值。"
                        maximumLength: 64
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        inputBorderColor: root.separatorColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: nodeField
                        objectName: "teamNodeField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "本机节点标识"
                        value: root.nodeText
                        hint: "独立实例使用独立节点标识。"
                        maximumLength: 64
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        inputBorderColor: root.separatorColor
                        warningColor: root.warningColor
                    }
                    OperatorSetupSelectForm {
                        id: robotSelect
                        objectName: "teamRobotSelect"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "本机语义机器人 · 非官方线路ID"
                        choices: root.robotTitles
                        selectedIndex: root.robotIndex
                        selectionText: root.robotDisplay
                        hint: root.robotHint
                        editable: root.editorEditable
                        fieldSpacing: root.fieldSpacing
                        controlHeight: root.controlHeight
                        noteSize: root.noteSize
                        labelSize: root.noteSize
                        hintSize: root.noteSize
                        inputSize: root.inputSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        warningColor: root.warningColor
                        inputBorderColor: root.separatorColor
                    }
                    OperatorStartupFieldForm {
                        id: publisherField
                        objectName: "teamPublisherField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "指定汇总发布节点"
                        value: root.publisherText
                        hint: "填写允许汇总的本机或固定队友节点ID。"
                        maximumLength: 64
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        inputBorderColor: root.separatorColor
                        warningColor: root.warningColor
                    }
                }
                Flow { width: parent.width; spacing: root.actionSpacing
                    OperatorCheckBox { id: canSendCheck; objectName: "teamCanSend"; width: Math.min(300, parent.width); height: root.controlHeight; text: "允许本机发送授权字段"; checked: root.canSendChecked; enabled: root.editorEditable; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                    OperatorCheckBox { id: canAggregateCheck; objectName: "teamCanAggregate"; width: Math.min(330, parent.width); height: root.controlHeight; text: "允许本机承担汇总发布"; checked: root.canAggregateChecked; enabled: root.editorEditable; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                    OperatorCheckBox { id: confirmedCheck; objectName: "teamConfirmed"; width: Math.min(380, parent.width); height: root.controlHeight; text: "队内已确认身份与必要共享范围"; checked: root.confirmedChecked; enabled: root.editorEditable; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                }
            }
        }
        OperatorSection {
            id: transportSection
            objectName: "terminalTeamTransportSection"
            width: parent.width
            height: transportSectionColumn.implicitHeight + bodyTop + contentMargin
            title: "加密通道与证书 · 显式启用"
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: transportSectionColumn
                parent: transportSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                GridLayout {
                    width: parent.width
                    columns: width >= 760 ? 2 : 1
                    columnSpacing: root.columnGap
                    rowSpacing: root.fieldSpacing
                    OperatorStartupFieldForm {
                        id: endpointField
                        objectName: "teamEndpointField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "队内MQTTS地址与明确端口"
                        value: root.endpointText
                        hint: "由实际部署提供 mqtts://主机:端口；不预设服务器。"
                        maximumLength: 256
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        inputBorderColor: root.separatorColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: caField
                        objectName: "teamCaField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "CA证书文件"
                        value: root.caText
                        hint: "相对引用以共享配置文件目录为基准。"
                        maximumLength: 4096
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        inputBorderColor: root.separatorColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: certificateField
                        objectName: "teamCertificateField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "本机签名证书文件"
                        value: root.certificateText
                        hint: "身份须与队友固定的公钥指纹一致。"
                        maximumLength: 4096
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        inputBorderColor: root.separatorColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: keyEnvField
                        objectName: "teamKeyEnvField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "签名密钥文件路径的环境变量名"
                        value: root.keyEnvText
                        hint: "仅保存环境变量名；密钥及其解析后路径不进入界面。"
                        maximumLength: 96
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        inputBorderColor: root.separatorColor
                        warningColor: root.warningColor
                    }
                }
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    text: "此配置不会自动连接。启用时才由宿主读取密钥文件引用并核验证书；相对文件引用可随独立实例配置迁移，证书与环境变量仍须由部署者准备。"
                    size: root.noteSize
                    color: root.mutedColor
                    font.family: root.fontFamily
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideNone
                }
            }
        }
        OperatorSection {
            id: timingSection
            objectName: "terminalTeamTimingSection"
            width: parent.width
            height: timingSectionColumn.implicitHeight + bodyTop + contentMargin
            title: "心跳、过期与训练边界"
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: timingSectionColumn
                parent: timingSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                GridLayout {
                    width: parent.width
                    columns: root.formColumns
                    columnSpacing: root.columnGap
                    rowSpacing: root.fieldSpacing
                    OperatorStartupFieldForm {
                        id: heartbeatField
                        objectName: "teamHeartbeatField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "心跳周期 / ms"
                        value: root.heartbeatText
                        hint: "250–10000ms。"
                        maximumLength: 5
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        inputBorderColor: root.separatorColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: timeoutField
                        objectName: "teamTimeoutField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "节点超时 / ms"
                        value: root.timeoutText
                        hint: "750–60000ms，至少三个心跳周期。"
                        maximumLength: 5
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        inputBorderColor: root.separatorColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: skewField
                        objectName: "teamSkewField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "声明的时钟偏差上限 / ms"
                        value: root.skewText
                        hint: "0–1000ms；不等于已完成时钟同步核验。"
                        maximumLength: 4
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        inputBorderColor: root.separatorColor
                        warningColor: root.warningColor
                    }
                }
                Flow { width: parent.width; spacing: root.actionSpacing
                    OperatorCheckBox { id: clocksCheck; objectName: "teamClocks"; width: Math.min(350, parent.width); height: root.controlHeight; text: "声明节点时钟已同步"; checked: root.clocksChecked; enabled: root.editorEditable; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                    OperatorCheckBox { id: mockCheck; objectName: "teamTrainingMock"; width: Math.min(350, parent.width); height: root.controlHeight; text: "允许明确标记的训练mock"; checked: root.mockChecked; enabled: root.mockEditable; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                }
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    text: "勾选mock仅授权共享已存在且匹配身份和字段允许列表的模拟观测，不生成数据。可在‘本地数据总线’显式生成mock；身份不匹配时不会被此节点导出。心跳与重复汇总不会刷新旧测量的生命周期。"
                    size: root.noteSize
                    color: root.mutedColor
                    font.family: root.fontFamily
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideNone
                }
            }
        }
        OperatorSection {
            id: grantsSection
            objectName: "terminalTeamGrantsSection"
            width: parent.width
            height: grantsSectionColumn.implicitHeight + bodyTop + contentMargin
            title: "本机字段与接收用途 · 最小必要共享"
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: grantsSectionColumn
                parent: grantsSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    text: "全局允许用途与具体字段用途共同生效。模型和语音授权只是配置，不表示对应生产消费者已经接通；比赛用途不允许外部模型。"
                    size: root.noteSize
                    color: root.mutedColor
                    font.family: root.fontFamily
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideNone
                }
                Flow { id: usesFlow; width: parent.width; spacing: root.fieldSpacing; Repeater { model: root.purposeCount; delegate: root.purposeDelegate } }
                GridLayout {
                    width: parent.width
                    columns: width >= 760 ? 2 : 1
                    columnSpacing: root.columnGap
                    rowSpacing: root.fieldSpacing
                    OperatorSetupSelectForm {
                        id: localFieldSelect
                        objectName: "teamLocalFieldSelect"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignTop
                        label: "本机已出现的观测字段"
                        choices: root.localFieldTitles
                        selectedIndex: root.localFieldSelectedIndex
                        selectionText: root.localFieldDisplay
                        hint: ""
                        editable: root.localFieldEditable
                        fieldSpacing: root.fieldSpacing
                        controlHeight: root.controlHeight
                        noteSize: root.noteSize
                        labelSize: root.noteSize
                        hintSize: root.noteSize
                        inputSize: root.inputSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        warningColor: root.warningColor
                        inputBorderColor: root.separatorColor
                    }
                    OperatorButton { id: addObservedButton; objectName: "teamAddObserved"; Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.preferredHeight: root.controlHeight; text: "将选中字段加入允许列表"; enabled: root.addObservedEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
                }
                Repeater { model: 1; delegate: root.localGrantDelegate }
            }
        }
        OperatorSection {
            id: peersSection
            objectName: "terminalTeamPeersSection"
            width: parent.width
            height: peersSectionColumn.implicitHeight + bodyTop + contentMargin
            title: "固定队友身份与公钥 · 不接受未列出的发送者"
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: peersSectionColumn
                parent: peersSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorText {
                    width: parent.width
                    height: implicitHeight
                    text: "每个队友使用同阵营且独立的语义机器人、节点ID与签名公钥。公钥固定和签名核验用于确认发送者；本地传感器、视觉与推导值仍保留原来源，不能冒充官方权威。"
                    size: root.noteSize
                    color: root.mutedColor
                    font.family: root.fontFamily
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideNone
                }
                Repeater { model: root.peerCount; delegate: root.peerDelegate }
                OperatorButton { id: addPeerButton; objectName: "teamAddPeer"; width: Math.min(210, parent.width); height: root.controlHeight; text: "添加固定身份队友"; enabled: root.addPeerEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
            }
        }
        OperatorText {
            width: parent.width
            height: implicitHeight
            visible: root.errorText.length > 0
            text: root.errorText
            size: root.noteSize
            color: root.warningColor
            font.family: root.fontFamily
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideNone
        }
        OperatorDiagnosticTable {
            objectName: "terminalTeamViewSection"
            width: parent.width
            title: "当前已提交的队伍汇总视图"
            rows: root.viewRows
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            fontFamily: root.fontFamily
            textColor: root.textColor
            mutedColor: root.mutedColor
            separatorColor: root.separatorColor
            outlineColor: root.separatorColor
            labelSize: root.noteSize
            valueSize: root.inputSize
        }
        Flow { id: membersFlow; objectName: "terminalTeamMembersSection"; width: parent.width; spacing: root.actionSpacing; Repeater { model: root.memberCount; delegate: root.memberDelegate } }
        OperatorText {
            width: parent.width
            height: implicitHeight
            visible: root.itemCount === 0
            text: "当前没有已提交的数据项。网络连接、节点心跳或收到零散消息都不会补造汇总内容；仅显示通过来源证明与完整汇总提交的数据。"
            size: root.noteSize
            color: root.mutedColor
            font.family: root.fontFamily
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideNone
        }
        Repeater { model: root.itemCount; delegate: root.itemDelegate }
    }
}
