import QtQuick
import "OperatorTeamConfigPolicy.js" as Policy

QtObject {
    id: root
    property int clientID: 0
    property var hostConfiguration: null
    property var nodes: ({})
    readonly property string nodeKey: String(clientID)
    readonly property var current: hostConfiguration !== null ? hostConfiguration.current : nodes[nodeKey] ?? Policy.defaults()
    readonly property string serialized: JSON.stringify({version: 1, nodes: nodes})
    signal edited
    function restore(text) {
        // 生产配置按宿主实例／机器人隔离，旧QtSettings草稿不能覆盖权限或重启网络。
        if (hostConfiguration !== null) return;
        if (typeof text !== "string" || text.length > 65536) return;
        try {
            const stored = JSON.parse(text), next = {};
            if (stored.version !== 1 || !stored.nodes || Array.isArray(stored.nodes)) return;
            for (const key of Object.keys(stored.nodes).slice(0, 19)) {
                if (!/^(?:0|[1-9]|10[1-9])$/.test(key)) continue;
                const value = Policy.clean(stored.nodes[key]);
                if (!Policy.problems(value, Number(key)).length) next[key] = value;
            }
            nodes = next;
        } catch (error) { /* 损坏的UI草稿不变成认证材料或运行配置。 */ }
    }
    function save(value) {
        // 生产保存由宿主严格校验；失败后不写旧草稿，也不把授权字段清洗成另一份可接受配置。
        if (hostConfiguration !== null) return hostConfiguration.save(value) === true;
        const clean = Policy.clean(value);
        if (Policy.problems(clean, clientID).length) return false;
        const next = Object.assign({}, nodes, {[nodeKey]: clean});
        if (JSON.stringify({version: 1, nodes: next}).length > 65536) return false;
        nodes = next; edited(); return true;
    }
}
