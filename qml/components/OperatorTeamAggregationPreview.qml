import QtQuick

QtObject {
    id: root
    property string visual: "ready"
    property int sequenceStep: 0
    readonly property string phase: visual === "sequence" ? ["collecting", "ready", "partial", "offline"][sequenceStep] : visual
    readonly property bool hasView: ["ready", "partial", "conflict", "zero", "offline"].includes(phase)
    readonly property var details: ({origin: "offline-preview", installed: phase !== "absent", enabled: !["absent", "disabled", "unknown"].includes(phase),
        state: phase, view_usable: hasView && phase !== "offline", role: "aggregation", plugin_id: "sample.team.aggregate",
        publisher_id: "sample-leader", voice: "主节点统一播报样例 · 未接通音频", configuration_available: false})
    readonly property string status: "离线绘制样例 · " + ({absent: "插件未安装", disabled: "插件已关闭", collecting: "汇集中 · 未发布完整视图", ready: "完整视图可供检查", partial: "部分成员离线 · 排除旧字段", conflict: "同版本冲突 · 字段隔离", zero: "零值 / false 保留", offline: "汇总端断连 · 视图失效", auth: "队伍 / 发送者认证失败", unknown: "状态未提供"})[phase]
    readonly property var view: hasView ? makeView() : ({})
    function field(path, value, source, robot, state, kind) {
        return {path: path, value: value, data_type: typeof value, source_kind: kind, sensor_id: null,
            producer_version: "mock-export-adapter", confidence: null, verification: "offline mock / 未核验",
            lifecycle: state === "stale" ? "expired" : state === "conflict" ? "conflict" : "active",
            received_at_ms: 1791900000180, source_node: source, robot_id: robot, state: state, kind: kind,
            player_export_id: kind === "derived" ? null : "sample-player-" + robot,
            snapshot_id: "sample-export-snapshot-" + robot, field_revision: 12,
            origin_observed_at_ms: 1791900000000, received_age_ms: state === "stale" ? 3600 : 180,
            remaining_ms: state === "stale" ? 0 : 800, trust: "offline-sample", accepted: state === "fresh" || state === "derived"};
    }
    function makeView() {
        const partial = phase === "partial" || phase === "offline";
        const zero = phase === "zero";
        const conflict = phase === "conflict";
        return {origin: "offline-preview", view_id: "sample-team-view-17", revision: partial ? 18 : 17,
            issuer_id: "sample-leader", team_id: "sample-team", match_id: "sample-match", epoch: "sample-epoch-a",
            received_age_ms: phase === "offline" ? 5000 : 240, remaining_ms: phase === "offline" ? 0 : 760,
            generated_at_ms: 1791900000000, verified: false, status: partial ? "partial" : "ready",
            members: [
                {node_id: "sample-client-3", robot_id: 3, player_export_id: "sample-player-3", snapshot_id: "sample-export-snapshot-3", state: "fresh", auth: "offline-sample", age_ms: 180},
                {node_id: "sample-client-1", robot_id: 1, player_export_id: "sample-player-1", snapshot_id: "sample-export-snapshot-1", state: partial ? "stale" : "fresh", auth: "offline-sample", age_ms: partial ? 3600 : 220},
                {node_id: "sample-client-7", robot_id: 7, player_export_id: "sample-player-7", snapshot_id: "sample-export-snapshot-7", state: "missing", auth: "offline-sample"}],
            fields: [
                field("robotDynamic.current_health", zero ? 0 : 320, "sample-client-3", 3, "fresh", "official_player_client"),
                field("gameStatus.is_paused", false, "sample-client-3", 3, "fresh", "official_player_client"),
                field("robotDynamic.remaining_ammo", zero ? 0 : 120, "sample-client-3", 3, conflict ? "conflict" : "fresh", "official_player_client"),
                field("strategy.resource_pressure", "补给优先 · 独立推导层", "sample-client-3", 3, "derived", "derived"),
                field("robotDynamic.current_health", 240, "sample-client-1", 1, partial ? "stale" : "fresh", "official_player_client")],
            discoveries: [
                {item_id: "mock-vision-target-23", data_type: "target.observation", source_kind: "local_vision", source_robot: 1,
                    source_node: "sample-client-1", sensor_id: "mock-front-camera", producer_version: "mock-detector", source_time_ms: 1791900000000,
                    received_at_ms: 1791900000120, received_age_ms: partial ? 3600 : 120, remaining_ms: partial ? 0 : 800,
                    confidence: 0.72, verification: "mock / 未经实机核验", lifecycle: partial ? "expired" : "active",
                    frame_id: "rm2026.field", frame_revision: "mock-calibration-1", unit: "m", x: 18.2, y: 8.1,
                    summary: "队友视觉：疑似目标 · 尚待确认", trust: "offline-sample", mock: true},
                {item_id: "mock-sensor-warning-4", data_type: "sensor.warning", source_kind: "local_sensor", source_robot: 3,
                    source_node: "sample-client-3", sensor_id: "mock-control-board", producer_version: "mock-serial-adapter", source_time_ms: 1791900000000,
                    received_at_ms: 1791900000100, received_age_ms: 100, remaining_ms: 1000, confidence: null,
                    verification: "mock / 尚无电控适配器", lifecycle: phase === "conflict" ? "withdrawn" : "active",
                    frame_id: "robot.body", unit: "m", summary: "本机电控：模块温度关注样例", trust: "offline-sample", mock: true}
            ],
            excluded: [
                {path: "robotDynamic.current_health", source_node: "sample-client-7", reason: "该成员未收到有效字段 · 不填 0"},
                {path: "raw_bytes / video / secrets", source_node: "全部成员", reason: "字段不在授权白名单 · 不进入汇总或 AI"},
                {path: "export-snapshot-11", source_node: "sample-client-1", reason: "迟到或重复源序号 · 丢弃，不重新标 fresh"}
            ].concat(partial ? [{path: "robotDynamic.current_health", source_node: "sample-client-1", reason: "字段独立过期 · 成员心跳不延长数据有效期"}] : [])
                .concat(conflict ? [{path: "robotDynamic.remaining_ammo", source_node: "sample-client-3", reason: "同源同版本不同值 · 隔离冲突，不按到达顺序覆盖"}] : [])};
    }
    readonly property var projection: ({mock: true, verified: false, markers: hasView && !["partial", "offline"].includes(phase) ? [{item_id: "mock-vision-target-23", label: "视", source_kind: "local_vision", source_robot: 1, mock: true, x: 18.2, y: 8.1, frame_id: "rm2026.field", frame_revision: "mock-calibration-1", unit: "m", lifecycle: "active", renderable: true}] : []})
    onVisualChanged: { sequenceStep = 0; if (visual === "sequence") progression.restart(); else progression.stop(); }
    // 只驱动离线绘制状态；不收发队伍消息、不实现汇总或认证。
    property Timer progression: Timer { interval: 4200; repeat: true; onTriggered: { root.sequenceStep = Math.min(3, root.sequenceStep + 1); if (root.sequenceStep === 3) stop(); } }
}
