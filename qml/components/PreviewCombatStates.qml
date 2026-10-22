import QtQuick
import "OperatorPreviewRules.js" as PreviewRules

// 明确离线mock；只切换绘制输入，不运行选手端、设备或生产倒计时。
QtObject {
    id:root
    property string mode:"telemetry"
    property int robotId:3
    property int step:0
    readonly property var phases:["none","false","countdown","out","counter-only","counter-zero","flag-old",
        "counter-old","out-counter-old","legacy","metadata-missing","invalid-flag","invalid-counter","conflict",
        "foreign","identity-missing","identity-old","dead","dead-old","offline","long","nominal","low","full"]
    readonly property string current:mode === "sequence" ? phases[step%phases.length] : mode
    readonly property bool connected:current !== "offline"
    readonly property bool secondsVerified:!["raw","counter-only-raw"].includes(current)
    onModeChanged:step=0
    property Timer cycle:Timer {interval:800;repeat:true;running:root.mode === "sequence";onTriggered:root.step+=1}
    readonly property var drawing:{
        const value={flag:false,countdown:0,flag_state:"fresh",countdown_state:"fresh",
            staticValues:{robot_id:robotId,alive_state:1},dynamicValues:{},
            subjectStates:{robot_id:"fresh",alive_state:"fresh"}};
        if (["none","counter-only","counter-only-raw","counter-zero","counter-only-invalid","dead-only"].includes(current)) value.flag=undefined;
        if (["none","flag-only","dead-only"].includes(current)) value.countdown=undefined;
        if (["out","flag-old","out-counter-old","conflict","offline","stale"].includes(current)) value.flag=true;
        if (["nominal","countdown","raw","counter-only","counter-only-raw","flag-old","false-old","counter-old","out-counter-old","conflict","offline"].includes(current)) value.countdown=4;
        if (["flag-old","false-old","stale"].includes(current)) value.flag_state="stale";
        if (["counter-old","out-counter-old","stale"].includes(current)) value.countdown_state="stale";
        if (current === "legacy") {value.flag_state=undefined;value.countdown_state=undefined;value.subjectStates={};}
        if (current === "metadata-missing") {value.flag_state="missing";value.countdown_state="missing";}
        if (current === "invalid-flag") value.flag="false";
        if (current === "invalid-counter") value.countdown="4";
        if (current === "counter-only-invalid") value.countdown=-1;
        if (["foreign","identity-hidden","dead-foreign"].includes(current)) value.staticValues.robot_id=robotId%100===3 ? robotId+1 : (robotId>100?103:3);
        if (current === "identity-missing") value.staticValues.robot_id=undefined;
        if (current === "identity-hidden") value.subjectStates.robot_id="missing";
        if (["identity-old","stale"].includes(current)) value.subjectStates.robot_id="stale";
        if (["dead","dead-only","dead-old","dead-foreign","dead-unknown","dead-invalid"].includes(current)) {
            value.staticValues.alive_state=2;
            value.dynamicValues.current_health=0;
        }
        if (current === "dead-old") value.subjectStates.alive_state="stale";
        if (current === "dead-unknown") value.staticValues.alive_state=0;
        if (current === "dead-invalid") value.staticValues.alive_state="2";
        if (current === "zero-health") value.dynamicValues.current_health=0;
        if (current === "low") Object.assign(value.dynamicValues,{current_health:1,current_chassis_energy:1,current_buffer_energy:1});
        if (current === "full") Object.assign(value.dynamicValues,{current_health:PreviewRules.sample(robotId,2).maximum,current_chassis_energy:100,current_buffer_energy:60});
        if (current === "long-health") {
            value.staticValues.max_health=4294967295;
            value.dynamicValues.current_health=4294967295;
            value.subjectStates.max_health="fresh";
        }
        if (current === "long") value.countdown=4294967295;
        return value;
    }
}
