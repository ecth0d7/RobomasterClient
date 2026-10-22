import QtQuick

QtObject {
    id: root
    property string visual: "absent"
    readonly property var runtime: ({mock: true, origin: "offline-preview", health: visual,
        status: ({absent: "未接数据源插件 · 本机选手端路径继续", ready: "人工模拟源有效 · 没有真实设备",
            stale: "人工模拟项过期 · 不落图、不送AI", rejected: "人工载荷格式拒绝 · 不替换已有数据",
            offline: "人工源失联 · 单机其他来源独立"})[visual] ?? "状态未公开",
        capabilities: {inspectAdapter: false, activate: false},
        adapters: visual === "absent" ? [] : [{id: "example.mock.v1", title: "模拟适配器 · 绘制样例", kinds: ["local_vision"]}],
        sources: visual === "absent" ? [] : [{id: "mock-camera", sensor_id: "camera-mock", robot_id: 3,
            source_kind: "local_vision", adapter_id: "example.mock.v1", adapter_version: "drawing.1",
            state: visual === "ready" ? "mock-active" : visual, item_type: "target_observation", unit: "m",
            generated_at: "2026-10-13T19:00:00.000Z", received_at: "2026-10-13T19:00:00.020Z",
            age_ms: visual === "ready" ? 120 : 2400, remaining_ms: visual === "ready" ? 880 : 0,
            confidence: 0.72, verification: "mock-unverified", frame_id: "camera.mock", frame_revision: "calibration-mock-1",
            projection: "未标定到赛场 · 不显示地图目标", rejection: visual === "rejected" ? "模拟：载荷版本不支持" : "",
            uses: "仅绘制 · 没有模型请求、队内发送或机器人动作"}]
    })
}
