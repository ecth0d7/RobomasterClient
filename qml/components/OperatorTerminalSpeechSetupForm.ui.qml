import QtQuick
import QtQuick.Layouts

// Pure speech-engine drawing. Opening this Form creates no native endpoint,
// process, request or audio. Configuration behavior stays in the .qml wrapper.
Item {
    id: root
    objectName: "terminalSpeechSetupForm"
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
    property alias testOutputControl: testOutputButton
    property alias executableControl: executableField.inputControl
    property alias voiceControl: voiceField.inputControl
    property alias speedControl: speedField.inputControl
    property alias endpointControl: endpointField.inputControl
    property alias modelControl: modelField.inputControl
    property alias timeoutControl: timeoutField.inputControl
    property alias playerControl: playerField.inputControl
    property alias playbackControl: playbackCheck
    property alias diagnosticsControl: statusTable
    property alias identityControl: identityTable
    property var providerTitles: []
    property int selectedProviderIndex: -1
    property string providerDisplayText: "Designer绘制参考 · 原生提供者未接通"
    property string providerEmptyText: "当前提供者未发现，保留原选择"
    property bool providerEditable: false
    property bool configurationEditable: false
    property bool canRefresh: false
    property bool canSave: false
    property bool canEnable: false
    property bool canStop: false
    property bool canUndo: false
    property bool canTestOutput: false
    property bool showEspeak: false
    property bool showHttp: false
    property bool showPackage: false
    property bool playbackValue: false
    property string executableValue: ""
    property string voiceValue: ""
    property string speedValue: ""
    property string endpointValue: ""
    property string modelValue: ""
    property string timeoutValue: ""
    property string playerValue: ""
    property string testOutputText: "示例文本合成"
    property string introText: "先配置实际合成引擎，再在下方选择建议身份、接收者与队内播放职责。保存不启用，重启不自动启动；试音手动使用宿主固定示例，不接收任意文本。语音提交不证明已经出声。"
    property string lockMessage: "Designer绘制参考 · 原生语音宿主未接通，不能保存或启用。"
    property string reviewMessage: ""
    property string statusText: "Designer绘制参考 · 没有创建音频或播放进程。"
    property bool statusEmphasized: false
    property string providerWarningText: "原生提供者目录未接通；没有预选或启动引擎。"
    property string validationMessage: ""
    property string packageHelpText: "插件专有地址、音色、凭据引用和播放选项在“插件包管理”中配置。本页只选明确的原生语音工厂；身份由宿主重新核验，不接受任意库路径或界面自报可信度。"
    property string httpHelpText: "此HTTP适配器按现有Piper约定提交JSON text／可选voice并接收WAV。只允许明确的本机回环HTTP，不接受账号密钥、查询参数或重定向；不是任意云端TTS接口。本机地址也不能证明该服务内部从未联网。"
    property string coordinationHelpText: "引擎选择按正式规则范围与训练／比赛用途保存，不重复设置机器人身份。建议有效寿命、来源、逐字段voice授权、唯一播放节点与去重由下方协调层核验；引擎可用不代表队内语音已接通。"
    property var statusRows: [{label: "原生语音宿主", value: "Designer绘制参考 · 未接通", detail: true}]
    property var identityRows: []
    property real sectionSpacing: 16
    property real formSpacing: 12
    property real formColumnGap: 12
    property real fieldRowSpacing: 8
    property real fieldBreakpoint: 760
    property real actionWidth: 190
    property real shortActionWidth: 156
    property real testOutputWidth: 170
    property real refreshWidth: 210
    property real playbackWidth: 380
    property real controlHeight: 38
    property real fieldLabelHeight: 26
    property real fieldLabelGap: 4
    property real fieldHintGap: 8
    property real fieldHintMinimumHeight: 26
    property real fieldHintExtraHeight: 4
    property real sectionBodyTop: 47
    property real sectionContentMargin: 14
    property real introSize: 13
    property real noteSize: 12
    property real sectionTitleSize: 14
    property real labelSize: 12
    property real inputSize: 14
    property real hintSize: 11
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color secondaryTextColor: Theme.muted
    property color warningColor: Theme.warning
    property string fontFamily: Theme.fontFamily
    property string inputFontFamily: root.fontFamily
    property color inputSurfaceColor: "#232c27"
    property color inputBorderColor: Theme.line

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
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        Flow {
            width: parent.width
            spacing: root.formSpacing
            OperatorButton { id: saveButton; objectName: "terminalSpeechSave"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "保存语音引擎配置"; primary: true; enabled: root.canSave; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: enableButton; objectName: "terminalSpeechEnable"; width: Math.min(root.actionWidth, parent.width); height: root.controlHeight; text: "启用已保存引擎"; enabled: root.canEnable; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: stopButton; objectName: "terminalSpeechStop"; width: Math.min(root.shortActionWidth, parent.width); height: root.controlHeight; text: "停止本宿主引擎"; enabled: root.canStop; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: undoButton; objectName: "terminalSpeechUndo"; width: Math.min(root.shortActionWidth, parent.width); height: root.controlHeight; text: "撤销未保存修改"; enabled: root.canUndo; font.family: root.fontFamily; textColor: root.textColor }
            OperatorButton { id: testOutputButton; objectName: "terminalSpeechTestOutput"; width: Math.min(root.testOutputWidth, parent.width); height: root.controlHeight; text: root.testOutputText; Accessible.name: "手动提交宿主固定语音示例；队列接纳不表示已经播放"; enabled: root.canTestOutput; font.family: root.fontFamily; textColor: root.textColor }
        }
        OperatorText { width: parent.width; height: implicitHeight; visible: root.lockMessage.length > 0; text: root.lockMessage; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: implicitHeight; visible: root.reviewMessage.length > 0; text: root.reviewMessage; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: implicitHeight; text: root.statusText; size: root.noteSize; color: root.statusEmphasized ? root.textColor : root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        OperatorDiagnosticTable {
            id: statusTable
            objectName: "terminalSpeechDiagnosticsSection"
            width: parent.width
            title: "语音引擎 · 实际宿主状态"
            rows: root.statusRows
            surfaceColor: root.surfaceColor
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            fontFamily: root.fontFamily
            textColor: root.textColor
            mutedColor: root.secondaryTextColor
            separatorColor: root.inputBorderColor
            outlineColor: root.inputBorderColor
            labelSize: root.noteSize
            valueSize: root.inputSize
            bodyTop: root.sectionBodyTop
            contentMargin: root.sectionContentMargin
        }
        OperatorSection {
            id: providerSection
            objectName: "terminalSpeechProviderSection"
            width: parent.width
            height: providerColumn.implicitHeight + bodyTop + contentMargin
            title: "合成提供者 · 本地配置"
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            fontFamily: root.fontFamily
            outlineColor: root.inputBorderColor
            surfaceColor: root.surfaceColor
            bodyTop: root.sectionBodyTop
            contentMargin: root.sectionContentMargin
            Column {
                id: providerColumn
                width: parent.width
                spacing: root.formSpacing
                OperatorSelect {
                    id: providerSelect
                    objectName: "terminalSpeechProviderSelect"
                    width: parent.width
                    height: root.controlHeight
                    label: "实际语音合成提供者"
                    model: root.providerTitles
                    currentIndex: root.selectedProviderIndex
                    displayText: root.providerDisplayText
                    emptyText: root.providerEmptyText
                    enabled: root.providerEditable
                    textColor: root.textColor
                    borderColor: root.inputBorderColor
                    font.family: root.fontFamily
                    font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                }
                OperatorButton { id: refreshButton; objectName: "terminalSpeechRefreshProviders"; width: Math.min(root.refreshWidth, parent.width); height: root.controlHeight; text: "刷新语音提供者目录"; enabled: root.canRefresh; font.family: root.fontFamily; textColor: root.textColor }
                OperatorText { width: parent.width; height: implicitHeight; visible: root.providerWarningText.length > 0; text: root.providerWarningText; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                OperatorDiagnosticTable {
                    id: identityTable
                    visible: root.showPackage
                    width: parent.width
                    title: "插件语音能力 · 预期身份"
                    rows: root.identityRows
                    surfaceColor: root.surfaceColor
                    titleSize: root.sectionTitleSize
                    titleColor: root.textColor
                    fontFamily: root.fontFamily
                    textColor: root.textColor
                    mutedColor: root.secondaryTextColor
                    separatorColor: root.inputBorderColor
                    outlineColor: root.inputBorderColor
                    labelSize: root.noteSize
                    valueSize: root.inputSize
                    bodyTop: root.sectionBodyTop
                    contentMargin: root.sectionContentMargin
                }
                OperatorText { width: parent.width; height: implicitHeight; visible: root.showPackage; text: root.packageHelpText; size: root.noteSize; color: root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
            }
        }
        OperatorSection {
            id: parametersSection
            objectName: "terminalSpeechParametersSection"
            visible: root.showEspeak || root.showHttp
            width: parent.width
            height: parameterColumn.implicitHeight + bodyTop + contentMargin
            title: "实际合成参数 · 保存后再启用"
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            fontFamily: root.fontFamily
            outlineColor: root.inputBorderColor
            surfaceColor: root.surfaceColor
            bodyTop: root.sectionBodyTop
            contentMargin: root.sectionContentMargin
            Column {
                id: parameterColumn
                width: parent.width
                spacing: root.formSpacing
                GridLayout {
                    width: parent.width
                    columns: width >= root.fieldBreakpoint ? 2 : 1
                    columnSpacing: root.formColumnGap
                    rowSpacing: root.fieldRowSpacing
                    OperatorStartupFieldForm {
                        id: executableField
                        Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignTop
                        visible: root.showEspeak
                        label: "eSpeak可执行文件引用"; value: root.executableValue; maximumLength: 1024; editable: root.configurationEditable
                        hint: "留空由宿主从PATH查找espeak-ng，或填写明确的可执行文件路径；不填写参数串。"
                        labelHeight: root.fieldLabelHeight; labelGap: root.fieldLabelGap; controlHeight: root.controlHeight
                        hintGap: root.fieldHintGap; minimumHintHeight: root.fieldHintMinimumHeight; hintBottomPadding: root.fieldHintExtraHeight
                        labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.hintSize
                        secondaryTextColor: root.secondaryTextColor; textColor: root.textColor; warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor; inputBorderColor: root.inputBorderColor
                        fontFamily: root.fontFamily; inputFontFamily: root.inputFontFamily
                    }
                    OperatorStartupFieldForm {
                        id: voiceField
                        Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignTop
                        visible: root.showEspeak
                        label: "eSpeak音色标识"; value: root.voiceValue; maximumLength: 48; editable: root.configurationEditable
                        hint: "使用已安装音色的真实标识；不伪造可用音色目录。"
                        labelHeight: root.fieldLabelHeight; labelGap: root.fieldLabelGap; controlHeight: root.controlHeight
                        hintGap: root.fieldHintGap; minimumHintHeight: root.fieldHintMinimumHeight; hintBottomPadding: root.fieldHintExtraHeight
                        labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.hintSize
                        secondaryTextColor: root.secondaryTextColor; textColor: root.textColor; warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor; inputBorderColor: root.inputBorderColor
                        fontFamily: root.fontFamily; inputFontFamily: root.inputFontFamily
                    }
                    OperatorStartupFieldForm {
                        id: speedField
                        Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignTop
                        visible: root.showEspeak
                        label: "eSpeak语速"; value: root.speedValue; maximumLength: 3; editable: root.configurationEditable
                        hint: "80–350整数；默认值175来自原生配置模板。"
                        labelHeight: root.fieldLabelHeight; labelGap: root.fieldLabelGap; controlHeight: root.controlHeight
                        hintGap: root.fieldHintGap; minimumHintHeight: root.fieldHintMinimumHeight; hintBottomPadding: root.fieldHintExtraHeight
                        labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.hintSize
                        secondaryTextColor: root.secondaryTextColor; textColor: root.textColor; warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor; inputBorderColor: root.inputBorderColor
                        fontFamily: root.fontFamily; inputFontFamily: root.inputFontFamily
                    }
                    OperatorStartupFieldForm {
                        id: endpointField
                        Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignTop
                        visible: root.showHttp
                        label: "本机Piper HTTP完整端点"; value: root.endpointValue; maximumLength: 2048; editable: root.configurationEditable
                        hint: "按真实部署填写http://回环地址及路径；不预填端口。可先保存空配置，空端点不能启用。"
                        labelHeight: root.fieldLabelHeight; labelGap: root.fieldLabelGap; controlHeight: root.controlHeight
                        hintGap: root.fieldHintGap; minimumHintHeight: root.fieldHintMinimumHeight; hintBottomPadding: root.fieldHintExtraHeight
                        labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.hintSize
                        secondaryTextColor: root.secondaryTextColor; textColor: root.textColor; warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor; inputBorderColor: root.inputBorderColor
                        fontFamily: root.fontFamily; inputFontFamily: root.inputFontFamily
                    }
                    OperatorStartupFieldForm {
                        id: modelField
                        Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignTop
                        visible: root.showHttp
                        label: "Piper音色标识 · 可留空"; value: root.modelValue; maximumLength: 128; editable: root.configurationEditable
                        hint: "留空由服务使用其实际默认音色；字段名model，不是模型目录查询。"
                        labelHeight: root.fieldLabelHeight; labelGap: root.fieldLabelGap; controlHeight: root.controlHeight
                        hintGap: root.fieldHintGap; minimumHintHeight: root.fieldHintMinimumHeight; hintBottomPadding: root.fieldHintExtraHeight
                        labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.hintSize
                        secondaryTextColor: root.secondaryTextColor; textColor: root.textColor; warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor; inputBorderColor: root.inputBorderColor
                        fontFamily: root.fontFamily; inputFontFamily: root.inputFontFamily
                    }
                    OperatorStartupFieldForm {
                        id: timeoutField
                        Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignTop
                        label: "合成／播放超时 / ms"; value: root.timeoutValue; maximumLength: 5; editable: root.configurationEditable
                        hint: "50–60000ms整数；超时与失效由实际服务处理，不续命建议。"
                        labelHeight: root.fieldLabelHeight; labelGap: root.fieldLabelGap; controlHeight: root.controlHeight
                        hintGap: root.fieldHintGap; minimumHintHeight: root.fieldHintMinimumHeight; hintBottomPadding: root.fieldHintExtraHeight
                        labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.hintSize
                        secondaryTextColor: root.secondaryTextColor; textColor: root.textColor; warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor; inputBorderColor: root.inputBorderColor
                        fontFamily: root.fontFamily; inputFontFamily: root.inputFontFamily
                    }
                    OperatorStartupFieldForm {
                        id: playerField
                        Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignTop
                        label: "音频播放程序引用 · 可留空"; value: root.playerValue; maximumLength: 1024; editable: root.configurationEditable
                        hint: "仅启用播放时使用；留空按现有服务查找aplay，不填写shell命令。"
                        labelHeight: root.fieldLabelHeight; labelGap: root.fieldLabelGap; controlHeight: root.controlHeight
                        hintGap: root.fieldHintGap; minimumHintHeight: root.fieldHintMinimumHeight; hintBottomPadding: root.fieldHintExtraHeight
                        labelSize: root.labelSize; inputSize: root.inputSize; hintSize: root.hintSize
                        secondaryTextColor: root.secondaryTextColor; textColor: root.textColor; warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor; inputBorderColor: root.inputBorderColor
                        fontFamily: root.fontFamily; inputFontFamily: root.inputFontFamily
                    }
                }
                OperatorCheckBox {
                    id: playbackCheck
                    objectName: "terminalSpeechPlayback"
                    width: Math.min(root.playbackWidth, parent.width)
                    height: root.controlHeight
                    text: "允许合成后交给播放程序"
                    checked: root.playbackValue
                    enabled: root.configurationEditable
                    textColor: root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                }
                OperatorText { width: parent.width; height: implicitHeight; visible: root.showHttp; text: root.httpHelpText; size: root.noteSize; color: root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
            }
        }
        OperatorText { width: parent.width; height: implicitHeight; text: root.coordinationHelpText; size: root.noteSize; color: root.secondaryTextColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: implicitHeight; visible: root.validationMessage.length > 0; text: root.validationMessage; size: root.noteSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
    }
}
