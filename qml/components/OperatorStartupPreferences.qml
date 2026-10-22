import QtQuick
import "OperatorStartupPolicy.js" as Startup

QtObject {
    id: root
    // 只记住连接配置的UI草稿；不把它当成本次实际 AppConfig 或生效配置文件。
    property var current: Startup.defaults()
    readonly property string serialized: JSON.stringify({version: 1, draft: current})
    signal edited
    function restore(text) {
        if (typeof text !== "string" || text.length > 16384) return;
        try {
            const stored = JSON.parse(text);
            if (stored.version === 1 && Startup.valid(stored.draft)) current = Startup.clean(stored.draft);
        } catch (error) { /* 损坏的草稿不替代明确默认值。 */ }
    }
    function save(value) {
        if (!Startup.valid(value)) return false;
        const next = Startup.clean(value);
        if (JSON.stringify({version: 1, draft: next}).length > 16384) return false;
        current = next;
        edited();
        return true;
    }
}
