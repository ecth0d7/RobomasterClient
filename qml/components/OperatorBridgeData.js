.pragma library
.import "OperatorProtocolSchema.js" as Schema
.import "OperatorDiagnostics.js" as Diagnostics

function object(value) { return value !== null && typeof value === "object" && !Array.isArray(value) ? value : {}; }
// fresh仅描述本机近期是否收到来源报文，不核验远端测量或生产时钟。
function sourceState(peer) { return peer?.fresh === true ? "近期收到 · 内容未核验" : peer?.fresh === false ? "来源已静默" : "接收时效未知"; }
function time(value) {
    if (typeof value !== "number" || !Number.isSafeInteger(value)) return "—";
    const date = new Date(value);
    return Number.isFinite(date.getTime()) ? date.toISOString().replace("T", " ") : "—";
}
function groups(payload) {
    const keys = new Set(Schema.messages.filter(message => message.direction === "receive").map(message => message.group));
    for (const key of Object.keys(object(payload?.groups))) keys.add(key);
    for (const key of Object.keys(object(payload?.freshness))) keys.add(key);
    for (const key of Object.keys(object(payload?.field_freshness))) keys.add(key);
    return Array.from(keys).filter(Boolean).map(key => ({key: key, title: Diagnostics.groupTitles[key] ?? key}));
}
function fields(group, values) {
    const known = Schema.messages.find(message => message.group === group)?.fields ?? [];
    return known.concat(Object.keys(object(values)).filter(key => !known.some(field => field.name === key)).sort().map(key => ({name: key, title: key, type: "扩展字段", cardinality: "optional"})));
}
function fieldState(peer, group, field, value) {
    if (value === undefined || value === null) return "missing";
    // 来源快照失效时，内部 fresh 不能把旧快照重新标成有效。
    if (peer?.fresh === false) return "stale";
    if (peer?.fresh !== true) return "unknown";
    const state = peer?.payload?.field_freshness?.[group]?.[field] ?? peer?.payload?.freshness?.[group];
    return ["fresh", "stale", "missing"].includes(state) ? state : "unknown";
}
function json(value) {
    return JSON.stringify(value, (_, item) => {
        if (typeof item !== "number") return item;
        if (!Number.isFinite(item)) return "[非有限数值]";
        return Number.isInteger(item) && !Number.isSafeInteger(item) ? "[超出精确整数显示范围]" : item;
    }, 2);
}
