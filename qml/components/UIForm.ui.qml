import QtQuick
import QtQuick.Effects

Item {
    id: root
    implicitWidth: 1280
    implicitHeight: 720
    width: implicitWidth
    height: implicitHeight
    // 设计入口可见布局槽；UI.qml显式关闭，正式运行仍按数据有效性显隐。
    property bool designCanvas: true
    property TelemetryDefaults fallbackTelemetry: TelemetryDefaults {}
    property var telemetry: fallbackTelemetry
    property int clientID: 0
    property var videoSource: null
    property var inputState: null
    property int videoOrientation: 0
    property bool monochrome: false
    property var events: []
    property var robotEvents: []
    property int raceMessageViewRevision: 0
    property int robotMessageViewRevision: 0
    property bool robotMessageProducerConnected: false
    property var terminalAdviceRuntime: null
    property var terminalVoiceRuntime: null
    property bool terminalHudEnabled: false
    property bool terminalHudInteractionAllowed: true
    property real terminalAdviceWidth: 340
    property real terminalAdviceSideInset: 24
    property real terminalAdviceTop: 220
    property real terminalAdviceGap: Theme.hudGap
    property bool terminalAdviceRightSlot: terminalAdvice.settings.hud_position === "right"
        || dashboard.messagesObject.y - terminalAdvice.reservedHeight - root.terminalAdviceGap < root.terminalAdviceTop
    property alias dashboardObject: dashboard
    property alias videoObject: video
    property alias terminalAdviceHudObject: terminalAdvice
    property alias layoutScale: viewport.scale
    property alias stageObject: viewport

    Rectangle { anchors.fill: parent; color: Theme.background }
    UdpVideoDisplay {
        id: video
        anchors.fill: parent
        receiver: root.videoSource
        videoDisplay.rotation: root.videoOrientation === 1 ? 180 : 0
        layer.enabled: root.monochrome
        layer.effect: MultiEffect { saturation: -1.0 }
    }
    // 小窗口等比缩小以容纳HUD；正常尺寸以上保留控件逻辑尺寸。
    // 扩大窗口时画布向四边展开，上下HUD仍锚定边缘，新增空间留给图传。
    Item {
        id: viewport
        x: 0
        y: 0
        scale: root.width > 0 && root.height > 0 ? Math.min(1, root.width / 1600, root.height / 900) : 1
        transformOrigin: Item.TopLeft
        width: root.width / scale
        height: root.height / scale
        OperatorDashboard {
            id: dashboard
            anchors.fill: parent
            // Native Designer reference and retained 2026 advice placeholders
            // must not draw on top of one another in the same editing canvas.
            designCanvas: root.designCanvas && !root.terminalHudEnabled
            telemetry: root.telemetry
            clientID: root.clientID
            inputState: root.inputState
            events: root.events
            robotEvents: root.robotEvents
            raceMessageViewRevision: root.raceMessageViewRevision
            robotMessageViewRevision: root.robotMessageViewRevision
            robotMessagesAvailable: root.robotMessageProducerConnected
            waitingForVideo: !video.hasReceivedFrame
            layer.enabled: root.monochrome
            layer.effect: MultiEffect { saturation: -1.0 }
        }
        // Both HUD generations share this logical canvas and the existing
        // field-information slot. Visibility never participates in layout.
        OperatorTerminalAdviceHud {
            id: terminalAdvice
            objectName: "terminalAdviceHud"
            z: 2
            width: root.terminalAdviceWidth
            x: root.terminalAdviceRightSlot ? parent.width - width - root.terminalAdviceSideInset : root.terminalAdviceSideInset
            y: root.terminalAdviceRightSlot ? root.terminalAdviceTop : dashboard.messagesObject.y - height - root.terminalAdviceGap
            runtime: root.terminalAdviceRuntime
            voiceRuntime: root.terminalVoiceRuntime
            hudScale: viewport.scale
            designPlaceholder: root.designCanvas && root.terminalHudEnabled
            enabled: root.terminalHudInteractionAllowed && displayable && !placeholderActive
            visible: root.terminalHudEnabled && (placeholderActive || displayable)
        }
    }
}
