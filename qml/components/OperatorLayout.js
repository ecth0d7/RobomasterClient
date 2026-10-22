.pragma library

// 稳定 ID 是外部布局配置的接口；标题、贴图和机器人身份可以独立变更。
var widgets = [
    {id: "scoreboard", title: "比分 / 时间 / 建筑血量", area: "顶部"},
    {id: "redRoster", title: "红方机器人", area: "左上"},
    {id: "blueRoster", title: "蓝方机器人", area: "右上"},
    {id: "economy", title: "队伍经济", area: "顶部中央"},
    {id: "advice", title: "AI 建议 / 依据 / 来源", area: "有效时显示"},
    {id: "reticle", title: "准星 / 热量 / 射击读数", area: "中央"},
    {id: "discoveries", title: "本机感知 / 队友发现", area: "机器人消息区"},
    {id: "messages", title: "系统 / 机器人消息组", area: "左侧"},
    {id: "raceMessages", title: "系统通知槽", area: "消息组上槽"},
    {id: "robotMessages", title: "独立机器人通知槽", area: "消息组下槽"},
    {id: "vitals", title: "自身状态 / 空中专属条", area: "左下"},
    {id: "combatState", title: "战斗 / 脱战标记与倒数", area: "自身生命右侧"},
    {id: "penaltyBadge", title: "自身黄牌 / 红牌徽章", area: "归属已核验时显示"},
    {id: "ownEffects", title: "虚弱 / 断电 / 功率提示", area: "有可信来源时显示"},
    {id: "buffs", title: "本机增益 / 来源 / 时效", area: "自身状态上方"},
    {id: "modules", title: "模块／底部状态", area: "左下"},
    {id: "map", title: "战场地图", area: "右下"},
    {id: "keys", title: "键盘 / 鼠标显示", area: "右下"},
    {id: "exchangeHint", title: "兑换入口", area: "底部中央"},
    {id: "videoStatus", title: "图传等待提示", area: "中央"}
];

function shown(profile, id) {
    return profile?.[id] !== false;
}

function parse(text) {
    // 配置只保存布尔显示偏好，不能携带代码、资源路径或遥测数据。
    if (typeof text !== "string" || text.length > 16384)
        return {};
    try {
        const source = JSON.parse(text);
        if (source?.version !== 1 || !source.roles || Array.isArray(source.roles))
            return {};
        const roles = {};
        for (let role = 0; role <= 9; ++role) {
            const profile = source.roles[String(role)];
            if (!profile || typeof profile !== "object" || Array.isArray(profile))
                continue;
            const clean = {};
            for (const widget of widgets) {
                if (profile[widget.id] === false)
                    clean[widget.id] = false;
            }
            roles[String(role)] = clean;
        }
        return roles;
    } catch (error) {
        return {};
    }
}
