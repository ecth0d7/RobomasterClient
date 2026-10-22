.pragma library

function state(telemetry, group, key) {
    const data = telemetry?.[group] ?? {};
    if (data[key] === undefined || data[key] === null)
        return "missing";
    return telemetry?.fieldFreshness?.[group]?.[key]
            ?? telemetry?.freshness?.[group] ?? "missing";
}

// 当前事件类型刷新后，旧数量/时长即使还在fresh窗口内，也不是这次事件的字段。
function notOlderThan(telemetry,group,key,anchor) {
    if(typeof telemetry?.fieldObservation!=="function")return false;
    const sample=telemetry.fieldObservation(group,key),reference=telemetry.fieldObservation(group,anchor);
    return typeof sample?.observation_session_id==="string" && sample.observation_session_id.length>0
        && sample.observation_session_id===reference?.observation_session_id
        && Number.isSafeInteger(sample.observation_revision) && Number.isSafeInteger(reference.observation_revision)
        && sample.observation_revision>=reference.observation_revision;
}

function text(telemetry, group, key, decimals) {
    const value = telemetry?.[group]?.[key];
    if (state(telemetry, group, key) === "missing"
            || typeof value !== "number" || !Number.isFinite(value))
        return "—";
    return decimals === undefined ? String(value) : value.toFixed(decimals);
}

function fraction(value, maximum) {
    if (typeof value !== "number" || !Number.isFinite(value)
            || typeof maximum !== "number" || !Number.isFinite(maximum) || maximum <= 0)
        return 0;
    return Math.max(0, Math.min(1, value / maximum));
}

function portrait(id) {
    const role = id % 100;
    const team = id > 100 ? "blue" : "red";
    if (role === 7)
        return "../resources/player/top_robots/" + team + "_tab_guard.png";
    if (role === 6)
        return "../resources/player/my_robot/" + team + "_airplane_statusbar_avatar.png";
    const kind = ({1: "hero", 2: "enginner", 3: "infantry", 4: "infantry", 5: "infantry"})[role];
    return "../resources/player/my_robot/" + team + "_statusbar_avatar_" + (kind ?? "empty") + ".png";
}
