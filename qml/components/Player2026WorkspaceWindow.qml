import QtQuick

// 与正式入口共用所有原生接线；仅选择保留HUD，不经过DesignerPreview。
Main {
    title: "RoboMaster 2026 选手端"
    initialPanel: clientBackend.connected || clientBackend.connecting ? "none" : "login"
    ui.retainedHudWorkspace: true
    workspaceCaption: "2026 选手端 · "
        + (ui.mqttConnected ? "已连接 [点击配置]" : "未连接 [点击登录]")
}
