.pragma library
.import "UiFormat.js" as Format

var groupTitles = {
    gameStatus: "比赛状态", globalUnit: "全局单位", globalLogistics: "队伍后勤",
    globalSpecial: "特殊机制", event: "赛场事件", robotInjury: "受伤统计",
    robotRespawn: "复活状态", robotStatic: "机器人静态状态", robotDynamic: "机器人动态状态",
    robotModule: "机器人模块", robotPosition: "自身坐标", buff: "增益", penalty: "判罚",
    robotPath: "机器人路径", radar: "雷达信息", customByteBlock: "自定义数据",
    techCore: "科技核心", robotPerfSync: "性能体系同步", deployMode: "英雄部署",
    runeStatus: "能量机关", sentryStatus: "哨兵姿态", dartTarget: "飞镖目标",
    sentryCtrlResult: "哨兵指令结果", airSupport: "空中支援", mapClick: "地图标记"
};

function boolean(value, yes, no) {
    return value === true ? yes : value === false ? no : "—";
}
function number(value, unit, decimals) {
    const text = Format.number(value, decimals);
    return text === "—" ? text : text + (unit ?? "");
}
function kibibytes(value) {
    return typeof value === "number" && Number.isFinite(value) && value > 0
        ? number(value / 1024, " KiB", 0) : "—";
}
function codec(value) {
    if (value === "hevc") return "HEVC / H.265";
    if (value === "h264") return "H.264";
    if (value === "auto") return "自动识别";
    return typeof value === "string" && value.length ? value : "—";
}
function dimensions(width, height) {
    return Number.isSafeInteger(width) && width>0 && Number.isSafeInteger(height) && height>0
        ? width+" × "+height : "—";
}
function groups(telemetry) {
    // 分组由可替换状态插件提供，不在 UI 中推算 TTL 或把缺失值补为零。
    const freshness = telemetry?.freshness ?? {};
    // Each native getter returns a QVariantMap. Read the complete field map
    // once, rather than converting it again for every one of the 25 groups.
    const fieldFreshness = telemetry?.fieldFreshness ?? {};
    return Object.keys(freshness).sort().map(key => {
        const fields=fieldFreshness[key] ?? {};
        let oldFields=0;
        for(const field of Object.keys(fields))if(fields[field]==="stale")++oldFields;
        return {key:key,title:groupTitles[key] ?? key,
            state:["fresh","stale","missing"].includes(freshness[key]) ? freshness[key] : "missing",oldFields};
    });
}
function summary(entries) {
    const result = {fresh: 0, stale: 0, missing: 0, total: entries.length};
    for (const entry of entries) ++result[entry.state];
    return result;
}
function stateName(state) {
    return ({fresh: "有效", stale: "旧数据", missing: "未收到"})[state] ?? "未知";
}
function commandResult(entry) {
    return boolean(entry?.accepted, "本地已提交", "本地未提交");
}
function commandTime(entry) {
    const stamp = entry?.recorded_at;
    return typeof stamp === "string" && /^\d{4}-\d{2}-\d{2}T/.test(stamp) ? stamp.slice(11, 19) + " UTC" : "—";
}
