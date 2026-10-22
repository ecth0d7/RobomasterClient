import QtQuick
import "OperatorSourcePolicy.js" as Policy

QtObject {
    id: root
    property int clientID: 0
    property var nodes: ({})
    readonly property var current: nodes[String(clientID)] ?? Policy.defaults()
    readonly property string serialized: JSON.stringify({version: 1, nodes: nodes})
    signal edited
    function restore(text) {
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
        } catch (error) { /* 损坏的UI草稿不启动设备或替换权威遥测。 */ }
    }
    function save(value) {
        const clean = Policy.clean(value);
        if (Policy.problems(clean).length) return false;
        const next = Object.assign({}, nodes, {[String(clientID)]: clean});
        if (JSON.stringify({version: 1, nodes: next}).length > 65536) return false;
        nodes = next; edited(); return true;
    }
}
