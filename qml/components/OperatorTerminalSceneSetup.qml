import QtQuick

OperatorTerminalSceneSetupForm {
    id: root
    property var runtime: null
    property string draftTeam: ""
    readonly property var providers: list(runtime?.providerCatalog)
    readonly property var currentProvider: runtime?.current ?? ({})
    readonly property var actual: runtime?.details ?? ({})
    readonly property var scene: runtime?.projection ?? ({})
    readonly property var markers: list(scene.markers)
    readonly property var records: list(scene.text_records)
    readonly property int providerIndex: providers.findIndex(entry => entry.kind === currentProvider.kind
        && (entry.kind === "builtin" ? entry.plugin_id === currentProvider.plugin_id
            : entry.package_id === currentProvider.package_id && entry.service_name === currentProvider.service_name))
    readonly property string selectedProviderLabel: currentProvider.kind === "package"
        ? (currentProvider.package_id || "未提供包ID") + " / " + (currentProvider.service_name || "未提供服务名")
        : currentProvider.kind === "builtin" ? "内置二维投影" : "未选择提供者"

    onVisibleChanged: if (visible) draftTeam = runtime?.teamId ?? ""
    onRuntimeChanged: draftTeam = runtime?.teamId ?? ""
    function list(value) {
        // QVariantList是Qt序列；在行为层转成普通数组供稳定的计数委托取值。
        return value !== null && typeof value === "object" && Number.isInteger(value.length)
            ? Array.from(value) : [];
    }
    function selectProvider(index) {
        const entry = providers[index];
        if (!runtime || runtime.editable !== true || !entry) return;
        // 宿主自行解析已审阅的包／配置身份；QML不向选择接口提供指纹或插件路径。
        const locator = entry.kind === "builtin" ? {kind: "builtin"}
            : {kind: "package", package_id: entry.package_id, service_name: entry.service_name};
        runtime.selectProvider(locator);
    }
    providerTitles: providers.map(entry => entry.label || entry.title || entry.service_name || entry.plugin_id)
    providerSelectedIndex: providerIndex
    providerEmptyText: currentProvider.kind ? "已保存的提供者当前不可用" : "选择已就绪的渲染提供者"
    teamValue: draftTeam
    configurationEditable: runtime?.editable === true
    providerEditable: configurationEditable && providers.length > 0
    canRefresh: !!runtime
    canSaveTeam: configurationEditable && draftTeam.trim().length > 0
    canEnable: configurationEditable && runtime?.active !== true
        && actual.provider_available === true && actual.configuration_valid === true
        && (runtime?.teamId?.length ?? 0) > 0
    canStop: runtime?.active === true
    statusText: runtime?.status ?? "可选渲染宿主未提供"
    statusWarning: actual.provider_available === false
    validationMessage: actual.configuration_error ?? ""
    selectionRows: [
        {label: "预期提供者", value: selectedProviderLabel, detail: true},
        {label: "提供者可用", value: actual.provider_available === true ? "是" : "否；保留选择，不自动回退"},
        {label: "配置有效", value: actual.configuration_valid === true ? "是" : "否"},
        {label: "已保存队伍范围", value: runtime?.teamId || "未选择"},
        {label: "预期插件ID", value: currentProvider.kind === "package" ? "按包ID／服务名选择" : currentProvider.plugin_id || "未提供", detail: true},
        {label: "预期包内容指纹", value: currentProvider.kind === "package" ? currentProvider.package_fingerprint || "未提供" : "内置提供者不适用", detail: true},
        {label: "预期配置指纹", value: currentProvider.kind === "package" ? currentProvider.configuration_fingerprint || "未提供" : "内置提供者不适用", detail: true},
        {label: "选择配置文件", value: actual.settings_file || "未提供", detail: true}
    ]
    stateRows: [
        {label: "实际渲染插件", value: actual.active === true ? actual.plugin_id || "未提供" : "未启用"},
        {label: "场地标定", value: actual.calibration_status ?? "unverified"},
        {label: "已注册的原生变换", value: String(actual.registered_transforms ?? 0)},
        {label: "实际标记／仅文字记录", value: markers.length + " / " + records.length},
        {label: "UE依赖", value: "当前无；预留相同版本场景契约"},
        {label: "控制边界", value: "只呈现数据，不产生机器人动作", detail: true}
    ]
    markerCount: markers.length
    recordCount: records.length
    markerDelegate: Component {
        OperatorTerminalSceneMarker {
            required property int index
            datum: root.markers[index] ?? ({})
            surfaceWidth: root.markerSurfaceWidth
            surfaceHeight: root.markerSurfaceHeight
            markerColor: root.markerColor
            headingColor: root.markerColor
            textColor: root.textColor
            fontFamily: root.fontFamily
            labelSize: root.noteSize
        }
    }
    recordDelegate: Component {
        OperatorDiagnosticTable {
            required property int index
            readonly property var datum: root.records[index] ?? ({})
            width: root.recordDelegateWidth
            title: datum.label || datum.origin?.item_id || "来源记录"
            titleSize: root.sectionTitleSize
            titleColor: root.textColor
            contentMargin: root.sectionContentMargin
            bodyTop: root.sectionBodyTop
            outlineColor: root.outlineColor
            fontFamily: root.fontFamily
            textColor: root.textColor
            mutedColor: root.mutedColor
            separatorColor: root.outlineColor
            labelSize: root.noteSize
            valueSize: root.inputSize
            rows: [
                {label: "机器人／原来源", value: (datum.origin?.robot_key ?? "未知") + " / " + (datum.origin?.source_id ?? "未知"), detail: true},
                {label: "仅文字原因", value: datum.reason || datum.state || "未标定", detail: true},
                {label: "剩余有效期", value: String(datum.remaining_ms ?? 0) + " ms"}
            ]
        }
    }
    Connections {
        target: root.providerControl
        function onActivated(index) { root.selectProvider(index); }
    }
    Connections {
        target: root.teamControl
        function onTextEdited() { root.draftTeam = root.teamControl.text; }
    }
    Connections {
        target: root.refreshControl
        function onClicked() { if (root.runtime) root.runtime.refreshProviders(); }
    }
    Connections {
        target: root.saveTeamControl
        function onClicked() { if (root.runtime) root.runtime.selectTeam(root.draftTeam.trim()); }
    }
    Connections {
        target: root.enableControl
        function onClicked() { if (root.runtime) root.runtime.setEnabled(true); }
    }
    Connections {
        target: root.stopControl
        function onClicked() { if (root.runtime) root.runtime.stop(); }
    }
}
