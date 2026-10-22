import QtQuick

// A stable field instance edits only parent-owned drafts. Native schema
// validation, inclusion maps, persistence and lifecycle stay in the manager.
OperatorPackageConfigFieldForm {
    id: root
    property var spec: ({})
    property string name: ""
    property bool required: false
    property bool included: false
    property bool editable: false
    property var value
    property string text: ""
    property alias textValue: root.text
    readonly property bool effectiveIncluded: required || included
    readonly property var enumValues: enumEntries()
    readonly property bool hasEnum: enumValues.length > 0
    readonly property string fieldType: typeof spec.type === "string" ? spec.type : "unsupported"
    readonly property bool structured: !hasEnum && (fieldType === "object" || fieldType === "array")
    readonly property bool numerical: fieldType === "integer" || fieldType === "number"
    readonly property int actualEnumIndex: effectiveIncluded && value !== undefined ? enumValues.findIndex(entry => entry === value) : -1
    readonly property int actualMaximumLength: maximumLength()
    property bool trimmingStructured: false
    signal valueEdited(var value)
    signal textEdited(string text)
    signal inclusionEdited(bool included)

    fieldTitle: title() + (root.required ? "（必填）" : "（可选）")
    fieldDescription: typeof root.spec.description === "string" ? root.spec.description : ""
    editorKind: root.hasEnum ? "enum" : root.fieldType
    requiredField: root.required
    includedField: root.effectiveIncluded
    inclusionEditable: root.editable && !root.required
    inputEditable: root.editable && root.effectiveIncluded
    booleanValue: root.value === true
    booleanLabel: typeof root.value !== "boolean" ? "尚未明确开关值（未设置）"
        : (root.effectiveIncluded ? "当前值：" : "保留草稿值：") + (root.value ? "true（开启）" : "false（关闭）")
    enumTitles: root.enumValues.map(entry => root.enumTitle(entry))
    enumIndex: root.actualEnumIndex
    // ComboBox may internally pick index0 when its model arrives. Keep the
    // caption tied to the actual typed draft, and emit only user activation.
    enumDisplayText: root.actualEnumIndex >= 0 ? root.enumTitle(root.enumValues[root.actualEnumIndex]) : root.effectiveIncluded ? "请明确选择插件允许的值" : "未设置（保存时省略）"
    enumEmptyText: root.enumDisplayText
    scalarText: root.text
    structuredText: root.text
    scalarMaximumLength: root.actualMaximumLength
    inputLabel: root.title()
    inputPlaceholder: root.effectiveIncluded ? root.structured ? "输入符合插件声明的JSON" : root.numerical ? "输入明确数值；空白不等于0" : "输入文字；空字符串与未设置分别保存" : "未设置；勾选上方选项后编辑"
    presenceText: root.presence()
    presenceWarning: root.effectiveIncluded && (root.hasEnum ? root.actualEnumIndex < 0 : root.fieldType === "boolean" && typeof root.value !== "boolean")
    typeHint: root.hint()
    editorFontFamily: root.numerical ? Theme.numberFamily : root.fontFamily

    function title() {
        return typeof spec.title === "string" && spec.title.length ? spec.title : name || "插件参数";
    }
    function enumTitle(entry) {
        if (typeof entry === "string") return entry.length ? entry : "\"\"（空字符串）";
        return String(entry);
    }
    function enumEntries() {
        const entries = spec?.enum;
        // Native QVariantList is an array-like QML sequence, for which
        // Array.isArray() returns false. Copy its bounded entries without
        // changing Boolean/number/string types or selecting a default value.
        if (entries === undefined || entries === null || typeof entries !== "object"
            || !Number.isInteger(entries.length) || entries.length < 1 || entries.length > 32) return [];
        return Array.from(entries);
    }
    function maximumLength() {
        const declared = spec.maxLength;
        return typeof declared === "number" && Number.isFinite(declared) && declared >= 0
            ? Math.min(65536, Math.floor(declared)) : 4096;
    }
    function presence() {
        if (!effectiveIncluded) return "未设置；保存时省略此可选参数。已有草稿保留，未授权保存该字段。";
        if (hasEnum && actualEnumIndex < 0) return "已包含此参数，但尚未选择明确的枚举值。";
        if (fieldType === "boolean" && typeof value !== "boolean") return "已包含此参数，但尚未明确开关值；未设置不等于false。";
        return required ? "必填参数；保存时必须包含并通过原生校验。" : "已包含此可选参数；false、0和空字符串均保留其实际值。";
    }
    function shown(value) { return value === undefined || value === null ? "未声明" : String(value); }
    function hint() {
        if (hasEnum) return "枚举 · 仅保存插件声明的原始类型和值；不自动选择第一项。";
        if (fieldType === "integer" || fieldType === "number")
            return (fieldType === "integer" ? "整数" : "有限数值") + " · 下限：" + shown(spec.minimum) + "；上限：" + shown(spec.maximum);
        if (fieldType === "string") return "文字 · 最少：" + shown(spec.minLength) + "；最多：" + actualMaximumLength + "字符；空字符串仍受插件长度要求约束。";
        if (fieldType === "object" || fieldType === "array")
            return (fieldType === "object" ? "JSON对象" : "JSON数组") + " · 编辑器最多65536字符，原生宿主另校验嵌套类型、条目和整体字节数。";
        if (fieldType === "boolean") return "布尔值 · 开关值与是否包含参数分开保存；取消包含不会清空草稿。";
        return "插件未声明受支持的参数类型；不能以此编辑器绕过原生校验。";
    }
    function selectEnum(index) {
        if (!inputEditable || !hasEnum || !Number.isInteger(index) || index < 0 || index >= enumValues.length) return;
        valueEdited(enumValues[index]);
    }
    function structuredEdited() {
        if (trimmingStructured || !structured || !inputEditable) return;
        const control = structuredControl;
        if (control.text === text) return; // Parent reloads are not user edits.
        if (control.text.length > 65536) {
            trimmingStructured = true;
            // TextArea inherits TextEdit rather than TextInput and has no
            // maximumLength. Remove only excess text, retaining the control,
            // caret and parent-owned source binding instead of recreating it.
            control.remove(65536, control.text.length);
            trimmingStructured = false;
        }
        if (control.text !== text) textEdited(control.text);
    }

    Connections {
        target: root.includeControl
        function onToggled() {
            if (root.inclusionEditable) root.inclusionEdited(root.includeControl.checked);
        }
    }
    Connections {
        target: root.booleanControl
        function onToggled() {
            if (root.inputEditable && !root.hasEnum && root.fieldType === "boolean") root.valueEdited(root.booleanControl.checked);
        }
    }
    Connections {
        target: root.enumControl
        function onActivated(index) { root.selectEnum(index); }
    }
    Connections {
        target: root.inputControl
        function onTextEdited() {
            if (root.inputEditable && !root.structured && !root.hasEnum && root.inputControl.text !== root.text)
                root.textEdited(root.inputControl.text);
        }
    }
    Connections {
        target: root.structuredControl
        function onTextChanged() { root.structuredEdited(); }
    }
}
