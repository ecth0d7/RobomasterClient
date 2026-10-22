.pragma library

// 接收逐机器人静态投影或明确标记的本机Shark模型元数据，不从当前HP反推上限。
// 本机服务器来源与official_player_client分别校验，不把本机联调声明为官方认证。
function item(items, id, now, previewOnly) {
    if (!Array.isArray(items) || items.length > 18) return null;
    const matches = items.filter(e => e && e.robot_id === id);
    if (matches.length !== 1) return null;
    const e = matches[0];
    if (e.source_kind === "mock") {
        if (!previewOnly || e.validation !== "mock") return null;
    } else if (e.source_kind === "local_shark_server") {
        if (e.validation !== "local_server" || e.source_id !== "SharkDataSever"
            || e.endpoint !== "http://127.0.0.1:2026/api/roster") return null;
    } else if (e.source_kind !== "official_player_client" || e.host_verified !== true || e.validation !== "verified") return null;
    if (e.source_robot_id !== id || e.lifecycle !== "active" || !["fresh","stale"].includes(e.state)
        || typeof e.source_id !== "string" || !e.source_id || e.source_id.length > 128
        || typeof e.snapshot_id !== "string" || !e.snapshot_id || e.snapshot_id.length > 128
        || ![e.produced_at_ms,e.received_at_ms,e.ttl_ms].every(Number.isSafeInteger)
        || e.produced_at_ms > e.received_at_ms || e.received_at_ms > now
        || e.ttl_ms <= 0 || e.ttl_ms > 60000) return null;
    const age = now - e.produced_at_ms;
    if (age < 0 || age >= e.ttl_ms) return null;
    const result = Object.assign({}, e, {age_ms:age,state:e.state === "fresh" && age <= 5000 ? "fresh" : "stale"});
    for(const key of ["operator_registered","expelled","yellow_card","respawn_invulnerable","rune_active"]) {
        if(typeof e[key]!=="boolean" || !["fresh","stale"].includes(e[key+"_state"])) {
            delete result[key];result[key+"_state"]="missing";
        } else result[key+"_state"]=result.state==="fresh" ? e[key+"_state"] : "stale";
    }
    for(const key of ["air_support_status","air_shooter_status","air_ammo"]) {
        const maximum=key==="air_support_status" ? 1 : key==="air_shooter_status" ? 2 : 4294967295;
        if(!Number.isSafeInteger(e[key]) || e[key]<0 || e[key]>maximum || !["fresh","stale"].includes(e[key+"_state"])) {
            delete result[key];result[key+"_state"]="missing";
        } else result[key+"_state"]=result.state==="fresh" ? e[key+"_state"] : "stale";
    }
    for (const key of ["max_health","remaining_bullets","level"]) {
        const valid = Number.isSafeInteger(e[key]) && (key === "max_health"
            ? e[key] > 0 && e[key] <= 4294967295 : key === "level"
            ? e[key] >= 1 && e[key] <= 10 : e[key] >= -2147483648 && e[key] <= 4294967295);
        if (!valid || !["fresh","stale"].includes(e[key+"_state"])) {
            delete result[key];result[key+"_state"]="missing";
        } else result[key+"_state"]=result.state === "fresh" ? e[key+"_state"] : "stale";
    }
    for (const key of ["connection_state","current_respawn_progress","total_respawn_progress","deploy_cooldown_remaining_seconds","air_call_remaining_seconds"]) {
        const valid = Number.isSafeInteger(e[key]) && e[key] >= 0 && e[key] <= (key === "connection_state" ? 1 : key === "deploy_cooldown_remaining_seconds" ? 8 : 4294967295);
        if (!valid || !["fresh","stale"].includes(e[key+"_state"])) {
            delete result[key];result[key+"_state"]="missing";
        } else result[key+"_state"]=result.state === "fresh" ? e[key+"_state"] : "stale";
    }
    if(typeof e.air_paid_call!=="boolean" || !["fresh","stale"].includes(e.air_paid_call_state)) {
        delete result.air_paid_call;result.air_paid_call_state="missing";
    } else result.air_paid_call_state=result.state==="fresh" ? e.air_paid_call_state : "stale";
    for (const key of ["max_heat","heat_cooldown_rate","max_power"]) {
        const valid = typeof e[key] === "number" && Number.isFinite(e[key]) && e[key] >= 0
            && e[key] <= 4294967295 && (key === "heat_cooldown_rate" || Number.isSafeInteger(e[key]));
        if (!valid || !["fresh","stale"].includes(e[key+"_state"])) {
            delete result[key];result[key+"_state"]="missing";
        } else result[key+"_state"]=result.state === "fresh" ? e[key+"_state"] : "stale";
    }
    return result;
}

function compactInteger(value) {
    if (!Number.isSafeInteger(value)) return "—";
    if (Math.abs(value) < 10000) return String(value);
    const unit = Math.abs(value) >= 1000000 ? 1000000 : 1000;
    return (value / unit).toFixed(1).replace(/\.0$/, "") + (unit === 1000000 ? "M" : "k");
}
