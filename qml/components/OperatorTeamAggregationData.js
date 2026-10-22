.pragma library

// 只格式化宿主已发布的完整视图；UI 不合并报文、不猜测认证或字段时效。
function text(value) { return typeof value === "string" && value.length ? value : "未提供"; }
function number(value, suffix) { return typeof value === "number" && Number.isFinite(value) ? String(value) + (suffix || "") : "—"; }
function value(field) {
    if (!field || field.state === "missing" || field.value === undefined || field.value === null) return "未提供";
    return typeof field.value === "object" ? JSON.stringify(field.value) : String(field.value);
}
function mode(value) { return value === "team" ? "队伍整合数据" : value === "local" ? "本机机器人数据" : "未提供输入范围"; }
function state(value) {
    return ({fresh: "新鲜", stale: "已旧", missing: "未收到", conflict: "冲突隔离", rejected: "拒绝", derived: "客户端推导",
        online: "在线 · 字段独立计时", offline: "失联", withdrawn: "已撤回"})[value] ?? "时效未提供";
}
function kind(value) { return ({official_player_client: "选手端数据转述", local_sensor: "本地传感器 / 电控", local_vision: "本地视觉发现", derived: "客户端推导 / 非权威"})[value] ?? "来源类别未提供"; }
function members(view) { return Array.isArray(view?.members) ? view.members.slice(0, 16) : []; }
function fields(view, member) { return Array.isArray(view?.fields) ? view.fields.filter(field => field.source_node === member).slice(0, 64) : []; }
function exclusions(view) { return Array.isArray(view?.excluded) ? view.excluded.slice(0, 64) : []; }

function discoveries(view) { return Array.isArray(view?.discoveries) ? view.discoveries.slice(0, 32) : []; }
function confidence(value) { return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 1 ? Math.round(value * 100) + "%" : "未提供"; }
function lifecycle(value) { return ({active: "有效期内", expired: "已过期", withdrawn: "已撤回", retracted: "已撤回", unverified: "未核验", conflict: "冲突隔离"})[value] ?? "生命周期未提供"; }
function markers(projection, previewOnly) {
    // 旧raw投影缺少独立时效与观测关联，不再进入活动地图；仅供原始详情保留。
    // 当前renderer统一消费OperatorDiscoveryData.project的已限定结果。
    return [];
}

function shortKind(value) { return ({official_player_client: "选手端", local_sensor: "电控感知", local_vision: "视觉", derived: "推导"})[value] ?? "未知来源"; }
