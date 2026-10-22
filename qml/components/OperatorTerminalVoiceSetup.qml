import QtQuick

OperatorTerminalVoiceSetupForm {
    id: root
    property var runtime: null
    property var seasonRuntime: null
    property var teamRuntime: null
    property var adviceRuntime: null
    property var draft: ({})
    property string savedConfigurationSnapshot: ""
    property string loadedScope: ""
    property string feedback: ""
    readonly property var actual: runtime?.details ?? ({})
    readonly property bool editable: runtime?.editable === true
    readonly property bool dirty: JSON.stringify(draft) !== savedConfigurationSnapshot
    readonly property var activeAnnouncements: actual.active_announcements ?? []
    readonly property var robotChoices: robotKeys()
    readonly property var knownNodes: nodes()
    readonly property string formError: configurationError()

    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function string(value) { return value === undefined || value === null ? "" : String(value); }
    function shown(value) { return value === undefined || value === null || value === "" ? "未提供" : String(value); }
    function scopeKey() { return JSON.stringify([actual.context ?? {}, actual.environment ?? ""]); }
    function reload() {
        draft = clone(runtime?.current ?? ({}));
        savedConfigurationSnapshot = JSON.stringify(draft);
        loadedScope = scopeKey();
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
    function robotKeys() {
        const result = [];
        for (const camp of ["red", "blue"])
            for (const role of seasonRuntime?.current?.roster ?? [])
                for (let slot = 1; slot <= role.count; ++slot)
                    result.push(camp + "/" + role.role_id + "/" + slot);
        return result;
    }
    function nodes() {
        const config = teamRuntime?.current ?? ({}), result = [];
        if (config.node_id) result.push({id: config.node_id, robot: config.robot_key, local: true});
        for (const peer of config.peers ?? []) result.push({id: peer.node_id, robot: peer.robot_key, local: false});
        return result;
    }
    function setListener(id, selected) {
        const next = (draft.listener_node_ids ?? []).filter(value => value !== id);
        if (selected) next.push(id);
        update("listener_node_ids", next);
    }
    function configurationError() {
        if (!runtime) return "自动语音协调宿主尚未接通。";
        if (!/^[A-Za-z0-9_.:/-]{1,64}$/.test(string(draft.team_id)) || robotChoices.indexOf(draft.robot_key) < 0)
            return "填写队伍标识并选择当前2027语义机器人。";
        if (draft.team_enabled === true) {
            if (!/^[A-Za-z0-9_.-]{1,64}$/.test(string(draft.speaker_node_id))) return "队内模式需要明确指定唯一播放节点。";
            if ((draft.listener_node_ids ?? []).indexOf(draft.speaker_node_id) < 0) return "把指定播放节点列入明确接收列表，再保存队内语音配置。";
        }
        return "";
    }
    function save() {
        if (!runtime || !editable) return;
        if (formError) { feedback = formError; return; }
        const accepted = runtime.save(clone(draft));
        const status = runtime.status;
        if (accepted) reload();
        feedback = status;
    }
    function priorityName(value) { return ({info: "一般及以上", caution: "注意及以上", urgent: "仅紧急"})[value] ?? shown(value); }
    function routeName(value) { return ({disabled: "未启用", local: "独立本机建议播报", team_designated: "队内指定节点统一播放", team_publish: "本机写入共享事件"})[value] ?? shown(value); }
    onRuntimeChanged: reload()
    onVisibleChanged: if (visible) synchronize()
    Component.onCompleted: reload()
    Connections { target: root.runtime; function onChanged() { root.synchronize(); } }

    inputEditable: editable
    saveEnabled: editable && dirty
    undoEnabled: editable && dirty
    localEnabled: draft.local_enabled === true
    teamEnabled: draft.team_enabled === true
    teamValue: string(draft.team_id)
    robotTitles: robotChoices
    robotIndex: robotChoices.indexOf(draft.robot_key)
    robotDisplayText: robotIndex >= 0 ? robotChoices[robotIndex] : draft.robot_key ? "已保存机器人不在当前角色目录" : "选择2027阵营／角色／槽位"
    robotHint: draft.robot_key || "不推测官方登录编号。"
    priorityIndex: ["info", "caution", "urgent"].indexOf(draft.minimum_priority)
    priorityDisplayText: priorityIndex >= 0 ? priorityName(draft.minimum_priority) : "尚未选择优先级"
    speakerValue: string(draft.speaker_node_id)
    listenersValue: (draft.listener_node_ids ?? []).join("\n")
    lockText: editable ? "" : runtime?.lockReason || "语音配置宿主不可用或正在保存，请稍后重试。"
    statusText: feedback || runtime?.status || "协调宿主尚未接通，没有提交自动语音。"
    feedbackVisible: feedback.length > 0
    formErrorText: formError
    nodeCount: knownNodes.length
    announcementCount: activeAnnouncements.length
    routingRows: [
        {label: "已保存路径", value: routeName(actual.route)},
        {label: "模型语音意向／本机独立路径", value: (actual.model_voice_enabled === true ? "已开启并匹配身份" : "未开启或身份不匹配") + " / " + (actual.local_route_ready === true ? "可接纳" : "未就绪"), detail: true},
        {label: "本节点／指定播放节点", value: shown(actual.local_node_id) + " / " + shown(runtime?.current?.speaker_node_id), detail: true},
        {label: "共享事件发布", value: actual.team_publish_ready === true ? "可写入已授权本机总线；实际发送由队伍插件报告" : actual.publish_block_reason || "未就绪", detail: true},
        {label: "队内播放接纳", value: actual.team_receive_ready === true ? "当前节点通过完整视图与时钟接纳" : actual.team_block_reason || "未就绪", detail: true},
        {label: "实际语音服务", value: actual.speech_status || "未提供", detail: true},
        {label: "语音输出方式", value: actual.speech_details?.playback === true ? "服务报告合成后播放；提交不证明已经出声" : actual.speech_details?.playback === false ? "服务仅合成，不播放" : "尚未提供输出能力", detail: true},
        {label: "提交／取消／去重", value: shown(actual.submitted) + " / " + shown(actual.cancelled) + " / " + shown(actual.deduplicated)},
        {label: "写入本机共享事件／撤回", value: shown(actual.published) + " / " + shown(actual.withdrawn)},
        {label: "隐式降级／机器人动作", value: "均不启用；共享插件缺失不影响其他本机功能", detail: true}
    ]
    grantRows: [{label: "来源ID", value: "terminal.advice.voice"}, {label: "数据项ID", value: "announcement"},
                {label: "用途", value: "voice"}, {label: "本机／队友字段许可", value: "由实际发送者与接收者的队伍配置共同限制；本页不代替共享授权", detail: true}]
    nodeDelegate: Component {
        OperatorCheckBox {
            required property int index
            readonly property var node: root.knownNodes[index] ?? ({})
            width: root.nodeDelegateWidth
            height: root.controlHeight
            font.family: root.fontFamily
            font.pixelSize: Math.max(root.inputSize, 9.5 / Math.max(0.1, hudScale))
            textColor: root.textColor
            text: (node.local ? "本机 " : "队友 ") + node.id + " / " + node.robot
            checked: (root.draft.listener_node_ids ?? []).indexOf(node.id) >= 0
            enabled: root.editable
            onToggled: root.setListener(node.id, checked)
        }
    }
    announcementDelegate: Component {
        OperatorDiagnosticTable {
            required property int index
            readonly property var item: root.activeAnnouncements[index] ?? ({})
            width: root.announcementDelegateWidth
            title: "当前协调中的语音请求"
            fontFamily: root.fontFamily
            titleColor: root.textColor
            titleSize: root.sectionTitleSize
            textColor: root.textColor
            mutedColor: root.secondaryTextColor
            separatorColor: root.separatorColor
            labelSize: root.noteSize
            valueSize: root.inputSize
            rows: [{label: "路径／来源节点", value: root.routeName(item.route) + " / " + root.shown(item.origin_node), detail: true},
                   {label: "来源会话", value: root.shown(item.origin_session), detail: true},
                   {label: "原请求／快照", value: root.shown(item.request_id) + " / " + root.shown(item.snapshot_id), detail: true},
                   {label: "剩余有效寿命", value: root.shown(item.remaining_ms) + " ms"},
                   {label: "实际播放", value: "此处仅表示协调请求；实际合成或音频输出由语音服务报告", detail: true}]
        }
    }
    Connections { target: root.saveControl; function onClicked() { root.save(); } }
    Connections { target: root.undoControl; function onClicked() { root.reload(); } }
    Connections { target: root.teamControl; function onTextEdited() { root.update("team_id", root.teamControl.text); } }
    Connections {
        target: root.robotControl
        function onActivated(index) { if (index >= 0 && index < root.robotChoices.length) root.update("robot_key", root.robotChoices[index]); }
    }
    Connections { target: root.localEnabledControl; function onToggled() { root.update("local_enabled", root.localEnabledControl.checked); } }
    Connections { target: root.teamEnabledControl; function onToggled() { root.update("team_enabled", root.teamEnabledControl.checked); } }
    Connections {
        target: root.priorityControl
        function onActivated(index) {
            const priorities = ["info", "caution", "urgent"];
            if (index >= 0 && index < priorities.length) root.update("minimum_priority", priorities[index]);
        }
    }
    Connections { target: root.speakerControl; function onTextEdited() { root.update("speaker_node_id", root.speakerControl.text); } }
    Connections {
        target: root.listenersControl
        function onTextChanged() {
            const values = root.listenersControl.text.split(/[\r\n]+/).map(value => value.trim()).filter(value => value.length > 0);
            if (JSON.stringify(values) !== JSON.stringify(root.draft.listener_node_ids ?? [])) root.update("listener_node_ids", values);
        }
    }
}
