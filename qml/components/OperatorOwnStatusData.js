.pragma library

const kinds = ["yellow_card", "bilateral_yellow", "red_card", "respawn_weakness", "power_cutoff", "power_bonus"];
const titles = {yellow_card:"黄牌", bilateral_yellow:"双方黄牌", red_card:"红牌", respawn_weakness:"复活虚弱", power_cutoff:"断电", power_bonus:"功率提升"};
function unsigned(value) { return Number.isSafeInteger(value) && value >= 0 && value <= 4294967295; }
function token(value) { return typeof value === "string" && value.length > 0 && value.length <= 128; }
function fieldState(record, key) {
    if (record[key] === undefined || record[key] === null) return "missing";
    if (record.state !== "fresh") return "stale";
    const state = record.field_states?.[key];
    return state === "fresh" || state === "stale" ? state : "missing";
}

// 这是宿主已核验的显示投影，不是新的官方消息。原PenaltyInfo不含机器人ID／解除时刻。
function project(items, robotId, sessionId, round, now, previewOnly) {
    if (!Array.isArray(items) || items.length > 16 || !Number.isFinite(now)) return [];
    const accepted = [];
    for (const item of items) {
        if (!item || typeof item !== "object" || item.version !== 1 || !kinds.includes(item.kind) || item.kind_verified !== true
            || item.robot_id !== robotId || item.applies_to_robot_verified !== true
            || !Number.isSafeInteger(round) || round <= 0 || item.round !== round || item.round_verified !== true
            || !token(item.source_id) || !token(item.snapshot_id) || !token(item.session_id)
            || item.session_id !== sessionId || !["fresh","stale"].includes(item.state)
            || !["active","ended","retracted"].includes(item.lifecycle)) continue;
        const mock = previewOnly && item.source_kind === "mock" && item.validation === "mock";
        const official = item.source_kind === "official_player_client" && item.host_verified === true && item.validation === "verified";
        if (!mock && !official || !["source_epoch","local_receive"].includes(item.clock_basis)) continue;
        if (item.kind === "power_cutoff" && (!Array.isArray(item.target_modules) || item.target_modules.length === 0
            || item.target_modules.length > 5 || new Set(item.target_modules).size !== item.target_modules.length
            || item.target_modules.some(module => !["chassis","gimbal","shooter","shooter_17","shooter_42"].includes(module)))) continue;
        if (!Number.isSafeInteger(item.produced_at_ms) || !Number.isSafeInteger(item.received_at_ms)
            || item.produced_at_ms < 0 || item.produced_at_ms > item.received_at_ms || item.received_at_ms > now
            || !Number.isSafeInteger(item.ttl_ms) || item.ttl_ms <= 0 || item.ttl_ms > 60000) continue;
        if (item.clock_basis === "local_receive" && item.produced_at_ms !== item.received_at_ms) continue;
        const age = now - item.produced_at_ms;
        if (age >= item.ttl_ms) continue;
        const record = Object.assign({}, item, {age_ms:age});
        const freshWindow = Number.isSafeInteger(item.fresh_for_ms) && item.fresh_for_ms > 0 && item.fresh_for_ms <= item.ttl_ms;
        record.state = freshWindow && age < item.fresh_for_ms ? item.state : "stale";
        record.active = record.state === "fresh" && record.lifecycle === "active";
        record.count_valid = unsigned(item.count) && fieldState(record,"count") === "fresh" && item.count_scope_verified === true
            && (item.count_semantics === "current_penalty_quantity"
                || item.kind === "bilateral_yellow" && item.count_semantics === "shared_penalty_quantity"
                || item.kind === "yellow_card" && item.count_semantics === "robot_round_yellow_total"
                   && Number.isSafeInteger(round) && round > 0 && item.round === round);
        // remaining_seconds是适配器确认的剩余量，不能把PenaltyInfo.effect_sec直接当它。
        record.timer_valid = record.active && unsigned(item.remaining_seconds)
            && fieldState(record,"remaining_seconds") === "fresh" && item.time_unit === "s" && item.time_unit_verified === true;
        record.estimated_remaining_seconds = record.timer_valid ? Math.max(0,item.remaining_seconds - Math.floor(age/1000)) : null;
        record.derived_display = record.timer_valid ? {source_kind:"derived", source_id:"ui.own_status_clock",
            based_on_source_id:item.source_id, based_on_snapshot_id:item.snapshot_id, computed_at_ms:now} : null;
        accepted.push(record);
    }
    // 同槽重复或冲突必须由宿主解决，renderer不叠加、不选择最后一条。
    return accepted.filter(record => accepted.filter(other => other.kind === record.kind).length === 1);
}
function hint(record) {
    const powerTarget = record.target_modules?.length === 1
        ? ({chassis:"底盘",gimbal:"云台",shooter:"发射",shooter_17:"17mm",shooter_42:"42mm"})[record.target_modules[0]] : "多路";
    const name = record.kind === "power_cutoff" ? powerTarget + "断电"
        : ({respawn_weakness:"虚弱",power_bonus:"功率"})[record.kind] ?? titles[record.kind] ?? "状态";
    if (record.timer_valid) return record.estimated_remaining_seconds > 0
        ? name + " " + record.estimated_remaining_seconds + "s"
        : (record.kind === "power_cutoff" ? "断电" : name) + " · 待同步";
    return name + (fieldState(record,"remaining_seconds") === "stale" ? " · 旧" : "");
}
function cardText(record) {
    if (record.kind === "bilateral_yellow") return "双黄";
    if (!record.count_valid) return titles[record.kind] ?? "判罚";
    return (record.count_semantics === "robot_round_yellow_total" ? "×" : "罚") + record.count;
}
function description(record) {
    if(record.source_kind==="mqtt" && record.source_id==="PenaltyInfo")
        return (titles[record.kind]??"判罚")+"。本机接收的当前判罚数量："+(record.count_valid?record.count:"未提供")
            +"；效果时长原字段："+(unsigned(record.penalty_effect_sec)?record.penalty_effect_sec+"s":"本次未提供")
            +"。效果时长不作为UI剩余倒数；数量/时长不早于当前类型字段，缺值不补0。";
    return (titles[record.kind] ?? "状态") + "，" + (record.source_kind === "mock" ? "离线状态样例" : record.active ? "宿主标记当前有效" : "非活动／旧记录")
        + "。" + record.source_kind + " / " + record.source_id + "；快照 " + record.snapshot_id
        + "；会话 " + record.session_id + "；机器人 " + record.robot_id
        + "；局次 " + record.round + (record.kind === "power_cutoff" ? "；停用电源 " + record.target_modules.join("／") : "")
        + "；年龄 " + (Number.isFinite(record.age_ms) ? Math.round(record.age_ms)+"ms" : "逐字段时效") + "，时间依据 " + record.clock_basis
        + "。数量原值 " + (unsigned(record.count) ? record.count : "未收到") + "（" + fieldState(record,"count") + "），口径 " + (record.count_semantics ?? "未核实")
        + (record.count_valid ? "（已满足徽章数量条件）" : "（未满足徽章数量条件，不绘制该数值）")
        + "。剩余原值 " + (unsigned(record.remaining_seconds) ? record.remaining_seconds : "未收到")
        + "（" + fieldState(record,"remaining_seconds") + "）"
        + (record.timer_valid ? record.clock_basis==="server_model" ? "；服务器模型同步剩余 "+record.estimated_remaining_seconds+"s，UI不自行减秒。"
            : "，本地显示倒数 " + record.estimated_remaining_seconds + "s（derived，不改原值）；归零仍等待解除同步。"
            : "；剩余时长未核实或缺失，不生成秒数。")
        + (record.source_kind === "mock" ? " 离线样例，生产端未接通。" : "");
}
