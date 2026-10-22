import QtQuick
import "OperatorDecisionPolicy.js" as Policy

QtObject {
    id: root
    property string teamId: "local"
    property int clientID: 0
    property var runtime: null
    property var roles: ({})
    property var teams: ({})
    // 未认证队伍只隔离本地阵营偏好，不把机器人编号当作队内成员认证。
    readonly property string teamKey: teamId === "local" ? "local:" + (clientID >= 100 ? "blue" : "red") : teamId
    readonly property string roleKey: teamKey + ":" + clientID
    readonly property var current: runtime !== null ? runtime.current
        : Object.assign(Policy.defaults(), roles[roleKey] ?? {}, {teamStrategy: teams[teamKey] ?? "balanced"})
    readonly property string serialized: JSON.stringify({version: 1, roles: roles, teams: teams})
    signal edited
    function restore(text) {
        // 生产策略以宿主存档为准，旧UI偏好不能覆盖输入授权或来源确认。
        if (runtime !== null) return;
        if (typeof text !== "string" || text.length > 32768) return;
        try {
            const stored = JSON.parse(text);
            if (stored.version !== 1 || !stored.roles || !stored.teams) return;
            const nextRoles = {}, nextTeams = {};
            for (const key of Object.keys(stored.roles).slice(0, 64)) {
                if (key.length > 160) continue;
                nextRoles[key] = Policy.clean(stored.roles[key]);
            }
            for (const key of Object.keys(stored.teams).slice(0, 32)) {
                if (key.length <= 96 && Policy.teamStrategies.some(entry => entry.id === stored.teams[key])) nextTeams[key] = stored.teams[key];
            }
            roles = nextRoles; teams = nextTeams;
        } catch (error) { /* 旧或损坏的偏好不替代明确默认值，也不装载可执行内容。 */ }
    }
    function save(values) {
        const clean = Policy.clean(values);
        // 不发edited、不改legacy存档，防止宿主提交后另写一份QtSettings。
        if (runtime !== null) return runtime.save(clean) === true;
        const nextRoles = Object.assign({}, roles), nextTeams = Object.assign({}, teams);
        if (!nextRoles[roleKey] && Object.keys(nextRoles).length >= 64 || !nextTeams[teamKey] && Object.keys(nextTeams).length >= 32) return false;
        nextTeams[teamKey] = clean.teamStrategy;
        delete clean.teamStrategy;
        nextRoles[roleKey] = clean;
        if (JSON.stringify({version: 1, roles: nextRoles, teams: nextTeams}).length > 32768) return false;
        roles = nextRoles; teams = nextTeams;
        edited();
        return true;
    }
}
