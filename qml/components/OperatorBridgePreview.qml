import QtQuick

QtObject {
    id: root
    property string visual: "nominal"
    property var peers: ({})
    readonly property string bridgeStatus: visual === "disabled" ? "未启用 · 离线样例" : visual === "error" ? "离线样例：桥接连接中断" : "实验室桥接 · 离线绘制样例"
    readonly property var bridgeDetails: visual === "unknown" ? ({}) : ({active: visual !== "disabled", listen_port: visual === "disabled" ? 0 : 39393, connections: visual === "empty" ? 1 : visual === "disabled" ? 0 : visual === "many" ? 8 : 2, pending_input_bytes: visual === "error" ? 2048 : 0, pending_output_bytes: 0, dropped: visual === "error" ? 3 : 0, pending_reads: 0, drain_batches: 42, drain_yields: 1, maximum_batch_messages: 32})
    onVisualChanged: reset()
    Component.onCompleted: reset()
    function sample(source, id, fresh, zero) {
        return {source: source, robot_id: id, received_at_ms: 1791896520000, sent_at_ms: 1791896519940, fresh: fresh,
            payload: {client_id: id, connected: id !== 107, groups: {
                gameStatus: {current_round: 1, red_score: 2, blue_score: 1, stage: 4, stage_remain_time: 187},
                robotDynamic: {current_health: zero ? 0 : 320, current_heat: 72, remaining_ammo: zero ? 0 : 120},
                robotStatic: {max_health: 400, max_heat: 200},
                customByteBlock: {data: "00ff4142"},
                pluginExample: {enabled: false, note: "扩展样例：<tag> 按纯文本显示", count: 0}},
                freshness: {gameStatus: "fresh", robotDynamic: "fresh", robotStatic: "fresh", customByteBlock: "fresh", pluginExample: "fresh"},
                field_freshness: {robotDynamic: {current_health: "fresh", current_heat: "fresh", remaining_ammo: "stale"}},
                robots: {}}};
    }
    function reset() {
        expiry.stop();
        if (["disabled", "empty", "unknown"].includes(visual)) { peers = {}; return; }
        const result = {}, count = visual === "many" ? 16 : 2;
        for (let i = 0; i < count; ++i) {
            const source = visual === "long" && i === 0 ? "sample-01-" + "a".repeat(85) : "sample-" + String(i + 1).padStart(2, "0") + "-00000000-0000-4000-8000-000000000000";
            result[source] = sample(source, i === 0 ? 3 : i === 1 ? 107 : 101 + i % 9, visual === "stale" ? false : i === 0, visual === "zero");
            if (visual === "partial" && i === 0) { delete result[source].payload.groups.robotStatic; delete result[source].payload.groups.robotDynamic.current_heat; delete result[source].payload.field_freshness; }
        }
        peers = result;
        if (visual === "expires") expiry.restart();
    }
    property Timer expiry: Timer {
        interval: 6000
        onTriggered: {
            // 只替换人工快照对象，保留“固定查看”持有的旧对象。
            const next = Object.assign({}, root.peers), source = Object.keys(next).sort()[0];
            if (!source) return;
            next[source] = Object.assign({}, next[source], {fresh: false});
            root.peers = next;
        }
    }
}
