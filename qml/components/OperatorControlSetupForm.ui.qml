import QtQuick

// Historical local control configuration drawing only. The ordinary wrapper
// owns drafts, scope, validation and explicit native save/reload requests.
Item {
    id: root
    objectName: "controlSetupForm"
    implicitWidth: 720
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property alias dartAuthorizedControl: dartAuthorizedCheck
    property alias runeAllowedControl: runeAllowedCheck
    property alias runeKindControl: runeKindSelect
    property alias operationControl: operationSelect
    property alias mappingAllowedControl: mappingAllowedCheck
    property alias mappingVerifiedControl: mappingVerifiedCheck
    property alias paramModeControl: paramModeSelect
    property alias paramValueControl: paramValueInput
    property alias paramSourceControl: paramSourceInput
    property alias saveControl: saveButton
    property alias discardControl: discardButton
    property int dartCount: 0
    property Component dartDelegate: null
    readonly property real dartDelegateWidth: dartBody.width
    property bool inputEditable: false
    property bool operationEditable: false
    property bool paramEditable: false
    property bool saveEnabled: false
    property bool discardEnabled: false
    property bool dartAuthorized: false
    property bool runeAllowed: false
    property bool mappingAllowed: false
    property bool mappingVerified: false
    property var runeTitles: []
    property int runeIndex: -1
    property string runeDisplayText: "未提供历史场景选项"
    property var operationTitles: []
    property int operationIndex: -1
    property string operationDisplayText: "尚未选择历史操作"
    property var paramModeTitles: []
    property int paramModeIndex: -1
    property string paramModeDisplayText: "未配置参数模式"
    property string paramValueText: ""
    property string paramInputLabel: "历史通用命令的uint32参数"
    property string paramSourceText: ""
    property string contextText: "Designer绘制参考 · 未接通配置宿主、机器人身份或目标协议。"
    property string editingMessage: "当前仅绘制，所有配置入口关闭。"
    property bool editingLocked: true
    property string mappingStatusText: "草稿：本项关闭或尚未配置。"
    property string entryMessage: "未提供参数依据；本Form不生成参数映射。"
    property bool entryHasError: false
    property string statusText: "配置宿主未接通；没有保存、应用或发送命令。"
    property bool statusHasError: false
    property string saveText: "保存并应用本地配置"
    property string dirtyMessage: "当前没有未保存改动。"
    property string headingText: "操作命令配置 · 本地"
    property string historicalBoundaryText: "此页保留历史2026客户端操作入口与显式参数映射，不是2027正式线路接口。保存只修改本机配置，命令仍需在原面板选择、核验并确认。"
    property real formSpacing: 14
    property real permissionSpacing: 14
    property real permissionBreakpoint: 760
    property real commonSpacing: 10
    property real dartSpacing: 6
    property real runeSpacing: 10
    property real fieldSpacing: 6
    property real flagSpacing: 12
    property real parameterSpacing: 12
    property real actionSpacing: 12
    property real mappingBreakpoint: 600
    property real actionBreakpoint: 360
    property real sectionBodyTop: 47
    property real sectionContentMargin: 14
    property real controlHeight: 38
    property real labelHeight: 24
    property real headingHeight: 28
    property real contextMinimumHeight: 24
    property real permissionNoteMinimumHeight: 42
    property real runeNoteMinimumHeight: 56
    property real mappingIntroMinimumHeight: 42
    property real mappingStatusMinimumHeight: 24
    property real entryNoteMinimumHeight: 28
    property real statusMinimumHeight: 26
    property real dirtyMinimumHeight: 24
    property real headingSize: 16
    property real sectionTitleSize: 14
    property real noteSize: 12
    property real hintSize: 11
    property real inputSize: 14
    property color surfaceColor: Theme.hudSolid
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property color inputSurfaceColor: "#232c27"
    property color selectSurfaceColor: "#282f2c"
    property string fontFamily: Theme.fontFamily
    property string inputFontFamily: root.fontFamily

    Rectangle { anchors.fill: parent; color: root.surfaceColor; z: -1 }
    Column {
        id: contentColumn
        width: root.width
        spacing: root.formSpacing
        OperatorText { width: parent.width; height: root.headingHeight; text: root.headingText; size: root.headingSize; font.bold: true; font.family: root.fontFamily; color: root.textColor }
        OperatorText { width: parent.width; height: Math.max(root.contextMinimumHeight, implicitHeight); text: root.contextText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: implicitHeight; text: root.historicalBoundaryText; size: root.hintSize; color: root.warningColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        OperatorText { width: parent.width; height: Math.max(root.contextMinimumHeight, implicitHeight); text: root.editingMessage; size: root.noteSize; color: root.editingLocked ? root.warningColor : root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        Flow {
            id: permissionCards
            width: parent.width
            spacing: root.permissionSpacing
            property real cardWidth: width >= root.permissionBreakpoint ? (width - root.permissionSpacing) / 2 : width
            OperatorSection {
                id: dartSection
                objectName: "controlSetupDartSection"
                width: permissionCards.cardWidth
                height: dartBody.implicitHeight + bodyTop + contentMargin
                title: "飞镖 · 本地操作员配置"
                bodyTop: root.sectionBodyTop; contentMargin: root.sectionContentMargin; titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily; titleColor: root.textColor; outlineColor: root.separatorColor; surfaceColor: root.surfaceColor
                Column {
                    id: dartBody
                    width: parent.width
                    spacing: root.dartSpacing
                    OperatorCheckBox {
                        id: dartAuthorizedCheck
                        width: parent.width; height: root.controlHeight
                        text: "本人配置云台手飞镖操作入口"
                        checked: root.dartAuthorized; enabled: root.inputEditable
                        textColor: root.textColor; font.family: root.fontFamily
                        font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                    }
                    Repeater { model: root.dartCount; delegate: root.dartDelegate }
                    OperatorText { width: parent.width; height: Math.max(root.permissionNoteMinimumHeight, implicitHeight); text: "这些开关是本地配置，不是赛事引擎授权。实际闸门、目标、次数与冷却仍须核验；不会自动执行动作。"; size: root.hintSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                }
            }
            OperatorSection {
                objectName: "controlSetupRuneSection"
                width: permissionCards.cardWidth
                height: runeBody.implicitHeight + bodyTop + contentMargin
                title: "能量机关 · 本地操作员配置"
                bodyTop: root.sectionBodyTop; contentMargin: root.sectionContentMargin; titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily; titleColor: root.textColor; outlineColor: root.separatorColor; surfaceColor: root.surfaceColor
                Column {
                    id: runeBody
                    width: parent.width
                    spacing: root.runeSpacing
                    OperatorCheckBox {
                        id: runeAllowedCheck
                        width: parent.width; height: root.controlHeight
                        text: "配置步兵机关激活入口"
                        checked: root.runeAllowed; enabled: root.inputEditable
                        textColor: root.textColor; font.family: root.fontFamily
                        font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                    }
                    OperatorText { width: parent.width; height: root.labelHeight; text: "当前场景类型"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily }
                    OperatorSelect {
                        id: runeKindSelect
                        width: parent.width; height: root.controlHeight
                        label: "本地配置能量机关场景类型"
                        model: root.runeTitles; currentIndex: root.runeIndex
                        displayText: root.runeDisplayText; emptyText: root.runeDisplayText
                        enabled: root.inputEditable
                        textColor: root.textColor; backgroundColor: root.selectSurfaceColor; borderColor: root.separatorColor
                        font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                    }
                    OperatorText { width: parent.width; height: Math.max(root.runeNoteMinimumHeight, implicitHeight); text: "本地声明不代表已收到官方场景资格。激活仍需本机、存活与机关状态通过宿主核验，再由操作员在原面板确认。"; size: root.hintSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                }
            }
        }
        OperatorSection {
            objectName: "controlSetupMappingSection"
            width: parent.width
            height: commonBody.implicitHeight + bodyTop + contentMargin
            title: "通用命令3–6 · 显式参数映射"
            bodyTop: root.sectionBodyTop; contentMargin: root.sectionContentMargin; titleSize: root.sectionTitleSize
            fontFamily: root.fontFamily; titleColor: root.textColor; outlineColor: root.separatorColor; surfaceColor: root.surfaceColor
            Column {
                id: commonBody
                width: parent.width
                spacing: root.commonSpacing
                OperatorText { width: parent.width; height: Math.max(root.mappingIntroMinimumHeight, implicitHeight); text: "历史2026客户端通信协议V2.0.0未明确这些操作的param语义。未配置或未声明核验的映射保持不可用；不会填入猜测的0、1、60、100或10。"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                OperatorSelect {
                    id: operationSelect
                    width: parent.width; height: root.controlHeight
                    label: "选择需要编辑的通用命令映射"
                    model: root.operationTitles; currentIndex: root.operationIndex
                    displayText: root.operationDisplayText; emptyText: root.operationDisplayText
                    enabled: root.operationEditable
                    textColor: root.textColor; backgroundColor: root.selectSurfaceColor; borderColor: root.separatorColor
                    font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                }
                Flow {
                    id: mappingFlags
                    width: parent.width; spacing: root.flagSpacing
                    property real cellWidth: width >= root.mappingBreakpoint ? (width - root.flagSpacing) / 2 : width
                    OperatorCheckBox {
                        id: mappingAllowedCheck
                        width: mappingFlags.cellWidth; height: root.controlHeight
                        text: "启用此项映射"; enabled: root.inputEditable; checked: root.mappingAllowed
                        textColor: root.textColor; font.family: root.fontFamily
                        font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                    }
                    OperatorCheckBox {
                        id: mappingVerifiedCheck
                        width: mappingFlags.cellWidth; height: root.controlHeight
                        text: "本人已核验参数依据"; enabled: root.inputEditable; checked: root.mappingVerified
                        textColor: root.textColor; font.family: root.fontFamily
                        font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                    }
                }
                OperatorText { width: parent.width; height: Math.max(root.mappingStatusMinimumHeight, implicitHeight); text: root.mappingStatusText; size: root.hintSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                Flow {
                    id: parameterFields
                    width: parent.width; spacing: root.parameterSpacing
                    property real cellWidth: width >= root.mappingBreakpoint ? (width - root.parameterSpacing) / 2 : width
                    Column {
                        width: parameterFields.cellWidth; spacing: root.fieldSpacing
                        OperatorText { width: parent.width; height: root.labelHeight; text: "参数模式"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily }
                        OperatorSelect {
                            id: paramModeSelect
                            width: parent.width; height: root.controlHeight
                            label: "通用命令参数模式"
                            model: root.paramModeTitles; currentIndex: root.paramModeIndex
                            displayText: root.paramModeDisplayText; emptyText: root.paramModeDisplayText
                            enabled: root.inputEditable
                            textColor: root.textColor; backgroundColor: root.selectSurfaceColor; borderColor: root.separatorColor
                            font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                        }
                    }
                    Column {
                        width: parameterFields.cellWidth; spacing: root.fieldSpacing
                        OperatorText { width: parent.width; height: root.labelHeight; text: "明确参数值"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily }
                        OperatorInput {
                            id: paramValueInput
                            width: parent.width; height: root.controlHeight
                            label: root.paramInputLabel
                            placeholderText: "0…4294967295；不填默认值"
                            maximumLength: 10; inputMethodHints: Qt.ImhDigitsOnly
                            text: root.paramValueText; enabled: root.paramEditable
                            color: enabled ? root.textColor : root.mutedColor; backgroundColor: root.inputSurfaceColor; borderColor: root.separatorColor
                            font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                        }
                    }
                }
                OperatorText { width: parent.width; height: root.labelHeight; text: "核验来源／协议或引擎版本"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily }
                OperatorInput {
                    id: paramSourceInput
                    width: parent.width; height: root.controlHeight
                    label: "此项参数映射的核验来源与版本"
                    maximumLength: 256
                    placeholderText: "填写可追溯的依据；仅声明核验时必须填写"
                    text: root.paramSourceText; enabled: root.inputEditable
                    color: enabled ? root.textColor : root.mutedColor; backgroundColor: root.inputSurfaceColor; borderColor: root.separatorColor
                    font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                }
                OperatorText { width: parent.width; height: Math.max(root.entryNoteMinimumHeight, implicitHeight); text: root.entryMessage; size: root.hintSize; color: root.entryHasError ? root.warningColor : root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                OperatorText { width: parent.width; height: Math.max(root.entryNoteMinimumHeight, implicitHeight); text: "切换操作保留各项草稿。现场17／42mm数量策略保持原样；装配会话上下文由宿主管理，不在本页保存。"; size: root.hintSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
            }
        }
        OperatorText { width: parent.width; height: Math.max(root.statusMinimumHeight, implicitHeight); text: root.statusText; size: root.noteSize; color: root.statusHasError ? root.warningColor : root.mutedColor; font.family: root.fontFamily; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
        Flow {
            id: buttons
            width: parent.width; spacing: root.actionSpacing
            property real cellWidth: width >= root.actionBreakpoint ? (width - root.actionSpacing) / 2 : width
            OperatorButton { id: saveButton; width: buttons.cellWidth; height: root.controlHeight; text: root.saveText; enabled: root.saveEnabled; primary: root.saveEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
            OperatorButton { id: discardButton; width: buttons.cellWidth; height: root.controlHeight; text: "放弃草稿／重新载入"; enabled: root.discardEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale)) }
        }
        OperatorText { width: parent.width; height: Math.max(root.dirtyMinimumHeight, implicitHeight); text: root.dirtyMessage; size: root.hintSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
    }
}
