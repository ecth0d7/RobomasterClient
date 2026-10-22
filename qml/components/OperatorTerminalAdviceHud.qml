import QtQuick
import QtQuick.Window

// Native 2027 advice only. This view cannot request models, publish messages,
// certify sources or dispatch robot commands.
OperatorTerminalAdviceHudForm {
    id: root
    property var runtime: null
    property var voiceRuntime: null
    property bool designPlaceholder: false
    property real hudScale: Window.window?.ui?.layoutScale ?? 1
    readonly property var settings: runtime?.current ?? ({})
    readonly property var advice: runtime?.advice ?? ({})
    readonly property var trace: advice.input_trace ?? ({})
    readonly property var inputTrace: runtime?.inputTrace ?? ({})
    readonly property var voiceDetails: voiceRuntime?.details ?? ({})
    readonly property bool compact: settings.hud_density !== "standard"
    readonly property bool placeholderActive: designPlaceholder && runtime === null
    readonly property bool displayable: runtime?.active === true && settings.hud_enabled !== false
        && advice.fresh === true && positive(advice.remaining_ms) && nonblank(advice.summary)
        && nonblank(trace.snapshot_id) && advice.mock !== true && trace.mock !== true
        && advice.source === "terminal-advice-host"
    signal detailsRequested
    visible: root.placeholderActive || root.displayable
    enabled: root.displayable && !root.placeholderActive
    headerHeight: Math.max(24, 16 / Math.max(0.1, root.hudScale))
    summaryHeight: root.compact ? Math.max(34, 26 / Math.max(0.1, root.hudScale)) : Math.max(42, 30 / Math.max(0.1, root.hudScale))
    reasonHeight: root.compact ? Math.max(20, 12 / Math.max(0.1, root.hudScale)) : Math.max(34, 24 / Math.max(0.1, root.hudScale))
    // Leave a readable baseline gap when the shared HUD canvas is reduced to
    // the smallest desktop window; text keeps the common minimum pixel size.
    metaHeight: Math.max(18, 14 / Math.max(0.1, root.hudScale))
    reasonLines: root.compact ? 1 : 2
    priorityColor: root.placeholderActive ? Theme.muted : root.advice.priority === "urgent" ? Theme.red
        : root.advice.priority === "caution" ? Theme.warning : Theme.green
    priorityText: root.placeholderActive ? "Designer布局参考 · 非实时建议"
        : root.advice.priority === "urgent" ? "紧急建议" : root.advice.priority === "caution" ? "注意建议" : "赛场建议"
    summaryText: root.placeholderActive ? "摘要文字槽 · 非比赛数据" : root.string(root.advice.summary)
    reasonText: root.placeholderActive ? "依据文字槽 · 非模型结果"
        : "依据：" + (root.nonblank(root.advice.rationale) ? root.advice.rationale : "模型未提供关键依据")
    provenanceText: root.placeholderActive ? "来源机器人／提供者／模型文字槽 · 非实时来源" : root.provenance()
    modelText: root.placeholderActive ? "模型／生成宿主文字槽 · 非实时来源"
        : "模型 " + (root.nonblank(root.trace.model) ? root.trace.model : "未提供") + " · "
            + (root.nonblank(root.trace.origin_node) ? root.trace.origin_node : root.string(root.advice.source))
    snapshotText: root.placeholderActive ? "输入范围／快照标识文字槽 · 非实际快照" : root.inputMode() + " · 快照 " + root.string(root.trace.snapshot_id)
    freshnessText: root.placeholderActive ? "接收年龄／输入年龄／剩余寿命文字槽" : "接收 " + root.age(root.advice.received_age_ms)
        + " · 输入 " + root.age(root.inputTrace.snapshot_id === root.trace.snapshot_id ? root.inputTrace.snapshot_age_ms : undefined)
        + " · 剩余 " + root.age(root.advice.remaining_ms)
    voiceText: root.placeholderActive ? "语音路由／队列状态槽 · 非播放确认" : root.voiceState()

    function string(value) { return typeof value === "string" ? value : ""; }
    function nonblank(value) { return typeof value === "string" && value.trim().length > 0; }
    function positive(value) { return typeof value === "number" && Number.isFinite(value) && value > 0; }
    function age(value) {
        if (typeof value !== "number" || !Number.isFinite(value) || value < 0) return "未知";
        return value >= 1000 ? (value / 1000).toFixed(1) + "s" : Math.floor(value) + "ms";
    }
    function inputMode() {
        return trace.input_mode === "team" ? "队伍汇总" : trace.input_mode === "local" ? "本机独立" : "输入范围未提供";
    }
    function provenance() {
        const identity = trace.provider_identity ?? ({});
        const provider = nonblank(identity.package_id) ? identity.package_id + " / " + string(identity.service_name)
            : trace.provider_kind === "codex" ? "Codex" : trace.provider_kind === "http" ? "HTTP" : "提供者未提供";
        return "来源 " + (nonblank(trace.robot_key) ? trace.robot_key : "机器人未提供") + " · " + provider;
    }
    function voiceState() {
        if (settings.voice_enabled !== true) return "语音关闭";
        if (!voiceRuntime) return "语音服务未接通";
        if (voiceDetails.model_voice_enabled !== true) return "语音尚未授权";
        if (voiceDetails.route === "disabled") return "语音路由关闭";
        let state;
        if (voiceDetails.route === "team_designated") state = voiceDetails.team_publish_ready === true ? "队内发布就绪" : "队内发布未就绪";
        else state = voiceDetails.local_route_ready === true ? "本机播报就绪" : "本机播报未就绪";
        const queued = voiceDetails.speech_details?.queued;
        const queue = typeof queued === "number" && Number.isFinite(queued) && queued >= 0 ? String(Math.floor(queued)) : "未知";
        return "语音 " + state + " · 队列 " + queue + " · 非播放确认";
    }
    Connections {
        target: root.detailsControl
        function onClicked() { if (root.enabled && root.displayable) root.detailsRequested(); }
    }
}
