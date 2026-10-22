.pragma library
.import "OperatorData.js" as Data
.import "UiFormat.js" as Format
.import "OperatorRosterData.js" as Roster

function roles(blue, clientID) {
    const result = [1, 2, 3, 4, 6, 7];
    const ownRole = clientID % 100;
    if (Format.validLogin(clientID) && (clientID > 100) === blue && ownRole === 5) result.splice(4,0,ownRole);
    return result;
}
function reading(telemetry, clientID, robotID, key, items, now, previewOnly) {
    if (!Format.validLogin(clientID)) return {text: "—", state: "missing"};
    const row = telemetry?.robotData?.[String(robotID)] ?? {};
    // 当前派生索引只有其他机器人的全局生命；不把队友推导参数当官方静态遥测。
    const localState = robotID === clientID ? Data.state(telemetry,"robotStatic",key) : "missing";
    if (key !== "current_health" && localState !== "fresh") {
        const projection = Roster.item(items,robotID,now,previewOnly);
        if (projection && ["max_health","max_heat","heat_cooldown_rate","max_power","level"].includes(key)
            && projection[key+"_state"] === "fresh")
            return {text:Format.number(projection[key]),state:"fresh",value:projection[key],source:projection.source_kind};
        if (robotID !== clientID) return {text:"—",state:"missing"};
    }
    let group = "robotStatic", field = key;
    if (key === "current_health") {
        group = row.current_health_source ?? (robotID === clientID ? "robotDynamic" : "globalUnit");
        if (!["robotDynamic", "globalUnit"].includes(group)) return {text: "—", state: "missing"};
        field = group === "globalUnit" ? "robot_health" : key;
    }
    const state = Data.state(telemetry, group, field);
    const value = row[key];
    return {text: state === "missing" ? "—" : Format.number(value) + (state === "stale" && Number.isFinite(value) ? "旧" : ""), state: state, value: value, source: group};
}
function damage(telemetry, clientID, blue) {
    if (!Format.validLogin(clientID)) return {text: "—", state: "missing"};
    const key = (clientID > 100) === blue ? "total_damage_ally" : "total_damage_enemy";
    const state = Data.state(telemetry, "globalUnit", key);
    return {text: Data.text(telemetry, "globalUnit", key) + (state === "stale" ? " · 旧" : ""), state: state};
}
