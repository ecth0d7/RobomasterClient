import QtQuick
import QtQuick.Controls

// Settings drawing only. The PanelFrame wrapper owns the local draft, identity
// selection and explicit navigation/apply intents. No external state is written here.
Item {
    id: root
    objectName: "settingsForm"
    implicitWidth: root.panelWidth - 2 * root.panelContentMargin
    implicitHeight: root.panelHeight - root.panelBodyTop - root.panelContentMargin
    width: implicitWidth
    height: implicitHeight
    property alias headerArea: header
    property alias sectionsArea: sectionsViewport
    property alias footerArea: footer
    property alias identityControl: identitySelect
    property alias loginControl: loginButton
    property bool showStartupDraft: false
    property alias startupControl: startupButton
    property alias controlSetupControl: controlSetupButton
    property alias orientationControl: orientationSelect
    property alias sensitivityControl: sensitivitySlider
    property alias servicesControl: servicesButton
    property alias volumeControl: volumeSlider
    property alias ambienceControl: ambienceSlider
    property alias alertTestControl: alertTestButton
    property alias windowModeControl: windowModeSelect
    property alias reducedMotionControl: reducedMotionToggle
    property bool reducedMotion: false
    property bool startupAnimationEnabled: true
    property alias startupAnimationControl: startupAnimationToggle
    property alias replayStartupControl: replayStartupButton
    property alias layoutControl: layoutButton
    property alias shortcutsControl: shortcutsButton
    property alias undoControl: undoButton
    property alias applyControl: applyButton
    property alias performanceRepeater: performanceInstances
    property int performanceCount: 0
    property Component performanceDelegate: null
    readonly property real performanceDelegateWidth: performanceHost.width
    readonly property real performanceDelegateHeight: performanceHost.height

    property string panelTitle: "设置面板"
    property string panelIconAsset: "ServerUI_Setting"
    property url panelBackgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    property real panelWidth: 1360
    property real panelHeight: 650
    property real panelContentMargin: 28
    property real panelBodyTop: 60
    property string headingText: "设置绘制参考 · 未接通配置宿主"
    property string headingNote: "没有应用配置、连接机器人或发送性能选择。"
    property string currentIdentityText: "尚未选择"
    property color currentIdentityColor: root.mutedColor
    property string connectionText: "连接状态未提供"
    property var identityTitles: []
    property int identityIndex: -1
    property string identityDisplayText: "尚未选择身份"
    property bool identityEditable: false
    property string loginText: "登录所选机器人"
    property bool loginEnabled: false
    property string identityNote: "身份编号沿用历史2026参考；当前Form未连接选手端，不表示已确认2027线路。"
    property bool localEditable: false
    property bool sensitivityEditable: false
    property var orientationTitles: []
    property int orientationIndex: -1
    property string orientationDisplayText: "尚未提供图像方向"
    property string orientationNote: "尚未接通图传；本页不修改视频或机器人姿态。"
    property real sensitivityValue: 100
    property string sensitivityNote: "输入比例能力未提供。"
    property real volumeValue: 80
    property real ambienceValue: 50
    property string audioText: "音频状态未提供"
    property string alertTestText: "试听本机提示音"
    property bool alertTestEnabled: false
    property var windowModeTitles: []
    property int windowModeIndex: -1
    property string windowModeDisplayText: "尚未提供显示模式"
    property string actualWindowText: "实际窗口状态未提供"
    property string feedbackText: "配置宿主未接通；本地草稿未应用。"
    property bool feedbackWarning: false
    property string shortcutText: "关闭与返回快捷键由面板宿主提供"
    property string applyText: "应用本地设置"
    property bool undoEnabled: false
    property bool applyEnabled: false

    property real headerMinimumHeight: 34
    property real headerInset: 14
    property real headerTop: 8
    property real headingHeight: 22
    property real headingNoteHeight: 0
    property real headerTextGap: 4
    property real headerBottom: 8
    property real headerSectionsGap: 12
    property real sectionSpacing: 14
    property real sectionsFooterGap: 12
    property real fourColumnBreakpoint: 1120
    property real twoColumnBreakpoint: 660
    property real compactSectionHeight: 420
    property real sectionBodyTop: 47
    property real sectionContentMargin: 12
    property real sectionTitleTop: 9
    property real sectionTitleHeight: 25
    property real sectionTitleSize: 14
    property real entrySpacing: 6
    property real labelHeight: 24
    property real identityHeight: 34
    property real connectionMinimumHeight: 32
    property real identityNoteMinimumHeight: 30
    property real orientationNoteMinimumHeight: 30
    property real sensitivityNoteMinimumHeight: 30
    property real audioNoteMinimumHeight: 30
    property real layoutNoteMinimumHeight: 30
    property real noteBottomPadding: 8
    property real windowStatusHeight: 26
    property real separatorHeight: 1
    property real controlHeight: 38
    property real sliderHeight: 48
    property real sliderValueWidth: 48
    property real sliderLabelHeight: 25
    property real sliderTrackY: 32
    property real sliderTrackHeight: 3
    property real sliderHandleSize: 15
    property real actionSpacing: 10
    property real sectionActionBreakpoint: 240
    property real scrollContentInset: 10
    property real scrollBarWidth: 6
    property real scrollThumbWidth: 4
    property real scrollRadius: 3
    property real footerBreakpoint: 680
    property real footerActionBreakpoint: 420
    property real footerActionSpacing: 12
    property real footerHintGap: 22
    property real footerStatusGap: 6
    property real footerFeedbackHeight: 28
    property real footerFeedbackPadding: 2
    property real footerHintHeight: 26
    property real undoWidth: 196
    property real applyWidth: 200
    property real footerBottomPadding: 4
    property real headingSize: 15
    property real headingNoteSize: 11
    property real identitySize: 16
    property real noteSize: 11
    property real statusSize: 12
    property real inputSize: 12
    property real buttonSize: 14
    property string fontFamily: Theme.fontFamily
    property string inputFontFamily: root.fontFamily
    property string numberFontFamily: Theme.numberFamily
    property bool drawingBackgroundVisible: true
    property color drawingBackgroundColor: Theme.hudSolid
    property color surfaceColor: "transparent"
    property color headerColor: Theme.hudSurface
    property color headerBorderColor: Theme.hudBorder
    property color textColor: Theme.text
    property color mutedColor: Theme.muted
    property color warningColor: Theme.warning
    property color redColor: Theme.red
    property color blueColor: Theme.blue
    property color separatorColor: Theme.line
    property color selectSurfaceColor: "#282f2c"
    property color scrollTrackColor: "#14201a"
    readonly property int sectionColumns: width >= root.fourColumnBreakpoint ? 4 : width >= root.twoColumnBreakpoint ? 2 : 1
    readonly property real sectionWidth: (sectionCards.width - (root.sectionColumns - 1) * root.sectionSpacing) / root.sectionColumns
    readonly property real sectionHeight: root.sectionColumns === 4 ? sectionsViewport.height : root.compactSectionHeight

    Rectangle { anchors.fill: parent; visible: root.drawingBackgroundVisible; color: root.drawingBackgroundColor; z: -1 }
    Rectangle {
        id: header
        visible: root.headingText.length > 0 || root.headingNote.length > 0
        width: parent.width
        height: visible ? Math.max(root.headerMinimumHeight, headerText.implicitHeight + root.headerTop + root.headerBottom) : 0
        color: root.headerColor
        OperatorOutline { color: root.headerBorderColor }
        Column {
            id: headerText
            x: root.headerInset; y: root.headerTop
            width: parent.width - 2 * root.headerInset
            spacing: root.headerTextGap
            OperatorText { width: parent.width; height: Math.max(root.headingHeight, implicitHeight); text: root.headingText; size: root.headingSize; color: root.textColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
            OperatorText { width: parent.width; visible: root.headingNote.length > 0; height: visible ? Math.max(root.headingNoteHeight, implicitHeight) : 0; text: root.headingNote; size: root.headingNoteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
        }
    }
    OperatorScrollableColumn {
        id: sectionsViewport
        objectName: "settingsSectionsViewport"
        y: header.height + root.headerSectionsGap
        width: parent.width
        height: Math.max(0, footer.y - y - root.sectionsFooterGap)
        contentRightInset: root.sectionColumns < 4 ? root.scrollContentInset : 0
        entrySpacing: 0
        scrollBarWidth: root.scrollBarWidth; scrollThumbWidth: root.scrollThumbWidth; scrollRadius: root.scrollRadius
        scrollTrackColor: root.scrollTrackColor; scrollThumbColor: root.mutedColor; scrollPressedColor: root.textColor
        Flow {
            id: sectionCards
            width: parent.width
            spacing: root.sectionSpacing
            OperatorSection {
                objectName: "settingsIdentitySection"
                title: "机器人身份"
                width: root.sectionWidth; height: root.sectionHeight
                bodyTop: root.sectionBodyTop; contentMargin: root.sectionContentMargin
                titleTop: root.sectionTitleTop; titleHeight: root.sectionTitleHeight; titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily; titleColor: root.textColor; outlineColor: root.separatorColor; surfaceColor: root.surfaceColor
                OperatorScrollableColumn {
                    anchors.fill: parent
                    entrySpacing: root.entrySpacing; contentRightInset: root.scrollContentInset
                    scrollBarWidth: root.scrollBarWidth; scrollThumbWidth: root.scrollThumbWidth; scrollRadius: root.scrollRadius
                    scrollTrackColor: root.scrollTrackColor; scrollThumbColor: root.mutedColor; scrollPressedColor: root.textColor
                    OperatorText { width: parent.width; height: root.labelHeight; text: "当前机器人"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily }
                    OperatorText { width: parent.width; height: root.identityHeight; text: root.currentIdentityText; size: root.identitySize; color: root.currentIdentityColor; font.family: root.fontFamily }
                    OperatorText { width: parent.width; height: Math.max(root.connectionMinimumHeight, implicitHeight + root.noteBottomPadding); text: root.connectionText; size: root.statusSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                    OperatorButton {
                        id: startupButton
                        objectName: "settingsConnectionButton"
                        width: parent.width; height: root.controlHeight
                        text: root.showStartupDraft ? "高级启动草稿 / 本次运行" : "MQTT / UDP 连接设置"
                        textColor: root.textColor; font.family: root.fontFamily
                        font.pixelSize: Math.max(root.buttonSize, 9.5 / Math.max(0.1, hudScale))
                    }
                    Rectangle { width: parent.width; height: root.separatorHeight; color: root.separatorColor }
                    OperatorText { width: parent.width; height: root.labelHeight; text: "选择机器人"; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily }
                    OperatorSelect {
                        id: identitySelect
                        width: parent.width; height: root.controlHeight
                        label: "机器人身份及编号"
                        model: root.identityTitles; currentIndex: root.identityIndex
                        displayText: root.identityDisplayText; emptyText: root.identityDisplayText
                        enabled: root.identityEditable
                        textColor: root.textColor; backgroundColor: root.selectSurfaceColor; borderColor: root.separatorColor
                        font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                    }
                    OperatorButton { id: loginButton; width: parent.width; height: root.controlHeight; text: root.loginText; primary: true; enabled: root.loginEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.buttonSize, 9.5 / Math.max(0.1, hudScale)) }
                    OperatorButton { id: controlSetupButton; width: parent.width; height: root.controlHeight; text: "操作权限 / 命令参数"; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.buttonSize, 9.5 / Math.max(0.1, hudScale)) }
                    OperatorText { width: parent.width; height: Math.max(root.identityNoteMinimumHeight, implicitHeight + root.noteBottomPadding); text: root.identityNote; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                }
            }
            Item {
                id: performanceHost
                objectName: "settingsPerformanceHost"
                width: root.sectionWidth; height: root.sectionHeight
                Repeater { id: performanceInstances; model: root.performanceCount; delegate: root.performanceDelegate }
            }
            OperatorSection {
                objectName: "settingsInputSection"
                title: "图传 / 鼠标输入"
                width: root.sectionWidth; height: root.sectionHeight
                bodyTop: root.sectionBodyTop; contentMargin: root.sectionContentMargin
                titleTop: root.sectionTitleTop; titleHeight: root.sectionTitleHeight; titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily; titleColor: root.textColor; outlineColor: root.separatorColor; surfaceColor: root.surfaceColor
                OperatorScrollableColumn {
                    anchors.fill: parent
                    entrySpacing: root.entrySpacing; contentRightInset: root.scrollContentInset
                    scrollBarWidth: root.scrollBarWidth; scrollThumbWidth: root.scrollThumbWidth; scrollRadius: root.scrollRadius
                    scrollTrackColor: root.scrollTrackColor; scrollThumbColor: root.mutedColor; scrollPressedColor: root.textColor
                    OperatorText { width: parent.width; height: root.labelHeight; text: "图像方向"; size: root.statusSize; color: root.textColor; font.family: root.fontFamily }
                    OperatorSelect {
                        id: orientationSelect
                        width: parent.width; height: root.controlHeight
                        label: "图像方向"
                        model: root.orientationTitles; currentIndex: root.orientationIndex
                        displayText: root.orientationDisplayText; emptyText: root.orientationDisplayText
                        enabled: root.localEditable
                        textColor: root.textColor; backgroundColor: root.selectSurfaceColor; borderColor: root.separatorColor
                        font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                    }
                    OperatorText { width: parent.width; height: Math.max(root.orientationNoteMinimumHeight, implicitHeight + root.noteBottomPadding); text: root.orientationNote; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                    Rectangle { width: parent.width; height: root.separatorHeight; color: root.separatorColor }
                    OperatorSlider {
                        id: sensitivitySlider
                        width: parent.width; height: root.sliderHeight
                        label: "鼠标输入比例"; unit: "%"; from: 25; to: 200; value: root.sensitivityValue
                        enabled: root.sensitivityEditable
                        valueWidth: root.sliderValueWidth; labelHeight: root.sliderLabelHeight; trackY: root.sliderTrackY; trackHeight: root.sliderTrackHeight; handleSize: root.sliderHandleSize
                        labelColor: root.textColor; valueColor: enabled ? root.textColor : root.mutedColor
                        font.family: root.inputFontFamily; valueFont.family: root.numberFontFamily
                        font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                    }
                    OperatorText { width: parent.width; height: Math.max(root.sensitivityNoteMinimumHeight, implicitHeight + root.noteBottomPadding); text: root.sensitivityNote; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                    OperatorButton { id: servicesButton; width: parent.width; height: root.controlHeight; text: "图传 / 解码 / 服务状态"; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.buttonSize, 9.5 / Math.max(0.1, hudScale)) }
                }
            }
            OperatorSection {
                objectName: "settingsAudioSection"
                title: "声音 / 界面"
                width: root.sectionWidth; height: root.sectionHeight
                bodyTop: root.sectionBodyTop; contentMargin: root.sectionContentMargin
                titleTop: root.sectionTitleTop; titleHeight: root.sectionTitleHeight; titleSize: root.sectionTitleSize
                fontFamily: root.fontFamily; titleColor: root.textColor; outlineColor: root.separatorColor; surfaceColor: root.surfaceColor
                OperatorScrollableColumn {
                    anchors.fill: parent
                    entrySpacing: root.entrySpacing; contentRightInset: root.scrollContentInset
                    scrollBarWidth: root.scrollBarWidth; scrollThumbWidth: root.scrollThumbWidth; scrollRadius: root.scrollRadius
                    scrollTrackColor: root.scrollTrackColor; scrollThumbColor: root.mutedColor; scrollPressedColor: root.textColor
                    OperatorSlider {
                        id: volumeSlider
                        width: parent.width; height: root.sliderHeight
                        label: "语音播报音量"; unit: "%"; value: root.volumeValue; enabled: root.localEditable
                        valueWidth: root.sliderValueWidth; labelHeight: root.sliderLabelHeight; trackY: root.sliderTrackY; trackHeight: root.sliderTrackHeight; handleSize: root.sliderHandleSize
                        labelColor: root.textColor; valueColor: enabled ? root.textColor : root.mutedColor
                        font.family: root.inputFontFamily; valueFont.family: root.numberFontFamily
                        font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                    }
                    OperatorSlider {
                        id: ambienceSlider
                        width: parent.width; height: root.sliderHeight
                        label: "提示音音量"; unit: "%"; value: root.ambienceValue; enabled: root.localEditable
                        valueWidth: root.sliderValueWidth; labelHeight: root.sliderLabelHeight; trackY: root.sliderTrackY; trackHeight: root.sliderTrackHeight; handleSize: root.sliderHandleSize
                        labelColor: root.textColor; valueColor: enabled ? root.textColor : root.mutedColor
                        font.family: root.inputFontFamily; valueFont.family: root.numberFontFamily
                        font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                    }
                    OperatorText { width: parent.width; height: Math.max(root.audioNoteMinimumHeight, implicitHeight + root.noteBottomPadding); text: root.audioText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone }
                    OperatorButton { id: alertTestButton; width: parent.width; height: root.controlHeight; text: root.alertTestText; enabled: root.alertTestEnabled; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.buttonSize, 9.5 / Math.max(0.1, hudScale)) }
                    Rectangle { width: parent.width; height: root.separatorHeight; color: root.separatorColor }
                    OperatorText { width: parent.width; height: root.labelHeight; text: "显示模式"; size: root.statusSize; color: root.textColor; font.family: root.fontFamily }
                    OperatorSelect {
                        id: windowModeSelect
                        width: parent.width; height: root.controlHeight
                        label: "显示模式"
                        model: root.windowModeTitles; currentIndex: root.windowModeIndex
                        displayText: root.windowModeDisplayText; emptyText: root.windowModeDisplayText
                        enabled: root.localEditable
                        textColor: root.textColor; backgroundColor: root.selectSurfaceColor; borderColor: root.separatorColor
                        font.family: root.inputFontFamily; font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
                    }
                    OperatorText { width: parent.width; height: root.windowStatusHeight; text: root.actualWindowText; size: root.noteSize; color: root.mutedColor; font.family: root.fontFamily }
                    CheckBox {
                        id:reducedMotionToggle
                        objectName:"reduceMotionToggle"
                        width:parent.width
                        text:"减少动态效果（即时保存）"
                        checked:root.reducedMotion
                        palette.windowText:Theme.text;font.family:Theme.fontFamily
                    }
                    CheckBox {
                        id: startupAnimationToggle
                        objectName: "startupAnimationToggle"
                        width: parent.width
                        text: "启动时播放开场动画"
                        checked: root.startupAnimationEnabled
                        palette.windowText: root.textColor
                        font.family: root.fontFamily
                    }
                    OperatorButton {
                        id: replayStartupButton
                        objectName: "replayStartupSequence"
                        width: parent.width; height: root.controlHeight
                        text: "重播开场"
                        enabled: !root.reducedMotion
                    }
                    Flow {
                        id: sectionActions
                        width: parent.width; spacing: root.actionSpacing
                        property real buttonWidth: width >= root.sectionActionBreakpoint ? (width - root.actionSpacing) / 2 : width
                        OperatorButton { id: layoutButton; width: sectionActions.buttonWidth; height: root.controlHeight; text: "界面自定义"; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.buttonSize, 9.5 / Math.max(0.1, hudScale)) }
                        OperatorButton { id: shortcutsButton; width: sectionActions.buttonWidth; height: root.controlHeight; text: "快捷键"; textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.buttonSize, 9.5 / Math.max(0.1, hudScale)) }
                    }
                }
            }
        }
    }
    Item {
        id: footer
        objectName: "settingsFooter"
        y: parent.height - height
        width: parent.width
        height: Math.max(shortcutsLabel.y + shortcutsLabel.height, footerActions.y + footerActions.implicitHeight) + root.footerBottomPadding
        OperatorText {
            id: feedbackLabel
            width: parent.width
            height: Math.max(root.footerFeedbackHeight, implicitHeight + root.footerFeedbackPadding)
            text: root.feedbackText; size: root.noteSize
            color: root.feedbackWarning ? root.warningColor : root.mutedColor
            font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone
        }
        OperatorText {
            id: shortcutsLabel
            y: feedbackLabel.height + root.footerStatusGap
            width: root.width >= root.footerBreakpoint ? parent.width - footerActions.width - root.footerHintGap : parent.width
            height: Math.max(root.footerHintHeight, implicitHeight)
            text: root.shortcutText; size: root.noteSize; color: root.mutedColor
            font.family: root.fontFamily; wrapMode: Text.Wrap; elide: Text.ElideNone
        }
        Flow {
            id: footerActions
            x: parent.width - width
            y: root.width >= root.footerBreakpoint ? feedbackLabel.height : shortcutsLabel.y + shortcutsLabel.height + root.footerStatusGap
            width: root.width >= root.footerBreakpoint ? root.undoWidth + root.applyWidth + root.footerActionSpacing : parent.width
            spacing: root.footerActionSpacing
            OperatorButton {
                id: undoButton
                width: root.width >= root.footerBreakpoint ? root.undoWidth : footerActions.width >= root.footerActionBreakpoint ? (footerActions.width - root.footerActionSpacing) / 2 : footerActions.width
                height: root.controlHeight; text: "撤销本地修改"; enabled: root.undoEnabled
                textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.buttonSize, 9.5 / Math.max(0.1, hudScale))
            }
            OperatorButton {
                id: applyButton
                width: root.width >= root.footerBreakpoint ? root.applyWidth : footerActions.width >= root.footerActionBreakpoint ? (footerActions.width - root.footerActionSpacing) / 2 : footerActions.width
                height: root.controlHeight; text: root.applyText; primary: true; enabled: root.applyEnabled
                textColor: root.textColor; font.family: root.fontFamily; font.pixelSize: Math.max(root.buttonSize, 9.5 / Math.max(0.1, hudScale))
            }
        }
    }
}
