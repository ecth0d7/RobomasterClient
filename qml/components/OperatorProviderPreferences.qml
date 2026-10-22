import QtQuick
import "OperatorProviderPolicy.js" as Policy

QtObject {
    id: root
    property int clientID: 0
    property var runtime: null
    property var nodes: ({})
    readonly property var current: runtime !== null ? runtime.current : nodes[String(clientID)] ?? Policy.defaults()
    readonly property string serialized: JSON.stringify({version: 1, nodes: nodes})
    signal edited
    function restore(text) {
        // 生产配置由宿主按当前profile／机器人读取；旧UI存档不能覆盖它。
        if (runtime !== null) return;
        if (typeof text !== "string" || text.length > 65536) return;
        try {
            const stored = JSON.parse(text), next = {};
            if (stored.version !== 1 || !stored.nodes || Array.isArray(stored.nodes)) return;
            for (const key of Object.keys(stored.nodes).slice(0, 19)) {
                if (!/^(?:0|[1-9]|10[1-9])$/.test(key)) continue;
                const value = Policy.clean(stored.nodes[key]);
                if (!Policy.problems(value).length) next[key] = value;
            }
            nodes = next;
        } catch (error) { /* UI草稿不能替代认证，也不在恢复时启动模型。 */ }
    }
    function save(value) {
        const clean = Policy.clean(value);
        // 不改legacy nodes、不发edited，避免宿主保存后又写回另一份QtSettings。
        if (runtime !== null) return runtime.save(clean) === true;
        if (Policy.problems(clean).length) return false;
        const next = Object.assign({}, nodes, {[String(clientID)]: clean});
        if (JSON.stringify({version: 1, nodes: next}).length > 65536) return false;
        nodes = next; edited(); return true;
    }
}
