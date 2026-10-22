import QtQuick
import "OperatorData.js" as Data

QtObject {
    id: root
    property var telemetry: null
    property int clientID: 3
    property string scenario: "nominal"
    property string visual: "ready"
    property string inputMode: "local"
    property var teamView: null
    property string degradationReason: ""
    property string phase: "idle"
    property string statusNote: ""
    property var advice: ({})
    property var decisionInput: ({})
    property bool snapshotFresh: false
    property int receivedAgeMs: 0
    property int sampleSequence: 1
    property double sampleCreatedAt: 0
    readonly property var decisionTrace: ({origin: "offline-preview", sender_id: "sample-client-" + clientID,
        snapshot_id: "sample-snapshot-" + sampleSequence, advice_id: "sample-advice-" + sampleSequence,
        model_source: "离线绘制示例模型", trust: "offline-sample", created_at_ms: sampleCreatedAt,
        received_age_ms: receivedAgeMs, input_mode: decisionInput.input_mode,
        team_view_id: decisionInput.team_view?.view_id, team_view_revision: decisionInput.team_view?.revision,
        degradation_reason: decisionInput.degradation_reason, player_export_verified: false, sender_verified: false})
    readonly property bool online: scenario !== "disconnected"
    readonly property bool decisionAvailable: online && (inputMode !== "team" || typeof teamView?.view_id === "string" && teamView?.remaining_ms > 0) && phase !== "disabled" && phase !== "busy" && telemetry?.freshness?.robotDynamic === "fresh"
    readonly property bool decisionInputFresh: online && (decisionInput.input_mode !== "team" || teamView?.view_id === decisionInput.team_view?.view_id && teamView?.revision === decisionInput.team_view?.revision && teamView?.remaining_ms > 0) && snapshotFresh && Object.keys(decisionInput?.groups?.robotDynamic ?? {}).length > 0
    readonly property var decisionDetails: ({active: phase !== "disabled", busy: phase === "busy", health: phase === "error" ? "timeout" : phase === "disabled" ? "disabled" : phase === "busy" ? "busy" : "ready", model: "离线绘制示例模型", api: "chat", timeout_ms: 15000})
    readonly property string decisionStatus: !online ? "离线样例：等待连接与新遥测" : phase === "disabled" ? "未启用 · 离线样例"
        : phase === "error" ? "离线样例：模型服务未返回有效建议" : phase === "busy" ? "离线演示：正在绘制分析状态"
        : statusNote || "可用 · 离线绘制样例"
    onVisualChanged: prepare.restart()
    onInputModeChanged: prepare.restart()
    onTeamViewChanged: if (inputMode === "team") prepare.restart()
    onDegradationReasonChanged: prepare.restart()
    onScenarioChanged: prepare.restart()
    onClientIDChanged: prepare.restart()
    Component.onCompleted: prepare.restart()

    function captureInput(historical) {
        if (inputMode === "team") {
            // 仅从已发布完整人工视图提取本机焦点；不把另一份本机遥测混入队伍截面。
            // 这是离线展示适配，不是生产收包、汇总、认证或决策逻辑。
            const focus = {}, excluded = [];
            for (const field of teamView?.fields ?? []) {
                if (field.source_node !== "sample-client-" + clientID || field.kind !== "official_player_client") continue;
                const keys = field.path.split(".");
                if (keys.length !== 2 || field.accepted !== true || field.state !== "fresh") { excluded.push(field.path); continue; }
                if (!focus[keys[0]]) focus[keys[0]] = {};
                focus[keys[0]][keys[1]] = field.value;
            }
            return {input_mode: "team", team_view: teamView?.view_id ? JSON.parse(JSON.stringify(teamView)) : null,
                client_id: clientID, connected: online, groups: focus, groups_origin: "published_team_view_focus",
                computed_facts: {}, unavailable_groups: ["未在完整视图提供的本机分组"],
                unavailable_fields: excluded, omitted_groups: ["未授权字段 / 原始字节 / 视频"]};
        }
        const groups = {}, freshness = {}, unavailable = [], omitted = [], unavailableFields = [];
        // 过期场景模拟先前有效请求；这是离线显示样例，不从旧生产遥测生成新请求。
        for (const group of Object.keys(telemetry?.freshness ?? {})) {
            const values = telemetry?.[group] ?? {};
            freshness[group] = historical ? Object.keys(values).length ? "fresh" : "missing" : telemetry.freshness[group];
            if (freshness[group] !== "fresh") { unavailable.push(group); continue; }
            if (["customByteBlock", "robotPath"].includes(group)) { omitted.push(group); continue; }
            groups[group] = {};
            for (const key of Object.keys(values)) {
                if (historical || Data.state(telemetry, group, key) === "fresh") groups[group][key] = JSON.parse(JSON.stringify(values[key]));
                else unavailableFields.push(group + "." + key);
            }
        }
        if (visual === "partial") {
            delete groups.robotStatic;
            freshness.robotStatic = "missing";
            if (groups.robotDynamic) delete groups.robotDynamic.remaining_ammo;
            unavailable.push("robotStatic");
            unavailableFields.push("robotDynamic.remaining_ammo");
        }
        if (visual === "zero" && groups.robotDynamic) {
            groups.robotDynamic.current_health = 0;
            groups.robotDynamic.remaining_ammo = 0;
        }
        const fixed = groups.robotStatic ?? {}, dynamic = groups.robotDynamic ?? {}, computed = {};
        for (const entry of [["current_health", "max_health", "health_percent"], ["current_heat", "max_heat", "heat_percent"]]) {
            if (typeof dynamic[entry[0]] === "number" && dynamic[entry[0]] >= 0 && typeof fixed[entry[1]] === "number" && fixed[entry[1]] > 0)
                computed[entry[2]] = Math.round(dynamic[entry[0]] / fixed[entry[1]] * 1000) / 10;
        }
        // 队伍输入只复制完整人工视图；这不是生产数据整合实现。
        return {input_mode: inputMode, degradation_reason: degradationReason,
            team_view: inputMode === "team" && teamView?.view_id ? JSON.parse(JSON.stringify(teamView)) : null,
            client_id: clientID, connected: true, groups: groups, freshness: freshness,
            unavailable_groups: unavailable, omitted_groups: omitted, unavailable_fields: unavailableFields, computed_facts: computed};
    }
    function makeAdvice(fresh) {
        const dynamic = decisionInput?.groups?.robotDynamic ?? {};
        let summary = "先核对允许弹量与热量，再根据战场状态决定下一步操作。";
        let rationale = "本次输入生命为 " + (dynamic.current_health ?? "未收") + "，热量为 " + (dynamic.current_heat ?? "未收") + "，允许弹量为 " + (dynamic.remaining_ammo ?? "未收") + "。这些数值属于请求快照。";
        if (visual === "partial") { summary = "本次输入缺少上限；先核对当前读数。"; rationale = "快照内没有静态上限和允许弹量，不据此推算比例或剩余弹量。"; }
        if (visual === "zero") { summary = "生命读数为零，先核对复活与链路状态。"; rationale = "本次快照生命和允许弹量均为零；零值与未收到不同。"; }
        if (visual === "long") rationale = ("此段是长依据绘制样例。请逐项核对生命、热量、允许弹量、比赛阶段和地图来源，明确哪些字段未提供或已被省略。建议只给出操作关注点，不会自动发出机器人指令。\n").repeat(6).slice(0, 500);
        if (decisionInput.input_mode === "team") {
            summary = "队伍视图已整合；先核对队友有效生命与资源，再决定支援。";
            rationale = "使用完整人工视图 " + (decisionInput.team_view?.view_id ?? "未提供") + "，版本 " + (decisionInput.team_view?.revision ?? "未提供") + "。逐字段过期、缺失和冲突项不作为当前依据。这是离线绘制样例。";
        }
        return {summary: summary, hud_summary: decisionInput.input_mode === "team" ? "核对队友生命与资源，再决定支援。" : visual === "zero" ? "生命读数为零；请核对复活与链路。" : "核对弹量与热量，再决定下一步。", rationale: rationale, key_reason: decisionInput.input_mode === "team" ? "视图 v" + (decisionInput.team_view?.revision ?? "—") + " · 旧值、冲突及未授权项排除。" : "生命 " + (dynamic.current_health ?? "—") + " · 热量 " + (dynamic.current_heat ?? "—") + " · 弹量 " + (dynamic.remaining_ammo ?? "—") + "，均来自本次快照。", priority: visual === "zero" ? "urgent" : "caution", focus: visual === "zero" ? "health" : "ammo", expires_in_ms: 5000, based_on_age_ms: 640, fresh: fresh};
    }
    function resetVisual() {
        response.stop(); expiry.stop(); advice = {}; decisionInput = {}; snapshotFresh = false; statusNote = "";
        receivedAgeMs = 0; sampleCreatedAt = Date.now();
        phase = ["long", "partial", "zero"].includes(visual) ? "ready" : visual === "question-long" ? "idle" : visual;
        if (!online || ["idle", "disabled"].includes(phase)) return;
        decisionInput = captureInput(phase === "expired");
        snapshotFresh = phase !== "expired";
        if (!["busy", "error"].includes(phase)) {
            advice = makeAdvice(decisionInputFresh);
            if (advice.fresh === true) expiry.restart();
        }
    }
    function request(question) {
        if (!decisionAvailable) return;
        response.stop(); expiry.stop(); decisionInput = captureInput(false); snapshotFresh = true;
        advice = {}; phase = "busy"; statusNote = "";
        sampleSequence += 1; receivedAgeMs = 0; sampleCreatedAt = Date.now();
        response.restart();
    }
    function cancel() {
        if (phase !== "busy") return;
        response.stop(); phase = "idle"; statusNote = "离线演示：请求已取消";
    }
    function expire() {
        if (!Object.keys(advice).length) return;
        advice = Object.assign({}, advice, {fresh: false}); snapshotFresh = false;
        phase = "expired"; statusNote = "离线演示：上次建议已失效";
    }
    property Timer prepare: Timer { interval: 1; onTriggered: root.resetVisual() }
    property Timer response: Timer {
        interval: 2200
        onTriggered: { root.phase = "ready"; root.receivedAgeMs = 0; root.sampleCreatedAt = Date.now(); root.advice = root.makeAdvice(root.decisionInputFresh); expiry.restart(); }
    }
    property Timer expiry: Timer { interval: 5000; onTriggered: root.expire() }
    property Timer ageDisplay: Timer { interval: 200; repeat: true; running: root.online && Object.keys(root.advice).length > 0; onTriggered: root.receivedAgeMs += interval }
}
