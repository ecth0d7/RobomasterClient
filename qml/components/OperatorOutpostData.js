.pragma library

// 绘制投影不是认证器：真实producer必须先完成来源／身份／时钟与字段校验。
// 现有GlobalUnitStatus没有重建双进度／剩余次数，生产默认空，不能从status5猜百分比。
function rebuild(items, robotId, team, now, previewOnly) {
    if (!Array.isArray(items) || items.length > 2) return null;
    const matches = items.filter(e => e && e.robot_id === robotId && e.team === team);
    if (matches.length !== 1) return null;
    const e = matches[0];
    if (e.source_kind === "mock") {
        if (!previewOnly || e.validation !== "mock") return null;
    } else if(e.source_kind === "local_shark_server") {
        if(e.validation!=="local_server" || e.source_id!=="SharkDataSever"
            || e.endpoint!=="http://127.0.0.1:2026/api/roster")return null;
    } else if (e.source_kind !== "official_player_client" || e.host_verified !== true || e.validation !== "verified") return null;
    if (!["fresh","stale"].includes(e.state) || e.lifecycle !== "active"
        || typeof e.source_id !== "string" || !e.source_id || e.source_id.length > 128
        || typeof e.snapshot_id !== "string" || !e.snapshot_id || e.snapshot_id.length > 128
        || ![e.produced_at_ms,e.received_at_ms,e.ttl_ms].every(Number.isSafeInteger)
        || e.produced_at_ms > e.received_at_ms || e.received_at_ms > now
        || e.ttl_ms <= 0 || e.ttl_ms > 60000) return null;
    const age = now - e.produced_at_ms;
    if (age < 0 || age >= e.ttl_ms) return null;
    const result = Object.assign({}, e, {age_ms:age, state:e.state === "fresh" && age <= 5000 ? "fresh" : "stale"});
    for (const key of ["team_progress","robot_progress","remaining_count"]) {
        const valid = key === "remaining_count"
            ? Number.isSafeInteger(result[key]) && result[key] >= 0 && result[key] <= 4294967295
            : typeof result[key] === "number" && Number.isFinite(result[key]) && result[key] >= 0 && result[key] <= 1;
        if (!valid || !["fresh","stale"].includes(e[key + "_state"])) {
            delete result[key]; result[key + "_state"] = "missing";
        } else result[key + "_state"] = result.state === "fresh" ? e[key + "_state"] : "stale";
    }
    return result;
}

// 同一可靠来源边界，但防御百分比是独立扩展，绝不由outpost_status或机器人Buff猜得。
function defense(items, robotId, team, now, previewOnly) {
    const e = rebuild(items, robotId, team, now, previewOnly);
    if (!e || e.unit !== "percent" || typeof e.defense_percent !== "number"
        || !Number.isFinite(e.defense_percent) || e.defense_percent < 0 || e.defense_percent > 100
        || !["fresh","stale"].includes(e.defense_percent_state)) return null;
    return Object.assign({}, e, {defense_percent_state:e.state === "fresh" ? e.defense_percent_state : "stale"});
}
