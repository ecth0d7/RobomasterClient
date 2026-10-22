import QtQuick

QtObject {
    id: root
    property string visual: "ready"
    property bool setupOnly: false
    readonly property var pluginCatalog: [
        {id: "mqtt.mosquitto", title: "Mosquitto · 元数据样例", role: "mqtt", available: true},
        {id: "protocol.rm2026.v2", title: "官方协议 V2 · 元数据样例", role: "protocol", available: true},
        {id: "video.ffmpeg", title: "FFmpeg · 元数据样例", role: "video", available: visual !== "missing-plugin"},
        {id: "state.telemetry", title: "遥测状态 · 元数据样例", role: "state", available: true},
        {id: "input.qt", title: "Qt 输入 · 元数据样例", role: "input", available: true},
        {id: "policy.operator", title: "操作策略 · 元数据样例", role: "policy", available: true}
    ]
    // 人工已应用启动截面；界面草稿变化不修改它，不加载插件或探测端口。
    readonly property var runtime: visual === "unavailable" ? null : ({
        origin: "offline-preview", profileLabel: "operator.json · 离线样例",
        purpose: root.setupOnly ? "preparation" : "operator", setupOnlyVerified: root.setupOnly, rendererActual: "软件绘制 · 离线样例",
        rendererReason: "OpenGL不可用时自动回退的状态绘制样例",
        selected: {host: "192.168.12.1", mqttPort: 3333, videoBind: "0.0.0.0", videoPort: 3334, videoCodec: "hevc", renderer: "auto"},
        pluginCatalog: root.pluginCatalog,
        capabilities: {loadProfile: false, saveProfile: false, applyOnRestart: false},
        pendingRestart: visual === "pending",
        status: visual === "pending" ? "离线样例 · 已有等待下次启动的配置" : visual === "missing-plugin" ? "离线样例 · 核心视频插件未就绪，不能启动操作模式" : root.setupOnly ? "仅准备模式的离线绘制样例 · 未建立比赛连接" : "离线绘制样例 · 并非实际配置检查结果",
        warning: visual === "missing-plugin"
    })
}
