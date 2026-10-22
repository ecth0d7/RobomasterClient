.pragma library

// 这里只校验绘制阶段的配置草稿；源身份、协议、时钟和标定由宿主适配器核验。
var kinds = [
    {id: "local_sensor", title: "本地传感器 / 电控"},
    {id: "local_vision", title: "本地视觉算法"},
    {id: "derived", title: "本机推导"}
];
var transports = [
    {id: "player_private_bytes", title: "选手端 CustomByteBlock · 私有载荷"},
    {id: "local_ipc", title: "本地 IPC / 算法进程"},
    {id: "device_adapter", title: "设备适配器 · 协议待核实"},
    {id: "mock", title: "明确模拟源 · 不代表设备"}
];
var uses = [
    {id: "hud", title: "本机 HUD / 地图"}, {id: "alerts", title: "本机告警"},
    {id: "localAi", title: "本地模型输入"}, {id: "externalAi", title: "外部模型输入"},
    {id: "share", title: "允许队内共享 · 仍须队伍授权"}
];
function defaults() { return {sources: []}; }
function sourceDefaults() {
    return {id: "", label: "", kind: "local_sensor", sensorId: "", adapterId: "", enabled: false,
        transport: "player_private_bytes", endpoint: "", schemaId: "", schemaVersion: "1",
        itemType: "", unit: "", ttlMs: "1000", clockDomain: "", confidenceDefinition: "",
        spatial: false, frameId: "", frameRevision: "", transformId: "", uses: {}};
}
function token(value) { return typeof value === "string" && /^[A-Za-z0-9][A-Za-z0-9_.-]{0,95}$/.test(value); }
function line(value) { return typeof value === "string" && value.length <= 512 && !/[\x00-\x1f\x7f]/.test(value); }
function lifetimeError(value) {
    return /^\d+$/.test(value) && Number(value) >= 100 && Number(value) <= 60000 ? "" : "有效期须为100–60000 ms。";
}
function stateTitle(value) {
    return ({"mock-active": "模拟项有效 · mock", active: "宿主接纳项有效", fresh: "本机接收时效有效", stale: "已过期", expired: "已过期",
        registered: "已登记 · 按样本独立核对", waiting: "等待样本", time_unverified: "时钟映射未核验", conflict: "版本冲突 · 已隔离",
        withdrawn: "已撤回", rejected: "已拒绝", offline: "来源失联", retracted: "已撤回", missing: "没有有效项"})[value] ?? "状态未识别 · " + value;
}
function cleanSource(value) {
    const result = sourceDefaults();
    if (!value || typeof value !== "object") return result;
    for (const key of Object.keys(result)) {
        if (typeof result[key] === "boolean") result[key] = value[key] === true;
        else if (typeof result[key] === "string" && typeof value[key] === "string") result[key] = value[key].slice(0, 512);
    }
    for (const use of uses) if (value.uses?.[use.id] === true) result.uses[use.id] = true;
    return result;
}
function clean(value) { return {sources: Array.isArray(value?.sources) ? value.sources.slice(0, 16).map(cleanSource) : []}; }
function sourceError(source, others) {
    if (!token(source.id)) return "来源ID：1–96个字母、数字、点、下划线或连字符。";
    if (others.some(item => item.id === source.id)) return "来源ID与已有草稿重复。";
    for (const key of Object.keys(source)) if (typeof source[key] === "string" && !line(source[key])) return "字段含控制字符或超过长度限制。";
    if (!kinds.some(item => item.id === source.kind) || !transports.some(item => item.id === source.transport)) return "来源类型或传输方式不受支持。";
    if (lifetimeError(source.ttlMs)) return lifetimeError(source.ttlMs) + " 收到消息不能延长产生时间的寿命。";
    if (!/^\d+$/.test(source.schemaVersion) || Number(source.schemaVersion) < 1 || Number(source.schemaVersion) > 65535) return "载荷版本：1–65535。";
    if (!source.enabled) return "";
    if (![source.sensorId, source.adapterId, source.schemaId, source.itemType, source.clockDomain].every(token)) return "启用意向须填写传感器、适配器、载荷、数据类型与时钟域ID。";
    if (!source.unit.trim()) return "填写数据单位；无量纲请明确写 dimensionless。";
    if (source.transport !== "player_private_bytes" && !source.endpoint.trim()) return "填写独立适配器端点；此处不自动连接或执行进程。";
    if (source.spatial && (!token(source.frameId) || !token(source.frameRevision))) return "空间项须有坐标系与标定版本；没有有效转换时不得落图。";
    if (source.uses.externalAi && source.transport === "mock") return "模拟源不能授权外部模型输入。";
    return "";
}
function problems(value) {
    const result = [];
    for (let index = 0; index < value.sources.length; index++) {
        const issue = sourceError(value.sources[index], value.sources.filter((_, other) => index !== other));
        if (issue) result.push(value.sources[index].id + "：" + issue);
    }
    return result;
}
function title(items, id) { return items.find(item => item.id === id)?.title ?? "未知配置 · " + id; }
