import QtQuick

// 本地配置草稿；保存配置不发送机器人命令，也不改写选手端资格。
OperatorControlSetupForm {
    id: root
    property var runtime: null
    property bool previewOnly: false
    property var appliedBaseline: ({})
    property var draft: ({})
    property bool dirty: false
    property bool ready: false
    property string feedback: ""
    property int selectedOperation: 0
    readonly property var operations: [
        {key:"free",title:"3 · 确认免费复活"},
        {key:"paid",title:"4 · 兑换立即复活"},
        {key:"remote17",title:"5 · 远程17mm发弹量"},
        {key:"remote42",title:"5 · 远程42mm发弹量"},
        {key:"remoteHeal",title:"6 · 远程恢复血量"}
    ]
    readonly property var dartOperations: [
        {key: "target", title: "目标选择"}, {key: "open", title: "请求开闸"},
        {key: "close", title: "请求关闸"}, {key: "launch", title: "确认发射"}
    ]
    readonly property string operationKey: operations[selectedOperation]?.key ?? "free"
    readonly property var entry: draft.common_controls?.[operationKey] ?? ({})
    readonly property bool editable: runtime !== null ? runtime.editable === true : previewOnly
    readonly property int currentClientId: runtime?.clientId ?? 0
    readonly property string targetLabel: runtime?.targetLabel ?? "未提供MQTT目标／协议"
    readonly property string validationError: validateDraft()
    readonly property bool canSave: editable && dirty && validationError.length === 0
        && (previewOnly || runtime !== null)
    width: parent ? parent.width : implicitWidth

    inputEditable: root.editable
    operationEditable: root.operations.length > 0
    paramEditable: root.editable && root.entry.param_mode === "mapped"
    saveEnabled: root.canSave
    discardEnabled: root.editable && (root.previewOnly || root.runtime !== null)
    dartAuthorized: root.draft.dart_operator_authorized === true
    runeAllowed: root.draft.rune_activation_allowed === true
    mappingAllowed: root.entry.allowed === true
    mappingVerified: root.entry.param_verified === true
    dartCount: root.dartOperations.length
    runeTitles: ["未指定", "小能量机关", "大能量机关"]
    runeIndex: root.draft.rune_kind === "small" ? 1 : root.draft.rune_kind === "large" ? 2 : 0
    runeDisplayText: root.runeTitles[root.runeIndex] ?? "未指定"
    operationTitles: root.operations.map(item => item.title)
    operationIndex: root.selectedOperation
    operationDisplayText: root.operations[root.selectedOperation]?.title ?? "尚未选择历史操作"
    paramModeTitles: ["省略param（须有明确依据）", "明确uint32参数"]
    paramModeIndex: root.entry.param_mode === "none" ? 0 : root.entry.param_mode === "mapped" ? 1 : -1
    paramModeDisplayText: root.paramModeIndex >= 0 ? root.paramModeTitles[root.paramModeIndex] : "未配置参数模式"
    paramValueText: root.entry.param === undefined ? "" : String(root.entry.param)
    paramInputLabel: (root.operations[root.selectedOperation]?.title ?? "未选择的历史操作") + "的uint32参数"
    paramSourceText: typeof root.entry.source === "string" ? root.entry.source : ""
    contextText: (root.previewOnly ? "mock · " : "") + "机器人 " + (root.currentClientId || "未选择") + "　" + root.targetLabel
    editingMessage: root.editable ? "配置仅用于本机操作入口；命令仍在原面板选择并确认。"
        : root.runtime?.lockReason || "当前配置只读；请先选择合法身份并确认配置宿主可用。"
    editingLocked: !root.editable
    mappingStatusText: root.entry.allowed !== true ? "草稿：本项关闭或尚未配置。"
        : root.entry.param_verified !== true ? "草稿：参数映射未核验，本项仍不可用。"
        : root.entryError(root.entry).length ? "草稿：依据不完整，本项仍不可用。"
        : "草稿：已作本地核验声明；实际资格与执行仍由选手端判定。"
    entryMessage: root.entryError(root.entry) || "省略参数也是明确映射选择；optional字段本身不证明引擎接受该语义。"
    entryHasError: root.entryError(root.entry).length > 0
    statusText: root.validationError || root.feedback || (root.previewOnly
        ? "离线mock配置界面；不保存、不调用生产apply、不发送命令。"
        : root.runtime?.status || "配置宿主未接通。")
    statusHasError: root.validationError.length > 0
    saveText: root.previewOnly ? "mock · 确认草稿" : "保存并应用本地配置"
    dirtyMessage: root.dirty ? "有未保存草稿；保存并应用后生效。" : "当前没有未保存改动。"

    function clone(value) {
        try { return JSON.parse(JSON.stringify(value ?? {})); }
        catch (error) { return {}; }
    }
    function initialValues() {
        const values=clone(runtime?.values ?? {});
        // 会话装配上下文永不进入此页或保存文件；现场确认由宿主另行管理。
        delete values.assembly_context;
        values.dart_operator_authorized=values.dart_operator_authorized === true;
        values.dart_operations=clone(values.dart_operations ?? {});
        for (const key of ["target","open","close","launch"]) {
            const fallback=key === "target" || key === "close";
            values.dart_operations[key]=values.dart_operations[key] === undefined
                ? fallback : values.dart_operations[key] === true;
        }
        values.rune_activation_allowed=values.rune_activation_allowed === true;
        values.common_controls=clone(values.common_controls ?? {});
        for (const operation of operations) {
            const item=values.common_controls[operation.key];
            // A configured mapping defaults to allowed in the host; an absent
            // mapping remains absent. Display the same meaning as the host.
            if (item && item.allowed === undefined) item.allowed=true;
        }
        return values;
    }
    function resetDraft() {
        appliedBaseline=initialValues();
        draft=clone(appliedBaseline);
        dirty=false;
        feedback="";
    }
    function changed(values) {
        draft=values;
        dirty=JSON.stringify(draft) !== JSON.stringify(appliedBaseline);
        feedback="";
    }
    function setTop(key,value) {
        if (!editable) return;
        const values=clone(draft);
        if (value === undefined) delete values[key]; else values[key]=value;
        changed(values);
    }
    function setDart(key,value) {
        if (!editable) return;
        const values=clone(draft);
        values.dart_operations=clone(values.dart_operations ?? {});
        values.dart_operations[key]=value;
        changed(values);
    }
    function setEntry(key,value) {
        if (!editable) return;
        const values=clone(draft);
        values.common_controls=clone(values.common_controls ?? {});
        const item=clone(values.common_controls[operationKey] ?? {});
        if (value === undefined) delete item[key]; else item[key]=value;
        if (key === "param_mode" && value === "none") delete item.param;
        values.common_controls[operationKey]=item;
        changed(values);
    }
    function uintValue(value) {
        if (typeof value === "string") {
            if (!/^[0-9]{1,10}$/.test(value)) return null;
            value=Number(value);
        }
        return typeof value === "number" && Number.isInteger(value)
            && value >= 0 && value <= 4294967295 ? value : null;
    }
    function entryError(item) {
        const source=typeof item.source === "string" ? item.source : "";
        if (source.length > 256 || /[\u0000-\u001f\u007f-\u009f]/.test(source))
            return "来源／版本须为256字以内的单行文字";
        if (item.param_mode === "mapped" && item.param !== undefined && item.param !== ""
            && uintValue(item.param) === null) return "明确参数须为0…4294967295整数";
        if (item.param_verified !== true) return "";
        if (!["none","mapped"].includes(item.param_mode)) return "请明确选择省略参数或uint32参数";
        if (item.param_mode === "mapped" && uintValue(item.param) === null) return "已核验映射需要明确uint32参数，不能留空";
        return source.trim().length ? "" : "已核验映射需要填写依据来源及版本";
    }
    function validateDraft() {
        for (const operation of operations) {
            const error=entryError(draft.common_controls?.[operation.key] ?? {});
            if (error.length) return operation.title+"："+error;
        }
        return "";
    }
    function payload() {
        const values=clone(draft);
        delete values.assembly_context;
        // 只整理此页可编辑的五项；既有buy17／buy42和其他基线字段保持原样。
        for (const operation of operations) {
            const item=values.common_controls?.[operation.key];
            if (!item) continue;
            if (item.param_mode === "none") delete item.param;
            else if (item.param !== undefined) {
                const number=uintValue(item.param);
                if (number !== null) item.param=number;
                else if (item.param === "" && item.param_verified !== true) delete item.param;
            }
            if (typeof item.source === "string") {
                if (!item.source.trim().length && item.param_verified !== true) delete item.source;
                else item.source=item.source.trim();
            }
        }
        return values;
    }
    function save() {
        if (!canSave) return;
        if (previewOnly) {
            feedback="mock草稿已确认；未保存配置、未调用生产接口、未发送命令。";
            return;
        }
        if (runtime.apply(payload()) === true) resetDraft();
        else feedback=runtime.status || "配置未保存；草稿保留，请核对当前身份与锁定状态。";
    }
    function discard() {
        if (!editable) return;
        if (previewOnly) {resetDraft();feedback="mock草稿已重置；未读取或修改生产配置。";return;}
        if (!runtime) return;
        if (runtime.reload() === true) resetDraft();
        else feedback=runtime.status || "重新载入未完成；未保存草稿仍保留。";
    }
    onRuntimeChanged: if (ready) resetDraft()
    onCurrentClientIdChanged: if (ready) resetDraft()
    onVisibleChanged: if (ready && visible) resetDraft()
    Component.onCompleted: {ready=true;resetDraft();}
    Connections {
        target: root.runtime
        ignoreUnknownSignals: true
        function onScopeChanged() {if (root.ready) root.resetDraft();}
        function onValuesChanged() {if (root.ready && !root.dirty) root.resetDraft();}
        // phase／status变化只锁编辑，不覆盖尚未保存的草稿。
    }

    dartDelegate: Component {
        OperatorControlSetupDartForm {
            id: dartRow
            required property int index
            readonly property var operation: root.dartOperations[index] ?? ({})
            width: root.dartDelegateWidth
            controlHeight: root.controlHeight
            text: operation.title ?? "未配置的历史入口"
            checked: root.draft.dart_operations?.[operation.key] === true
            editable: root.editable && root.draft.dart_operator_authorized === true
            textColor: root.textColor
            fontFamily: root.fontFamily
            inputSize: root.inputSize
            Connections {
                target: dartRow.checkControl
                function onToggled() { root.setDart(dartRow.operation.key, dartRow.checkControl.checked); }
            }
        }
    }
    Connections { target: root.dartAuthorizedControl; function onToggled() { root.setTop("dart_operator_authorized", root.dartAuthorizedControl.checked); } }
    Connections { target: root.runeAllowedControl; function onToggled() { root.setTop("rune_activation_allowed", root.runeAllowedControl.checked); } }
    Connections {
        target: root.runeKindControl
        function onActivated(index) {
            if (index >= 0 && index < root.runeTitles.length) root.setTop("rune_kind", index === 1 ? "small" : index === 2 ? "large" : undefined);
        }
    }
    Connections {
        target: root.operationControl
        function onActivated(index) { if (index >= 0 && index < root.operations.length) root.selectedOperation = index; }
    }
    Connections { target: root.mappingAllowedControl; function onToggled() { root.setEntry("allowed", root.mappingAllowedControl.checked); } }
    Connections { target: root.mappingVerifiedControl; function onToggled() { root.setEntry("param_verified", root.mappingVerifiedControl.checked); } }
    Connections {
        target: root.paramModeControl
        function onActivated(index) { if (index === 0 || index === 1) root.setEntry("param_mode", index === 0 ? "none" : "mapped"); }
    }
    Connections { target: root.paramValueControl; function onTextEdited() { if (root.paramEditable) root.setEntry("param", root.paramValueControl.text); } }
    Connections { target: root.paramSourceControl; function onTextEdited() { root.setEntry("source", root.paramSourceControl.text); } }
    Connections { target: root.saveControl; function onClicked() { root.save(); } }
    Connections { target: root.discardControl; function onClicked() { root.discard(); } }
}
