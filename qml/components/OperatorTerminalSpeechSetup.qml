import QtQuick

// Engine selection is separate from semantic identity and listener policy.
// This view cannot submit arbitrary text. Explicit enable and fixed sample
// actions both pass through the native host's preparation/ownership guards.
OperatorTerminalSpeechSetupForm {
    id: root
    property var runtime: null
    property var draft: ({})
    property var providerDrafts: ({})
    property string savedConfigurationSnapshot: ""
    property string loadedScope: ""
    property string feedback: ""
    readonly property var actual: runtime?.details ?? ({})
    readonly property var speech: actual.speech ?? ({})
    readonly property var providers: Array.from(runtime?.providerCatalog ?? [])
    readonly property var options: draft.provider_options ?? ({})
    readonly property bool editable: runtime?.editable === true
    readonly property bool active: runtime?.active === true
    readonly property bool dirty: JSON.stringify(draft) !== savedConfigurationSnapshot
    readonly property bool espeak: draft.provider_kind === "espeak"
    readonly property bool http: draft.provider_kind === "http"
    readonly property bool packageProvider: draft.provider_kind === "package"
    readonly property int providerIndex: providers.findIndex(entry => matches(entry, draft.provider_kind, options))
    readonly property var selectedProvider: providers[providerIndex] ?? ({})
    readonly property bool selectionAvailable: actual.provider_available === true || actual.selection_available === true
    readonly property string formError: configurationError()

    providerTitles: root.providers.map(entry => entry.label)
    selectedProviderIndex: root.providerIndex
    providerDisplayText: root.providerIndex >= 0 ? root.string(root.selectedProvider.label) : root.providerEmptyText
    providerEditable: root.editable && root.providers.length > 0
    configurationEditable: root.editable && (root.espeak || root.http)
    canRefresh: root.editable && typeof root.runtime?.refreshProviders === "function"
    canSave: root.editable && (root.dirty || root.actual.configuration_saved !== true)
    canEnable: root.editable && root.actual.configuration_saved === true && !root.dirty && !root.active && root.selectionAvailable
    canStop: root.active || root.actual.owner_current === true
    canUndo: root.editable && root.dirty
    canTestOutput: root.editable && root.active && root.actual.owner_current === true && typeof root.runtime?.testOutput === "function"
    showEspeak: root.espeak
    showHttp: root.http
    showPackage: root.packageProvider
    executableValue: root.string(root.options.executable)
    voiceValue: root.string(root.options.voice)
    speedValue: root.string(root.options.speed)
    endpointValue: root.string(root.options.endpoint)
    modelValue: root.string(root.options.model)
    timeoutValue: root.string(root.options.timeout_ms)
    playerValue: root.string(root.options.player)
    playbackValue: root.options.playback === true
    testOutputText: root.speech.playback === true ? "语音试音" : "示例文本合成"
    lockMessage: root.editable ? "" : root.runtime?.lockReason || "语音配置宿主不可用或正在切换，请稍后重试。"
    reviewMessage: !!root.runtime && root.actual.configuration_saved !== true
        ? "当前只有初始模板，尚未在本规则／用途范围明确保存。请核对后保存配置，再启用引擎；默认值不作为启用许可。" : ""
    statusText: root.feedback || root.runtime?.status || "原生语音引擎未接入；没有创建音频或播放进程。"
    statusEmphasized: root.feedback.length > 0
    providerWarningText: root.providerIndex < 0 || root.selectedProvider.available === false
        ? root.packageProvider ? "缺失或变化的插件保留完整身份，不自动切换引擎。先在插件管理中检查安装、启用、依赖和配置，再明确选择当前能力并保存。"
          : "所选引擎模块尚未就绪。请检查实际安装的语音模块与依赖，然后刷新目录；不会自动切换到另一种引擎。" : ""
    validationMessage: root.formError
    statusRows: [
        {label: "引擎／所有权", value: (root.active ? "已启用" : "未启用") + " / " + (root.actual.owner_current === true ? "本宿主持有当前服务" : "本宿主未持有当前服务"), detail: true},
        {label: "已保存选择可用", value: root.selectionAvailable ? "原生提供者已就绪；不代表已经合成或播放" : "未就绪或内容／配置已变化；不自动回退", detail: true},
        {label: "实际插件能力", value: root.actual.provider_identity?.package_id ? root.actual.provider_identity.package_id + " / " + root.shown(root.actual.provider_identity.service_name) : root.shown(root.actual.provider_identity?.plugin_id), detail: true},
        {label: "提供者报告的引擎／音色", value: root.shown(root.speech.engine) + " / " + root.shown(root.speech.voice), detail: true},
        {label: "忙碌／队列／丢弃", value: (root.speech.busy === true ? "处理中" : root.speech.busy === false ? "空闲" : "未报告") + " / " + root.shown(root.speech.queued) + " / " + root.shown(root.speech.dropped)},
        {label: "输出能力", value: root.speech.playback === true ? "提供者报告启用播放；当前未据此确认实际出声" : root.speech.playback === false ? "仅合成，不播放" : "尚未报告", detail: true},
        {label: "配置状态", value: root.actual.configuration_valid === true ? "宿主配置有效" : "未确认或无效"},
        {label: "当前范围保存状态", value: root.actual.configuration_saved === true ? "已明确保存" : "初始模板／尚未保存；不能启用"},
        {label: "配置范围", value: root.shown(root.actual.context?.profile_id) + " / " + root.shown(root.actual.environment), detail: true},
        {label: "选择配置文件", value: root.shown(root.actual.settings_file), detail: true}
    ]
    identityRows: [
        {label: "包ID／导出服务", value: root.shown(root.options.package_id) + " / " + root.shown(root.options.service_name), detail: true},
        {label: "包内容指纹", value: root.shown(root.options.package_fingerprint), detail: true},
        {label: "配置指纹", value: root.shown(root.options.configuration_fingerprint), detail: true}
    ]

    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function string(value) { return value === undefined || value === null ? "" : String(value); }
    function shown(value) { return value === undefined || value === null || value === "" ? "未提供" : String(value); }
    function scopeKey() { return JSON.stringify([actual.context ?? {}, actual.environment ?? ""]); }
    function key(kind, values) {
        return kind === "package" ? JSON.stringify([kind, values?.package_id ?? "", values?.service_name ?? ""]) : string(kind);
    }
    function matches(entry, kind, values) {
        const candidate = entry.default_options ?? entry;
        return entry.provider_kind === kind && key(entry.provider_kind, candidate) === key(kind, values)
            && (kind !== "package" || candidate.package_fingerprint === values.package_fingerprint
                && candidate.configuration_fingerprint === values.configuration_fingerprint);
    }
    function reload() {
        draft = clone(runtime?.current ?? ({}));
        savedConfigurationSnapshot = JSON.stringify(draft);
        const cached = {};
        if (draft.provider_kind) cached[key(draft.provider_kind, draft.provider_options)] = clone(draft.provider_options ?? ({}));
        providerDrafts = cached;
        loadedScope = scopeKey();
        feedback = "";
    }
    function synchronize() {
        if (loadedScope !== scopeKey() || (!dirty && JSON.stringify(runtime?.current ?? ({})) !== savedConfigurationSnapshot)) reload();
    }
    function updateOption(name, value) {
        const next = clone(draft), values = clone(options);
        values[name] = value;
        next.provider_options = values;
        draft = next;
        feedback = "";
    }
    function selectProvider(index) {
        const entry = providers[index];
        if (!editable || !entry?.default_options) return;
        const cached = clone(providerDrafts);
        if (draft.provider_kind) cached[key(draft.provider_kind, options)] = clone(options);
        providerDrafts = cached;
        const values = clone(cached[key(entry.provider_kind, entry.default_options)] ?? entry.default_options);
        if (entry.provider_kind === "package") {
            // IDs/hashes come from this exact catalog row, never a stale cache.
            // Native save independently resolves the reviewed provider again.
            for (const name of ["package_id", "service_name", "package_fingerprint", "configuration_fingerprint"])
                values[name] = entry.default_options[name];
        }
        draft = {provider_kind: entry.provider_kind, provider_options: values};
        feedback = "";
    }
    function refreshProviders() {
        if (!editable || typeof runtime?.refreshProviders !== "function") return;
        runtime.refreshProviders();
        feedback = "已刷新原生提供者目录；当前完整选择与未保存参数保持不变，没有启动语音。";
    }
    function configurationError() {
        if (!runtime) return "语音引擎宿主尚未接通。";
        if (!espeak && !http && !packageProvider) return "选择明确的eSpeak、本机Piper HTTP或插件提供者。";
        if (packageProvider) {
            if (!/^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$/.test(string(options.package_id)) || string(options.package_id).length > 64
                || !/^[a-z][a-z0-9_.-]{0,79}@[1-9][0-9]{0,3}$/.test(string(options.service_name)))
                return "从原生目录选择明确的包ID与导出服务。";
            if (!/^[0-9a-f]{64}$/.test(string(options.package_fingerprint)) || !/^[0-9a-f]{64}$/.test(string(options.configuration_fingerprint)))
                return "插件内容或配置身份未提供，请选择已审阅的原生能力。";
            return "";
        }
        if (!/^\d+$/.test(string(options.timeout_ms)) || Number(options.timeout_ms) < 50 || Number(options.timeout_ms) > 60000)
            return "合成与播放超时为50–60000ms整数。";
        if (typeof options.playback !== "boolean") return "明确选择是否播放合成后的音频。";
        if (string(options.player).length > 1024 || string(options.executable).length > 1024) return "程序引用最多1024字符，不填写shell命令。";
        if (espeak && (!/^[A-Za-z0-9_+.-]{1,48}$/.test(string(options.voice))
            || !/^\d+$/.test(string(options.speed)) || Number(options.speed) < 80 || Number(options.speed) > 350))
            return "eSpeak音色需符合提供者格式，语速为80–350整数。";
        if (http && (string(options.endpoint).length > 2048 || string(options.model).length > 128))
            return "HTTP端点最多2048字符，明确音色标识最多128字符。";
        return "";
    }
    function save() {
        if (!editable || !runtime) return;
        if (formError) { feedback = formError; return; }
        const values = clone(draft);
        if (espeak || http) values.provider_options.timeout_ms = Number(values.provider_options.timeout_ms);
        if (espeak) values.provider_options.speed = Number(values.provider_options.speed);
        const accepted = runtime.save(values), status = runtime.status;
        if (accepted) reload();
        feedback = status;
    }
    function testOutput() {
        if (!editable || !active || actual.owner_current !== true || typeof runtime?.testOutput !== "function") return;
        runtime.testOutput();
        feedback = (runtime.status || "宿主未报告示例提交结果。") + " 仅在宿主明确接纳时进入队列；接纳不证明已经完成合成或播放。";
    }
    onRuntimeChanged: reload()
    onVisibleChanged: if (visible) synchronize()
    Component.onCompleted: reload()
    Connections { target: root.runtime; function onChanged() { root.synchronize(); } }

    Connections { target: root.providerControl; function onActivated(index) { root.selectProvider(index); } }
    Connections { target: root.refreshControl; function onClicked() { if (root.canRefresh) root.refreshProviders(); } }
    Connections { target: root.saveControl; function onClicked() { if (root.canSave) root.save(); } }
    Connections { target: root.enableControl; function onClicked() { if (root.canEnable && root.runtime) root.runtime.setEnabled(true); } }
    Connections { target: root.stopControl; function onClicked() { if (root.canStop && root.runtime) root.runtime.stop(); } }
    Connections { target: root.undoControl; function onClicked() { if (root.canUndo) root.reload(); } }
    Connections { target: root.testOutputControl; function onClicked() { if (root.canTestOutput) root.testOutput(); } }
    Connections { target: root.executableControl; function onTextEdited() { if (root.configurationEditable && root.espeak) root.updateOption("executable", root.executableControl.text); } }
    Connections { target: root.voiceControl; function onTextEdited() { if (root.configurationEditable && root.espeak) root.updateOption("voice", root.voiceControl.text); } }
    Connections { target: root.speedControl; function onTextEdited() { if (root.configurationEditable && root.espeak) root.updateOption("speed", root.speedControl.text); } }
    Connections { target: root.endpointControl; function onTextEdited() { if (root.configurationEditable && root.http) root.updateOption("endpoint", root.endpointControl.text); } }
    Connections { target: root.modelControl; function onTextEdited() { if (root.configurationEditable && root.http) root.updateOption("model", root.modelControl.text); } }
    Connections { target: root.timeoutControl; function onTextEdited() { if (root.configurationEditable) root.updateOption("timeout_ms", root.timeoutControl.text); } }
    Connections { target: root.playerControl; function onTextEdited() { if (root.configurationEditable) root.updateOption("player", root.playerControl.text); } }
    Connections { target: root.playbackControl; function onToggled() { if (root.configurationEditable) root.updateOption("playback", root.playbackControl.checked); } }
}
