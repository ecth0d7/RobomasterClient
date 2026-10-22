import QtQuick
import "OperatorDecisionPolicy.js" as Policy
import "OperatorTeamAggregationData.js" as Team

OperatorPanelFrame {
    id: root
    property var services: null
    property var telemetry: null
    property var preferences: null
    property bool previewOnly: false
    property int clientID: 0
    property var discoveryDisplayView: ({active:[],markers:[],history:[],local_status:"本机生产投影未接通",team_status:"队伍生产投影未接通"})
    readonly property var discoveryRows: discoveryDisplayView.history.length > 0 ? discoveryDisplayView.history
        : Team.discoveries(view).map(item => Object.assign({},item,{display_reason:"旧原始记录，没有合格renderer投影",display_channel:"legacy"}))
    property var draft: Policy.defaults()
    property string feedback: ""
    property string selectedNode: ""
    property int detailTab: 0
    readonly property var details: services?.aggregationDetails ?? ({})
    readonly property var view: services?.aggregationView ?? ({})
    readonly property var members: Team.members(view)
    readonly property var selected: members.find(member => member.node_id === selectedNode) ?? members[0] ?? ({})
    readonly property var selectedFields: Team.fields(view, selected.node_id)
    readonly property bool hasView: typeof view.view_id === "string" && view.view_id.length > 0
    readonly property bool setupOnly: services?.decisionCapabilities?.setup_only === true && services?.decisionSetupMode === "offline-preparation"
    readonly property bool preparationAllowed: preferences?.runtime
        ? preferences.runtime.editable === true : previewOnly || setupOnly
    readonly property bool dirty: JSON.stringify(Policy.clean(draft)) !== JSON.stringify(Policy.clean(preferences?.current))
    signal decisionRequested
    signal layoutRequested
    signal teamSettingsRequested
    signal sourceSettingsRequested
    title: "队伍数据汇总 · 可选插件"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1440
    height: 780
    onVisibleChanged: if (visible) { reload(); if (inspection.contentItem) inspection.contentItem.contentY = 0; }
    Connections { target: root.preferences; function onCurrentChanged() { root.reload(); } }
    function reload() { draft = Policy.clean(preferences?.current); feedback = ""; }
    function setValue(key, value) {
        if (!preparationAllowed) return;
        draft = Object.assign({}, draft, {[key]: value}); feedback = "";
    }
    function save() {
        if (!preparationAllowed || !preferences || !dirty) return;
        // 和模型面板共用清理/保存边界；保存偏好不装载或启动生产插件。
        if (!preferences.save(draft)) { feedback = preferences?.runtime?.status || "未保存 · 策略字段或容量不合法"; return; }
        feedback = previewOnly ? "已保存演示偏好 · 未启动插件、共享、AI 或语音" : "已保存策略偏好 · 队伍网络在身份配置中独立启停；AI输入／发现投影仍待接通";
    }
    Rectangle {
        width: parent.width; height: 112; color: "#202a25"; border.color: Theme.line
        OperatorText { x: 14; y: 8; width: parent.width - 28; height: 26; text: root.services?.aggregationStatus ?? "生产端尚未接通 · 插件缺失时的本机隔离待宿主实现"; textFormat: Text.PlainText; size: 16; color: Theme.warning }
        OperatorText { x: 14; y: 41; width: parent.width - 228; height: 22; text: "赛事服务器 → 官方选手端 → 本客户端 → 可选队内汇总 → 完整数据视图 → AI"; size: 12 }
        OperatorButton { x: parent.width - 206; y: 37; width: 192; height: 30; text: "身份 / 用途配置"; onClicked: root.teamSettingsRequested() }
        OperatorText { x: 14; y: 72; width: parent.width - 228; height: Math.max(30, implicitHeight + 8); text: "本地感知 / 电控 / 视觉 → 数据源适配器 → 本客户端。单机无需汇总插件；各类来源分层，不能冒充官方数据。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
        OperatorButton { x: parent.width - 206; y: 72; width: 192; height: 30; text: "本地数据源配置"; onClicked: root.sourceSettingsRequested() }
    }
    Row {
        y: 128; width: parent.width; height: parent.height - y - 56; spacing: 18
        OperatorSection {
            width: 340; height: parent.height; title: "本地偏好 · 保存后应用"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorText { width: parent.width; height: Math.max(42, implicitHeight + 8); text: root.setupOnly ? "离线赛前准备 · 仅保存本地偏好" : "本地调试配置 · 可随时修改"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 12; color: root.preparationAllowed ? Theme.text : Theme.warning }
                OperatorCheckBox { width: parent.width; text: "允许使用队伍汇总 · 策略偏好"; enabled: root.preparationAllowed; checked: root.draft.aggregationEnabled; onToggled: root.setValue("aggregationEnabled", checked) }
                OperatorText { width: parent.width; height: Math.max(66, implicitHeight + 8); text: "可选队伍网络已与本机路径分开。缺失／失联／停用及跨设备行为仍待集中验收；队伍AI尚未接通。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.warning }
                OperatorText { width: parent.width; height: 24; text: "AI 请求输入范围"; size: 12; color: Theme.muted }
                OperatorSelect { width: parent.width; label: "汇总面板 AI 输入范围"; enabled: root.preparationAllowed; model: ["本机机器人数据", "队伍整合数据"]; currentIndex: root.draft.inputMode === "team" ? 1 : 0; onActivated: root.setValue("inputMode", currentIndex ? "team" : "local") }
                OperatorSelect { width: parent.width; label: "队伍视图不可用时"; enabled: root.preparationAllowed && root.draft.inputMode === "team"; model: ["暂停队伍建议 · 本机继续", "明确降级为本机建议"]; currentIndex: root.draft.teamFallback === "local" ? 1 : 0; onActivated: root.setValue("teamFallback", currentIndex ? "local" : "wait") }
                OperatorText { width: parent.width; height: Math.max(72, implicitHeight + 8); text: root.draft.inputMode === "local" ? "本机模式不等待成员或汇总视图。启用插件也不自动改为队伍输入。" : "只提交已发布的完整视图版本；缺必要字段时按明确的降级偏好处理，HUD 标注实际范围与原因。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
                OperatorText { width: parent.width; height: Math.max(92, implicitHeight + 8); text: "共享授权与接收汇总分别配置。开启插件不自动授权发送字段；队伍身份、节点和证书须明确配置，不能以机器人编号替代认证。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
                OperatorButton { width: parent.width; text: "模型 / 策略 / 共享字段"; onClicked: root.decisionRequested() }
            }
        }
        OperatorSection {
            width: 300; height: parent.height; title: "成员来源 · 原机器人保留"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorText { width: parent.width; height: Math.max(66, implicitHeight + 8); text: root.previewOnly ? "人工离线来源样例 · 不证明认证、汇总、心跳或网络工作。" : "仅显示宿主已发布视图；不会从实验室原始 peers 在 QML 中拼接。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.warning }
                OperatorText { visible: root.members.length === 0; width: parent.width; height: Math.max(68, implicitHeight + 8); text: "尚无完整视图的成员列表。本机路径无需等待这里出现成员。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 12; color: Theme.muted }
                Repeater {
                    model: root.members.length
                    Column {
                        required property int index
                        readonly property var modelData: root.members[index] ?? ({})
                        width: parent.width; spacing: 5
                        OperatorButton { width: parent.width; text: "机器人 " + Team.number(modelData.robot_id) + " · " + Team.state(modelData.state); primary: modelData.node_id === root.selected.node_id; onClicked: root.selectedNode = modelData.node_id }
                        OperatorText { width: parent.width; height: 24; text: Team.text(modelData.node_id); textFormat: Text.PlainText; size: 11; color: Theme.muted }
                        OperatorText { width: parent.width; height: 24; text: "接收年龄 " + Team.number(modelData.age_ms, " ms") + " · " + Team.text(modelData.auth); textFormat: Text.PlainText; size: 10; color: Theme.muted }
                    }
                }
                OperatorText { width: parent.width; height: Math.max(82, implicitHeight + 8); text: "心跳只标记节点在线，不刷新其字段。旧值、重复、迟到、冲突和未认证来源须逐项排除。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
            }
        }
        OperatorSection {
            width: parent.width - 676; height: parent.height; title: "先发布整合视图，再提供 AI 输入"
            Row {
                width: parent.width; spacing: 8
                Repeater {
                    model: ["完整视图", "字段出处", "排除记录", "发现 / 视觉"]
                    OperatorButton { required property int index; required property string modelData; width: (parent.width - 24) / 4; text: modelData; primary: root.detailTab === index; onClicked: { root.detailTab = index; inspection.contentItem.contentY = 0; } }
                }
            }
            OperatorScrollableColumn {
                id: inspection
                objectName: "discoveryInspectionScroll"
                y: 52; width: parent.width; height: parent.height - y
                OperatorText { visible: !root.hasView && root.detailTab !== 3; width: parent.width; height: Math.max(116, implicitHeight + 8); text: "尚未发布整合视图。\n零散队友包不直接进入模型；插件不可用时按已保存的范围 / 降级偏好处理。本机数据和操作继续。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 13; color: Theme.muted }
                OperatorDiagnosticTable {
                    visible: root.detailTab === 0 && root.hasView; width: parent.width; title: "不可变视图标识与发布来源"
                    rows: [
                        {label: "视图 / 版本", value: Team.text(root.view.view_id) + " / " + Team.number(root.view.revision), detail: true},
                        {label: "发布节点 / 代次", value: Team.text(root.view.issuer_id) + " / " + Team.text(root.view.epoch), detail: true},
                        {label: "队伍 / 比赛", value: Team.text(root.view.team_id) + " / " + Team.text(root.view.match_id), detail: true},
                        {label: "宿主核验", value: root.previewOnly ? "人工离线样例 · 非认证输入" : root.view.verified === true ? "宿主已核验 · 字段依赖仍需独立有效" : "未核验 · 不作为队伍模型输入", detail: true},
                        {label: "接收年龄 / 剩余有效期", value: Team.number(root.view.received_age_ms, " ms") + " / " + Team.number(root.view.remaining_ms, " ms"), detail: true},
                        {label: "生成时间 · UTC 毫秒", value: Team.number(root.view.generated_at_ms), detail: true}
                    ]
                }
                OperatorDiagnosticTable {
                    visible: root.detailTab === 1 && root.hasView; width: parent.width; title: "当前成员 · 追溯到选手端导出"
                    rows: [
                        {label: "原机器人 / 客户端", value: Team.number(root.selected.robot_id) + " / " + Team.text(root.selected.node_id)},
                        {label: "官方选手端导出标识", value: Team.text(root.selected.player_export_id)},
                        {label: "原始输入快照", value: Team.text(root.selected.snapshot_id)}
                    ]
                }
                Repeater {
                    model: root.detailTab === 1 ? root.selectedFields.length : 0
                    OperatorDiagnosticTable {
                        required property int index
                        readonly property var modelData: root.selectedFields[index] ?? ({})
                        width: parent.width; title: modelData.path
                        rows: [
                            {label: "值 / 字段状态", value: Team.value(modelData) + " / " + Team.state(modelData.state), detail: true},
                            {label: "数据类型 / 生命周期", value: Team.text(modelData.data_type) + " / " + Team.lifecycle(modelData.lifecycle), detail: true},
                            {label: "置信度 / 核验", value: Team.confidence(modelData.confidence) + " / " + Team.text(modelData.verification), detail: true},
                            {label: "原客户端接收时间 · UTC 毫秒", value: Team.number(modelData.received_at_ms), detail: true},
                            {label: "来源类别 / 当前用途", value: Team.kind(modelData.kind) + " / " + (modelData.accepted === true ? "模块期限内 · 仅诊断，尚未接AI" : "排除"), detail: true},
                            {label: "原选手端 / 源快照 / 字段版本", value: Team.text(modelData.player_export_id) + " / " + Team.text(modelData.snapshot_id) + " / " + Team.number(modelData.field_revision), detail: true},
                            {label: "源观测时间 · UTC 毫秒", value: Team.number(modelData.origin_observed_at_ms), detail: true},
                            {label: "接收年龄 / 独立剩余时效", value: Team.number(modelData.received_age_ms, " ms") + " / " + Team.number(modelData.remaining_ms, " ms"), detail: true},
                            {label: "可信等级", value: Team.text(modelData.trust), detail: true}
                        ]
                    }
                }
                OperatorText { visible: root.detailTab === 1 && root.hasView && root.selectedFields.length === 0; width: parent.width; height: Math.max(64, implicitHeight + 8); text: "该成员没有纳入视图的字段。缺失不会填成 0 或 false。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 12; color: Theme.muted }
                Repeater {
                    model: root.detailTab === 2 ? Team.exclusions(root.view) : []
                    OperatorDiagnosticTable { required property var modelData; width: parent.width; title: modelData.path; rows: [{label: "原来源", value: Team.text(modelData.source_node), detail: true}, {label: "排除原因", value: Team.text(modelData.reason), detail: true}] }
                }
                OperatorFieldMap {
                    id:discoveryInspectionMap
                    objectName:"discoveryInspectionMap"
                    visible: root.detailTab === 3
                    width: parent.width; height: 210; compact: true
                    telemetry: root.telemetry
                    clientID: root.clientID
                    discoveryMarkers: root.discoveryDisplayView.markers
                    previewOnly: root.previewOnly
                }
                OperatorText { visible: root.detailTab === 3; width: parent.width; height: Math.max(88, implicitHeight + 8); text: (root.previewOnly ? "离线mock · 非真实传感器。" : "独立发现不等于官方雷达目标。")
                    + "本机：" + (root.discoveryDisplayView.local_status || "显示源可用") + "；队伍：" + (root.discoveryDisplayView.team_status || "显示源可用")
                    + (discoveryInspectionMap.discoveryLabelsHidden ? "。地图标签 "+discoveryInspectionMap.discoveryLabelCount+"/"+root.discoveryDisplayView.markers.length+"；未排下的标签仍可在下方查看" : "。细线连接真实坐标，标签位置只作阅读")
                    + "。未标定坐标不落图；到期、撤回和冲突保留以下检查记录，不占活动告警。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.warning }
                Repeater {
                    model: root.detailTab === 3 ? root.discoveryRows.length : 0
                    OperatorDiagnosticTable {
                        required property int index
                        readonly property var modelData: root.discoveryRows[index] ?? ({})
                        width: parent.width; title: modelData.summary
                        rows: [
                            {label: "HUD / 地图检查", value: (modelData.display_reason || "HUD有效") + " / " + (modelData.map_reason === "" ? "地图有效" : modelData.map_reason || "未发布可用标记"), detail: true},
                            {label: "观察摘要", value: Team.text(modelData.summary), detail: true},
                            {label: "显示通道 / 完整视图", value: Team.text(modelData.display_channel) + " / " + Team.text(modelData.display_view_id) + " / v" + Team.number(modelData.display_view_revision), detail: true},
                            {label: "原类型 / 原生命周期", value: Team.text(modelData.data_type) + " / " + Team.text(modelData.lifecycle), detail: true},
                            {label: "来源机器人 / 客户端 / 传感器", value: Team.number(modelData.source_robot) + " / " + Team.text(modelData.source_node) + " / " + Team.text(modelData.sensor_id), detail: true},
                            {label: "来源类别 / 置信度", value: Team.kind(modelData.source_kind) + " / " + Team.confidence(modelData.confidence), detail: true},
                            {label: "源身份 / 测量核验", value: Team.text(modelData.validation) + " / " + Team.text(modelData.measurement_validation), detail: true},
                            {label: "观测 / 源会话 / 版本", value: Team.text(modelData.item_id) + " / " + Team.text(modelData.source_session_id) + " / " + Team.number(modelData.revision), detail: true},
                            {label: "原产生时刻 / 原时钟域", value: Team.number(modelData.source_time_ms) + " / " + Team.text(modelData.source_clock_domain), detail: true},
                            {label: "宿主接收时间 · UTC 毫秒", value: Team.number(modelData.received_at_ms), detail: true},
                            {label: "宿主映射产生时间 · UTC 毫秒", value: Team.number(modelData.produced_at_ms), detail: true},
                            {label: "源龄 / 接收龄 / 剩余有效期", value: Team.number(modelData.source_age_ms, " ms") + " / " + Team.number(modelData.receive_age_ms," ms") + " / " + Team.number(modelData.display_remaining_ms, " ms"), detail: true},
                            {label: "TTL / 新鲜窗口 · ms", value: Team.number(modelData.ttl_ms) + " / " + Team.number(modelData.fresh_for_ms), detail: true},
                            {label: "原坐标系 / 帧版本 / 单位", value: Team.text(modelData.frame_id) + " / " + Team.text(modelData.frame_revision) + " / " + Team.text(modelData.unit), detail: true},
                            {label: "地图变换 / 标定版本", value: Team.text(modelData.map_projection?.transform_id) + " / " + Team.text(modelData.map_projection?.transform_revision), detail: true},
                            {label: "原选手端 / 生产者版本", value: Team.text(modelData.player_export_id) + " / " + Team.text(modelData.producer_version), detail: true},
                            {label: "推导算法 / 原依赖", value: Team.text(modelData.algorithm_id) + " / " + (Array.isArray(modelData.dependencies) ? modelData.dependencies.slice(0,16).join(", ") : "未提供"), detail: true},
                            {label: "撤回与动作边界", value: "按 item_id / 源版本撤回；低置信或未核验发现不驱动机器人动作。", detail: true}
                        ]
                    }
                }
                OperatorText { width: parent.width; height: Math.max(90, implicitHeight + 8); text: "权威来源转述与推导值分层。聚合发布不提升信任；建议绑定视图版本与字段依赖，统一语音按建议 / 输出组去重。生产验证仍待全部 UI 完成。"; wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: Theme.muted }
            }
        }
    }
    OperatorText { y: parent.height - 46; width: parent.width - 508; height: Math.max(46, implicitHeight + 8); text: root.feedback || (root.dirty ? "有未保存的偏好 · 不会立即改变服务" : "保存偏好 ≠ 插件已启用；运行状态与原始桥接独立。密钥不保存在此界面。"); wrapMode: Text.WordWrap; elide: Text.ElideNone; size: 11; color: root.feedback ? Theme.warning : Theme.muted }
    Row {
        x: parent.width - 496; y: parent.height - 38; spacing: 12
        OperatorButton { width: 144; text: "撤销修改"; enabled: root.preparationAllowed && root.dirty; onClicked: root.reload() }
        OperatorButton { width: 164; text: root.previewOnly ? "保存演示偏好" : "保存本地偏好"; primary: true; enabled: root.preparationAllowed && root.dirty; onClicked: root.save() }
        OperatorButton { width: 164; text: "返回面板库"; onClicked: root.layoutRequested() }
    }
}
