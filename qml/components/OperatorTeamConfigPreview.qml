import QtQuick

QtObject {
    id: root
    property string visual: "absent"
    readonly property var runtime: ({origin: "offline-preview", mock: true, installed: visual !== "absent",
        health: visual, status: ({absent: "汇总网络模块未安装 · 离线样例", authenticating: "核验队伍／节点签名中 · 离线样例",
            ready: "已核验状态的绘制样例 · 不是实际认证", rejected: "发送源签名拒绝 · 离线样例", offline: "成员／汇总链路断连 · 离线样例"})[visual] ?? "状态未公开",
        team_id: "sample-team", local_node: "sample-client-3", issuer: "sample-client-1",
        configuration_revision: "mock-config-7", match_id: "mock-match", epoch: "mock-epoch-not-live",
        authenticated: visual === "ready", handshake_age_ms: visual === "ready" ? 240 : undefined,
        voice_owner: visual === "ready" ? "sample-client-1" : undefined,
        peers: [
            {node_id: "sample-client-1", robot_id: 1, state: visual === "rejected" ? "rejected" : visual === "offline" ? "offline" : visual === "ready" ? "verified" : "pending", age_ms: visual === "ready" ? 120 : undefined},
            {node_id: "sample-client-7", robot_id: 7, state: "offline", age_ms: 4200}
        ],
        rejection: visual === "rejected" ? "人工样例：签名不匹配，不续期字段、不送AI、不播放语音。" : "未提供真实排除记录",
        capabilities: {install: false, activate: false, inspectCertificate: false}
    })
}
