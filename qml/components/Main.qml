import QtQuick

OperatorWindow {
    id: root
    auxiliaryInteractionBlocked: bootSequenceActive || (situationWindow.item?.visible ?? false)
    Loader {
        id: situationWindow
        active: typeof battlefieldHost !== "undefined" && battlefieldHost !== null
        source: "OperatorBattlefieldWindow.qml"
        onLoaded: item.host = battlefieldHost
    }
    function openSituation() {
        if (!situationWindow.item) return;
        inputController.suspendMouseCapture();
        situationWindow.item.show();
        situationWindow.item.requestActivate();
    }
    property string initialPanel: ui.nextSeason ? "season" : "login"
    Component.onCompleted: ui.openPanel(initialPanel)
    ui.telemetry: clientBackend.telemetry
    ui.clientID: clientBackend.clientId
    readonly property var heroVideoSource:typeof heroVideoReceiver==="undefined"?null:heroVideoReceiver
    ui.videoSource:root.heroVideoSource?.active && root.heroVideoSource?.frameAvailable
        ?root.heroVideoSource:videoReceiver
    ui.primaryVideoState: videoReceiver
    ui.heroPanelObject.videoStatus:root.heroVideoSource?.status??""
    ui.inputState: inputController
    ui.mqttConnected: clientBackend.connected
    ui.mqttConnecting: clientBackend.connecting
    ui.mqttStatusMessage: clientBackend.status
    ui.connectionState: clientBackend
    ui.servicesState: extensionServices
    ui.viewController: uiViewController
    ui.globalPanelShortcutsAvailable: true
    ui.airSupportSecondsVerified: extensionServices.seasonConfiguration?.current?.season === 2026
    ui.combatCountdownSecondsVerified: extensionServices.seasonConfiguration?.current?.season === 2026
    // The official global message has current HP but no per-robot max HP/level.
    // The optional local adapter reads these and other missing display fields from the same running simulator.
    Loader {
        id: sharkRoster
        active: clientBackend.connected && ["127.0.0.1", "localhost", "::1"].includes(clientBackend.host)
            && extensionServices.seasonConfiguration?.current?.season === 2026
        source: active ? Qt.resolvedUrl("../../extensions/shark-local-roster/qml/SharkRoster.qml") : ""
    }
    ui.rosterProjectionItems: sharkRoster.item?.items ?? []
    ui.rosterProjectionConnected: sharkRoster.status === Loader.Ready
    ui.runeMapItems:clientBackend.port===3333 ? sharkRoster.item?.runeMapViews??[] : []
    ui.localBuffProjection:clientBackend.port===3333 && typeof sharkRoster.item?.buffProjection==="function"
        ?sharkRoster.item.buffProjection(clientBackend.clientId):null
    property var localSentryContext:typeof sharkRoster.item?.sentryProjection==="function"?sharkRoster.item.sentryProjection(clientBackend.clientId):null
    onLocalSentryContextChanged: {
        const actions=extensionServices.operatorActions;
        if(typeof actions?.syncLocalSentrySupport==="function")actions.syncLocalSentrySupport(localSentryContext??({}));
    }
    ui.sentrySupportProjection:localSentryContext
    ui.sentryLocalBusy:sharkRoster.item?.supportBusy??false
    Connections {
        target:sharkRoster.item
        ignoreUnknownSignals:true
        function onSupportFinished(operatorID,accepted,message){if(operatorID===clientBackend.clientId)root.ui.sentryPanelObject.feedback=message;}
    }
    Connections {
        target:root.ui
        function onSentryLocalRequested(fields){
            if(extensionServices.operatorActions?.uiCapabilities?.sentrySupport!==true
                || typeof sharkRoster.item?.submitSentry!=="function"
                || !sharkRoster.item.submitSentry(clientBackend.clientId,fields))
                root.ui.sentryPanelObject.feedback="等待有效的己方哨兵状态或上一次操作完成";
        }
    }
    ui.outpostRebuildItems: sharkRoster.item?.unitProjections(clientBackend.clientId,false) ?? []
    ui.outpostDefenseItems: sharkRoster.item?.unitProjections(clientBackend.clientId,false) ?? []
    ui.outpostDefenseConnected: sharkRoster.status === Loader.Ready
    ui.baseDefenseItems: sharkRoster.item?.unitProjections(clientBackend.clientId,true) ?? []
    ui.fortressProgressScale:sharkRoster.item?.fortressScale(clientBackend.clientId) ?? null
    ui.fortressScaleConnected:sharkRoster.status===Loader.Ready
    ui.dartDisplayProjection:typeof sharkRoster.item?.dartProjection==="function" ? sharkRoster.item.dartProjection(clientBackend.clientId) : null
    ui.localSettingsState: localUiSettings
    ui.operatorSettings: localUiSettings.values
    property string localAlertFeedback: ""
    ui.settingsFeedback: localAlertFeedback || localUiSettings.status
    function sendOperatorCommand(topic, fields) {
        const actions = extensionServices.operatorActions;
        const accepted = actions && typeof actions.sendCommand === "function" && actions.sendCommand(topic, fields);
        if(accepted && topic==="SentryCtrlCommand" && ui.sentrySupportConfigured && typeof sharkRoster.item?.invalidateSentry==="function")sharkRoster.item.invalidateSentry();
        const feedback = actions?.commandFeedback;
        if (topic === "AssemblyCommand") ui.engineerPanelObject.recordSubmission(fields,accepted);
        if (topic === "MapClickCmd") ui.mapPanelObject.recordSubmission(fields,accepted);
        if (topic === "CommonCommand") ui.exchangePanelObject.recordSubmission(fields,accepted);
        const message = accepted ? "已提交至MQTT；执行结果以选手端回传为准"
            : feedback?.reason || "操作发送入口不可用";
        const panels = {
            CommonCommand: ui.exchangePanelObject, DartCommand: ui.dartPanelObject,
            RuneActivateCommand: ui.runePanelObject, AssemblyCommand: ui.engineerPanelObject,
            AirSupportCommand: ui.airPanelObject, SentryCtrlCommand: ui.sentryPanelObject,
            HeroDeployModeEventCommand: ui.heroPanelObject, MapClickCmd: ui.mapPanelObject,
            CustomControl: ui.bytePanelObject
        };
        if (topic === "RobotPerformanceSelectionCommand") ui.performanceFeedback = message;
        else if (panels[topic]) panels[topic].feedback = message;
    }
    function applyWindowPreference() {
        const mode = localUiSettings.values.windowMode;
        if (mode === 2) {
            if (!root.fullscreen) root.beforeFullscreen = root.visibility;
            root.showFullScreen();
        } else if (mode === 1) root.showMaximized();
        else root.showNormal();
    }
    // 重连也会重载身份偏好；窗口模式只在启动或用户明确应用设置时改变。
    Timer { interval: 1; running: true; onTriggered: root.applyWindowPreference() }
    OperatorUiShortcuts { id: uiKeys; ui: root.ui; owner: root; inputState: inputController }
    Connections {
        target: inputController
        ignoreUnknownSignals: true
        function onKeyReleased(key) { uiKeys.releaseKey(key); }
        function onCaptureMenuRequested() { root.ui.openPanel("settings"); }
    }

    Binding {
        target: inputController
        property: "enabled"
        value: root.active && !root.auxiliaryInteractionBlocked && clientBackend.connected && !root.ui.modalActive && !root.ui.matchStateBlocksInput
    }
    Connections {
        target: clientBackend
        function onConnectionChanged() {
            if (clientBackend.connected && root.ui.loginOpen) root.ui.openPanel("none");
        }
    }
    Connections {
        target: root.ui
        function onPanelRequested(panel) {
            root.ui.openPanel(panel);
        }
        function onLoginRequested(robotId) {
            root.ui.openConnection(robotId);
            if(clientBackend.login(robotId)) root.ui.resetTransientState();
        }
        function onConnectionLoginRequested(robotId,host,port) {
            root.ui.openConnection(robotId,host,port);
            if(clientBackend.loginAt(robotId,host,port)) root.ui.resetTransientState();
        }
        function onConnectionSessionRequested(options) {
            if(options.video && !videoReceiver.configure(options.video))return;
            if(options.reconnect!==true && clientBackend.connected && clientBackend.clientId===options.robot_id
                && clientBackend.host===options.host && clientBackend.port===options.port) {
                root.ui.openPanel("none");return;
            }
            if(clientBackend.loginAt(options.robot_id,options.host,options.port)) {
                // 异步连接开始并不代表成功；保留地址和错误提示，收到 connected 后再收起。
                root.ui.resetTransientState();
            }
        }
        function onDisconnectRequested() {
            clientBackend.disconnectFromPlayer();
            root.ui.resetTransientState();
        }
        function onVideoConfigureRequested(options) { videoReceiver.configure(options); }
        function onVideoRestartRequested() { videoReceiver.restart(); }
        function onVideoStopRequested() { videoReceiver.stop(); }
        function onCommandRequested(topic, fields) { root.sendOperatorCommand(topic, fields); }
        function onProtocolCommandRequested(topic, fields) {
            let accepted = false;
            let reason = "";
            if (topic === "KeyboardMouseControl") {
                accepted = clientBackend.sendInputFields(fields);
                reason = accepted ? "键鼠字段已提交至 MQTT；请核对服务器接收记录" : "键鼠字段未发送：检查连接、数值范围与发送间隔";
            } else {
                accepted = extensionServices.operatorActions.sendCommand(topic, fields);
                reason = accepted ? "已提交至 MQTT；执行结果以回传为准" : extensionServices.operatorActions.commandFeedback?.reason || "发送未被接受";
            }
            root.ui.protocolPanelObject.commandFeedback = reason;
        }
        function onPerformanceRequested(fields) { root.sendOperatorCommand("RobotPerformanceSelectionCommand", fields); }
        function onAssemblyContextRequested(difficulty) {
            const actions = extensionServices.operatorActions;
            if (typeof actions?.confirmAssemblyDifficulty !== "function") {
                root.ui.engineerPanelObject.feedback = "当前宿主未提供人工参数确认入口";
                return;
            }
            actions.confirmAssemblyDifficulty(difficulty);
            root.ui.engineerPanelObject.feedback = actions.commandFeedback?.reason || "操作上下文未更新";
        }
        function onMapMarkRequested(fields) { root.sendOperatorCommand("MapClickCmd", fields); }
        function onCustomByteRequested(fields) { root.sendOperatorCommand("CustomControl", fields); }
        function onMouseCaptureRequested(capture) {
            // 只有用户明确操作且宿主条件满足才请求插件。旧插件无此可选方法时继续运行。
            if (capture && !root.active) {
                root.ui.inputCaptureFeedback = "请激活本窗口后启用捕获";
                return;
            }
            if (typeof inputController.requestMouseCapture !== "function") {
                root.ui.inputCaptureFeedback = "当前输入插件的平台捕获接口尚未接通";
                return;
            }
            const accepted = inputController.requestMouseCapture(capture);
            root.ui.inputCaptureFeedback = accepted ? "" : "本机捕获请求未成功，请查看插件状态";
        }
        function onLocalSettingsRequested(values) {
            root.localAlertFeedback = "";
            if (localUiSettings.apply(values)) root.applyWindowPreference();
        }
        function onLocalAlertTestRequested() {
            root.localAlertFeedback = extensionServices.testAlertTone() ? "本机提示音试听已提交；不代表赛事消息" : extensionServices.localAudioStatus;
        }
        function onDecisionRequested(question) { extensionServices.requestDecision(question); }
        function onInspectModelProviderRequested(configuration) {
            extensionServices.providerConfiguration?.inspect(configuration);
        }
        function onCancelDecisionRequested() { extensionServices.cancelDecision(); }
        function onNarrationRequested(text, priority, key) { extensionServices.narrate(text, priority, key); }
        function onTestSpeechRequested() { extensionServices.testSpeech(); }
        function onStopSpeechRequested() { extensionServices.stopSpeech(); }
        function onSpeakAdviceRequested() { extensionServices.speakAdvice(); }
        function onSpeakInputFactsRequested() { extensionServices.speakInputFacts(); }
    }
}
