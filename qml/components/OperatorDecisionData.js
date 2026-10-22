.pragma library
.import "OperatorDiagnostics.js" as Diagnostics
.import "OperatorProtocolSchema.js" as Schema

function number(value, decimals) {
    if (typeof value !== "number" || !Number.isFinite(value) || value < 0) return "—";
    return decimals === undefined ? String(value) : value.toFixed(decimals);
}
function percent(value) { return number(value) === "—" ? "—" : number(value) + "%"; }
function priority(value) { return ({info: "一般", caution: "注意", urgent: "优先关注"})[value] ?? (value ?? "—"); }
function focus(value) { return ({health: "生命", heat: "热量", ammo: "弹量", map: "地图", communication: "通信", match: "比赛"})[value] ?? (value ?? "—"); }
function api(value) { return ({chat: "兼容接口", responses: "Responses", process: "本地进程", rules: "规则插件"})[value] ?? (value ?? "—"); }
function facts(input) {
    const dynamic = input?.groups?.robotDynamic ?? {}, fixed = input?.groups?.robotStatic ?? {}, computed = input?.computed_facts ?? {};
    // 仅显示宿主已整理的快照及计算值，不拿当前遥测补齐历史输入。
    return [
        {title: "生命比例", value: percent(computed.health_percent), detail: number(dynamic.current_health) + " / " + number(fixed.max_health)},
        {title: "热量比例", value: percent(computed.heat_percent), detail: number(dynamic.current_heat) + " / " + number(fixed.max_heat)},
        {title: "允许弹量", value: number(dynamic.remaining_ammo), detail: "单位：发"}
    ];
}
function groupList(values) {
    return Array.isArray(values) && values.length ? values.map(key => Diagnostics.groupTitles[key] ?? key).join("、") : "无";
}
function fieldList(values) {
    if (!Array.isArray(values) || !values.length) return "无";
    return values.map(key => {
        const dot = key.indexOf("."), group = key.slice(0, dot), field = key.slice(dot + 1);
        const meta = Schema.messages.find(message => message.group === group)?.fields.find(entry => entry.name === field);
        return (Diagnostics.groupTitles[group] ?? group) + " · " + (meta?.title ?? field) + " [" + key + "]";
    }).join("\n");
}
function inputJson(input) {
    // QML 数值不能恢复已失去精度的大整数；显示副本明确占位，原输入对象不变。
    return JSON.stringify(input, (_, value) => {
        if (typeof value !== "number") return value;
        if (!Number.isFinite(value)) return "[非有限数值]";
        return Number.isInteger(value) && !Number.isSafeInteger(value) ? "[超出精确整数显示范围]" : value;
    }, 2);
}
