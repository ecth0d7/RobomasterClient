import QtQuick
import "UiFormat.js" as Format
import "OperatorData.js" as Data
import "OperatorDecisionPolicy.js" as DecisionPolicy
import "OperatorTeamConfigPolicy.js" as TeamConfigPolicy
import "OperatorSourcePolicy.js" as SourcePolicy
import "OperatorProviderPolicy.js" as ProviderPolicy
import "OperatorPreviewRules.js" as PreviewRules

OperatorWindow {
    id: root
    designPreview: true
    property int clientID: 3
    property string scenario: "nominal"
    property string panel: "none"
    property bool animatePreview: false
    property int motionFrame: 0
    property string dartVisual: "telemetry"
    property string exchangeVisual: "remote"
    property string injuryPage: "injury"
    property string helpPage: "general"
    property string keyVisual: "missing"
    property string fillVisual: "telemetry"
    property string ownVisual: "none"
    property string messageVisual: "nominal"
    property string scoreboardVisual: "telemetry"
    property string discoveryVisual: "auto"
    property string energyVisual:"telemetry"
    property string combatVisual:"telemetry"
    property string aerialVisual:"telemetry"
    property string airSupportVisual:"telemetry"
    property string moduleVisual:"telemetry"
    property string vitalsVisual:"telemetry"
    property int vitalsFrame:0
    PreviewVitalsStates {id:vitalsMock;mode:root.vitalsVisual;robotId:root.clientID;scenario:root.scenario;frame:root.vitalsFrame}
    Timer {interval:200;repeat:true;running:root.vitalsVisual === "sequence";onTriggered:root.vitalsFrame+=1}
    property int moduleFrame:0
    PreviewModuleStates {id:moduleMock;mode:root.moduleVisual;robotId:root.clientID;scenario:root.scenario;frame:root.moduleFrame}
    ui.bottomStatusView:moduleMock.view
    ui.bottomStatusProjectionConnected:root.moduleVisual !== "telemetry" && moduleMock.projectionConnected
    ui.bottomStatusSessionId:root.moduleVisual === "telemetry" ? "" : moduleMock.sessionId
    Timer {interval:250;repeat:true;running:root.moduleVisual === "sequence";onTriggered:root.moduleFrame+=1}
    property int supportFrame:0
    PreviewAirSupportStates {id:supportMock;mode:root.airSupportVisual;robotId:root.clientID;scenario:root.scenario;frame:root.supportFrame}
    ui.airSupportSecondsVerified:supportMock.secondsVerified
    ui.airPanelObject.actionsAvailable:supportMock.controlAvailable
    Timer {
        interval:250;repeat:true;running:root.airSupportVisual === "sequence"
        onTriggered:root.supportFrame+=1
    }
    onAirSupportVisualChanged:supportDrawing.restart()
    onSupportFrameChanged:if(supportFrame%4 === 0)supportDrawing.restart()
    Timer {
        id:supportDrawing;interval:80
        onTriggered:{
            if(root.airSupportVisual === "sequence")root.ui.openPanel(root.supportFrame%60 < 4 || root.supportFrame%60 >= 56 ? "none" : "air");
            // 只摆出待确认外观，不调用select/confirm，不触发commandRequested。
            if(supportMock.selection >= 0){
                root.ui.airPanelObject.selectionContext=root.ui.airPanelObject.currentContext;
                root.ui.airPanelObject.selectedCommand=supportMock.selection;
            }
        }
    }
    PreviewEnergyStates {id:energyMock;mode:root.energyVisual;robotId:root.clientID}
    PreviewCombatStates {id:combatMock;mode:root.combatVisual;robotId:root.clientID}
    PreviewAirStates {
        id:airMock;mode:root.aerialVisual;robotId:root.clientID;scenario:root.scenario
        fillVisual:root.fillVisual;animated:root.animatePreview;motionFrame:root.motionFrame
    }
    ui.airDisplayData:airMock.view
    ui.airDisplayProjectionConnected:airMock.projectionConnected
    ui.airDisplaySessionId:airMock.sessionId
    PreviewDiscoveries {
        id:discoveryMock;mode:root.discoveryVisual;robotId:root.clientID
        aggregationPhase:aggregationPreview.phase;sourcePhase:root.sourceVisual
    }
    ui.localDiscoveryView:discoveryMock.localView
    ui.teamDiscoveryView:discoveryMock.teamView
    ui.localDiscoveryProjectionConnected:discoveryMock.localAvailable
    ui.teamDiscoveryProjectionConnected:discoveryMock.teamAvailable
    ui.discoveryContext:discoveryMock.context
    PreviewMatchStates { id:matchMock;mode:root.scoreboardVisual }
    PreviewMessages {
        id:messageMock;mode:root.messageVisual;clientId:root.clientID
        raceRevision:root.ui.raceMessageViewRevision;robotRevision:root.ui.robotMessageViewRevision
    }
    ui.dashboardObject.raceMessagesAvailable: messageMock.raceSourcePresent && root.scenario!=="disconnected"
        && matchMock.connected && discoveryMock.playerConnected && energyMock.connected && combatMock.connected && airMock.playerConnected && supportMock.playerConnected && moduleMock.playerConnected && vitalsMock.connected
    ui.robotMessageProducerConnected: messageMock.robotSourcePresent
    ui.robotEvents: messageMock.robotEntries
    PreviewOwnStates { id: ownMock; mode: root.ownVisual; robotId: root.clientID }
    ui.ownStatusItems: root.scenario === "disconnected" ? [] : ownMock.records
    ui.ownStatusSessionId: "mock-own-session"
    ui.combatCountdownSecondsVerified: root.combatVisual === "telemetry" ? ownMock.secondsVerified : combatMock.secondsVerified
    property string layoutVisual: "normal"
    property string layoutPage: "hud"
    ui.layoutPanelObject.panelsTab: root.layoutPage === "panels"
    onLayoutVisualChanged: layoutDrawing.restart()
    Timer {
        id: layoutDrawing; interval: 1
        onTriggered: if (root.layoutVisual === "hidden") {
            // 只模拟从已有偏好恢复：不绕过正式编辑守卫，不写QtSettings。
            const roles = {}; roles[String(root.clientID % 100)] = {advice:false, map:false};
            root.ui.layoutStateObject.restore(JSON.stringify({version:1,roles:roles}));
        }
    }
    PreviewInput { id:inputMock;mode:root.keyVisual }
    ui.inputState: root.keyVisual === "missing" ? null : inputMock
    Connections {
        target:root.ui
        function onMouseCaptureRequested(capture) { inputMock.requestMouseCapture(capture); }
    }
    ui.globalPanelShortcutsAvailable: true
    ui.dashboardObject.vitalsObject.previewOnly: true
    ui.dashboardObject.vitalsObject.experienceRulesVersion: root.vitalsVisual === "telemetry" ? "2026-v2.2.0" : vitalsMock.rulesVersion
    ui.fortressProgressScale: ({seconds:60,unit:"s",state:"fresh",source_kind:"mock",validation:"mock",source_id:"mock-ring-scale-not-official-rule"})
    OperatorUiShortcuts { ui: root.ui; owner: root; inputState: root.ui.inputState }
    ui.helpPanelObject.page: ({general: 0, role: 1, input: 3})[root.helpPage] ?? 0
    property string roleVisual: "telemetry"
    property string byteVisual: "nominal"
    property string byteDraft: "none"
    property string decisionVisual: "ready"
    property string speechVisual: "idle"
    property string speechDraft: "none"
    property string speechPage: "service"
    property string bridgeVisual: "nominal"
    property string bridgePage: "summary"
    property string matchVisual: "battle"
    property string decisionDemo: "none"
    property string aggregationVisual: "ready"
    property string aggregationPage: "view"
    property string inputVisual: "local"
    property string advicePositionVisual: "race"
    property string adviceDensityVisual: "compact"
    property string connectionVisual: "nominal"
    property string startupVisual: "ready"
    property string startupPage: "connection"
    property string teamConfigVisual: "absent"
    property string teamConfigPage: "identity"
    property string teamConfigSeed: "empty"
    property string sourceVisual: "absent"
    property string sourcePage: "sources"
    property string sourceSeed: "empty"
    property string providerVisual: "pending"
    property string providerPage: "connection"
    property string providerKind: "deepseek"
    property string settingsVisual: "ready"
    property string buffVisual: "none"
    property string baseVisual: "telemetry"
    property string outpostVisual: "telemetry"
    property string outpostDetailVisual: "known"
    property string outpostDefenseVisual: "missing"
    ui.outpostDefenseItems: {
        if (root.outpostDefenseVisual === "missing" || root.scenario === "disconnected") return [];
        const now = Date.now();
        const make = team => ({robot_id:root.clientID,team:team,defense_percent:root.outpostDefenseVisual === "zero" ? 0 : 50,
            defense_percent_state:root.outpostDefenseVisual === "stale" ? "stale" : "fresh",unit:"percent",
            source_kind:"mock",validation:"mock",source_id:"mock-outpost-defense",snapshot_id:"mock-defense-"+team+"-"+root.motionFrame,
            state:root.outpostDefenseVisual === "stale" ? "stale" : "fresh",lifecycle:"active",
            produced_at_ms:root.outpostDefenseVisual === "expired" ? now-16000 : now,received_at_ms:now,ttl_ms:15000});
        return root.outpostDefenseVisual === "duplicate" ? [make("red"),make("red")] : [make("red"),make("blue")];
    }
    property string rosterVisual: "nominal"
    ui.rosterProjectionItems: {
        if (root.rosterVisual === "local-only" || root.scenario === "disconnected") return [];
        const now=Date.now();
        const ids=[1,2,3,4,7,101,102,103,104,107,6,106];
        const bullets=[50,0,120,100,200,70,15,80,160,110,540,480];
        const records=ids.map((id,index)=>({robot_id:id,source_robot_id:root.rosterVisual === "foreign" ? id+1 : id,
            max_health:(id===root.clientID?preview.ownRuleSample:PreviewRules.sample(id)).maximum,max_health_state:root.rosterVisual === "stale" || root.scenario === "hud-stale" ? "stale" : "fresh",
            remaining_bullets:root.rosterVisual === "zero" ? 0 : bullets[index],
            remaining_bullets_state:root.rosterVisual === "stale" || root.scenario === "hud-stale" ? "stale" : "fresh",
            level:(id===root.clientID?preview.ownRuleSample:PreviewRules.sample(id)).level,level_state:root.rosterVisual === "stale" || root.scenario === "hud-stale" ? "stale" : "fresh",
            source_kind:"mock",validation:"mock",source_id:"mock-official-client-"+id,snapshot_id:"mock-roster-"+id+"-"+root.motionFrame,
            state:root.rosterVisual === "stale" || root.scenario === "hud-stale" ? "stale" : "fresh",lifecycle:"active",
            produced_at_ms:root.rosterVisual === "expired" ? now-31000 : now,received_at_ms:now,ttl_ms:30000}));
        if (root.rosterVisual === "partial") {
            delete records[1].max_health;delete records[6].max_health;
            delete records[3].remaining_bullets;delete records[8].remaining_bullets;
            delete records[0].level;delete records[5].level;
        }
        if (root.scenario === "hud-partial") {
            records.filter(e=>e.robot_id === root.clientID).forEach(e=>{e.max_health_state="stale";e.remaining_bullets_state="stale";});
        }
        if (root.rosterVisual === "conflict") records[11]=Object.assign({},records[0],{snapshot_id:"mock-duplicate",max_health:1000});
        return records;
    }
    ui.outpostRebuildItems: {
        if (preview.outpostDrawingState !== "rebuilding" || root.outpostDetailVisual === "missing"
            || root.scenario === "hud-partial" || root.scenario === "disconnected") return [];
        const now = Date.now();
        const entry = {robot_id:root.clientID,team:root.clientID>100?"blue":"red",team_progress:0.45,robot_progress:0.3,remaining_count:1,
            team_progress_state:"fresh",robot_progress_state:root.outpostDetailVisual === "mixed" ? "stale" : "fresh",
            remaining_count_state:root.outpostDetailVisual === "mixed" ? "stale" : "fresh",
            source_kind:"mock",validation:"mock",source_id:"mock-player-rebuild",snapshot_id:"mock-outpost-"+preview.outpostDrawingStep,
            state:root.outpostDetailVisual === "stale" ? "stale" : "fresh",lifecycle:"active",
            produced_at_ms:root.outpostDetailVisual === "expired" ? now - 16000 : now,received_at_ms:now,ttl_ms:15000};
        if (root.outpostDetailVisual === "partial") { delete entry.robot_progress;delete entry.remaining_count; }
        if (root.outpostDetailVisual === "zero") { entry.team_progress=0;entry.robot_progress=0;entry.remaining_count=0; }
        return root.outpostDetailVisual === "duplicate" ? [entry,Object.assign({},entry,{snapshot_id:"mock-conflict"})] : [entry];
    }
    ui.buffProjectionItems: {
        if (root.buffVisual === "none" || root.scenario === "disconnected") return [];
        const now = Date.now();
        let samples = [[1,15],[2,50],[2,-30],[3,20],[4,25],[5,10],[6,120],[7,1],[99,4]];
        if (root.buffVisual === "many") samples = samples.concat(Array.from({length:7}, (_,i) => [100+i,i]));
        if (root.buffVisual === "nominal" || root.buffVisual === "dynamic") samples = [[1,15],[3,20],[5,10]];
        return samples.map((sample,index) => {
            const record = {robot_id: root.buffVisual === "foreign" ? (root.clientID > 100 ? 3 : 103) : root.clientID,
                buff_type: sample[0], buff_level: sample[1], buff_max_time: 30,
                buff_left_time: ["zero","active-zero"].includes(root.buffVisual) ? 0 : root.buffVisual === "full" ? 30 : Math.max(0, 24 - root.motionFrame),
                source_kind:"mock", source_id:"mock-official-client", snapshot_id:"mock-buff-" + root.motionFrame,
                validation:"mock", state:root.buffVisual === "stale" ? "stale" : "fresh",
                lifecycle:root.buffVisual === "zero" ? "ended" : "active", time_unit:"s", time_unit_verified:true,
                produced_at_ms:now, received_at_ms:now, ttl_ms:root.buffVisual === "expires" ? 4000 : 30000,
                fresh_for_ms:root.buffVisual === "expires" ? 1500 : 20000,collection_complete:true,
                field_states:{buff_type:"fresh",buff_level:"fresh",buff_max_time:"fresh",buff_left_time:"fresh"}};
            if (root.buffVisual === "partial") { delete record.buff_level; delete record.buff_max_time; }
            if (root.buffVisual === "raw") { record.time_unit="raw";record.time_unit_verified=false; }
            if (root.buffVisual === "timing-conflict") { record.buff_left_time=40;record.produced_at_ms=now-15000; }
            if (root.buffVisual === "field-stale") record.field_states.buff_left_time="stale";
            if (root.buffVisual === "freshness-missing") delete record.fresh_for_ms;
            return record;
        });
    }
    onSettingsVisualChanged: if (settingsVisual === "save-failed") ui.settingsFeedback = "mock：本地设置已应用，未保存：偏好文件正被另一个实例使用；原文件保留，不代表真实保存操作。"
    ui.settingsPanelObject.localApplyAvailable: root.settingsVisual !== "pending"
    ui.settingsPanelObject.sensitivityAvailable: root.settingsVisual !== "pending"
    ui.settingsPanelObject.performanceAvailable: root.settingsVisual !== "pending"
    onProviderVisualChanged: providerReview.restart()
    Timer {
        id: providerReview
        interval: 1
        onTriggered: {
            if (root.panel !== "provider") return;
            // 同一模型场景的背景建议同步退化；只影响离线样例，不提供生产能力。
            root.decisionVisual = ({pending: "idle", ready: "ready", busy: "busy", error: "error", offline: "disabled"})[root.providerVisual] ?? "idle";
        }
    }
    onProviderPageChanged: ui.providerPanelObject.page = providerPage === "limits" ? 1 : providerPage === "inputs" ? 2 : providerPage === "runtime" ? 3 : 0
    onProviderKindChanged: providerDrawing.restart()
    OperatorProviderPreview { id: providerPreview; visual: root.providerVisual }
    Timer { id: providerDrawing; interval: 1; onTriggered: root.ui.providerPreferencesObject.save(ProviderPolicy.defaults(root.providerKind)) }
    onSourceSeedChanged: sourceDrawing.restart()
    onSourcePageChanged: ui.sourcePanelObject.page = sourcePage === "data" ? 1 : sourcePage === "coordinates" ? 2 : sourcePage === "status" ? 3 : 0
    OperatorSourcePreview { id: sourcePreview; visual: root.sourceVisual }
    Timer {
        id: sourceDrawing
        interval: 1
        onTriggered: {
            if (root.sourceSeed !== "sample") return;
            const value = SourcePolicy.sourceDefaults();
            Object.assign(value, {id: "mock-camera", label: "模拟视觉源 · mock", kind: "local_vision", sensorId: "camera-mock",
                adapterId: "example.mock.v1", transport: "mock", endpoint: "fixture.only", schemaId: "example.observation",
                itemType: "target_observation", unit: "m", clockDomain: "mock-clock", spatial: true,
                frameId: "camera.mock", frameRevision: "calibration-mock-1", confidenceDefinition: "人工绘制分数，不代表真实算法校准"});
            value.uses = {hud: true};
            root.ui.sourcePreferencesObject.save({sources: [value]});
            root.ui.sourcePanelObject.selectSource(0);
        }
    }
    onTeamConfigSeedChanged: teamConfigDrawing.restart()
    Timer {
        id: teamConfigDrawing
        interval: 1
        onTriggered: {
            if (root.teamConfigSeed !== "sample") return;
            const value = TeamConfigPolicy.defaults();
            const camp = root.clientID > 100 ? 100 : 0;
            Object.assign(value, {teamId: "sample-team", nodeId: "sample-client-" + root.clientID, displayName: "本机配置 · mock",
                matchId: "mock-match", epoch: "mock-epoch-not-live", configurationRevision: "mock-config-7",
                clocksSynchronized: true, maxClockSkewMs: "250", teamWideSharingConfirmed: true, canSend: true, canAggregate: true,
                caFile: "certs/mock-ca.pem", certificateFile: "certs/mock-client.pem", publisherId: "sample-client-" + (camp + 1), voiceNodeId: "sample-client-" + (camp + 1)});
            value.peers = [
                {nodeId: "sample-client-" + (camp + 1), robotId: camp + 1, label: "英雄节点 · mock", certificateFile: "certs/mock-hero-public.pem", fingerprint: "a".repeat(64), canSend: true, canAggregate: true, canVoice: true, canHear: true},
                {nodeId: "sample-client-" + (camp + 7), robotId: camp + 7, label: "哨兵节点 · mock", certificateFile: "certs/mock-sentry-public.pem", fingerprint: "b".repeat(64), canSend: true, canAggregate: false, canVoice: false, canHear: true}
            ].filter(peer => peer.robotId !== root.clientID);
            if (!value.peers.some(peer => peer.nodeId === value.publisherId)) { value.publisherId = value.nodeId; value.voiceNodeId = value.nodeId; }
            value.permissions.health = {hud: true, alerts: true};
            value.permissions.visionDiscoveries = {hud: true};
            root.ui.teamConfigPreferencesObject.save(value);
        }
    }
    onTeamConfigPageChanged: ui.teamConfigPanelObject.page = teamConfigPage === "members" ? 1 : teamConfigPage === "uses" ? 2 : teamConfigPage === "status" ? 3 : 0
    OperatorTeamConfigPreview { id: teamConfigPreview; visual: root.teamConfigVisual }
    onStartupPageChanged: ui.startupPanelObject.page = startupPage === "video" ? 1 : startupPage === "plugins" ? 2 : startupPage === "runtime" ? 3 : 0
    OperatorStartupPreview { id: startupPreview; visual: root.startupVisual; setupOnly: root.matchVisual === "offline-preparation" }
    onAdvicePositionVisualChanged: inputDrawing.restart()
    onAdviceDensityVisualChanged: inputDrawing.restart()
    onInputVisualChanged: inputDrawing.restart()
    onAggregationPageChanged: ui.aggregationPanelObject.detailTab = aggregationPage === "fields" ? 1 : aggregationPage === "excluded" ? 2 : aggregationPage === "discoveries" ? 3 : 0
    OperatorTeamAggregationPreview { id: aggregationPreview; visual: root.aggregationVisual }
    onDecisionDemoChanged: if (decisionDemo === "hud") demoHudStart.restart()
    OperatorBridgePreview { id: bridgePreview; visual: root.bridgeVisual }
    OperatorSpeechPreview { id: speechPreview; visual: root.speechVisual }
    OperatorDecisionPreview {
        id: decisionPreview
        telemetry: preview
        clientID: root.clientID
        scenario: root.scenario
        visual: root.decisionVisual
        inputMode: root.inputVisual === "team" ? "team" : "local"
        teamView: aggregationPreview.view
        degradationReason: root.inputVisual === "fallback" ? "汇总插件断连 · 按已保存偏好使用本机" : ""
    }
    readonly property bool rolePanelSelected: ["role", "dart", "rune", "engineer", "air", "sentry", "hero"].includes(panel)
    PreviewData {
        id: preview
        scoreboardDrawing: root.scoreboardVisual === "telemetry" ? null : matchMock
        ownCombatDrawing: root.combatVisual === "telemetry" ? ownMock.combatDrawing : combatMock.drawing
        ownEnergyDrawing:root.energyVisual === "telemetry" ? null : energyMock
        ownAirDrawing:root.aerialVisual === "telemetry" ? null : airMock
        ownSupportDrawing:root.airSupportVisual === "telemetry" ? null : supportMock
        ownModuleDrawing:root.moduleVisual === "telemetry" ? null : moduleMock
        ownVitalsDrawing:root.vitalsVisual === "telemetry" ? null : vitalsMock
        clientID: root.clientID
        scenario: root.scenario
        baseVisual: root.baseVisual
        outpostVisual: root.outpostVisual
        rosterVisual: root.rosterVisual
        fixtureLevel: root.rosterVisual === "upgrade" ? root.motionFrame%10+1 : 2
        fillVisual: root.fillVisual
        dartVisual: root.dartVisual
        exchangeVisual: root.exchangeVisual
        roleVisual: root.roleVisual
        byteVisual: root.byteVisual
        matchVisual: root.matchVisual
        // 原始字段查看的独立mock消息，不把单消息当成全部生效增益。
        buff: root.buffVisual === "none" || root.scenario === "disconnected" ? ({}) : ({
            robot_id: root.clientID, buff_type: 1, buff_level: 15, buff_max_time: 30, buff_left_time: 24
        })
    }
    onPanelChanged: { ui.openPanel(panel); if (panel === "provider") providerReview.restart(); }
    Component.onCompleted: ui.openPanel(panel)
    onByteDraftChanged: if (byteDraft === "utf8") ui.bytePanelObject.setDraft(2, "RM 机器人")
    onDecisionVisualChanged: if (decisionVisual === "question-long") ui.decisionInspectorObject.setQuestion("样例 ".repeat(170).slice(0, 501))
    onSpeechDraftChanged: if (speechDraft === "long") ui.speechPanelObject.setText("语音样例 ".repeat(60).slice(0, 281))
    onSpeechPageChanged: ui.speechPanelObject.detailsTab = speechPage === "audio" ? 1 : 0
    onBridgePageChanged: ui.bridgePanelObject.detailTab = bridgePage === "fields" ? 1 : bridgePage === "raw" ? 2 : 0
    ui.telemetry: preview
    ui.clientID: root.clientID
    // 独立朝向快照明确标mock；雷达原数组没有yaw字段，绝不把样例并入正式遥测。
    ui.mapHeadingItems: {
        if (root.scenario === "disconnected" || root.scenario === "hud-partial") return [];
        const now = Date.now(), enemyBase = root.clientID > 100 ? 0 : 100;
        return [1, 2].map((role, index) => ({
            robot_id: enemyBase + role, yaw_deg: (index ? 210 : 90) + root.motionFrame * 30,
            source_kind: "mock", source_id: "mock-client-" + (enemyBase + role),
            source_robot_id: enemyBase + role, sensor_id: "mock-heading",
            snapshot_id: "mock-map-" + root.motionFrame, validation: "mock", confidence: 1,
            frame_id: "rm2026.field", unit: "deg", north_zero: true, clockwise: true,
            lifecycle: "active", state: root.scenario === "hud-stale" ? "stale" : "fresh",
            produced_at_ms: now, received_at_ms: now, fresh_for_ms: 15000, ttl_ms: 20000
        }));
    }
    // 诊断专用样例不绑定 UdpVideoDisplay，也不启动接收器或本地服务。
    ui.connectionState: root.clientID === 0 || root.scenario === "disconnected" || !matchMock.connected || !discoveryMock.playerConnected || !energyMock.connected || !combatMock.connected || !airMock.playerConnected || !supportMock.playerConnected || !moduleMock.playerConnected || !vitalsMock.connected || root.matchVisual === "offline-preparation" ? null : ({
        connected: true, connecting: false, status: "离线样例 · 已连接",
        receiveDiagnostics: {received: 328, delivered: 326, dropped: 0,
            pending_messages: 2, pending_bytes: 640, maximum_messages: 256,
            maximum_bytes: 1048576, decode_errors: root.scenario === "hud-stale" ? 1 : 0,
            last_decode_error: root.scenario === "hud-stale" ? "离线样例：GameStatus 消息字段无法解析" : ""},
        commandHistory: [
            {topic: "RuneActivateCommand", accepted: false, reason: "离线样例：机关状态尚未更新", sequence: 2, recorded_at: "2026-10-13T08:41:20Z"},
            {topic: "CommonCommand", accepted: true, reason: "", sequence: 1, recorded_at: "2026-10-13T08:41:18Z"}
        ]
    })
    ui.diagnosticVideoState: root.scenario === "disconnected" ? null : ({
        status: root.scenario === "video-stalled" ? "离线样例 · 画面未更新" : "离线样例 · 接收图像",
        fps: root.scenario === "video-stalled" ? 0 : 59.5,
        diagnostics: {bound: true, port: 3334, codec: "hevc", datagrams: 12500,
            bytes: 15000000, invalid_datagrams: 0, compressed_frames: 901,
            decoded_frames: 900, converted_frames: 895, ui_skipped_frames: 5,
            decoder_errors: 0, last_frame_age_ms: root.scenario === "video-stalled" ? 4000 : 34}
    })
    ui.servicesState: root.scenario === "disconnected" && root.matchVisual !== "offline-preparation" ? null : ({
        startupConfiguration: startupPreview.runtime,
        teamSharingConfiguration: teamConfigPreview.runtime,
        sourceConfiguration: sourcePreview.runtime,
        providerConfiguration: providerPreview.runtime,
        aggregationStatus: aggregationPreview.status,
        aggregationDetails: aggregationPreview.details,
        aggregationView: aggregationPreview.view,
        discoveryProjection: aggregationPreview.projection,
        discoveryHudItems: (aggregationPreview.view.discoveries ?? []).map(item => Object.assign({}, item, {state: item.lifecycle})),
        decisionInputStatus: root.inputVisual === "wait" ? "队伍视图不可用 · 暂停队伍建议，本机功能继续" : root.inputVisual === "fallback" ? "已降级为本机数据 · 离线样例" : "离线输入范围样例",
        bridgeStatus: bridgePreview.bridgeStatus,
        bridgeDetails: bridgePreview.bridgeDetails,
        peers: bridgePreview.peers,
        decisionStatus: decisionPreview.decisionStatus,
        decisionDetails: decisionPreview.decisionDetails,
        decisionAvailable: decisionPreview.decisionAvailable,
        decisionInputFresh: decisionPreview.decisionInputFresh,
        decisionInput: decisionPreview.decisionInput,
        advice: decisionPreview.advice,
        decisionTrace: decisionPreview.decisionTrace,
        decisionSetupMode: root.matchVisual === "offline-preparation" ? "offline-preparation" : "live",
        decisionCapabilities: {setup_only: root.matchVisual === "offline-preparation", automatic: false, team_input: root.inputVisual === "team", team_voice: false, team_sharing: false},
        decisionModels: [
            {id: "sample.deepseek", title: "DeepSeek API · 离线样例", available: true},
            {id: "sample.process", title: "本地模型进程 · 离线样例", available: true},
            {id: "sample.rules", title: "规则建议 · 离线样例", available: true}
        ],
        teamIdentity: {team_id: "sample-team", verified: false},
        speechStatus: speechPreview.speechStatus,
        speechDetails: speechPreview.speechDetails
    })
    ui.runePanelObject.activationAllowed: ["idle", "holding"].includes(root.roleVisual)
                                         && Data.state(preview, "runeStatus", "rune_status") === "fresh"
    ui.runePanelObject.referenceHoldProgress: root.roleVisual === "holding" ? 0.6 : 0
    // 官方同步不含机关类型；只在明确离线样例补充独立的大机关上下文。
    ui.runePanelObject.largeRuneConfirmed: true
    ui.dartPanelObject.operatorAuthorized: [1, 2, 3, 4, 5].includes(root.clientID % 100)
    ui.dartPanelObject.operationPolicy: ({target: true, open: !["cooldown", "exhausted"].includes(root.dartVisual), close: true, launch: true})
    ui.dartPanelObject.controlDetails: root.dartVisual === "cooldown" ? ({cooldownSec: 14, cooldownSecState: "fresh", source: "mock · 独立资格显示源"})
                                      : root.dartVisual === "exhausted" ? ({remainingOpenings: 0, remainingOpeningsState: "fresh", source: "mock · 独立资格显示源"}) : null
    ui.exchangePanelObject.selectedTab: ["pending", "free-ready", "pay-ready"].includes(root.exchangeVisual) ? 2 : root.exchangeVisual === "onsite" ? 1 : 0
    ui.damagePanelObject.selectedTab: root.injuryPage === "modules" ? 1 : root.injuryPage === "hud" ? 2 : 0
    ui.exchangePanelObject.commandPolicy: ({
        remoteHeal: {allowed: [1, 3, 4, 5].includes(root.clientID % 100), paramVerified: false},
        remote17: {allowed: [1, 3, 4, 5].includes(root.clientID % 100), paramVerified: false},
        remote42: {allowed: root.clientID % 100 === 1, paramVerified: false},
        buy17: {allowed: [1, 3, 4, 5, 7].includes(root.clientID % 100), paramVerified: true, paramMode: "quantity"},
        buy42: {allowed: root.clientID % 100 === 1, paramVerified: true, paramMode: "quantity"},
        free: {allowed: [1, 2, 3, 4, 5, 7].includes(root.clientID % 100), paramVerified: true, paramMode: "none"},
        paid: {allowed: [1, 2, 3, 4, 5, 7].includes(root.clientID % 100), paramVerified: true, paramMode: "none"}
    })
    onRoleVisualChanged: roleReview.restart()
    Timer {
        id: roleReview
        interval: 1
        onTriggered: {
            root.ui.engineerPanelObject.selecting = ["telemetry", "idle"].includes(root.roleVisual);
            root.ui.engineerPanelObject.assemblyDifficulty = ["level4", "complete"].includes(root.roleVisual) ? 4
                                                            : ["active", "confirm", "failed"].includes(root.roleVisual) ? 3 : null;
            root.ui.engineerPanelObject.assemblyContextValid = ["active", "confirm", "level4", "complete", "failed"].includes(root.roleVisual);
            root.ui.engineerPanelObject.outcome = root.roleVisual === "failed" ? "failed"
                                                  : root.roleVisual === "complete" ? "success" : "";
            root.ui.engineerPanelObject.outcomeVerified = ["failed", "complete"].includes(root.roleVisual);
            root.ui.engineerPanelObject.outcomeSource = "mock · 事件15绘制";
        }
    }
    onDartVisualChanged: dartReview.restart()
    Timer {
        id: dartReview
        interval: 1
        onTriggered: if (root.panel === "dart" && root.dartVisual === "confirm") root.ui.dartPanelObject.selectAction("open")
    }
    ui.mqttConnecting: root.connectionVisual === "connecting"
    ui.mqttStatusMessage: root.connectionVisual === "connecting" ? "离线样例 · 正在等待选手端回应" : root.connectionVisual === "error" ? "离线样例 · 连接失败，请检查选手端导出与本地设置" : "离线绘制预览"
    Connections {
        target: root.ui.decisionPreferencesObject
        function onEdited() { if (root.decisionDemo === "sequence") demoBattle.restart(); }
    }
    Timer {
        id: demoBattle
        interval: 1800
        onTriggered: {
            root.matchVisual = "battle";
            // 只演示赛前保存到比赛锁定及常驻 HUD，不启动自动生产调度。
            decisionPreview.request("离线策略样例");
            demoDisconnect.restart();
        }
    }
    Timer {
        id: inputDrawing
        interval: 1
        onTriggered: {
            // 仅 CLI 绘制样例设置窗口内偏好；不触发生产模型或插件。
            root.ui.decisionPreferencesObject.save(Object.assign({}, root.ui.decisionPreferencesObject.current,
                {inputMode: root.inputVisual === "local" ? "local" : "team", teamFallback: root.inputVisual === "fallback" ? "local" : "wait", aggregationEnabled: root.inputVisual !== "local", advicePosition: root.advicePositionVisual, adviceDensity: root.adviceDensityVisual}));
            if (root.inputVisual === "wait") decisionPreview.cancel();
        }
    }
    Timer { id: demoDisconnect; interval: 11000; onTriggered: root.scenario = "disconnected" }
    Timer {
        id: demoHudStart
        interval: 4500
        onTriggered: {
            root.ui.decisionPreferencesObject.save(Object.assign(DecisionPolicy.defaults(), {modelId: "sample.deepseek", autoAdvice: true, voiceEnabled: true, shareEnabled: true, shareFields: ["health", "advice"]}));
            decisionPreview.request("离线 HUD 状态样例");
            demoDisconnect.restart();
        }
    }
    Connections {
        target: root.ui
        function onLocalAlertTestRequested() { root.ui.settingsFeedback = "离线样例：试听意图已记录，不播放音频"; }
        function onPanelRequested(panel) { root.ui.openPanel(panel); }
        function onLoginRequested(robotID) { root.clientID = robotID; root.ui.openPanel("none"); }
        function onLocalSettingsRequested(values) {
            root.ui.operatorSettings = Object.assign({}, values);
            root.ui.settingsFeedback = "离线预览 · 已更新本窗口的演示设置";
            if (values.windowMode === 2) root.showFullScreen();
            else if (values.windowMode === 1) root.showMaximized();
            else root.showNormal();
        }
        function onCommandRequested(topic, fields) {
            if (topic === "SentryCtrlCommand") root.ui.sentryPanelObject.feedback = "预览已记录 Cmd " + fields.command_id + " · 未发送";
            if (topic === "HeroDeployModeEventCommand") root.ui.heroPanelObject.feedback = "预览已记录mode=" + fields.mode + " · 未发送";
            if (topic === "AssemblyCommand") root.ui.engineerPanelObject.feedback = "mock · op=" + fields.operation + " / 难度" + fields.difficulty + " · 未发送";
            if (topic === "AirSupportCommand") root.ui.airPanelObject.feedback = "mock · Cmd " + fields.command_id + " · 未发送";
            if (topic === "RuneActivateCommand") root.ui.runePanelObject.feedback = "mock · activate=" + fields.activate + " · 未发送";
            if (topic === "DartCommand") root.ui.dartPanelObject.feedback = "mock · " + JSON.stringify(fields) + " · 未发送";
            if (topic === "CommonCommand") root.ui.exchangePanelObject.feedback = "mock · " + JSON.stringify(fields) + " · 未发送";
        }
        function onPerformanceRequested(fields) {
            root.ui.performanceFeedback = "预览已记录 · 未发送";
        }
        function onDecisionRequested(question) { decisionPreview.request(question); }
        function onCancelDecisionRequested() { decisionPreview.cancel(); }
        // 只改变离线显示状态；不调用 ServiceHub 或任何语音引擎。
        function onNarrationRequested(text, priority, key) { speechPreview.submit(); }
        function onTestSpeechRequested() { speechPreview.submit(); }
        function onStopSpeechRequested() { speechPreview.stop(); }
    }
    ui.events: messageMock.raceEntries
    // 只推进离线样例以观察血条、热量环与秒数动画；不启动 MQTT、UDP 或机器人输入。
    Shortcut { sequence: "A"; enabled: !root.ui.modalActive && root.energyVisual === "telemetry" && root.combatVisual === "telemetry" && root.aerialVisual === "telemetry" && root.airSupportVisual === "telemetry" && root.moduleVisual === "telemetry" && root.vitalsVisual === "telemetry"; onActivated: root.animatePreview = !root.animatePreview }
    Timer {
        interval: 1000
        repeat: true
        running: root.animatePreview && root.energyVisual === "telemetry" && root.combatVisual === "telemetry" && root.aerialVisual === "telemetry" && root.airSupportVisual === "telemetry" && root.moduleVisual === "telemetry" && root.vitalsVisual === "telemetry"
        onTriggered: {
            root.motionFrame += 1;
            const cap=preview.robotStatic.max_health;
            const health=cap===undefined?undefined:Math.floor(cap*[0.8,0.65,0.4,0.9,1,0.7][root.motionFrame%6]);
            const experience=PreviewRules.experience(preview.fixtureLevel,(root.motionFrame%5)/5);
            preview.robotDynamic = Object.assign({}, preview.robotDynamic, {
                current_health: health,
                current_experience:preview.ownRuleSample.level===undefined?undefined:experience.current,
                experience_for_upgrade:preview.ownRuleSample.level===undefined?undefined:experience.remaining,
                current_heat: (root.motionFrame % 12) * 22,
                remaining_ammo: root.clientID % 100 === 6 ? 750 - (root.motionFrame * 90) % 750
                                                        : 120 - root.motionFrame % 120,
                current_chassis_energy: 100 - root.motionFrame % 80
            });
            if (root.scoreboardVisual === "telemetry") {
                preview.gameStatus = Object.assign({}, preview.gameStatus, {
                    stage_countdown_sec: Math.max(0, (root.scenario === "final-seconds" ? 7 : 187) - root.motionFrame)
                });
            }
            preview.robotPosition = Object.assign({}, preview.robotPosition, {
                yaw: (24 + root.motionFrame * 30) % 360
            });
        }
    }
}
