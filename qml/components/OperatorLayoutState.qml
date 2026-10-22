import QtQuick
import "OperatorLayout.js" as Layout

QtObject {
    id: root
    property int clientID: 0
    property var profiles: ({})
    property bool adviceEditable: false
    readonly property string roleKey: String(Math.max(0, Math.min(9, clientID % 100)))
    readonly property var current: profiles[roleKey] ?? ({})
    readonly property string serialized: JSON.stringify({version: 1, roles: profiles})
    signal edited

    function restore(text) {
        profiles = Layout.parse(text);
    }

    function setShown(id, shown) {
        // 模型面板和组件库共用入口，沿用配置宿主的可编辑权限。
        if (id === "advice" && !adviceEditable)
            return;
        if (!Layout.widgets.some(widget => widget.id === id))
            return;
        const profile = Object.assign({}, current);
        if (shown)
            delete profile[id];
        else
            profile[id] = false;
        const next = Object.assign({}, profiles);
        next[roleKey] = profile;
        profiles = next;
        edited();
    }

    function resetRole() {
        const next = Object.assign({}, profiles);
        if (!adviceEditable && current.advice === false)
            next[roleKey] = {advice: false};
        else
            delete next[roleKey];
        profiles = next;
        edited();
    }
}
