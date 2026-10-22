.pragma library

function result(bytes, maximum) {
    const count = bytes.length;
    return {valid: count <= maximum, count: count,
        hex: bytes.map(value => value.toString(16).padStart(2, "0")).join(""),
        bytes: bytes, error: count > maximum ? "超过 " + maximum + " 字节上限" : ""};
}
function parse(text, format, maximum) {
    // 这里只整理编辑草稿；收到的数据和协议发送仍属于各自状态/命令接口。
    if (typeof text !== "string" || text.length > 4096)
        return {valid: false, count: null, bytes: [], hex: "", error: "输入过长"};
    let bytes = [];
    if (format === 0) {
        const compact = text.replace(/\s/g, "");
        if (!/^[0-9a-f]*$/i.test(compact))
            return {valid: false, count: null, bytes: [], hex: "", error: "十六进制只接受 0–9、A–F 和空白"};
        if (compact.length % 2)
            return {valid: false, count: null, bytes: [], hex: "", error: "每个字节需要两位十六进制字符"};
        bytes = (compact.match(/../g) ?? []).map(pair => parseInt(pair, 16));
    } else if (format === 1) {
        const tokens = text.trim() ? text.trim().split(/[\s,]+/) : [];
        if (tokens.some(token => !/^\d{1,3}$/.test(token) || Number(token) > 255))
            return {valid: false, count: null, bytes: [], hex: "", error: "每项必须是 0–255 的整数，以空格或逗号分隔"};
        bytes = tokens.map(Number);
    } else if (format === 2) {
        // QML 没有浏览器 TextEncoder；按 Unicode 码点编码，拒绝不成对的代理项。
        for (const character of text) {
            const code = character.codePointAt(0);
            if (code >= 0xd800 && code <= 0xdfff)
                return {valid: false, count: null, bytes: [], hex: "", error: "文本含不完整的 Unicode 字符"};
            if (code < 0x80) bytes.push(code);
            else if (code < 0x800) bytes.push(0xc0 | code >> 6, 0x80 | code & 0x3f);
            else if (code < 0x10000) bytes.push(0xe0 | code >> 12, 0x80 | code >> 6 & 0x3f, 0x80 | code & 0x3f);
            else bytes.push(0xf0 | code >> 18, 0x80 | code >> 12 & 0x3f, 0x80 | code >> 6 & 0x3f, 0x80 | code & 0x3f);
        }
    } else {
        return {valid: false, count: null, bytes: [], hex: "", error: "未选择输入格式"};
    }
    return result(bytes, maximum);
}
function received(value) {
    if (value === undefined || value === null)
        return {valid: false, count: null, bytes: [], hex: "", error: "尚未收到字节数据"};
    if (typeof value !== "string" || value.length > 600 || !/^(?:[0-9a-f]{2})*$/i.test(value))
        return {valid: false, count: null, bytes: [], hex: "", error: "收到的数据不是有效的 0–300 字节十六进制内容"};
    // 已经是校验过的线上十六进制，不再走编辑器的分词、逐项
    // toString/padStart 和重新拼接。高频视频块需要避免这批临时字符串。
    const bytes = [];
    for (let i = 0; i < value.length; i += 2) {
        const high = value.charCodeAt(i), low = value.charCodeAt(i + 1);
        const a = high <= 57 ? high - 48 : (high | 32) - 87;
        const b = low <= 57 ? low - 48 : (low | 32) - 87;
        bytes.push((a << 4) | b);
    }
    return {valid: true, count: bytes.length, hex: value.toLowerCase(), bytes: bytes, error: ""};
}
function spaced(hex) { return hex.match(/../g)?.join(" ") ?? ""; }
function ascii(bytes) {
    return bytes.map(value => value >= 32 && value <= 126 ? String.fromCharCode(value) : "·").join("");
}
