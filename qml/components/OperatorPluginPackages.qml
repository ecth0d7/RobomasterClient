import QtQuick

OperatorPluginPackagesForm {
    id: root
    objectName: "pluginPackageManager"
    property var runtime: null
    property string selectedId: ""
    property string installationDirectory: ""
    property string feedback: ""
    property var draft: ({})
    property var fieldTexts: ({})
    property var fieldIncludes: ({})
    property string savedConfigurationSnapshot: ""
    property string loadedConfiguration: ""
    property string loadedScope: ""
    readonly property var packages: runtime?.packages ?? []
    readonly property var panels: runtime?.availablePanels ?? []
    readonly property var selected: packages.find(row => row.id === selectedId) ?? ({})
    readonly property var schema: selected.configuration_schema ?? ({})
    readonly property var fields: Object.keys(schema.properties ?? {}).map(name => ({name: name, schema: schema.properties[name]}))
    readonly property var selectedPanels: panels.filter(row => row.package_id === selectedId)
    readonly property bool editable: runtime?.editable === true
    readonly property bool dirty: selectedId !== "" && draftSnapshot() !== savedConfigurationSnapshot
    readonly property string formError: preparedConfiguration().error
    signal openExtensionPanelRequested(string packageId, string panelId)

    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function owns(value, name) { return Object.prototype.hasOwnProperty.call(value, name); }
    function putOwn(value, name, entry) {
        // Schema field names are JSON keys, including names such as __proto__.
        Object.defineProperty(value, name, {value: entry, enumerable: true, writable: true, configurable: true});
    }
    function fieldRequired(name) { return (schema.required ?? []).indexOf(name) >= 0; }
    function fieldIncluded(name) { return fieldRequired(name) || fieldIncludes[name] === true; }
    function draftSnapshot() { return JSON.stringify({values: draft, texts: fieldTexts, included: fieldIncludes}); }
    function string(value) { return value === undefined || value === null ? "" : String(value); }
    function shown(value) { return value === undefined || value === null || value === "" ? "未提供" : String(value); }
    function list(value) {
        // Native QVariantList/QStringList values are array-like Qt sequences.
        const entries = value !== null && typeof value === "object" && Number.isInteger(value.length)
            ? Array.from(value) : [];
        return entries.length ? entries.join("、") : "无";
    }
    function stateName(value) {
        return ({installed: "已发现 · 未启用", configured: "已配置", "waiting-dependency": "等待依赖", "waiting-unlock": "比赛锁定 · 等待恢复",
                 loading: "装配中", active: "运行中", error: "不可用"})[value] ?? shown(value);
    }
    function reload() {
        draft = clone(selected.configuration ?? selected.defaults ?? ({}));
        const texts = {}, included = {};
        for (const field of fields) {
            const present = owns(draft, field.name);
            const defaults = selected.defaults ?? ({});
            const value = present ? draft[field.name] : owns(defaults, field.name) ? defaults[field.name] : undefined;
            putOwn(included, field.name, present || fieldRequired(field.name));
            putOwn(texts, field.name, field.schema.type === "object" || field.schema.type === "array"
                ? JSON.stringify(value ?? (field.schema.type === "array" ? [] : {}), null, 2)
                : present ? string(draft[field.name]) : "");
        }
        fieldTexts = texts;
        fieldIncludes = included;
        loadedConfiguration = JSON.stringify(selected.configuration ?? ({}));
        savedConfigurationSnapshot = draftSnapshot();
    }
    function synchronize() {
        const scope = JSON.stringify(runtime?.scope ?? ({}));
        if (loadedScope !== scope) {
            loadedScope = scope;
            removalConfirmed = false; reload(); feedback = "";
        }
        if (selectedId && !packages.some(row => row.id === selectedId)) {
            removalConfirmed = false; selectedId = ""; reload();
        }
        if (!selectedId && packages.length) { selectedId = packages[0].id; reload(); }
        if (!dirty && JSON.stringify(selected.configuration ?? ({})) !== loadedConfiguration) reload();
    }
    function selectPackage(id) {
        if (id === selectedId) return;
        if (dirty) { feedback = "先保存或撤销当前插件配置，再选择其他插件。"; return; }
        removalConfirmed = false; selectedId = id; reload(); feedback = "";
    }
    function updateValue(name, value) {
        const next = clone(draft); putOwn(next, name, value); draft = next; feedback = "";
    }
    function updateText(name, value) {
        const next = clone(fieldTexts); putOwn(next, name, value); fieldTexts = next; feedback = "";
    }
    function updateInclusion(name, included) {
        if (!editable || fieldRequired(name)) return;
        const field = fields.find(entry => entry.name === name);
        if (!field) return;
        const next = clone(fieldIncludes); putOwn(next, name, included === true); fieldIncludes = next;
        // Presence itself is the explicit Boolean choice. Other absent types
        // keep their blank/unselected editor until the operator supplies a value.
        if (included === true && !field.schema.enum && field.schema.type === "boolean" && !owns(draft, name))
            updateValue(name, false);
        feedback = "";
    }
    function preparedConfiguration() {
        if (!selectedId) return {values: {}, error: "选择一个已发现的插件包。"};
        const values = clone(draft);
        for (const field of fields) {
            const spec = field.schema, name = field.name;
            if (!fieldIncluded(name)) { delete values[name]; continue; }
            if (spec.enum) {
                if (spec.enum.indexOf(values[name]) < 0) return {values: {}, error: name + "需要选择插件声明的值。"};
                continue;
            }
            if (spec.type === "boolean") {
                if (typeof values[name] !== "boolean") return {values: {}, error: name + "需要明确的开关值。"};
            } else if (spec.type === "integer" || spec.type === "number") {
                const input = string(fieldTexts[name]).trim(), value = Number(input);
                if (!input || !Number.isFinite(value) || (spec.type === "integer" && !Number.isInteger(value)))
                    return {values: {}, error: name + (spec.type === "integer" ? "需要整数。" : "需要有限数值。")};
                if ((spec.minimum !== undefined && value < spec.minimum) || (spec.maximum !== undefined && value > spec.maximum))
                    return {values: {}, error: name + "超出插件声明的数值范围。"};
                putOwn(values, name, value);
            } else if (spec.type === "object" || spec.type === "array") {
                try {
                    const value = JSON.parse(fieldTexts[name]);
                    if (spec.type === "array" ? !Array.isArray(value) : value === null || Array.isArray(value) || typeof value !== "object")
                        return {values: {}, error: name + "的JSON类型与插件声明不符。"};
                    putOwn(values, name, value);
                } catch (error) { return {values: {}, error: name + "不是有效JSON，尚未保存。"}; }
            } else if (spec.type === "string") {
                const value = string(fieldTexts[name]);
                if ((spec.minLength !== undefined && value.length < spec.minLength) || (spec.maxLength !== undefined && value.length > spec.maxLength))
                    return {values: {}, error: name + "的文字长度超出插件声明范围。"};
                putOwn(values, name, value);
            } else return {values: {}, error: name + "的配置类型尚无可用编辑器。"};
        }
        return {values: values, error: ""};
    }
    function save() {
        if (!runtime || !editable || !selectedId) return;
        const prepared = preparedConfiguration();
        if (prepared.error) { feedback = prepared.error; return; }
        const accepted = runtime.saveConfiguration(selectedId, prepared.values);
        const status = runtime.status;
        if (accepted) reload();
        feedback = status;
    }
    function setEnabled(enabled) {
        if (!runtime || (enabled && !editable) || !selectedId) return;
        if (enabled && dirty) { feedback = "先保存或撤销修改；启用使用已保存的配置。"; return; }
        runtime.setEnabled(selectedId, enabled);
        feedback = runtime.status;
        synchronize();
    }
    function requestPanel(panelId) {
        const entry = selectedPanels.find(row => row.panel_id === panelId);
        if (!runtime || selected.active !== true || !entry) return;
        // A single workspace host owns panel instances and input isolation.
        // The settings view selects declared IDs; it never loads entry URLs.
        openExtensionPanelRequested(entry.package_id, entry.panel_id);
    }
    onRuntimeChanged: { selectedId = ""; savedConfigurationSnapshot = ""; loadedScope = ""; synchronize(); }
    onVisibleChanged: if (visible) synchronize()
    Component.onCompleted: synchronize()
    Connections { target: root.runtime; function onChanged() { root.synchronize(); } }

    // Presentation remains editable in the script-free Form. Count models
    // preserve field instances and caret/focus across native status refreshes.
    packageCount: packages.length
    fieldCount: fields.length
    panelCount: (selected.panels ?? []).length
    hasSelection: selectedId !== ""
    installationDirectoryText: installationDirectory
    refreshEnabled: !!runtime && editable
    installationDirectoryEditable: editable
    installEnabled: !!runtime && editable && installationDirectory.trim().length > 0
    saveEnabled: editable && (dirty || selected.configured !== true) && !formError
    undoEnabled: dirty
    enableEnabled: editable && selected.configured === true && !selected.enabled && !selected.native_restart_required && !dirty
    disableEnabled: !!runtime && (selected.enabled === true || selected.restoration_pending === true || selected.persisted_enabled === true)
    removalConfirmationEnabled: editable && selected.enabled === false && selected.active === false && !dirty
    removeEnabled: removalConfirmationEnabled && removalConfirmed
    introText: "本地插件包可增加服务和面板。安装、配置、启用与依赖就绪分别显示；基础MQTT、图传、输入和本机数据不随某个扩展一起移除。"
    lockText: editable ? "" : runtime?.lockReason || "插件包宿主尚未接入。"
    statusText: feedback || runtime?.status || "等待原生插件包宿主。"
    configFileText: shown(runtime?.configFile)
    restorationText: "参数和启用选择会保存。重启仅恢复当前范围内已确认且内容未变的插件；新插件或内容变化后需重新确认。"
    emptyPackagesText: "尚未发现插件包。可从本机目录安装，然后刷新查看；不会生成模拟插件或伪造运行状态。"
    configurationIntroText: "字段由当前插件声明。可选字段只有勾选后才提交；不勾选与明确填写false、0或空文本不同。保存由原生宿主再次校验；修改运行中配置会按宿主生命周期退役旧实例。"
    nativeRestartText: selected.native_restart_required === true
        ? "原生库已更换，Qt仍保留此路径的旧库。配置已保留；请重启应用后启用新版本。停用会停止会话与面板，不代表二进制已从内存卸载。" : ""
    configurationReviewText: selected.configured !== true
        ? "当前范围尚未保存配置。先核对默认值并明确保存，再启用；没有配置字段的插件也需要保存确认。" : ""
    emptyFieldsText: "此插件没有声明可编辑配置。"
    formErrorText: dirty ? formError : ""
    saveText: selected.configured === true || dirty ? "保存插件配置" : "保存当前默认配置"
    panelStatusText: selected.active === true
        ? "在主工作区打开已声明面板，使用该插件的服务与配置范围。关闭面板不停止数据源；也可从界面自定义的面板库重新打开。"
        : "插件及必需能力就绪后才可打开面板；缺少依赖时不画模拟内容。"
    noPanelsText: "此插件没有声明面板。"
    removalText: "先停用当前插件。移除只作用于实例插件目录中的此包，基础服务保持独立；依赖此包能力的其他扩展会等待依赖恢复。"
    removalConfirmationText: "确认移除 " + selectedId
    selectionRows: [
        {label: "插件／版本", value: shown(selected.id) + " / " + shown(selected.version), detail: true},
        {label: "实现类型", value: selected.native === true ? "原生C++服务 + QML界面" : "QML服务／界面"},
        {label: "原生库", value: selected.native === true ? shown(selected.native_library) + (selected.native_restart_required ? " · 已更新，需重启" : "") : "未声明", detail: true},
        {label: "安装／配置", value: (selected.installed === true ? "已安装" : "未确认") + " / " + (selected.configured === true ? "已保存" : "尚未保存")},
        {label: "启用／运行", value: (selected.enabled === true ? "已请求启用" : "未启用") + " / " + stateName(selected.state), detail: true},
        {label: "重启恢复", value: selected.restart_restore_blocked ? "已阻止恢复" : selected.restored ? "已恢复上次选择" : selected.restoration_pending ? "等待范围／依赖就绪" : selected.persisted_enabled ? "已保存启用选择" : "已保存停用或尚未选择", detail: true},
        {label: "保存状态", value: selected.persistence_error || "未报告保存错误", detail: true},
        {label: "必需能力", value: list(selected.required_services), detail: true},
        {label: "缺失依赖", value: list(selected.missing_services), detail: true},
        {label: "可选能力／导出", value: list(selected.optional_services) + " / " + list(selected.exports), detail: true},
        {label: "本机包目录", value: shown(selected.path), detail: true},
        {label: "运行原因", value: selected.error || selected.description || "宿主未报告额外错误。", detail: true}
    ]

    packageDelegate: Component {
        OperatorPackageCardForm {
            id: packageRow
            required property int index
            readonly property var entry: root.packages[index] ?? ({})
            width: root.packageDelegateWidth
            contentMargin: root.sectionContentMargin
            rowSpacing: root.fieldSpacing
            columnGap: root.columnGap
            actionWidth: root.actionWidth
            controlHeight: root.controlHeight
            titleSize: root.sectionTitleSize
            noteSize: root.noteSize
            fontFamily: root.fontFamily
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            secondaryTextColor: root.secondaryTextColor
            selectedColor: root.highlightColor
            warningColor: root.warningColor
            separatorColor: root.separatorColor
            titleText: root.shown(entry.title) + " / " + root.shown(entry.version)
            identityText: root.shown(entry.id)
            stateText: root.stateName(entry.state)
            errorText: entry.error ?? ""
            selected: entry.id === root.selectedId
            selectEnabled: entry.id !== root.selectedId
            selectText: selected ? "当前插件" : "查看配置与面板"
            Connections { target: packageRow.selectControl; function onClicked() { root.selectPackage(packageRow.entry.id); } }
        }
    }
    fieldDelegate: Component {
        OperatorPackageConfigField {
            id: fieldRow
            required property int index
            readonly property var field: root.fields[index] ?? ({name: "", schema: {}})
            objectName: "packageField_" + field.name
            width: root.fieldDelegateWidth
            fieldSpacing: root.fieldSpacing
            structuredHeight: root.structuredHeight
            labelSize: root.introSize
            noteSize: root.noteSize
            inputSize: root.inputSize
            inputHeight: root.controlHeight
            includeHeight: root.controlHeight
            fontFamily: root.fontFamily
            surfaceColor: root.surfaceColor
            textColor: root.textColor
            mutedColor: root.secondaryTextColor
            warningColor: root.warningColor
            dividerColor: root.separatorColor
            name: field.name
            spec: field.schema
            required: root.fieldRequired(field.name)
            included: root.fieldIncluded(field.name)
            editable: root.editable
            value: root.owns(root.draft, field.name) ? root.draft[field.name] : undefined
            text: root.fieldTexts[field.name] ?? ""
            onValueEdited: function(value) { root.updateValue(field.name, value); }
            onTextEdited: function(text) { root.updateText(field.name, text); }
            onInclusionEdited: function(included) { root.updateInclusion(field.name, included); }
        }
    }
    panelDelegate: Component {
        OperatorButton {
            required property int index
            readonly property var entry: (root.selected.panels ?? [])[index] ?? ({})
            width: root.panelDelegateWidth
            height: root.controlHeight
            font.family: root.fontFamily
            text: entry.title || entry.id || "未声明面板"
            enabled: root.selected.active === true && root.selectedPanels.some(row => row.panel_id === entry.id)
            onClicked: root.requestPanel(entry.id)
        }
    }

    Connections {
        target: root.refreshControl
        function onClicked() {
            if (!root.runtime || !root.editable) return;
            root.runtime.rescan(); root.feedback = root.runtime.status; root.synchronize();
        }
    }
    Connections { target: root.installationDirectoryControl; function onTextEdited() { root.installationDirectory = root.installationDirectoryControl.text; } }
    Connections {
        target: root.installControl
        function onClicked() {
            if (!root.runtime || !root.editable || !root.installationDirectory.trim()) return;
            root.runtime.installDirectory(root.installationDirectory.trim()); root.feedback = root.runtime.status; root.synchronize();
        }
    }
    Connections { target: root.saveControl; function onClicked() { root.save(); } }
    Connections { target: root.undoControl; function onClicked() { root.reload(); root.feedback = "未保存修改已撤销。"; } }
    Connections { target: root.enableControl; function onClicked() { root.setEnabled(true); } }
    Connections { target: root.disableControl; function onClicked() { root.setEnabled(false); } }
    Connections { target: root.removalConfirmationControl; function onToggled() { root.removalConfirmed = root.removalConfirmationControl.checked; } }
    Connections {
        target: root.removeControl
        function onClicked() {
            if (!root.runtime || !root.removeEnabled) return;
            root.runtime.uninstall(root.selectedId);
            root.removalConfirmed = false; root.feedback = root.runtime.status; root.synchronize();
        }
    }
}
