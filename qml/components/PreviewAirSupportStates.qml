import QtQuick

// 仅用于绘制的独立样例；不启动连接，不执行select/confirm或机器人动作。
QtObject {
    property string mode: "telemetry"
    property int robotId: 6
    property string scenario: "nominal"
    property int frame: 0
    readonly property var phases: ["idle","free-zero","selected-free","selected-paid","active","selected-end",
        "laser","selected-unlock","old-free","old-support","offline","none","units","long","active"]
    readonly property string phase: mode === "sequence" ? phases[Math.floor(frame/4)%phases.length] : mode
    readonly property bool playerConnected: phase !== "offline" && scenario !== "disconnected"
    readonly property bool secondsVerified: phase !== "units"
    readonly property bool controlAvailable: phase !== "pending"
    readonly property int selection: ({"selected-free":1,"selected-paid":2,"selected-end":0,"selected-unlock":3})[phase] ?? -1
    readonly property var staticValues: ({robot_id:phase === "identity-missing" ? undefined
        : phase === "foreign" ? robotId === 6 ? 106 : 6 : robotId})
    readonly property var airValues: {
        const active=["active","paid","laser","selected-end","selected-unlock","shooter-zero","shooter-normal","shooter-old","shooter-invalid"].includes(phase);
        const values={airsupport_status:active ? 1 : 0,left_time:phase === "free-zero" || phase === "paid" ? 0 : 50,
            cost_coins:phase === "paid" ? 20 : 0,is_being_targeted:["laser","selected-unlock"].includes(phase) ? 1 : 0,
            shooter_status:phase === "shooter-zero" ? 0 : ["laser","selected-unlock","shooter-old"].includes(phase) ? 2 : 1};
        if (phase === "none") for (const key of Object.keys(values)) values[key]=undefined;
        if (phase === "missing-free") values.left_time=undefined;
        if (phase === "invalid") values.left_time="50";
        if (phase === "fraction") values.left_time=0.5;
        if (phase === "negative") values.left_time=-1;
        if (phase === "overflow") values.left_time=4294967296;
        if (phase === "status-invalid") values.airsupport_status=2;
        if (phase === "shooter-invalid") values.shooter_status=3;
        if (phase === "laser-invalid") values.is_being_targeted=true;
        if (phase === "long") {values.left_time=4294967295;values.cost_coins=4294967295;}
        return values;
    }
    readonly property var fieldStates: {
        const states={robotStatic:{robot_id:phase === "identity-old" ? "stale" : phase === "identity-missing" ? "missing" : "fresh"},airSupport:{}};
        if (phase === "legacy") {states.robotStatic={};return states;}
        for (const key of Object.keys(airValues)) if (airValues[key] !== undefined)
            states.airSupport[key]=scenario === "role-missing" ? "missing" : ["role-stale","hud-stale"].includes(scenario) ? "stale" : "fresh";
        const key=({"old-free":"left_time","old-support":"airsupport_status","old-coins":"cost_coins",
            "old-laser":"is_being_targeted","shooter-old":"shooter_status","field-missing":"left_time"})[phase];
        if (key) states.airSupport[key]=phase === "field-missing" ? "missing" : "stale";
        return states;
    }
}
