import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Designer drawing only. All mappings, admission and actions stay in the wrapper.
Item {
    id: root
    objectName: "terminalAdviceSetupForm"
    implicitWidth: 1300
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property bool editorEditable: false
    property bool saveEnabled: false
    property bool enableEnabled: false
    property bool stopEnabled: false
    property bool undoEnabled: false
    property bool refreshEnabled: false
    property bool teamWarningVisible: false
    property bool httpFieldsVisible: false
    property bool codexFieldsVisible: false
    property bool packageInfoVisible: false
    property bool thinkingChecked: false
    property bool thinkingEditable: false
    property bool candidateEnabled: false
    property bool addCandidateEnabled: false
    property bool addFieldEnabled: false
    property bool hudChecked: false
    property bool autoChecked: false
    property bool voiceChecked: false
    property bool questionEditable: false
    property bool requestEnabled: false
    property bool cancelEnabled: false
    property bool freshAdvice: false
    property var providerStatusRows: []
    property var robotTitles: []
    property var strategyTitles: []
    property var providerTitles: []
    property var packageIdentityRows: []
    property var candidateTitles: []
    property var traceRows: []
    property int robotIndex: -1
    property int inputModeIndex: -1
    property int strategyIndex: -1
    property int providerSelectedIndex: -1
    property int apiIndex: -1
    property int formatIndex: -1
    property int schemaIndex: -1
    property int reasoningIndex: -1
    property int candidateSelectedIndex: -1
    property int hudPositionIndex: -1
    property int hudDensityIndex: -1
    property int triggerIndex: -1
    property int selectedFieldCount: 0
    property int inputRecordCount: 0
    property int formColumns: width >= 1040 ? 3 : width >= 650 ? 2 : 1
    property string lockText: ""
    property string statusText: ""
    property string teamText: ""
    property string robotDisplay: ""
    property string robotHint: ""
    property string inputModeDisplay: ""
    property string inputModeHint: ""
    property string strategyDisplay: ""
    property string strategyDescription: ""
    property string strategyText: ""
    property string providerDisplay: ""
    property string providerWarningText: ""
    property string modelText: ""
    property string timeoutText: ""
    property string outputTokensText: ""
    property string outputTokensHint: ""
    property string endpointText: ""
    property string keyEnvText: ""
    property string providerNameText: ""
    property string codexExecutableText: ""
    property string codexAuthText: ""
    property string apiDisplay: ""
    property string formatDisplay: ""
    property string schemaDisplay: ""
    property string reasoningDisplay: ""
    property string candidateDisplay: ""
    property string hudPositionDisplay: ""
    property string hudDensityDisplay: ""
    property string triggerDisplay: ""
    property string minimumIntervalText: ""
    property string errorText: ""
    property string questionText: ""
    property string requestStatus: ""
    property string emptyAdviceText: ""
    property string adviceHeading: ""
    property string adviceSummary: ""
    property string adviceRationale: ""
    property string adviceFreshness: ""
    property string adviceSource: ""
    property string fontFamily: Theme.fontFamily
    property string introText: "模型、策略、输入授权与自动建议可随时修改，保存后应用。建议只分析宿主重新取得的新鲜、非mock输入；不自动触发机器人动作。HUD仅在建议通过来源与时效接纳后显示，不为加载、空结果或过期建议占位。"
    property string requestText: "按已保存配置请求建议"
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
    property real strategyHeight: 104
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property color adviceSummaryColor: Theme.text
    property Component selectedFieldDelegate: null
    property Component inputRecordDelegate: null
    readonly property real selectedFieldDelegateWidth: inputsSectionColumn.width
    readonly property real inputRecordDelegateWidth: contentColumn.width
    property alias saveControl: saveButton
    property alias enableControl: enableButton
    property alias stopControl: stopButton
    property alias undoControl: undoButton
    property alias teamControl: teamField.inputControl
    property alias robotControl: robotSelect.selectControl
    property alias inputModeControl: inputSelect.selectControl
    property alias strategyControl: strategySelect.selectControl
    property alias strategyTextControl: strategyArea
    property alias providerControl: providerSelect.selectControl
    property alias refreshProvidersControl: refreshButton
    property alias modelControl: modelField.inputControl
    property alias timeoutControl: timeoutField.inputControl
    property alias outputTokensControl: outputTokensField.inputControl
    property alias endpointControl: endpointField.inputControl
    property alias keyEnvControl: keyEnvField.inputControl
    property alias providerNameControl: providerNameField.inputControl
    property alias codexExecutableControl: codexExecutableField.inputControl
    property alias codexAuthControl: codexAuthField.inputControl
    property alias httpApiControl: apiSelect.selectControl
    property alias httpFormatControl: formatSelect.selectControl
    property alias httpSchemaControl: schemaSelect.selectControl
    property alias thinkingControl: thinkingCheck
    property alias reasoningControl: reasoningSelect.selectControl
    property alias candidateControl: candidateSelect.selectControl
    property alias addCandidateControl: addCandidateButton
    property alias addFieldControl: addFieldButton
    property alias hudControl: hudCheck
    property alias hudPositionControl: hudPositionSelect.selectControl
    property alias hudDensityControl: hudDensitySelect.selectControl
    property alias autoControl: autoCheck
    property alias voiceControl: voiceCheck
    property alias triggerControl: triggerSelect.selectControl
    property alias minimumIntervalControl: minimumIntervalField.inputControl
    property alias questionControl: questionInput
    property alias requestControl: requestButton
    property alias cancelControl: cancelButton

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.sectionSpacing
        OperatorAdviceSetupNoteForm {
            width: parent.width
            text: root.introText
            size: root.introSize
            color: root.warningColor
            fontFamily: root.fontFamily
        }
        Flow { width: parent.width; spacing: root.actionSpacing
            OperatorButton { id: saveButton; objectName: "adviceSaveButton"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "保存模型与策略"; enabled: root.saveEnabled; primary: true; font.family: root.fontFamily }
            OperatorButton { id: enableButton; objectName: "adviceEnableButton"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "启用已保存提供者"; enabled: root.enableEnabled; primary: false; font.family: root.fontFamily }
            OperatorButton { id: stopButton; objectName: "adviceStopButton"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "停止建议服务"; enabled: root.stopEnabled; primary: false; font.family: root.fontFamily }
            OperatorButton { id: undoButton; objectName: "adviceUndoButton"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "撤销未保存修改"; enabled: root.undoEnabled; primary: false; font.family: root.fontFamily }
        }
        OperatorAdviceSetupNoteForm {
            width: parent.width
            visible: root.lockText.length > 0
            text: root.lockText
            size: root.noteSize
            color: root.warningColor
            fontFamily: root.fontFamily
        }
        OperatorAdviceSetupNoteForm {
            width: parent.width
            text: root.statusText
            size: root.noteSize
            color: root.mutedColor
            fontFamily: root.fontFamily
        }
        OperatorDiagnosticTable { objectName: "terminalAdviceStatusTable"; width: parent.width; title: "提供者与输入接纳 · 实际宿主状态"; rows: root.providerStatusRows; fontFamily: root.fontFamily; textColor: root.textColor; mutedColor: root.mutedColor; separatorColor: root.separatorColor; labelSize: root.noteSize; valueSize: root.inputSize }
        OperatorSection {
            id: identitySection
            objectName: "terminalAdviceIdentitySection"
            width: parent.width
            height: identitySectionColumn.implicitHeight + bodyTop + contentMargin
            title: "建议身份、策略与输入范围"
            titleSize: root.sectionTitleSize
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
                        objectName: "adviceTeamField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "队伍标识"
                        value: root.teamText
                        hint: "与被授权本机或队伍视图的队伍一致。"
                        maximumLength: 64
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                    }
                    OperatorAdviceSetupSelectForm {
                        id: robotSelect
                        objectName: "adviceRobotSelect"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "本机语义机器人 · 非线路ID"
                        choices: root.robotTitles
                        selectedIndex: root.robotIndex
                        selectionText: root.robotDisplay
                        hint: root.robotHint
                        editable: root.editorEditable
                        fieldSpacing: root.fieldSpacing
                        controlHeight: root.controlHeight
                        noteSize: root.noteSize
                        inputSize: root.inputSize
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        fontFamily: root.fontFamily
                    }
                    OperatorAdviceSetupSelectForm {
                        id: inputSelect
                        objectName: "adviceInputSelect"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "建议输入数据路径"
                        choices: ["本机机器人独立数据", "队伍核验后的完整汇总"]
                        selectedIndex: root.inputModeIndex
                        selectionText: root.inputModeDisplay
                        hint: root.inputModeHint
                        editable: root.editorEditable
                        fieldSpacing: root.fieldSpacing
                        controlHeight: root.controlHeight
                        noteSize: root.noteSize
                        inputSize: root.inputSize
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        fontFamily: root.fontFamily
                    }
                }
                OperatorAdviceSetupSelectForm {
                    id: strategySelect
                    objectName: "adviceStrategySelect"
                    width: parent.width
                    label: "可保存策略"
                    choices: root.strategyTitles
                    selectedIndex: root.strategyIndex
                    selectionText: root.strategyDisplay
                    hint: root.strategyDescription
                    editable: root.editorEditable
                    fieldSpacing: root.fieldSpacing
                    controlHeight: root.controlHeight
                    noteSize: root.noteSize
                    inputSize: root.inputSize
                    textColor: root.textColor
                    mutedColor: root.mutedColor
                    fontFamily: root.fontFamily
                }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    text: "队伍／角色附加策略 · 持久保存的明确配置"
                    size: root.noteSize
                    color: root.mutedColor
                    fontFamily: root.fontFamily
                }
                ScrollView {
                    id: strategyScroll
                    width: parent.width
                    height: root.strategyHeight
                    clip: true
                    contentWidth: availableWidth
                    OperatorTextArea { id: strategyArea; objectName: "adviceStrategyText"; width: strategyScroll.availableWidth; height: Math.max(root.strategyHeight, implicitHeight); label: "附加策略"; text: root.strategyText; readOnly: !root.editorEditable; font.family: root.fontFamily }
                }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    visible: root.teamWarningVisible
                    text: "队伍模式还要求宿主核验原来源证明、完整视图与时钟同步。队伍签名不证明传感器测量或时钟；当前时钟核验未完成时，宿主会阻止模型输入，本机和其他功能继续运行。"
                    size: root.noteSize
                    color: root.warningColor
                    fontFamily: root.fontFamily
                }
            }
        }
        OperatorSection {
            id: providerSection
            objectName: "terminalAdviceProviderSection"
            width: parent.width
            height: providerSectionColumn.implicitHeight + bodyTop + contentMargin
            title: "模型提供者 · 配置与运行状态分开"
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: providerSectionColumn
                parent: providerSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorAdviceSetupSelectForm {
                    id: providerSelect
                    objectName: "adviceProviderSelect"
                    width: parent.width
                    label: "模型提供者"
                    choices: root.providerTitles
                    selectedIndex: root.providerSelectedIndex
                    selectionText: root.providerDisplay
                    hint: ""
                    editable: root.editorEditable
                    fieldSpacing: root.fieldSpacing
                    controlHeight: root.controlHeight
                    noteSize: root.noteSize
                    inputSize: root.inputSize
                    textColor: root.textColor
                    mutedColor: root.mutedColor
                    fontFamily: root.fontFamily
                }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    text: "提供者模板来自宿主，只填写配置结构；不代表账号已授权、模型可用或服务已连接。"
                    size: root.noteSize
                    color: root.mutedColor
                    fontFamily: root.fontFamily
                }
                OperatorButton { id: refreshButton; objectName: "adviceRefreshProviders"; width: Math.min(200, parent.width); height: root.controlHeight; text: "刷新提供者目录"; enabled: root.refreshEnabled; primary: false; font.family: root.fontFamily }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    visible: root.providerWarningText.length > 0
                    text: root.providerWarningText
                    size: root.noteSize
                    color: root.warningColor
                    fontFamily: root.fontFamily
                }
                OperatorDiagnosticTable { visible: root.packageInfoVisible; width: parent.width; title: "插件提供者 · 当前编辑选择"; rows: root.packageIdentityRows; fontFamily: root.fontFamily; textColor: root.textColor; mutedColor: root.mutedColor; separatorColor: root.separatorColor; labelSize: root.noteSize; valueSize: root.inputSize }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    visible: root.packageInfoVisible
                    text: "插件自身的地址、凭据引用与其他专有参数在“插件包管理”中配置。这里仅保存明确的插件能力、模型与请求预算，不执行任意插件路径或命令。"
                    size: root.noteSize
                    color: root.mutedColor
                    fontFamily: root.fontFamily
                }
                GridLayout {
                    width: parent.width
                    columns: width >= 760 ? 2 : 1
                    columnSpacing: root.columnGap
                    rowSpacing: root.fieldSpacing
                    OperatorStartupFieldForm {
                        id: modelField
                        objectName: "adviceModelField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "明确的模型ID"
                        value: root.modelText
                        hint: "由实际提供者／账号提供；未查询模型目录。"
                        maximumLength: 128
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: timeoutField
                        objectName: "adviceTimeoutField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "请求超时 / ms"
                        value: root.timeoutText
                        hint: "50–120000ms；超时结果不保留为有效建议。"
                        maximumLength: 6
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: outputTokensField
                        objectName: "adviceOutputTokensField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "输出长度上限 / tokens"
                        value: root.outputTokensText
                        hint: root.outputTokensHint
                        maximumLength: 4
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: endpointField
                        objectName: "adviceEndpointField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        visible: root.httpFieldsVisible
                        label: "HTTP完整端点"
                        value: root.endpointText
                        hint: "使用实际部署地址；保存不表示已连通。"
                        maximumLength: 2048
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: keyEnvField
                        objectName: "adviceKeyEnvField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        visible: root.httpFieldsVisible
                        label: "API密钥环境变量名"
                        value: root.keyEnvText
                        hint: "只保存名称，宿主启用时读取；界面不接收密钥。"
                        maximumLength: 96
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: providerNameField
                        objectName: "adviceProviderNameField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        visible: root.httpFieldsVisible
                        label: "提供者标识"
                        value: root.providerNameText
                        hint: "DeepSeek专用参数仅用于明确匹配的提供者。"
                        maximumLength: 64
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: codexExecutableField
                        objectName: "adviceCodexExecutableField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        visible: root.codexFieldsVisible
                        label: "Codex可执行程序引用"
                        value: root.codexExecutableText
                        hint: "填写程序名或路径，不填写shell命令或参数串。"
                        maximumLength: 1024
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                    }
                    OperatorStartupFieldForm {
                        id: codexAuthField
                        objectName: "adviceCodexAuthField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        visible: root.codexFieldsVisible
                        label: "Codex授权目录引用"
                        value: root.codexAuthText
                        hint: "授权文件由部署者准备；界面不展示凭据内容。"
                        maximumLength: 1024
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                    }
                }
                GridLayout {
                    width: parent.width
                    columns: root.formColumns
                    columnSpacing: root.columnGap
                    rowSpacing: root.fieldSpacing
                    visible: root.httpFieldsVisible
                    OperatorAdviceSetupSelectForm {
                        id: apiSelect
                        objectName: "adviceApiSelect"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "HTTP接口协议"
                        choices: ["chat", "responses"]
                        selectedIndex: root.apiIndex
                        selectionText: root.apiDisplay
                        hint: ""
                        editable: root.editorEditable
                        fieldSpacing: root.fieldSpacing
                        controlHeight: root.controlHeight
                        noteSize: root.noteSize
                        inputSize: root.inputSize
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        fontFamily: root.fontFamily
                    }
                    OperatorAdviceSetupSelectForm {
                        id: formatSelect
                        objectName: "adviceFormatSelect"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "结构化输出格式"
                        choices: ["json-object", "json-schema"]
                        selectedIndex: root.formatIndex
                        selectionText: root.formatDisplay
                        hint: ""
                        editable: root.editorEditable
                        fieldSpacing: root.fieldSpacing
                        controlHeight: root.controlHeight
                        noteSize: root.noteSize
                        inputSize: root.inputSize
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        fontFamily: root.fontFamily
                    }
                    OperatorAdviceSetupSelectForm {
                        id: schemaSelect
                        objectName: "adviceSchemaSelect"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "建议结构配置"
                        choices: ["concise", "basic"]
                        selectedIndex: root.schemaIndex
                        selectionText: root.schemaDisplay
                        hint: ""
                        editable: root.editorEditable
                        fieldSpacing: root.fieldSpacing
                        controlHeight: root.controlHeight
                        noteSize: root.noteSize
                        inputSize: root.inputSize
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        fontFamily: root.fontFamily
                    }
                }
                OperatorCheckBox { id: thinkingCheck; objectName: "adviceThinking"; width: Math.min(400, parent.width); height: root.controlHeight; visible: root.httpFieldsVisible; text: "启用提供者思考选项"; checked: root.thinkingChecked; enabled: root.thinkingEditable; font.family: root.fontFamily }
                OperatorAdviceSetupSelectForm {
                    id: reasoningSelect
                    objectName: "adviceReasoningSelect"
                    width: parent.width
                    visible: root.codexFieldsVisible
                    label: "Codex推理强度"
                    choices: ["low", "medium", "high"]
                    selectedIndex: root.reasoningIndex
                    selectionText: root.reasoningDisplay
                    hint: ""
                    editable: root.editorEditable
                    fieldSpacing: root.fieldSpacing
                    controlHeight: root.controlHeight
                    noteSize: root.noteSize
                    inputSize: root.inputSize
                    textColor: root.textColor
                    mutedColor: root.mutedColor
                    fontFamily: root.fontFamily
                }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    text: "HTTP在本机地址、进程在本机启动或插件自报本地，都不证明完全本地推理。当前宿主未认证此能力，仍须逐字段授权外部模型用途。配置不会授权文件编辑、项目访问或机器人动作。"
                    size: root.noteSize
                    color: root.warningColor
                    fontFamily: root.fontFamily
                }
            }
        }
        OperatorSection {
            id: inputsSection
            objectName: "terminalAdviceInputsSection"
            width: parent.width
            height: inputsSectionColumn.implicitHeight + bodyTop + contentMargin
            title: "模型输入允许列表 · 每个字段明确授权"
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: inputsSectionColumn
                parent: inputsSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    text: "仅选择必要字段；授权不刷新时效。mock、过期、撤回、来源不符、用途不符或时钟未核验的数据由宿主排除或阻止请求，不补造比赛数据。"
                    size: root.noteSize
                    color: root.mutedColor
                    fontFamily: root.fontFamily
                }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    visible: root.selectedFieldCount === 0
                    text: "尚未授权模型输入。可以先保存配置；在必要字段明确授权并满足新鲜度要求前，宿主不会发起模型请求。"
                    size: root.noteSize
                    color: root.mutedColor
                    fontFamily: root.fontFamily
                }
                GridLayout {
                    width: parent.width
                    columns: width >= 760 ? 2 : 1
                    columnSpacing: root.columnGap
                    rowSpacing: root.fieldSpacing
                    OperatorAdviceSetupSelectForm {
                        id: candidateSelect
                        objectName: "adviceCandidateSelect"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "已出现的来源字段"
                        choices: root.candidateTitles
                        selectedIndex: root.candidateSelectedIndex
                        selectionText: root.candidateDisplay
                        hint: ""
                        editable: root.candidateEnabled
                        fieldSpacing: root.fieldSpacing
                        controlHeight: root.controlHeight
                        noteSize: root.noteSize
                        inputSize: root.inputSize
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        fontFamily: root.fontFamily
                    }
                    OperatorButton { id: addCandidateButton; objectName: "adviceAddCandidate"; Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.preferredHeight: root.controlHeight; text: "加入选中来源字段"; enabled: root.addCandidateEnabled; font.family: root.fontFamily }
                }
                Repeater { model: root.selectedFieldCount; delegate: root.selectedFieldDelegate }
                OperatorButton { id: addFieldButton; objectName: "adviceAddFieldButton"; width: Math.min(210, parent.width); height: root.controlHeight; text: "添加明确输入字段"; enabled: root.addFieldEnabled; primary: false; font.family: root.fontFamily }
            }
        }
        OperatorSection {
            id: hudSection
            objectName: "terminalAdviceHudSection"
            width: parent.width
            height: hudSectionColumn.implicitHeight + bodyTop + contentMargin
            title: "比赛HUD建议提示 · 保存后应用"
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: hudSectionColumn
                parent: hudSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorCheckBox { id: hudCheck; objectName: "adviceHudEnabled"; width: Math.min(340, parent.width); height: root.controlHeight; text: "显示有效建议提示"; checked: root.hudChecked; enabled: root.editorEditable; font.family: root.fontFamily }
                GridLayout {
                    width: parent.width
                    columns: width >= 650 ? 2 : 1
                    columnSpacing: root.columnGap
                    rowSpacing: root.fieldSpacing
                    OperatorAdviceSetupSelectForm {
                        id: hudPositionSelect
                        objectName: "adviceHudPositionSelect"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "提示区域位置"
                        choices: ["现有赛场信息区上方", "右侧固定区域"]
                        selectedIndex: root.hudPositionIndex
                        selectionText: root.hudPositionDisplay
                        hint: ""
                        editable: root.editorEditable
                        fieldSpacing: root.fieldSpacing
                        controlHeight: root.controlHeight
                        noteSize: root.noteSize
                        inputSize: root.inputSize
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        fontFamily: root.fontFamily
                    }
                    OperatorAdviceSetupSelectForm {
                        id: hudDensitySelect
                        objectName: "adviceHudDensitySelect"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "信息密度"
                        choices: ["紧凑", "标准"]
                        selectedIndex: root.hudDensityIndex
                        selectionText: root.hudDensityDisplay
                        hint: ""
                        editable: root.editorEditable
                        fieldSpacing: root.fieldSpacing
                        controlHeight: root.controlHeight
                        noteSize: root.noteSize
                        inputSize: root.inputSize
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        fontFamily: root.fontFamily
                    }
                }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    text: "提示只在宿主启用且收到新鲜、有效、可追溯的建议时显示。无结果、加载、超时或过期时不显示空白卡片；区域出现或隐藏不推挤准星、读数、小地图或赛场信息。这些偏好可在比赛中修改，保存后应用。"
                    size: root.noteSize
                    color: root.mutedColor
                    fontFamily: root.fontFamily
                }
            }
        }
        OperatorSection {
            id: automaticSection
            objectName: "terminalAdviceAutomaticSection"
            width: parent.width
            height: automaticSectionColumn.implicitHeight + bodyTop + contentMargin
            title: "自动建议与语音意向 · 保存后应用"
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: automaticSectionColumn
                parent: automaticSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                Flow { width: parent.width; spacing: root.actionSpacing
                    OperatorCheckBox { id: autoCheck; objectName: "adviceAutomatic"; width: Math.min(300, parent.width); height: root.controlHeight; text: "自动生成有效建议"; checked: root.autoChecked; enabled: root.editorEditable; font.family: root.fontFamily }
                    OperatorCheckBox { id: voiceCheck; objectName: "adviceVoice"; width: Math.min(350, parent.width); height: root.controlHeight; text: "向语音服务提交有效建议"; checked: root.voiceChecked; enabled: root.editorEditable; font.family: root.fontFamily }
                }
                GridLayout {
                    width: parent.width
                    columns: width >= 760 ? 2 : 1
                    columnSpacing: root.columnGap
                    rowSpacing: root.fieldSpacing
                    OperatorAdviceSetupSelectForm {
                        id: triggerSelect
                        objectName: "adviceTriggerSelect"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "自动请求触发方式"
                        choices: ["新鲜输入发生变化", "按间隔取得新鲜快照"]
                        selectedIndex: root.triggerIndex
                        selectionText: root.triggerDisplay
                        hint: ""
                        editable: root.editorEditable
                        fieldSpacing: root.fieldSpacing
                        controlHeight: root.controlHeight
                        noteSize: root.noteSize
                        inputSize: root.inputSize
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        fontFamily: root.fontFamily
                    }
                    OperatorStartupFieldForm {
                        id: minimumIntervalField
                        objectName: "adviceMinimumIntervalField"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        label: "最小请求间隔 / ms"
                        value: root.minimumIntervalText
                        hint: "500–30000ms；限制请求，不续命旧快照。"
                        maximumLength: 5
                        editable: root.editorEditable
                        controlHeight: root.controlHeight
                        labelSize: root.noteSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                    }
                }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    text: "自动开关不证明服务已启用。输入失效、模型超时、断连或停止后，旧建议退出HUD；语音还须通过实际语音消费者的新鲜度与收听者策略，不因勾选此项宣称已经播出或队内播报。"
                    size: root.noteSize
                    color: root.mutedColor
                    fontFamily: root.fontFamily
                }
            }
        }
        OperatorAdviceSetupNoteForm {
            width: parent.width
            visible: root.errorText.length > 0
            text: root.errorText
            size: root.noteSize
            color: root.warningColor
            fontFamily: root.fontFamily
        }
        OperatorSection {
            id: requestSection
            objectName: "terminalAdviceRequestSection"
            width: parent.width
            height: requestSectionColumn.implicitHeight + bodyTop + contentMargin
            title: "实际请求与状态 · 不生成离线建议样例"
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: requestSectionColumn
                parent: requestSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    text: "当前关注点 · 可留空；发送时由宿主重新取得授权快照，而不是把界面数值拼成输入。"
                    size: root.noteSize
                    color: root.mutedColor
                    fontFamily: root.fontFamily
                }
                OperatorInput { id: questionInput; objectName: "adviceQuestion"; width: parent.width; height: root.controlHeight; label: "本次建议关注点"; text: root.questionText; maximumLength: 1024; readOnly: !root.questionEditable; font.family: root.fontFamily }
                Flow { width: parent.width; spacing: root.actionSpacing
                    OperatorButton { id: requestButton; objectName: "adviceRequestButton"; width: Math.min(220, parent.width); height: root.controlHeight; text: root.requestText; enabled: root.requestEnabled; primary: true; font.family: root.fontFamily }
                    OperatorButton { id: cancelButton; objectName: "adviceCancelButton"; width: Math.min(180, parent.width); height: root.controlHeight; text: "取消当前模型请求"; enabled: root.cancelEnabled; primary: false; font.family: root.fontFamily }
                }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    text: root.requestStatus
                    size: root.noteSize
                    color: root.mutedColor
                    fontFamily: root.fontFamily
                }
            }
        }
        OperatorAdviceSetupNoteForm {
            width: parent.width
            visible: !root.freshAdvice
            text: root.emptyAdviceText
            size: root.noteSize
            color: root.mutedColor
            fontFamily: root.fontFamily
        }
        OperatorSection {
            id: resultSection
            visible: root.freshAdvice
            objectName: "terminalAdviceResultSection"
            width: parent.width
            height: resultSectionColumn.implicitHeight + bodyTop + contentMargin
            title: root.adviceHeading
            titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            surfaceColor: root.surfaceColor
            outlineColor: root.separatorColor
            Column {
                id: resultSectionColumn
                parent: resultSection.sectionBody
                width: parent.width
                spacing: root.formSpacing
                OperatorAdviceSetupNoteForm { width: parent.width; text: root.adviceSummary; size: 16; color: root.adviceSummaryColor; fontFamily: root.fontFamily }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    text: root.adviceRationale
                    size: root.noteSize
                    color: root.mutedColor
                    fontFamily: root.fontFamily
                }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    text: root.adviceFreshness
                    size: root.noteSize
                    color: root.mutedColor
                    fontFamily: root.fontFamily
                }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    text: root.adviceSource
                    size: root.noteSize
                    color: root.mutedColor
                    fontFamily: root.fontFamily
                }
                OperatorAdviceSetupNoteForm {
                    width: parent.width
                    text: "建议依据是已接纳输入，传感器测量仍未核验。建议不直接控制机器人；语音是否实际播放以独立语音服务状态为准。"
                    size: root.noteSize
                    color: root.warningColor
                    fontFamily: root.fontFamily
                }
            }
        }
        OperatorDiagnosticTable { objectName: "terminalAdviceTraceSection"; width: parent.width; title: "最近一次实际采集的模型输入 · 可追溯快照"; rows: root.traceRows; fontFamily: root.fontFamily; textColor: root.textColor; mutedColor: root.mutedColor; separatorColor: root.separatorColor; labelSize: root.noteSize; valueSize: root.inputSize }
        OperatorAdviceSetupNoteForm {
            width: parent.width
            visible: root.inputRecordCount > 0
            text: "以下记录冻结于该次实际采集；不会用稍后收到的新数值冒充原模型输入。‘采集时剩余寿命’是历史值，当前整体寿命以上方宿主状态为准。宿主接收时间不替代传感器产生时间。"
            size: root.noteSize
            color: root.mutedColor
            fontFamily: root.fontFamily
        }
        Repeater { model: root.inputRecordCount; delegate: root.inputRecordDelegate }
    }
}
