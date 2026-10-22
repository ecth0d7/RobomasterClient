import QtQuick

QtObject {
    id: root
    property string visual: "pending"
    readonly property var runtime: ({mock: true, health: visual,
        status: ({pending: "生产提供者配置未接通 · 人工状态", ready: "人工模型就绪样例 · 不证明实际账号", busy: "人工请求中样例 · 无实际请求",
            error: "人工模型超时样例 · 建议已失效", offline: "人工服务失联样例 · 本机HUD继续"})[visual] ?? "未公开",
        provider_id: visual === "pending" ? undefined : "example.http", model: visual === "pending" ? undefined : "mock-model",
        inference_location: visual === "pending" ? undefined : "external", api: "chat", format: "json-object",
        endpoint: visual === "pending" ? undefined : "https://example.invalid/chat/completions", configuration_revision: visual === "pending" ? undefined : 4, credentials: "不公开密钥 / 未进行认证",
        request_id: visual === "busy" ? "mock-request-4" : undefined, input_mode: visual === "pending" ? undefined : "local", snapshot: visual === "pending" ? undefined : "mock-local-view-4",
        latency_ms: visual === "error" ? 15000 : undefined,
        capabilities: {inspect: false, activate: false, listModels: false}
    })
}
