.pragma library

var kinds = [{id: "deepseek", title: "DeepSeek API · 外部推理"}, {id: "local-http", title: "本机 HTTP 模型服务"},
    {id: "remote-http", title: "自定义 HTTPS 模型服务"}, {id: "codex", title: "本机 Codex 进程 · 可联网推理"}];
function defaults(kind) {
    const selected = kinds.some(item => item.id === kind) ? kind : "deepseek";
    return {kind: selected, enabled: false, endpoint: selected === "deepseek" ? "https://api.deepseek.com/chat/completions" : selected === "local-http" ? "http://127.0.0.1:8000/v1/chat/completions" : "",
        model: selected === "deepseek" ? "deepseek-flash" : selected === "codex" ? "gpt-6.1-sol" : "",
        keyEnv: selected === "deepseek" ? "DEEPSEEK_API_KEY" : "", api: "chat", format: selected === "deepseek" ? "json-object" : "json-schema",
        executable: "codex", authHome: "", reasoning: "high", timeoutMs: "15000", minimumIntervalMs: "1000",
        maxOutputTokens: "1200", thinking: false};
}
function clean(value) {
    const result = defaults(value?.kind);
    if (!value || typeof value !== "object") return result;
    for (const key of Object.keys(result)) {
        if (typeof result[key] === "boolean") result[key] = value[key] === true;
        else if (typeof value[key] === "string") result[key] = value[key].slice(0, 512);
    }
    return result;
}
function integer(value, low, high) { return /^\d+$/.test(value) && Number(value) >= low && Number(value) <= high; }
function endpointError(value) {
    if (value.kind === "codex") return "";
    if (!/^https?:\/\/[^/?#@\s]+\/[^?#\s]*$/.test(value.endpoint)) return "完整HTTP(S)推理路径；不能含账号、查询凭据或片段。";
    const local = /^https?:\/\/(?:127\.0\.0\.1|localhost|\[::1\])(?::\d+)?\//.test(value.endpoint);
    if (value.kind === "local-http" && !local) return "本机服务仅接受loopback；远端请明确选择HTTPS服务。";
    if (value.kind !== "local-http" && !value.endpoint.startsWith("https://")) return "外部模型端点必须使用HTTPS。";
    return "";
}
function problems(value) {
    const result = [];
    for (const key of Object.keys(value)) if (typeof value[key] === "string" && /[\x00-\x1f\x7f]/.test(value[key])) result.push("字段不能含控制字符。");
    if (!kinds.some(item => item.id === value.kind)) result.push("提供者类型未识别。");
    if (!integer(value.timeoutMs, 50, 120000)) result.push("总超时50–120000 ms。");
    if (!integer(value.minimumIntervalMs, 500, 30000)) result.push("最小请求间隔500–30000 ms。");
    if (!integer(value.maxOutputTokens, 256, 8192)) result.push("最大输出256–8192 tokens；须核对提供者能力。");
    if (!['chat','responses'].includes(value.api) || !['json-schema','json-object'].includes(value.format) || !['low','medium','high'].includes(value.reasoning)) result.push("API／输出格式／推理强度不受支持。");
    if (value.keyEnv && !/^[A-Za-z_][A-Za-z0-9_]{0,95}$/.test(value.keyEnv)) result.push("API密钥只填写环境变量名，不填密钥值。");
    if (value.kind === "deepseek" && (value.api !== "chat" || value.format !== "json-object")) result.push("当前DeepSeek预设使用Chat + JSON Object；不能假定严格schema兼容。");
    if (value.thinking && value.kind !== "deepseek") result.push("当前思考开关仅支持DeepSeek Chat预设。");
    if (/[?#]/.test(value.endpoint) || /^https?:\/\/[^/]*@/.test(value.endpoint)) result.push("端点不可保存账号、查询凭据或片段，即使未启用。");
    if (!value.enabled) return result;
    if (!value.model.trim() || value.model.length > 128) result.push("填写明确模型ID；文本ID不证明账号可用。");
    if (value.kind === "codex") { if (!value.executable.trim()) result.push("填写Codex可执行文件路径；不接受附加命令参数。"); }
    else { const issue = endpointError(value); if (issue) result.push(issue); }
    if ((value.kind === "deepseek" || value.kind === "remote-http") && !value.keyEnv) result.push("外部模型启用意向须配置密钥环境变量引用。");
    return result;
}

// 目录只表示当前端点明确返回过这些ID，不证明账号能推理或模型质量。
// 选择项只在用户activated时写入草稿；刷新绝不能替换用户输入的未知ID。
function catalog(entries) {
    if (!Array.isArray(entries)) return [];
    const accepted=[];
    for (const entry of entries.slice(0,256)) {
        if (!entry || entry.available !== true || entry.source !== "provider_catalog"
            || typeof entry.id !== "string" || !entry.id.trim().length || entry.id.length > 128
            || /[\x00-\x1f\x7f]/.test(entry.id)
            || typeof entry.checked_at_ms !== "number" || !Number.isFinite(entry.checked_at_ms)
            || entry.checked_at_ms < 0) continue;
        if (accepted.some(item => item.id === entry.id)) continue;
        const title=typeof entry.title === "string" && entry.title.trim().length
            ? entry.title.slice(0,256).replace(/[\x00-\x1f\x7f]/g," ").trim() : entry.id;
        accepted.push({id:entry.id,title:title,checkedAt:entry.checked_at_ms});
    }
    return accepted;
}
