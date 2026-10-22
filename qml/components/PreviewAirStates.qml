import QtQuick

// 离线绘制源，不是赛事接收器／传感器插件；750／50／5仅为显式mock数值。
QtObject {
    id:root
    property string mode:"telemetry"
    property int robotId:6
    property string scenario:"nominal"
    property string fillVisual:"telemetry"
    property bool animated:false
    property int motionFrame:0
    property int step:0
    property double startedAt:Date.now()
    readonly property var phases:["none","native-only","nominal","zero","full","limit-zero","limit-old","ammo-old",
        "progress-only","count-only","progress-old","count-cap-old","overflow","scope-conflict","legacy-native",
        "old-unverified","old-missing","duplicate","expired","source-offline","player-offline","vision","long","nominal"]
    readonly property string current:mode === "sequence" ? phases[step%phases.length] : mode
    readonly property string sessionId:"mock-air-session-"+robotId
    readonly property bool playerConnected:current !== "player-offline"
    readonly property bool projectionConnected:current !== "source-offline"
    onCurrentChanged:startedAt=Date.now()
    onModeChanged:step=0
    onMotionFrameChanged:if(mode === "telemetry" && animated)startedAt=Date.now()
    property Timer motion:Timer {interval:800;repeat:true;running:root.mode === "sequence";onTriggered:root.step+=1}
    readonly property var staticValues:{
        const result={robot_id:robotId};
        if (["foreign","identity-hidden"].includes(current)) result.robot_id=robotId===6 ? 106 : 6;
        if (current === "identity-missing") result.robot_id=undefined;
        return result;
    }
    readonly property var dynamicValues:{
        const result={remaining_ammo:540};
        if (current === "none") result.remaining_ammo=undefined;
        if (current === "zero") result.remaining_ammo=0;
        if (current === "full") result.remaining_ammo=750;
        if (current === "overflow") result.remaining_ammo=751;
        if (current === "invalid") result.remaining_ammo="540";
        if (current === "long") result.remaining_ammo=4294967295;
        return result;
    }
    readonly property var airValues:{
        const result={airsupport_status:1,left_time:32,cost_coins:60,is_being_targeted:1,shooter_status:2};
        if (["none","shooter-missing"].includes(current)) result.shooter_status=undefined;
        if (["zero","shooter-zero"].includes(current)) result.shooter_status=0;
        if (current === "shooter-normal") result.shooter_status=1;
        if (current === "invalid") result.shooter_status="1";
        if (current === "shooter-invalid") result.shooter_status=3;
        return result;
    }
    readonly property var fieldStates:{
        const result={robotStatic:{robot_id:"fresh"},robotDynamic:{remaining_ammo:"fresh"},airSupport:{}};
        for (const key of Object.keys(airValues)) if (airValues[key] !== undefined) result.airSupport[key]="fresh";
        if (current === "legacy-native") {result.robotStatic={};result.robotDynamic={};result.airSupport={};}
        if (current === "native-missing") {result.robotDynamic.remaining_ammo="missing";result.airSupport.shooter_status="missing";}
        if (current === "ammo-old") result.robotDynamic.remaining_ammo="stale";
        if (current === "shooter-old") result.airSupport.shooter_status="stale";
        if (current === "identity-old") result.robotStatic.robot_id="stale";
        if (current === "identity-hidden") result.robotStatic.robot_id="missing";
        return result;
    }
    readonly property var view:{
        if (["none","native-only","native-missing"].includes(current) || scenario === "disconnected"
            || mode === "telemetry" && scenario === "hud-partial") return null;
        if (current === "legacy-projection") return {ammoMaximum:750,ammoMaximumState:"fresh",countermeasureProgress:26,countermeasureMaximum:50,countermeasureState:"fresh"};
        const values={ammoMaximum:750,countermeasureProgress:26,countermeasureMaximum:50,countermeasureCount:2,countermeasureCountMaximum:5};
        if (mode === "telemetry") values.countermeasureProgress=fillVisual !== "telemetry" ? ({empty:0,half:25,full:50})[fillVisual] : animated ? (motionFrame*7)%51 : 26;
        if (current === "zero") {values.countermeasureProgress=0;values.countermeasureCount=0;}
        if (current === "full") {values.countermeasureProgress=50;values.countermeasureCount=5;}
        if (["limit-missing","progress-only","count-only"].includes(current)) delete values.ammoMaximum;
        if (current === "limit-zero") {values.ammoMaximum=0;values.countermeasureMaximum=0;values.countermeasureCountMaximum=0;}
        if (current === "progress-only") {delete values.countermeasureCount;delete values.countermeasureCountMaximum;}
        if (current === "count-only") {delete values.countermeasureProgress;delete values.countermeasureMaximum;}
        if (current === "counter-limit-missing") {delete values.countermeasureMaximum;delete values.countermeasureCountMaximum;}
        if (current === "overflow") {values.countermeasureProgress=51;values.countermeasureCount=6;}
        if (current === "long") for (const key of Object.keys(values)) values[key]=4294967295;
        if (current === "invalid") {values.ammoMaximum="750";values.countermeasureProgress=-1;values.countermeasureCount=1.5;}
        const records=Object.keys(values).map(key => {
            const timestamp=startedAt-(["old-unverified","old-missing"].includes(current)?2000:current === "expired"?16000:0);
            const record={kind:key,value:values[key],state:scenario === "hud-stale" ? "stale" : "fresh",
                kind_verified:true,applies_to_robot_verified:true,source_robot_id:robotId,
                source_kind:"mock",validation:"mock",source_id:"mock-air-display",snapshot_id:"mock-air-"+step+"-"+motionFrame,
                scale_id:key === "ammoMaximum" ? "mock-ammo-level2" : key.startsWith("countermeasureCount") ? "mock-countered-level2" : "mock-targeting-level2",
                lifecycle:"active",clock_basis:"local_receive",produced_at_ms:timestamp,received_at_ms:timestamp,
                fresh_for_ms:current === "expires" ? 1200 : 1500,ttl_ms:current === "expires" ? 3200 : 15000};
            if (current === "limit-old" && key.endsWith("Maximum")) record.state="stale";
            if (current === "progress-old" && key === "countermeasureProgress") record.state="stale";
            if (current === "count-cap-old" && key === "countermeasureCountMaximum") record.state="stale";
            if (current === "scope-conflict" && key === "countermeasureMaximum") record.scale_id="mock-other-level";
            if (current === "old-unverified") delete record.state;
            if (current === "old-missing") record.state="missing";
            if (current === "retracted") record.lifecycle="retracted";
            if (current === "unverified") {record.source_kind="official_player_client";record.validation="unverified";}
            if (current === "missing-window") delete record.fresh_for_ms;
            if (current === "clock-conflict") record.received_at_ms+=10;
            if (current === "future") {record.produced_at_ms=startedAt+30000;record.received_at_ms=record.produced_at_ms;}
            // 本地源只模拟宿主核验后的投影，不启动真实设备或算法。
            if (["vision","sensor","derived","mixed"].includes(current)) {
                record.source_kind=current === "mixed" ? key === "ammoMaximum" ? "derived" : "local_vision" : current === "vision" ? "local_vision" : current === "sensor" ? "local_sensor" : "derived";
                record.validation="verified";record.host_verified=true;record.sensor_id="mock-camera";
                record.dependencies_verified=true;record.based_on=[{source_id:"mock-input",snapshot_id:"mock-input-frame"}];
            }
            return record;
        });
        if (current === "duplicate") records.push(Object.assign({},records[0],{snapshot_id:"mock-duplicate",value:999}));
        return {version:1,robot_id:current === "projection-foreign" ? robotId === 6 ? 106 : 6 : robotId,
            session_id:current === "session" ? "mock-other-session" : sessionId,items:records};
    }
}
