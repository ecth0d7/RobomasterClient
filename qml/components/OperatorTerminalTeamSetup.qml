import QtQuick

OperatorTerminalTeamSetupForm {
    id: root
    property var runtime: null
    property var seasonRuntime: null
    property var draft: ({})
    property string savedConfigurationSnapshot: ""
    property string loadedScope: ""
    property string feedback: ""
    property var providerDraft: ({})
    property var providerDrafts: ({})
    property string providerSavedSnapshot: ""
    property string providerLoadedScope: ""
    property string providerFeedback: ""
    property int localFieldIndex: -1
    property var localFields: []
    readonly property bool editable: runtime?.editable === true
    readonly property bool active: runtime?.active === true
    readonly property var actual: runtime?.details ?? ({})
    readonly property var teamView: runtime?.teamView ?? ({})
    readonly property var items: sequence(teamView.items)
    readonly property var members: sequence(teamView.members)
    readonly property bool training: actual.environment === "training"
    readonly property bool dirty: JSON.stringify(draft) !== savedConfigurationSnapshot
    readonly property var providerCatalog: sequence(runtime?.providerCatalog)
    readonly property var providerOptions: providerDraft.provider_options ?? ({})
    readonly property bool providerDirty: JSON.stringify(providerDraft) !== providerSavedSnapshot
    readonly property bool packageProvider: providerDraft.provider_kind === "package"
    readonly property int providerIndex: providerCatalog.findIndex(entry => providerMatches(entry, providerDraft))
    readonly property var selectedProvider: providerCatalog[providerIndex] ?? ({})
    readonly property var purposes: [
        {id: "hud", title: "HUD提示"}, {id: "alerts", title: "告警"},
        {id: "localAi", title: "本机模型"}, {id: "externalAi", title: "外部模型 · 训练"},
        {id: "voice", title: "语音"}
    ]
    readonly property var robotChoices: robotKeys()
    readonly property string formError: configurationError()

    function sequence(value) {
        return value !== null && typeof value === "object" && Number.isInteger(value.length) ? Array.from(value) : [];
    }
    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function string(value) { return value === undefined || value === null ? "" : String(value); }
    function shown(value) { return value === undefined || value === null || value === "" ? "未提供" : String(value); }
    function token(value, maximum) { return typeof value === "string" && value.length > 0 && value.length <= maximum && /^[A-Za-z0-9_.-]+$/.test(value); }
    function fieldToken(value) { return typeof value === "string" && value.length > 0 && value.length <= 96 && /^[A-Za-z0-9_.:/-]+$/.test(value); }
    function scopeKey() { return JSON.stringify([actual.context ?? {}, actual.environment ?? ""]); }
    function providerScopeKey() { return JSON.stringify([actual.context ?? {}, actual.environment ?? "", runtime?.current?.node_id ?? "", runtime?.current?.robot_key ?? ""]); }
    function providerKey(kind, values) {
        return kind === "package" ? JSON.stringify([kind, values?.package_id ?? "", values?.service_name ?? ""]) : string(kind);
    }
    function providerMatches(entry, selection) {
        const values = selection.provider_options ?? ({}), candidate = entry.default_options ?? ({});
        return entry.provider_kind === selection.provider_kind && providerKey(entry.provider_kind, candidate) === providerKey(selection.provider_kind, values)
            && (entry.provider_kind !== "package" || candidate.package_fingerprint === values.package_fingerprint
                && candidate.configuration_fingerprint === values.configuration_fingerprint);
    }
    function reloadProvider() {
        providerDraft = clone(runtime?.providerSelection ?? ({}));
        providerSavedSnapshot = JSON.stringify(providerDraft);
        providerLoadedScope = providerScopeKey();
        providerDrafts = {};
        providerFeedback = "";
    }
    function selectProvider(index) {
        const entry = providerCatalog[index];
        if (!editable || !entry?.default_options) return;
        const cached = clone(providerDrafts);
        if (providerDraft.provider_kind) cached[providerKey(providerDraft.provider_kind, providerOptions)] = clone(providerOptions);
        providerDrafts = cached;
        const values = clone(cached[providerKey(entry.provider_kind, entry.default_options)] ?? entry.default_options);
        if (entry.provider_kind === "package") for (const name of ["package_id", "service_name", "package_fingerprint", "configuration_fingerprint"])
            values[name] = entry.default_options[name];
        providerDraft = {provider_kind: entry.provider_kind, provider_options: values};
        providerFeedback = "";
    }
    function refreshProviders() {
        if (!editable || typeof runtime?.refreshProviders !== "function") return;
        runtime.refreshProviders();
        providerFeedback = "已刷新原生提供者目录；共享参数和提供者的未保存修改均保持不变，没有建立连接。";
    }
    function saveProvider() {
        if (!editable || !runtime || dirty || actual.configured !== true) return;
        const accepted = runtime.saveProvider(clone(providerDraft)), status = runtime.status;
        if (accepted) reloadProvider();
        providerFeedback = status;
    }
    function reload() {
        draft = clone(runtime?.current ?? ({}));
        savedConfigurationSnapshot = JSON.stringify(draft);
        loadedScope = scopeKey();
        localFieldIndex = -1;
        feedback = "";
    }
    function synchronize() {
        if (loadedScope !== scopeKey() || (!dirty && JSON.stringify(runtime?.current ?? ({})) !== savedConfigurationSnapshot)) reload();
        if (providerLoadedScope !== providerScopeKey() || (!providerDirty && JSON.stringify(runtime?.providerSelection ?? ({})) !== providerSavedSnapshot)) reloadProvider();
    }
    function update(key, value) {
        const next = clone(draft);
        next[key] = value;
        draft = next;
        feedback = "";
    }
    function updatePeer(index, key, value) {
        const next = clone(draft.peers ?? []);
        next[index][key] = value;
        update("peers", next);
    }
    function removePeer(index) {
        const next = clone(draft.peers ?? []);
        next.splice(index, 1);
        update("peers", next);
    }
    function addPeer() {
        const next = clone(draft.peers ?? []);
        next.push({node_id: "", robot_key: "", certificate_file: "", fingerprint: "",
                   can_send: false, can_aggregate: false, allowed_fields: []});
        update("peers", next);
    }
    function toggleUse(id, selected) {
        const next = (draft.allowed_uses ?? []).filter(value => value !== id);
        if (selected) next.push(id);
        update("allowed_uses", next);
    }
    function robotKeys() {
        const result = [];
        const roster = sequence(seasonRuntime?.current?.roster);
        for (const camp of ["red", "blue"])
            for (const role of roster)
                for (let slot = 1; slot <= role.count; ++slot)
                    result.push(camp + "/" + role.role_id + "/" + slot);
        return result;
    }
    function peerRobotKeys() {
        const camp = string(draft.robot_key).split("/")[0];
        return robotChoices.filter(value => value.split("/")[0] === camp && value !== draft.robot_key);
    }
    function observedFields() {
        const result = [];
        const seen = {};
        for (const row of sequence(seasonRuntime?.terminalBus?.view?.items)) {
            if (row.team_id !== draft.team_id || row.robot_key !== draft.robot_key) continue;
            const key = JSON.stringify([row.source_id, row.item_id]);
            if (seen[key]) continue;
            seen[key] = true;
            result.push({source_id: row.source_id, item_id: row.item_id, mock: row.mock === true, state: row.state});
        }
        return result;
    }
    function refreshObservedFields() {
        const next = observedFields();
        if (JSON.stringify(next) === JSON.stringify(localFields)) return;
        const previous = localFields[localFieldIndex];
        localFields = next;
        localFieldIndex = previous ? next.findIndex(entry => entry.source_id === previous.source_id && entry.item_id === previous.item_id) : -1;
    }
    function addObservedField() {
        const field = localFields[localFieldIndex];
        if (!field) return;
        const next = clone(draft.allowed_fields ?? []);
        if (next.some(entry => entry.source_id === field.source_id && entry.item_id === field.item_id)) {
            feedback = "此来源字段已经在允许列表中。";
            return;
        }
        next.push({source_id: field.source_id, item_id: field.item_id, uses: []});
        update("allowed_fields", next);
    }
    function grantError(fields, label) {
        if (!fields || typeof fields.length !== "number" || fields.length > 64) return label + "最多64项字段。";
        const seen = {};
        for (const field of fields) {
            if (!fieldToken(field.source_id) || !fieldToken(field.item_id)) return label + "需要填写明确的来源ID与数据项ID，不使用通配符。";
            if (!training && (field.uses ?? []).indexOf("externalAi") >= 0) return label + "不能在比赛用途授权外部模型。";
            const key = JSON.stringify([field.source_id, field.item_id]);
            if (seen[key]) return label + "包含重复字段。";
            seen[key] = true;
        }
        return "";
    }
    function configurationError() {
        if (!runtime) return "队伍共享宿主尚未接入。";
        for (const key of ["team_id", "match_id", "epoch", "node_id", "publisher_id"])
            if (!token(draft[key], 64)) return "填写队伍、比赛、共享轮次、节点和发布节点标识；仅使用字母、数字、点、横线或下划线。";
        if (robotChoices.indexOf(draft.robot_key) < 0) return "请选择当前2027阵容中的本机语义机器人。";
        const endpoint = string(draft.endpoint);
        if (!/^mqtts:\/\/(?:\[[0-9a-fA-F:]+\]|[^\s/:@?#]+):[1-9]\d{0,4}$/.test(endpoint) || Number(endpoint.slice(endpoint.lastIndexOf(":") + 1)) > 65535)
            return "填写明确的 mqtts://主机:端口；不包含账号、路径或查询参数。";
        if (!string(draft.ca_file).trim() || !string(draft.certificate_file).trim()) return "填写CA证书与本机签名证书文件引用。";
        if (!/^[A-Za-z_][A-Za-z0-9_]{0,95}$/.test(string(draft.signing_key_file_env))) return "填写保存签名密钥文件路径的环境变量名；不要填写密钥或实际密钥路径。";
        for (const key of ["heartbeat_ms", "timeout_ms", "max_clock_skew_ms"])
            if (!/^\d+$/.test(string(draft[key]))) return "心跳、超时和时钟偏差须填写明确的整数毫秒值。";
        const heartbeat = Number(draft.heartbeat_ms), timeout = Number(draft.timeout_ms), skew = Number(draft.max_clock_skew_ms);
        if (!Number.isInteger(heartbeat) || heartbeat < 250 || heartbeat > 10000 || !Number.isInteger(timeout) || timeout < 750 || timeout > 60000 || timeout < 3 * heartbeat)
            return "心跳为250–10000ms，超时为750–60000ms且不少于三个心跳周期。";
        if (!Number.isInteger(skew) || skew < 0 || skew > 1000) return "时钟偏差上限为0–1000ms；声明同步不会自动证明时钟可信。";
        if (!draft.team_wide_sharing_confirmed) return "确认队内各节点的共享范围和身份后再保存。";
        let error = grantError(draft.allowed_fields ?? [], "本机允许列表");
        if (error) return error;
        const peers = draft.peers ?? [], nodes = [draft.node_id], robots = [draft.robot_key], pins = [];
        if (peers.length > 15) return "最多配置15个固定身份队友。";
        let publisher = draft.publisher_id === draft.node_id && draft.can_aggregate === true;
        for (const peer of peers) {
            if (!token(peer.node_id, 64) || nodes.indexOf(peer.node_id) >= 0) return "队友节点标识必须填写且互不重复，也不能与本机相同。";
            if (peerRobotKeys().indexOf(peer.robot_key) < 0 || robots.indexOf(peer.robot_key) >= 0) return "队友必须使用同阵营、互不重复的2027语义机器人。";
            if (!string(peer.certificate_file).trim() || !/^[0-9a-f]{64}$/.test(string(peer.fingerprint)) || pins.indexOf(peer.fingerprint) >= 0)
                return "每个队友需要证书文件和独立的64位小写SHA256公钥指纹。";
            error = grantError(peer.allowed_fields ?? [], "队友 " + peer.node_id + " 的允许列表");
            if (error) return error;
            nodes.push(peer.node_id); robots.push(peer.robot_key); pins.push(peer.fingerprint);
            publisher = publisher || (peer.node_id === draft.publisher_id && peer.can_aggregate === true);
        }
        if (!publisher) return "汇总发布节点必须是明确允许汇总的本机或固定队友。";
        if (!training && draft.training_mock) return "比赛用途不能启用训练mock。";
        if (!training && (draft.allowed_uses ?? []).indexOf("externalAi") >= 0) return "比赛用途不能授权外部模型。";
        return "";
    }
    function save() {
        if (!runtime || !editable) return;
        if (formError) { feedback = formError; return; }
        const values = clone(draft);
        for (const key of ["heartbeat_ms", "timeout_ms", "max_clock_skew_ms"]) values[key] = Number(values[key]);
        const accepted = runtime.save(values);
        const status = runtime.status;
        if (accepted) reload();
        feedback = status;
    }
    function purposeNames(values) { return sequence(values).map(value => purposes.find(entry => entry.id === value)?.title ?? value).join("、") || "未授权"; }
    function stateName(value) {
        return ({fresh: "有效 · 测量仍未核验", mock: "训练mock", time_unverified: "时间未核验", expired: "已过期", offline: "来源离线",
                 withdrawn: "已撤回", retired: "已退役", superseded: "已被新版本取代", conflict: "字段冲突", quarantined: "已隔离", clock_invalid: "时钟异常"})[value] ?? shown(value);
    }
    function stamp(value) { return typeof value === "number" && value > 0 ? Qt.formatDateTime(new Date(value), "yyyy-MM-dd hh:mm:ss.zzz") + " / " + value + " ms" : "未知"; }
    function valueText(row) {
        if (!["fresh", "mock", "time_unverified"].includes(row.state) || !(row.remaining_ms > 0)) return "此状态不提供有效值";
        return row.value === undefined || row.value === null ? "未知" : JSON.stringify(row.value);
    }
    onRuntimeChanged: { reload(); reloadProvider(); }
    onSeasonRuntimeChanged: refreshObservedFields()
    onDraftChanged: refreshObservedFields()
    onVisibleChanged: if (visible) synchronize()
    Component.onCompleted: { reload(); reloadProvider(); }
    Connections { target: root.runtime; function onChanged() { root.synchronize(); } }
    Connections { target: root.seasonRuntime?.terminalBus ?? null; function onChanged() { root.refreshObservedFields(); } }

    function selectionText(values, index, fallback) {
        return index >= 0 && index < values.length ? string(values[index]) : fallback;
    }

    // Provider selection and team parameters retain independent draft scopes.
    editorEditable: editable
    saveEnabled: editable && dirty
    enableEnabled: !!runtime && editable && !active && !dirty && !providerDirty && actual.configured === true
        && actual.provider_selection_saved === true && actual.provider_available === true && actual.verification_backend_available === true
    stopEnabled: active
    undoEnabled: editable && dirty
    providerTitles: providerCatalog.map(entry => entry.label + (entry.available === false ? " · 未就绪" : ""))
    providerSelectedIndex: providerIndex
    providerEditable: editable
    providerRefreshEnabled: editable && typeof runtime?.refreshProviders === "function"
    providerSaveEnabled: editable && !dirty && actual.configured === true && (providerDirty || actual.provider_selection_saved !== true)
    providerUndoEnabled: editable && providerDirty
    providerStatusText: providerFeedback || runtime?.status || "原生队伍共享宿主未接通，没有连接队友。"
    providerReviewText: dirty || actual.configured !== true ? "先明确保存下方队伍参数与节点身份，再保存该身份范围的共享提供者；提供者不重复设置身份或服务器地址。"
        : providerDirty ? "提供者存在未保存修改。保存会停止旧端点与旧汇总视图，不自动连接；启用仍须满足新的共享轮次要求。"
        : actual.provider_selection_saved !== true ? "当前身份范围尚未明确保存提供者。初始模板不构成启用许可。"
        : actual.provider_available !== true ? "保存的提供者尚未就绪或内容／配置已变化。保留原身份，不自动回退；请在插件管理中检查后明确选择并保存。" : ""
    providerIdentityRows: [
        {label: "当前编辑提供者", value: providerDraft.provider_kind === "builtin" ? "内置认证队伍共享" : packageProvider ? shown(providerOptions.package_id) + " / " + shown(providerOptions.service_name) : "未提供", detail: true},
        {label: "预期包内容指纹", value: packageProvider ? shown(providerOptions.package_fingerprint) : "内置提供者不适用", detail: true},
        {label: "预期配置指纹", value: packageProvider ? shown(providerOptions.configuration_fingerprint) : "内置提供者不适用", detail: true},
        {label: "已保存提供者／当前可用", value: (actual.provider_selection_saved === true ? "已明确保存" : "尚未保存") + " / " + (actual.provider_available === true ? "能力就绪" : "未就绪")},
        {label: "已保存节点／语义机器人范围", value: shown(runtime?.current?.node_id) + " / " + shown(runtime?.current?.robot_key), detail: true},
        {label: "正式规则／部署用途", value: shown(actual.context?.profile_id) + " / " + shown(actual.environment), detail: true},
        {label: "实际原生能力", value: actual.provider_identity?.package_id ? actual.provider_identity.package_id + " / " + shown(actual.provider_identity.service_name) : shown(actual.provider_identity?.plugin_id), detail: true},
        {label: "独立主机验签后端", value: actual.verification_backend_available === true ? "原生后端可用；不代表当前数据已经核验" : "后端不可用；共享不能启用，本机功能继续运行", detail: true},
        {label: "当前宿主验签范围", value: actual.host_verifier_configured === true ? "原生宿主已配置当前身份和证书范围" : "尚未配置；仅在原生启用核验成功后成立", detail: true}
    ]
    lockText: !editable || dirty ? runtime?.lockReason || "存在未保存修改。保存会停止当前共享；启用使用已保存配置，且必须使用新的共享轮次。" : ""
    statusText: feedback || runtime?.status || "队内共享宿主尚未接入；没有建立网络连接。"
    statusRows: [
        {label: "插件／TLS／通道", value: (active ? "已启用" : "已停用") + " / " + (actual.tls_connected === true ? "TLS已连接" : "TLS未确认") + " / " + (actual.connected === true ? "已连接" : "未连接"), detail: width < 760},
        {label: "来源原签名／发布者证明", value: (actual.source_proofs_verified === true ? "已核验" : "未核验") + " / " + (actual.publisher_proof_verified === true ? "已核验" : "未核验")},
        {label: "本机快照导出／接收汇总／拒绝", value: shown(actual.exports) + " / " + shown(actual.received_views) + " / " + shown(actual.rejected_views)},
        {label: "实际网络发布／接收／丢弃", value: shown(actual.published) + " / " + shown(actual.received) + " / " + shown(actual.dropped)},
        {label: "能力边界", value: "签名证明发送身份；不证明测量、生产时钟或地图标定。官方权威、模型输入与机器人动作未因此接通。", detail: true}
    ]
    teamText: string(draft.team_id)
    matchText: string(draft.match_id)
    epochText: string(draft.epoch)
    nodeText: string(draft.node_id)
    robotTitles: robotChoices
    robotIndex: robotChoices.indexOf(draft.robot_key)
    robotDisplay: selectionText(robotChoices, robotIndex, "选择2027阵营／角色／槽位")
    robotHint: draft.robot_key || "阵容来自当前正式规则目录；不推测官方登录编号。"
    publisherText: string(draft.publisher_id)
    canSendChecked: draft.can_send === true
    canAggregateChecked: draft.can_aggregate === true
    confirmedChecked: draft.team_wide_sharing_confirmed === true
    endpointText: string(draft.endpoint)
    caText: string(draft.ca_file)
    certificateText: string(draft.certificate_file)
    keyEnvText: string(draft.signing_key_file_env)
    heartbeatText: string(draft.heartbeat_ms)
    timeoutText: string(draft.timeout_ms)
    skewText: string(draft.max_clock_skew_ms)
    clocksChecked: draft.clocks_synchronized === true
    mockChecked: draft.training_mock === true
    mockEditable: editable && (training || draft.training_mock === true)
    purposeCount: purposes.length
    localFieldTitles: localFields.map(entry => (entry.mock ? "MOCK " : "") + entry.source_id + " / " + entry.item_id + " / " + stateName(entry.state))
    localFieldSelectedIndex: localFieldIndex
    localFieldDisplay: selectionText(localFieldTitles, localFieldIndex, "没有匹配当前队伍／机器人的已选字段")
    localFieldEditable: editable && localFields.length > 0
    addObservedEnabled: editable && localFieldIndex >= 0 && localFieldIndex < localFields.length && (draft.allowed_fields ?? []).length < 64
    peerCount: (draft.peers ?? []).length
    addPeerEnabled: editable && peerCount < 15
    memberCount: members.length
    itemCount: items.length
    errorText: formError
    viewRows: [
        {label: "队伍／场次／轮次", value: shown(teamView.team_id) + " / " + shown(teamView.match_id) + " / " + shown(teamView.epoch), detail: true},
        {label: "发布节点／视图ID／版本", value: shown(teamView.publisher_id) + " / " + shown(teamView.view_id) + " / " + shown(teamView.revision), detail: true},
        {label: "发布会话", value: shown(teamView.publisher_session_id), detail: true},
        {label: "规则／场地／能力版本", value: shown(teamView.context?.profile_id) + " / " + shown(teamView.context?.field_profile_id) + " / " + shown(teamView.context?.capability_revision), detail: true},
        {label: "成员／数据项", value: members.length + " / " + items.length},
        {label: "模型输入", value: teamView.ai_input_ready === true ? "宿主报告就绪" : "尚未接通；此视图不自动请求模型或机器人动作"}
    ]

    component GrantEditor: OperatorTeamSetupGrantForm {
        id: grants
        property var entries: []
        signal edited(var values)
        entryCount: entries.length
        addEnabled: root.editable && entries.length < 64
        function setValue(index, key, value) {
            if (!root.editable || index < 0 || index >= entries.length) return;
            const next = root.clone(entries); next[index][key] = value; edited(next);
        }
        function toggle(index, use, selected) {
            if (!root.editable || index < 0 || index >= entries.length) return;
            const values = (entries[index].uses ?? []).filter(value => value !== use);
            if (selected) values.push(use);
            setValue(index, "uses", values);
        }
        function remove(index) {
            if (!root.editable || index < 0 || index >= entries.length) return;
            const next = root.clone(entries); next.splice(index, 1); edited(next);
        }
        rowDelegate: Component {
            OperatorTeamSetupGrantRowForm {
                id: grantRow
                required property int index
                readonly property var entry: grants.entries[index] ?? ({})
                objectName: "teamGrant_" + index
                width: grants.rowDelegateWidth
                sourceValue: root.string(entry.source_id)
                itemValue: root.string(entry.item_id)
                inputEditable: root.editable
                removeEnabled: root.editable
                purposeCount: root.purposes.length
                fieldSpacing: grants.fieldSpacing
                columnGap: grants.columnGap
                fieldBreakpoint: grants.fieldBreakpoint
                purposeWideBreakpoint: grants.purposeWideBreakpoint
                purposeCompactBreakpoint: grants.purposeCompactBreakpoint
                purposeSpacing: grants.purposeSpacing
                removeWidth: grants.removeWidth
                controlHeight: grants.controlHeight
                labelHeight: grants.labelHeight
                labelGap: grants.labelGap
                hintGap: grants.hintGap
                minimumHintHeight: grants.minimumHintHeight
                hintBottomPadding: grants.hintBottomPadding
                labelSize: grants.labelSize
                inputSize: grants.inputSize
                hintSize: grants.hintSize
                surfaceColor: grants.surfaceColor
                textColor: grants.textColor
                secondaryTextColor: grants.secondaryTextColor
                warningColor: grants.warningColor
                separatorColor: grants.separatorColor
                inputSurfaceColor: grants.inputSurfaceColor
                fontFamily: grants.fontFamily
                inputFontFamily: grants.inputFontFamily
                purposeDelegate: Component {
                    OperatorCheckBox {
                        required property int index
                        readonly property var purpose: root.purposes[index] ?? ({})
                        width: grantRow.purposeDelegateWidth
                        height: grants.controlHeight
                        text: purpose.title ?? "未声明用途"
                        checked: (grantRow.entry.uses ?? []).indexOf(purpose.id) >= 0
                        enabled: root.editable && (purpose.id !== "externalAi" || root.training || checked)
                        textColor: grants.textColor
                        font.family: grants.fontFamily
                        font.pixelSize: Math.max(grants.inputSize, 9.5 / Math.max(0.1, hudScale))
                        onToggled: grants.toggle(grantRow.index, purpose.id, checked)
                    }
                }
                Connections { target: grantRow.sourceControl; function onTextEdited() { grants.setValue(grantRow.index, "source_id", grantRow.sourceControl.text); } }
                Connections { target: grantRow.itemControl; function onTextEdited() { grants.setValue(grantRow.index, "item_id", grantRow.itemControl.text); } }
                Connections { target: grantRow.removeControl; function onClicked() { grants.remove(grantRow.index); } }
            }
        }
        Connections {
            target: grants.addControl
            function onClicked() {
                if (!grants.addEnabled) return;
                const next = root.clone(grants.entries); next.push({source_id: "", item_id: "", uses: []}); grants.edited(next);
            }
        }
    }
    purposeDelegate: Component {
        OperatorCheckBox {
            required property int index
            readonly property var purpose: root.purposes[index] ?? ({})
            width: root.purposeDelegateWidth
            height: root.controlHeight
            text: purpose.title ?? "未声明用途"
            checked: (root.draft.allowed_uses ?? []).indexOf(purpose.id) >= 0
            enabled: root.editable && (purpose.id !== "externalAi" || root.training || checked)
            textColor: root.textColor
            font.family: root.fontFamily
            font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
            onToggled: root.toggleUse(purpose.id, checked)
        }
    }
    localGrantDelegate: Component {
        GrantEditor {
            width: root.localGrantDelegateWidth
            entries: root.draft.allowed_fields ?? []
            label: "本机可发送字段"
            sectionSpacing: root.formSpacing
            fieldSpacing: root.fieldSpacing
            columnGap: root.columnGap
            controlHeight: root.controlHeight
            labelSize: root.noteSize
            noteSize: root.noteSize
            inputSize: root.inputSize
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            secondaryTextColor: root.mutedColor
            warningColor: root.warningColor
            separatorColor: root.separatorColor
            fontFamily: root.fontFamily
            onEdited: function(values) { root.update("allowed_fields", values); }
        }
    }
    peerDelegate: Component {
        OperatorTeamSetupPeerForm {
            id: peerRow
            required property int index
            readonly property var entry: (root.draft.peers ?? [])[index] ?? ({})
            readonly property var peerRobots: root.peerRobotKeys()
            objectName: "teamPeer_" + index
            width: root.peerDelegateWidth
            titleText: "队友 " + (entry.node_id || "待填写身份")
            nodeValue: root.string(entry.node_id)
            certificateValue: root.string(entry.certificate_file)
            fingerprintValue: root.string(entry.fingerprint)
            robotTitles: peerRobots
            robotIndex: peerRobots.indexOf(entry.robot_key)
            robotDisplayText: root.selectionText(peerRobots, robotIndex, "选择同阵营且未重复的机器人")
            robotHint: entry.robot_key || "先选择本机阵营与角色。"
            canSendValue: entry.can_send === true
            canAggregateValue: entry.can_aggregate === true
            inputEditable: root.editable
            removeEnabled: root.editable
            formSpacing: root.formSpacing
            actionSpacing: root.actionSpacing
            fieldSpacing: root.fieldSpacing
            columnGap: root.columnGap
            controlHeight: root.controlHeight
            sectionTitleSize: root.sectionTitleSize
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            labelSize: root.noteSize
            noteSize: root.noteSize
            inputSize: root.inputSize
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            secondaryTextColor: root.mutedColor
            warningColor: root.warningColor
            separatorColor: root.separatorColor
            fontFamily: root.fontFamily
            grantsDelegate: Component {
                GrantEditor {
                    width: peerRow.grantDelegateWidth
                    entries: peerRow.entry.allowed_fields ?? []
                    label: "此队友允许发送的字段"
                    sectionSpacing: root.formSpacing
                    fieldSpacing: root.fieldSpacing
                    columnGap: root.columnGap
                    controlHeight: root.controlHeight
                    labelSize: root.noteSize
                    noteSize: root.noteSize
                    inputSize: root.inputSize
                    surfaceColor: root.surfaceColor
                    textColor: root.textColor
                    secondaryTextColor: root.mutedColor
                    warningColor: root.warningColor
                    separatorColor: root.separatorColor
                    fontFamily: root.fontFamily
                    onEdited: function(values) { root.updatePeer(peerRow.index, "allowed_fields", values); }
                }
            }
            Connections { target: peerRow.nodeControl; function onTextEdited() { root.updatePeer(peerRow.index, "node_id", peerRow.nodeControl.text); } }
            Connections { target: peerRow.certificateControl; function onTextEdited() { root.updatePeer(peerRow.index, "certificate_file", peerRow.certificateControl.text); } }
            Connections { target: peerRow.fingerprintControl; function onTextEdited() { root.updatePeer(peerRow.index, "fingerprint", peerRow.fingerprintControl.text); } }
            Connections { target: peerRow.robotControl; function onActivated(index) { if (root.editable && index >= 0 && index < peerRow.peerRobots.length) root.updatePeer(peerRow.index, "robot_key", peerRow.peerRobots[index]); } }
            Connections { target: peerRow.canSendControl; function onToggled() { if (root.editable) root.updatePeer(peerRow.index, "can_send", peerRow.canSendControl.checked); } }
            Connections { target: peerRow.canAggregateControl; function onToggled() { if (root.editable) root.updatePeer(peerRow.index, "can_aggregate", peerRow.canAggregateControl.checked); } }
            Connections { target: peerRow.removeControl; function onClicked() { if (root.editable) root.removePeer(peerRow.index); } }
        }
    }
    memberDelegate: Component {
        OperatorTeamSetupMemberForm {
            required property int index
            readonly property var entry: root.members[index] ?? ({})
            objectName: "teamMember_" + index
            width: root.memberDelegateWidth
            heading: "来源节点 " + root.shown(entry.node_id)
            rows: [{label: "语义机器人／心跳状态", value: root.shown(entry.robot_key) + " / " + (entry.online === true ? "在线" : "离线／未确认"), detail: true},
                   {label: "原节点快照", value: root.shown(entry.snapshot_id), detail: true},
                   {label: "节点会话", value: root.shown(entry.session_id), detail: true}]
            sectionTitleSize: root.sectionTitleSize
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            noteSize: root.noteSize
            inputSize: root.inputSize
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            mutedColor: root.mutedColor
            separatorColor: root.separatorColor
            fontFamily: root.fontFamily
        }
    }
    itemDelegate: Component {
        OperatorTeamSetupObservationForm {
            required property int index
            readonly property var entry: root.items[index] ?? ({})
            objectName: "teamObservation_" + index
            width: root.itemDelegateWidth
            heading: (entry.mock === true ? "MOCK  ·  " : "共享观测  ·  ") + root.shown(entry.item_id) + "  /  " + root.stateName(entry.state)
            valueText: "值：" + root.valueText(entry)
            valueColor: entry.state === "fresh" ? root.textColor : root.warningColor
            sourceText: "来源节点 " + root.shown(entry.source_node) + " / 机器人 " + root.shown(entry.robot_key) + " / 数据源 " + root.shown(entry.source_id) + " / 传感器 " + root.shown(entry.sensor_id)
            typeText: "类型 " + root.shown(entry.source_kind) + " / " + root.shown(entry.data_type) + " / 验证 " + root.shown(entry.validation) + " / 置信度 " + (typeof entry.confidence === "number" ? entry.confidence.toFixed(3) : "未知")
            timeText: "产生 " + root.stamp(entry.produced_at_ms) + "\n接收 " + root.stamp(entry.received_at_ms)
            lifetimeText: "接收年龄 " + root.shown(entry.received_age_ms) + " ms / 剩余寿命 " + root.shown(entry.remaining_ms) + " ms / TTL " + root.shown(entry.ttl_ms) + " ms / 时钟域 " + root.shown(entry.clock_domain) + " / 时间依据 " + root.shown(entry.time_basis)
            lineageText: "原来源会话 " + root.shown(entry.session_id) + " / 序号 " + root.shown(entry.sequence) + " / 生命周期 " + root.shown(entry.lifecycle) + " / 原快照 " + root.shown(entry.snapshot_id)
            proofText: "原签名证明 " + (entry.host_source_proof_verified === true ? "宿主已核验" : "未核验") + " / 证明引用 " + root.shown(entry.source_proof_ref)
            permissionText: "当前允许用途：" + root.purposeNames(entry.allowed_uses) + "。测量／地图标定未核验；共享签名不授予官方权威或自动动作。"
            frameText: entry.frame_id ? "坐标参考 " + root.shown(entry.frame_id) + " / 版本 " + root.shown(entry.frame_revision) + " / 变换 " + root.shown(entry.transform_id) + "；当前仅文本，未接地图渲染。" : ""
            fieldSpacing: root.fieldSpacing
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            sectionTitleSize: root.sectionTitleSize
            noteSize: root.noteSize
            valueSize: root.introSize
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            mutedColor: root.mutedColor
            warningColor: root.warningColor
            separatorColor: root.separatorColor
            fontFamily: root.fontFamily
        }
    }

    Connections { target: root.providerControl; function onActivated(index) { root.selectProvider(index); } }
    Connections { target: root.providerRefreshControl; function onClicked() { root.refreshProviders(); } }
    Connections { target: root.providerSaveControl; function onClicked() { root.saveProvider(); } }
    Connections { target: root.providerUndoControl; function onClicked() { if (root.editable) root.reloadProvider(); } }
    Connections { target: root.saveControl; function onClicked() { root.save(); } }
    Connections { target: root.enableControl; function onClicked() { if (root.enableEnabled) root.runtime.setEnabled(true); } }
    Connections { target: root.stopControl; function onClicked() { if (root.active) root.runtime.stop(); } }
    Connections { target: root.undoControl; function onClicked() { if (root.editable) root.reload(); } }
    Connections { target: root.teamControl; function onTextEdited() { root.update("team_id", root.teamControl.text); } }
    Connections { target: root.matchControl; function onTextEdited() { root.update("match_id", root.matchControl.text); } }
    Connections { target: root.epochControl; function onTextEdited() { root.update("epoch", root.epochControl.text); } }
    Connections { target: root.nodeControl; function onTextEdited() { root.update("node_id", root.nodeControl.text); } }
    Connections { target: root.robotControl; function onActivated(index) { if (root.editable && index >= 0 && index < root.robotChoices.length) root.update("robot_key", root.robotChoices[index]); } }
    Connections { target: root.publisherControl; function onTextEdited() { root.update("publisher_id", root.publisherControl.text); } }
    Connections { target: root.canSendControl; function onToggled() { if (root.editable) root.update("can_send", root.canSendControl.checked); } }
    Connections { target: root.canAggregateControl; function onToggled() { if (root.editable) root.update("can_aggregate", root.canAggregateControl.checked); } }
    Connections { target: root.confirmedControl; function onToggled() { if (root.editable) root.update("team_wide_sharing_confirmed", root.confirmedControl.checked); } }
    Connections { target: root.endpointControl; function onTextEdited() { root.update("endpoint", root.endpointControl.text); } }
    Connections { target: root.caControl; function onTextEdited() { root.update("ca_file", root.caControl.text); } }
    Connections { target: root.certificateControl; function onTextEdited() { root.update("certificate_file", root.certificateControl.text); } }
    Connections { target: root.keyEnvControl; function onTextEdited() { root.update("signing_key_file_env", root.keyEnvControl.text); } }
    Connections { target: root.heartbeatControl; function onTextEdited() { root.update("heartbeat_ms", root.heartbeatControl.text); } }
    Connections { target: root.timeoutControl; function onTextEdited() { root.update("timeout_ms", root.timeoutControl.text); } }
    Connections { target: root.skewControl; function onTextEdited() { root.update("max_clock_skew_ms", root.skewControl.text); } }
    Connections { target: root.clocksControl; function onToggled() { if (root.editable) root.update("clocks_synchronized", root.clocksControl.checked); } }
    Connections { target: root.mockControl; function onToggled() { if (root.mockEditable) root.update("training_mock", root.mockControl.checked); } }
    Connections { target: root.localFieldControl; function onActivated(index) { if (root.localFieldEditable && index >= 0 && index < root.localFields.length) root.localFieldIndex = index; } }
    Connections { target: root.addObservedControl; function onClicked() { if (root.addObservedEnabled) root.addObservedField(); } }
    Connections { target: root.addPeerControl; function onClicked() { if (root.addPeerEnabled) root.addPeer(); } }
}
