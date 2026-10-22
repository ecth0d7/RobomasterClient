import QtQuick
import "OperatorStartupPolicy.js" as Startup

OperatorPanelFrame {
    id: root
    property var preferences: null
    property var runtime: null
    property var telemetry: null
    property var connection: null
    property var seasonRuntime: null
    property int clientID: 0
    property bool previewOnly: false
    property int page: 0
    property var draft: Startup.defaults()
    property string feedback: ""
    property bool saveError: false
    property alias drawing: form
    readonly property bool cold: clientID === 0 && connection?.connected !== true && connection?.connecting !== true
    readonly property bool editable: preferences !== null
    readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(preferences?.current)
    readonly property bool valid: Startup.valid(draft)
    readonly property string phaseText: "启动草稿可编辑 · 不受比赛阶段限制"
    readonly property var tabTitles: ["选手端连接", "图传 / 绘制", "插件 / 迁移", "本次运行"]
    readonly property var codecIds: ["hevc", "h264", "auto"]
    readonly property var codecTitles: ["H.265 / HEVC · 历史2026基线", "H.264 · 本地联调或已确认源", "自动识别 · 等待参数集确认"]
    readonly property var rendererIds: ["auto", "software", "opengl"]
    readonly property var rendererTitles: ["自动 · 可用时加速，OpenGL失败转软件", "软件绘制 · 兼容模式", "强制OpenGL · 不可用时正常报错退出"]
    signal loginRequested
    signal loadProfileRequested
    signal saveProfileRequested(var connectionOptions, string purpose)
    signal connectAddressRequested(string host, int port)
    title: "高级启动草稿 · 下次启动"
    iconAsset: "ServerUI_Setting"
    accent: Theme.text
    backgroundSource: "../resources/engine-137/sprites/setting_bg_1.png"
    width: 1440
    height: 780

    onVisibleChanged: if (visible) reload()
    Connections {
        target: root.preferences
        function onCurrentChanged() { root.reload(); }
    }
    function reload() {
        draft = Object.assign({}, preferences?.current ?? Startup.defaults());
        feedback = "";
        saveError = false;
    }
    function setValue(key, value) {
        if (!editable || !Object.prototype.hasOwnProperty.call(Startup.defaults(), key)) return;
        draft = Object.assign({}, draft, {[key]: value});
        feedback = "";
        saveError = false;
    }
    function selectPurpose(id) {
        if (!editable) return;
        draft = Startup.preset(id, draft);
        feedback = "";
        saveError = false;
    }
    function saveDraft() {
        if (!editable || !valid || !preferences) return;
        saveError = !preferences.save(draft);
        feedback = saveError ? "草稿未保存，请检查字段与容量。" : previewOnly ? "已保存本窗口草稿 · 未写启动文件或改变本次服务" : "已保存本地UI草稿 · 启动文件写入与应用尚未接通";
    }
    function sequence(value) {
        // Qt QVariantList is array-like rather than a JavaScript Array.
        return value !== null && typeof value === "object" && Number.isInteger(value.length)
            && value.length >= 0 && value.length <= 1024 ? Array.from(value) : [];
    }
    function fieldValue(key) { return typeof draft[key] === "string" ? draft[key] : ""; }
    function caption(titles, index, empty) { return index >= 0 && index < titles.length ? titles[index] : empty; }
    function plugins(role) {
        return sequence(runtime?.pluginCatalog).filter(entry => entry && entry.role === role
            && entry.available === true && typeof entry.id === "string").slice(0, 32);
    }

    OperatorStartupPanelForm {
        id: form
        anchors.fill: parent
        drawingBackgroundVisible: false
        selectedPage: root.page
        tabCount: root.tabTitles.length
        pluginCount: Startup.pluginRoles.length
        inputEditable: root.editable
        phaseText: root.phaseText
        phaseWarning: !root.editable
        statusText: root.runtime?.status ?? "生产启动配置尚未公开 · 这里的草稿不代表本次实际配置"
        statusWarning: !!root.runtime?.warning
        headerHintText: root.editable ? "本页编辑下次启动草稿；本次连接、UDP和身份请在连接与登录页修改" : "本页仅查看已保存草稿；修改本次连接、UDP或身份请返回连接与登录页"
        nameValue: root.fieldValue("name")
        nameError: Startup.error(root.draft.name, "name")
        purposeChoices: Startup.purposes.map(entry => entry.title)
        purposeIndex: Startup.purposes.findIndex(entry => entry.id === root.draft.purpose)
        purposeSelectionText: root.caption(purposeChoices, purposeIndex, "请选择启动用途")
        purposeNoteText: Startup.purposes.find(entry => entry.id === root.draft.purpose)?.note ?? "未提供用途说明。"
        dataPathText: root.seasonRuntime?.current?.season === 2027
            ? "2027正式规则允许赛事引擎 → RJ45有线 → 自定义终端，并允许操作间内有线互联。详细协议未取得，本页旧MQTT／UDP参数属于2026草稿，不用于2027连接。"
            : "2026比赛路径：官方赛事服务器 → 官方选手端 → 本自定义客户端。机器人编号在身份页选择，必须与选手端一致；连通不代表发布者已认证。"
        hostLabel: root.draft.purpose === "laboratory" ? "本地联调导出地址" : "官方选手端导出地址"
        hostValue: root.fieldValue("host")
        hostError: Startup.error(root.draft.host, "host")
        mqttPortValue: root.fieldValue("mqttPort")
        mqttPortError: Startup.error(root.draft.mqttPort, "mqttPort")
        messageBoundaryText: root.editable ? "改变草稿不会建立连接。点击‘带入地址并选择身份’只填写连接页，确认身份后才能连接。" : "当前草稿只读。‘返回连接与登录’保留本次连接地址，不带入草稿，也不发起连接。"
        videoBindValue: root.fieldValue("videoBind")
        videoBindError: Startup.error(root.draft.videoBind, "videoBind")
        videoPortValue: root.fieldValue("videoPort")
        videoPortError: Startup.error(root.draft.videoPort, "videoPort")
        codecChoices: root.codecTitles
        codecIndex: root.codecIds.indexOf(root.draft.videoCodec)
        codecSelectionText: root.caption(codecChoices, codecIndex, "请选择视频编码")
        videoBoundaryText: "配置不等于收到画面。解码、帧年龄、实收帧率在服务状态核对；未接数据不能伪造1920×1080或60帧实测。"
        rendererChoices: root.rendererTitles
        rendererIndex: root.rendererIds.indexOf(root.draft.renderer)
        rendererSelectionText: root.caption(rendererChoices, rendererIndex, "请选择绘制后端")
        rendererBoundaryText: "第一扇窗口前决定后端，此处只保存下次启动草稿。自动保留平台原生后端，默认OpenGL失败可退软件；显式启动环境约束保留或明确报错。软件用CPU，实际性能待最后验收，比赛中不切换。"
        rendererRows: [
            {label: "实际绘制", value: Startup.text(root.runtime?.rendererActual), detail: true},
            {label: "回退原因", value: Startup.text(root.runtime?.rendererReason), detail: true}
        ]
        uiDirValue: root.fieldValue("uiDir")
        uiDirError: Startup.error(root.draft.uiDir, "uiDir")
        pluginDirValue: root.fieldValue("pluginDir")
        pluginDirError: Startup.error(root.draft.pluginDir, "pluginDir")
        migrationText: "本项目使用的图像与字体都在UI包中；迁移要带完整程序、Qt运行库、插件、UI／资源和配置。路径可以含中文或空格，不作为Shell命令执行。目录发现与依赖检查由宿主完成。"
        pluginCatalogText: !root.runtime
            ? "尚未公开本地发现清单，不能虚构可选插件；保留草稿ID供后续宿主核对。"
            : root.previewOnly ? "清单由宿主提供；图中是离线元数据样例，不证明依赖可加载。核心插件缺失时不能启动操作模式。"
            : "清单由宿主提供，仅表示发现的元数据，不证明依赖可加载。核心插件缺失时不能启动操作模式。"
        optionalModulesText: "队伍汇总、感知数据源、模型和语音属于独立可选模块，在各自页面配置。可选模块缺失／卸载必须不阻塞单机客户端；真实链路与生产隔离仍待集中验收。"
        runtimeTitle: !root.runtime ? "未取得本次运行配置" : root.previewOnly ? "离线运行配置样例" : "宿主公开配置"
        runtimeRows: Startup.runtimeRows(root.runtime)
        pendingText: root.runtime?.pendingRestart === true
            ? root.previewOnly ? "宿主提示：有等待下次启动的配置。此处样例不触发重启。" : "宿主提示：有等待下次启动的配置；本页不会自动重启。"
            : "没有可核验的待启动配置。保存UI草稿不证明已经写入启动文件。"
        savedRows: [
            {label: "名称", value: Startup.text(root.preferences?.current?.name)},
            {label: "下次用途", value: Startup.purpose(root.preferences?.current?.purpose)},
            {label: "导出地址", value: Startup.text(root.preferences?.current?.host), detail: true},
            {label: "下次绘制选择", value: Startup.renderer(root.preferences?.current?.renderer)}
        ]
        loadProfileText: root.runtime?.capabilities?.loadProfile === true ? "读取启动配置文件" : "读取启动配置文件 · 待接通"
        loadProfileEnabled: root.editable && root.runtime?.capabilities?.loadProfile === true
        saveProfileText: root.runtime?.capabilities?.saveProfile === true ? "写入启动配置文件" : "写入启动配置文件 · 待接通"
        saveProfileEnabled: root.editable && root.valid && !root.dirty && root.runtime?.capabilities?.saveProfile === true
        fileBoundaryText: "文件读写、字段合并、依赖检查与仅准备模式的生产启动控制尚未接通。本界面不会删除原profile的模型／语音配置，也不会自动重启或连接设备；最后统一联调。"
        feedbackText: root.feedback || (!root.editable ? "配置宿主未接通，当前只读。" : !root.valid ? "输入格式有误，请查看各字段提示；草稿未保存。" : root.dirty ? "有未保存草稿；本次运行配置保持原样。" : "已保存UI草稿与本次实际配置分别显示。")
        feedbackColor: root.saveError || !root.valid ? form.warningColor : root.feedback ? Theme.green : form.mutedColor
        undoEnabled: root.editable && root.dirty
        saveEnabled: root.editable && root.valid && root.dirty
        saveText: root.previewOnly ? "保存本窗口草稿" : "保存本地UI草稿"
        connectText: root.editable ? "带入地址并选择身份" : "返回连接与登录"
        connectEnabled: !root.editable || root.valid && root.draft.purpose !== "preparation"
        tabDelegate: Component {
            OperatorButton {
                required property int index
                objectName: "startupTab_" + index
                width: form.tabDelegateWidth
                height: form.controlHeight
                text: root.tabTitles[index]
                primary: root.page === index
                textColor: form.textColor
                font.family: form.fontFamily
                font.pixelSize: Math.max(form.inputSize, 9.5 / Math.max(0.1, hudScale))
                onClicked: root.page = index
            }
        }
        pluginDelegate: Component {
            OperatorStartupPluginRowForm {
                id: pluginRow
                required property int index
                readonly property var role: Startup.pluginRoles[index] ?? ({})
                readonly property var candidates: root.plugins(role.role)
                readonly property string savedId: root.fieldValue(role.key)
                objectName: "startupPlugin_" + (role.role ?? index)
                width: form.pluginDelegateWidth
                titleText: role.title ?? "未提供插件角色"
                selectionLabel: "下次启动的" + (role.title ?? "未提供角色") + "插件"
                draftText: "草稿ID：" + (savedId || "未提供")
                choices: candidates.map(entry => entry.title ?? entry.id)
                selectedIndex: candidates.findIndex(entry => entry.id === savedId)
                selectionText: root.caption(choices, selectedIndex, !root.runtime ? "本地发现清单尚未公开" : candidates.length ? "草稿ID不在可选清单" : "此角色暂无可选插件")
                inputEditable: root.editable && candidates.length > 0
                labelHeight: form.labelHeight
                labelGap: form.labelGap
                controlHeight: form.controlHeight
                hintGap: form.fieldSpacing
                minimumHintHeight: form.minimumHintHeight
                hintBottomPadding: form.hintBottomPadding
                labelSize: form.labelSize
                inputSize: form.inputSize
                noteSize: form.noteSize
                fontFamily: form.fontFamily
                inputFontFamily: form.inputFontFamily
                textColor: form.textColor
                mutedColor: form.mutedColor
                warningColor: form.warningColor
                inputSurfaceColor: form.inputSurfaceColor
                inputBorderColor: form.inputBorderColor
                Connections {
                    target: pluginRow.selectControl
                    function onActivated(index) {
                        const candidate = pluginRow.candidates[index];
                        if (candidate) root.setValue(pluginRow.role.key, candidate.id);
                    }
                }
            }
        }
    }
    Connections {
        target: form.nameControl
        function onTextEdited() { root.setValue("name", form.nameControl.text); }
    }
    Connections {
        target: form.hostControl
        function onTextEdited() { root.setValue("host", form.hostControl.text); }
    }
    Connections {
        target: form.mqttPortControl
        function onTextEdited() { root.setValue("mqttPort", form.mqttPortControl.text); }
    }
    Connections {
        target: form.videoBindControl
        function onTextEdited() { root.setValue("videoBind", form.videoBindControl.text); }
    }
    Connections {
        target: form.videoPortControl
        function onTextEdited() { root.setValue("videoPort", form.videoPortControl.text); }
    }
    Connections {
        target: form.uiDirControl
        function onTextEdited() { root.setValue("uiDir", form.uiDirControl.text); }
    }
    Connections {
        target: form.pluginDirControl
        function onTextEdited() { root.setValue("pluginDir", form.pluginDirControl.text); }
    }
    Connections {
        target: form.purposeControl
        function onActivated(index) {
            const choice = Startup.purposes[index];
            if (choice) root.selectPurpose(choice.id);
        }
    }
    Connections {
        target: form.codecControl
        function onActivated(index) {
            if (index >= 0 && index < root.codecIds.length) root.setValue("videoCodec", root.codecIds[index]);
        }
    }
    Connections {
        target: form.rendererControl
        function onActivated(index) {
            if (index >= 0 && index < root.rendererIds.length) root.setValue("renderer", root.rendererIds[index]);
        }
    }
    Connections { target: form.undoControl; function onClicked() { root.reload(); } }
    Connections { target: form.saveControl; function onClicked() { root.saveDraft(); } }
    Connections {
        target: form.connectControl
        function onClicked() {
            if (!root.editable) root.loginRequested();
            else if (root.valid && root.draft.purpose !== "preparation")
                root.connectAddressRequested(root.draft.host, Startup.port(root.draft.mqttPort));
        }
    }
    Connections { target: form.loadProfileControl; function onClicked() { root.loadProfileRequested(); } }
    Connections { target: form.saveProfileControl; function onClicked() { root.saveProfileRequested(Startup.connectionPatch(root.draft), root.draft.purpose); } }
}
