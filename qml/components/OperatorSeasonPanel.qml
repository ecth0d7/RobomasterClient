import QtQuick

OperatorPanelFrame {
    id: root
    property var runtime: null
    property var links: []
    property var teamRuntime: null
    property var adviceRuntime: null
    property var packageRuntime: null
    property var sceneRuntime: null
    property var speechRuntime: null
    property var voiceRuntime: null
    property var bridgeRuntime: null
    property var viewController: null
    property string draftProfile: ""
    property string draftEnvironment: ""
    property int page: 0
    property var visitedPages: []
    property string feedback: ""
    property string referenceHealth: "10000"
    property bool referenceOutposts: false
    property bool referenceBases: false
    property var tabTitles: ["规则与角色", "数据机会", "接入与部署", "机制推算", "本地数据总线", "收发插件", "队内共享", "模型与建议", "社区插件", "场景渲染", "语音与播报", "实验室桥接"]
    property real tabSpacing: 12
    readonly property var catalogue: sequence(runtime?.profiles)
    readonly property var selected: catalogue.find(entry => entry.id === draftProfile) ?? ({})
    readonly property bool editable: runtime?.editable === true
    readonly property bool dirty: runtime?.context?.configuration_valid === false || draftProfile !== runtime?.profileId || draftEnvironment !== runtime?.environment
    readonly property bool nextSeason: selected.season === 2027
    readonly property var bus: runtime?.terminalBus ?? null
    readonly property var busView: bus?.view ?? ({})
    readonly property var localItems: sequence(busView.items)
    readonly property var opportunities: sequence(selected.data_opportunities)
    readonly property bool healthValid: /^(0|[1-9]\d{0,4})$/.test(referenceHealth) && Number(referenceHealth) <= 10000
    readonly property var logistics: runtime?.profileId === draftProfile && nextSeason && healthValid
        ? runtime.estimateLogistics(Number(referenceHealth)) : ({})
    readonly property var rate: runtime?.profileId === draftProfile && nextSeason
        ? runtime.estimateTerritoryRate(referenceOutposts, referenceBases) : ({})
    signal openExtensionPanelRequested(string packageId, string panelId)
    title: "赛季与规则工作区"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1440
    height: 820
    function visitCurrentPage() {
        if (!visible || page<0 || page>=tabTitles.length || visitedPages.includes(page)) return;
        visitedPages=visitedPages.concat([page]);
    }
    function sequence(value) {
        return value !== null && typeof value === "object" && Number.isInteger(value.length) ? Array.from(value) : [];
    }
    function shown(value) { return value === undefined || value === null || value === "" ? "未提供" : String(value); }
    function reload() {
        draftProfile = runtime?.profileId ?? "";
        draftEnvironment = runtime?.environment ?? "";
        feedback = "";
    }
    function apply() {
        if (!editable || !draftProfile) return;
        feedback = runtime.apply(draftProfile, draftEnvironment)
            ? "已保存，旧连接与服务已退役；新赛季不继承旧线路与授权。" : runtime.status;
    }
    function sourceName(id) {
        return ({official_engine: "官方赛事引擎", official_player_client: "官方选手端导出",
            local_sensor: "本地电控／传感器", local_vision: "本地视觉", derived: "推导值"})[id] ?? shown(id);
    }
    function stateName(id) {
        return ({protocol_pending: "详细协议待取得", adapter_pending: "设备／适配器待接入",
            existing_adapter: "已有2026适配器 · 未最终验收", local_adapter_pending: "本地适配器待接入",
            renderer_pending: "场地标定／渲染待接入", confirmed: "正式规则已核实"})[id] ?? shown(id);
    }
    function percent(value) { return typeof value === "number" ? (value * 100).toFixed(1) + "%" : "—"; }
    function openReferenceView() {
        if (typeof viewController?.openReference !== "function") {
            feedback = "当前宿主未提供保留界面入口";
            return;
        }
        feedback = viewController.openReference("player-2026")
            ? "已打开2026保留界面；其中数值均为离线样例。"
            : viewController.status || "保留界面未能打开，请查看宿主状态";
    }
    onVisibleChanged: if (visible) {reload();visitCurrentPage();}
    Component.onCompleted: visitCurrentPage()
    onPageChanged: {
        visitCurrentPage();
        if (workspace?.contentControl?.contentItem) workspace.contentControl.contentItem.contentY = 0;
    }
    Connections { target: root.runtime; function onContextChanged() { root.reload(); } }

    OperatorSeasonWorkspaceForm {
        id: workspace
        anchors.fill: parent
        selectedPage: root.page
        loadedPages: root.visitedPages
        tabSpacing: root.tabSpacing
        headerTitleText: root.draftProfile
            ? "RMUC " + root.shown(root.selected.season) + " · 正式规则 " + root.shown(root.selected.rules_version) + " · " + root.shown(root.selected.released_on)
            : "等待宿主提供已核实的赛季目录"
        headerDescriptionText: root.nextSeason ? "2027正式规则已归档；9月前瞻仅作历史参考。MQTT + ProtoBuf / UDP通信族已确认，详细报文尚未取得。"
            : "2026全国赛规则、通信协议和界面手册分别版本化；2027区域赛不会沿用旧角色、字段顺序或命令权限。"
        referenceEnabled: typeof root.viewController?.openReference === "function"
        profileTitles: root.catalogue.map(entry => "RMUC " + root.shown(entry.season) + " · "
            + (entry.competition_stage === "regional" ? "区域赛" : entry.competition_stage === "national" ? "全国赛" : "阶段未提供") + " " + root.shown(entry.rules_version))
        profileIndex: root.catalogue.findIndex(entry => entry.id === root.draftProfile)
        profileDisplayText: profileIndex >= 0 && profileIndex < profileTitles.length ? profileTitles[profileIndex] : "明确选择宿主提供的规则版本"
        environmentTitles: ["训练／本地开发", "比赛部署 · 无操作间外通信"]
        environmentIndex: ["training", "competition"].indexOf(root.draftEnvironment)
        environmentDisplayText: environmentIndex >= 0 ? environmentTitles[environmentIndex] : "明确选择宿主提供的部署用途"
        scopeEditable: root.editable
        scopeHintText: root.runtime?.lockReason || "可修改本地规则配置；保存会停止旧连接、图传、建议和共享。"
        tabCount: root.sequence(root.tabTitles).length
        opportunityCount: root.opportunities.length
        feedbackText: root.feedback || root.runtime?.status || "赛季宿主未接通，不保存选择或创建生产能力"
        feedbackEmphasized: root.feedback.length > 0
        undoEnabled: root.editable && root.dirty
        saveEnabled: root.editable && root.dirty && root.draftProfile.length > 0 && environmentIndex >= 0
        tabDelegate: Component {
            OperatorButton {
                required property int index
                objectName: "seasonTab_" + index
                width: workspace.tabDelegateWidth
                height: workspace.controlHeight
                text: root.shown(root.sequence(root.tabTitles)[index])
                primary: root.page === index
                textColor: workspace.textColor
                font.family: workspace.fontFamily
                font.pixelSize: Math.max(workspace.inputSize, 9.5 / Math.max(0.1, hudScale))
                onClicked: root.page = index
            }
        }
        page0Delegate: Component {
            OperatorSeasonRulesForm {
                id: rulesPage
                width: workspace.pageWidth
                rolesIntroText: root.nextSeason ? "重装合并原英雄与工程；指挥手和安全员取代旧云台手／飞手。" : "2026角色与素材保留；本页不修改现有协议。"
                rolesBoundaryText: root.nextSeason ? "规则编号不等于登录ID。蓝方绝对ID、数组顺序与自定义终端会话身份等待2027协议。" : "官方规则与通信接口的版本号互相独立，不能只靠年份判断兼容。"
                roleCount: root.sequence(root.selected.roster).length
                capabilityCount: root.sequence(root.selected.capabilities).length
                formSpacing: workspace.formSpacing
                columnGap: workspace.pageSpacing
                contentMargin: workspace.contentMargin
                bodyTop: workspace.bodyTop
                titleSize: workspace.sectionTitleSize
                noteSize: workspace.noteSize
                inputSize: workspace.inputSize
                fontFamily: workspace.fontFamily
                surfaceColor: workspace.surfaceColor
                textColor: workspace.textColor
                mutedColor: workspace.mutedColor
                warningColor: workspace.warningColor
                separatorColor: workspace.separatorColor
                roleDelegate: Component {
                    OperatorSeasonRoleForm {
                        required property int index
                        readonly property var entry: root.sequence(root.selected.roster)[index] ?? ({})
                        objectName: "seasonRole_" + index
                        width: rulesPage.roleDelegateWidth
                        numberText: entry.rule_number_label ?? "—"
                        titleText: root.shown(entry.title)
                        countText: typeof entry.count === "number" ? "主力数量 " + entry.count : "主力数量未提供"
                        noteSize: workspace.noteSize
                        inputSize: workspace.inputSize
                        fontFamily: workspace.fontFamily
                        surfaceColor: workspace.surfaceColor
                        textColor: workspace.textColor
                        mutedColor: workspace.mutedColor
                        separatorColor: workspace.separatorColor
                    }
                }
                capabilityDelegate: Component {
                    OperatorSeasonCapabilityForm {
                        required property int index
                        readonly property var entry: root.sequence(root.selected.capabilities)[index] ?? ({})
                        objectName: "seasonCapability_" + index
                        width: rulesPage.capabilityDelegateWidth
                        heading: root.shown(entry.title)
                        summaryText: root.shown(entry.summary)
                        referenceText: root.stateName(entry.data_state) + " · " + root.shown(entry.page)
                        contentMargin: workspace.contentMargin
                        bodyTop: workspace.bodyTop
                        titleSize: workspace.sectionTitleSize
                        noteSize: workspace.noteSize
                        inputSize: workspace.inputSize
                        fontFamily: workspace.fontFamily
                        surfaceColor: workspace.surfaceColor
                        textColor: workspace.textColor
                        mutedColor: workspace.mutedColor
                        warningColor: workspace.warningColor
                        separatorColor: workspace.separatorColor
                    }
                }
            }
        }
        opportunityDelegate: Component {
            OperatorSeasonOpportunityForm {
                required property int index
                readonly property var entry: root.opportunities[index] ?? ({})
                objectName: "seasonOpportunity_" + index
                width: workspace.opportunityDelegateWidth
                heading: root.shown(entry.title)
                sourceText: "来源：" + (root.sequence(entry.source_kinds).map(root.sourceName).join(" / ") || "未提供")
                refreshText: "采集／刷新：" + root.shown(entry.refresh)
                trustText: "可信度／时序：" + root.shown(entry.trust)
                useText: "用途：" + (root.sequence(entry.uses).join(" / ") || "未提供") + " · " + root.shown(entry.producer_status) + " · " + root.shown(entry.rule_reference)
                contentMargin: workspace.contentMargin
                bodyTop: workspace.bodyTop
                titleSize: workspace.sectionTitleSize
                noteSize: workspace.noteSize
                inputSize: workspace.inputSize
                fontFamily: workspace.fontFamily
                surfaceColor: workspace.surfaceColor
                textColor: workspace.textColor
                mutedColor: workspace.mutedColor
                warningColor: workspace.warningColor
                separatorColor: workspace.separatorColor
            }
        }
        page2Delegate: Component {
            OperatorSeasonDeploymentForm {
                id: deploymentPage
                width: workspace.pageWidth
                flowTitle: root.nextSeason ? "2027 有线终端路径 · 详细适配待接通" : "2026 官方选手端导出路径"
                flowText: root.nextSeason ? "赛事引擎  →  RJ45 / MQTT + ProtoBuf / UDP  →  自定义终端" : "官方赛事服务器  →  官方选手端  →  MQTT / UDP 导出  →  本客户端"
                localPathText: "电控／传感器／视觉适配器 → 有来源、有时刻、有寿命的本机视图 → 本机HUD与建议\n可选共享 → 认证与完整汇总 → 队伍HUD／AI／指定播报节点；不依赖队友也能使用本机路径。"
                sharingText: root.nextSeason
                    ? "schema3队伍宿主及独立验签已实现；启用须另存参数与提供者并核验证书／新epoch，真实链路与证明待集中验收；无有效时钟映射不得进入队伍AI／语音。"
                    : "2026比赛配置停用客户端间共享；现有队伍模块可用于明确的本地训练，真实认证与原始证明仍待集中验收。"
                competitionText: "比赛中禁止操作间外通信（2027 R33），终端禁止无线（S50）。本项目据此默认停用云端／推理位置未知模型和实验室桥接；这是保守实现推论，不是官方点名AI供应商。"
                speechText: "localhost或本地Codex进程不能证明本地推理。目前没有已核验的全本地推理适配器。比赛模式仅保留经原生身份核对的speech.espeak；原生owner、指定节点与去重已实现，队内播报仍须完整证明、voice授权及独立时钟映射，不表示生产播报已接通。"
                rendererText: "二维与未来UE共用来源数据；更换渲染器前须核验坐标系、标定与变换，不引入UE运行依赖。"
                documentCount: root.sequence(root.selected.documents).length
                sectionSpacing: workspace.pageSpacing
                formSpacing: workspace.formSpacing
                fieldSpacing: workspace.fieldSpacing
                contentMargin: workspace.contentMargin
                bodyTop: workspace.bodyTop
                sectionTitleSize: workspace.sectionTitleSize
                noteSize: workspace.noteSize
                inputSize: workspace.inputSize
                fontFamily: workspace.fontFamily
                surfaceColor: workspace.surfaceColor
                textColor: workspace.textColor
                mutedColor: workspace.mutedColor
                warningColor: workspace.warningColor
                separatorColor: workspace.separatorColor
                documentDelegate: Component {
                    OperatorSeasonDocumentForm {
                        required property int index
                        readonly property var entry: root.sequence(root.selected.documents)[index] ?? ({})
                        objectName: "seasonDocument_" + index
                        width: deploymentPage.documentDelegateWidth
                        heading: root.shown(entry.title)
                        rows: [{label: "版本／状态", value: root.shown(entry.version) + " / " + root.shown(entry.status)},
                               {label: "发布日期", value: root.shown(entry.published_on)},
                               {label: "官方来源", value: root.shown(entry.source_url), detail: true},
                               {label: "项目归档", value: root.shown(entry.local_path), detail: true}]
                        contentMargin: workspace.contentMargin
                        bodyTop: workspace.bodyTop
                        titleSize: workspace.sectionTitleSize
                        noteSize: workspace.noteSize
                        inputSize: workspace.inputSize
                        fontFamily: workspace.fontFamily
                        surfaceColor: workspace.surfaceColor
                        textColor: workspace.textColor
                        mutedColor: workspace.mutedColor
                        warningColor: workspace.warningColor
                        separatorColor: workspace.separatorColor
                    }
                }
            }
        }
        page3Delegate: Component {
            id: mechanicsComponent
            OperatorSeasonMechanicsForm {
                id: mechanicsPage
                width: workspace.pageWidth
                introText: !root.nextSeason ? "机制推算仅适用已核实的2027正式规则，请先选择并保存2027配置。"
                    : root.runtime?.profileId !== root.draftProfile ? "先保存所选2027配置，再使用对应规则推算。"
                    : "手动规则推算 · 非实时比赛数据，不写入遥测、不请求模型、不发送机器人命令。未来只有具备来源／依赖／新鲜度的观测才可进入HUD。"
                healthValue: root.referenceHealth
                logisticsTitle: "后勤系数 λ · 规则 p.94–95"
                territoryTitle: "阵地控制增量 · 规则 p.96–97"
                controlEditable: root.editable && root.nextSeason && root.runtime?.profileId === root.draftProfile
                outpostsValue: root.referenceOutposts
                basesValue: root.referenceBases
                logisticsRows: [{label: "回血／交互带宽系数", value: root.percent(root.logistics.health_multiplier)},
                                {label: "复活时长倍率", value: typeof root.logistics.respawn_time_factor === "number" ? root.logistics.respawn_time_factor.toFixed(3) + "×" : "—"},
                                {label: "图传有效像素面积", value: root.percent(root.logistics.video_pixel_area_factor)}]
                territoryRows: [{label: "每秒增加控制度", value: typeof root.rate.control_points_per_second === "number" ? root.rate.control_points_per_second + " / s" : "—"},
                                {label: "前哨／基地条件", value: "+1/s / +3/s"}]
                healthHint: root.healthValid ? "λ = 1 − (10000 − HP) / 20000；画面变化也可能来自规则后勤机制。" : "输入应为0–10000整数；无效输入不产生推算。"
                territoryNote: "‘控制’不额外解释为‘完全控制’。争夺、状态变化和真实积分必须由核验消息确认；此处不按本机墙钟自动累计分数。"
                sectionSpacing: workspace.pageSpacing
                formSpacing: workspace.formSpacing
                fieldSpacing: workspace.fieldSpacing
                columnGap: workspace.pageSpacing
                controlHeight: workspace.controlHeight
                contentMargin: workspace.contentMargin
                bodyTop: workspace.bodyTop
                sectionTitleSize: workspace.sectionTitleSize
                noteSize: workspace.noteSize
                inputSize: workspace.inputSize
                fontFamily: workspace.fontFamily
                surfaceColor: workspace.surfaceColor
                textColor: workspace.textColor
                mutedColor: workspace.mutedColor
                warningColor: workspace.warningColor
                separatorColor: workspace.separatorColor
                Connections { target: mechanicsPage.healthControl; function onTextEdited() { root.referenceHealth = mechanicsPage.healthControl.text; } }
                Connections { target: mechanicsPage.outpostsControl; function onToggled() { root.referenceOutposts = mechanicsPage.outpostsControl.checked; } }
                Connections { target: mechanicsPage.basesControl; function onToggled() { root.referenceBases = mechanicsPage.basesControl.checked; } }
            }
        }
        page4Delegate: Component {
            OperatorSeasonLocalBusForm {
                id: busPage
                width: workspace.pageWidth
                introText: "本机规范总线已实现；下方演示按钮仅显式生成mock，不连接网络、官方数据或真实传感器，也不转发给AI、语音或机器人。其他实际来源按各自适配器接入；未核验坐标只显示文本。"
                statusText: "schema 3 · 单机独立 · 生产源需独立核验 · 此页不直接请求AI"
                emptyText: "尚无本地观测。可在训练配置中生成明确标记的mock，查看来源、序号、时效与置信度；没有数据不补造比赛值。"
                seedEnabled: root.editable && root.runtime?.environment === "training"
                clearEnabled: root.localItems.length > 0
                observationCount: root.localItems.length
                sectionSpacing: workspace.pageSpacing
                formSpacing: workspace.formSpacing
                fieldSpacing: workspace.fieldSpacing
                controlHeight: workspace.controlHeight
                contentMargin: workspace.contentMargin
                bodyTop: workspace.bodyTop
                sectionTitleSize: workspace.sectionTitleSize
                noteSize: workspace.noteSize
                inputSize: workspace.inputSize
                fontFamily: workspace.fontFamily
                surfaceColor: workspace.surfaceColor
                textColor: workspace.textColor
                mutedColor: workspace.mutedColor
                warningColor: workspace.warningColor
                separatorColor: workspace.separatorColor
                observationDelegate: Component {
                    OperatorSeasonLocalObservationForm {
                        required property int index
                        readonly property var entry: root.localItems[index] ?? ({})
                        objectName: "seasonLocalObservation_" + index
                        width: busPage.observationDelegateWidth
                        titleText: (entry.mock === true ? "MOCK  ·  " : "本机未核验  ·  ") + root.shown(entry.item_id)
                        identityText: "队伍 " + root.shown(entry.team_id) + " / 机器人 " + root.shown(entry.robot_key) + " / 来源 " + root.shown(entry.source_id) + " / 传感器 " + root.shown(entry.sensor_id)
                        valueText: "值：" + (entry.value === undefined || entry.value === null ? "未知" : JSON.stringify(entry.value)) + "    置信度：" + (typeof entry.confidence === "number" ? entry.confidence.toFixed(2) : "未知")
                        timingText: "状态 " + root.shown(entry.state) + " / 序号 " + root.shown(entry.sequence) + " / 接收年龄 " + root.shown(entry.received_age_ms) + " ms / 剩余寿命 " + root.shown(entry.remaining_ms) + " ms"
                        verificationText: "验证 " + root.shown(entry.validation) + " / 产生时间 " + root.shown(entry.produced_at_ms) + " / 接收时间 " + root.shown(entry.received_at_ms) + " / 坐标 " + root.shown(entry.spatial_status) + " / 不授予模型或动作权限"
                        fieldSpacing: workspace.fieldSpacing
                        contentMargin: workspace.contentMargin
                        bodyTop: workspace.bodyTop
                        sectionTitleSize: workspace.sectionTitleSize
                        noteSize: workspace.noteSize
                        inputSize: workspace.inputSize
                        fontFamily: workspace.fontFamily
                        surfaceColor: workspace.surfaceColor
                        textColor: workspace.textColor
                        mutedColor: workspace.mutedColor
                        warningColor: workspace.warningColor
                        separatorColor: workspace.separatorColor
                    }
                }
                Connections { target: busPage.seedControl; function onClicked() { if (busPage.seedEnabled && root.runtime) root.runtime.seedLocalDemo(); } }
                Connections { target: busPage.clearControl; function onClicked() { if (busPage.clearEnabled && root.runtime) root.runtime.clearLocalDemo(); } }
            }
        }
        // Every configuration page is instantiated once, even while hidden.
        // Switching tabs does not dispose provider identities or unsaved drafts.
        page5Delegate: Component { OperatorTerminalLinkSetup { width: workspace.pageWidth; gateways: root.links } }
        page6Delegate: Component { OperatorTerminalTeamSetup { width: workspace.pageWidth; runtime: root.teamRuntime; seasonRuntime: root.runtime } }
        page7Delegate: Component { OperatorTerminalAdviceSetup { width: workspace.pageWidth; runtime: root.adviceRuntime; seasonRuntime: root.runtime; teamRuntime: root.teamRuntime } }
        page8Delegate: Component {
            OperatorPluginPackages {
                width: workspace.pageWidth
                runtime: root.packageRuntime
                onOpenExtensionPanelRequested: function(packageId, panelId) { root.openExtensionPanelRequested(packageId, panelId); }
            }
        }
        page9Delegate: Component { OperatorTerminalSceneSetup { width: workspace.pageWidth; runtime: root.sceneRuntime } }
        page10Delegate: Component {
            Column {
                width: workspace.pageWidth
                spacing: 24
                OperatorTerminalSpeechSetup { width: parent.width; runtime: root.speechRuntime }
                OperatorTerminalVoiceSetup { width: parent.width; runtime: root.voiceRuntime; seasonRuntime: root.runtime; teamRuntime: root.teamRuntime; adviceRuntime: root.adviceRuntime }
            }
        }
        page11Delegate: Component { OperatorTerminalBridgeSetup { width: workspace.pageWidth; runtime: root.bridgeRuntime } }
    }
    Connections { target: workspace.referenceControl; function onClicked() { root.openReferenceView(); } }
    Connections {
        target: workspace.profileControl
        function onActivated(index) {
            if (!root.editable || index < 0 || index >= root.catalogue.length) return;
            root.draftProfile = root.catalogue[index].id; root.feedback = "";
        }
    }
    Connections {
        target: workspace.environmentControl
        function onActivated(index) {
            if (!root.editable || index < 0 || index > 1) return;
            root.draftEnvironment = ["training", "competition"][index]; root.feedback = "";
        }
    }
    Connections { target: workspace.undoControl; function onClicked() { if (root.editable) root.reload(); } }
    Connections { target: workspace.saveControl; function onClicked() { if (workspace.saveEnabled) root.apply(); } }
}
