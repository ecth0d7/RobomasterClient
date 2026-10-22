import QtQuick
import "OperatorSourcePolicy.js" as Policy
import "UiFormat.js" as Identity

OperatorPanelFrame {
    id: root
    property var preferences: null
    property var runtime: null
    property var telemetry: null
    property var connection: null
    property bool setupOnly: false
    property bool previewOnly: false
    property int clientID: 0
    property int page: 0
    property var draft: Policy.defaults()
    property var sourceDraft: Policy.sourceDefaults()
    property int selectedSource: -1
    property string feedback: ""
    readonly property bool cold: clientID === 0 && connection?.connected !== true && connection?.connecting !== true
    readonly property bool editable: typeof runtime?.editable === "boolean" ? runtime.editable
        : previewOnly || cold || setupOnly
    readonly property string sourceIssue: Policy.sourceError(sourceDraft, draft.sources.filter((_, index) => index !== selectedSource))
    readonly property var issues: Policy.problems(draft)
    readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(preferences?.current)
    readonly property bool sourceDirty: JSON.stringify(sourceDraft) !== JSON.stringify(selectedSource >= 0 ? draft.sources[selectedSource] : Policy.sourceDefaults())
    readonly property var adapters: Array.isArray(runtime?.adapters) ? runtime.adapters : []
    readonly property var actualSources: Array.isArray(runtime?.sources) ? runtime.sources : []
    readonly property var actualItems: Array.isArray(runtime?.localView?.items) ? runtime.localView.items : []
    signal aggregationRequested
    signal teamSettingsRequested
    signal adapterInspectRequested(string id)
    title: "本地数据源 · 传感器 / 电控 / 视觉"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1440
    height: 780
    onVisibleChanged: if (visible) reload()
    onClientIDChanged: reload()
    Connections { target: root.preferences; function onCurrentChanged() { root.reload(); } }
    function reload() { draft = Policy.clean(preferences?.current); selectedSource = -1; sourceDraft = Policy.sourceDefaults(); feedback = ""; }
    function selectSource(index) { selectedSource = index; sourceDraft = index >= 0 ? Policy.cleanSource(draft.sources[index]) : Policy.sourceDefaults(); feedback = ""; }
    function setValue(key, value) {
        if (!editable || !Object.prototype.hasOwnProperty.call(Policy.sourceDefaults(), key)) return;
        sourceDraft = Object.assign({}, sourceDraft, {[key]: value}); feedback = "";
    }
    function setUse(key, allowed) {
        const next = Object.assign({}, sourceDraft.uses);
        if (allowed) next[key] = true; else delete next[key];
        setValue("uses", next);
    }
    function keepSource() {
        if (!editable || sourceIssue || selectedSource < 0 && draft.sources.length >= 16) return;
        const sources = draft.sources.slice(), value = Policy.cleanSource(sourceDraft);
        const index = selectedSource < 0 ? sources.length : selectedSource;
        if (selectedSource < 0) sources.push(value); else sources[selectedSource] = value;
        draft = {sources: sources}; selectedSource = index;
        feedback = "来源已保留到未保存草稿 · 未打开设备、进程或网络";
    }
    function removeSource() {
        if (!editable || selectedSource < 0) return;
        draft = {sources: draft.sources.filter((_, index) => index !== selectedSource)};
        selectSource(-1); feedback = "仅移除来源草稿 · 没有撤回运行中的数据";
    }
    function saveDraft() {
        if (!editable || sourceDirty || issues.length || !preferences) return;
        const selectedId = selectedSource >= 0 ? draft.sources[selectedSource].id : "";
        if (!preferences.save(draft)) { feedback = "草稿无效或容量不足，未保存。"; return; }
        if (selectedId) selectSource(draft.sources.findIndex(source => source.id === selectedId));
        feedback = previewOnly ? "本窗口来源草稿已保存 · 没有启动真实源或模型" : "本地UI草稿已保存 · 宿主来源簿已接，设备配置启用仍待接通";
    }
    Rectangle {
        width: parent.width; height: 92; color: Theme.hudSurface
        OperatorOutline { color: root.editable ? Theme.hudBorder : Theme.warning }
        OperatorText { x: 14; y: 8; width: parent.width - 28; height: 26; text: !root.editable && root.runtime?.lockReason ? root.runtime.lockReason : root.cold ? "尚未选身份 · 仅准备来源草稿" : root.setupOnly ? "仅准备配置 · 不开启比赛控制" : "本地调试配置 · 可随时修改"; size: 15; color: root.editable ? Theme.text : Theme.warning }
        OperatorText { x: 14; y: 38; width: parent.width - 28; height: 22; text: root.runtime?.status ?? "数据源运行状态未公开 · 不从配置推断已接传感器或视觉"; size: 12; color: root.runtime?.health === "rejected" || root.runtime?.health === "stale" ? Theme.warning : Theme.muted }
        OperatorText { x: 14; y: 64; width: parent.width - 28; height: 22; text: "本地发现独立于官方遥测 · 缺少插件不阻塞选手端 / HUD · 模拟源始终标记 mock"; size: 11; color: Theme.muted }
    }
    Row {
        y: 108; spacing: 12; width: parent.width
        Repeater { model: ["来源 / 适配器", "数据 / 用途", "坐标 / 生命周期", "实际源状态"]; OperatorButton { required property string modelData; required property int index; width: (parent.width - 36) / 4; text: modelData; primary: root.page === index; onClicked: root.page = index } }
    }
    Row {
        y: 162; width: parent.width; height: parent.height - y - 72; spacing: 22; visible: root.page < 3
        OperatorSection {
            width: 410; height: parent.height; title: "来源列表 · 本机 " + (root.clientID || "未选择")
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorButton { width: parent.width; text: "新增来源草稿"; enabled: root.editable && root.draft.sources.length < 16; onClicked: root.selectSource(-1) }
                Repeater {
                    model: root.draft.sources.length
                    OperatorButton { required property int index; readonly property var source: root.draft.sources[index]; width: parent.width; height: 74; text: (source.label || source.id) + "\n" + source.id + (source.transport === "mock" ? " · mock" : " · " + (source.enabled ? "启用意向" : "关闭意向")); primary: root.selectedSource === index; Accessible.name: "编辑来源草稿 " + source.id; onClicked: root.selectSource(index) }
                }
                OperatorText { width: parent.width; height: Math.max(98, implicitHeight + 8); text: "此处只保存来源草稿。官方字段来自既有选手端协议；本地传感器、视觉和推导不能写成 official_player_client。"; size: 11; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorText { width: parent.width; height: Math.max(94, implicitHeight + 8); text: "先保留所选来源，再保存列表。切换来源会丢弃未保留编辑；修改配置不续期样本，也不构成实际数据撤回。"; size: 11; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorButton { width: parent.width; text: "移除所选来源草稿"; enabled: root.editable && root.selectedSource >= 0; onClicked: root.removeSource() }
            }
        }
        OperatorSection {
            width: parent.width - 432; height: parent.height; title: root.page === 0 ? "连接声明 · 不自动启动" : root.page === 1 ? "有类型的数据与独立用途" : "空间转换与时效约束"
            OperatorScrollableColumn {
                anchors.fill: parent; visible: root.page === 0
                OperatorCheckBox { width: parent.width; text: "下次允许启用此来源"; enabled: root.editable; checked: root.sourceDraft.enabled; onToggled: root.setValue("enabled", checked) }
                Row {
                    width: parent.width; spacing: 16
                    OperatorStartupField { width: (parent.width - 16) / 2; label: "来源ID"; value: root.sourceDraft.id; editable: root.editable; hint: "本机器人内唯一；不替代发送节点身份。"; onValueEdited: value => root.setValue("id", value) }
                    OperatorStartupField { width: (parent.width - 16) / 2; label: "可见名称"; value: root.sourceDraft.label; editable: root.editable; hint: "仅显示名称；不改变可信等级。"; onValueEdited: value => root.setValue("label", value) }
                }
                OperatorSelect { width: parent.width; label: "数据来源类型"; enabled: root.editable; model: Policy.kinds.map(item => item.title); currentIndex: Policy.kinds.findIndex(item => item.id === root.sourceDraft.kind); onActivated: root.setValue("kind", Policy.kinds[currentIndex].id) }
                OperatorStartupField { width: parent.width; label: "传感器 / 电控板 / 算法源ID"; value: root.sourceDraft.sensorId; editable: root.editable; hint: "原机器人 " + Identity.role(root.clientID) + " · " + (root.clientID || "未选择") + "；共享保持原来源，不改成转发者。"; onValueEdited: value => root.setValue("sensorId", value) }
                OperatorSelect { width: parent.width; label: "承载通道"; enabled: root.editable; model: Policy.transports.map(item => item.title); currentIndex: Policy.transports.findIndex(item => item.id === root.sourceDraft.transport); onActivated: root.setValue("transport", Policy.transports[currentIndex].id) }
                OperatorStartupField { width: parent.width; label: "适配器ID"; value: root.sourceDraft.adapterId; editable: root.editable; hint: root.adapters.length ? "宿主公开候选：" + root.adapters.map(item => item.id).join("、") : "宿主未公开可用适配器；文本草稿不等于插件已安装。"; onValueEdited: value => root.setValue("adapterId", value) }
                OperatorStartupField { width: parent.width; label: "适配器端点 / 相对路径"; value: root.sourceDraft.endpoint; editable: root.editable && root.sourceDraft.transport !== "player_private_bytes"; hint: root.sourceDraft.transport === "player_private_bytes" ? "经官方选手端的既有 CustomByteBlock；载荷语义仍是私有来源。" : "由适配器核验协议与部署权限；不填口令，不执行任意命令。"; onValueEdited: value => root.setValue("endpoint", value) }
                OperatorButton { width: parent.width; text: "检查适配器契约 · " + (root.runtime?.capabilities?.inspectAdapter === true ? "可用" : "待接通"); enabled: root.editable && root.runtime?.capabilities?.inspectAdapter === true && !!root.sourceDraft.adapterId; onClicked: root.adapterInspectRequested(root.sourceDraft.adapterId) }
            }
            OperatorScrollableColumn {
                anchors.fill: parent; visible: root.page === 1
                Row {
                    width: parent.width; spacing: 16
                    OperatorStartupField { width: (parent.width - 16) / 2; label: "私有载荷 Schema ID"; value: root.sourceDraft.schemaId; editable: root.editable; hint: "版本由电控 / 视觉协议确认，不是伪官方 topic。"; onValueEdited: value => root.setValue("schemaId", value) }
                    OperatorStartupField { width: (parent.width - 16) / 2; label: "Schema 版本"; value: root.sourceDraft.schemaVersion; editable: root.editable; hint: "版本不匹配应拒绝，不猜测解码。"; onValueEdited: value => root.setValue("schemaVersion", value) }
                }
                Row {
                    width: parent.width; spacing: 16
                    OperatorStartupField { width: (parent.width - 16) / 2; label: "数据类型ID"; value: root.sourceDraft.itemType; editable: root.editable; hint: "例如目标观察 / 事件；实际结构由适配器声明。"; onValueEdited: value => root.setValue("itemType", value) }
                    OperatorStartupField { width: (parent.width - 16) / 2; label: "数据单位"; value: root.sourceDraft.unit; editable: root.editable; hint: "m / cm / px / dimensionless 等必须明确。"; onValueEdited: value => root.setValue("unit", value) }
                }
                OperatorStartupField { width: parent.width; label: "置信度语义 / 验证说明"; value: root.sourceDraft.confidenceDefinition; editable: root.editable; hint: "说明算法分数含义；不是给每个样本统一填写固定可信度。身份核验与测量验证分开。"; onValueEdited: value => root.setValue("confidenceDefinition", value) }
                Repeater { model: Policy.uses; OperatorCheckBox { required property var modelData; width: parent.width; text: modelData.title; enabled: root.editable; checked: root.sourceDraft.uses[modelData.id] === true; onToggled: root.setUse(modelData.id, checked) } }
                OperatorText { width: parent.width; height: Math.max(80, implicitHeight + 8); text: "全部用途默认关闭。共享还须可信成员 / 类别 / 用途授权；本机或队伍输入范围与本地或外部模型是独立选择。两种范围都先校验数据视图；原始视频、任意bytes和控制命令不自动发送。"; size: 11; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
            OperatorScrollableColumn {
                anchors.fill: parent; visible: root.page === 2
                Row {
                    width: parent.width; spacing: 16
                    OperatorStartupField { width: (parent.width - 16) / 2; label: "最大有效期 · ms"; value: root.sourceDraft.ttlMs; editable: root.editable; error: root.sourceDirty ? Policy.lifetimeError(root.sourceDraft.ttlMs) : ""; hint: "100–60000；产品初值，非官方协议固定TTL。"; onValueEdited: value => root.setValue("ttlMs", value) }
                    OperatorStartupField { width: (parent.width - 16) / 2; label: "产生时间的时钟域ID"; value: root.sourceDraft.clockDomain; editable: root.editable; hint: "未知时钟映射不能冒充新鲜；接收时间另存。"; onValueEdited: value => root.setValue("clockDomain", value) }
                }
                OperatorCheckBox { width: parent.width; text: "此来源包含空间项 / 图像标注"; enabled: root.editable; checked: root.sourceDraft.spatial; onToggled: root.setValue("spatial", checked) }
                Row {
                    width: parent.width; spacing: 16
                    OperatorStartupField { width: (parent.width - 16) / 2; label: "原坐标系ID"; value: root.sourceDraft.frameId; editable: root.editable && root.sourceDraft.spatial; hint: "原点 / 轴向 / 单位由适配器声明；不直接当赛场坐标。"; onValueEdited: value => root.setValue("frameId", value) }
                    OperatorStartupField { width: (parent.width - 16) / 2; label: "坐标 / 标定版本"; value: root.sourceDraft.frameRevision; editable: root.editable && root.sourceDraft.spatial; hint: "版本变化使旧投影失效；不能沿用旧变换。"; onValueEdited: value => root.setValue("frameRevision", value) }
                }
                OperatorStartupField { width: parent.width; label: "经过核验的转换ID · 可为空"; value: root.sourceDraft.transformId; editable: root.editable && root.sourceDraft.spatial; hint: "为空或未核验：保留有来源的事件 / 提示，禁用地图投影；不猜测标定。"; onValueEdited: value => root.setValue("transformId", value) }
                OperatorText { width: parent.width; height: Math.max(90, implicitHeight + 8); text: "每个项须独立携带产生 / 接收时间、序号、原发送源、置信度 / 验证、寿命和撤回状态。重复、迟到、未来时间、断连或撤回不能续期；推导须声明依赖并随依赖失效。"; size: 11; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorText { width: parent.width; height: Math.max(66, implicitHeight + 8); text: "宿主转换后提供现有2D地图标记；来源模型不依赖渲染器。UE接口后续独立插件接入，当前未引入UE或3D场景。"; size: 11; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
    }
    Row {
        y: 162; width: parent.width; height: parent.height - y - 72; spacing: 22; visible: root.page === 3
        OperatorSection {
            width: 410; height: parent.height; title: "宿主公开的实际源 · 不使用草稿补值"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorText { width: parent.width; height: Math.max(60, implicitHeight + 8); text: root.runtime?.mock === true ? "离线 mock 状态绘制 · 非设备验证" : root.runtime ? "宿主状态 · 按来源逐项核验" : "未接通数据源运行截面"; size: 13; color: root.runtime?.mock === true ? Theme.warning : Theme.text; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorText { width: parent.width; height: Math.max(68, implicitHeight + 8); text: root.runtime?.teamExportStatus ?? "队伍导出状态尚未公开"; size: 11; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                Repeater { model: root.actualSources; OperatorText { required property var modelData; width: parent.width; height: Math.max(80, implicitHeight + 8); text: modelData.id + "\n" + modelData.source_kind + " · 机器人 " + modelData.robot_id + "\n" + Policy.stateTitle(modelData.state); size: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone } }
                OperatorText { width: parent.width; height: Math.max(100, implicitHeight + 8); text: root.actualSources.length ? "不同源的失联不阻塞其他本机源。官方字段仍走选手端；本地发现没有被提升为官方权威状态。" : "未公开来源不表示机器人没有传感器；也不以配置中写了ID证明设备在线。"; size: 11; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
        OperatorSection {
            width: parent.width - 432; height: parent.height; title: "样本溯源 / 时效 / 投影状态"
            OperatorScrollableColumn {
                anchors.fill: parent
                Repeater {
                    model: root.actualSources
                    Column {
                        required property var modelData
                        width: parent.width; spacing: 12
                        Repeater {
                            model: [
                                "来源：" + modelData.id + " / " + modelData.sensor_id + " · " + modelData.source_kind,
                                "适配器：" + modelData.adapter_id + " @ " + modelData.adapter_version,
                                "类型 / 单位：" + modelData.item_type + " / " + modelData.unit,
                                "产生时间：" + (modelData.generated_at ?? "未提供"), "接收时间：" + (modelData.received_at ?? "未提供"),
                                "宿主样本年龄：" + (Number.isFinite(modelData.age_ms) ? modelData.age_ms + " ms" : "未知") + " · 剩余寿命 " + (Number.isFinite(modelData.remaining_ms) ? modelData.remaining_ms + " ms" : "未知"),
                                "置信度 / 验证：" + (Number.isFinite(modelData.confidence) ? modelData.confidence : "未知") + " / " + (modelData.verification ?? "未核验"),
                                "坐标系：" + (modelData.frame_id ?? "无空间项") + " @ " + (modelData.frame_revision ?? "未提供"),
                                "投影：" + (modelData.projection ?? "未提供可落图结果"), "用途：" + (modelData.uses ?? "未提供"),
                                "拒绝 / 撤回依据：" + (modelData.rejection || "没有公开记录")
                            ]
                            OperatorText { required property string modelData; width: parent.width; height: Math.max(34, implicitHeight + 8); text: modelData; size: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                        }
                    }
                }
                Repeater {
                    model: root.actualItems
                    Column {
                        required property var modelData
                        readonly property var sample: modelData.item
                        width: parent.width; spacing: 4
                        OperatorText { width: parent.width; height: 28; text: parent.modelData.source_id + " · " + parent.sample.path; size: 12; color: Theme.text; elide: Text.ElideMiddle }
                        OperatorText { width: parent.width; height: 28; text: (parent.sample.data_type === "discovery" ? parent.sample.value.summary : String(parent.sample.value)) + " · " + Policy.stateTitle(parent.modelData.state) + " · " + parent.modelData.remaining_ms + " ms"; size: 12; color: parent.modelData.state === "fresh" ? Theme.text : Theme.warning }
                        OperatorText { width: parent.width; height: 48; text: "原源时间 " + (parent.sample.source_time_ms ?? "未知") + " / 接收 " + parent.sample.received_at_ms + " · " + parent.sample.measurement_validation + "\n用途 " + parent.sample.allowed_uses.join(" / ") + " · 不作为设备执行回执"; size: 10; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    }
                }
                OperatorText { width: parent.width; height: 80; visible: !root.actualItems.length; text: root.runtime?.capabilities?.registry === true ? "宿主来源簿已接通，当前没有合格样本。先确认官方选手端来源与必要用途；设备／IPC／视觉适配器仍未接入。" : "没有宿主样本。生产适配器、数据源注册与逐项生命周期仍待接通；不绘制伪造目标或实时数值。"; size: 12; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
    }
    Item {
        y: parent.height - 62; width: parent.width; height: 62
        OperatorText { width: parent.width - 574; height: 24; text: root.feedback || (root.sourceDirty && root.sourceIssue && root.page < 3 ? root.sourceIssue : root.sourceDirty ? "所选来源尚未保留 · 先保留来源，再保存列表" : root.issues[0] || (root.dirty ? "列表草稿未保存 · 实际源与样本没有变化" : "UI草稿独立保存 · 设备启用 / AI / 地图投影仍待接入")); size: 11; color: root.sourceDirty || root.issues.length ? Theme.warning : Theme.muted; elide: Text.ElideRight }
        OperatorText { y: 28; width: parent.width - 574; height: 24; text: "先保留当前来源，再保存列表 · 不启动机器人动作 / 模型请求 / 队内发送"; size: 11; color: Theme.muted }
        Row {
            x: parent.width - width; y: 22; spacing: 12
            OperatorButton { width: 146; text: "保留所选来源"; visible: root.page < 3; enabled: root.editable && !root.sourceIssue && root.sourceDirty; onClicked: root.keepSource() }
            OperatorButton { width: 136; text: "保存列表草稿"; primary: true; enabled: root.editable && !root.sourceDirty && !root.issues.length && root.dirty; onClicked: root.saveDraft() }
            OperatorButton { width: 118; text: "队伍权限"; onClicked: root.teamSettingsRequested() }
            OperatorButton { width: 118; text: "汇总视图"; onClicked: root.aggregationRequested() }
        }
    }
}
