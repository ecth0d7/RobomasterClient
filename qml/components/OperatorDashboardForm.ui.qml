import QtQuick 6.5

Item {
    id: root
    implicitWidth: 1600
    implicitHeight: 900
    width: implicitWidth
    height: implicitHeight
    property var telemetry: null
    property var hudVisibility: ({})
    property string economyText: "—"
    property int clientID: 3
    property bool designCanvas: true
    property var events: []
    property var robotEvents: []
    property int raceMessageViewRevision: 0
    property int robotMessageViewRevision: 0
    property bool raceMessagesAvailable: connectedToPlayer || previewOnly
    property bool robotMessagesAvailable: false
    property var inputState: null
    property string inputCaptureFeedback: ""
    signal mouseCaptureRequested(bool captured)
    property bool waitingForVideo: true
    property bool leftPanelOpen: false
    property bool bottomPanelOpen: false
    property var decisionServices: null
    property var decisionPreferences: null
    property bool connectedToPlayer: false
    property bool previewOnly: false
    property bool interactionAllowed: true
    property bool panelShortcutsAvailable: false
    property string exchangeShortcut: "H"
    property string airEndShortcut: "N"
    // 使用可绑定的布局属性，让Designer也能在预览尺寸变化后重新求值。
    property bool adviceInRightSlot: root.decisionPreferences?.current?.advicePosition === "right"
        || root.leftPanelOpen || messages.y - adviceHud.reservedHeight - Theme.hudGap < 220
    property var discoveryDisplayView: ({active:[],markers:[],history:[]})
    property var discoveryMarkers: []
    property var fusionView: ({})
    property var headingItems: []
    property var runeMapItems: []
    property alias mapFeedbackObject:mapFeedbackNotice
    property string mapFeedback:""
    property var buffRecords: []
    property var ownStatusItems: []
    property string ownStatusSessionId: ""
    property bool combatCountdownSecondsVerified: false
    property var airDisplayData: null
    property bool airDisplayProjectionConnected: false
    property string airDisplaySessionId: ""
    property bool airSupportSecondsVerified: false
    property bool airSupportEndShortcutAvailable: false
    property var bottomStatusView: null
    property bool bottomStatusProjectionConnected: false
    property string bottomStatusSessionId: ""
    property bool bottomStatusDetailVisible: false
    property var outpostRebuildItems: []
    property var outpostDefenseItems: []
    property var baseDefenseItems: []
    property var rosterProjectionItems: []
    property var fortressProgressScale: null
    property alias buffHudObject: buffHud
    property alias discoveriesHudObject: discoveriesHud
    property alias adviceHudObject: adviceHud
    property alias exchangeHitArea: exchangeHit
    property alias mapObject: fieldMap
    property alias vitalsObject: vitals
    property alias modulesObject: modules
    property alias keyMonitorObject: keyMonitor
    property alias messagesObject: messages
    readonly property real shootingReadingsLeft: reticle.x + reticle.shootingReadingsObject.x
    property alias shootingReadingsObject: reticle.shootingReadingsObject

    Rectangle {
        anchors.fill: parent
        visible: root.designCanvas
        color: Theme.background
    }
    Item {
        id: topHud
        property real teamWidth: 600
        objectName: "topHudGroup"
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, 1600)
        height: 180
        OperatorScoreboard {
            id: scoreboard
            objectName: "scoreboard"
            visible: root.hudVisibility.scoreboard !== false
            x: 24
            y: 3
            width: parent.width - 48
            teamSpan: topHud.teamWidth
            telemetry: root.telemetry
            clientID: root.clientID
            previewOnly: root.previewOnly
            connectedToPlayer: root.connectedToPlayer
            outpostRebuildItems: root.outpostRebuildItems
            outpostDefenseItems: root.outpostDefenseItems
            baseDefenseItems: root.baseDefenseItems
        }
        OperatorRoster {
            id: redRoster
            objectName: "redRoster"
            previewOnly: root.previewOnly
            projectionItems: root.rosterProjectionItems
            visible: root.hudVisibility.redRoster !== false
            x: 24
            y: 90
            width: topHud.teamWidth
            telemetry: root.telemetry
            clientID: root.clientID
        }
        OperatorRoster {
            id: blueRoster
            objectName: "blueRoster"
            previewOnly: root.previewOnly
            projectionItems: root.rosterProjectionItems
            visible: root.hudVisibility.blueRoster !== false
            x: parent.width - width - 24
            y: 90
            width: topHud.teamWidth
            blue: true
            telemetry: root.telemetry
            clientID: root.clientID
        }
        OperatorEconomy {
            id: economy
            objectName: "economyGroup"
            visible: root.designCanvas || root.hudVisibility.economy !== false && economy.displayable
            anchors.horizontalCenter: parent.horizontalCenter
            y: 95
            width: 330
            height: 58
            economyText: root.economyText
            telemetry: root.telemetry
            clientID: root.clientID
            previewOnly: root.previewOnly
            progressScale: root.fortressProgressScale
        }
    }
    OperatorAdviceHud {
        id: adviceHud
        // 左侧操作卡或小视口没有足够高度时用固定右上槽，位置不依赖建议显隐。
        // 始终只锚定上边与左边，Designer与运行端共用几何，不以相反边锚点拉伸卡片。
        anchors.left: parent.left
        anchors.leftMargin: root.adviceInRightSlot ? parent.width - width - 24 : 24
        anchors.top: root.adviceInRightSlot ? parent.top : messages.top
        anchors.topMargin: root.adviceInRightSlot ? 220 : -height - Theme.hudGap
        visible: root.designCanvas || root.hudVisibility.advice !== false && adviceHud.displayable
        designPlaceholder: root.designCanvas
        services: root.decisionServices
        preferences: root.decisionPreferences
        connected: root.connectedToPlayer
        previewOnly: root.previewOnly
    }
    OperatorDiscoveriesHud {
        id: discoveriesHud
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.top: messages.top
        anchors.topMargin: 120
        visible: root.designCanvas || !root.leftPanelOpen && root.hudVisibility.discoveries !== false && discoveriesHud.visibleItems.length > 0
        designPlaceholder: root.designCanvas
        displayView: root.discoveryDisplayView
        previewOnly: root.previewOnly
    }
    OperatorReticle {
        id: reticle
        objectName: "operatorReticle"
        clientID: root.clientID
        connectedToPlayer: root.connectedToPlayer
        previewOnly: root.previewOnly
        projectionItems: root.rosterProjectionItems
        topExclusionHeight: 400
        rightDockLeft: fieldMap.x
        rightDockTop: fieldMap.y
        visible: root.hudVisibility.reticle !== false
        anchors.centerIn: parent
        telemetry: root.telemetry
    }
    OperatorMessages {
        id: messages
        objectName: "messagesGroup"
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.bottom: vitals.top
        anchors.bottomMargin: 12
        events: root.events
        robotEvents: root.robotEvents
        raceSourceAvailable: root.raceMessagesAvailable
        robotSourceAvailable: root.robotMessagesAvailable
        clientID: root.clientID
        raceViewRevision: root.raceMessageViewRevision
        robotViewRevision: root.robotMessageViewRevision
        previewOnly: root.previewOnly
        designPlaceholder: root.designCanvas
        raceMessagesVisible: root.hudVisibility.raceMessages!==false
        robotMessagesVisible: !discoveriesHud.visible && root.hudVisibility.robotMessages!==false
        visible: root.designCanvas || !root.leftPanelOpen && root.hudVisibility.messages !== false && messages.displayable
    }
    OperatorVitals {
        id: vitals
        objectName: "ownVitals"
        visible: root.hudVisibility.vitals !== false
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.bottom: modules.top
        anchors.bottomMargin: 12
        telemetry: root.telemetry
        clientID: root.clientID
        projectionItems: root.rosterProjectionItems
        previewOnly: root.previewOnly
        connectedToPlayer: root.connectedToPlayer
        ownStatusItems: root.ownStatusItems
        ownStatusSessionId: root.ownStatusSessionId
        combatCountdownSecondsVerified: root.combatCountdownSecondsVerified
        airDisplayData: root.airDisplayData
        airDisplayProjectionConnected: root.airDisplayProjectionConnected
        airDisplaySessionId: root.airDisplaySessionId
        showCombatState: root.hudVisibility.combatState !== false
        showPenaltyBadge: root.hudVisibility.penaltyBadge !== false
        showStateHints: root.hudVisibility.ownEffects !== false
    }
    OperatorBuffHud {
        id: buffHud
        objectName: "buffHud"
        // 手册印刷页07：圆形增益落在血板／空中弹量正上方；不推挤相邻HUD。
        // 空中读数更高，圆环在消息区右侧预留槽，避免小窗口时向上长入消息。
        anchors.left: vitals.left
        anchors.leftMargin: vitals.aerial ? messages.width + Theme.hudGap : vitals.portraitRight + 8
        anchors.bottom: vitals.top
        anchors.bottomMargin: 8 - (vitals.aerial ? vitals.airReadoutTop : vitals.healthTop)
        records: root.buffRecords
        designPlaceholder: root.designCanvas
        visible: root.designCanvas || !root.bottomPanelOpen && root.hudVisibility.buffs !== false && buffHud.displayable
    }
    OperatorModules {
        id: modules
        visible: root.hudVisibility.modules !== false && displayable
        anchors.left: parent.left
        anchors.leftMargin: 30
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        telemetry: root.telemetry
        clientID: root.clientID
        connectedToPlayer: root.connectedToPlayer
        previewOnly: root.previewOnly
        displayData: root.bottomStatusView
        displayProjectionConnected: root.bottomStatusProjectionConnected
        displaySessionId: root.bottomStatusSessionId
        detailVisible: root.bottomStatusDetailVisible
    }
    OperatorMap {
        id: fieldMap
        feedback:root.mapFeedback
        discoveryMarkers: root.discoveryMarkers
        fusionView:root.fusionView
        headingItems: root.headingItems
        runeMapItems:root.runeMapItems
        projectionItems: root.rosterProjectionItems
        previewOnly: root.previewOnly
        visible: root.hudVisibility.map !== false
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.bottom: keyMonitor.top
        anchors.bottomMargin: 8
        telemetry: root.telemetry
        clientID: root.clientID
    }
    OperatorText {
        id:mapFeedbackNotice
        objectName:"mapTransientFeedback"
        anchors.left:fieldMap.left
        anchors.bottom:fieldMap.top
        anchors.bottomMargin:6
        width:fieldMap.width
        height:24
        visible:fieldMap.visible && root.mapFeedback.length>0
        text:root.mapFeedback.startsWith("已提交") ? "地图标记已提交" : root.mapFeedback.includes("操作过快") ? "地图标记 · 操作过快" : "地图标记未发送"
        Accessible.role:Accessible.StaticText
        Accessible.name:root.mapFeedback
        size:11
        color:root.mapFeedback.startsWith("已提交") ? Theme.green : Theme.warning
    }
    OperatorKeyMonitor {
        id: keyMonitor
        objectName: "keyMouseMonitor"
        visible: root.hudVisibility.keys !== false && (root.designCanvas || keyMonitor.displayable)
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        inputState: root.inputState
        previewOnly: root.previewOnly
        interactionAllowed: root.interactionAllowed
        captureFeedback: root.inputCaptureFeedback
    }
    OperatorText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 + 55
        width: 330
        height: 22
        visible: !root.bottomPanelOpen && root.hudVisibility.videoStatus !== false
        text: root.waitingForVideo ? "等待图传画面" : ""
        horizontalAlignment: Text.AlignHCenter
        size: 12
        color: Theme.muted
    }
    OperatorExchangeHint {
        id: exchangeHit
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height - 24
        visible: exchangeHit.roleSupported && !root.bottomPanelOpen && root.hudVisibility.exchangeHint !== false
        clientID: root.clientID
        shortcutsAvailable: root.previewOnly || root.panelShortcutsAvailable
        shortcutLabel: root.exchangeShortcut
        endShortcutLabel: root.airEndShortcut
        telemetry: root.telemetry
        connectedToPlayer: root.connectedToPlayer
        airSupportSecondsVerified: root.airSupportSecondsVerified
        previewOnly: root.previewOnly
        endShortcutAvailable: root.airSupportEndShortcutAvailable
        enabled: root.interactionAllowed && exchangeHit.actionAvailable
    }
}
