.pragma library

var purposes = [
    {id: "operator", title: "官方选手端导出", note: "赛事数据经官方选手端取得；地址、机器人身份和选手端配置须一致。实际发布者认证仍待宿主核验。"},
    {id: "preparation", title: "仅赛前本地准备", note: "下次启动请求仅准备模式，隔离比赛连接与控制。当前只保存草稿，不会停掉本次服务；生产启动隔离待接通。"},
    {id: "laboratory", title: "本地协议联调", note: "仅用于明确的本地联调数据源，不能把模拟器当官方赛事服务器；本轮不建立连接。"}
];
var pluginRoles = [
    {key: "mqttPlugin", role: "mqtt", title: "消息传输", option: "mqtt-plugin"},
    {key: "protocolPlugin", role: "protocol", title: "协议解码", option: "protocol-plugin"},
    {key: "videoPlugin", role: "video", title: "视频解码", option: "video-plugin"},
    {key: "statePlugin", role: "state", title: "遥测状态", option: "state-plugin"},
    {key: "inputPlugin", role: "input", title: "窗口输入", option: "input-plugin"},
    {key: "policyPlugin", role: "policy", title: "命令策略", option: "policy-plugin"}
];
function defaults() {
    return {name: "选手端连接", purpose: "operator", host: "192.168.12.1", mqttPort: "3333",
        videoBind: "0.0.0.0", videoPort: "3334", videoCodec: "hevc", renderer: "auto",
        pluginDir: "", uiDir: "", mqttPlugin: "mqtt.mosquitto", protocolPlugin: "protocol.rm2026.v2",
        videoPlugin: "video.ffmpeg", statePlugin: "state.telemetry", inputPlugin: "input.qt", policyPlugin: "policy.operator"};
}
function singleLine(value, maximum, empty) {
    return typeof value === "string" && value.length <= maximum && !/[\u0000-\u001f\u007f]/.test(value) && (empty || value.trim().length > 0);
}
function port(value) {
    if (typeof value !== "string" || !/^[0-9]{1,5}$/.test(value)) return undefined;
    const number = Number(value);
    return number >= 1 && number <= 65535 ? number : undefined;
}
function hostValid(value) {
    return singleLine(value, 255, false) && !/[\s\/@?#\\]/.test(value);
}
function bindPlausible(value) {
    if (!singleLine(value, 128, false)) return false;
    if (/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/.test(value))
        return value.split(".").every(part => part.length <= 3 && Number(part) <= 255);
    // IPv6 只作界面初筛；完整地址及可绑定性必须由宿主 QHostAddress / 端点核验。
    return value.includes(":") && /^[0-9a-fA-F:.]+(?:%[A-Za-z0-9_.-]+)?$/.test(value);
}
function error(value, key) {
    if (key === "name") return singleLine(value, 64, false) ? "" : "名称须为1–64字符，不含换行或控制符。";
    if (key === "host") return hostValid(value) ? "" : "填写IP或主机名，不含URL、空格或账号密码。";
    if (key === "mqttPort" || key === "videoPort") return port(value) !== undefined ? "" : "端口须为1–65535的十进制整数。";
    if (key === "videoBind") return bindPlausible(value) ? "" : "监听地址须为本机IPv4／IPv6字面量，不能是主机名。";
    if (key === "uiDir" || key === "pluginDir") return singleLine(value, 512, true) ? "" : "路径过长或包含控制字符。";
    if (pluginRoles.some(role => role.key === key)) return typeof value === "string" && /^[A-Za-z0-9_.-]{1,160}$/.test(value) ? "" : "插件ID须为1–160个字母、数字、点、下划线或连字符。";
    return "";
}
function valid(value) {
    if (!value || typeof value !== "object" || Array.isArray(value)) return false;
    const enums = {purpose: purposes.map(entry => entry.id), videoCodec: ["hevc", "h264", "auto"], renderer: ["auto", "software", "opengl"]};
    for (const key of Object.keys(enums)) if (!enums[key].includes(value[key])) return false;
    return Object.keys(defaults()).every(key => !error(value[key], key));
}
function clean(value) {
    const result = defaults();
    if (!value || typeof value !== "object" || Array.isArray(value)) return result;
    for (const key of Object.keys(result)) {
        if (typeof value[key] === "string" && value[key].length <= 512) result[key] = value[key];
    }
    return valid(result) ? result : defaults();
}
function preset(purpose, current) {
    const result = Object.assign({}, current, {purpose: purpose});
    if (purpose === "operator") Object.assign(result, {host: "192.168.12.1", mqttPort: "3333", videoCodec: "hevc"});
    if (purpose === "laboratory") Object.assign(result, {host: "127.0.0.1", mqttPort: "3333", videoBind: "127.0.0.1"});
    return result;
}
function connectionPatch(draft) {
    // 仅已支持的 schema1 options 补丁；保留原 profile 中模型／语音等其他配置。
    const options = {host: draft.host, "mqtt-port": port(draft.mqttPort), "video-bind": draft.videoBind,
        "video-port": port(draft.videoPort), "video-codec": draft.videoCodec, renderer: draft.renderer};
    for (const role of pluginRoles) options[role.option] = draft[role.key];
    options["plugin-dir"] = draft.pluginDir;
    options["ui-dir"] = draft.uiDir;
    return options;
}
function text(value) { return typeof value === "string" && value.length ? value : "未公开"; }
function renderer(value) { return ({auto: "自动", software: "软件绘制", opengl: "OpenGL"})[value] ?? "未公开"; }
function purpose(value) { return purposes.find(entry => entry.id === value)?.title ?? "未公开"; }
function runtimeRows(runtime) {
    const selected = runtime?.selected ?? {};
    return [
        {label: "配置来源", value: text(runtime?.profileLabel), detail: true},
        {label: "本次用途", value: purpose(runtime?.purpose)},
        {label: "导出地址", value: text(selected.host), detail: true},
        {label: "消息端口", value: typeof selected.mqttPort === "number" ? String(selected.mqttPort) : "未公开", numeric: true},
        {label: "图传监听", value: text(selected.videoBind) + " : " + (typeof selected.videoPort === "number" ? selected.videoPort : "未公开"), detail: true},
        {label: "解码选项", value: text(selected.videoCodec)},
        {label: "请求的绘制选项", value: renderer(selected.renderer)},
        {label: "实际绘制后端", value: text(runtime?.rendererActual), detail: true},
        {label: "回退原因", value: text(runtime?.rendererReason), detail: true}
    ];
}
