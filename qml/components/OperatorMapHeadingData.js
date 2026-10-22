.pragma library

function validRobot(id) {
    return Number.isInteger(id) && [1, 2, 3, 4, 5, 6, 7, 8, 9].includes(id % 100)
            && (id < 100 || id > 100 && id < 110);
}

// renderer只接宿主已汇总的唯一快照；校验不替代宿主的队伍认证与冲突处理。
// UTC毫秒仅用于显示生命周期，接收层仍须负责时钟偏差和单调超时。
function headingFor(items, robotId, now, previewOnly) {
    if (!Array.isArray(items) || items.length > 16 || !validRobot(robotId)) return null;
    let candidate = null;
    for (const entry of items.slice(0, 16)) {
        if (!entry || entry.robot_id !== robotId) continue;
        // 同一机器人尚有多条记录表示汇总未解决冲突，不在绘制层擅自挑赢家。
        if (candidate !== null) return null;
        candidate = entry;
    }
    const e = candidate;
    if (!e || e.lifecycle !== "active" || e.frame_id !== "rm2026.field" || e.unit !== "deg"
        || e.north_zero !== true || typeof e.clockwise !== "boolean"
        || !["fresh", "stale"].includes(e.state)
        || typeof e.yaw_deg !== "number" || !Number.isFinite(e.yaw_deg)
        || !Number.isFinite(e.confidence) || e.confidence < 0 || e.confidence > 1
        || !["snapshot_id", "source_id", "sensor_id"].every(k => typeof e[k] === "string" && e[k].length > 0 && e[k].length <= 128)
        || !validRobot(e.source_robot_id)) return null;
    if (e.source_kind === "mock") {
        if (!previewOnly || e.validation !== "mock") return null;
    } else if (e.host_verified !== true || e.validation !== "verified"
        || !["official_player_client", "local_sensor", "local_vision", "derived"].includes(e.source_kind)) return null;
    if (![e.produced_at_ms, e.received_at_ms, e.ttl_ms, e.fresh_for_ms].every(Number.isSafeInteger)
        || e.ttl_ms <= 0 || e.ttl_ms > 60000 || e.fresh_for_ms < 0 || e.fresh_for_ms > e.ttl_ms
        || e.produced_at_ms > e.received_at_ms || e.received_at_ms > now) return null;
    const age = now - e.produced_at_ms;
    if (age < 0 || age >= e.ttl_ms) return null;
    return Object.assign({}, e, {state: e.state === "stale" || age > e.fresh_for_ms ? "stale" : "fresh"});
}
