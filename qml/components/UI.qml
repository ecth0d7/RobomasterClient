import QtQuick
import QtQuick.Window
import "EventFormat.js" as EventFormat
import "UiFormat.js" as Format
import "OperatorDecisionPolicy.js" as DecisionPolicy
import "OperatorTeamAggregationData.js" as Team
import "OperatorBuffData.js" as Buff
import "OperatorMessageData.js" as Messages
import "OperatorData.js" as Data
import "OperatorDiscoveryData.js" as Discovery

UIForm {
    id: root
    designCanvas: false
    videoObject.overlayExclusions: {
        // Source rectangles use the actual HUD geometry, including responsive scaling and letterboxing.
        const scale = root.layoutScale;
        const widthDependency = root.width, heightDependency = root.height;
        const dashboard = root.dashboardObject;
        if (!dashboard.visible) return [];
        const top = dashboard.children.find(o => o.objectName === "topHudGroup");
        const items = [top, dashboard.mapObject, dashboard.vitalsObject, dashboard.modulesObject,
                       dashboard.messagesObject, dashboard.keyMonitorObject, dashboard.shootingReadingsObject];
        return items.filter(o => o && o.visible).map(o => {
            const xDependency = o.x, yDependency = o.y;
            const point = o.mapToItem(root.videoObject, 0, 0);
            return {x:point.x-4, y:point.y-4, w:o.width*scale+8, h:o.height*scale+8};
        });
    }
    monochrome: matchOverlay.dead && !engineerPanel.temporaryActive
    property bool loginOpen: false
    property bool layoutOpen: false
    property bool extensionPanelOpen: false
    property string extensionPanelFeedback: ""
    property bool startupOpen: false
    property bool teamConfigOpen: false
    property bool sourceConfigOpen: false
    property bool providerOpen: false
    property bool seasonOpen: false
    property bool previewOnly: false
    // 画面可临时切到吊射等来源，连接页仍配置普通 UDP 接收器。
    property var primaryVideoState: null
    // 新来源／队伍renderer生产端尚未接通；各通道独立缺省关闭，不依赖旧bridge或MQTT peers。
    property var localDiscoveryView: null
    property var teamDiscoveryView: null
    property bool localDiscoveryProjectionConnected: false
    property bool teamDiscoveryProjectionConnected: false
    property var discoveryContext: null
    property double discoveryNow: Date.now()
    readonly property var discoveryDisplayView: Discovery.project(localDiscoveryView,teamDiscoveryView,
        localDiscoveryProjectionConnected,teamDiscoveryProjectionConnected,discoveryContext,clientID,discoveryNow,
        previewOnly,connectionState?.connected === true)
    function refreshDiscoveryClock() { discoveryNow=Math.max(discoveryNow,Date.now()); }
    onLocalDiscoveryViewChanged: Qt.callLater(root.refreshDiscoveryClock)
    onTeamDiscoveryViewChanged: Qt.callLater(root.refreshDiscoveryClock)
    Timer {
        interval:250;repeat:true;running:root.visible && (root.localDiscoveryView !== null || root.teamDiscoveryView !== null)
        onTriggered:root.refreshDiscoveryClock()
    }
    property var mapHeadingItems: []
    property var runeMapItems: []
    property var outpostRebuildItems: []
    property var outpostDefenseItems: []
    property var baseDefenseItems: []
    property bool outpostDefenseConnected: false
    property var rosterProjectionItems: []
    property bool rosterProjectionConnected: false
    property var dartDisplayProjection: null
    property var sentrySupportProjection:null
    property bool sentryLocalBusy:false
    readonly property bool sentrySupportConfigured:controlState?.uiCapabilities?.sentrySupportConfigured===true
    property var ownStatusItems: []
    property bool ownStatusProjectionConnected: false
    property string ownStatusSessionId: ""
    property bool combatCountdownSecondsVerified: false
    property var airDisplayData: null
    property bool airDisplayProjectionConnected: false
    property string airDisplaySessionId: ""
    // left_time的秒单位由实际适配器核对后显式声明，不能用previewOnly补生产能力。
    property bool airSupportSecondsVerified: false
    property var bottomStatusView: null
    property bool bottomStatusProjectionConnected: false
    property string bottomStatusSessionId: ""
    property int airSupportContextRevision: 0
    readonly property bool playerConnected: connectionState?.connected === true
    onPlayerConnectedChanged: airSupportContextRevision += 1
    property var fortressProgressScale: null
    property bool fortressScaleConnected: false
    property var buffProjectionItems: []
    property bool buffProjectionConnected: false
    property var localBuffProjection:null
    readonly property var localBuffRecords:Buff.localCollection(localBuffProjection,telemetry,clientID,buffNow,playerConnected)
    property bool buffsOpen: false
    property alias buffPanelObject:buffPanel
    property double buffNow: Date.now()
    readonly property var nativeBuffRecords: {
        const b = telemetry?.buff;
        if (!b || !b.buff_type || b.buff_level === undefined || b.buff_level === 0) return [];
        if (b.robot_id && b.robot_id !== clientID && b.robot_id !== 0) return [];
        const bType = Number(b.buff_type);
        if (bType < 1 || bType > 7) return [];
        if(!root.previewOnly && !Buff.nativeContextReady(root.telemetry,clientID))return [];
        const slotKey = bType + (bType === 2 && b.buff_level < 0 ? "-" : "+");
        const maxTime = b.buff_max_time;
        const leftTime = b.buff_left_time;
        const fresh = root.playerConnected && ["buff_type", "buff_level", "buff_max_time", "buff_left_time"]
            .every(key => Data.state(root.telemetry, "buff", key) === "fresh");
        const pairValid = Number.isInteger(maxTime) && Number.isInteger(leftTime)
            && maxTime > 0 && leftTime >= 0 && leftTime <= maxTime;
        return [{
            slot_key: slotKey,
            robot_id: clientID,
            buff_type: bType,
            buff_level: Number(b.buff_level),
            buff_max_time: maxTime,
            buff_left_time: leftTime,
            raw_buff_left_time: leftTime,
            raw_buff_max_time: maxTime,
            time_pair_valid: pairValid,
            time_conflict: Number.isInteger(leftTime) && Number.isInteger(maxTime) && leftTime > maxTime,
            time_unit: "s",
            clock_verified: true,
            state: fresh ? "fresh" : "stale",
            lifecycle: leftTime === 0 || b.buff_level === 0 ? "ended" : "active",
            source_kind: "mqtt",
            source_id: "Buff",
            snapshot_id: "协议未提供源快照",
            field_states: {
                buff_type: Data.state(root.telemetry,"buff","buff_type"),
                buff_level: Data.state(root.telemetry,"buff","buff_level"),
                buff_max_time: Data.state(root.telemetry,"buff","buff_max_time"),
                buff_left_time: Data.state(root.telemetry,"buff","buff_left_time")
            }
        }];
    }
    readonly property var buffRecords: (buffProjectionConnected || (previewOnly && Array.isArray(buffProjectionItems) && buffProjectionItems.length > 0))
        ? Buff.project(buffProjectionItems, clientID, buffNow, previewOnly) : localBuffRecords??nativeBuffRecords
    readonly property int buffExcludedCount: (buffProjectionConnected || previewOnly) && Array.isArray(buffProjectionItems)
        ? Math.max(0, buffProjectionItems.length - buffRecords.length) : 0
    Timer { interval: 500; repeat: true; running: root.visible && (root.localBuffProjection!==null || Array.isArray(root.buffProjectionItems) && root.buffProjectionItems.length > 0 || nativeBuffRecords.length > 0); onTriggered: root.buffNow = Date.now() }
    onLocalBuffProjectionChanged:buffNow=Date.now()
    onBuffProjectionItemsChanged: buffNow = Date.now()
    onVisibleChanged: if (visible) buffNow = Date.now()
    property alias layoutStateObject: hudLayoutState
    property alias layoutPanelObject: layoutEditor
    property alias extensionPanelObject: extensionPanelHost
    property alias startupPanelObject: startupPanelLoader.item
    property alias startupPreferencesObject: startupPreferences
    property alias teamConfigPanelObject: teamConfigPanel
    property alias teamConfigPreferencesObject: teamConfigPreferences
    property alias sourcePanelObject: sourcePanel
    property alias sourcePreferencesObject: sourcePreferences
    property alias providerPanelObject: providerPanel
    property alias providerPreferencesObject: providerPreferences
    property alias settingsPanelObject: settingsPanel
    property alias sentryPanelObject: sentryPanel
    property alias heroPanelObject: heroPanel
    property alias exchangePanelObject: exchangePanel
    property alias damagePanelObject: damagePanel
    property alias helpPanelObject: helpPanel
    property alias shortcutPreferencesObject: shortcutPreferences
    property alias statusPanelObject: statusPanel
    property bool globalPanelShortcutsAvailable: false
    property bool commonCommandOpen: false
    property bool injuryOpen: false
    property bool robotStatusOpen: false
    property bool helpOpen: false
    property bool servicesOpen: false
    property bool decisionOpen: false
    property bool decisionInspectorOpen: false
    property bool speechOpen: false
    property bool bridgeOpen: false
    property bool aggregationOpen: false
    property bool roleOpen: false
    property bool tuningOpen: false
    property bool detailsOpen: false
    property bool customDataOpen: false
    property bool mapMarkOpen: false
    property string smallMapFeedback:""
    property bool mqttConnected: false
    property bool mqttConnecting: false
    property string mqttStatusMessage: "未连接"
    property var connectionState: null
    property var servicesState: null
    property var viewController: null
    property string referenceFeedback: ""
    readonly property var seasonRuntime: servicesState?.seasonConfiguration ?? null
    readonly property bool nextSeason: seasonRuntime?.current?.season === 2027
    // 展示26版HUD不改变原生规则、协议或命令权限。功能工作台不注入预览数据。
    property bool retainedHudWorkspace: false
    readonly property bool terminalPresentation: nextSeason && !retainedHudWorkspace
    property alias seasonPanelObject: seasonPanel
    readonly property var controlState: servicesState?.operatorActions ?? servicesState
    readonly property bool captureDesired: inputState?.captureDesired === true || inputState?.mouseCaptureEnabled === true
    property var diagnosticVideoState: null
    property var operatorSettings: ({orientation: 0, sensitivity: 100, volume: 80, ambience: 50, windowMode: 0})
    property var localSettingsState: null
    videoOrientation: operatorSettings.orientation ?? 0
    property string settingsFeedback: ""
    property string inputCaptureFeedback: ""
    signal mouseCaptureRequested(bool captured)
    property string performanceFeedback: ""
    onClientIDChanged: {
        smallMapFeedback="";
        airSupportContextRevision += 1;
        performanceFeedback="";
        if(!previewOnly)resetTransientState();
    }
    onMqttConnectedChanged: if(!previewOnly)resetRaceNotifications()
    property int eventSerial: 0
    property var lastNotificationRound: null
    property var lastPenaltyNotice:null
    readonly property var notificationRound: mqttConnected
        && Data.state(telemetry,"gameStatus","current_round")==="fresh"
        && Number.isSafeInteger(telemetry?.gameStatus?.current_round) && telemetry.gameStatus.current_round>0
        ? telemetry.gameStatus.current_round : null
    onNotificationRoundChanged: {airSupportContextRevision+=1;if(!previewOnly)syncNotificationRound();}
    property string roleSection: "role"
    readonly property string resolvedRoleSection: roleSection === "role" ? Format.roleSection(clientID) : roleSection
    readonly property bool matchStateBlocksInput: matchOverlay.dead && !engineerPanel.temporaryActive || matchOverlay.ended || matchOverlay.paused
    property alias resultOverlayObject:matchOverlay.resultObject
    readonly property bool resultPresentationVisible:matchOverlay.resultObject.presentationVisible
    readonly property bool modalActive: seasonOpen || loginOpen || startupOpen || teamConfigOpen || sourceConfigOpen || providerOpen || commonCommandOpen || injuryOpen || buffsOpen
                                        || robotStatusOpen || helpOpen || servicesOpen || decisionOpen || decisionInspectorOpen || speechOpen || bridgeOpen || aggregationOpen
                                        || roleOpen && !["hero","rune"].includes(resolvedRoleSection) || tuningOpen || detailsOpen || customDataOpen || mapMarkOpen || layoutOpen || extensionPanelOpen
    signal commandRequested(string topic, var fields)
    signal sentryLocalRequested(var fields)
    signal protocolCommandRequested(string topic, var fields)
    signal loginRequested(int robotId)
    signal connectionLoginRequested(int robotId, string host, int port)
    signal connectionSessionRequested(var options)
    signal disconnectRequested
    signal videoConfigureRequested(var options)
    signal videoRestartRequested
    signal videoStopRequested
    signal startupPreviewRequested
    signal loadStartupProfileRequested
    signal saveStartupProfileRequested(var connectionOptions, string purpose)
    signal inspectTeamCertificateRequested(string file)
    signal inspectSourceAdapterRequested(string id)
    signal inspectModelProviderRequested(var configuration)
    signal localSettingsRequested(var values)
    signal localAlertTestRequested
    signal performanceRequested(var fields)
    signal assemblyContextRequested(int difficulty)
    signal mapMarkRequested(var fields)
    signal customByteRequested(var fields)
    signal panelRequested(string panel)
    signal commonCommandClosed
    signal decisionRequested(string question)
    signal cancelDecisionRequested
    signal narrationRequested(string text, string priority, string key)
    signal testSpeechRequested
    signal stopSpeechRequested
    signal speakAdviceRequested
    signal speakInputFactsRequested
    property alias protocolPanelObject: protocolPanel
    property alias mapPanelObject: mapPanel
    property alias bytePanelObject: bytePanel
    property alias servicesPanelObject: servicesPanel
    property alias decisionPanelObject: decisionPanel
    property alias decisionInspectorObject: decisionInspector
    property alias decisionPreferencesObject: decisionPreferences
    property alias speechPanelObject: speechPanel
    property alias bridgePanelObject: bridgePanel
    property alias aggregationPanelObject: aggregationPanel
    property alias dartPanelObject: dartPanel
    property alias runePanelObject: runePanel
    property alias eventOverlayObject:eventOverlay
    property alias sentryRfidObject:sentryRfid
    property alias engineerPanelObject: engineerPanel
    property alias airPanelObject: airPanel
    dashboardObject.exchangeShortcut: shortcutPreferences.sequence("exchange")
    dashboardObject.airEndShortcut: shortcutPreferences.sequence("airEnd")
    dashboardObject.hudVisibility: hudLayoutState.current
    dashboardObject.visible: !root.terminalPresentation && !root.mapMarkOpen
    dashboardObject.leftPanelOpen: root.injuryOpen || matchOverlay.dead && !engineerPanel.temporaryActive || root.roleOpen && ["dart", "sentry"].includes(root.resolvedRoleSection)
    dashboardObject.bottomPanelOpen: root.commonCommandOpen && exchangePanel.selectedTab===0 || root.roleOpen && ["engineer", "air"].includes(root.resolvedRoleSection)
    dashboardObject.mapObject.enabled: !root.modalActive && !root.captureDesired
    // Also cover HUD detail links/hover controls which do not use the map or
    // interactionAllowed property. A lost native grab must not enable clicking.
    dashboardObject.enabled: !root.modalActive && !root.captureDesired && !root.matchStateBlocksInput
    dashboardObject.decisionServices: root.servicesState
    dashboardObject.discoveryDisplayView: root.discoveryDisplayView
    dashboardObject.discoveryMarkers: root.discoveryDisplayView.markers
    dashboardObject.fusionView:typeof battlefieldHost === "undefined" ? ({}) : battlefieldHost?.view ?? ({})
    dashboardObject.decisionPreferences: decisionPreferences
    dashboardObject.connectedToPlayer: (root.connectionState?.connected === true) || root.mqttConnected
    dashboardObject.previewOnly: root.previewOnly
    terminalAdviceRuntime: root.servicesState?.terminalAdvice ?? null
    terminalVoiceRuntime: root.servicesState?.terminalVoice ?? null
    // Native display preferences are scoped by semantic robot and season;
    // retained 2026 numeric-role layout choices do not override them.
    terminalHudEnabled: root.nextSeason && !root.modalActive
    terminalHudInteractionAllowed: !root.modalActive && !root.captureDesired
    Connections {
        target: root.terminalAdviceHudObject
        function onDetailsRequested() { root.openPanel("season"); seasonPanel.page = 7; }
    }
    dashboardObject.headingItems: root.mapHeadingItems
    dashboardObject.runeMapItems:root.runeMapItems
    dashboardObject.mapFeedback:root.smallMapFeedback
    dashboardObject.outpostRebuildItems: root.outpostRebuildItems
    dashboardObject.baseDefenseItems: root.baseDefenseItems
    dashboardObject.outpostDefenseItems: root.outpostDefenseConnected || root.previewOnly ? root.outpostDefenseItems : []
    dashboardObject.rosterProjectionItems: root.rosterProjectionConnected || root.previewOnly ? root.rosterProjectionItems : []
    dashboardObject.fortressProgressScale: root.fortressScaleConnected || root.previewOnly ? root.fortressProgressScale : null
    dashboardObject.buffRecords: root.buffRecords
    dashboardObject.ownStatusItems: root.previewOnly || root.ownStatusProjectionConnected && root.mqttConnected ? root.ownStatusItems : []
    dashboardObject.ownStatusSessionId: root.ownStatusSessionId
    dashboardObject.combatCountdownSecondsVerified: root.combatCountdownSecondsVerified
    dashboardObject.airDisplayData: root.airDisplayData
    dashboardObject.airDisplayProjectionConnected: root.airDisplayProjectionConnected
    dashboardObject.airDisplaySessionId: root.airDisplaySessionId
    dashboardObject.airSupportSecondsVerified: root.airSupportSecondsVerified
    dashboardObject.airSupportEndShortcutAvailable: root.globalPanelShortcutsAvailable && airPanel.allowed(0)
        && root.inputState?.mouseCaptureEnabled !== true
    dashboardObject.bottomStatusView: root.bottomStatusView
    dashboardObject.bottomStatusProjectionConnected: root.bottomStatusProjectionConnected
    dashboardObject.bottomStatusSessionId: root.bottomStatusSessionId
    dashboardObject.bottomStatusDetailVisible: root.injuryOpen && damagePanel.selectedTab === 2
    dashboardObject.interactionAllowed: !root.modalActive && !root.captureDesired
    dashboardObject.panelShortcutsAvailable: root.globalPanelShortcutsAvailable || root.controlState?.uiCapabilities?.globalPanelShortcuts === true
    dashboardObject.inputCaptureFeedback: root.inputCaptureFeedback
    Connections { target: root.dashboardObject; function onMouseCaptureRequested(capture) { root.mouseCaptureRequested(capture); } }

    OperatorDecisionPreferences {
        id: decisionPreferences
        clientID: root.clientID
        runtime: root.previewOnly ? null : root.servicesState?.decisionConfiguration ?? null
    }
    OperatorStartupPreferences { id: startupPreferences }
    OperatorTeamConfigPreferences {
        id: teamConfigPreferences
        clientID: root.clientID
        hostConfiguration: root.previewOnly ? null : root.servicesState?.teamConfiguration ?? null
    }
    OperatorSourcePreferences { id: sourcePreferences; clientID: root.clientID }
    OperatorProviderPreferences {
        id: providerPreferences; clientID: root.clientID
        runtime: root.previewOnly ? null : root.servicesState?.providerConfiguration ?? null
    }
    onServicesStateChanged: activateTeamPreferences()
    function activateTeamPreferences() {
        const identity = servicesState?.teamIdentity;
        // 链路失联不把已选择队伍的本地偏好切回空配置；运行认证由宿主另行判定。
        if ((previewOnly || identity?.verified === true) && typeof identity?.team_id === "string" && identity.team_id.length > 0 && identity.team_id.length <= 96)
            decisionPreferences.teamId = identity.team_id;
    }
    Connections {
        target: root.previewOnly ? null : root.servicesState
        enabled: !root.previewOnly
        ignoreUnknownSignals: true
        function onTeamIdentityChanged() { root.activateTeamPreferences(); }
    }

    Connections { target: root.dashboardObject.discoveriesHudObject; function onDetailsRequested() { root.openPanel("aggregation"); root.aggregationPanelObject.detailTab = 3; } }
    Connections { target:root.dashboardObject.mapObject;function onDiscoveryDetailsRequested() {root.openPanel("aggregation");root.aggregationPanelObject.detailTab=3;} }

    OperatorLayoutState {
        id: hudLayoutState
        clientID: root.clientID
        adviceEditable: decisionPanel.preparationAllowed
    }
    // 面板库只选择界面；网络命令由各面板意图在后续接线阶段处理。
    function restorePanelFocus() {
        const panels = Array.from(root.stageObject.children).filter(item => item.visible && item.operatorPanelKeyboardBoundary === true);
        panels.sort((a,b) => b.z-a.z);
        (panels[0] ?? root).forceActiveFocus();
    }
    function openPanel(panel) {
        // 正式运行的旧启动入口统一进入实际连接页；草稿只保留给Designer预览。
        if (panel === "startup" && !root.previewOnly) panel = "login";
        // 先退役正文，再解除模态，插件关闭回调期间仍保持机器人输入暂停。
        extensionPanelHost.closePanel();
        extensionPanelOpen = false;
        if (panel === "scene") {
            openPanel("season");
            seasonPanel.page = 9;
            return;
        }
        if (root.nextSeason && panel === "speech") {
            openPanel("season");
            seasonPanel.page = 10;
            return;
        }
        if (panel === "packages") {
            openPanel("season");
            seasonPanel.page = 8;
            return;
        }
        if (root.nextSeason && ["team-config", "aggregation", "sources"].includes(panel)) {
            openPanel("season");
            seasonPanel.page = panel === "sources" ? 5 : 6;
            return;
        }
        if (panel === "control-setup") {
            openPanel("services");
            servicesPanel.selectedTab = 5;
            return;
        }
        // The 2026 panels encode 2026 roles, coordinates and command semantics.
        // They cannot become a 2027 interface just by changing a year label.
        if (root.terminalPresentation && !["none", "season", "login", "services", "startup", "sources",
            "team-config", "provider", "speech", "bridge", "aggregation", "help", "layout",
            "settings", "tuning"].includes(panel)) panel = "season";
        // 统一入口关闭先前面板，避免弹层叠加和焦点残留。
        if ((panel === "settings" || panel === "tuning") && !tuningOpen)
            performanceFeedback = "";
        layoutOpen = panel === "layout";
        seasonOpen = panel === "season";
        buffsOpen = panel === "buffs";
        startupOpen = panel === "startup";
        teamConfigOpen = panel === "team-config";
        sourceConfigOpen = panel === "sources";
        providerOpen = panel === "provider";
        loginOpen = panel === "login";
        detailsOpen = panel === "details" || panel === "protocol";
        customDataOpen = panel === "custom";
        mapMarkOpen = panel === "map";
        tuningOpen = panel === "settings" || panel === "tuning";
        helpOpen = panel === "help";
        servicesOpen = panel === "services";
        decisionOpen = panel === "decision";
        decisionInspectorOpen = panel === "decision-details";
        speechOpen = panel === "speech";
        bridgeOpen = panel === "bridge";
        aggregationOpen = panel === "aggregation";
        commonCommandOpen = panel === "commands";
        robotStatusOpen = panel === "status";
        injuryOpen = panel === "injury";
        if (!injuryOpen) { damagePanel.heldOpen = false; damagePanel.selectedTab = 0; }
        roleOpen = ["role", "dart", "rune", "engineer", "air", "sentry", "hero"].includes(panel);
        if (roleOpen)
            roleSection = panel;
    }
    function openConnection(robotId, host, port) {
        openPanel("login");
        if (Format.validLogin(robotId)) {
            loginPanel.selectedRobot = robotId % 100;
            loginPanel.blue = robotId > 100;
        }
        if (host !== undefined) loginPanel.draftHost = host;
        if (port !== undefined) loginPanel.draftPort = String(port);
    }
    function openExtensionPanel(packageId, panelId) {
        // 先使整个宿主进入模态，再执行插件 QML；不撤销用户持续捕获的意图。
        openPanel("none");
        extensionPanelFeedback = "";
        extensionPanelOpen = true;
        extensionPanelHost.openPanel(packageId, panelId);
    }
    function openPanelLibrary() {
        openPanel("layout");
        layoutEditor.panelsTab = true;
    }
    function openReferenceView() {
        if (typeof viewController?.openReference !== "function") {
            referenceFeedback = "当前宿主未提供保留界面入口";
            return;
        }
        referenceFeedback = viewController.openReference("player-2026-reference")
            ? "已打开2026保留界面；其中数值均为离线样例。"
            : viewController.status || "保留界面未能打开，请查看宿主状态";
    }
    Connections {
        target: root.seasonRuntime
        function onContextChanged() { root.resetTransientState(); root.openPanel("season"); }
    }
    OperatorSeasonPanel {
        id: seasonPanel
        parent: root.stageObject
        anchors.centerIn: parent
        z: 40
        visible: root.seasonOpen
        runtime: root.seasonRuntime
        links: root.servicesState?.terminalGateways ?? []
        teamRuntime: root.servicesState?.terminalTeam ?? null
        adviceRuntime: root.servicesState?.terminalAdvice ?? null
        voiceRuntime: root.servicesState?.terminalVoice ?? null
        speechRuntime: root.servicesState?.terminalSpeech ?? null
        bridgeRuntime: root.servicesState?.terminalBridge ?? null
        packageRuntime: root.servicesState?.packageRuntime ?? null
        sceneRuntime: root.servicesState?.terminalScene ?? null
        viewController: root.viewController
        onCloseRequested: root.seasonOpen = false
        onOpenExtensionPanelRequested: (packageId, panelId) => root.openExtensionPanel(packageId, panelId)
    }
    Column {
        parent: root.stageObject
        anchors.centerIn: parent
        width: Math.min(840, parent.width - 80)
        spacing: 20
        visible: root.terminalPresentation && !root.modalActive
        OperatorText { width: parent.width; height: 42; text: "RMUC 2027 · 正式规则 V1.0.0"; size: 26; horizontalAlignment: Text.AlignHCenter }
        OperatorText { width: parent.width; height: 78; text: root.seasonRuntime?.connectionReason ?? "2027生产数据尚未接通"; size: 16; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone; horizontalAlignment: Text.AlignHCenter }
        OperatorText { width: parent.width; height: 62; text: "2026选手端界面已独立保留，可打开查看，并作为后续界面改造的基础。2027比赛信息等待核验后的适配器接入；保留界面的样例不会进入生产数据。"; size: 13; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone; horizontalAlignment: Text.AlignHCenter }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 16
            OperatorButton { width: 210; text: "赛季与规则工作区"; primary: true; onClicked: root.openPanel("season") }
            OperatorButton { width: 180; text: "服务与连接状态"; onClicked: root.openPanel("services") }
            OperatorButton { width: 180; text: "查看26版界面"; enabled: typeof root.viewController?.openReference === "function"; onClicked: root.openReferenceView() }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            OperatorButton {
                width: 230
                text: "面板库 · 扩展 " + (root.servicesState?.packageRuntime?.availablePanels?.length ?? 0)
                onClicked: root.openPanelLibrary()
            }
            OperatorButton { width: 180; text: "安装与管理插件"; onClicked: root.openPanel("packages") }
        }
        OperatorText { visible: root.referenceFeedback.length > 0; width: parent.width; height: 42; text: root.referenceFeedback; size: 12; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone; horizontalAlignment: Text.AlignHCenter }
    }
    OperatorLayoutEditor {
        id: layoutEditor
        parent: root.stageObject
        x: 24
        y: 212
        height: Math.min(680, parent.height - y - 24)
        visible: root.layoutOpen
        z: 40
        clientID: root.clientID
        layoutState: hudLayoutState
        previewOnly: root.previewOnly
        nextSeason: root.terminalPresentation
        extensionPanels: root.servicesState?.packageRuntime?.availablePanels ?? []
        extensionFeedback: root.extensionPanelFeedback
        onCloseRequested: root.layoutOpen = false
        onOpenPanelRequested: panel => root.openPanel(panel)
        onOpenExtensionPanelRequested: (packageId, panelId) => root.openExtensionPanel(packageId, panelId)
    }
    OperatorExtensionPanelHost {
        id: extensionPanelHost
        parent: root.stageObject
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - 48)
        height: Math.min(implicitHeight, parent.height - 48)
        visible: root.extensionPanelOpen
        z: 40
        runtime: root.servicesState?.packageRuntime ?? null
        onCloseRequested: root.extensionPanelOpen = false
        onLibraryRequested: root.openPanelLibrary()
        onUnavailable: reason => {
            root.extensionPanelFeedback = reason;
            root.openPanelLibrary();
        }
    }
    // 本阶段重画主 HUD。后端信号保持原接口，角色与服务表面逐块重画后再接回。
    function resetRaceNotifications() { events=[];raceMessageViewRevision+=1;lastNotificationRound=null;lastPenaltyNotice=null; }
    function syncNotificationRound() {
        if(notificationRound===null)return;
        if(lastNotificationRound!==null && lastNotificationRound!==notificationRound)resetRaceNotifications();
        lastNotificationRound=notificationRound;
    }
    function resetTransientState() {
        resetRaceNotifications();
        robotEvents=[];robotMessageViewRevision+=1;
    }
    function appendRaceNotification(text,critical,source,raw) {
        if(!previewOnly && !mqttConnected)return;
        syncNotificationRound();
        const entry=Messages.observed(text,critical,source,clientID,raceMessageViewRevision,++eventSerial,Date.now(),previewOnly);
        // 只保留通知的原始字段，不能让文本参数覆写观察时间／来源／局部视图修订。
        if(raw?.event_id!==undefined)entry.event_id=raw.event_id;
        if(raw?.param!==undefined)entry.param=raw.param;
        if(raw?.penalty_type!==undefined)entry.penalty_type=raw.penalty_type;
        if(raw?.penalty_quantity!==undefined)entry.penalty_quantity=raw.penalty_quantity;
        if(raw?.penalty_effect_sec!==undefined)entry.penalty_effect_sec=raw.penalty_effect_sec;
        entry.tone=raw?.tone??"neutral";
        entry.observed_round=notificationRound;
        if(notificationRound!==null && Data.state(telemetry,"gameStatus","current_stage")==="fresh"
            && telemetry.gameStatus.current_stage===4 && Data.state(telemetry,"gameStatus","stage_countdown_sec")==="fresh"
            && Number.isSafeInteger(telemetry.gameStatus.stage_countdown_sec) && telemetry.gameStatus.stage_countdown_sec>=0) {
            entry.match_clock_sec=telemetry.gameStatus.stage_countdown_sec;
            entry.match_clock_fresh_at_observation=true;
        }
        events=events.concat([entry]).slice(-30);
    }
    function showEvent(id, parameter) {
        // A local server may send an empty snapshot before any trigger. Zero is
        // not a V2.0.0 event; keep the raw field in the inspector, not the HUD.
        if (id === 0 && parameter === "") return;
        appendRaceNotification(EventFormat.notificationText(id,parameter),EventFormat.critical(id),"telemetry.eventReceived",
            {event_id:id,param:parameter,tone:EventFormat.notificationTone(id,parameter,clientID)});
    }
    function showPenalty(type, seconds, count) {
        const currentCount=Data.state(root.telemetry,"penalty","total_penalty_num")==="fresh"
            && Data.notOlderThan(root.telemetry,"penalty","total_penalty_num","penalty_type") ? root.telemetry.penalty.total_penalty_num : null;
        const remaining=Data.state(root.telemetry,"penalty","penalty_effect_sec")==="fresh"
            && Data.notOlderThan(root.telemetry,"penalty","penalty_effect_sec","penalty_type") ? root.telemetry.penalty.penalty_effect_sec : null;
        if(type===0 || currentCount===0) {lastPenaltyNotice=null;return;}
        const previous=lastPenaltyNotice;
        const duplicate=previous && previous.type===type && previous.count===currentCount
            && remaining!==null && previous.remaining!==null && remaining<=previous.remaining
            && Date.now()-previous.at<60000;
        lastPenaltyNotice={type:type,count:currentCount,remaining:remaining,at:Date.now()};
        // 同一判罚的倒数更新不刷屏；类型/数量变化或时长重新增长才产生新通知。
        if(duplicate)return;
        // 旧int信号丢失optional存在性，不能把缺失时长／数量经toInt得到的0当真实值。
        const name = ({1:"黄牌",2:"双方黄牌",3:"红牌",4:"超功率",5:"超热量",6:"超射速"})[type] ?? "未知类型 " + type;
        appendRaceNotification(name+(currentCount===null?"":" · 数量 "+currentCount),true,"telemetry.penaltyReceived",
            {penalty_type:type,penalty_quantity:currentCount??undefined,penalty_effect_sec:remaining??undefined,tone:[1,2,3,4,5,6].includes(type)?"adverse":"neutral"});
    }
    Connections {
        target: root.telemetry
        function onEventReceived(id, parameter) {
            root.showEvent(id, parameter);
        }
        function onPenaltyReceived(type, seconds, count) {
            root.showPenalty(type, seconds, count);
        }
    }
    Connections {
        target: root.dashboardObject
        function onMapModeRequested(mode) { mapPanel.markerMode=mode; }
        function onMapPointRequested(mapX, mapY) {
            mapPanel.submitOwnPoint(mapX,mapY);
            root.smallMapFeedback=mapPanel.feedback;smallMapFeedbackTimer.restart();
        }
        function onMapEnemyRequested(robotId) {
            mapPanel.submitOwnEnemy(robotId);
            root.smallMapFeedback=mapPanel.feedback;smallMapFeedbackTimer.restart();
        }
        function onPanelRequested(panel) {
            if (panel === "commands") root.openPanel(root.commonCommandOpen ? "none" : "commands");
            else root.panelRequested(panel);
        }
    }
    Image {
        parent: root.stageObject
        anchors.fill: parent
        visible: (root.loginOpen || root.startupOpen) && root.clientID === 0
        source: visible ? "../resources/engine-137/sprites/ServerUI_LoginBg.png" : ""
        fillMode: Image.PreserveAspectCrop
        mipmap: true
        z: 9
    }
    Rectangle {
        parent: root.stageObject
        anchors.fill: parent
        color: "#870c1210"
        visible: root.seasonOpen || root.loginOpen || root.startupOpen || root.teamConfigOpen || root.sourceConfigOpen || root.providerOpen || root.commonCommandOpen && exchangePanel.selectedTab===1 || root.robotStatusOpen || root.tuningOpen || root.helpOpen || root.servicesOpen || root.detailsOpen || root.customDataOpen || root.decisionOpen || root.decisionInspectorOpen || root.speechOpen || root.bridgeOpen || root.aggregationOpen || root.buffsOpen || root.extensionPanelOpen
        z: 10
    }
    OperatorMatchOverlay {
        id: matchOverlay
        objectName: "matchStateOverlay"
        parent: root.stageObject
        anchors.fill: parent
        z: 5
        telemetry: root.telemetry
        clientID: root.clientID
        connected: root.playerConnected
        temporaryActivation:engineerPanel.temporaryActive
        obscured: root.modalActive && !root.injuryOpen || root.terminalPresentation
        actionsAvailable: root.controlState?.uiCapabilities?.commonControl === true
        revivePolicy: root.controlState?.commonControls?.robotID === root.clientID
                      && root.controlState?.commonControls?.freshness === "fresh"
                      ? root.controlState.commonControls.operations ?? ({}) : ({})
        onCommonIntent: fields => root.commandRequested("CommonCommand", fields)
    }
    OperatorEventOverlay {
        id:eventOverlay
        objectName:"eventOverlay"
        parent:root.stageObject;anchors.fill:parent;z:6
        events:root.events;clientID:root.clientID;revision:root.raceMessageViewRevision
        previewOnly:root.previewOnly;dead:matchOverlay.dead
        enabledDisplay:!root.terminalPresentation && !(root.modalActive && !root.injuryOpen) && !matchOverlay.ended && root.playerConnected
    }
    OperatorSentryRfid {
        id:sentryRfid
        parent:root.stageObject;z:6
        x:(parent.width-width)/2;y:parent.height/2-120
        telemetry:root.telemetry;clientID:root.clientID;connected:root.playerConnected
        projectionItems:root.rosterProjectionConnected?root.rosterProjectionItems:[]
        displayAllowed:!root.terminalPresentation && !root.modalActive
        previewOnly:root.previewOnly
    }
    OperatorProtocolInspector {
        id: protocolPanel
        objectName: "protocolInspector"
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.detailsOpen
        z: 30
        telemetry: root.telemetry
        previewOnly: root.previewOnly
        connected: root.mqttConnected
        onCommandIntent: (topic, fields) => root.protocolCommandRequested(topic, fields)
        onCloseRequested: root.detailsOpen = false
        onLayoutRequested: root.openPanel("layout")
    }
    OperatorBuffPanel {
        id:buffPanel
        objectName:"operatorBuffPanel"
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.buffsOpen
        z: 30
        records: root.buffRecords
        clientID: root.clientID
        previewOnly: root.previewOnly
        projectionConnected: root.buffProjectionConnected
        nativeConnected:root.playerConnected
        localCollectionAvailable:!root.buffProjectionConnected && root.localBuffRecords!==null
        excludedCount: root.buffExcludedCount
        onCloseRequested: root.openPanel("none")
        onProtocolRequested: { root.openPanel("details"); protocolPanel.selectedTopic = "Buff"; }
    }
    OperatorMapPanel {
        id: mapPanel
        connected:root.playerConnected
        discoveryMarkers:root.discoveryDisplayView.markers
        supportVisible: root.clientID%100===7 || root.sentrySupportConfigured
        supportHeight:sentryPanel.height
        supportConfirming: !!sentryPanel.selectedAction
        forwardMode:root.sentrySupportConfigured
        forwardActive:sentryPanel.localDisplay?.map_offer?.active===true
        teamMarkAllowed: root.controlState?.uiCapabilities?.mapTeamMark === true
        submissionAvailable: root.previewOnly || (root.sentrySupportConfigured?root.controlState?.uiCapabilities?.sentrySupport===true && sentryPanel.localDisplay!==null:root.controlState?.uiCapabilities?.mapMark === true)
        unavailableReason: root.sentrySupportConfigured?"等待己方哨兵状态更新":root.controlState?.unavailableReasons?.mapMark ?? "生产地图发送入口未接通"
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.mapMarkOpen
        z: 30
        telemetry: root.telemetry
        clientID: root.clientID
        headingItems: root.mapHeadingItems
        runeMapItems:root.runeMapItems
        projectionItems: root.rosterProjectionConnected ? root.rosterProjectionItems : []
        previewOnly: root.previewOnly
        onCloseRequested: root.mapMarkOpen = false
        onLayoutRequested: root.openPanel("layout")
        onMapIntent: fields => root.mapMarkRequested(fields)
    }
    Timer {id:smallMapFeedbackTimer;interval:3000;onTriggered:root.smallMapFeedback=""}
    readonly property var mapMonitorObject:mapMonitor.item
    Loader {
        id:mapMonitor
        active:!root.terminalPresentation && root.controlState?.uiCapabilities?.mapTeamMark===true && Qt.application.screens.length>1
        sourceComponent:OperatorMapMonitor {
            operatorWindow:root.Window.window
            displayEnabled:true
            telemetry:root.telemetry;clientID:root.clientID
            headingItems:root.mapHeadingItems
            runeMapItems:root.runeMapItems
            projectionItems:root.rosterProjectionConnected ? root.rosterProjectionItems : []
        }
    }
    OperatorBytePanel {
        id: bytePanel
        submissionAvailable: root.previewOnly || root.controlState?.uiCapabilities?.customBytes === true
        unavailableReason: root.controlState?.unavailableReasons?.customBytes ?? "生产自定义数据入口未接通"
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.customDataOpen
        z: 30
        telemetry: root.telemetry
        clientID: root.clientID
        previewOnly: root.previewOnly
        onCloseRequested: root.customDataOpen = false
        onLayoutRequested: root.openPanel("layout")
        onByteIntent: fields => root.customByteRequested(fields)
    }
    OperatorLogin {
        id: loginPanel
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.loginOpen
        z: 20
        connectionStatus: root.mqttStatusMessage
        connection: root.connectionState
        videoState: root.primaryVideoState ?? root.videoSource
        seasonRuntime: root.seasonRuntime
        clientID: root.clientID
        connecting: root.mqttConnecting
        connected: root.mqttConnected
        previewOnly: root.previewOnly
        onCloseRequested: root.loginOpen = false
        onLoginRequested: robotID => root.loginRequested(robotID)
        onSessionRequested: options => root.connectionSessionRequested(options)
        onDisconnectRequested: root.disconnectRequested()
        onVideoConfigureRequested: options => root.videoConfigureRequested(options)
        onVideoRestartRequested: root.videoRestartRequested()
        onVideoStopRequested: root.videoStopRequested()
        onSeasonRequested: root.openPanel("season")
    }
    Loader {
        id: startupPanelLoader
        // 正式客户端的连接入口直接使用登录页，旧启动草稿只属于Designer预览。
        active: root.previewOnly
        sourceComponent: OperatorStartupPanel {
            parent: root.stageObject
            anchors.centerIn: parent
            visible: root.previewOnly && root.startupOpen
            z: 30
            preferences: startupPreferences
            seasonRuntime: root.seasonRuntime
            runtime: root.servicesState?.startupConfiguration ?? null
            telemetry: root.telemetry
            connection: root.connectionState ?? ({connected: root.mqttConnected, connecting: root.mqttConnecting})
            clientID: root.clientID
            previewOnly: root.previewOnly
            onCloseRequested: root.startupOpen = false
            onLoginRequested: root.openPanel("login")
            onLoadProfileRequested: root.loadStartupProfileRequested()
            onSaveProfileRequested: (options, purpose) => root.saveStartupProfileRequested(options, purpose)
            onConnectAddressRequested: (host,port) => {
                root.openPanel("login");
                Qt.callLater(()=>{loginPanel.draftHost=host;loginPanel.draftPort=String(port);});
            }
        }
    }
    OperatorTeamConfigPanel {
        id: teamConfigPanel
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.teamConfigOpen
        z: 30
        preferences: teamConfigPreferences
        decisionPreferences: decisionPreferences
        runtime: root.servicesState?.teamSharingConfiguration ?? null
        telemetry: root.telemetry
        connection: root.connectionState ?? ({connected: root.mqttConnected, connecting: root.mqttConnecting})
        setupOnly: root.servicesState?.decisionCapabilities?.setup_only === true && root.servicesState?.decisionSetupMode === "offline-preparation"
        clientID: root.clientID
        previewOnly: root.previewOnly
        onCloseRequested: root.teamConfigOpen = false
        onModelSettingsRequested: root.openPanel("decision")
        onAggregationRequested: root.openPanel("aggregation")
        onCertificateInspectRequested: file => root.inspectTeamCertificateRequested(file)
    }
    OperatorSourcePanel {
        id: sourcePanel
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.sourceConfigOpen
        z: 30
        preferences: sourcePreferences
        runtime: root.servicesState?.sourceConfiguration ?? null
        telemetry: root.telemetry
        connection: root.connectionState ?? ({connected: root.mqttConnected, connecting: root.mqttConnecting})
        setupOnly: root.servicesState?.decisionCapabilities?.setup_only === true && root.servicesState?.decisionSetupMode === "offline-preparation"
        clientID: root.clientID
        previewOnly: root.previewOnly
        onCloseRequested: root.sourceConfigOpen = false
        onTeamSettingsRequested: root.openPanel("team-config")
        onAggregationRequested: root.openPanel("aggregation")
        onAdapterInspectRequested: id => root.inspectSourceAdapterRequested(id)
    }
    OperatorProviderPanel {
        id: providerPanel
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.providerOpen
        z: 30
        preferences: providerPreferences
        decisionPreferences: decisionPreferences
        controller: root.previewOnly ? null : root.servicesState?.providerConfiguration ?? null
        runtime: controller?.state ?? root.servicesState?.providerConfiguration ?? null
        telemetry: root.telemetry
        connection: root.connectionState ?? ({connected: root.mqttConnected, connecting: root.mqttConnecting})
        setupOnly: root.servicesState?.decisionCapabilities?.setup_only === true && root.servicesState?.decisionSetupMode === "offline-preparation"
        clientID: root.clientID
        previewOnly: root.previewOnly
        onCloseRequested: root.providerOpen = false
        onStrategyRequested: root.openPanel("decision")
        onSourcesRequested: root.openPanel("sources")
        onTeamSettingsRequested: root.openPanel("team-config")
        onInspectRequested: configuration => root.inspectModelProviderRequested(configuration)
    }
    OperatorSettings {
        id: settingsPanel
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.tuningOpen
        z: 20
        clientID: root.clientID
        connecting: root.mqttConnecting || root.connectionState?.connecting === true
        connected: root.mqttConnected || root.connectionState?.connected === true
        localApplyAvailable: root.previewOnly || root.localSettingsState?.capabilities?.localSettings === true
        sensitivityAvailable: root.previewOnly || root.localSettingsState?.capabilities?.sensitivity === true
        audioStatus: root.previewOnly ? "离线样例；不播放音频" : root.servicesState?.localAudioStatus ?? "音量偏好与服务状态未提供"
        audioPlaybackAvailable: root.servicesState?.speechDetails?.active === true && root.servicesState?.speechDetails?.playback === true && root.servicesState?.speechDetails?.tone_control === true && root.servicesState?.speechDetails?.local_volume_applied === true
        onAlertTestIntent: root.localAlertTestRequested()
        performanceAvailable: root.previewOnly || root.controlState?.uiCapabilities?.performanceSelection === true
        performanceControls: root.controlState?.performanceControls ?? ({})
        telemetry: root.telemetry
        connectionStatus: root.mqttStatusMessage
        previewOnly: root.previewOnly
        appliedSettings: root.operatorSettings
        settingsFeedback: root.settingsFeedback
        performanceFeedback: root.performanceFeedback
        onLoginIntent: robotID => root.loginRequested(robotID)
        onSettingsIntent: values => root.localSettingsRequested(values)
        onPerformanceIntent: fields => root.performanceRequested(fields)
        onCloseRequested: root.tuningOpen = false
        onServicesRequested: root.openPanel("services")
        onStartupPreviewRequested: root.startupPreviewRequested()
        onStartupRequested: root.openPanel("startup")
        onLayoutRequested: root.openPanel("layout")
        onShortcutsRequested: {root.openPanel("help");helpPanel.editorMode=true;}
        onControlSetupRequested: root.openPanel("control-setup")
        // 本地偏好与性能命令分开交给宿主，不把本地选择写入同步遥测。
    }
    OperatorHelp {
        id: helpPanel
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.helpOpen
        z: 30
        clientID: root.clientID
        previewOnly: root.previewOnly
        routesInstalled: root.globalPanelShortcutsAvailable
        preferences: shortcutPreferences
        inputState: root.inputState
        onOpenPanelRequested: panel => root.openPanel(panel)
        onCloseRequested: root.helpOpen = false
    }
    OperatorShortcutPreferences {
        id: shortcutPreferences
        editable: root.previewOnly || !Format.validLogin(root.clientID) && !root.mqttConnected && !root.mqttConnecting
            || decisionPanel.preparationAllowed
    }
    OperatorServices {
        id: servicesPanel
        mapRenderer:mapPanel.map3DControl
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.servicesOpen
        z: 20
        services: root.servicesState
        connection: root.connectionState
        video: root.diagnosticVideoState ?? root.primaryVideoState ?? root.videoSource
        telemetry: root.telemetry
        previewOnly: root.previewOnly
        onCloseRequested: root.servicesOpen = false
        onProviderRequested: root.openPanel("provider")
        onSpeechRequested: root.openPanel("speech")
        onSettingsRequested: root.openPanel("settings")
        onSeasonRequested: root.openPanel("season")
        onOpenExtensionPanelRequested: (packageId, panelId) => root.openExtensionPanel(packageId, panelId)
    }
    OperatorDecisionPanel {
        id: decisionPanel
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.decisionOpen
        z: 30
        services: root.servicesState
        preferences: decisionPreferences
        controller: root.previewOnly ? null : root.servicesState?.decisionConfiguration ?? null
        layoutState: hudLayoutState
        telemetry: root.telemetry
        clientID: root.clientID
        previewOnly: root.previewOnly
        onCloseRequested: root.decisionOpen = false
        onLayoutRequested: root.openPanel("layout")
        onServicesRequested: root.openPanel("services")
        onInspectorRequested: root.openPanel("decision-details")
        onAggregationRequested: root.openPanel("aggregation")
        onProviderRequested: root.openPanel("provider")
    }
    OperatorDecisionInspector {
        id: decisionInspector
        preferences: decisionPreferences
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.decisionInspectorOpen
        z: 30
        services: root.servicesState
        clientID: root.clientID
        previewOnly: root.previewOnly
        preparationAllowed: root.previewOnly || root.servicesState?.decisionConfiguration?.editable === true
        onCloseRequested: root.decisionInspectorOpen = false
        onLayoutRequested: root.openPanel("layout")
        onServicesRequested: root.openPanel("services")
        onRequestIntent: question => root.decisionRequested(question)
        onCancelIntent: root.cancelDecisionRequested()
        onSpeakAdviceIntent: root.speakAdviceRequested()
        onSpeakInputIntent: root.speakInputFactsRequested()
    }
    OperatorSpeechPanel {
        id: speechPanel
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.speechOpen
        z: 30
        services: root.servicesState
        clientID: root.clientID
        connected: root.connectionState?.connected === true
        previewOnly: root.previewOnly
        onCloseRequested: root.speechOpen = false
        onLayoutRequested: root.openPanel("layout")
        onServicesRequested: root.openPanel("services")
        onNarrationIntent: (text, priority, key) => root.narrationRequested(text, priority, key)
        onExampleIntent: root.testSpeechRequested()
        onStopIntent: root.stopSpeechRequested()
    }
    OperatorBridgePanel {
        id: bridgePanel
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.bridgeOpen
        z: 30
        services: root.servicesState
        previewOnly: root.previewOnly
        onCloseRequested: root.bridgeOpen = false
        onLayoutRequested: root.openPanel("layout")
        onServicesRequested: root.openPanel("services")
    }
    OperatorTeamAggregationPanel {
        id: aggregationPanel
        clientID: root.clientID
        discoveryDisplayView: root.discoveryDisplayView
        parent: root.stageObject
        anchors.centerIn: parent
        visible: root.aggregationOpen
        z: 30
        services: root.servicesState
        telemetry: root.telemetry
        preferences: decisionPreferences
        previewOnly: root.previewOnly
        onCloseRequested: root.aggregationOpen = false
        onDecisionRequested: root.openPanel("decision")
        onLayoutRequested: root.openPanel("layout")
        onTeamSettingsRequested: root.openPanel("team-config")
        onSourceSettingsRequested: root.openPanel("sources")
    }
    OperatorExchange {
        id: exchangePanel
        parent: root.stageObject
        x: (parent.width-width)/2
        y: selectedTab===1 ? (parent.height-height)/2 : parent.height-height-24
        projectionItems: root.rosterProjectionItems
        visible: root.commonCommandOpen
        z: 20
        telemetry: root.telemetry
        clientID: root.clientID
        previewOnly: root.previewOnly
        actionsAvailable: root.previewOnly || root.controlState?.uiCapabilities?.commonControl === true
        hostReason: root.controlState?.unavailableReasons?.commonControl ?? ""
        commandPolicy: root.controlState?.commonControls?.robotID === root.clientID
                       && root.controlState?.commonControls?.freshness === "fresh" ? root.controlState.commonControls.operations ?? ({}) : ({})
        onCommonIntent: fields => root.commandRequested("CommonCommand", fields)
        onCloseRequested: root.commonCommandOpen = false
    }
    OperatorStatusTable {
        id: statusPanel
        parent: root.stageObject
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 16
        visible: root.robotStatusOpen
        z: 20
        telemetry: root.telemetry
        clientID: root.clientID
        previewOnly: root.previewOnly
        projectionItems: root.rosterProjectionItems
        onCloseRequested: root.robotStatusOpen = false
    }
    OperatorDamagePanel {
        id: damagePanel
        parent: root.stageObject
        x: 0
        y: 200
        availableHeight: root.dashboardObject.vitalsObject.y - y - 12
        visible: root.injuryOpen || matchOverlay.dead && !engineerPanel.temporaryActive && !root.modalActive
        z: 20
        telemetry: root.telemetry
        clientID: root.clientID
        previewOnly: root.previewOnly
        connectedToPlayer: root.playerConnected
        bottomStatusDisplay: root.dashboardObject.modulesObject.display
        onCloseRequested: { root.injuryOpen = false; heldOpen = false; selectedTab = 0; }
    }
    Connections {
        target: root.dashboardObject.modulesObject
        function onDetailsRequested(page) { root.openPanel("injury"); root.damagePanelObject.selectedTab = page === 2 ? 2 : 1; }
    }
    OperatorDartPanel {
        id: dartPanel
        parent: root.stageObject
        x: root.dashboardObject.messagesObject.x
        width:root.dashboardObject.messagesObject.width
        y: 224
        visible: root.roleOpen && root.resolvedRoleSection === "dart"
        z: 20
        telemetry: root.telemetry
        clientID: root.clientID
        previewOnly: root.previewOnly
        actionsAvailable: root.previewOnly || root.controlState?.uiCapabilities?.dartControl === true
        hostReason: root.controlState?.unavailableReasons?.dartControl ?? ""
        operatorAuthorized: root.controlState?.dartControl?.operatorRole === "gimbal"
                            && root.controlState?.dartControl?.robotID === root.clientID
                            && root.controlState?.dartControl?.freshness === "fresh"
        operationPolicy: root.controlState?.dartControl?.operations ?? ({})
        displayProjection:root.dartDisplayProjection
        onDartIntent: fields => root.commandRequested("DartCommand", fields)
        onCloseRequested: root.roleOpen = false
    }
    OperatorRunePanel {
        id: runePanel
        parent: root.dashboardObject
        x: root.dashboardObject.messagesObject.x
        width: root.dashboardObject.messagesObject.width
        y: 184
        availableHeight: root.dashboardObject.messagesObject.y-y-10
        visible: [3,4,5].includes(root.clientID%100) && !root.modalActive && !root.terminalPresentation && !root.dashboardObject.leftPanelOpen
        z: 20
        telemetry: root.telemetry
        projectionItems:root.rosterProjectionConnected ? root.rosterProjectionItems : []
        clientID: root.clientID
        previewOnly: root.previewOnly
        actionsAvailable: root.previewOnly || root.controlState?.uiCapabilities?.runeActivate === true
        hostReason: root.controlState?.unavailableReasons?.runeActivate ?? ""
        activationAllowed: root.controlState?.runeActivation?.allowed === true
                           && root.controlState?.runeActivation?.robotID === root.clientID
                           && root.controlState?.runeActivation?.freshness === "fresh"
        largeRuneConfirmed: root.controlState?.runeContext?.kind === "large"
                            && root.controlState?.runeContext?.robotID === root.clientID
                            && root.controlState?.runeContext?.freshness === "fresh"
        onActivationIntent: root.commandRequested("RuneActivateCommand", {activate: 1})
        onCloseRequested: root.roleOpen = false
    }
    OperatorEngineerPanel {
        id: engineerPanel
        parent: root.stageObject
        // 与英雄卡同一保留区，不侵入自身状态、小地图或射击读数。
        x: (parent.width-width)/2
        y: selecting ? (parent.height-height)/2 : parent.height-height-24
        visible: root.roleOpen && root.resolvedRoleSection === "engineer"
        z: 20
        telemetry: root.telemetry
        projectionItems:root.rosterProjectionConnected?root.rosterProjectionItems:[]
        clientID: root.clientID
        previewOnly: root.previewOnly
        actionsAvailable: root.previewOnly || root.controlState?.uiCapabilities?.engineerAssembly === true
        hostReason: root.controlState?.unavailableReasons?.engineerAssembly ?? ""
        assemblyDifficulty: root.controlState?.assemblyContext?.difficulty ?? null
        assemblyContext: root.controlState?.assemblyContext ?? null
        canConfirmDifficulty: root.previewOnly || root.controlState?.assemblyContext?.canConfirmDifficulty === true
        assemblyContextValid: root.controlState?.assemblyContext?.valid === true
                              && root.controlState?.assemblyContext?.robotID === root.clientID
                              && root.controlState?.assemblyContext?.freshness === "fresh"
        onAssemblyIntent: (operation, difficulty) => root.commandRequested("AssemblyCommand", {operation: operation, difficulty: difficulty})
        onAssemblyContextIntent: difficulty => root.assemblyContextRequested(difficulty)
        onAttentionRequested:root.roleOpen=true
        onCloseRequested: root.roleOpen = false
    }
    OperatorAirSupportPanel {
        id: airPanel
        parent: root.stageObject
        x: (parent.width-width)/2
        projectionItems: root.rosterProjectionItems
        y: parent.height - height - 24
        visible: root.roleOpen && root.resolvedRoleSection === "air"
        z: 20
        telemetry: root.telemetry
        clientID: root.clientID
        previewOnly: root.previewOnly
        connectedToPlayer: root.playerConnected
        secondsVerified: root.airSupportSecondsVerified
        contextRevision: root.airSupportContextRevision
        commandInputAvailable: root.roleOpen && root.resolvedRoleSection === "air" && root.inputState?.mouseCaptureEnabled !== true
        actionsAvailable: root.previewOnly || root.controlState?.uiCapabilities?.airSupport === true
        hostReason: root.controlState?.unavailableReasons?.airSupport ?? ""
        onSupportIntent: commandID => root.commandRequested("AirSupportCommand", {command_id: commandID})
        onCloseRequested: root.roleOpen = false
    }
    OperatorSentryPanel {
        id: sentryPanel
        parent: root.mapMarkOpen && mapPanel.supportVisible ? mapPanel : root.stageObject
        x: root.mapMarkOpen && mapPanel.supportVisible ? parent.width-width-12 : 24
        y: root.mapMarkOpen && mapPanel.supportVisible ? 52 : Math.max(20,(parent.height-height)/2)
        visible: root.mapMarkOpen && mapPanel.supportVisible || root.roleOpen && root.resolvedRoleSection === "sentry"
        z: 31
        telemetry: root.telemetry
        clientID: root.clientID
        projectionItems:root.rosterProjectionConnected?root.rosterProjectionItems:[]
        supportMode:root.sentrySupportConfigured
        supportProjection:root.sentrySupportProjection
        localBusy:root.sentryLocalBusy
        previewOnly: root.previewOnly
        actionsAvailable: root.previewOnly || root.controlState?.uiCapabilities?.sentryControl === true
        hostReason: root.controlState?.unavailableReasons?.sentryControl ?? ""
        commandReasons: root.controlState?.unavailableReasons?.sentryCommands ?? ({})
        onControlIntent: commandID => root.commandRequested("SentryCtrlCommand", {command_id: commandID})
        onLocalIntent:fields=>root.sentryLocalRequested(fields)
        onMapRequested: root.openPanel("map")
        onCloseRequested: {if(root.mapMarkOpen)root.mapMarkOpen=false;else root.roleOpen=false;}
    }
    OperatorHeroPanel {
        id: heroPanel
        parent: root.dashboardObject
        x: (parent.width - width) / 2
        y: root.dashboardObject.exchangeHitArea.y - height - 8
        visible: root.clientID%100===1 && !root.modalActive && !root.terminalPresentation
        z: 20
        telemetry: root.telemetry
        clientID: root.clientID
        previewOnly: root.previewOnly
        projectionItems: root.rosterProjectionItems
        actionsAvailable: root.previewOnly || root.controlState?.uiCapabilities?.heroDeploy === true
        hostReason: root.controlState?.unavailableReasons?.heroDeploy ?? ""
        onDeployIntent: enter => root.commandRequested("HeroDeployModeEventCommand", {mode: enter ? 1 : 0})
        onCloseRequested: root.roleOpen = false
    }
}
