import QtQuick
import "OperatorProviderPolicy.js" as Policy
import "OperatorDecisionPolicy.js" as Match

OperatorPanelFrame {
    id: root
    property var preferences: null
    property var decisionPreferences: null
    property var runtime: null
    property var controller: null
    property var telemetry: null
    property var connection: null
    property bool setupOnly: false
    property bool previewOnly: false
    property int clientID: 0
    property int page: 0
    property var draft: Policy.defaults()
    property string feedback: ""
    readonly property bool cold: clientID === 0 && connection?.connected !== true && connection?.connecting !== true
    readonly property bool editable: previewOnly || controller?.editable === true
    readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(preferences?.current)
    readonly property var issues: Policy.problems(draft)
    readonly property var roleSettings: decisionPreferences?.current ?? ({})
    readonly property var catalogModels: Policy.catalog(controller?.models ?? [])
    readonly property bool catalogScopeMatches: draft.kind === preferences?.current?.kind
        && draft.endpoint === preferences?.current?.endpoint && draft.api === preferences?.current?.api
    readonly property bool draftActivationKnown: catalogScopeMatches && draft.format === preferences?.current?.format
        && runtime?.capabilities?.activate === true
    readonly property bool canRefreshModels: !previewOnly && controller !== null && editable
        && runtime?.capabilities?.listModels === true && runtime?.catalog_busy !== true && !dirty
    signal strategyRequested
    signal sourcesRequested
    signal teamSettingsRequested
    signal inspectRequested(var configuration)
    title: "模型提供者 · 连接 / 进程 / 运行边界"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1440; height: 780
    onVisibleChanged: if (visible) reload()
    onClientIDChanged: reload()
    onControllerChanged: reload()
    Connections { target: root.preferences; function onCurrentChanged() { root.reload(); } }
    Connections {
        target: root.controller
        ignoreUnknownSignals: true
        function onScopeChanged() {root.reload();}
        // status／catalog更新不覆盖未保存的连接／模型草稿。
    }
    function reload() { draft = Policy.clean(preferences?.current); feedback = ""; }
    function setValue(key, value) { if (!editable) return; draft = Object.assign({}, draft, {[key]: value}); feedback = ""; }
    function selectKind(kind) { if (!editable) return; draft = Policy.defaults(kind); feedback = "已选择连接预设 · 替换未保存草稿，尚未应用到运行服务"; }
    function saveDraft() {
        if (!editable || issues.length || !preferences) return;
        if (previewOnly && preferences.runtime !== null && preferences.runtime !== undefined) {
            feedback="mock草稿已核对；未调用生产保存或请求模型。";return;
        }
        if (!preferences.save(draft)) {
            feedback = "保存未完成 · "+(controller?.status || runtime?.status || "请核对字段与锁定状态，草稿保留。");
            return;
        }
        feedback = previewOnly ? "本窗口mock草稿已保存 · 未读密钥、未启动进程、未请求模型"
            : controller?.status || runtime?.status || "配置已保存；是否应用成功以宿主运行状态为准。";
    }
    function refreshModels() {
        if (!canRefreshModels) return;
        const accepted=controller.refreshModels();
        feedback=accepted === true ? "已提交当前端点模型目录刷新；目录结果不证明账号推理权限。"
            : "目录刷新未启动 · "+(controller.status || "当前模型ID保留。");
    }
    Rectangle {
        width: parent.width; height: 92; color: Theme.hudSurface
        OperatorOutline { color: root.editable ? Theme.hudBorder : Theme.warning }
        OperatorText { x: 14; y: 8; width: parent.width - 28; height: 26; text: !root.previewOnly && root.controller !== null ? root.controller.lockReason || (root.editable ? "提供者配置 · 保存后由宿主应用" : "当前提供者配置只读") : root.previewOnly ? root.cold ? "mock · 未选身份，准备连接草稿" : root.setupOnly ? "mock · 仅准备配置" : "本地调试配置 · 可随时修改" : "生产提供者配置宿主未接通"; size: 15; color: root.editable ? Theme.text : Theme.warning }
        OperatorText { x: 14; y: 38; width: parent.width - 28; height: 22; text: root.runtime?.status ?? "生产提供者配置未公开 · 不从草稿推断已接模型"; size: 12; color: root.runtime?.health === "error" ? Theme.warning : Theme.muted }
        OperatorText { x: 14; y: 64; width: parent.width - 28; height: 22; text: "连接预设 / 可用模型 / 当前选择分开 · 保存后应用 · 建议不会自动触发机器人动作"; size: 11; color: Theme.muted }
    }
    Row {
        y: 108; width: parent.width; spacing: 12
        Repeater { model: ["提供者 / 连接", "时限 / 输出", "输入 / 权限", "实际运行"]; OperatorButton { required property string modelData; required property int index; width: (parent.width - 36) / 4; text: modelData; primary: root.page === index; onClicked: root.page = index } }
    }
    Row {
        y: 162; width: parent.width; height: parent.height - y - 72; spacing: 22; visible: root.page === 0
        OperatorSection {
            width: 410; height: parent.height; title: "连接预设 · 切换替换未保存草稿"
            OperatorScrollableColumn {
                anchors.fill: parent
                Repeater { model: Policy.kinds; OperatorButton { required property var modelData; width: parent.width; height: 58; text: modelData.title; primary: root.draft.kind === modelData.id; enabled: root.editable; onClicked: root.selectKind(modelData.id) } }
                OperatorCheckBox { width: parent.width; text: "保存时启用此提供者"; checked: root.draft.enabled; enabled: root.editable; onToggled: root.setValue("enabled", checked) }
                OperatorText { width: parent.width; height: Math.max(110, implicitHeight + 8); text: (root.clientID === 0 ? "未选身份时保存为本配置的默认值；选定身份后保存仅属于该机器人。" : "当前保存仅属于机器人"+root.clientID+"。")+"预设不证明模型／账号可用。策略、自动建议和语音偏好在原模型面板。启动配置的高级插件参数仅在明确保存本页时替换。"; size: 11; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
        OperatorSection {
            width: parent.width - 432; height: parent.height; title: root.draft.kind === "codex" ? "本机进程 · 不等于离线模型" : "完整推理端点与凭据引用"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorStartupField { width: parent.width; visible: root.draft.kind !== "codex"; label: "完整HTTP(S)推理端点"; value: root.draft.endpoint; editable: root.editable; error: root.draft.enabled ? Policy.endpointError(root.draft) : ""; hint: "本机服务限loopback；外部服务HTTPS，不在URL保存账号或密钥。"; onValueEdited: value => root.setValue("endpoint", value) }
                OperatorStartupField { width: parent.width; visible: root.draft.kind === "codex"; label: "Codex可执行文件 / 路径"; value: root.draft.executable; editable: root.editable; hint: "只填程序路径，不填命令参数；在专用隔离工作目录运行。"; onValueEdited: value => root.setValue("executable", value) }
                OperatorStartupField { width: parent.width; label: "明确模型ID / 本地服务别名"; value: root.draft.model; editable: root.editable; hint: "自由ID保留，不静默替换；预设名字不是账号可用清单。"; onValueEdited: value => root.setValue("model", value) }
                OperatorText {width:parent.width;height:26;visible:root.controller !== null;text:"当前端点返回的模型目录";size:12;color:Theme.muted}
                OperatorSelect {
                    width:parent.width;visible:root.controller !== null
                    label:"选择当前端点返回的模型ID";emptyText:root.catalogModels.length ? "自由ID未在目录中，保持不变" : "尚无经端点返回的目录"
                    model:root.catalogModels.map(item=>item.title === item.id ? item.id : item.title+" · "+item.id)
                    currentIndex:root.catalogModels.findIndex(item=>item.id === root.draft.model)
                    enabled:root.editable && root.catalogScopeMatches && root.catalogModels.length > 0 && root.runtime?.catalog_busy !== true
                    onActivated:index=>{const item=root.catalogModels[index];if(item)root.setValue("model",item.id);}
                }
                OperatorButton {
                    width:parent.width;visible:root.controller !== null
                    text:root.runtime?.catalog_busy === true ? "正在刷新模型目录" : "刷新已保存端点的模型目录"
                    enabled:root.canRefreshModels
                    onClicked:root.refreshModels()
                }
                OperatorText {
                    width:parent.width;height:Math.max(44,implicitHeight+6);visible:root.controller !== null
                    text:!root.catalogScopeMatches ? "目录属于已保存的端点；连接草稿未应用，请先保存再刷新。自由模型ID保留。"
                        : root.dirty ? "连接／模型草稿未保存；先保存，再显式刷新当前端点目录。"
                        : root.runtime?.capabilities?.listModels !== true ? "当前提供者未公开模型目录能力；仍可保留自由模型ID。"
                        : root.catalogModels.length ? "目录仅说明端点列出了这些ID；不证明当前选择已获账号权限、推理可用或质量合格。"
                        : "目录不会在打开页面时自动请求。只有显式刷新成功后显示；自由模型ID始终保留。"
                    size:11;color:Theme.muted;wrapMode:Text.WordWrap;elide:Text.ElideNone
                }
                OperatorStartupField { width: parent.width; visible: root.draft.kind !== "codex"; label: "API密钥的环境变量名"; value: root.draft.keyEnv; editable: root.editable; hint: "只保存引用，不读取或显示密钥。文件／队内消息／教程不含凭据。"; onValueEdited: value => root.setValue("keyEnv", value) }
                OperatorStartupField { width: parent.width; visible: root.draft.kind === "codex"; label: "专用Codex认证目录引用 · 可为空"; value: root.draft.authHome; editable: root.editable; hint: "为空使用应用配置目录/codex-credentials；需单独登录，不复用开发目录，不复制或显示auth.json。"; onValueEdited: value => root.setValue("authHome", value) }
                OperatorText { width: parent.width; height: Math.max(100, implicitHeight + 8); text: root.draft.kind === "codex" ? "保留Codex进程选项与明确模型ID；是否安装兼容适配器、认证及执行边界以宿主状态为准。本机进程仍可能使用外部模型，不自动当作离线推理。" : root.draft.kind === "deepseek" ? "DeepSeek预设使用Chat与JSON Object；生产HTTP入口由宿主应用。配置／插件就绪不证明账号有权使用所选模型，完整输出仍须通过建议契约校验。" : "选择API及结构化格式须与服务器能力一致。本机HTTP只说明端点在本机，不保证上游没有代理到外部模型；宿主须公开真实推理边界。"; size: 11; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorButton { width: parent.width; text: "检查本地配置 · 不请求推理"; enabled: root.editable && root.runtime?.capabilities?.inspect === true; onClicked: root.inspectRequested(Policy.clean(root.draft)) }
            }
        }
    }
    Row {
        y: 162; width: parent.width; height: parent.height - y - 72; spacing: 22; visible: root.page === 1
        OperatorSection {
            width: (parent.width - 22) / 2; height: parent.height; title: "请求总时限与节流 · 最多一个在途"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorStartupField { width: parent.width; label: "总超时 · ms"; value: root.draft.timeoutMs; editable: root.editable; error: Policy.integer(root.draft.timeoutMs, 50, 120000) ? "" : "总超时50–120000 ms。"; hint: "包括进程启动／请求／完整输出；超时取消，并隐藏失效建议。"; onValueEdited: value => root.setValue("timeoutMs", value) }
                OperatorStartupField { width: parent.width; label: "最小请求间隔 · ms"; value: root.draft.minimumIntervalMs; editable: root.editable; hint: "500–30000；合并新事件，不排队累积过期快照。"; onValueEdited: value => root.setValue("minimumIntervalMs", value) }
                OperatorStartupField { width: parent.width; label: root.draft.kind === "codex" ? "输出长度提示 tokens · 非硬限制" : "最大输出 tokens"; value: root.draft.maxOutputTokens; editable: root.editable; hint: root.draft.kind === "codex" ? "当前CLI未核验token硬上限；只作提示。stdout限256KiB，最终结果限64KiB，超限拒绝。" : "256–8192；需核对模型能力，截断不是有效建议。"; onValueEdited: value => root.setValue("maxOutputTokens", value) }
                OperatorText { width: parent.width; height: Math.max(100, implicitHeight + 8); text: "自动建议开关与策略仍由模型面板拥有。启用提供者不开始自动请求；生产调度须用实时新鲜视图或事件、取消过时代次并验证完整建议／来源依赖。"; size: 11; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
        OperatorSection {
            width: (parent.width - 22) / 2; height: parent.height; title: "输出契约 · 不依靠模型自称可信"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorText { width: parent.width; height: 26; visible: root.draft.kind !== "codex"; text: "HTTP协议"; size: 12; color: Theme.muted }
                OperatorSelect { width: parent.width; visible: root.draft.kind !== "codex"; label: "HTTP协议"; enabled: root.editable && root.draft.kind !== "deepseek"; model: ["Chat Completions", "Responses"]; currentIndex: root.draft.api === "responses" ? 1 : 0; onActivated: root.setValue("api", currentIndex ? "responses" : "chat") }
                OperatorText { width: parent.width; height: 26; visible: root.draft.kind !== "codex"; text: "结构化输出"; size: 12; color: Theme.muted }
                OperatorSelect { width: parent.width; visible: root.draft.kind !== "codex"; label: "结构化输出"; enabled: root.editable && root.draft.kind !== "deepseek"; model: ["JSON Schema · 需服务端支持", "JSON Object · 宿主严格校验"]; currentIndex: root.draft.format === "json-object" ? 1 : 0; onActivated: root.setValue("format", currentIndex ? "json-object" : "json-schema") }
                OperatorCheckBox { width: parent.width; text: "DeepSeek thinking · 需核对超时／输出预算"; visible: root.draft.kind === "deepseek"; checked: root.draft.thinking; enabled: root.editable; onToggled: root.setValue("thinking", checked) }
                OperatorText { width: parent.width; height: 26; visible: root.draft.kind === "codex"; text: "Codex推理强度 · 明确选择，不替换模型"; size: 12; color: Theme.muted }
                OperatorSelect { width: parent.width; visible: root.draft.kind === "codex"; label: "Codex推理强度"; enabled: root.editable; model: ["low", "medium", "high"]; currentIndex: ["low","medium","high"].indexOf(root.draft.reasoning); onActivated: root.setValue("reasoning", model[currentIndex]) }
                OperatorText { width: parent.width; height: Math.max(150, implicitHeight + 8); text: root.draft.kind === "codex" ? "Codex进度、工具日志和stderr不是建议；只有完整成功且通过宿主校验的最终结果可显示。"+(root.draftActivationKnown ? "宿主为已保存配置公开了兼容激活入口；实际认证与执行仍以运行结果为准。" : root.catalogScopeMatches ? "当前宿主未公开可用Codex激活入口；保存选项不代表已安装或可运行。" : "连接草稿尚未应用，不能沿用其他提供者的激活状态判断Codex能力。") : "JSON格式正确不证明建议合格。宿主须校验摘要／依据／优先级／截止、拒绝空内容与截断、记录提供者和输入视图，并检查原来源依赖仍新鲜。流式片段不直接当有效HUD指引。"; size: 12; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
    }
    Row {
        y: 162; width: parent.width; height: parent.height - y - 72; spacing: 22; visible: root.page === 2
        OperatorSection {
            width: (parent.width - 22) / 2; height: parent.height; title: "已有角色偏好 · 本页只查看"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorDiagnosticTable { width: parent.width; title: "不维护第二份策略开关"; rows: [
                    {label: "输入范围", value: root.roleSettings.inputMode === "team" ? "完整队伍数据视图" : "本机机器人数据"},
                    {label: "所选模型ID", value: root.roleSettings.modelId || "尚未选择", detail: true},
                    {label: "自动建议", value: root.roleSettings.autoAdvice ? "已保存开启偏好 · 实际调度见宿主状态" : "关闭", detail: true},
                    {label: "队伍策略", value: Match.teamStrategies.find(item => item.id === root.roleSettings.teamStrategy)?.title ?? "未配置", detail: true},
                    {label: "角色策略", value: Match.roleStrategies.find(item => item.id === root.roleSettings.roleStrategy)?.title ?? "未配置", detail: true}
                ] }
                OperatorButton { width: parent.width; text: "模型 / 策略 / HUD偏好"; onClicked: root.strategyRequested() }
                OperatorText { width: parent.width; height: Math.max(120, implicitHeight + 8); text: "本机模式不等待队友；队伍模式先汇总验证，再交给提供者。目录与自由模型ID分开，未知ID不会静默替换；保存或目录列出都不证明账号已获推理权限。"; size: 12; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
        OperatorSection {
            width: (parent.width - 22) / 2; height: parent.height; title: "数据用途与推理地点 · 独立边界"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorText { width: parent.width; height: Math.max(150, implicitHeight + 8); text: "输入范围与推理地点独立。本机数据交给外部API仍须外部AI许可；完整队伍视图交给本地模型仍须团队成员／来源／用途与新鲜度校验。Codex或本机HTTP可能使用远端后端，不能仅凭进程／端点位置当成离线。"; size: 12; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                OperatorButton { width: parent.width; text: "来源 / 传感器用途"; onClicked: root.sourcesRequested() }
                OperatorButton { width: parent.width; text: "队伍身份 / 数据用途"; onClicked: root.teamSettingsRequested() }
                OperatorText { width: parent.width; height: Math.max(140, implicitHeight + 8); text: "只送策略所需授权项，不送原始视频、凭据、任意bytes或控制命令。官方数据仍经官方选手端；本地来源分层。模型建议仅提示，用户确认与现有命令安全边界保持。"; size: 12; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
    }
    Row {
        y: 162; width: parent.width; height: parent.height - y - 72; spacing: 22; visible: root.page === 3
        OperatorSection {
            width: (parent.width - 22) / 2; height: parent.height; title: "实际提供者截面 · 不以草稿补值"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorText { width: parent.width; height: 38; text: root.runtime?.mock === true ? "离线mock绘制 · 非模型／账号验证" : "宿主状态 · 未提供字段显示未知"; size: 13; color: Theme.warning }
                OperatorDiagnosticTable { width: parent.width; title: "宿主公开参数"; rows: [
                    {label: "提供者", value: root.runtime?.provider_id ?? "未公开", detail: true},
                    {label: "已保存模型ID", value: root.runtime?.configured_model ?? "未公开", detail: true},
                    {label: "请求模型ID", value: root.runtime?.model ?? "未公开", detail: true},
                    {label: "兼容激活入口", value: root.runtime?.capabilities?.activate === true ? "宿主已公开；不等于账号／推理验证" : "不可用或未公开", detail: true},
                    {label: "账号／模型验证", value: "本地配置检查及目录列出不构成推理验证", detail: true},
                    {label: "推理地点", value: ({local: "宿主核验本地", external: "外部模型", unknown: "未知 · 按外部权限"})[root.runtime?.inference_location] ?? "未知 · 按外部权限", detail: true},
                    {label: "端点", value: root.runtime?.endpoint ?? "未公开", detail: true}, {label: "配置版本", value: String(root.runtime?.configuration_revision ?? "未公开")},
                    {label: "凭据状态", value: root.runtime?.credentials ?? "未公开 · 不展示密钥", detail: true},
                    {label: "Codex执行边界", value: root.runtime?.provider_id === "decision.codex" ? "临时目录／固定参数／请求关闭工具；CLI、认证和有效隔离尚未实际验收" : "非Codex提供者", detail: true},
                    {label: "Codex输出限制", value: root.runtime?.provider_id === "decision.codex" ? "输出长度仅提示；256KiB事件／64KiB最终结果硬限制" : "按当前HTTP提供者配置", detail: true}
                ] }
            }
        }
        OperatorSection {
            width: (parent.width - 22) / 2; height: parent.height; title: "请求 / 输入 / 退化状态"
            OperatorScrollableColumn {
                anchors.fill: parent
                OperatorDiagnosticTable { width: parent.width; title: "独立请求证据"; rows: [
                    {label: "状态", value: root.runtime?.status ?? "生产配置未接通", detail: true}, {label: "请求ID", value: root.runtime?.request_id ?? "没有公开在途请求", detail: true},
                    {label: "实际输入范围", value: ({local: "本机机器人视图", team: "完整队伍视图"})[root.runtime?.input_mode] ?? "未公开"}, {label: "输入视图", value: root.runtime?.snapshot ?? "未公开", detail: true},
                    {label: "耗时", value: Number.isFinite(root.runtime?.latency_ms) ? root.runtime.latency_ms + " ms" : "未公开"}
                ] }
                OperatorText { width: parent.width; height: Math.max(170, implicitHeight + 8); text: "超时／失联／拒绝／来源失效降为状态提示，HUD没有新鲜有效建议就隐藏，不推挤赛场信息／准星／读数／地图。已保存配置、已应用HTTP插件、端点目录和真实推理响应分别判断；请求模型ID不等于服务端实际返回模型。Codex适配器是否可用以宿主状态为准。"; size: 12; color: Theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
        }
    }
    Item {
        y: parent.height - 62; width: parent.width; height: 62
        OperatorText { width: parent.width - 310; height: 24; text: root.feedback || root.issues[0] || (root.dirty ? "连接草稿未保存 · 运行配置不变" : root.controller?.status || root.runtime?.status || "提供者配置宿主未公开"); size: 11; color: root.issues.length ? Theme.warning : Theme.muted }
        OperatorText { y: 28; width: parent.width - 310; height: 24; text: root.previewOnly ? "mock · 不调用生产配置／目录请求或模型" : "保存后由宿主应用兼容插件；自动建议／语音偏好仍独立"; size: 11; color: Theme.muted }
        Row { x: parent.width - width; y: 22; spacing: 12
            OperatorButton { width: 146; text: root.previewOnly ? "保存mock草稿" : root.draft.enabled && root.draftActivationKnown ? "保存并应用提供者" : "保存提供者配置"; primary: true; enabled: root.editable && !root.issues.length && root.dirty; onClicked: root.saveDraft() }
            OperatorButton { width: 136; text: "模型策略面板"; onClicked: root.strategyRequested() }
        }
    }
}
