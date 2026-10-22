import QtQuick
import QtQuick.Window
import "UiFormat.js" as Format

// Local preferences and historical-2026 identity/performance references remain
// separate. Only explicit user intents leave this wrapper; drawing is in the Form.
OperatorPanelFrame {
    id: root
    property int clientID: 0
    property var telemetry: null
    property bool previewOnly: false
    property bool connecting: false
    property bool connected: false
    property bool localApplyAvailable: false
    property bool sensitivityAvailable: false
    property string audioStatus: "音频状态未提供"
    property bool audioPlaybackAvailable: false
    property bool performanceAvailable: false
    property var performanceControls: ({})
    property string connectionStatus: "未连接"
    property string settingsFeedback: ""
    property string performanceFeedback: ""
    property var appliedSettings: ({orientation: 0, sensitivity: 100, volume: 80, ambience: 50, windowMode: 0})
    property alias formControl: settingsForm
    readonly property int actualWindowMode: Window.window?.visibility === Window.FullScreen ? 2 : Window.window?.visibility === Window.Maximized ? 1 : 0
    onActualWindowModeChanged: if (visible) settingsForm.windowModeControl.currentIndex = actualWindowMode
    property int selectedIdentity: clientID
    readonly property var identityIDs: Format.loginIds()
    readonly property bool currentIdentity: !previewOnly && connected && selectedIdentity === clientID
    readonly property bool localDirty: settingsForm.orientationControl.currentIndex !== appliedSettings.orientation
        || settingsForm.sensitivityControl.value !== appliedSettings.sensitivity
        || settingsForm.volumeControl.value !== appliedSettings.volume
        || settingsForm.ambienceControl.value !== appliedSettings.ambience
        || settingsForm.windowModeControl.currentIndex !== actualWindowMode
    onClientIDChanged: selectedIdentity = clientID
    onVisibleChanged: if (visible) { selectedIdentity = clientID; resetDraft(); clearPerformanceSelection(); forceActiveFocus(); }
    signal loginIntent(int robotID)
    signal settingsIntent(var values)
    signal performanceIntent(var fields)
    signal servicesRequested
    signal layoutRequested
    signal startupPreviewRequested
    signal startupRequested
    signal shortcutsRequested
    signal controlSetupRequested
    signal alertTestIntent
    title: settingsForm.panelTitle
    iconAsset: settingsForm.panelIconAsset
    accent: settingsForm.textColor
    backgroundSource: settingsForm.panelBackgroundSource
    width: settingsForm.panelWidth
    height: settingsForm.panelHeight
    contentMargin: settingsForm.panelContentMargin
    bodyTop: settingsForm.panelBodyTop

    function resetDraft() {
        settingsForm.orientationControl.currentIndex = appliedSettings.orientation;
        settingsForm.sensitivityControl.value = appliedSettings.sensitivity;
        settingsForm.volumeControl.value = appliedSettings.volume;
        settingsForm.ambienceControl.value = appliedSettings.ambience;
        settingsForm.windowModeControl.currentIndex = actualWindowMode;
    }
    function draftValues() {
        return {orientation: settingsForm.orientationControl.currentIndex,
            sensitivity: settingsForm.sensitivityControl.value,
            volume: settingsForm.volumeControl.value,
            ambience: settingsForm.ambienceControl.value,
            windowMode: settingsForm.windowModeControl.currentIndex};
    }
    function clearPerformanceSelection() {
        const selector = settingsForm.performanceRepeater.itemAt(0);
        if (selector) selector.clearSelection();
    }
    function login() {
        if (connecting || !Format.validLogin(selectedIdentity)) return;
        if (currentIdentity) closeRequested(); else loginIntent(selectedIdentity);
    }
    function applyLocal() { if (localApplyAvailable && localDirty) settingsIntent(draftValues()); }
    // The old ComboBoxes initialized from their first option. Initialize from the
    // actual local baseline instead; standalone opening must not invent a dirty draft.
    Component.onCompleted: resetDraft()

    OperatorSettingsForm {
        id: settingsForm
        anchors.fill: parent
        drawingBackgroundVisible: false
        showStartupDraft: root.previewOnly
        reducedMotion:Theme.reducedMotion
        startupAnimationEnabled: Theme.startupAnimationEnabled
        headingText: root.previewOnly ? "设置预览" : ""
        headingNote: ""
        currentIdentityText: root.clientID ? (root.clientID > 100 ? "蓝方 · " : "红方 · ") + Format.role(root.clientID) + " · " + root.clientID : "尚未选择"
        currentIdentityColor: root.clientID > 100 ? blueColor : root.clientID > 0 ? redColor : mutedColor
        connectionText: root.connectionStatus
        identityTitles: root.identityIDs.map(id => (id > 100 ? "蓝方 · " : "红方 · ") + Format.role(id) + " · " + id)
        identityIndex: root.identityIDs.indexOf(root.selectedIdentity)
        identityDisplayText: identityIndex >= 0 ? identityTitles[identityIndex] : "尚未选择身份"
        identityEditable: !root.connecting
        loginText: root.connecting ? "正在连接 · 请等待" : root.currentIdentity ? "返回当前客户端" : root.previewOnly ? "查看所选机器人 · 预览" : "登录所选机器人"
        loginEnabled: !root.connecting && Format.validLogin(root.selectedIdentity)
        identityNote: root.previewOnly ? "预览身份，不建立连接。" : "切换机器人后建立新会话，重新接收该机器人的数据。"
        localEditable: root.localApplyAvailable
        sensitivityEditable: root.localApplyAvailable && root.sensitivityAvailable
        orientationTitles: ["正向", "旋转 180°"]
        orientationDisplayText: orientationControl.currentIndex >= 0 && orientationControl.currentIndex < orientationTitles.length
            ? orientationTitles[orientationControl.currentIndex] : "尚未提供图像方向"
        orientationNote: "只旋转视频画面，界面保持正向。"
        sensitivityNote: !root.sensitivityAvailable ? "当前输入插件不支持调整。" : "100%保持原始移动量，不改系统鼠标速度。"
        audioText: root.audioStatus
        alertTestText: root.previewOnly ? "记录提示音试听 · 预览" : "试听本机提示音"
        alertTestEnabled: root.previewOnly || root.audioPlaybackAvailable
        windowModeTitles: ["普通窗口", "最大化", "全屏"]
        windowModeDisplayText: windowModeControl.currentIndex >= 0 && windowModeControl.currentIndex < windowModeTitles.length
            ? windowModeTitles[windowModeControl.currentIndex] : "尚未提供显示模式"
        actualWindowText: "实际窗口：" + windowModeTitles[root.actualWindowMode]
        feedbackText: root.localDirty ? "有未应用的修改" : root.settingsFeedback || "本地偏好自动保存；性能选择需单独提交。"
        feedbackWarning: root.localDirty
        shortcutText: root.shortcutLabel("settings") + " · 关闭设置    Esc · 返回    F11 · 全屏"
        applyText: root.previewOnly ? "应用窗口演示设置" : "应用本地设置"
        undoEnabled: root.localDirty
        applyEnabled: root.localApplyAvailable && root.localDirty
        performanceCount: 1
        performanceDelegate: Component {
            OperatorPerformanceSelector {
                width: settingsForm.performanceDelegateWidth
                height: settingsForm.performanceDelegateHeight
                clientID: root.clientID
                telemetry: root.telemetry
                previewOnly: root.previewOnly
                submissionAvailable: root.performanceAvailable
                controls: root.performanceControls
                feedback: root.performanceFeedback
                formControl.compact: true
                formControl.sectionBodyTop: settingsForm.sectionBodyTop
                formControl.sectionContentMargin: settingsForm.sectionContentMargin
                formControl.sectionTitleTop: settingsForm.sectionTitleTop
                formControl.sectionTitleHeight: settingsForm.sectionTitleHeight
                formControl.sectionTitleSize: settingsForm.sectionTitleSize
                formControl.entrySpacing: settingsForm.entrySpacing
                formControl.controlHeight: settingsForm.controlHeight
                formControl.scrollContentInset: settingsForm.scrollContentInset
                formControl.scrollBarWidth: settingsForm.scrollBarWidth
                formControl.scrollThumbWidth: settingsForm.scrollThumbWidth
                formControl.scrollRadius: settingsForm.scrollRadius
                formControl.fontFamily: settingsForm.fontFamily
                formControl.inputFontFamily: settingsForm.inputFontFamily
                formControl.noteSize: settingsForm.noteSize
                formControl.readingSize: settingsForm.statusSize
                formControl.inputSize: settingsForm.inputSize
                formControl.buttonSize: settingsForm.buttonSize
                formControl.surfaceColor: settingsForm.surfaceColor
                formControl.textColor: settingsForm.textColor
                formControl.mutedColor: settingsForm.mutedColor
                formControl.warningColor: settingsForm.warningColor
                formControl.separatorColor: settingsForm.separatorColor
                formControl.selectSurfaceColor: settingsForm.selectSurfaceColor
                formControl.scrollTrackColor: settingsForm.scrollTrackColor
                onSelectionIntent: fields => root.performanceIntent(fields)
            }
        }
    }
    Connections {
        target: settingsForm.identityControl
        function onActivated(index) {
            if (index >= 0 && index < root.identityIDs.length) root.selectedIdentity = root.identityIDs[index];
        }
    }
    Connections { target: settingsForm.loginControl; function onClicked() { root.login(); } }
    Connections { target: settingsForm.startupControl; function onClicked() { root.startupRequested(); } }
    Connections { target: settingsForm.controlSetupControl; function onClicked() { root.controlSetupRequested(); } }
    Connections { target: settingsForm.servicesControl; function onClicked() { root.servicesRequested(); } }
    Connections { target: settingsForm.alertTestControl; function onClicked() { root.alertTestIntent(); } }
    Connections { target: settingsForm.layoutControl; function onClicked() { root.layoutRequested(); } }
    Connections { target: settingsForm.shortcutsControl; function onClicked() { root.shortcutsRequested(); } }
    Connections { target: settingsForm.undoControl; function onClicked() { root.resetDraft(); } }
    Connections { target: settingsForm.startupAnimationControl; function onToggled() { Theme.setStartupAnimationEnabled(settingsForm.startupAnimationControl.checked); } }
    Connections { target: settingsForm.replayStartupControl; function onClicked() { root.startupPreviewRequested(); } }
    Connections { target: settingsForm.reducedMotionControl; function onToggled() { Theme.setReducedMotion(settingsForm.reducedMotionControl.checked); } }
    Connections { target: settingsForm.applyControl; function onClicked() { root.applyLocal(); } }
}
