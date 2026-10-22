import QtQuick
import "OperatorTeamConfigPolicy.js" as Policy
import "UiFormat.js" as Identity

OperatorPanelFrame {
    id: root
    property var preferences: null
    property var decisionPreferences: null
    property var runtime: null
    property var telemetry: null
    property var connection: null
    property bool setupOnly: false
    property int clientID: 0
    property bool previewOnly: false
    property int page: 0
    property var draft: Policy.defaults()
    property var peerDraft: Policy.peerDefaults()
    property int selectedPeer: -1
    property string feedback: ""
    property bool feedbackFailure: false
    readonly property var controller: preferences?.hostConfiguration ?? null
    readonly property var runtimeState: runtime ?? controller?.state ?? ({})
    readonly property bool cold: clientID === 0 && connection?.connected !== true && connection?.connecting !== true
    readonly property bool editable: controller !== null ? controller.editable === true
        : previewOnly
    readonly property string editingStatus: controller !== null ? controller.lockReason || (editable ? "队伍配置 · 保存后由宿主应用" : "当前配置只读")
        : previewOnly ? cold ? "mock · 尚未选身份，仅准备配置草稿" : setupOnly ? "mock · 仅准备配置" : "本地调试配置 · 可随时修改"
        : "生产队伍配置宿主未接通 · 只读"
    readonly property var issues: Policy.problems(draft, clientID)
    readonly property bool valid: issues.length === 0
    readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(preferences?.current)
    readonly property string peerIssue: Policy.peerError(peerDraft, draft.peers.filter((_, index) => index !== selectedPeer), draft.nodeId, clientID, draft.networkEnabled)
    readonly property var publishers: Policy.candidates(draft, "canAggregate")
    readonly property var speakers: Policy.candidates(draft, "canVoice")
    readonly property var listeners: Policy.candidates(draft, "canHear")
    readonly property var peerRobotIds: Identity.loginIds().filter(id => !Identity.validLogin(clientID) || (id > 100) === (clientID > 100))
    readonly property var roleSettings: decisionPreferences?.current ?? ({})
    signal modelSettingsRequested
    signal aggregationRequested
    signal certificateInspectRequested(string file)
    title: "队伍身份与共享权限 · 可选模块"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1440
    height: 780
    onVisibleChanged: if (visible) reload()
    onClientIDChanged: reload()
    Connections { target: root.preferences; function onCurrentChanged() { root.reload(); } }
    function reload() { draft = Policy.clean(preferences?.current); selectedPeer = -1; peerDraft = Policy.peerDefaults(); feedback = ""; feedbackFailure = false; }
    function setValue(key, value) {
        if (!editable || !Object.prototype.hasOwnProperty.call(Policy.defaults(), key)) return;
        draft = Object.assign({}, draft, {[key]: value}); feedback = ""; feedbackFailure = false;
    }
    function setPeerValue(key, value) { if (editable) peerDraft = Object.assign({}, peerDraft, {[key]: value}); }
    function selectPeer(index) {
        selectedPeer = index;
        peerDraft = index >= 0 ? Object.assign({}, draft.peers[index]) : Policy.peerDefaults();
        feedback = ""; feedbackFailure = false;
    }
    function keepPeer() {
        if (!editable || peerIssue || selectedPeer < 0 && draft.peers.length >= 15) return;
        const peers = draft.peers.slice(), value = Object.assign({}, peerDraft);
        const keptIndex = selectedPeer < 0 ? peers.length : selectedPeer;
        if (selectedPeer < 0) peers.push(value); else peers[selectedPeer] = value;
        setValue("peers", peers); selectedPeer = keptIndex;
        feedback = "成员已加入未保存草稿 · 没有认证或连接";
    }
    function removePeer() {
        if (!editable || selectedPeer < 0) return;
        const node = draft.peers[selectedPeer].nodeId;
        setValue("peers", draft.peers.filter((_, index) => index !== selectedPeer));
        if (draft.publisherId === node) setValue("publisherId", "");
        if (draft.voiceNodeId === node) setValue("voiceNodeId", "");
        if (draft.voiceOutputNodeId === node) setValue("voiceOutputNodeId", "");
        selectPeer(-1); feedback = "仅移除草稿成员 · 运行权限没有改变";
    }
    function setUse(category, use, allowed) {
        if (!editable) return;
        const permissions = Object.assign({}, draft.permissions), values = Object.assign({}, permissions[category]);
        if (allowed) values[use] = true; else delete values[use];
        permissions[category] = values; setValue("permissions", permissions);
    }
    function saveDraft() {
        if (!editable || !valid || !preferences) return;
        // 预览只能保存自己的离线草稿，不能误用注入的生产宿主启动网络。
        if (previewOnly && controller !== null) { feedbackFailure = true; feedback = "mock预览没有提交生产配置。"; return; }
        if (!preferences.save(draft)) {
            feedbackFailure = true;
            feedback = "保存未完成 · " + (controller?.status || "字段无效或草稿容量不足；修改保留。");
            return;
        }
        feedbackFailure = false;
        feedback = previewOnly ? "已保存本窗口mock草稿 · 未认证、未共享、未播报"
            : controller?.status || "配置已保存；应用与连接结果以宿主状态为准。";
    }
    Rectangle {
        width: parent.width; height: 92; color: Theme.hudSurface
        OperatorOutline { color: root.editable ? Theme.hudBorder : Theme.warning }
        OperatorText { x: 14; y: 8; width: parent.width - 28; height: 26; text: root.editingStatus; size: 15; color: root.editable ? Theme.text : Theme.warning }
        OperatorText { x: 14; y: 38; width: parent.width - 28; height: 22; text: root.runtimeState.status ?? "队伍认证与共享运行状态未公开 · 不从草稿推断在线或可信"; size: 12; color: root.runtimeState.health === "rejected" || root.runtimeState.health === "offline" ? Theme.warning : Theme.muted }
        OperatorText { x: 14; y: 64; width: parent.width - 28; height: 22; text: "独立可选网络 · 关闭／缺失时本机继续 · 配置ID、公钥指纹及置信度都不等于认证完成"; size: 11; color: Theme.muted }
    }
    Row {
        y: 108; spacing: 12; width: parent.width
        Repeater { model: ["身份 / 连接", "可信成员", "用途 / 语音", "核验状态"]; OperatorButton { required property string modelData; required property int index; width: (parent.width - 36) / 4; text: modelData; primary: root.page === index; onClicked: root.page = index } }
    }
    Row {
        y: 162; width: parent.width; height: parent.height - y - 72; spacing: 22; visible: root.page === 0
        OperatorSection {
            width: (parent.width - 22) / 2; height: parent.height; title: "本机身份与共享会话配置"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorCheckBox { width: parent.width; text: "启用可选队内汇总网络"; enabled: root.editable; checked: root.draft.networkEnabled; onToggled: root.setValue("networkEnabled", checked) }
                OperatorText { width: parent.width; height: Math.max(80, implicitHeight + 8); text: "保存启用仅由宿主加载可选插件，不自动授权任何数据。发送还须本机发布许可、模型面板共享开关／类别与本页用途的交集。关闭、缺失或断连不阻塞本机功能。"; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: Theme.muted }
                OperatorStartupField { width: parent.width; label: "队伍命名空间ID"; value: root.draft.teamId; editable: root.editable; hint: "字母／数字／点／下划线／连字符；不是仅靠名称进行认证。"; onValueEdited: value => root.setValue("teamId", value) }
                OperatorStartupField { width: parent.width; label: "本机唯一节点ID"; value: root.draft.nodeId; editable: root.editable; hint: "不同客户端分别配置；与证书／签名及比赛会话绑定。"; onValueEdited: value => root.setValue("nodeId", value) }
                OperatorStartupField { width: parent.width; label: "本机显示名称"; value: root.draft.displayName; editable: root.editable; hint: "仅显示名称，不改变机器人身份或可信等级。"; onValueEdited: value => root.setValue("displayName", value) }
                OperatorText { width: parent.width; height: 30; text: "当前机器人绑定：" + Identity.role(root.clientID) + " · " + (root.clientID || "未选择"); size: 12; color: Theme.muted }
                OperatorCheckBox { width: parent.width; text: "允许本机发布经授权的来源数据"; enabled: root.editable; checked: root.draft.canSend; onToggled: root.setValue("canSend", checked) }
                OperatorCheckBox { width: parent.width; text: "允许本机担任汇总发布节点"; enabled: root.editable; checked: root.draft.canAggregate; onToggled: root.setValue("canAggregate", checked) }
                OperatorStartupField { width: parent.width; label: "比赛ID · 全队一致"; value: root.draft.matchId; editable: root.editable; hint: "1–64个标识字符；隔离不同比赛，不从裁判数据自动生成。"; onValueEdited: value => root.setValue("matchId", value) }
                OperatorStartupField { width: parent.width; label: "共享会话epoch · 全队一致"; value: root.draft.epoch; editable: root.editable; hint: "停止、重启或重新启用后必须由队伍指定新的epoch；持久会话租约禁止自动复用。"; onValueEdited: value => root.setValue("epoch", value) }
                OperatorStartupField { width: parent.width; label: "共享配置版本 · 全队一致"; value: root.draft.configurationRevision; editable: root.editable; hint: "1–64个标识字符；成员、用途及来源授权变更须同步配置。"; onValueEdited: value => root.setValue("configurationRevision", value) }
            }
        }
        OperatorSection {
            width: (parent.width - 22) / 2; height: parent.height; title: "独立传输与凭据引用"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorStartupField { width: parent.width; label: "队内安全消息端点"; value: root.draft.endpoint; editable: root.editable; hint: "mqtts://主机:端口；独立于官方选手端导出，不填账号或密码。"; onValueEdited: value => root.setValue("endpoint", value) }
                OperatorStartupField { width: parent.width; label: "信任根证书文件"; value: root.draft.caFile; editable: root.editable; hint: "相对路径按实例配置目录解析；文件内容不进入共享消息。"; onValueEdited: value => root.setValue("caFile", value) }
                OperatorStartupField { width: parent.width; label: "本机公开证书文件"; value: root.draft.certificateFile; editable: root.editable; hint: "宿主按明确配置核对证书、队伍／节点／机器人绑定；独立检查按钮尚未接通。"; onValueEdited: value => root.setValue("certificateFile", value) }
                OperatorStartupField { width: parent.width; label: "签名私钥文件路径的环境变量"; value: root.draft.signingKeyFileEnv; editable: root.editable; hint: "界面只保存变量名，不展示私钥；插件启用后读取指定文件签名。共用口令不证明原发送者身份。"; onValueEdited: value => root.setValue("signingKeyFileEnv", value) }
                OperatorButton { width: parent.width; text: root.runtimeState.capabilities?.inspectCertificate === true ? "检查证书绑定" : "检查证书绑定 · 待接通"; enabled: root.editable && root.runtimeState.capabilities?.inspectCertificate === true; onClicked: root.certificateInspectRequested(root.draft.certificateFile) }
                OperatorCheckBox { width: parent.width; text: "已通过外部机制同步所有成员时钟"; enabled: root.editable; checked: root.draft.clocksSynchronized; onToggled: root.setValue("clocksSynchronized", checked) }
                OperatorStartupField { width: parent.width; label: "允许时钟偏差 · ms"; value: root.draft.maxClockSkewMs; editable: root.editable; hint: "0–1000；人工声明不等于本客户端测量或完成了时钟同步。"; onValueEdited: value => root.setValue("maxClockSkewMs", value) }
                OperatorCheckBox { width: parent.width; text: "已向全队说明汇总视图的用途及披露范围"; enabled: root.editable; checked: root.draft.teamWideSharingConfirmed; onToggled: root.setValue("teamWideSharingConfirmed", checked) }
                OperatorText { width: parent.width; height: Math.max(120, implicitHeight + 8); text: "模块已有TLS传输与消息签名实现，真实证书认证、实网联通及数据生产链仍待集中验证；保存不证明已认证。当前没有真实传感器／视觉源，mock样例不参与生产共享或模型输入。"; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: Theme.warning }
            }
        }
    }
    Row {
        y: 162; width: parent.width; height: parent.height - y - 72; spacing: 22; visible: root.page === 1
        OperatorSection {
            width: 410; height: parent.height; title: "成员草稿 · 不代表已核验"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorText { width: parent.width; height: 26; text: "其他成员 " + root.draft.peers.length + " / 15 · 含本机最多16个节点"; size: 12; color: Theme.muted }
                OperatorButton { width: parent.width; text: "添加成员草稿"; enabled: root.editable && root.draft.peers.length < 15; onClicked: root.selectPeer(-1) }
                Repeater {
                    model: root.draft.peers.length
                    OperatorButton { required property int index; readonly property var member: root.draft.peers[index]; width: parent.width; height: 70; text: (member.label || member.nodeId) + "\n" + member.nodeId + " · " + member.robotId; Accessible.name: "编辑成员草稿 " + member.nodeId; primary: index === root.selectedPeer; onClicked: root.selectPeer(index) }
                }
                OperatorText { width: parent.width; height: Math.max(120, implicitHeight + 8); text: "新增／移除只改变未应用草稿。实际身份必须结合节点签名、公钥固定、队伍／机器人绑定和会话核验；不以IP或机器人编号自动授信。"; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: Theme.muted }
            }
        }
        OperatorSection {
            width: parent.width - 432; height: parent.height; title: root.selectedPeer >= 0 ? "编辑已有成员草稿" : "新成员 · 完整信息后加入草稿"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorStartupField { width: parent.width; label: "成员节点ID"; value: root.peerDraft.nodeId; editable: root.editable; hint: "不能与本机／其他成员重复。"; onValueEdited: value => root.setPeerValue("nodeId", value) }
                OperatorStartupField { width: parent.width; label: "成员显示名称"; value: root.peerDraft.label; editable: root.editable; hint: "名称不作为身份核验依据。"; onValueEdited: value => root.setPeerValue("label", value) }
                OperatorText { width: parent.width; height: 26; text: "允许绑定的机器人"; size: 12; color: Theme.muted }
                OperatorSelect { width: parent.width; label: "成员机器人绑定"; enabled: root.editable; model: root.peerRobotIds.map(id => (id > 100 ? "蓝方 " : "红方 ") + Identity.role(id) + " · " + id); currentIndex: root.peerRobotIds.indexOf(root.peerDraft.robotId); onActivated: root.setPeerValue("robotId", root.peerRobotIds[currentIndex]) }
                OperatorStartupField { width: parent.width; label: "成员公开证书文件"; value: root.peerDraft.certificateFile; editable: root.editable; hint: "部署本地公开证书引用，用于校验签名来源；不会共享私钥。"; onValueEdited: value => root.setPeerValue("certificateFile", value) }
                OperatorStartupField { width: parent.width; label: "固定SPKI公钥指纹 · SHA-256"; value: root.peerDraft.fingerprint; editable: root.editable; hint: "64个十六进制字符；为证书SPKI公钥哈希，不是整张证书的哈希。"; onValueEdited: value => root.setPeerValue("fingerprint", value) }
                Repeater {
                    model: [{key: "canSend", title: "允许该节点发布已授权来源数据"}, {key: "canAggregate", title: "允许成为汇总发布节点"}, {key: "canVoice", title: "队内语音生成偏好 · 生产链待接通"}, {key: "canHear", title: "队内语音收听偏好 · 生产链待接通"}]
                    OperatorCheckBox { required property var modelData; width: parent.width; text: modelData.title; enabled: root.editable; checked: root.peerDraft[modelData.key] === true; onToggled: root.setPeerValue(modelData.key, checked) }
                }
                OperatorText { width: parent.width; height: Math.max(56, implicitHeight + 8); text: root.peerIssue || "成员格式可加入草稿；仍没有任何生产认证。"; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: root.peerIssue ? Theme.warning : Theme.muted }
                Row {
                    width: parent.width; spacing: 12
                    OperatorButton { width: (parent.width - 12) / 2; text: "保留到成员草稿"; primary: true; enabled: root.editable && !root.peerIssue; onClicked: root.keepPeer() }
                    OperatorButton { width: (parent.width - 12) / 2; text: "移除所选草稿成员"; enabled: root.editable && root.selectedPeer >= 0; onClicked: root.removePeer() }
                }
            }
        }
    }
    Row {
        y: 162; width: parent.width; height: parent.height - y - 72; spacing: 22; visible: root.page === 2
        OperatorSection {
            width: 814; height: parent.height; title: "允许的数据用途 · 不自动扩大字段共享"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorText { width: parent.width; height: Math.max(78, implicitHeight + 8); text: "默认所有用途关闭。来源身份、字段白名单及用途分别授权；可允许HUD／告警而禁止模型，外部AI另行明确许可。不共享密钥、原始视频、任意bytes或控制命令。"; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: Theme.muted }
                OperatorText { width: parent.width; height: Math.max(56, implicitHeight + 8); text: root.roleSettings.shareEnabled ? "本角色发送类别：" + Policy.categories.filter(category => root.roleSettings.shareFields?.includes(category.id)).map(category => category.title).join("、") : "模型面板的本角色发送开关：关 · 此处勾选用途不自动开启发送。"; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: Theme.muted }
                Row {
                    width: parent.width
                    OperatorText { width: 222; height: 34; text: "数据类别"; size: 11; color: Theme.muted }
                    Repeater { model: Policy.uses; OperatorText { required property var modelData; width: (parent.width - 222) / 5; height: 34; text: modelData.title; size: 10; horizontalAlignment: Text.AlignHCenter; color: Theme.muted } }
                }
                Repeater {
                    model: Policy.categories
                    Item {
                        id: categoryRow
                        required property var modelData
                        width: parent.width; height: 48
                        Rectangle { anchors.fill: parent; color: "#19282421" }
                        OperatorText { x: 8; width: 210; height: parent.height; text: categoryRow.modelData.title; size: 11 }
                        Row {
                            x: 222; width: parent.width - 222; height: parent.height
                            Repeater {
                                model: Policy.uses
                                OperatorCheckBox { required property var modelData; width: parent.width / 5; height: parent.height; text: ""; centerIndicator: true; Accessible.name: categoryRow.modelData.title + "用于" + modelData.title; enabled: root.editable; checked: root.draft.permissions[categoryRow.modelData.id]?.[modelData.id] === true; onToggled: root.setUse(categoryRow.modelData.id, modelData.id, checked) }
                            }
                        }
                    }
                }
                OperatorButton { width: parent.width; text: "查看模型面板的发送字段／语音偏好"; onClicked: root.modelSettingsRequested() }
            }
        }
        OperatorSection {
            width: parent.width - 836; height: parent.height; title: "完整汇总与统一语音责任"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorText { width: parent.width; height: 26; text: "固定汇总发布节点"; size: 12; color: Theme.muted }
                OperatorSelect { width: parent.width; label: "汇总发布节点"; emptyText: root.publishers.length ? "请选择发布节点" : "先配置本机／授权成员"; enabled: root.editable && root.publishers.length > 0; model: root.publishers.map(entry => entry.title); currentIndex: root.publishers.findIndex(entry => entry.id === root.draft.publisherId); onActivated: root.setValue("publisherId", root.publishers[currentIndex].id) }
                OperatorText { width: parent.width; height: Math.max(102, implicitHeight + 8); text: "来源校验、逐项时效与冲突处理后形成完整视图。HUD／AI消费链仍须宿主单独接通，不因保存此页就可用；发布者失联不拼零散消息或自动改用另一发布者。"; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: Theme.muted }
                OperatorText { width: parent.width; height: 26; text: "语音生成节点偏好 · 未接通"; size: 12; color: Theme.muted }
                OperatorSelect { width: parent.width; label: "队伍语音生成节点"; emptyText: root.speakers.length ? "请选择语音生成节点" : "先配置授权语音节点"; enabled: root.editable && root.speakers.length > 0; model: root.speakers.map(entry => entry.title); currentIndex: root.speakers.findIndex(entry => entry.id === root.draft.voiceNodeId); onActivated: root.setValue("voiceNodeId", root.speakers[currentIndex].id) }
                OperatorCheckBox { width: parent.width; text: "本机队内收听偏好 · 未接通"; enabled: root.editable; checked: root.draft.selfListen; onToggled: root.setValue("selfListen", checked) }
                OperatorStartupField { width: parent.width; label: "语音输出组ID"; value: root.draft.voiceOutputGroup; editable: root.editable; hint: "同一物理扬声器／收听区域共用一个组与唯一播放者。"; onValueEdited: value => root.setValue("voiceOutputGroup", value) }
                OperatorText { width: parent.width; height: 26; text: "唯一播放节点偏好 · 未接通"; size: 12; color: Theme.muted }
                OperatorSelect { width: parent.width; label: "输出组唯一播放节点"; emptyText: root.listeners.length ? "请选择唯一播放节点" : "先配置收听授权成员"; enabled: root.editable && root.listeners.length > 0; model: root.listeners.map(entry => entry.title); currentIndex: root.listeners.findIndex(entry => entry.id === root.draft.voiceOutputNodeId); onActivated: root.setValue("voiceOutputNodeId", root.listeners[currentIndex].id) }
                OperatorText { width: parent.width; height: Math.max(62, implicitHeight + 8); text: "模型语音偏好：" + (root.roleSettings.voiceEnabled ? "开" : "关") + " · " + (root.roleSettings.voiceAudience === "team" ? "队内收听" : "仅本机") + " · " + (({local: "本机播报", leader: "主操作手播报", designated: "指定节点播报"})[root.roleSettings.voiceSpeaker] ?? "未配置"); size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: Theme.muted }
                OperatorText { width: parent.width; height: Math.max(102, implicitHeight + 8); text: "实际播报还须模型语音偏好、可信发送者和用途许可。唯一生成节点／输出组按建议ID与job去重；失联不抢播、不重播旧警告。当前没有队内语音生产链路。"; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: Theme.muted }
                OperatorStartupField { width: parent.width; label: "心跳间隔 · ms"; value: root.draft.heartbeatMs; editable: root.editable; hint: "500–5000；成员心跳不刷新字段时效。"; onValueEdited: value => root.setValue("heartbeatMs", value) }
                OperatorStartupField { width: parent.width; label: "成员断连超时 · ms"; value: root.draft.timeoutMs; editable: root.editable; hint: "至少3个心跳周期，不超过30000。"; onValueEdited: value => root.setValue("timeoutMs", value) }
            }
        }
    }
    Row {
        y: 162; width: parent.width; height: parent.height - y - 72; spacing: 22; visible: root.page === 3
        OperatorSection {
            width: (parent.width - 22) / 2; height: parent.height; title: "宿主核验状态 · 不从配置推导"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorDiagnosticTable { width: parent.width; title: root.previewOnly ? "离线核验状态样例" : "真实运行状态"; rows: [
                    {label: "实际队伍", value: root.runtimeState.team_id || "未公开"}, {label: "实际节点", value: root.runtimeState.local_node || "未公开", detail: true},
                    {label: "配置版本", value: typeof root.runtimeState.configuration_revision === "string" || typeof root.runtimeState.configuration_revision === "number" ? String(root.runtimeState.configuration_revision) || "未公开" : "未公开", detail: true},
                    {label: "认证结果", value: root.previewOnly ? "mock · 非实际认证" : root.runtimeState.authenticated === true ? "宿主已核验 · 测量仍需独立验证" : "未核验", detail: true},
                    {label: "握手年龄", value: typeof root.runtimeState.handshake_age_ms === "number" ? root.runtimeState.handshake_age_ms + "ms" : "未公开"},
                    {label: "汇总发布者", value: root.runtimeState.issuer || "未公开", detail: true}, {label: "语音责任节点", value: root.runtimeState.voice_owner || "未接通", detail: true}
                ] }
                OperatorText { width: parent.width; height: Math.max(76, implicitHeight + 8); text: root.runtimeState.rejection || "没有真实排除记录；不虚构签名／TLS检查结果。"; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: Theme.warning }
            }
        }
        OperatorSection {
            width: (parent.width - 22) / 2; height: parent.height; title: "发送者与旁路状态"
            OperatorScrollableColumn {
                anchors.fill: parent
                Repeater {
                    model: Array.isArray(root.runtimeState.peers) ? root.runtimeState.peers.length : 0
                    OperatorDiagnosticTable { required property int index; readonly property var peer: root.runtimeState.peers[index]; width: parent.width; title: peer.node_id ?? "来源未公开"; rows: [{label: "原机器人", value: String(peer.robot_id ?? "未公开")}, {label: "核验状态", value: root.previewOnly ? "mock · " + (({verified: "核验完成状态", pending: "待核验", rejected: "已拒绝", offline: "失联"})[peer.state] ?? "未公开") : (({verified: "宿主身份已核验", pending: "待核验", rejected: "已拒绝", offline: "失联"})[peer.state] ?? "未公开"), detail: true}, {label: "心跳年龄", value: typeof peer.age_ms === "number" ? peer.age_ms + "ms" : "未公开"}] }
                }
                OperatorText { width: parent.width; height: Math.max(130, implicitHeight + 8); text: "配置保存不等于实网认证成功。签名错误／重复／旧会话／过期／撤回由模块拒绝或隔离；不同来源类别不混同。关闭或缺失插件时，本机选手端连接与其他功能继续；真实传感器／视觉适配器仍待提供。"; size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: Theme.muted }
                OperatorButton { width: parent.width; text: "完整视图／来源诊断"; onClicked: root.aggregationRequested() }
            }
        }
    }
    OperatorText {
        y: parent.height - 58; width: parent.width - 626; height: 50
        text: root.feedback || (!root.editable ? root.editingStatus : !root.valid ? root.issues[0] : root.dirty ? "有未保存修改；保存前不改变运行配置。" : root.controller?.status || "字段、用途、身份与运行核验分别表示；网络默认关闭。")
        size: 11; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: !root.valid || root.feedbackFailure ? Theme.warning : root.feedback ? Theme.green : Theme.muted
    }
    Row {
        x: parent.width - 614; y: parent.height - 38; spacing: 12
        OperatorButton { width: 184; text: "撤销全部草稿修改"; enabled: root.editable && root.dirty; onClicked: root.reload() }
        OperatorButton { width: 214; text: root.previewOnly ? "保存本窗口mock草稿" : "保存并应用队伍配置"; primary: true; enabled: root.editable && root.valid && root.dirty; onClicked: root.saveDraft() }
        OperatorButton { width: 192; text: "查看完整队伍视图"; onClicked: root.aggregationRequested() }
    }
}
