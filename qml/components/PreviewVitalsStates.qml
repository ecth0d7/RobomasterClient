import QtQuick
import "OperatorPreviewRules.js" as Rules

// 当前经验的样例数值不是已验证累计口径；所有数据只供离线绘制，不驱动升级或机器人。
QtObject {
    id: root
    property string mode:"telemetry"
    property int robotId:3
    property string scenario:"nominal"
    property int frame:0
    readonly property var phases:["nominal","damage","zero","dead","full","limit-zero","over","health-old","limit-old","foreign",
        "offline","none","legacy","nominal","xp-start","xp-complete","upgrade","level9","level10","rules-missing"]
    readonly property string phase:mode === "sequence" ? phases[Math.floor(frame/4)%phases.length] : mode
    readonly property bool connected:phase !== "offline" && scenario !== "disconnected"
    readonly property string rulesVersion:phase === "rules-missing" ? "" : phase === "rules-unknown" ? "unverified-season" : "2026-v2.2.0"
    readonly property int sampleLevel:phase === "level9" ? 9 : ["level10","level10-missing","max-independent"].includes(phase) ? 10 : phase === "upgrade" ? 3 : 2
    readonly property var sample:Rules.sample(robotId,sampleLevel)
    readonly property var staticValues: {
        const values={robot_id:phase === "identity-missing" ? undefined
            : ["foreign","identity-hidden"].includes(phase) ? (robotId > 100 ? robotId-100 : robotId+100) : robotId,
            level:sample.level,max_health:sample.maximum,alive_state:phase === "dead" ? 2 : 1};
        if (["none","health-only","level-missing"].includes(phase)) values.level=undefined;
        if (["none","xp-only","limit-missing"].includes(phase)) values.max_health=undefined;
        if (phase === "limit-zero") values.max_health=0;
        if (phase === "invalid-limit") values.max_health=-1;
        if (phase === "level-zero") values.level=0;
        if (phase === "level-invalid") values.level=11;
        if (phase === "level-string") values.level="2";
        if (phase === "max-independent") values.max_health=123;
        if (["long","long-old"].includes(phase)) values.max_health=4294967295;
        if (phase === "metadata-missing") {values.level=99;values.max_health=999;}
        return values;
    }
    readonly property var dynamicValues: {
        const exp=Rules.experience(sampleLevel,phase === "xp-start" || phase === "upgrade" ? 0 : phase === "level9" ? 0.5 : 350/550);
        const values={current_health:sample.maximum === undefined ? undefined : Math.floor(sample.maximum*0.8),
            current_experience:sample.level === undefined ? undefined : exp.current,
            experience_for_upgrade:sample.level === undefined ? undefined : exp.remaining};
        if (phase === "damage") values.current_health=30;
        if (["zero","dead"].includes(phase)) values.current_health=0;
        if (phase === "full") values.current_health=sample.maximum;
        if (phase === "over") values.current_health=(sample.maximum ?? 0)+1;
        if (phase === "low") values.current_health=1;
        if (["none","xp-only","health-missing"].includes(phase)) values.current_health=undefined;
        if (["none","health-only","level10-missing"].includes(phase)) {values.current_experience=undefined;values.experience_for_upgrade=undefined;}
        if (phase === "current-xp-missing") values.current_experience=undefined;
        if (phase === "remaining-missing") values.experience_for_upgrade=undefined;
        if (phase === "xp-complete") values.experience_for_upgrade=0;
        if (phase === "xp-zero") {values.current_experience=0;values.experience_for_upgrade=0;}
        if (["xp-over","level-hidden"].includes(phase)) values.experience_for_upgrade=600;
        if (phase === "xp-invalid") values.experience_for_upgrade="200";
        if (phase === "xp-overflow") values.current_experience=4294967296;
        if (phase === "invalid-health") values.current_health="140";
        if (phase === "health-negative") values.current_health=-1;
        if (phase === "health-fraction") values.current_health=1.5;
        if (phase === "health-overflow") values.current_health=4294967296;
        if (phase === "max-independent") values.current_health=100;
        if (["long","long-old"].includes(phase)) {values.current_health=4294967295;values.current_experience=4294967295;values.experience_for_upgrade=4294967295;}
        if (phase === "metadata-missing") {values.current_health="old invalid";values.experience_for_upgrade=600;}
        return values;
    }
    readonly property var fieldStates: {
        const result={robotStatic:{},robotDynamic:{}};
        if (phase === "legacy") return result;
        for (const group of ["robotStatic","robotDynamic"]) {
            const values=group === "robotStatic" ? staticValues : dynamicValues;
            for (const key of Object.keys(values)) if (values[key] !== undefined)
                result[group][key]=phase === "stale" || phase === "long-old" || scenario === "hud-stale" ? "stale" : "fresh";
        }
        if (phase === "health-old") result.robotDynamic.current_health="stale";
        if (phase === "limit-old") result.robotStatic.max_health="stale";
        if (phase === "level-old") result.robotStatic.level="stale";
        if (phase === "remaining-old") result.robotDynamic.experience_for_upgrade="stale";
        if (phase === "current-xp-old") result.robotDynamic.current_experience="stale";
        if (phase === "level-hidden") result.robotStatic.level="missing";
        if (phase === "identity-hidden") result.robotStatic.robot_id="missing";
        if (phase === "identity-old") result.robotStatic.robot_id="stale";
        if (phase === "metadata-missing") {
            result.robotStatic.level="missing";result.robotStatic.max_health="missing";
            result.robotDynamic.current_health="missing";result.robotDynamic.experience_for_upgrade="missing";
        }
        return result;
    }
}
