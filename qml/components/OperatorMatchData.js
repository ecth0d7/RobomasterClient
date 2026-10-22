.pragma library

const fields = ["current_round", "total_rounds", "red_score", "blue_score",
    "current_stage", "stage_countdown_sec", "is_paused"];
const names = {current_round:"当前局次",total_rounds:"总局次",red_score:"红方比分",blue_score:"蓝方比分",
    current_stage:"阶段",stage_countdown_sec:"倒计时",is_paused:"暂停"};
const stageNames = ["未开始比赛", "准备阶段", "裁判自检", "五秒倒计时", "比赛中", "比赛结算"];

function valid(key, value) {
    if (key === "is_paused") return typeof value === "boolean";
    if (typeof value !== "number" || !Number.isInteger(value)) return false;
    if (key === "current_stage") return value >= 0 && value <= 5;
    if (key === "stage_countdown_sec") return value >= 0 && value <= 2147483647;
    return value >= (["current_round", "total_rounds"].includes(key) ? 1 : 0) && value <= 4294967295;
}

function field(telemetry, key, connected) {
    const value = telemetry?.gameStatus?.[key];
    if (value === undefined || value === null) return {value:value,state:"missing"};
    if (!valid(key,value)) return {value:value,state:"invalid"};
    // GameStatus的optional字段会单独合并。分组刚收到不证明这个字段刚收到；
    // 旧SDK没有逐字段元数据时保留原值，但不能将它冒充实时比赛状态。
    const reported = telemetry?.fieldFreshness?.gameStatus?.[key];
    if (reported === "missing") return {value:value,state:"missing"};
    if (!connected) return {value:value,state:"offline"};
    return {value:value,state:["fresh","stale"].includes(reported) ? reported : "unverified"};
}

function text(item) {
    return ["missing","invalid"].includes(item.state) ? "—" : String(item.value);
}

function roundText(data) {
    // 原局次窄槽容不下uint32的极端长值，用明确省略号而非无标记裁断；详情保留原数。
    const current=text(data.current_round), total=text(data.total_rounds);
    return "Round " + (current.length > 3 ? "…" : current) + "/" + (total.length > 3 ? "…" : total);
}

function time(item) {
    if (["missing","invalid"].includes(item.state)) return "—:—";
    // 七月手册计分板为M:SS；只显示实际接收的秒数，不在UI递减或推进阶段。
    return Math.floor(item.value / 60) + ":" + String(item.value % 60).padStart(2,"0");
}

function view(telemetry, connected) {
    const result = {};
    for (const key of fields) result[key] = field(telemetry,key,connected);
    result.hasData = fields.some(key => result[key].value !== undefined && result[key].value !== null);
    result.roundConflict = result.current_round.state === "fresh" && result.total_rounds.state === "fresh"
        && result.current_round.value > result.total_rounds.value;
    result.urgent = connected && result.stage_countdown_sec.state === "fresh"
        && result.current_stage.state === "fresh" && result.current_stage.value === 4
        && result.is_paused.state === "fresh" && result.is_paused.value === false
        && result.stage_countdown_sec.value <= 10;
    result.caption = caption(result,connected);
    return result;
}

function caption(data, connected) {
    if (!data.hasData) return "";
    if (!connected) return "选手端已断连 · 保留值";
    const invalid = fields.filter(key => data[key].state === "invalid");
    if (data.roundConflict) return "局次冲突 · 请核对原值";
    if (invalid.length) return names[invalid[0]] + "异常" + (invalid.length > 1 ? "等" : "");
    const states = fields.map(key => data[key].state);
    if (!states.includes("fresh") && states.includes("stale")) return "比赛数据已过期";
    if (!states.includes("fresh") && states.includes("unverified")) return "比赛数据时效待核";
    const parts = [];
    if (data.current_stage.state === "fresh") parts.push(stageNames[data.current_stage.value]);
    else parts.push(({stale:"阶段旧",missing:"阶段未提供",unverified:"阶段时效待核"})[data.current_stage.state] ?? "阶段待核");
    if (data.is_paused.state === "fresh" && data.is_paused.value === true) parts.unshift("已暂停");
    else if (data.is_paused.state !== "fresh") parts.push(data.is_paused.state === "stale" ? "暂停旧" : "暂停未知");
    if (data.stage_countdown_sec.state === "stale") parts.push("计时旧");
    else if (data.stage_countdown_sec.state === "unverified") parts.push("计时时效待核");
    if (data.red_score.state === "stale") parts.push("红分旧");
    if (data.blue_score.state === "stale") parts.push("蓝分旧");
    if ([data.current_round.state,data.total_rounds.state].includes("stale")) parts.push("局次旧");
    if (states.includes("unverified") && !parts.some(part => part.includes("时效待核"))) parts.push("含时效待核值");
    return parts.join(" · ");
}

function description(data, keys, connected, previewOnly) {
    const labels = {fresh:"新鲜接收值",stale:"旧值，已过期",missing:"未提供",invalid:"值异常",offline:"断连保留值",unverified:"时效待核"};
    const lines = [previewOnly ? "离线 mock 绘制；非真实接收或比赛状态。"
        : connected ? "选手端导出接收视图；发布源未认证，字段时效仅表示本机接收。" : "选手端导出连接已断开。"];
    for (const key of keys) {
        const item = data[key];
        lines.push(names[key] + "：" + (item.value === undefined || item.value === null ? "未提供" : String(item.value))
            + "；" + (previewOnly && item.state === "fresh" ? "mock新鲜态" : labels[item.state]));
    }
    if (data.roundConflict) lines.push("局次与总局次冲突；保持收到的原值，不截断或修正。");
    lines.push("这是独立字段的本机接收视图，不证明同一比赛阶段快照。UI不推算比赛时间。");
    return lines.join("\n");
}
