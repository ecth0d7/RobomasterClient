import QtQuick
import "OperatorDecisionPolicy.js" as Policy
import "UiFormat.js" as Format

OperatorPanelFrame {
    id: root
    property var services: null
    property var telemetry: null
    property var preferences: null
    property var controller: null
    property var layoutState: null
    property int clientID: 3
    property bool previewOnly: false
    property var draft: Policy.defaults()
    property string feedback: ""
    property bool saveError: false
    property bool draftShown: true
    readonly property bool savedShown: layoutState?.current?.advice !== false
    readonly property bool setupOnly: services?.decisionSetupMode === "offline-preparation" && services?.decisionCapabilities?.setup_only === true
    readonly property bool preparationAllowed: previewOnly || controller?.editable === true
    readonly property bool validClientID: [1, 2, 3, 4, 5, 6, 7, 9, 101, 102, 103, 104, 105, 106, 107, 109].includes(clientID)
    readonly property var availableModels: Array.isArray(services?.decisionModels)
        ? services.decisionModels.filter(model => model.available === true)
        : []
    readonly property bool dirty: draftShown !== savedShown || JSON.stringify(Policy.clean(draft)) !== JSON.stringify(Policy.clean(preferences?.current))
    readonly property bool valid: typeof draft.modelId === "string" && draft.modelId.length <= 128
        && (!draft.autoAdvice || draft.modelId.trim().length > 0)
        && (!draft.shareEnabled || draft.shareFields.length > 0)
    signal layoutRequested
    signal servicesRequested
    signal inspectorRequested
    signal aggregationRequested
    signal providerRequested
    title: "模型与策略 · 本地配置"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1440
    height: 780
    onVisibleChanged: if (visible) reload()
    onClientIDChanged: reload()
    onControllerChanged: reload()
    function reload() { draft = Policy.clean(preferences?.current); draftShown = savedShown; feedback = ""; saveError = false; }
    Connections {
        target: root.preferences
        function onCurrentChanged() { root.reload(); }
    }
    Connections { target: root.layoutState; function onCurrentChanged() { root.reload(); } }
    Connections { target: root.controller; function onScopeChanged() { root.reload(); } }
    function setValue(key, value) {
        if (!preparationAllowed) return;
        draft = Object.assign({}, draft, {[key]: value}); feedback = ""; saveError = false;
    }
    function setField(key, enabled) {
        const fields = draft.shareFields.filter(value => value !== key);
        if (enabled) fields.push(key);
        setValue("shareFields", fields);
    }
    function setAiField(use, key, enabled) {
        if (use !== "localAiFields" && use !== "externalAiFields") return;
        const fields = draft[use].filter(value => value !== key);
        if (enabled) fields.push(key);
        setValue(use, fields);
    }
    function save() {
        // 保存仍由宿主检查配置范围、字段和服务生命周期。
        if (!preparationAllowed || !valid || !preferences) return;
        const showAdvice = draftShown;
        if (!preferences.save(draft)) { saveError = true; feedback = root.controller?.status || "未保存，请核对字段与锁定状态；当前草稿保留。"; return; }
        // 显示开关沿用组件库的唯一持久化字段，保留已有隐藏方案，不维护第二份布尔值。
        if (layoutState && savedShown !== showAdvice) layoutState.setShown("advice", showAdvice);
        feedback = previewOnly ? "已保存本窗口偏好 · 未切换模型、播报或共享"
            : root.controller?.status || "策略已保存；运行状态以宿主反馈为准。";
    }
    Rectangle {
        width: parent.width; height: 100; color: "#202a25"; border.color: root.preparationAllowed ? Theme.line : Theme.warning
        OperatorText { x: 14; y: 8; width: parent.width - 28; height: 26; text: root.previewOnly ? root.setupOnly ? "离线赛前准备 · 仅保存演示偏好" : "本地调试配置 · 可随时修改" : root.controller !== null ? root.controller.lockReason || "策略与输入授权 · 保存后由宿主应用" : "生产策略宿主未接通 · 设置只读"; size: 16; color: root.preparationAllowed ? Theme.text : Theme.warning }
        OperatorText { x: 14; y: 40; width: parent.width - 28; height: 24; text: "赛事服务器 → 官方选手端 → 本客户端；来源确认是操作手声明，不代表发布者已通过密码学认证。"; size: 12; color: Theme.muted }
        OperatorText { x: 14; y: 70; width: parent.width - 28; height: 22; text: Format.role(root.clientID) + " " + root.clientID + " · 本机队伍策略偏好 · " + (root.controller?.state?.automatic_status ?? root.controller?.status ?? "保存偏好不代表已启用生产服务"); textFormat: Text.PlainText; size: 11; color: Theme.muted }
    }
    Row {
        y: 116; width: parent.width; height: parent.height - y - 58; spacing: 22
        OperatorSection {
            width: (parent.width - 44) / 3; height: parent.height; title: "模型 / 策略 / 输入授权"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorText { width: parent.width; height: 26; text: "模型 ID · 可从目录选择或直接填写"; size: 12; color: Theme.muted }
                OperatorSelect { width: parent.width; label: "从端点目录选择模型"; emptyText: root.availableModels.length ? "可选择模型 ID" : "尚未取得模型目录"; enabled: root.preparationAllowed && root.availableModels.length > 0; model: root.availableModels.map(entry => entry.title); currentIndex: root.availableModels.findIndex(entry => entry.id === root.draft.modelId); onActivated: root.setValue("modelId", root.availableModels[currentIndex]?.id ?? "") }
                OperatorInput { width: parent.width; label: "明确的模型 ID"; placeholderText: "填写提供者支持的模型 ID"; enabled: root.preparationAllowed; maximumLength: 128; text: root.draft.modelId; onTextEdited: root.setValue("modelId", text) }
                OperatorText { width: parent.width; height: Math.max(72, implicitHeight + 8); text: "目录只提供可选择的 ID，不证明账号权限或推理已验收。保存时同步提供者的模型 ID，保持原有启停状态，不会自动启用提供者。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
                OperatorButton { width: parent.width; text: "提供者 / 连接配置"; onClicked: root.providerRequested() }
                OperatorText { width: parent.width; height: 26; text: "队伍策略 · 当前仅本机偏好"; size: 12; color: Theme.muted }
                OperatorSelect { width: parent.width; label: "本机队伍策略偏好"; enabled: root.preparationAllowed; model: Policy.teamStrategies.map(entry => entry.title); currentIndex: Policy.teamStrategies.findIndex(entry => entry.id === root.draft.teamStrategy); onActivated: root.setValue("teamStrategy", Policy.teamStrategies[currentIndex].id) }
                OperatorText { width: parent.width; height: Math.max(64, implicitHeight + 8); text: Policy.teamStrategies.find(entry => entry.id === root.draft.teamStrategy)?.detail ?? ""; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 12; color: Theme.muted }
                OperatorText { width: parent.width; height: 26; text: "当前角色任务 · 独立保存"; size: 12; color: Theme.muted }
                OperatorSelect { width: parent.width; label: "当前机器人角色策略"; enabled: root.preparationAllowed; model: Policy.roleStrategies.map(entry => entry.title); currentIndex: Policy.roleStrategies.findIndex(entry => entry.id === root.draft.roleStrategy); onActivated: root.setValue("roleStrategy", Policy.roleStrategies[currentIndex].id) }
                OperatorText { width: parent.width; height: Math.max(76, implicitHeight + 8); text: Policy.roleStrategies.find(entry => entry.id === root.draft.roleStrategy)?.detail ?? ""; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 12; color: Theme.muted }
                OperatorCheckBox { width: parent.width; visible: root.validClientID; text: "确认当前连接来自官方选手端导出"; enabled: root.preparationAllowed; checked: root.draft.playerSourceConfirmed; onToggled: root.setValue("playerSourceConfirmed", checked) }
                OperatorText { width: parent.width; height: Math.max(88, implicitHeight + 8); text: "确认针对当前 MQTT 地址、协议与机器人身份。仅声明已核对选手端导出，不等于密码学认证，也不允许直连赛事服务器。未确认时暂停自动建议。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
                OperatorText { width: parent.width; height: 26; text: "本机选手端遥测 → 本地模型"; size: 12; color: Theme.muted }
                Repeater {
                    model: Policy.aiFields
                    OperatorCheckBox { required property var modelData; width: parent.width; text: modelData.title; enabled: root.preparationAllowed; checked: root.draft.localAiFields.includes(modelData.id); onToggled: root.setAiField("localAiFields", modelData.id, checked) }
                }
                OperatorText { width: parent.width; height: 26; text: "本机选手端遥测 → 外部模型"; size: 12; color: Theme.muted }
                Repeater {
                    model: Policy.aiFields
                    OperatorCheckBox { required property var modelData; width: parent.width; text: modelData.title; enabled: root.preparationAllowed; checked: root.draft.externalAiFields.includes(modelData.id); onToggled: root.setAiField("externalAiFields", modelData.id, checked) }
                }
                OperatorText { width: parent.width; height: Math.max(112, implicitHeight + 8); text: "默认不授权。用途授权与队内共享分开；队友、传感器与视觉数据还须符合各自权限。运行在本机的 HTTP 或 Codex 进程不代表本地推理；无法证明完全本地时须满足外部授权。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
            }
        }
        OperatorSection {
            width: (parent.width - 44) / 3; height: parent.height; title: "HUD / 输入范围 / 自动建议 / 语音"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorCheckBox { width: parent.width; text: "在 HUD 显示有效建议"; enabled: root.preparationAllowed; checked: root.draftShown; onToggled: { if (root.preparationAllowed) { root.draftShown = checked; root.feedback = ""; } } }
                OperatorSelect { width: parent.width; label: "建议区域位置"; enabled: root.preparationAllowed && root.draftShown; model: ["赛场信息上方 · 默认", "右上信息区"]; currentIndex: root.draft.advicePosition === "right" ? 1 : 0; onActivated: root.setValue("advicePosition", currentIndex ? "right" : "race") }
                OperatorSelect { width: parent.width; label: "建议区域密度"; enabled: root.preparationAllowed && root.draftShown; model: ["紧凑 · 一行关键依据", "标准 · 展开关键依据"]; currentIndex: root.draft.adviceDensity === "standard" ? 1 : 0; onActivated: root.setValue("adviceDensity", currentIndex ? "standard" : "compact") }
                OperatorText { width: parent.width; height: Math.max(100, implicitHeight + 8); text: "仅新鲜且来源有效的建议出现；空白、加载、过期和未核验结果不占HUD卡片。默认在赛场信息上方；左侧操作卡展开时固定到右上备用区，不推挤其他控件。详情保留状态与完整依据。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
                OperatorText { width: parent.width; height: 24; text: "AI 输入范围"; size: 12; color: Theme.muted }
                OperatorSelect { width: parent.width; label: "AI 输入范围"; enabled: root.preparationAllowed; model: ["本机机器人数据", "队伍整合数据 · 可选插件"]; currentIndex: root.draft.inputMode === "team" ? 1 : 0; onActivated: root.setValue("inputMode", currentIndex ? "team" : "local") }
                OperatorSelect { visible: root.draft.inputMode === "team"; width: parent.width; label: "队伍视图不可用时"; enabled: root.preparationAllowed; model: ["暂停队伍建议 · 本机功能继续", "明确降级为本机数据建议"]; currentIndex: root.draft.teamFallback === "local" ? 1 : 0; onActivated: root.setValue("teamFallback", currentIndex ? "local" : "wait") }
                OperatorText { width: parent.width; height: Math.max(88, implicitHeight + 8); text: root.draft.inputMode === "team" ? "队伍汇总插件尚未接通；按上方选择暂停建议或明确降为本机输入。不会把实验室桥接的零散队友消息交给 AI。" : "使用已授权且新鲜的本机快照；无需等待队友或汇总插件。实际输入范围与排除原因由宿主记录。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
                OperatorCheckBox { width: parent.width; text: "自动生成建议"; enabled: root.preparationAllowed; checked: root.draft.autoAdvice; onToggled: root.setValue("autoAdvice", checked) }
                OperatorSelect { width: parent.width; label: "建议触发方式"; enabled: root.preparationAllowed && root.draft.autoAdvice; model: ["事件变化触发", "持续更新 · 合并节流"]; currentIndex: root.draft.trigger === "periodic" ? 1 : 0; onActivated: root.setValue("trigger", currentIndex ? "periodic" : "event") }
                OperatorText { width: parent.width; height: Math.max(80, implicitHeight + 8); text: root.previewOnly ? "离线绘制不发起请求。只使用新鲜输入；超时或失联隐藏建议。" : root.controller?.state?.automatic_status ?? "自动建议状态未提供；不从开关推断正在请求模型。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
                OperatorCheckBox { width: parent.width; text: "播报有效建议"; enabled: root.preparationAllowed; checked: root.draft.voiceEnabled; onToggled: root.setValue("voiceEnabled", checked) }
                OperatorSelect { width: parent.width; label: "最低播报等级"; enabled: root.preparationAllowed && root.draft.voiceEnabled; model: ["一般及以上", "注意及以上", "仅紧急"]; currentIndex: ["info", "caution", "urgent"].indexOf(root.draft.voicePriority); onActivated: root.setValue("voicePriority", ["info", "caution", "urgent"][currentIndex]) }
                OperatorSelect { width: parent.width; label: "谁收听建议"; enabled: root.preparationAllowed && root.draft.voiceEnabled; model: ["仅本机操作手", "队内已授权收听者"]; currentIndex: root.draft.voiceAudience === "team" ? 1 : 0; onActivated: root.setValue("voiceAudience", currentIndex ? "team" : "self") }
                OperatorSelect { width: parent.width; label: "谁负责播报"; enabled: root.preparationAllowed && root.draft.voiceEnabled; model: ["本机 · 不扩散", "队伍主操作手节点", "队伍指定播报节点"]; currentIndex: ["local", "leader", "designated"].indexOf(root.draft.voiceSpeaker); onActivated: root.setValue("voiceSpeaker", ["local", "leader", "designated"][currentIndex]) }
                OperatorText { width: parent.width; height: Math.max(102, implicitHeight + 8); text: "此处仅保存自动播报意向，自动播报尚未接通。队内接收者和指定节点仍待队伍认证、单一播报仲裁与建议 ID 去重，当前没有队内语音生产链路。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
            }
        }
        OperatorSection {
            width: (parent.width - 44) / 3; height: parent.height; title: "队内共享 · 必要字段"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorCheckBox { width: parent.width; text: "允许本角色队内共享"; enabled: root.preparationAllowed; checked: root.draft.shareEnabled; onToggled: root.setValue("shareEnabled", checked) }
                OperatorText { width: parent.width; height: Math.max(84, implicitHeight + 8); text: "队伍身份认证、字段白名单、建议分发和统一播报尚未接通。现有实验室原始快照桥接不能视为此功能。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.warning }
                Repeater {
                    model: Policy.shareFields
                    OperatorCheckBox { required property var modelData; width: parent.width; text: modelData.title; enabled: root.preparationAllowed && root.draft.shareEnabled; checked: root.draft.shareFields.includes(modelData.id); onToggled: root.setField(modelData.id, checked) }
                }
                OperatorButton { width: parent.width; text: "队伍汇总插件 / 来源查看"; onClicked: root.aggregationRequested() }
                OperatorText { width: parent.width; height: Math.max(114, implicitHeight + 8); text: "仅共享明确勾选且新鲜的必要字段。模型建议属于客户端策略数据，不能覆盖选手端权威遥测；不共享视频、自定义字节、密钥或完整模型输入。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
            }
        }
    }
    OperatorText { y: parent.height - 46; width: parent.width - 672; height: Math.max(46, implicitHeight + 8); text: root.feedback || (!root.preparationAllowed ? root.controller?.lockReason || "配置宿主不可用或正在保存，请稍后重试。" : !root.valid ? "自动建议须填写模型 ID；共享须勾选必要字段。" : root.dirty ? "有未保存的偏好；不会立即改变服务。" : root.controller?.status || "已保存偏好与生产运行状态分别显示。"); wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: root.saveError ? Theme.warning : root.feedback ? Theme.green : !root.valid ? Theme.warning : Theme.muted }
    Row {
        x: parent.width - 660; y: parent.height - 38; spacing: 12
        OperatorButton { width: 144; text: "撤销修改"; enabled: root.preparationAllowed && root.dirty; onClicked: root.reload() }
        OperatorButton { width: 144; text: root.previewOnly ? "保存演示偏好" : "保存本地偏好"; enabled: root.preparationAllowed && root.valid && root.dirty; primary: true; onClicked: root.save() }
        OperatorButton { width: 172; text: "建议 / 输入详情"; onClicked: root.inspectorRequested() }
        OperatorButton { width: 164; text: "返回面板库"; onClicked: root.layoutRequested() }
    }
}
