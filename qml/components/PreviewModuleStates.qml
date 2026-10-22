import QtQuick
import "OperatorModuleData.js" as Modules

// 离线绘制视图：所有来源、认证标志和置信度都为mock，不连接提供者或改动命令。
QtObject {
    id: root
    property string mode: "telemetry"
    property int robotId: 3
    property string scenario: "nominal"
    property int frame: 0
    readonly property var phases: ["native","nominal","false","install","projected-old","partial",
        "source-offline","none","player-offline","conflict","low-confidence","nominal"]
    readonly property string phase: mode === "sequence" ? phases[Math.floor(frame/4)%phases.length] : mode
    readonly property bool playerConnected: !["offline","player-offline","requires-player"].includes(phase) && scenario !== "disconnected"
    readonly property bool projectionConnected: phase !== "source-offline"
    readonly property string sessionId: "mock-bottom-status-session"
    readonly property var staticValues: ({robot_id:phase === "identity-missing" ? undefined
        : phase === "foreign" ? (robotId > 100 ? robotId-100 : robotId+100) : robotId})
    readonly property var nativeValues: {
        const result={};
        if (phase === "none") return result;
        for (const module of Modules.modules) result[module.key]=phase === "zero" || phase === "false" ? 0 : phase === "install" ? 2 : 1;
        if (phase === "partial") {
            for (const key of Object.keys(result)) if (!["power_manager","uwb","armor"].includes(key)) delete result[key];
            result.power_manager=0;
        }
        if (phase === "invalid") {
            const values=["1",true,-1,0.5,3,255,4294967296,{},2,0,1];
            Modules.modules.forEach((module,index) => result[module.key]=values[index]);
        }
        return result;
    }
    readonly property var fieldStates: {
        const result={robotStatic:{},robotModule:{}};
        if (phase === "legacy") return result;
        if (staticValues.robot_id !== undefined) result.robotStatic.robot_id=phase === "identity-old" ? "stale" : "fresh";
        for (const key of Object.keys(nativeValues)) result.robotModule[key]=phase === "stale" || scenario === "hud-stale" ? "stale" : "fresh";
        if (phase === "partial") {result.robotModule.uwb="stale";result.robotModule.armor="missing";}
        return result;
    }
    readonly property var view: {
        const projected=["nominal","false","video-low","video-zero","rfid-only","vision","sensor","derived",
            "player-offline","requires-player","source-offline","projected-old","expired","retracted","duplicate",
            "unverified-source","clock-conflict","session","conflict","low-confidence","long","expires"];
        if (!projected.includes(phase)) return null;
        // 一次构造固定时间戳，只有样例阶段改变才换快照；不能每次绘制续命。
        const now=Date.now();
        let kinds=Modules.slots.map(slot => slot.kind);
        if (["rfid-only","vision"].includes(phase)) kinds=["rfid_recognition"];
        if (phase === "sensor") kinds=["chassis_power"];
        if (phase === "derived") kinds=["module_group"];
        const items=kinds.map((kind,index) => {
            const source=phase === "vision" ? "local_vision" : ["sensor","player-offline","requires-player"].includes(phase) ? "local_sensor"
                : phase === "derived" ? "derived" : "mock";
            const item={kind:kind,value:phase !== "false",source_kind:source,
                source_id:"mock-status-"+kind,source_robot_id:robotId,snapshot_id:"mock-status-"+phase+"-"+index,
                validation:source === "mock" ? "mock" : "verified",host_verified:source !== "mock",
                kind_verified:true,applies_to_robot_verified:true,confidence:phase === "low-confidence" ? 0.72 : 1,
                clock_basis:"local_receive",produced_at_ms:now,received_at_ms:now,
                fresh_for_ms:phase === "expires" ? 700 : 15000,ttl_ms:phase === "expires" ? 2200 : 20000,
                lifecycle:phase === "retracted" ? "retracted" : "active",state:phase === "projected-old" ? "stale" : "fresh"};
            if (source === "local_sensor" || source === "local_vision") item.sensor_id="mock-status-sensor";
            if (source === "derived") {item.dependencies_verified=true;item.based_on=[{source_id:"mock-status-input",snapshot_id:"mock-input-1"}];}
            if (phase === "requires-player") item.requires_player=true;
            if (kind === "video_link") {
                item.value=phase === "video-zero" || phase === "false" ? 0 : phase === "long" ? 9876543210.5 : 12.5;
                item.unit="Mbps";
                item.quality=phase === "video-zero" || phase === "false" ? "very_low" : phase === "video-low" ? "low" : "normal";
                item.quality_rules_version="mock-quality-rules-not-official";
            }
            if (phase === "expired") {item.produced_at_ms=now-25000;item.received_at_ms=item.produced_at_ms;}
            if (phase === "unverified-source") item.validation="unverified";
            if (phase === "clock-conflict") item.produced_at_ms=now+10000;
            if (phase === "conflict" && kind === "uwb_connection") item.value=false;
            if (phase === "long") {item.source_id="mock-source-"+"x".repeat(110);item.snapshot_id="mock-snapshot-"+"y".repeat(110);}
            return item;
        });
        if (phase === "duplicate") items.push(Object.assign({},items[0]));
        return {version:1,robot_id:robotId,session_id:phase === "session" ? "mock-other-session" : sessionId,items:items};
    }
}
