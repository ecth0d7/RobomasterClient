import QtQuick

// The editable Form owns appearance. This wrapper only edits a draft and calls
// the native owner-aware host; opening/refreshing the page never starts a link.
OperatorTerminalBridgeSetupForm {
    id: root
    property var runtime: null
    property var draft: ({})
    property var providerDrafts: ({})
    property string savedConfigurationSnapshot: ""
    property string loadedScope: ""
    property string feedback: ""
    readonly property var actual: runtime?.details ?? ({})
    readonly property var bridge: actual.bridge ?? ({})
    readonly property var providers: runtime?.providerCatalog ?? []
    readonly property var options: draft.provider_options ?? ({})
    readonly property bool editable: runtime?.editable === true
    readonly property bool active: runtime?.active === true
    readonly property bool dirty: JSON.stringify(draft) !== savedConfigurationSnapshot
    readonly property bool packageProvider: draft.provider_kind === "package"
    readonly property int selectedProviderIndex: providers.findIndex(entry => matches(entry, draft.provider_kind, options))
    readonly property bool selectionAvailable: actual.provider_available === true
    readonly property string formError: configurationError()

    configurationEditable: root.editable
    providerEditable: root.editable && root.providers.length > 0
    providerTitles: root.providers.map(entry => entry.label)
    providerIndex: root.selectedProviderIndex
    providerEmptyText: "当前准确提供者未发现；保留原选择，不自动改用首项"
    bindValue: root.string(root.draft.bind)
    listenPortValue: root.string(root.draft.listen_port)
    peerValue: root.string(root.draft.peer)
    tokenEnvValue: root.string(root.draft.token_env)
    listenValue: root.draft.listen === true
    snapshotsValue: root.draft.export_snapshots === true
    eventsValue: root.draft.export_events === true
    canRefresh: root.editable && typeof root.runtime?.refreshProviders === "function"
    canSave: root.editable && (root.dirty || root.actual.configuration_saved !== true)
    canEnable: root.editable && root.actual.configuration_saved === true && root.actual.configuration_valid === true
        && !root.dirty && !root.active && root.selectionAvailable
    canStop: root.active || root.actual.owner_current === true
    canUndo: root.editable && root.dirty
    statusText: root.feedback || root.runtime?.status || "原生实验室桥接宿主未接通；没有创建监听器、对端或实验数据。"
    reviewMessage: !root.runtime ? "当前仅绘制界面，没有可保存／启用的原生宿主。"
        : root.actual.configuration_saved !== true ? "当前范围只有初始模板，须明确保存后才可启用；保存、刷新和重启不会建立连接。"
        : root.dirty ? "存在未保存修改。保存会停止本宿主的旧桥接；启用只使用已保存配置。"
        : !root.selectionAvailable ? "已保存提供者缺失或内容／配置已变化，保留准确身份；请审核刷新后的来源再选择保存，不自动回退。" : ""
    validationMessage: root.formError
    lockMessage: root.editable ? "" : root.runtime?.lockReason || "实验室桥接宿主未接通，配置不可编辑。"
    identityRows: [
        {label: "配置／当前范围保存", value: root.actual.configuration_valid === true ? "有效 / " + (root.actual.configuration_saved === true ? "已明确保存" : "初始模板，尚未保存") : "尚未确认有效 / " + (root.actual.configuration_saved === true ? "已保存" : "未保存"), detail: true},
        {label: "活动／服务所有权", value: (root.active ? "已启用" : "未启用") + " / " + root.booleanText(root.actual.owner_current, "本宿主持有", "本宿主未持有"), detail: true},
        {label: "已保存提供者可用", value: root.selectionAvailable ? "原生能力就绪；不代表已连接或已认证" : "未就绪或身份变化，不自动回退", detail: true},
        {label: "当前原生提供者", value: root.identityText(root.actual.provider_identity), detail: true},
        {label: "编辑中的包／服务", value: root.packageProvider ? root.shown(root.options.package_id) + " / " + root.shown(root.options.service_name) : root.draft.provider_kind === "tcp" ? "内置实验室TCP" : "未选择", detail: true},
        {label: "预期包内容／配置指纹", value: root.packageProvider ? root.shown(root.options.package_fingerprint) + " / " + root.shown(root.options.configuration_fingerprint) : "内置项不适用", detail: true},
        {label: "规则／用途", value: root.shown(root.actual.context?.profile_id) + " / " + root.shown(root.actual.environment), detail: true},
        {label: "配置文件", value: root.shown(root.actual.settings_file), detail: true}
    ]
    bridgeRows: [
        {label: "当前原生传输实现", value: root.transportText(), detail: true},
        {label: "提供者报告活动", value: root.booleanText(root.bridge.active, "活动；不作为身份核验", "未活动"), detail: true},
        {label: "引擎报告连接", value: root.booleanText(root.bridge.connected, "报告连接；不作为对端认证", "报告未连接"), detail: true},
        {label: "实际监听端口", value: root.shown(root.bridge.listen_port)},
        {label: "传输连接数", value: root.shown(root.bridge.connections)},
        {label: "丢弃／待读回调", value: root.shown(root.bridge.dropped) + " / " + root.shown(root.bridge.pending_reads)},
        {label: "待处理输入／输出字节", value: root.shown(root.bridge.pending_input_bytes) + " / " + root.shown(root.bridge.pending_output_bytes)},
        {label: "接收／拒绝帧", value: root.shown(root.bridge.received_frames) + " / " + root.shown(root.bridge.rejected_frames)},
        {label: "快照来源／序号来源", value: root.shown(root.bridge.peer_count) + " / " + root.shown(root.bridge.source_sequence_count)},
        {label: "到达新近／过期来源", value: root.shown(root.bridge.arrival_fresh_peers) + " / " + root.shown(root.bridge.arrival_stale_peers)},
        {label: "最后本机接收UTC", value: root.arrivalTime(root.bridge.last_received_at_ms), detail: true},
        {label: "距最后有效帧 / ms", value: root.shown(root.bridge.last_received_age_ms)},
        {label: "当前实际导出快照／事件", value: root.booleanText(root.bridge.export_snapshots, "允许", "关闭") + " / " + root.booleanText(root.bridge.export_events, "允许", "关闭")},
        {label: "来源新近程度", value: root.bridge.freshness_basis === "local_arrival_only" ? "仅按本机到达年龄；不代表远端测量新鲜或有效" : "未报告", detail: true},
        {label: "来源时间／身份核验", value: root.booleanText(root.bridge.source_time_verified, "时间已核验", "时间未核验") + " / " + root.booleanText(root.bridge.peer_authenticated, "身份已核验", "来源未认证"), detail: true},
        {label: "schema3／官方／模型资格", value: "实验室schema1未认证来源；不构成可信队伍、官方输入或AI授权", detail: true}
    ]

    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function string(value) { return value === undefined || value === null ? "" : String(value); }
    function shown(value) { return value === undefined || value === null || value === "" ? "未报告" : String(value); }
    function booleanText(value, yes, no) { return value === true ? yes : value === false ? no : "未报告"; }
    function identityText(value) {
        return value?.package_id ? value.package_id + " / " + shown(value.service_name) : shown(value?.plugin_id);
    }
    function transportText() {
        if (actual.provider_identity?.plugin_id === "bridge.tcp") return "内置明文TCP；是否活动、监听与连接分别报告";
        return actual.provider_identity?.package_id ? "原生包实现；宿主未认证其传输或加密声明" : "尚无当前原生提供者";
    }
    function arrivalTime(value) {
        return typeof value === "number" && value > 0 ? Qt.formatDateTime(new Date(value), "yyyy-MM-dd hh:mm:ss.zzz") + " / " + value + " ms" : "尚未报告有效帧到达";
    }
    function scopeKey() { return JSON.stringify([actual.context ?? {}, actual.environment ?? ""]); }
    function providerKey(kind, values) {
        return kind === "package" ? JSON.stringify([kind, values?.package_id ?? "", values?.service_name ?? ""]) : string(kind);
    }
    function matches(entry, kind, values) {
        const candidate = entry.default_options ?? ({});
        return entry.provider_kind === kind && providerKey(entry.provider_kind, candidate) === providerKey(kind, values)
            && (kind !== "package" || candidate.package_fingerprint === values.package_fingerprint
                && candidate.configuration_fingerprint === values.configuration_fingerprint);
    }
    function reload() {
        draft = clone(runtime?.current ?? ({}));
        savedConfigurationSnapshot = JSON.stringify(draft);
        loadedScope = scopeKey();
        providerDrafts = {};
        feedback = "";
    }
    function synchronize() {
        if (loadedScope !== scopeKey() || (!dirty && JSON.stringify(runtime?.current ?? ({})) !== savedConfigurationSnapshot)) reload();
    }
    function update(name, value) {
        if (!editable) return;
        const next = clone(draft);
        next[name] = value;
        draft = next;
        feedback = "";
    }
    function selectProvider(index) {
        const entry = providers[index];
        if (!editable || !entry?.default_options) return;
        const cached = clone(providerDrafts);
        if (draft.provider_kind) cached[providerKey(draft.provider_kind, options)] = clone(options);
        providerDrafts = cached;
        const selected = clone(cached[providerKey(entry.provider_kind, entry.default_options)] ?? entry.default_options);
        if (entry.provider_kind === "package") for (const name of ["package_id", "service_name", "package_fingerprint", "configuration_fingerprint"])
            selected[name] = entry.default_options[name];
        const next = clone(draft);
        next.provider_kind = entry.provider_kind;
        next.provider_options = selected;
        draft = next;
        feedback = "";
    }
    function refreshProviders() {
        if (!canRefresh) return;
        runtime.refreshProviders();
        feedback = "已刷新原生提供者目录；准确选择与未保存连接／导出草稿保持不变，没有启动桥接。";
    }
    function configurationError() {
        if (!runtime) return "原生桥接宿主尚未接通。";
        if (draft.provider_kind !== "tcp" && !packageProvider) return "从原生目录选择明确的实验室桥接提供者。";
        if (packageProvider && (!/^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$/.test(string(options.package_id))
            || string(options.package_id).length > 64 || !/^[a-z][a-z0-9_.-]{0,79}@[1-9][0-9]{0,3}$/.test(string(options.service_name))
            || !/^[0-9a-f]{64}$/.test(string(options.package_fingerprint)) || !/^[0-9a-f]{64}$/.test(string(options.configuration_fingerprint))))
            return "选择已审阅的准确包／服务和原生内容／配置指纹，不输入任意库地址。";
        if (!string(draft.bind) || string(draft.bind).length > 256 || /\s/.test(string(draft.bind)))
            return "监听地址使用不含空白的IPv4／IPv6数字地址，原生宿主继续校验实际地址。";
        if (!/^\d+$/.test(string(draft.listen_port)) || Number(draft.listen_port) < 0 || Number(draft.listen_port) > 65535)
            return "监听端口为0–65535整数；0由系统在启用监听时分配实际端口。";
        const peer = string(draft.peer);
        if (peer && (peer.length > 2048 || !/^tcp:\/\/(?:\[[^\]\s]+\]|[^\s/:@?#]+):[1-9]\d{0,4}$/.test(peer)
            || Number(peer.slice(peer.lastIndexOf(":") + 1)) > 65535))
            return "对端为空或实际tcp://主机:端口，不含账号、路径、查询或片段。";
        if (typeof draft.listen !== "boolean" || typeof draft.export_snapshots !== "boolean" || typeof draft.export_events !== "boolean")
            return "明确选择监听与两种导出偏好。";
        if (!draft.listen && !peer) return "开启监听或填写实际外连对端，至少选择一条实验室通路。";
        if (!/^[A-Za-z_][A-Za-z0-9_]{0,95}$/.test(string(draft.token_env))) return "令牌环境变量名为1–96字符，不填写实际令牌。";
        return "";
    }
    function save() {
        if (!canSave || !runtime) return;
        if (formError) { feedback = formError; return; }
        const values = clone(draft);
        values.listen_port = Number(values.listen_port);
        const accepted = runtime.save(values), status = runtime.status;
        if (accepted) reload();
        feedback = status;
    }
    function enableSaved() {
        if (!canEnable || !runtime) return;
        runtime.setEnabled(true);
        feedback = runtime.status;
    }
    function stopOwned() {
        if (!canStop || !runtime) return;
        runtime.stop();
        feedback = runtime.status;
    }
    onRuntimeChanged: reload()
    onVisibleChanged: if (visible) synchronize()
    Component.onCompleted: reload()
    Connections { target: root.runtime; function onChanged() { root.synchronize(); } }
    Connections { target: root.providerControl; function onActivated(index) { root.selectProvider(index); } }
    Connections { target: root.refreshControl; function onClicked() { root.refreshProviders(); } }
    Connections { target: root.saveControl; function onClicked() { root.save(); } }
    Connections { target: root.enableControl; function onClicked() { root.enableSaved(); } }
    Connections { target: root.stopControl; function onClicked() { root.stopOwned(); } }
    Connections { target: root.undoControl; function onClicked() { if (root.canUndo) root.reload(); } }
    Connections { target: root.bindControl; function onTextEdited() { root.update("bind", root.bindControl.text); } }
    Connections { target: root.listenPortControl; function onTextEdited() { root.update("listen_port", root.listenPortControl.text); } }
    Connections { target: root.peerControl; function onTextEdited() { root.update("peer", root.peerControl.text); } }
    Connections { target: root.tokenEnvControl; function onTextEdited() { root.update("token_env", root.tokenEnvControl.text); } }
    Connections { target: root.listenControl; function onToggled() { root.update("listen", root.listenControl.checked); } }
    Connections { target: root.snapshotControl; function onToggled() { root.update("export_snapshots", root.snapshotControl.checked); } }
    Connections { target: root.eventsControl; function onToggled() { root.update("export_events", root.eventsControl.checked); } }
}
