.pragma library
.import "UiFormat.js" as Identity
.import "OperatorStartupPolicy.js" as Common

var uses = [
    {id: "hud", title: "HUD"}, {id: "alerts", title: "告警"},
    {id: "localAi", title: "本地AI"}, {id: "externalAi", title: "外部AI"}, {id: "voice", title: "队内语音"}
];
var categories = [
    {id: "health", title: "生命与存活"}, {id: "resources", title: "热量与弹量"},
    {id: "position", title: "位置与坐标出处"}, {id: "objective", title: "角色任务"},
    {id: "advice", title: "建议与依据"}, {id: "sensorEvents", title: "电控／传感器"},
    {id: "visionDiscoveries", title: "视觉发现"}, {id: "derived", title: "客户端推导"}
];
function defaults() {
    const permissions = {};
    for (const category of categories) permissions[category.id] = {};
    return {networkEnabled: false, teamId: "", nodeId: "", displayName: "", matchId: "", epoch: "", configurationRevision: "",
        clocksSynchronized: false, maxClockSkewMs: "250", teamWideSharingConfirmed: false, canSend: false, canAggregate: false,
        endpoint: "mqtts://127.0.0.1:8883",
        caFile: "", certificateFile: "", signingKeyFileEnv: "ROBOMASTER_NODE_SIGNING_KEY_FILE",
        heartbeatMs: "1000", timeoutMs: "3000", publisherId: "", voiceNodeId: "", selfListen: false,
        voiceOutputGroup: "", voiceOutputNodeId: "",
        peers: [], permissions: permissions};
}
function identifier(value, maximum, empty) {
    return typeof value === "string" && (empty && value.length === 0 || /^[A-Za-z0-9_.-]+$/.test(value) && value.length <= maximum);
}
function fingerprint(value, empty) { return typeof value === "string" && (empty && value.length === 0 || /^[A-Fa-f0-9]{64}$/.test(value)); }
function endpoint(value) {
    if (typeof value !== "string") return false;
    const matched = /^mqtts:\/\/(\[[0-9a-fA-F:%.]+\]|[A-Za-z0-9.-]+):([0-9]{1,5})$/.exec(value);
    return !!matched && Common.port(matched[2]) !== undefined;
}
function peerDefaults() { return {nodeId: "", robotId: 1, label: "", certificateFile: "", fingerprint: "", canSend: false, canAggregate: false, canVoice: false, canHear: false}; }
function peerError(peer, peers, localNodeId, localRobotId, requiredPin) {
    if (!peer || !identifier(peer.nodeId, 64, false)) return "节点ID须为1–64个字母、数字、点、下划线或连字符。";
    if (peer.nodeId === localNodeId || peers.some(other => other?.nodeId === peer.nodeId)) return "节点ID重复或与本机相同，不能保存。";
    if (!Identity.validLogin(peer.robotId) || peer.robotId === localRobotId || peers.some(other => other?.robotId === peer.robotId)) return "机器人绑定不合法或与当前配置重复。";
    if (Identity.validLogin(localRobotId) && (peer.robotId > 100) !== (localRobotId > 100)) return "队内成员须与本机属于同一阵营。";
    if (!Common.singleLine(peer.label, 64, true)) return "成员名称过长或含控制字符。";
    if (!Common.singleLine(peer.certificateFile, 512, !requiredPin)) return "启用网络须为每位成员指定公开证书文件引用。";
    if (!fingerprint(peer.fingerprint, !requiredPin)) return "SPKI公钥SHA-256指纹须为64个十六进制字符；草稿值不代表认证完成。";
    return "";
}
function problems(value, localRobotId) {
    const issues = [];
    if (!value || typeof value !== "object" || Array.isArray(value)) return ["配置结构不合法。"];
    if (!identifier(value.teamId, 64, !value.networkEnabled)) issues.push("队伍ID须为1–64个字母、数字、点、下划线或连字符。");
    if (!identifier(value.nodeId, 64, !value.networkEnabled)) issues.push("本机节点ID缺失或格式错误。");
    for (const key of ["matchId", "epoch", "configurationRevision"]) if (!identifier(value[key], 64, !value.networkEnabled)) issues.push("比赛ID、共享会话epoch与配置版本须分别为1–64个合法标识字符。");
    if (value.networkEnabled && !Identity.validLogin(localRobotId)) issues.push("启用队内网络前须选择本机机器人身份。");
    if (value.networkEnabled && value.clocksSynchronized !== true) issues.push("须明确确认成员时钟已同步；界面不会自动宣称已同步。");
    if (!/^(?:0|[1-9][0-9]{0,3})$/.test(value.maxClockSkewMs ?? "") || Number(value.maxClockSkewMs) > 1000) issues.push("允许时钟偏差须为0–1000ms，不使用前导零。");
    if (value.networkEnabled && value.teamWideSharingConfirmed !== true) issues.push("须确认队伍成员已知悉汇总视图的用途授权及披露范围。");
    if (!Common.singleLine(value.displayName, 64, true)) issues.push("本机名称格式错误。");
    if (!endpoint(value.endpoint)) issues.push("连接须为mqtts://主机:端口，不含账号、密码或路径。");
    for (const key of ["caFile", "certificateFile"]) if (!Common.singleLine(value[key], 512, !value.networkEnabled)) issues.push("启用网络需配置根证书与本机公开证书引用。");
    if (!/^[A-Za-z_][A-Za-z0-9_]{0,95}$/.test(value.signingKeyFileEnv ?? "")) issues.push("私钥文件环境变量名不合法。");
    const heartbeat = Number(value.heartbeatMs), timeout = Number(value.timeoutMs);
    if (!/^(?:0|[1-9][0-9]{0,4})$/.test(value.heartbeatMs ?? "") || heartbeat < 500 || heartbeat > 5000) issues.push("心跳须为500–5000ms，不使用前导零。");
    if (!/^(?:0|[1-9][0-9]{0,4})$/.test(value.timeoutMs ?? "") || timeout < 3 * heartbeat || timeout > 30000) issues.push("成员超时须至少3个心跳周期且不超过30000ms，不使用前导零。");
    if (!Array.isArray(value.peers) || value.peers.length > 15) return issues.concat(["除本机外最多15位可信成员，含本机总计16个节点。"]);
    for (let i = 0; i < value.peers.length; ++i) {
        const issue = peerError(value.peers[i], value.peers.slice(0, i), value.nodeId, localRobotId, value.networkEnabled);
        if (issue) issues.push("成员" + (i + 1) + "：" + issue);
    }
    for (const key of ["publisherId", "voiceNodeId", "voiceOutputNodeId"]) if (!identifier(value[key], 64, true)) issues.push("发布／语音节点ID格式错误。");
    if (!identifier(value.voiceOutputGroup, 64, !value.selfListen)) issues.push("队内收听需配置明确的输出组ID。");
    if (value.selfListen && !value.voiceOutputNodeId) issues.push("队内收听需指定输出组的唯一播放节点。");
    if (value.publisherId && !candidates(value, "canAggregate").some(entry => entry.id === value.publisherId)) issues.push("汇总发布节点不在已配置授权清单。");
    if (value.networkEnabled && !value.publisherId) issues.push("启用网络须明确选择一个已授权的汇总发布节点。");
    if (value.voiceNodeId && !candidates(value, "canVoice").some(entry => entry.id === value.voiceNodeId)) issues.push("语音节点不在已配置授权清单。");
    if (value.voiceOutputNodeId && !candidates(value, "canHear").some(entry => entry.id === value.voiceOutputNodeId)) issues.push("播放节点不在已配置收听授权清单。");
    return issues;
}
function candidates(value, permission) {
    const result = value.nodeId && (permission !== "canAggregate" || value.canAggregate === true)
        ? [{id: value.nodeId, title: "本机 · " + value.nodeId}] : [];
    for (const peer of Array.isArray(value.peers) ? value.peers : []) if (peer?.[permission] === true) result.push({id: peer.nodeId, title: (peer.label || peer.nodeId) + " · " + peer.nodeId});
    return result;
}
function clean(value) {
    const result = defaults();
    if (!value || typeof value !== "object" || Array.isArray(value)) return result;
    for (const key of ["teamId", "nodeId", "displayName", "matchId", "epoch", "configurationRevision", "maxClockSkewMs", "endpoint", "caFile", "certificateFile", "signingKeyFileEnv", "heartbeatMs", "timeoutMs", "publisherId", "voiceNodeId", "voiceOutputGroup", "voiceOutputNodeId"])
        if (typeof value[key] === "string" && value[key].length <= 512) result[key] = value[key];
    for (const key of ["networkEnabled", "selfListen", "clocksSynchronized", "teamWideSharingConfirmed", "canSend", "canAggregate"]) result[key] = value[key] === true;
    if (Array.isArray(value.peers)) result.peers = value.peers.slice(0, 16).map(peer => {
        const cleanPeer = peerDefaults();
        if (!peer || typeof peer !== "object" || Array.isArray(peer)) return cleanPeer;
        for (const key of ["nodeId", "label", "certificateFile", "fingerprint"]) if (typeof peer[key] === "string" && peer[key].length <= 512) cleanPeer[key] = peer[key];
        cleanPeer.robotId = Identity.validLogin(peer.robotId) ? peer.robotId : 0;
        for (const key of ["canSend", "canAggregate", "canVoice", "canHear"]) cleanPeer[key] = peer[key] === true;
        return cleanPeer;
    });
    for (const category of categories) for (const use of uses)
        if (value.permissions?.[category.id]?.[use.id] === true) result.permissions[category.id][use.id] = true;
    return result;
}
