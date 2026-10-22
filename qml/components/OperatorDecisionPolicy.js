.pragma library

var teamStrategies = [
    {id: "balanced", title: "稳健推进", detail: "优先存活与任务完成，避免无依据冒进。"},
    {id: "resource", title: "资源优先", detail: "关注弹量、热量、经济与补给，再判断交战时机。"},
    {id: "objective", title: "目标协同", detail: "围绕队伍目标提供支援、压制与任务协同建议。"}
];
var roleStrategies = [
    {id: "assist", title: "支援与存活", detail: "根据当前机器人能力支援队友，优先规避失控与失效数据。"},
    {id: "task", title: "角色任务优先", detail: "优先本角色的装配、机关、支援、部署或侦察任务。"},
    {id: "pressure", title: "机会压制", detail: "资源与证据充分时提示压制机会，动作仍由操作手确认。"}
];
var shareFields = [
    {id: "health", title: "生命与存活状态"}, {id: "resources", title: "热量与允许弹量"},
    {id: "position", title: "有效位置与坐标来源"}, {id: "objective", title: "角色任务状态"},
    {id: "advice", title: "建议与必要依据 / 快照标识"},
    {id: "sensorEvents", title: "本地传感器 / 电控事件"}, {id: "visionDiscoveries", title: "本地视觉发现 / 目标"},
    {id: "derived", title: "客户端推导 / 置信依据"}
];
// AI用途授权与队内共享独立；这里仅描述本机从选手端取得的遥测分类。
var aiFields = [
    {id: "health", title: "生命与存活状态"}, {id: "resources", title: "热量、弹量与经济"},
    {id: "position", title: "位置与坐标来源"}, {id: "objective", title: "比赛与角色任务状态"}
];
function defaults() {
    return {modelId: "", teamStrategy: "balanced", roleStrategy: "assist", autoAdvice: false,
        trigger: "event", voiceEnabled: false, voicePriority: "caution", voiceAudience: "self",
        voiceSpeaker: "local", shareEnabled: false, shareFields: [],
        localAiFields: [], externalAiFields: [], playerSourceConfirmed: false,
        inputMode: "local", teamFallback: "wait", aggregationEnabled: false,
        advicePosition: "race", adviceDensity: "compact"};
}
function clean(value) {
    const result = defaults();
    if (!value || typeof value !== "object" || Array.isArray(value)) return result;
    if (typeof value.modelId === "string" && value.modelId.length <= 128) result.modelId = value.modelId;
    const enums = {teamStrategy: teamStrategies.map(entry => entry.id), roleStrategy: roleStrategies.map(entry => entry.id),
        inputMode: ["local", "team"], teamFallback: ["wait", "local"], advicePosition: ["race", "right"], adviceDensity: ["compact", "standard"], trigger: ["event", "periodic"], voicePriority: ["info", "caution", "urgent"], voiceAudience: ["self", "team"], voiceSpeaker: ["local", "leader", "designated"]};
    for (const key of Object.keys(enums)) if (enums[key].includes(value[key])) result[key] = value[key];
    for (const key of ["autoAdvice", "voiceEnabled", "shareEnabled", "aggregationEnabled", "playerSourceConfirmed"]) result[key] = value[key] === true;
    result.shareFields = shareFields.filter(entry => Array.isArray(value.shareFields) && value.shareFields.includes(entry.id)).map(entry => entry.id);
    for (const key of ["localAiFields", "externalAiFields"])
        result[key] = aiFields.filter(entry => Array.isArray(value[key]) && value[key].includes(entry.id)).map(entry => entry.id);
    return result;
}
function title(entries, id) { return entries.find(entry => entry.id === id)?.title ?? "未选择"; }
