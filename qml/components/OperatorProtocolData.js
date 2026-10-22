.pragma library

function isArray(value) { return Array.isArray(value); }
function isObject(value) { return value !== null && typeof value === "object" && !isArray(value); }
function hex(value) { return typeof value === "string" && value.length % 2 === 0 && /^[0-9a-f]*$/i.test(value); }
function unsafeInteger(value, field) {
    return ["uint64", "int64"].includes(field?.type) && typeof value === "number" && !Number.isSafeInteger(value);
}
function display(value, field) {
    if (value === undefined || value === null) return "—";
    if (unsafeInteger(value, field)) return "精确整数值不可用";
    if (typeof value === "boolean") return value ? "true · 是" : "false · 否";
    if (typeof value === "number") return Number.isFinite(value) ? String(value) : "非有限数值";
    if (field?.type === "bytes" && hex(value)) return value.length / 2 + " 字节";
    if (isArray(value)) return value.length + " 项";
    if (isObject(value)) return Object.keys(value).length + " 个字段";
    return value === "" ? "空字符串" : String(value);
}
function detail(value, field, schema) {
    if (field?.type === "bytes" && hex(value)) return value.match(/.{1,2}/g)?.join(" ") ?? "";
    if (isObject(value)) {
        const nested = schema?.find(message => message.topic === field?.type);
        const known = nested?.fields ?? [];
        const rows = known.map(meta => meta.title + " [" + meta.name + "]: " + display(value[meta.name], meta));
        for (const key of Object.keys(value)) {
            if (!known.some(meta => meta.name === key))
                rows.push(key + ": " + (isObject(value[key]) || isArray(value[key]) ? JSON.stringify(value[key]) : display(value[key])));
        }
        return rows.join("\n");
    }
    if (isArray(value)) return JSON.stringify(value, null, 2);
    return value === undefined || value === null ? "—" : String(value);
}
function extraFields(data, fields) {
    return Object.keys(data ?? {}).filter(key => !fields.some(field => field.name === key)).sort();
}
