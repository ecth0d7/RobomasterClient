.pragma library
.import "OperatorData.js" as Data

// 官方通信协议 V2.0.0 §2.2.10 / §2.2.23 / §2.2.24。
var shooterNames = ["冷却优先", "爆发优先", "英雄近战优先", "英雄远程优先"];
var chassisNames = ["血量优先", "功率优先", "英雄近战优先", "英雄远程优先"];
var controlNames = ["自动控制", "半自动控制"];
function choices(field, role) {
    const names = field === "shooter" ? shooterNames : chassisNames;
    // 保留官方枚举编号；英雄专用项不因过滤而重编号为1／2。
    return [{value: 0, title: "保持当前"}].concat(names.map((title, index) => ({value: index + 1, title: title}))
        .filter(item => role === 1 ? item.value >= 3 : [3,4,5].includes(role) && item.value <= 2));
}

function reading(telemetry, field) {
    const staticField = {shooter: "performance_system_shooter", chassis: "performance_system_chassis"}[field];
    const syncState = Data.state(telemetry, "robotPerfSync", field);
    const staticState = staticField ? Data.state(telemetry, "robotStatic", staticField) : "missing";
    // 新鲜值优先。没有同步消息时仍可显示静态状态中的体系，不把旧同步盖过新状态。
    const useSync = syncState === "fresh" || (staticState !== "fresh" && syncState !== "missing");
    const state = useSync ? syncState : staticState;
    const value = useSync ? telemetry?.robotPerfSync?.[field] : telemetry?.robotStatic?.[staticField];
    const names = field === "shooter" ? shooterNames : field === "chassis" ? chassisNames : controlNames;
    const offset = field === "sentry_control" ? 0 : 1;
    return {state: state, text: state === "missing" ? "—" : names[value - offset] ?? "未知（" + value + "）"};
}
