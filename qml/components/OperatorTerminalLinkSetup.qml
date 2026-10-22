import QtQuick

OperatorTerminalLinkPageForm {
    id: root
    property var gateways: []
    property int plane: 0
    property string pluginId: ""
    property var packageOptions: ({})
    property var providerDrafts: ({})
    property string savedConfigurationSnapshot: ""
    property string loadedConfiguration: ""
    property string loadedScope: ""
    property string feedback: ""
    property string host: ""
    property string port: ""
    property string clientId: ""
    property string receiveTopics: ""
    property string sendTopics: ""
    property string bindAddress: "127.0.0.1"
    property string bindPort: "0"
    property string peerAddress: ""
    property string peerPort: ""
    property string rawHex: ""
    property string sendChannel: ""
    property bool sendConfirmed: false
    property string confirmedActivation: ""
    readonly property var runtime: gateways[plane]?.runtime ?? null
    readonly property var modules: list(runtime?.modules)
    readonly property var packets: list(runtime?.receivedPackets)
    readonly property var actual: runtime?.details ?? ({})
    readonly property var appliedConfiguration: runtime?.configuration ?? ({})
    readonly property bool mqtt: pluginId === "terminal.link.mqtt.v1"
    readonly property bool udp: pluginId === "terminal.link.udp.v1"
    readonly property bool loopback: pluginId === "terminal.link.loopback.v1"
    readonly property bool packageProvider: pluginId === "package"
    readonly property bool editable: runtime?.editable === true
    readonly property bool active: runtime?.active === true
    readonly property string draftSnapshot: JSON.stringify({plugin_id: pluginId, options: draftValues(false)})
    readonly property bool dirty: draftSnapshot !== savedConfigurationSnapshot
    readonly property bool configurationSaved: appliedConfiguration.configuration_saved === true && actual.configuration_saved === true
    readonly property bool applied: !dirty && configurationSaved && pluginId === appliedConfiguration.plugin_id
        && sameOptions(draftValues(true), appliedConfiguration.options ?? ({}))
    readonly property int providerIndex: modules.findIndex(entry => matches(entry, pluginId, packageOptions))
    readonly property var selectedModule: modules[providerIndex] ?? ({})
    readonly property var channels: loopback ? ["local"] : udp ? ["peer"] : mqtt ? list(appliedConfiguration.options?.send_topics) : []
    readonly property string formError: configurationError()

    function sequence(value) {
        return value !== null && typeof value === "object" && Number.isInteger(value.length) && value.length >= 0;
    }
    function list(value) {
        // QVariantList／QStringList在QML是Qt序列，不依赖Array.isArray识别原生主题。
        return sequence(value) ? Array.from(value) : [];
    }
    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function string(value) { return value === undefined || value === null ? "" : String(value); }
    function shown(value) { return value === undefined || value === null || value === "" ? "未提供" : String(value); }
    function providerKey(id, options) { return id === "package" ? JSON.stringify([id, options?.package_id ?? "", options?.service_name ?? ""]) : id; }
    function matches(entry, id, values) {
        if (entry.id !== id) return false;
        const candidate = entry.options ?? ({});
        return id !== "package" || providerKey(id, candidate) === providerKey(id, values)
            && candidate.package_fingerprint === values.package_fingerprint && candidate.configuration_fingerprint === values.configuration_fingerprint;
    }
    function topics(text) { return text.split(/[\n,]/).map(value => value.trim()).filter(value => value.length > 0); }
    function draftValues(normalized) {
        if (packageProvider) return clone(packageOptions);
        if (mqtt) return {host: normalized ? host.trim() : host, port: normalized ? Number(port) : port,
            client_id: normalized ? clientId.trim() : clientId, receive_topics: normalized ? topics(receiveTopics) : receiveTopics,
            send_topics: normalized ? topics(sendTopics) : sendTopics};
        if (udp) return {bind_address: normalized ? bindAddress.trim() : bindAddress, bind_port: normalized ? Number(bindPort) : bindPort,
            peer_address: normalized ? peerAddress.trim() : peerAddress, peer_port: normalized ? Number(peerPort) : peerPort};
        return {};
    }
    function sameOptions(left, right) {
        const names = Object.keys(left).sort();
        if (JSON.stringify(names) !== JSON.stringify(Object.keys(right).sort())) return false;
        return names.every(name => sequence(left[name]) || sequence(right[name])
            ? sequence(left[name]) && sequence(right[name]) && JSON.stringify(list(left[name])) === JSON.stringify(list(right[name]))
            : left[name] === right[name]);
    }
    function nativeSnapshot() {
        return JSON.stringify({plugin_id: appliedConfiguration.plugin_id ?? "", options: appliedConfiguration.options ?? {}, configuration_saved: appliedConfiguration.configuration_saved === true});
    }
    function scopeKey() { return JSON.stringify([gateways[plane]?.id ?? "", actual.context ?? {}, actual.environment ?? ""]); }
    function loadOptions(options) {
        packageOptions = packageProvider ? clone(options) : ({});
        host = string(options.host); port = string(options.port); clientId = string(options.client_id);
        receiveTopics = sequence(options.receive_topics) ? list(options.receive_topics).join("\n") : string(options.receive_topics);
        sendTopics = sequence(options.send_topics) ? list(options.send_topics).join("\n") : string(options.send_topics);
        bindAddress = options.bind_address ?? "127.0.0.1"; bindPort = string(options.bind_port ?? 0);
        peerAddress = string(options.peer_address); peerPort = string(options.peer_port);
    }
    function reload() {
        pluginId = appliedConfiguration.plugin_id ?? "";
        loadOptions(appliedConfiguration.options ?? ({}));
        savedConfigurationSnapshot = draftSnapshot;
        loadedConfiguration = nativeSnapshot(); loadedScope = scopeKey();
        providerDrafts = {};
        // 允许列表不是发送意图；每次装入／更换配置都等待明确选择通道。
        sendChannel = "";
        sendConfirmed = false; confirmedActivation = ""; feedback = "";
    }
    function synchronize() {
        if (loadedScope !== scopeKey()) { rawHex = ""; reload(); }
        else if (!dirty && loadedConfiguration !== nativeSnapshot()) reload();
        if (sendConfirmed && (!active || actual.activation_id !== confirmedActivation)) sendConfirmed = false;
    }
    function selectProvider(index) {
        const entry = modules[index];
        if (!editable || !entry) return;
        const cache = clone(providerDrafts);
        if (pluginId) cache[providerKey(pluginId, packageOptions)] = draftValues(false);
        providerDrafts = cache;
        const key = providerKey(entry.id, entry.options);
        const values = clone(cache[key] ?? entry.options ?? ({}));
        if (entry.id === "package") for (const name of ["package_id", "service_name", "package_fingerprint", "configuration_fingerprint"])
            values[name] = entry.options?.[name];
        pluginId = entry.id;
        loadOptions(values);
        // 允许列表不是发送意图；每次装入／更换配置都等待明确选择通道。
        sendChannel = "";
        sendConfirmed = false; feedback = "";
    }
    function refreshModules() {
        if (!editable || typeof runtime?.refreshModules !== "function") return;
        runtime.refreshModules();
        feedback = "已刷新原生传输目录；当前完整选择与未保存参数保持不变，没有自动启用链路。";
    }
    function configurationError() {
        if (!runtime) return "独立链路宿主尚未提供。";
        if (!pluginId) return "明确选择传输插件；不会默认选择回环或网络插件。";
        if (mqtt) {
            if (!host.trim() || !clientId.trim() || !/^\d+$/.test(port) || Number(port) < 1 || Number(port) > 65535) return "填写MQTT地址、明确客户端标识及1–65535端口。";
            const receive = topics(receiveTopics), send = topics(sendTopics);
            if (receive.length > 32 || send.length > 32 || (!receive.length && !send.length)) return "接收／发送主题分别最多32项，至少明确一项。";
            if (receive.concat(send).some(value => /[+#]/.test(value)) || receive.some(value => send.includes(value))) return "使用明确主题，不使用通配符；收发主题必须分开以避免自回环。";
        }
        if (udp && (!bindAddress.trim() || !peerAddress.trim() || !/^\d+$/.test(bindPort) || Number(bindPort) > 65535
            || !/^\d+$/.test(peerPort) || Number(peerPort) < 1 || Number(peerPort) > 65535)) return "填写明确数字IP、本机0–65535端口及对端1–65535端口；IP由原生宿主进一步核验。";
        if (packageProvider && (!/^[0-9a-f]{64}$/.test(string(packageOptions.package_fingerprint))
            || !/^[0-9a-f]{64}$/.test(string(packageOptions.configuration_fingerprint)) || !packageOptions.package_id || !packageOptions.service_name))
            return "从原生目录选择包含完整包／服务身份的能力，不能填写任意插件路径。";
        return "";
    }
    function configure() {
        if (!editable || !runtime) return;
        if (formError) { feedback = formError; return; }
        const accepted = runtime.configure(pluginId, draftValues(true)), status = runtime.status;
        if (accepted) reload();
        feedback = status;
    }
    function sendRaw() {
        if (!editable || !active || !applied || !sendConfirmed || confirmedActivation !== actual.activation_id) return;
        runtime.sendTrainingHex(sendChannel.trim(), rawHex, sendConfirmed);
        feedback = runtime.status; sendConfirmed = false;
    }
    onRuntimeChanged: { providerDrafts = {}; rawHex = ""; reload(); }
    onVisibleChanged: if (visible) synchronize()
    onDirtyChanged: if (dirty) sendConfirmed = false
    onRawHexChanged: sendConfirmed = false
    onSendChannelChanged: sendConfirmed = false
    Component.onCompleted: reload()
    Connections { target: root.runtime; function onChanged() { root.synchronize(); } }

    planeTitles: list(gateways).map(entry => entry.title)
    providerTitles: modules.map(entry => ({"terminal.link.loopback.v1": "本机字节回环", "terminal.link.mqtt.v1": "MQTT原始字节", "terminal.link.udp.v1": "UDP原始数据报"}[entry.id] || entry.title || entry.id) + (entry.available === false ? " · 未就绪" : ""))
    planeSelectedIndex: gateways[plane] ? plane : -1
    providerSelectedIndex: providerIndex
    planeEditable: !dirty
    providerEditable: editable
    refreshEnabled: editable && typeof runtime?.refreshModules === "function"
    configurationEditable: editable
    providerEmptyText: pluginId ? "未发现当前选择；保留身份，不自动替换" : "请选择传输提供者；不自动选择或连接"
    dirtyMessage: dirty ? "当前存在未保存配置。保存或撤销后再切换独立平面；启用和发送只使用已保存且匹配的当前配置。" : ""
    lockMessage: editable ? "" : runtime?.lockReason || "配置当前只读；不能修改主题或提交训练字节。"
    unsavedMessage: !!runtime && !configurationSaved ? "当前范围尚未明确保存传输配置。默认模板不构成启用许可，保存后仍须手动启用。" : ""
    providerStatusRows: [
        {label: "已保存插件", value: shown(appliedConfiguration.plugin_id)},
        {label: "当前范围已保存", value: configurationSaved ? "是；不会自动启动" : "否"},
        {label: "已保存提供者可用", value: actual.provider_available === true ? "原生能力就绪" : "未就绪／内容变化；不自动回退"},
        {label: "实际原生能力", value: actual.provider_identity?.package_id ? actual.provider_identity.package_id + " / " + shown(actual.provider_identity.service_name) : shown(actual.provider_identity?.plugin_id), detail: true},
        {label: "配置文件", value: shown(actual.settings_file), detail: true}
    ]
    showPackage: packageProvider
    showMqtt: mqtt
    showUdp: udp
    showLoopback: loopback
    packageWarningVisible: providerIndex < 0 || selectedModule.available === false
    packageIdentityRows: [
        {label: "包ID／导出服务", value: shown(packageOptions.package_id) + " / " + shown(packageOptions.service_name), detail: true},
        {label: "包内容指纹", value: shown(packageOptions.package_fingerprint), detail: true},
        {label: "配置指纹", value: shown(packageOptions.configuration_fingerprint), detail: true}
    ]
    hostValue: host
    portValue: port
    clientIdValue: clientId
    receiveTopicsValue: receiveTopics
    sendTopicsValue: sendTopics
    bindAddressValue: bindAddress
    bindPortValue: bindPort
    peerAddressValue: peerAddress
    peerPortValue: peerPort
    validationMessage: formError
    statusText: feedback || runtime?.status || "可选链路宿主未提供，没有启动传输。"
    statusEmphasized: feedback.length > 0
    saveEnabled: editable && pluginId.length > 0 && (dirty || !configurationSaved)
    enableEnabled: editable && applied && actual.provider_available === true && !active
    stopEnabled: active
    undoEnabled: editable && dirty
    mockEnabled: editable && loopback && applied && active
    channelTitles: channels
    channelSelectedIndex: channels.indexOf(sendChannel)
    channelSelectionText: channelSelectedIndex >= 0 ? channels[channelSelectedIndex] : "明确选择已保存配置允许的发送通道"
    packageChannelValue: sendChannel
    payloadValue: rawHex
    channelEditable: editable && applied
    confirmationValue: sendConfirmed
    confirmationEnabled: editable && applied && active
    sendEnabled: editable && active && applied && sendConfirmed && sendChannel.trim().length > 0
        && rawHex.trim().length > 0 && confirmedActivation === actual.activation_id
    transferRows: [
        {label: "已提交／已接收", value: shown(actual.sent_packets) + " / " + shown(actual.received_packets)},
        {label: "发送／接收字节", value: shown(actual.sent_bytes) + " / " + shown(actual.received_bytes)},
        {label: "规范总线接纳／拒绝", value: shown(actual.normalized_packets) + " / " + shown(actual.normalization_rejected)},
        {label: "连接／当前激活", value: (actual.connected === true ? "插件报告已连接" : "未确认连接") + " / " + shown(actual.activation_id), detail: true},
        {label: "官方协议绑定", value: actual.official_protocol_bound === true ? "已绑定" : "未绑定；中性字节收发不授予官方权威", detail: true},
        {label: "发送确认边界", value: "本地提交不等于远端送达或机器人执行；原始包不自动成为AI输入", detail: true}
    ]
    packetCount: packets.length
    packetDelegate: Component {
        OperatorDiagnosticTable {
            required property int index
            readonly property var packet: root.packets[index] ?? ({})
            objectName: "terminalLinkReceivedPacket_" + index
            width: root.packetDelegateWidth
            title: "接收包 " + root.shown(packet.packet_id)
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            fontFamily: root.fontFamily
            textColor: root.textColor
            mutedColor: root.mutedColor
            separatorColor: root.separatorColor
            outlineColor: root.separatorColor
            labelSize: root.noteSize
            valueSize: root.inputSize
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            rows: [
                {label: "通道／对端", value: root.shown(packet.channel) + " / " + root.shown(packet.peer), detail: true},
                {label: "实际字节", value: root.shown(packet.bytes)},
                {label: "接收十六进制预览", value: (packet.preview_hex || "空载荷") + (packet.preview_truncated ? " …仅预览前1024字节" : ""), detail: true},
                {label: "解码／规范化", value: packet.normalized ? "已接纳项目本地观测" : packet.normalization_status || "原始字节；无匹配字段绑定", detail: true}
            ]
        }
    }
    Connections {
        target: root.planeControl
        function onActivated(index) { if (!root.dirty && index >= 0 && index < root.gateways.length) root.plane = index; }
    }
    Connections { target: root.providerControl; function onActivated(index) { root.selectProvider(index); } }
    Connections { target: root.refreshControl; function onClicked() { root.refreshModules(); } }
    Connections { target: root.hostControl; function onTextEdited() { if (root.editable) root.host = root.hostControl.text; } }
    Connections { target: root.portControl; function onTextEdited() { if (root.editable) root.port = root.portControl.text; } }
    Connections { target: root.clientIdControl; function onTextEdited() { if (root.editable) root.clientId = root.clientIdControl.text; } }
    Connections { target: root.receiveTopicsControl; function onTextChanged() { if (root.editable && root.receiveTopicsControl.text !== root.receiveTopics) root.receiveTopics = root.receiveTopicsControl.text; } }
    Connections { target: root.sendTopicsControl; function onTextChanged() { if (root.editable && root.sendTopicsControl.text !== root.sendTopics) root.sendTopics = root.sendTopicsControl.text; } }
    Connections { target: root.bindAddressControl; function onTextEdited() { if (root.editable) root.bindAddress = root.bindAddressControl.text; } }
    Connections { target: root.bindPortControl; function onTextEdited() { if (root.editable) root.bindPort = root.bindPortControl.text; } }
    Connections { target: root.peerAddressControl; function onTextEdited() { if (root.editable) root.peerAddress = root.peerAddressControl.text; } }
    Connections { target: root.peerPortControl; function onTextEdited() { if (root.editable) root.peerPort = root.peerPortControl.text; } }
    Connections { target: root.saveControl; function onClicked() { root.configure(); } }
    Connections { target: root.enableControl; function onClicked() { if (root.enableEnabled) root.runtime.setEnabled(true); } }
    Connections { target: root.stopControl; function onClicked() { if (root.active) root.runtime.stop(); } }
    Connections { target: root.undoControl; function onClicked() { if (root.undoEnabled) root.reload(); } }
    Connections { target: root.mockControl; function onClicked() { if (root.mockEnabled) root.runtime.sendMock(); } }
    Connections {
        target: root.channelControl
        function onActivated(index) { if (root.channelEditable && index >= 0 && index < root.channels.length) root.sendChannel = root.channels[index]; }
    }
    Connections { target: root.packageChannelControl; function onTextEdited() { if (root.editable) root.sendChannel = root.packageChannelControl.text; } }
    Connections { target: root.payloadControl; function onTextChanged() { if (root.editable && root.payloadControl.text !== root.rawHex) root.rawHex = root.payloadControl.text; } }
    Connections {
        target: root.confirmationControl
        function onToggled() {
            if (!root.confirmationEnabled) return;
            root.sendConfirmed = root.confirmationControl.checked;
            root.confirmedActivation = root.sendConfirmed ? root.string(root.actual.activation_id) : "";
        }
    }
    Connections { target: root.sendControl; function onClicked() { if (root.sendEnabled) root.sendRaw(); } }
}
