import QtQuick

// 只用于离线绘制；没有设备、电控、网络或真实能量计时。
QtObject {
    id:root
    property string mode:"telemetry"
    property int robotId:3
    property int step:0
    readonly property var phases:["none","chassis-only","buffer-only","zero","full","limit-missing","limit-zero",
        "limit-old","value-old","partial","legacy","metadata-missing","invalid","overflow","foreign",
        "identity-missing","identity-old","offline","long","nominal"]
    readonly property string current:mode === "sequence" ? phases[step%phases.length] : mode
    readonly property bool connected:current !== "offline"
    property Timer motion:Timer {interval:800;repeat:true;running:root.mode === "sequence";onTriggered:root.step+=1}
    readonly property var staticValues:{
        const values={robot_id:robotId,max_chassis_energy:100,max_buffer_energy:60};
        if (["none","buffer-only"].includes(current)) values.max_chassis_energy=undefined;
        if (["none","chassis-only"].includes(current)) values.max_buffer_energy=undefined;
        if (current === "limit-missing") {values.max_chassis_energy=undefined;values.max_buffer_energy=undefined;}
        if (current === "limit-zero") {values.max_chassis_energy=0;values.max_buffer_energy=0;}
        if (current === "metadata-missing") values.max_buffer_energy=0;
        if (current === "invalid-limit") {values.max_chassis_energy="100";values.max_buffer_energy=-1;}
        if (["foreign","identity-hidden"].includes(current)) values.robot_id=(robotId>100?100:0)+(robotId%100===3 ? 4 : 3);
        if (current === "identity-missing") values.robot_id=undefined;
        if (current === "long") {values.max_chassis_energy=4294967295;values.max_buffer_energy=4294967295;}
        return values;
    }
    readonly property var dynamicValues:{
        const values={current_chassis_energy:72,current_buffer_energy:44};
        if (["none","buffer-only"].includes(current)) values.current_chassis_energy=undefined;
        if (["none","chassis-only","partial"].includes(current)) values.current_buffer_energy=undefined;
        if (current === "zero") {values.current_chassis_energy=0;values.current_buffer_energy=0;}
        if (current === "full") {values.current_chassis_energy=100;values.current_buffer_energy=60;}
        if (current === "limit-zero") values.current_buffer_energy=0;
        if (current === "invalid") {values.current_chassis_energy="72";values.current_buffer_energy=-1;}
        if (current === "overflow") {values.current_chassis_energy=101;values.current_buffer_energy=65;}
        if (current === "long") {values.current_chassis_energy=4294967295;values.current_buffer_energy=4294967295;}
        return values;
    }
    readonly property var fieldStates:{
        const result={robotStatic:{},robotDynamic:{}};
        if (current === "legacy") return result;
        for (const key of Object.keys(staticValues)) if (staticValues[key] !== undefined)
            result.robotStatic[key]=current === "stale" ? "stale" : "fresh";
        for (const key of Object.keys(dynamicValues)) if (dynamicValues[key] !== undefined)
            result.robotDynamic[key]=["stale","value-old"].includes(current) ? "stale" : "fresh";
        if (["limit-old","partial"].includes(current)) result.robotStatic.max_chassis_energy="stale";
        if (current === "limit-old") result.robotStatic.max_buffer_energy="stale";
        if (current === "identity-old") result.robotStatic.robot_id="stale";
        if (current === "metadata-missing") {delete result.robotDynamic.current_chassis_energy;result.robotStatic.max_buffer_energy="missing";}
        if (current === "identity-hidden") result.robotStatic.robot_id="missing";
        return result;
    }
}
