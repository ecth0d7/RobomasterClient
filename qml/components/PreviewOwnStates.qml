import QtQuick

// 仅离线绘制；没有输入控制器、设备、MQTT或判罚计数累加。
QtObject {
    id: root
    property string mode: "none"
    property int robotId: 3
    property double startedAt: Date.now()
    property double clockNow: Date.now()
    property int step: 0
    readonly property string phase: mode === "sequence"
        ? ["countdown","out","yellow","quantity","weak","cutoff","power","all","unknown-timer","old","conflict","none"][step % 12] : mode
    onModeChanged: { step = 0; startedAt = Date.now(); clockNow = startedAt; }
    onPhaseChanged: startedAt = Date.now()
    property Timer cycle: Timer { interval: 1600; repeat: true; running: root.mode === "sequence"; onTriggered: root.step += 1 }
    property Timer tick: Timer { interval: 250; repeat: true; running: ["countdown","sequence"].includes(root.mode); onTriggered: root.clockNow = Date.now() }
    readonly property var combatDrawing: phase === "none" ? null : ({
        flag: phase === "missing" ? undefined : ["out","old","conflict"].includes(phase),
        countdown: phase === "missing" || phase === "partial" ? undefined : phase === "conflict" ? 3
            : phase === "countdown" || phase === "raw" ? Math.max(0,5 - Math.floor((clockNow-startedAt)/1000)) : 0,
        flag_state: phase === "old" ? "stale" : "fresh",
        countdown_state: phase === "old" ? "stale" : "fresh"
    })
    readonly property bool secondsVerified: phase !== "raw"
    readonly property var records: {
        const card = ["yellow","quantity","bilateral","red"].includes(phase);
        const all = ["all","old","field-old","ended","foreign","duplicate","expires","unknown-timer"].includes(phase);
        const kinds = all ? ["yellow_card","power_cutoff","respawn_weakness","power_bonus"]
            : card ? [phase === "red" ? "red_card" : phase === "bilateral" ? "bilateral_yellow" : "yellow_card"]
            : ({weak:["respawn_weakness"],cutoff:["power_cutoff"],power:["power_bonus"]})[phase] ?? [];
        const result = kinds.map((kind,index) => ({version:1,kind:kind,kind_verified:true,
            robot_id:phase === "foreign" ? robotId + 1 : robotId,applies_to_robot_verified:true,
            source_kind:"mock",validation:"mock",source_id:"mock-own-state-adapter",snapshot_id:"mock-own-"+step+"-"+index,
            session_id:"mock-own-session",round:1,round_verified:true,
            target_modules:kind === "power_cutoff" ? ["chassis"] : undefined,
            clock_basis:"local_receive",produced_at_ms:startedAt,received_at_ms:startedAt,
            ttl_ms:phase === "expires" ? 4000 : 30000,fresh_for_ms:phase === "expires" ? 1500 : 20000,
            state:phase === "old" ? "stale" : "fresh",lifecycle:phase === "ended" ? "ended" : "active",
            count:["yellow_card","bilateral_yellow","red_card"].includes(kind) ? 1 : undefined,
            count_semantics:phase === "quantity" || kind === "red_card" ? "current_penalty_quantity" : kind === "bilateral_yellow" ? "shared_penalty_quantity" : "robot_round_yellow_total",count_scope_verified:true,
            remaining_seconds:phase === "unknown-timer" ? undefined : 5,time_unit:"s",time_unit_verified:true,
            field_states:{count:"fresh",remaining_seconds:phase === "field-old" ? "stale" : "fresh"}
        }));
        if (phase === "duplicate" && result.length) result.push(Object.assign({},result[0],{snapshot_id:"mock-own-duplicate"}));
        return result;
    }
}
