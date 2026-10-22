.pragma library

// 2026 V2.0.0附录二：机器人编号1–9／101–109；MQTT clientID使用机器人编号。
var loginRoles = [1, 2, 3, 4, 5, 6, 7, 8, 9];
function loginIds() { return loginRoles.concat(loginRoles.map(id => id + 100)); }
function validLogin(id) { return typeof id === "number" && loginIds().includes(id); }

function number(value, decimals) {
    if (typeof value !== "number" || !Number.isFinite(value)) return "—";
    return decimals === undefined ? String(value) : value.toFixed(decimals);
}
function role(id) {
    const base = Number(id) > 100 ? Number(id) - 100 : Number(id);
    return ({1:"英雄", 2:"工程", 3:"步兵 3", 4:"步兵 4", 5:"步兵 5", 6:"空中", 7:"哨兵", 8:"飞镖", 9:"雷达"})[base] ?? "未选身份";
}
function roleSection(id) {
    return ({1: "hero", 2: "engineer", 3: "rune", 4: "rune", 5: "rune",
             6: "air", 7: "sentry", 8: "dart", 9: "sentry"})[Number(id) % 100] ?? "rune";
}
function stage(value) {
    if (value === undefined || value === null) return "等待比赛数据";
    // V2.0.0 §2.2.3 只定义 0..5；暂停由 is_paused 单独表示。
    return ({0:"赛前准备", 1:"准备阶段", 2:"裁判自检", 3:"倒计时", 4:"比赛进行中", 5:"比赛结算"})[value] ?? "未知阶段（" + value + "）";
}
function time(value) {
    if (typeof value !== "number" || !Number.isFinite(value) || value < 0) return "—:—";
    const seconds = Math.floor(value);
    return Math.floor(seconds / 60).toString().padStart(2, "0") + ":" + (seconds % 60).toString().padStart(2, "0");
}
function command(topic) {
    return ({KeyboardMouseControl:"键鼠输入",CustomControl:"自定义控制",MapClickCmd:"地图标记",
        AssemblyCommand:"机器人装配",RobotPerformanceSelectionCommand:"性能配置",CommonCommand:"通用操作",
        HeroDeployModeEventCommand:"英雄部署",RuneActivateCommand:"机关激活",DartCommand:"飞镖选靶",
        SentryCtrlCommand:"哨兵指令",AirSupportCommand:"空中支援"})[topic] ?? "扩展操作";
}
