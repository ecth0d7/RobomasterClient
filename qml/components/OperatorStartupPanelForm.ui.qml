import QtQuick
import QtQuick.Layouts

// Complete startup body. The ordinary wrapper owns policy, drafts and native actions.
Item {
    id: root
    objectName: "startupPanelForm"
    implicitWidth: 1384
    implicitHeight: 692
    width: implicitWidth
    height: implicitHeight
    // 独立编辑时提供对比底色；正式外框保留原贴图。
    property bool drawingBackgroundVisible: true
    property color drawingBackgroundColor: Theme.hudSolid
    Rectangle { anchors.fill: parent; visible: root.drawingBackgroundVisible; color: root.drawingBackgroundColor; z: -1 }
    property int selectedPage: 0
    property int tabCount: 0
    property int pluginCount: 0
    property Component tabDelegate: null
    property Component pluginDelegate: null
    property bool inputEditable: false
    property bool phaseWarning: false
    property bool statusWarning: false
    property bool undoEnabled: false
    property bool saveEnabled: false
    property bool connectEnabled: false
    property bool loadProfileEnabled: false
    property bool saveProfileEnabled: false
    property string phaseText: "启动配置宿主未接通"
    property string statusText: "未提供本次实际启动配置。"
    property string headerHintText: "Designer绘制参考；不保存、不连接或创建服务。"
    property string purposeNoteText: "未提供用途说明。"
    property string dataPathText: "未提供当前规则的数据路径。"
    property string messageBoundaryText: "编辑草稿不会建立连接。"
    property string videoBoundaryText: "未收到数据，不显示实测图传状态。"
    property string rendererBoundaryText: "绘制后端由宿主在启动时决定。"
    property string migrationText: "未提供迁移目录。"
    property string pluginCatalogText: "本地发现清单尚未公开。"
    property string optionalModulesText: "可选模块未接通；本地客户端能力由宿主确认。"
    property string runtimeTitle: "未取得本次运行配置"
    property string pendingText: "没有可核验的待启动配置。"
    property string fileBoundaryText: "启动配置文件能力尚未公开。"
    property string feedbackText: "宿主未接通；没有保存或应用配置。"
    property string connectText: "返回连接与登录"
    property string saveText: "保存本地UI草稿"
    property string loadProfileText: "读取启动配置文件 · 待接通"
    property string saveProfileText: "写入启动配置文件 · 待接通"
    property color feedbackColor: root.mutedColor
    property var rendererRows: []
    property var runtimeRows: []
    property var savedRows: []
    property string nameValue: ""
    property string nameError: ""
    property string hostLabel: "导出地址"
    property string hostValue: ""
    property string hostError: ""
    property string mqttPortValue: ""
    property string mqttPortError: ""
    property string videoBindValue: ""
    property string videoBindError: ""
    property string videoPortValue: ""
    property string videoPortError: ""
    property string uiDirValue: ""
    property string uiDirError: ""
    property string pluginDirValue: ""
    property string pluginDirError: ""
    property var purposeChoices: []
    property int purposeIndex: -1
    property string purposeSelectionText: "请选择启动用途"
    property var codecChoices: []
    property int codecIndex: -1
    property string codecSelectionText: "请选择视频编码"
    property var rendererChoices: []
    property int rendererIndex: -1
    property string rendererSelectionText: "请选择绘制后端"
    property real chromeSpacing: 16
    property real columnGap: 22
    property real pageRowSpacing: 12
    property real pageBreakpoint: 850
    property real formSpacing: 12
    property real fieldSpacing: 8
    property real tabSpacing: 12
    property real tabBreakpoint: 700
    property int tabColumns: width >= tabBreakpoint ? Math.max(1, tabCount) : 2
    property real headerMinimumHeight: 92
    property real headerInset: 14
    property real headerVerticalInset: 8
    property real headerBottomInset: 6
    property real headerLineSpacing: 4
    property real headerTitleHeight: 26
    property real headerStatusHeight: 22
    property real headerHintHeight: 22
    property real headerTitleSize: 15
    property real headerStatusSize: 12
    property real headerHintSize: 11
    property real sectionTitleSize: 14
    property real sectionContentMargin: 14
    property real sectionBodyTop: 47
    property real sectionTitleTop: 9
    property real sectionTitleHeight: 25
    property real labelHeight: 26
    property real labelGap: 4
    property real controlHeight: 38
    property real minimumHintHeight: 26
    property real hintBottomPadding: 4
    property real textBottomPadding: 8
    property real labelSize: 12
    property real inputSize: 14
    property real noteSize: 11
    property real paragraphSize: 12
    property real emphasisSize: 13
    property real purposeNoteHeight: 88
    property real dataPathHeight: 92
    property real messageBoundaryHeight: 94
    property real videoBoundaryHeight: 74
    property real rendererBoundaryHeight: 104
    property real migrationHeight: 120
    property real pluginCatalogHeight: 80
    property real optionalModulesHeight: 104
    property real pendingHeight: 70
    property real fileBoundaryHeight: 108
    property real scrollContentInset: 16
    property real scrollBarWidth: 8
    property real scrollThumbWidth: 6
    property real scrollRadius: 3
    property real footerMinimumHeight: 58
    property real footerFeedbackHeight: 50
    property real footerGap: 14
    property real footerActionTop: 20
    property real footerActionSpacing: 12
    property real footerBreakpoint: 1060
    property real footerStackBreakpoint: 600
    property real footerCompactSpacing: 12
    property real undoWidth: 184
    property real saveWidth: 214
    property real connectWidth: 192
    property string fontFamily: Theme.fontFamily
    property string inputFontFamily: root.fontFamily
    property string numericFontFamily: Theme.numberFamily
    property color surfaceColor: "transparent"
    property color headerSurfaceColor: Theme.hudSurface
    property color sectionSurfaceColor: "transparent"
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color separatorColor: Theme.line
    property color editableBorderColor: Theme.hudBorder
    property color inputSurfaceColor: "#232c27"
    property color inputBorderColor: Theme.line
    property color scrollTrackColor: "#14201a"
    property color scrollThumbColor: root.mutedColor
    property color scrollPressedColor: root.textColor
    readonly property real tabDelegateWidth: Math.max(0, (tabs.width - root.tabSpacing * (root.tabColumns - 1)) / root.tabColumns)
    readonly property real pluginDelegateWidth: Math.max(0, pluginsContent.availableWidth - root.scrollContentInset)
    property alias nameControl: nameField.inputControl
    property alias purposeControl: purposeField.selectControl
    property alias hostControl: hostField.inputControl
    property alias mqttPortControl: mqttPortField.inputControl
    property alias videoBindControl: videoBindField.inputControl
    property alias videoPortControl: videoPortField.inputControl
    property alias codecControl: codecField.selectControl
    property alias rendererControl: rendererField.selectControl
    property alias uiDirControl: uiDirField.inputControl
    property alias pluginDirControl: pluginDirField.inputControl
    property alias undoControl: undoButton
    property alias saveControl: saveButton
    property alias connectControl: connectButton
    property alias loadProfileControl: loadProfileButton
    property alias saveProfileControl: saveProfileButton
    property alias rendererTableControl: rendererTable
    property alias runtimeTableControl: runtimeTable
    property alias savedTableControl: savedTable

    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
        z: -1
    }
    Column {
        id: chrome
        width: parent.width
        spacing: root.chromeSpacing
        Rectangle {
            width: parent.width
            height: Math.max(root.headerMinimumHeight, headerContent.implicitHeight + root.headerVerticalInset + root.headerBottomInset)
            color: root.headerSurfaceColor
            OperatorOutline { color: root.phaseWarning ? root.warningColor : root.editableBorderColor }
            Column {
                id: headerContent
                x: root.headerInset
                y: root.headerVerticalInset
                width: parent.width - root.headerInset * 2
                spacing: root.headerLineSpacing
                OperatorText {
                    width: parent.width
                    height: Math.max(root.headerTitleHeight, implicitHeight)
                    text: root.phaseText
                    size: root.headerTitleSize
                    color: root.phaseWarning ? root.warningColor : root.textColor
                    font.family: root.fontFamily
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }
                OperatorText {
                    width: parent.width
                    height: Math.max(root.headerStatusHeight, implicitHeight)
                    text: root.statusText
                    size: root.headerStatusSize
                    color: root.statusWarning ? root.warningColor : root.mutedColor
                    font.family: root.fontFamily
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }
                OperatorText {
                    width: parent.width
                    height: Math.max(root.headerHintHeight, implicitHeight)
                    text: root.headerHintText
                    size: root.headerHintSize
                    color: root.mutedColor
                    font.family: root.fontFamily
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }
            }
        }
        Grid {
            id: tabs
            width: parent.width
            columns: root.tabColumns
            columnSpacing: root.tabSpacing
            rowSpacing: root.tabSpacing
            Repeater { model: root.tabCount; delegate: root.tabDelegate }
        }
    }
    Item {
        id: pageArea
        objectName: "startupPages"
        y: chrome.height + root.chromeSpacing
        width: parent.width
        height: Math.max(0, footer.y - y - root.footerGap)
        GridLayout {
            objectName: "startupPage0"
            anchors.fill: parent
            visible: root.selectedPage === 0
            columns: width >= root.pageBreakpoint ? 2 : 1
            columnSpacing: root.columnGap
            rowSpacing: root.pageRowSpacing
            OperatorSection {
                objectName: "startupPurposeSection"
                title: "配置草稿与用途"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily
                titleColor: root.textColor
                outlineColor: root.separatorColor
                surfaceColor: root.sectionSurfaceColor
                contentMargin: root.sectionContentMargin
                bodyTop: root.sectionBodyTop
                titleTop: root.sectionTitleTop
                titleHeight: root.sectionTitleHeight
                OperatorScrollableColumn {
                    id: purposeContent
                    anchors.fill: parent
                    entrySpacing: root.formSpacing
                    contentRightInset: root.scrollContentInset
                    scrollBarWidth: root.scrollBarWidth
                    scrollThumbWidth: root.scrollThumbWidth
                    scrollRadius: root.scrollRadius
                    scrollTrackColor: root.scrollTrackColor
                    scrollThumbColor: root.scrollThumbColor
                    scrollPressedColor: root.scrollPressedColor
                    OperatorStartupFieldForm {
                        id: nameField
                        objectName: "startupNameField"
                        width: parent.width
                        editable: root.inputEditable
                        labelHeight: root.labelHeight
                        labelGap: root.labelGap
                        controlHeight: root.controlHeight
                        hintGap: root.fieldSpacing
                        minimumHintHeight: root.minimumHintHeight
                        hintBottomPadding: root.hintBottomPadding
                        labelSize: root.labelSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        inputFontFamily: root.inputFontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor
                        inputBorderColor: root.inputBorderColor
                        label: "草稿名称"
                        value: root.nameValue
                        error: root.nameError
                        hint: "记住本地编辑选择；生效启动配置另行确认。"
                        maximumLength: 64
                    }
                    OperatorSetupSelectForm {
                        id: purposeField
                        objectName: "startupPurposeField"
                        width: parent.width
                        editable: root.inputEditable
                        labelHeight: root.labelHeight
                        labelGap: root.labelGap
                        controlHeight: root.controlHeight
                        labelSize: root.labelSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        inputFontFamily: root.inputFontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor
                        inputBorderColor: root.inputBorderColor
                        label: "下次启动用途"
                        choices: root.purposeChoices
                        selectedIndex: root.purposeIndex
                        selectionText: root.purposeSelectionText
                        minimumHintHeight: 0
                        hintBottomPadding: 0
                        hintGap: 0
                    }
                    OperatorText {
                        width: parent.width
                        height: Math.max(root.purposeNoteHeight, implicitHeight + root.textBottomPadding)
                        text: root.purposeNoteText
                        size: root.paragraphSize
                        color: root.mutedColor
                        font.family: root.fontFamily
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                    OperatorText {
                        width: parent.width
                        height: Math.max(root.dataPathHeight, implicitHeight + root.textBottomPadding)
                        text: root.dataPathText
                        size: root.paragraphSize
                        color: root.mutedColor
                        font.family: root.fontFamily
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                }
            }
            OperatorSection {
                objectName: "startupMessageSection"
                title: "选手端消息导出"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily
                titleColor: root.textColor
                outlineColor: root.separatorColor
                surfaceColor: root.sectionSurfaceColor
                contentMargin: root.sectionContentMargin
                bodyTop: root.sectionBodyTop
                titleTop: root.sectionTitleTop
                titleHeight: root.sectionTitleHeight
                OperatorScrollableColumn {
                    id: messageContent
                    anchors.fill: parent
                    entrySpacing: root.formSpacing
                    contentRightInset: root.scrollContentInset
                    scrollBarWidth: root.scrollBarWidth
                    scrollThumbWidth: root.scrollThumbWidth
                    scrollRadius: root.scrollRadius
                    scrollTrackColor: root.scrollTrackColor
                    scrollThumbColor: root.scrollThumbColor
                    scrollPressedColor: root.scrollPressedColor
                    OperatorStartupFieldForm {
                        id: hostField
                        objectName: "startupHostField"
                        width: parent.width
                        editable: root.inputEditable
                        labelHeight: root.labelHeight
                        labelGap: root.labelGap
                        controlHeight: root.controlHeight
                        hintGap: root.fieldSpacing
                        minimumHintHeight: root.minimumHintHeight
                        hintBottomPadding: root.hintBottomPadding
                        labelSize: root.labelSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        inputFontFamily: root.inputFontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor
                        inputBorderColor: root.inputBorderColor
                        label: root.hostLabel
                        value: root.hostValue
                        error: root.hostError
                        hint: "默认192.168.12.1来自官方配置资料；实际主机身份须核验。"
                        maximumLength: 255
                    }
                    OperatorStartupFieldForm {
                        id: mqttPortField
                        objectName: "startupMqttPortField"
                        width: parent.width
                        editable: root.inputEditable
                        labelHeight: root.labelHeight
                        labelGap: root.labelGap
                        controlHeight: root.controlHeight
                        hintGap: root.fieldSpacing
                        minimumHintHeight: root.minimumHintHeight
                        hintBottomPadding: root.hintBottomPadding
                        labelSize: root.labelSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        inputFontFamily: root.inputFontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor
                        inputBorderColor: root.inputBorderColor
                        label: "消息端口"
                        value: root.mqttPortValue
                        error: root.mqttPortError
                        hint: "官方资料默认3333；联调端口以本地源配置为准。"
                        maximumLength: 5
                    }
                    OperatorText {
                        width: parent.width
                        height: Math.max(root.messageBoundaryHeight, implicitHeight + root.textBottomPadding)
                        text: root.messageBoundaryText
                        size: root.paragraphSize
                        color: root.mutedColor
                        font.family: root.fontFamily
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                }
            }
        }
        GridLayout {
            objectName: "startupPage1"
            anchors.fill: parent
            visible: root.selectedPage === 1
            columns: width >= root.pageBreakpoint ? 2 : 1
            columnSpacing: root.columnGap
            rowSpacing: root.pageRowSpacing
            OperatorSection {
                objectName: "startupVideoSection"
                title: "图传导出与监听"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily
                titleColor: root.textColor
                outlineColor: root.separatorColor
                surfaceColor: root.sectionSurfaceColor
                contentMargin: root.sectionContentMargin
                bodyTop: root.sectionBodyTop
                titleTop: root.sectionTitleTop
                titleHeight: root.sectionTitleHeight
                OperatorScrollableColumn {
                    id: videoContent
                    anchors.fill: parent
                    entrySpacing: root.formSpacing
                    contentRightInset: root.scrollContentInset
                    scrollBarWidth: root.scrollBarWidth
                    scrollThumbWidth: root.scrollThumbWidth
                    scrollRadius: root.scrollRadius
                    scrollTrackColor: root.scrollTrackColor
                    scrollThumbColor: root.scrollThumbColor
                    scrollPressedColor: root.scrollPressedColor
                    OperatorStartupFieldForm {
                        id: videoBindField
                        objectName: "startupVideoBindField"
                        width: parent.width
                        editable: root.inputEditable
                        labelHeight: root.labelHeight
                        labelGap: root.labelGap
                        controlHeight: root.controlHeight
                        hintGap: root.fieldSpacing
                        minimumHintHeight: root.minimumHintHeight
                        hintBottomPadding: root.hintBottomPadding
                        labelSize: root.labelSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        inputFontFamily: root.inputFontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor
                        inputBorderColor: root.inputBorderColor
                        label: "本机监听地址"
                        value: root.videoBindValue
                        error: root.videoBindError
                        hint: "0.0.0.0为所有本机IPv4接口；本地样例用127.0.0.1。"
                        maximumLength: 128
                    }
                    OperatorStartupFieldForm {
                        id: videoPortField
                        objectName: "startupVideoPortField"
                        width: parent.width
                        editable: root.inputEditable
                        labelHeight: root.labelHeight
                        labelGap: root.labelGap
                        controlHeight: root.controlHeight
                        hintGap: root.fieldSpacing
                        minimumHintHeight: root.minimumHintHeight
                        hintBottomPadding: root.hintBottomPadding
                        labelSize: root.labelSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        inputFontFamily: root.inputFontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor
                        inputBorderColor: root.inputBorderColor
                        label: "图传端口"
                        value: root.videoPortValue
                        error: root.videoPortError
                        hint: "官方资料默认3334；实际端口绑定由视频端点确认。"
                        maximumLength: 5
                    }
                    OperatorSetupSelectForm {
                        id: codecField
                        objectName: "startupCodecField"
                        width: parent.width
                        editable: root.inputEditable
                        labelHeight: root.labelHeight
                        labelGap: root.labelGap
                        controlHeight: root.controlHeight
                        labelSize: root.labelSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        inputFontFamily: root.inputFontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor
                        inputBorderColor: root.inputBorderColor
                        label: "视频编码选项"
                        choices: root.codecChoices
                        selectedIndex: root.codecIndex
                        selectionText: root.codecSelectionText
                        minimumHintHeight: 0
                        hintBottomPadding: 0
                        hintGap: 0
                    }
                    OperatorText {
                        width: parent.width
                        height: Math.max(root.videoBoundaryHeight, implicitHeight + root.textBottomPadding)
                        text: root.videoBoundaryText
                        size: root.noteSize
                        color: root.mutedColor
                        font.family: root.fontFamily
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                }
            }
            OperatorSection {
                objectName: "startupRendererSection"
                title: "绘制后端 · 启动时决定"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily
                titleColor: root.textColor
                outlineColor: root.separatorColor
                surfaceColor: root.sectionSurfaceColor
                contentMargin: root.sectionContentMargin
                bodyTop: root.sectionBodyTop
                titleTop: root.sectionTitleTop
                titleHeight: root.sectionTitleHeight
                OperatorScrollableColumn {
                    id: rendererContent
                    anchors.fill: parent
                    entrySpacing: root.formSpacing
                    contentRightInset: root.scrollContentInset
                    scrollBarWidth: root.scrollBarWidth
                    scrollThumbWidth: root.scrollThumbWidth
                    scrollRadius: root.scrollRadius
                    scrollTrackColor: root.scrollTrackColor
                    scrollThumbColor: root.scrollThumbColor
                    scrollPressedColor: root.scrollPressedColor
                    OperatorSetupSelectForm {
                        id: rendererField
                        objectName: "startupRendererField"
                        width: parent.width
                        editable: root.inputEditable
                        labelHeight: root.labelHeight
                        labelGap: root.labelGap
                        controlHeight: root.controlHeight
                        labelSize: root.labelSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        inputFontFamily: root.inputFontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor
                        inputBorderColor: root.inputBorderColor
                        label: "下次启动的绘制选择"
                        choices: root.rendererChoices
                        selectedIndex: root.rendererIndex
                        selectionText: root.rendererSelectionText
                        minimumHintHeight: 0
                        hintBottomPadding: 0
                        hintGap: 0
                    }
                    OperatorText {
                        width: parent.width
                        height: Math.max(root.rendererBoundaryHeight, implicitHeight + root.textBottomPadding)
                        text: root.rendererBoundaryText
                        size: root.paragraphSize
                        color: root.mutedColor
                        font.family: root.fontFamily
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                    OperatorDiagnosticTable {
                        id: rendererTable
                        width: parent.width
                        fontFamily: root.fontFamily
                        numericFontFamily: root.numericFontFamily
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        separatorColor: root.separatorColor
                        titleColor: root.textColor
                        outlineColor: root.separatorColor
                        surfaceColor: root.sectionSurfaceColor
                        titleSize: root.sectionTitleSize
                        labelSize: root.noteSize
                        valueSize: root.inputSize
                        contentMargin: root.sectionContentMargin
                        bodyTop: root.sectionBodyTop
                        titleTop: root.sectionTitleTop
                        titleHeight: root.sectionTitleHeight
                        title: "本次实际状态"
                        rows: root.rendererRows
                    }
                }
            }
        }
        GridLayout {
            objectName: "startupPage2"
            anchors.fill: parent
            visible: root.selectedPage === 2
            columns: width >= root.pageBreakpoint ? 2 : 1
            columnSpacing: root.columnGap
            rowSpacing: root.pageRowSpacing
            OperatorSection {
                objectName: "startupMigrationSection"
                title: "资源包与可迁移目录"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily
                titleColor: root.textColor
                outlineColor: root.separatorColor
                surfaceColor: root.sectionSurfaceColor
                contentMargin: root.sectionContentMargin
                bodyTop: root.sectionBodyTop
                titleTop: root.sectionTitleTop
                titleHeight: root.sectionTitleHeight
                OperatorScrollableColumn {
                    id: migrationContent
                    anchors.fill: parent
                    entrySpacing: root.formSpacing
                    contentRightInset: root.scrollContentInset
                    scrollBarWidth: root.scrollBarWidth
                    scrollThumbWidth: root.scrollThumbWidth
                    scrollRadius: root.scrollRadius
                    scrollTrackColor: root.scrollTrackColor
                    scrollThumbColor: root.scrollThumbColor
                    scrollPressedColor: root.scrollPressedColor
                    OperatorStartupFieldForm {
                        id: uiDirField
                        objectName: "startupUiDirField"
                        width: parent.width
                        editable: root.inputEditable
                        labelHeight: root.labelHeight
                        labelGap: root.labelGap
                        controlHeight: root.controlHeight
                        hintGap: root.fieldSpacing
                        minimumHintHeight: root.minimumHintHeight
                        hintBottomPadding: root.hintBottomPadding
                        labelSize: root.labelSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        inputFontFamily: root.inputFontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor
                        inputBorderColor: root.inputBorderColor
                        label: "外部UI包目录"
                        value: root.uiDirValue
                        error: root.uiDirError
                        hint: "留空使用程序默认UI包；相对路径以配置文件目录解析。"
                        maximumLength: 512
                    }
                    OperatorStartupFieldForm {
                        id: pluginDirField
                        objectName: "startupPluginDirField"
                        width: parent.width
                        editable: root.inputEditable
                        labelHeight: root.labelHeight
                        labelGap: root.labelGap
                        controlHeight: root.controlHeight
                        hintGap: root.fieldSpacing
                        minimumHintHeight: root.minimumHintHeight
                        hintBottomPadding: root.hintBottomPadding
                        labelSize: root.labelSize
                        inputSize: root.inputSize
                        hintSize: root.noteSize
                        fontFamily: root.fontFamily
                        inputFontFamily: root.inputFontFamily
                        textColor: root.textColor
                        secondaryTextColor: root.mutedColor
                        warningColor: root.warningColor
                        inputSurfaceColor: root.inputSurfaceColor
                        inputBorderColor: root.inputBorderColor
                        label: "原生插件目录"
                        value: root.pluginDirValue
                        error: root.pluginDirError
                        hint: "留空使用程序默认目录；迁移时保留插件及其依赖。"
                        maximumLength: 512
                    }
                    OperatorText {
                        width: parent.width
                        height: Math.max(root.migrationHeight, implicitHeight + root.textBottomPadding)
                        text: root.migrationText
                        size: root.paragraphSize
                        color: root.mutedColor
                        font.family: root.fontFamily
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                }
            }
            OperatorSection {
                objectName: "startupPluginsSection"
                title: "核心插件选择 · 元数据与实际加载分开"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily
                titleColor: root.textColor
                outlineColor: root.separatorColor
                surfaceColor: root.sectionSurfaceColor
                contentMargin: root.sectionContentMargin
                bodyTop: root.sectionBodyTop
                titleTop: root.sectionTitleTop
                titleHeight: root.sectionTitleHeight
                OperatorScrollableColumn {
                    id: pluginsContent
                    anchors.fill: parent
                    entrySpacing: root.formSpacing
                    contentRightInset: root.scrollContentInset
                    scrollBarWidth: root.scrollBarWidth
                    scrollThumbWidth: root.scrollThumbWidth
                    scrollRadius: root.scrollRadius
                    scrollTrackColor: root.scrollTrackColor
                    scrollThumbColor: root.scrollThumbColor
                    scrollPressedColor: root.scrollPressedColor
                    OperatorText {
                        width: parent.width
                        height: Math.max(root.pluginCatalogHeight, implicitHeight + root.textBottomPadding)
                        text: root.pluginCatalogText
                        size: root.noteSize
                        color: root.mutedColor
                        font.family: root.fontFamily
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                    Repeater { model: root.pluginCount; delegate: root.pluginDelegate }
                    OperatorText {
                        width: parent.width
                        height: Math.max(root.optionalModulesHeight, implicitHeight + root.textBottomPadding)
                        text: root.optionalModulesText
                        size: root.noteSize
                        color: root.mutedColor
                        font.family: root.fontFamily
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                }
            }
        }
        GridLayout {
            objectName: "startupPage3"
            anchors.fill: parent
            visible: root.selectedPage === 3
            columns: width >= root.pageBreakpoint ? 2 : 1
            columnSpacing: root.columnGap
            rowSpacing: root.pageRowSpacing
            OperatorSection {
                objectName: "startupRuntimeSection"
                title: "本次实际启动截面"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily
                titleColor: root.textColor
                outlineColor: root.separatorColor
                surfaceColor: root.sectionSurfaceColor
                contentMargin: root.sectionContentMargin
                bodyTop: root.sectionBodyTop
                titleTop: root.sectionTitleTop
                titleHeight: root.sectionTitleHeight
                OperatorScrollableColumn {
                    id: runtimeContent
                    anchors.fill: parent
                    entrySpacing: root.formSpacing
                    contentRightInset: root.scrollContentInset
                    scrollBarWidth: root.scrollBarWidth
                    scrollThumbWidth: root.scrollThumbWidth
                    scrollRadius: root.scrollRadius
                    scrollTrackColor: root.scrollTrackColor
                    scrollThumbColor: root.scrollThumbColor
                    scrollPressedColor: root.scrollPressedColor
                    OperatorDiagnosticTable {
                        id: runtimeTable
                        width: parent.width
                        fontFamily: root.fontFamily
                        numericFontFamily: root.numericFontFamily
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        separatorColor: root.separatorColor
                        titleColor: root.textColor
                        outlineColor: root.separatorColor
                        surfaceColor: root.sectionSurfaceColor
                        titleSize: root.sectionTitleSize
                        labelSize: root.noteSize
                        valueSize: root.inputSize
                        contentMargin: root.sectionContentMargin
                        bodyTop: root.sectionBodyTop
                        titleTop: root.sectionTitleTop
                        titleHeight: root.sectionTitleHeight
                        title: root.runtimeTitle
                        rows: root.runtimeRows
                    }
                }
            }
            OperatorSection {
                objectName: "startupSaveBoundarySection"
                title: "保存与应用边界"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily
                titleColor: root.textColor
                outlineColor: root.separatorColor
                surfaceColor: root.sectionSurfaceColor
                contentMargin: root.sectionContentMargin
                bodyTop: root.sectionBodyTop
                titleTop: root.sectionTitleTop
                titleHeight: root.sectionTitleHeight
                OperatorScrollableColumn {
                    id: saveBoundaryContent
                    anchors.fill: parent
                    entrySpacing: root.formSpacing
                    contentRightInset: root.scrollContentInset
                    scrollBarWidth: root.scrollBarWidth
                    scrollThumbWidth: root.scrollThumbWidth
                    scrollRadius: root.scrollRadius
                    scrollTrackColor: root.scrollTrackColor
                    scrollThumbColor: root.scrollThumbColor
                    scrollPressedColor: root.scrollPressedColor
                    OperatorText {
                        width: parent.width
                        height: Math.max(root.pendingHeight, implicitHeight + root.textBottomPadding)
                        text: root.pendingText
                        size: root.emphasisSize
                        color: root.mutedColor
                        font.family: root.fontFamily
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                    OperatorDiagnosticTable {
                        id: savedTable
                        width: parent.width
                        fontFamily: root.fontFamily
                        numericFontFamily: root.numericFontFamily
                        textColor: root.textColor
                        mutedColor: root.mutedColor
                        separatorColor: root.separatorColor
                        titleColor: root.textColor
                        outlineColor: root.separatorColor
                        surfaceColor: root.sectionSurfaceColor
                        titleSize: root.sectionTitleSize
                        labelSize: root.noteSize
                        valueSize: root.inputSize
                        contentMargin: root.sectionContentMargin
                        bodyTop: root.sectionBodyTop
                        titleTop: root.sectionTitleTop
                        titleHeight: root.sectionTitleHeight
                        title: "已保存UI草稿"
                        rows: root.savedRows
                    }
                    OperatorButton {
                        id: loadProfileButton
                        objectName: "startupLoadProfileControl"
                        width: parent.width
                        height: root.controlHeight
                        textColor: root.textColor
                        font.family: root.fontFamily
                        font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                        text: root.loadProfileText
                        enabled: root.loadProfileEnabled
                    }
                    OperatorButton {
                        id: saveProfileButton
                        objectName: "startupSaveProfileControl"
                        width: parent.width
                        height: root.controlHeight
                        textColor: root.textColor
                        font.family: root.fontFamily
                        font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                        text: root.saveProfileText
                        enabled: root.saveProfileEnabled
                    }
                    OperatorText {
                        width: parent.width
                        height: Math.max(root.fileBoundaryHeight, implicitHeight + root.textBottomPadding)
                        text: root.fileBoundaryText
                        size: root.paragraphSize
                        color: root.warningColor
                        font.family: root.fontFamily
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                }
            }
        }
    }
    Item {
        id: footer
        objectName: "startupFooter"
        y: parent.height - height
        width: parent.width
        height: root.width >= root.footerBreakpoint ? Math.max(root.footerMinimumHeight, feedback.height, actions.implicitHeight + root.footerActionTop) : feedback.height + root.footerCompactSpacing + actions.implicitHeight
        OperatorText {
            id: feedback
            width: root.width >= root.footerBreakpoint ? Math.max(0, parent.width - actions.width - root.footerActionSpacing) : parent.width
            height: Math.max(root.footerFeedbackHeight, implicitHeight)
            text: root.feedbackText
            size: root.noteSize
            color: root.feedbackColor
            font.family: root.fontFamily
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        GridLayout {
            id: actions
            x: root.width >= root.footerBreakpoint ? parent.width - width : 0
            y: root.width >= root.footerBreakpoint ? root.footerActionTop : feedback.height + root.footerCompactSpacing
            width: root.width >= root.footerBreakpoint ? root.undoWidth + root.saveWidth + root.connectWidth + root.footerActionSpacing * 2 : parent.width
            columns: root.width >= root.footerStackBreakpoint ? 3 : 1
            columnSpacing: root.footerActionSpacing
            rowSpacing: root.footerActionSpacing
            OperatorButton {
                id: undoButton
                objectName: "startupUndoControl"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: root.undoWidth
                Layout.preferredHeight: root.controlHeight
                text: "撤销草稿修改"
                enabled: root.undoEnabled
                textColor: root.textColor
                font.family: root.fontFamily
                font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
            }
            OperatorButton {
                id: saveButton
                objectName: "startupSaveControl"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: root.saveWidth
                Layout.preferredHeight: root.controlHeight
                text: root.saveText
                primary: true
                enabled: root.saveEnabled
                textColor: root.textColor
                font.family: root.fontFamily
                font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
            }
            OperatorButton {
                id: connectButton
                objectName: "startupConnectControl"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: root.connectWidth
                Layout.preferredHeight: root.controlHeight
                text: root.connectText
                enabled: root.connectEnabled
                textColor: root.textColor
                font.family: root.fontFamily
                font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
            }
        }
    }
}
