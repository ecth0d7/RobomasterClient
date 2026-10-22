import QtQuick

OperatorTerminalAdviceSetupForm {
    id: root
    property var runtime: null
    property var seasonRuntime: null
    property var teamRuntime: null
    property var draft: ({})
    property var providerDrafts: ({})
    property var candidates: []
    property int candidateIndex: -1
    property string savedConfigurationSnapshot: ""
    property string loadedScope: ""
    property string feedback: ""
    property string question: ""
    readonly property var actual: runtime?.details ?? ({})
    readonly property var reportedProvider: actual.provider_reported ?? actual.provider ?? ({})
    readonly property var result: runtime?.advice ?? ({})
    readonly property var trace: runtime?.inputTrace ?? ({})
    readonly property var strategies: sequence(runtime?.strategyCatalog)
    readonly property var providers: sequence(runtime?.providerCatalog)
    readonly property var strategy: strategies.find(entry => entry.id === draft.strategy_id) ?? ({})
    readonly property bool editable: runtime?.editable === true
    readonly property bool active: runtime?.active === true
    readonly property bool busy: actual.busy === true
    readonly property bool freshResult: result.fresh === true && result.remaining_ms > 0
    readonly property bool dirty: JSON.stringify(draft) !== savedConfigurationSnapshot
    readonly property bool http: draft.provider_kind === "http"
    readonly property bool codex: draft.provider_kind === "codex"
    readonly property bool packageProvider: draft.provider_kind === "package"
    readonly property bool teamMode: draft.input_mode === "team"
    readonly property var options: draft.provider_options ?? ({})
    readonly property int providerIndex: providers.findIndex(entry => providerMatches(entry, draft.provider_kind, options))
    readonly property var catalogProvider: providers[providerIndex] ?? ({})
    readonly property var readyPackageProvider: packageProvider ? providers.find(entry => entry.kind === "package"
        && entry.available !== false && providerKey(entry.kind, entry.default_options ?? entry) === providerKey(draft.provider_kind, options)) ?? ({}) : ({})
    readonly property bool packageReviewRequired: packageProvider && readyPackageProvider.kind === "package"
        && (options.package_fingerprint !== readyPackageProvider.default_options?.package_fingerprint
            || options.configuration_fingerprint !== readyPackageProvider.default_options?.configuration_fingerprint)
    readonly property var selectedFields: draft.selected_fields ?? []
    readonly property var inputIdentities: sequence(trace.input_identities)
    readonly property var inputRecords: sequence(trace.input_records)
    readonly property var robotChoices: robotKeys()
    readonly property string formError: configurationError()

    function sequence(value) {
        return value !== null && typeof value === "object" && Number.isInteger(value.length) ? Array.from(value) : [];
    }
    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function string(value) { return value === undefined || value === null ? "" : String(value); }
    function shown(value) { return value === undefined || value === null || value === "" ? "未提供" : String(value); }
    function fieldToken(value) { return typeof value === "string" && value.length > 0 && value.length <= 96 && /^[A-Za-z0-9_.:/-]+$/.test(value); }
    function providerKey(kind, values) {
        return kind === "package" ? JSON.stringify([kind, values?.package_id ?? "", values?.service_name ?? ""]) : string(kind);
    }
    function providerMatches(entry, kind, values) {
        const candidate = entry.default_options ?? entry;
        return entry.kind === kind && providerKey(entry.kind, candidate) === providerKey(kind, values)
            && (kind !== "package" || (candidate.package_fingerprint === values.package_fingerprint
                && candidate.configuration_fingerprint === values.configuration_fingerprint));
    }
    function scopeKey() { return JSON.stringify([seasonRuntime?.context?.id ?? "", seasonRuntime?.context?.environment ?? "", actual.context ?? {}]); }
    function reload() {
        draft = clone(runtime?.current ?? ({}));
        savedConfigurationSnapshot = JSON.stringify(draft);
        providerDrafts = {};
        if (draft.provider_kind) providerDrafts[providerKey(draft.provider_kind, draft.provider_options)] = clone(draft.provider_options ?? ({}));
        loadedScope = scopeKey();
        candidateIndex = -1;
        feedback = "";
    }
    function synchronize() {
        if (loadedScope !== scopeKey() || (!dirty && JSON.stringify(runtime?.current ?? ({})) !== savedConfigurationSnapshot)) reload();
    }
    function update(key, value) {
        const next = clone(draft);
        next[key] = value;
        draft = next;
        feedback = "";
    }
    function updateOption(key, value) {
        const next = clone(options);
        next[key] = value;
        update("provider_options", next);
    }
    function changeProvider(index) {
        const entry = providers[index];
        if (!entry) return;
        const cached = clone(providerDrafts);
        if (draft.provider_kind) cached[providerKey(draft.provider_kind, options)] = clone(options);
        providerDrafts = cached;
        // Only a native template or the operator's previous draft supplies
        // connection settings. A new empty provider is never called available.
        const template = entry.default_options;
        const key = providerKey(entry.kind, template ?? entry);
        if (!template) { feedback = "宿主尚未提供此模型提供者的配置模板。"; return; }
        const next = clone(draft);
        next.provider_kind = entry.kind;
        next.provider_options = clone(cached[key] ?? template);
        if (entry.kind === "package") {
            // Display only the native catalog's current reviewed identity.
            // Save independently resolves/stamps it again in the native host.
            for (const name of ["package_id", "service_name", "package_fingerprint", "configuration_fingerprint"])
                next.provider_options[name] = template[name];
        }
        draft = next;
        feedback = "";
    }
    function refreshProviders() {
        if (!editable || typeof runtime?.refreshProviders !== "function") return;
        // Metadata refresh never applies a catalog template to the draft.
        // Identity changes remain visible until an explicit selection/save.
        runtime.refreshProviders();
        feedback = dirty ? "已刷新提供者目录，未保存的参数与完整身份保持不变；请核对可用状态和指纹后明确保存。"
                         : runtime.status || "已刷新提供者目录；当前选择保持不变。";
    }
    function robotKeys() {
        const result = [];
        for (const camp of ["red", "blue"])
            for (const role of sequence(seasonRuntime?.current?.roster))
                for (let slot = 1; slot <= role.count; ++slot)
                    result.push(camp + "/" + role.role_id + "/" + slot);
        return result;
    }
    function refreshCandidates() {
        const result = [], seen = {};
        const rows = sequence(teamMode ? teamRuntime?.teamView?.items : seasonRuntime?.terminalBus?.view?.items);
        for (const row of rows) {
            if (row.team_id !== draft.team_id || (!teamMode && row.robot_key !== draft.robot_key)) continue;
            const key = JSON.stringify([row.robot_key, row.source_id, row.item_id]);
            if (seen[key]) continue;
            seen[key] = true;
            result.push({robot_key: row.robot_key, source_id: row.source_id, item_id: row.item_id,
                         source_kind: row.source_kind, mock: row.mock === true, state: row.state});
        }
        if (JSON.stringify(result) === JSON.stringify(candidates)) return;
        const selected = candidates[candidateIndex];
        candidates = result;
        candidateIndex = selected ? result.findIndex(entry => entry.robot_key === selected.robot_key && entry.source_id === selected.source_id && entry.item_id === selected.item_id) : -1;
    }
    function addField(candidate) {
        const next = clone(selectedFields);
        const item = candidate ? {robot_key: candidate.robot_key, source_id: candidate.source_id, item_id: candidate.item_id, uses: []}
                               : {source_id: "", item_id: "", uses: []};
        if (candidate && next.some(entry => (entry.robot_key ?? draft.robot_key) === item.robot_key && entry.source_id === item.source_id && entry.item_id === item.item_id)) {
            feedback = "此机器人来源字段已经在输入允许列表中。";
            return;
        }
        next.push(item);
        update("selected_fields", next);
    }
    function updateField(index, key, value) {
        const next = clone(selectedFields);
        if (key === "robot_key" && !value) delete next[index][key];
        else next[index][key] = value;
        update("selected_fields", next);
    }
    function toggleUse(index, use, selected) {
        const values = (selectedFields[index].uses ?? []).filter(value => value !== use);
        if (selected) values.push(use);
        updateField(index, "uses", values);
    }
    function configurationError() {
        if (!runtime) return "2027建议宿主尚未接入。";
        if (!fieldToken(draft.team_id) || robotChoices.indexOf(draft.robot_key) < 0) return "填写队伍标识并选择当前2027语义机器人。";
        if (!http && !codex && !packageProvider) return "明确选择HTTP、Codex或插件模型提供者。";
        if (packageProvider) {
            if (!/^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$/.test(string(options.package_id)) || string(options.package_id).length > 64
                || !/^[a-z][a-z0-9_.-]{0,79}@[1-9][0-9]{0,3}$/.test(string(options.service_name)))
                return "插件提供者需要明确的包ID和导出服务名；请从原生宿主目录选择。";
            if (!/^[0-9a-f]{64}$/.test(string(options.package_fingerprint)) || !/^[0-9a-f]{64}$/.test(string(options.configuration_fingerprint)))
                return "插件内容与配置身份尚未提供；请重新选择已就绪的插件能力。";
        }
        if (!string(options.model).trim()) return "填写提供者实际支持且账号有权使用的模型ID；此处不伪造可用模型目录。";
        if (http && (!string(options.endpoint).trim() || !/^[A-Za-z_][A-Za-z0-9_]{0,95}$/.test(string(options.key_env)))) return "填写HTTP端点及API密钥环境变量名；不要将密钥写入界面或配置。";
        if (codex && !string(options.executable).trim()) return "填写Codex可执行程序引用；不会从此面板执行任意命令文本。";
        for (const key of ["timeout_ms", "max_output_tokens"])
            if (!/^\d+$/.test(string(options[key]))) return "超时和输出长度需要填写明确整数。";
        if (Number(options.timeout_ms) < 50 || Number(options.timeout_ms) > 120000 || Number(options.max_output_tokens) < 256 || Number(options.max_output_tokens) > 8192)
            return "超时为50–120000ms，输出预算为256–8192 tokens。";
        if (!/^\d+$/.test(string(draft.minimum_interval_ms))) return "填写自动建议最小请求间隔。";
        if (Number(draft.minimum_interval_ms) < 500 || Number(draft.minimum_interval_ms) > 30000) return "最小请求间隔为500–30000ms。";
        if (!["field-above", "right"].includes(draft.hud_position ?? "field-above") || !["compact", "standard"].includes(draft.hud_density ?? "compact"))
            return "选择明确的建议提示位置与密度。";
        if (strategies.findIndex(entry => entry.id === draft.strategy_id) < 0) return "选择宿主提供的明确策略。";
        if (string(draft.strategy_text).length > 1000 || (draft.strategy_id === "custom" && !string(draft.strategy_text).trim())) return "附加策略最多1000字；自定义策略需要填写明确内容。";
        if (selectedFields.length > 32) return "最多选择32个必要模型输入字段。";
        const seen = {};
        for (const field of selectedFields) {
            if (!fieldToken(field.source_id) || !fieldToken(field.item_id)) return "每个输入项须明确填写来源ID与数据项ID，不使用通配符。";
            if (field.robot_key && robotChoices.indexOf(field.robot_key) < 0) return "输入项的机器人必须在当前2027语义阵容中。";
            if (field.robot_key && field.robot_key.split("/")[0] !== string(draft.robot_key).split("/")[0]) return "模型输入项必须属于当前同阵营语义机器人。";
            if (!teamMode && field.robot_key && field.robot_key !== draft.robot_key) return "本机输入模式不能选择队友机器人字段。";
            if (!(field.uses ?? []).length) return "为每个输入项明确授权本机模型或外部模型用途。";
            const key = JSON.stringify([field.robot_key ?? draft.robot_key, field.source_id, field.item_id]);
            if (seen[key]) return "输入列表中存在重复的机器人来源字段。";
            seen[key] = true;
        }
        return "";
    }
    function save() {
        if (!runtime || !editable) return;
        if (formError) { feedback = formError; return; }
        const values = clone(draft);
        values.minimum_interval_ms = Number(values.minimum_interval_ms);
        for (const key of ["timeout_ms", "max_output_tokens"]) values.provider_options[key] = Number(values.provider_options[key]);
        const accepted = runtime.save(values);
        const status = runtime.status;
        if (accepted) reload();
        feedback = status;
    }
    function stamp(value) { return typeof value === "number" && value > 0 ? Qt.formatDateTime(new Date(value), "yyyy-MM-dd hh:mm:ss.zzz") + " / " + value + " ms" : "未知"; }
    function stateName(value) {
        return ({fresh: "新鲜", mock: "模拟 · 不用于建议", time_unverified: "时间未核验", expired: "已过期", offline: "离线", pending: "请求中",
                 withdrawn: "已撤回", retired: "已退役", superseded: "版本已更替", conflict: "字段冲突", quarantined: "已隔离", clock_invalid: "时钟异常"})[value] ?? shown(value);
    }
    function priorityName(value) { return ({info: "一般", caution: "注意", urgent: "紧急"})[value] ?? shown(value); }
    function focusName(value) { return ({health: "生存与血量", heat: "热量", ammo: "弹药", map: "地图", communication: "通信", match: "赛场"})[value] ?? shown(value); }
    onRuntimeChanged: reload()
    onDraftChanged: refreshCandidates()
    onTeamModeChanged: refreshCandidates()
    onSeasonRuntimeChanged: refreshCandidates()
    onTeamRuntimeChanged: refreshCandidates()
    onVisibleChanged: if (visible) synchronize()
    Component.onCompleted: reload()
    Connections { target: root.runtime; function onChanged() { root.synchronize(); } }
    Connections { target: root.seasonRuntime?.terminalBus ?? null; function onChanged() { root.refreshCandidates(); } }
    Connections { target: root.teamRuntime; function onChanged() { root.refreshCandidates(); } }

    function selectionText(values, index, fallback) {
        return index >= 0 && index < values.length ? string(values[index]) : fallback;
    }
    function selectValue(key, values, index, option) {
        if (!editable || !Number.isInteger(index) || index < 0 || index >= values.length) return;
        if (option) updateOption(key, values[index]); else update(key, values[index]);
    }
    function fieldRobotIndex(entry) {
        if (!entry.robot_key) return 0;
        const index = robotChoices.indexOf(entry.robot_key);
        return index < 0 ? -1 : index + 1;
    }
    function removeField(index) {
        if (!editable || index < 0 || index >= selectedFields.length) return;
        const next = clone(selectedFields); next.splice(index, 1); update("selected_fields", next);
    }

    // Native catalogs are normalized from Qt's array-like sequences. Dynamic
    // grants and captured records retain their controls on metadata refreshes.
    editorEditable: editable
    saveEnabled: editable && dirty
    enableEnabled: !!runtime && editable && !active && !dirty && !formError && actual.provider_available === true
    stopEnabled: active
    undoEnabled: editable && dirty
    refreshEnabled: editable && typeof runtime?.refreshProviders === "function"
    lockText: !editable || dirty ? runtime?.lockReason || "存在未保存修改。保存会取消旧请求与旧建议；启用使用已保存的模型、策略和输入授权。" : ""
    statusText: feedback || runtime?.status || "2027建议宿主尚未接通，没有发起模型请求。"
    teamText: string(draft.team_id)
    robotTitles: robotChoices
    robotIndex: robotChoices.indexOf(draft.robot_key)
    robotDisplay: selectionText(robotChoices, robotIndex, "选择2027阵营／角色／槽位")
    robotHint: draft.robot_key || "仅从正式规则阵容选择，不推测官方编号。"
    inputModeIndex: ["local", "team"].indexOf(draft.input_mode)
    inputModeDisplay: selectionText(["本机机器人独立数据", "队伍核验后的完整汇总"], inputModeIndex, "明确选择输入路径")
    inputModeHint: teamMode ? "先汇总与核验，再送模型；不使用零散消息。" : "独立使用本机数据，不等待队伍插件。"
    strategyTitles: strategies.map(entry => entry.label)
    strategyIndex: strategies.findIndex(entry => entry.id === draft.strategy_id)
    strategyDisplay: selectionText(strategyTitles, strategyIndex, "等待宿主提供策略目录")
    strategyDescription: strategy.description ?? strategy.summary ?? strategy.text ?? "策略说明尚未提供。"
    strategyText: string(draft.strategy_text)
    teamWarningVisible: teamMode
    providerTitles: providers.map(entry => entry.label)
    providerSelectedIndex: providerIndex
    providerDisplay: selectionText(providerTitles, providerIndex, packageProvider ? "已保存的插件提供者当前未发现；保留选择" : "等待宿主提供配置模板")
    httpFieldsVisible: http
    codexFieldsVisible: codex
    packageInfoVisible: packageProvider
    providerWarningText: packageProvider && (providerIndex < 0 || catalogProvider.available === false || packageReviewRequired || actual.provider_available === false)
        ? providerIndex < 0 ? "当前插件未启用、依赖未就绪或已移除，保留原包／服务选择；不会改用HTTP或其他模型。请先检查插件管理。"
          : packageReviewRequired ? "同名插件的内容或配置已变化。核对下方预期身份与当前就绪身份，选择当前能力或修改配置后明确保存；保存是本次身份审阅确认，旧身份不会自动迁移。"
          : catalogProvider.available === false ? "保存的插件能力当前未就绪，保留完整身份。请在插件管理中检查启用、依赖与配置；恢复后仍须明确启用建议服务。"
          : "已保存的提供者尚不可用。若已重新选择当前插件，请核对下方身份并保存后再启用。" : ""
    modelText: string(options.model)
    timeoutText: string(options.timeout_ms)
    outputTokensText: string(options.max_output_tokens)
    outputTokensHint: codex ? "256–8192；Codex为长度提示，不是硬上限。" : "256–8192；不用于推断请求费用或模型能力。"
    endpointText: string(options.endpoint)
    keyEnvText: string(options.key_env)
    providerNameText: string(options.provider)
    codexExecutableText: string(options.executable)
    codexAuthText: string(options.auth_home)
    apiIndex: ["chat", "responses"].indexOf(options.api)
    apiDisplay: selectionText(["chat", "responses"], apiIndex, "明确选择HTTP接口协议")
    formatIndex: ["json-object", "json-schema"].indexOf(options.format)
    formatDisplay: selectionText(["json-object", "json-schema"], formatIndex, "明确选择输出格式")
    schemaIndex: ["concise", "basic"].indexOf(options.schema_profile)
    schemaDisplay: selectionText(["concise", "basic"], schemaIndex, "明确选择建议结构")
    thinkingChecked: options.thinking === true
    thinkingEditable: editable && ((options.provider === "deepseek" && options.api === "chat") || options.thinking === true)
    reasoningIndex: ["low", "medium", "high"].indexOf(options.reasoning)
    reasoningDisplay: selectionText(["low", "medium", "high"], reasoningIndex, "明确选择推理强度")
    candidateTitles: candidates.map(entry => (entry.mock ? "MOCK · 不用于建议 " : "") + entry.robot_key + " / " + entry.source_id + " / " + entry.item_id + " / " + stateName(entry.state))
    candidateSelectedIndex: candidateIndex
    candidateDisplay: selectionText(candidateTitles, candidateIndex, "没有匹配队伍／输入路径的已选字段")
    candidateEnabled: editable && candidates.length > 0
    addCandidateEnabled: editable && selectedFields.length < 32 && candidateIndex >= 0 && candidateIndex < candidates.length && candidates[candidateIndex]?.mock !== true
    addFieldEnabled: editable && selectedFields.length < 32
    selectedFieldCount: selectedFields.length
    inputRecordCount: inputRecords.length
    hudChecked: draft.hud_enabled !== false
    hudPositionIndex: ["field-above", "right"].indexOf(draft.hud_position)
    hudPositionDisplay: selectionText(["现有赛场信息区上方", "右侧固定区域"], hudPositionIndex, "明确选择提示位置")
    hudDensityIndex: ["compact", "standard"].indexOf(draft.hud_density)
    hudDensityDisplay: selectionText(["紧凑", "标准"], hudDensityIndex, "明确选择信息密度")
    autoChecked: draft.auto_advice === true
    voiceChecked: draft.voice_enabled === true
    triggerIndex: ["event", "interval"].indexOf(draft.trigger)
    triggerDisplay: selectionText(["新鲜输入发生变化", "按间隔取得新鲜快照"], triggerIndex, "明确选择触发方式")
    minimumIntervalText: string(draft.minimum_interval_ms)
    errorText: formError
    questionText: question
    questionEditable: active
    requestText: busy ? "正在请求新鲜建议" : "按已保存配置请求建议"
    requestEnabled: active && !dirty && !busy
    cancelEnabled: busy
    requestStatus: runtime?.status || "没有运行中的模型提供者。"
    emptyAdviceText: busy ? "模型正在处理当前授权快照。加载期间不显示建议卡片；输入先失效时会取消或丢弃结果。"
        : "当前没有新鲜有效的建议。未连接、无输入、已过期、已取消或失败的请求不会在HUD留下空白卡片或伪装成实时指引。"
    freshAdvice: freshResult
    adviceHeading: "有效建议  /  " + priorityName(result.priority) + "  /  " + focusName(result.focus)
    adviceSummary: string(result.summary)
    adviceSummaryColor: result.priority === "urgent" ? Theme.red : result.priority === "caution" ? warningColor : textColor
    adviceRationale: "关键依据：" + (result.rationale || "提供者没有返回额外依据；不补写推测。")
    adviceFreshness: "接收 " + stamp(result.received_at_ms) + " / 建议年龄 " + shown(result.received_age_ms) + " ms / 当前剩余寿命 " + shown(result.remaining_ms) + " ms"
    adviceSource: "来源 " + shown(result.source) + " / 输入路径 " + shown(result.input_mode) + " / 请求 " + shown(result.request_id) + " / 原快照 " + shown(result.snapshot_id)
    providerStatusRows: [
        {label: "提供者／请求", value: (active ? "已启用" : "未启用") + " / " + (busy ? "请求处理中" : "无进行中请求")},
        {label: "已保存提供者可用", value: actual.provider_available === true ? "宿主能力就绪；不代表模型或账号已经连通" : actual.provider_available === false ? "提供者未就绪或内容／配置已变化；不自动回退" : "宿主尚未报告", detail: true},
        {label: "已保存模型／策略", value: shown(actual.model) + " / " + shown(actual.strategy_id), detail: true},
        {label: "完整输入接纳", value: actual.input_ready === true ? "此刻具备新鲜授权输入；发送时仍重新核验" : actual.input_block_reason || "尚未满足新鲜度、来源与用途要求", detail: true},
        {label: "提供者自报推理位置／本地声明", value: shown(reportedProvider.inference_location) + " / " + (reportedProvider.fully_local_verified === true ? "自报完全本地；不是宿主认证" : "未声明完全本地"), detail: true},
        {label: "宿主本地推理认证", value: "未认证；当前按externalAi用途授权接纳，不采用插件自报作为证明", detail: true},
        {label: "实际提供者状态", value: shown(actual.provider?.status ?? actual.provider?.api), detail: true},
        {label: "实际插件能力身份", value: actual.provider_identity?.package_id ? actual.provider_identity.package_id + " / " + shown(actual.provider_identity.service_name) : "未启用插件能力", detail: true},
        {label: "配置／版本", value: (actual.configuration_valid === true ? "宿主配置有效" : "配置未确认或无效") + " / " + shown(actual.configuration_revision)},
        {label: "比赛适配／自动动作", value: "比赛模型适配尚未核验；建议不生成机器人动作", detail: true}
    ]
    packageIdentityRows: [
        {label: "包ID／导出服务", value: shown(options.package_id) + " / " + shown(options.service_name), detail: true},
        {label: "预期包内容指纹", value: shown(options.package_fingerprint), detail: true},
        {label: "预期配置指纹", value: shown(options.configuration_fingerprint), detail: true},
        {label: "当前就绪包内容指纹", value: readyPackageProvider.default_options?.package_fingerprint || "未发现同一包／服务的就绪能力", detail: true},
        {label: "当前就绪配置指纹", value: readyPackageProvider.default_options?.configuration_fingerprint || "未发现同一包／服务的就绪能力", detail: true},
        {label: "身份确认边界", value: "来自原生目录，只读显示；保存时由宿主重新解析并确认，不接受界面自报身份。", detail: true}
    ]
    traceRows: [
        {label: "请求／输入快照", value: shown(trace.request_id) + " / " + shown(trace.snapshot_id), detail: true},
        {label: "模型／策略／配置版本", value: shown(trace.provider_kind) + " / " + shown(trace.model) + " / " + shown(trace.strategy_id) + " / " + shown(trace.configuration_revision), detail: true},
        {label: "实际输入路径／队伍／机器人", value: shown(trace.input_mode) + " / " + shown(trace.team_id) + " / " + shown(trace.robot_key), detail: true},
        {label: "采集时间", value: stamp(trace.captured_at_ms), detail: true},
        {label: "快照年龄／整体剩余寿命", value: shown(trace.snapshot_age_ms) + " / " + shown(trace.remaining_ms) + " ms"},
        {label: "输入版本是否仍有效", value: trace.input_revision_current === true ? "宿主重新核验一致且仍在寿命内" : "未采集或已变化／失效；不作为当前有效依据", detail: true},
        {label: "规则／场地／能力版本", value: shown(trace.context?.profile_id) + " / " + shown(trace.context?.field_profile_id) + " / " + shown(trace.context?.capability_revision), detail: true},
        {label: "输入证据引用", value: shown(trace.evidence_hash), detail: true},
        {label: "冻结来源记录／身份记录", value: inputRecords.length + " / " + inputIdentities.length}
    ]

    selectedFieldDelegate: Component {
        OperatorAdviceSetupInputForm {
            id: fieldRow
            required property int index
            readonly property var entry: root.selectedFields[index] ?? ({})
            objectName: "adviceInputField_" + index
            width: root.selectedFieldDelegateWidth
            sourceText: root.string(entry.source_id)
            itemText: root.string(entry.item_id)
            robotTitles: ["使用本机语义机器人"].concat(root.robotChoices)
            robotIndex: root.fieldRobotIndex(entry)
            robotDisplay: root.selectionText(robotTitles, robotIndex, "已保存来源机器人不在当前阵容")
            robotHint: entry.robot_key || root.draft.robot_key || "尚未选择本机身份。"
            editable: root.editable
            localUse: (entry.uses ?? []).indexOf("localAi") >= 0
            externalUse: (entry.uses ?? []).indexOf("externalAi") >= 0
            formColumns: root.formColumns
            fieldSpacing: root.fieldSpacing
            actionSpacing: root.actionSpacing
            columnGap: root.columnGap
            controlHeight: root.controlHeight
            noteSize: root.noteSize
            inputSize: root.inputSize
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            mutedColor: root.mutedColor
            warningColor: root.warningColor
            separatorColor: root.separatorColor
            fontFamily: root.fontFamily
            Connections { target: fieldRow.sourceControl; function onTextEdited() { root.updateField(fieldRow.index, "source_id", fieldRow.sourceControl.text); } }
            Connections { target: fieldRow.itemControl; function onTextEdited() { root.updateField(fieldRow.index, "item_id", fieldRow.itemControl.text); } }
            Connections {
                target: fieldRow.robotControl
                function onActivated(index) {
                    if (!root.editable || index < 0 || index > root.robotChoices.length) return;
                    root.updateField(fieldRow.index, "robot_key", index ? root.robotChoices[index - 1] : "");
                }
            }
            Connections { target: fieldRow.localUseControl; function onToggled() { root.toggleUse(fieldRow.index, "localAi", fieldRow.localUseControl.checked); } }
            Connections { target: fieldRow.externalUseControl; function onToggled() { root.toggleUse(fieldRow.index, "externalAi", fieldRow.externalUseControl.checked); } }
            Connections { target: fieldRow.removeControl; function onClicked() { root.removeField(fieldRow.index); } }
        }
    }
    inputRecordDelegate: Component {
        OperatorAdviceSetupRecordForm {
            required property int index
            readonly property var record: root.inputRecords[index] ?? ({})
            objectName: "adviceInputRecord_" + index
            width: root.inputRecordDelegateWidth
            heading: "实际输入来源  /  " + root.shown(record.robot_key) + "  /  " + root.shown(record.item_id)
            sourceText: "来源 " + root.shown(record.source_id) + " / 传感器 " + root.shown(record.sensor_id) + " / 类型 " + root.shown(record.source_kind) + " / 验证 " + root.shown(record.validation)
            timeText: "产生 " + root.stamp(record.produced_at_ms) + "\n宿主记录接收 " + root.stamp(record.received_at_ms)
            clockText: "时钟域 " + root.shown(record.clock_domain) + " / 时间依据 " + root.shown(record.time_basis) + " / 置信度 " + (typeof record.confidence === "number" ? record.confidence.toFixed(3) : "未知")
            lifetimeText: "TTL " + root.shown(record.ttl_ms) + " ms / 采集时接收年龄 " + root.shown(record.received_age_ms_at_capture) + " ms / 采集时剩余寿命 " + root.shown(record.remaining_ms_at_capture) + " ms"
            identityText: "来源会话 " + root.shown(record.session_id) + " / 序号 " + root.shown(record.sequence) + " / 观测引用 " + root.shown(record.observation_hash)
            teamText: record.source_node || record.source_proof_ref ? "队伍源节点 " + root.shown(record.source_node) + " / 原始签名证明引用 " + root.shown(record.source_proof_ref) : ""
            fieldSpacing: root.fieldSpacing
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            titleSize: root.sectionTitleSize
            noteSize: root.noteSize
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            mutedColor: root.mutedColor
            warningColor: root.warningColor
            separatorColor: root.separatorColor
            fontFamily: root.fontFamily
        }
    }

    Connections { target: root.saveControl; function onClicked() { root.save(); } }
    Connections { target: root.enableControl; function onClicked() { if (root.enableEnabled) root.runtime.setEnabled(true); } }
    Connections { target: root.stopControl; function onClicked() { if (root.active) root.runtime.stop(); } }
    Connections { target: root.undoControl; function onClicked() { if (root.editable) root.reload(); } }
    Connections { target: root.teamControl; function onTextEdited() { root.update("team_id", root.teamControl.text); } }
    Connections { target: root.robotControl; function onActivated(index) { root.selectValue("robot_key", root.robotChoices, index, false); } }
    Connections { target: root.inputModeControl; function onActivated(index) { root.selectValue("input_mode", ["local", "team"], index, false); } }
    Connections { target: root.strategyControl; function onActivated(index) { if (root.editable && index >= 0 && index < root.strategies.length) root.update("strategy_id", root.strategies[index].id); } }
    Connections { target: root.strategyTextControl; function onTextChanged() { if (root.editable && root.strategyTextControl.text !== root.string(root.draft.strategy_text)) root.update("strategy_text", root.strategyTextControl.text); } }
    Connections { target: root.providerControl; function onActivated(index) { if (root.editable) root.changeProvider(index); } }
    Connections { target: root.refreshProvidersControl; function onClicked() { root.refreshProviders(); } }
    Connections { target: root.modelControl; function onTextEdited() { root.updateOption("model", root.modelControl.text); } }
    Connections { target: root.timeoutControl; function onTextEdited() { root.updateOption("timeout_ms", root.timeoutControl.text); } }
    Connections { target: root.outputTokensControl; function onTextEdited() { root.updateOption("max_output_tokens", root.outputTokensControl.text); } }
    Connections { target: root.endpointControl; function onTextEdited() { root.updateOption("endpoint", root.endpointControl.text); } }
    Connections { target: root.keyEnvControl; function onTextEdited() { root.updateOption("key_env", root.keyEnvControl.text); } }
    Connections { target: root.providerNameControl; function onTextEdited() { root.updateOption("provider", root.providerNameControl.text); } }
    Connections { target: root.codexExecutableControl; function onTextEdited() { root.updateOption("executable", root.codexExecutableControl.text); } }
    Connections { target: root.codexAuthControl; function onTextEdited() { root.updateOption("auth_home", root.codexAuthControl.text); } }
    Connections { target: root.httpApiControl; function onActivated(index) { root.selectValue("api", ["chat", "responses"], index, true); } }
    Connections { target: root.httpFormatControl; function onActivated(index) { root.selectValue("format", ["json-object", "json-schema"], index, true); } }
    Connections { target: root.httpSchemaControl; function onActivated(index) { root.selectValue("schema_profile", ["concise", "basic"], index, true); } }
    Connections { target: root.thinkingControl; function onToggled() { if (root.thinkingEditable) root.updateOption("thinking", root.thinkingControl.checked); } }
    Connections { target: root.reasoningControl; function onActivated(index) { root.selectValue("reasoning", ["low", "medium", "high"], index, true); } }
    Connections { target: root.candidateControl; function onActivated(index) { if (root.candidateEnabled && index >= 0 && index < root.candidates.length) root.candidateIndex = index; } }
    Connections { target: root.addCandidateControl; function onClicked() { if (root.addCandidateEnabled) root.addField(root.candidates[root.candidateIndex]); } }
    Connections { target: root.addFieldControl; function onClicked() { if (root.addFieldEnabled) root.addField(null); } }
    Connections { target: root.hudControl; function onToggled() { if (root.editable) root.update("hud_enabled", root.hudControl.checked); } }
    Connections { target: root.hudPositionControl; function onActivated(index) { root.selectValue("hud_position", ["field-above", "right"], index, false); } }
    Connections { target: root.hudDensityControl; function onActivated(index) { root.selectValue("hud_density", ["compact", "standard"], index, false); } }
    Connections { target: root.autoControl; function onToggled() { if (root.editable) root.update("auto_advice", root.autoControl.checked); } }
    Connections { target: root.voiceControl; function onToggled() { if (root.editable) root.update("voice_enabled", root.voiceControl.checked); } }
    Connections { target: root.triggerControl; function onActivated(index) { root.selectValue("trigger", ["event", "interval"], index, false); } }
    Connections { target: root.minimumIntervalControl; function onTextEdited() { root.update("minimum_interval_ms", root.minimumIntervalControl.text); } }
    Connections { target: root.questionControl; function onTextEdited() { if (root.active) root.question = root.questionControl.text; } }
    Connections { target: root.requestControl; function onClicked() { if (root.requestEnabled) root.runtime.request(root.question); } }
    Connections { target: root.cancelControl; function onClicked() { if (root.busy) root.runtime.cancel(); } }
}
