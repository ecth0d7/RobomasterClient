.pragma library
.import "OperatorData.js" as Data
.import "OperatorRuneData.js" as Rune

var postures = {1: "进攻姿态", 2: "防御姿态", 3: "移动姿态"};
var commands = [
    {id: 7, title: "进攻姿态", posture: 1, powered: false, icon: "attack"}, {id: 10, title: "强化进攻姿态", posture: 1, powered: true, icon: "attack"},
    {id: 8, title: "防御姿态", posture: 2, powered: false, icon: "defence"}, {id: 11, title: "强化防御姿态", posture: 2, powered: true, icon: "defence"},
    {id: 9, title: "移动姿态", posture: 3, powered: false, icon: "move"}, {id: 12, title: "强化移动姿态", posture: 3, powered: true, icon: "move"},
    {id: 1, title: "补血点补弹"}, {id: 3, title: "远程补弹"}, {id: 4, title: "远程回血"},
    {id: 5, title: "确认免费复活", revive: true}, {id: 6, title: "兑换立即复活", revive: true, paid: true}
];
function flag(telemetry, key, on, off) {
    const state = Data.state(telemetry, "sentryStatus", key), value = telemetry?.sentryStatus?.[key];
    return state === "missing" || typeof value !== "boolean" ? "—" : (value ? on : off) + (state === "stale" ? " · 旧" : "");
}
function view(items,id,now,previewOnly,telemetry) {
    if(id%100!==7)return null;
    const s=Rune.source(items,id,now,previewOnly),d=s?.sentry_control;
    if(!d || d.version!==1 || d.round!==telemetry?.gameStatus?.current_round
        || Data.state(telemetry,"gameStatus","current_round")!=="fresh")return null;
    for(const key of ["posture_id","is_powered","is_weakened"])
        if(Data.state(telemetry,"sentryStatus",key)!=="fresh" || d[key]!==telemetry?.sentryStatus?.[key])return null;
    if(!validDetails(d))return null;
    return Object.assign({},d,{source:s});
}
function validDetails(d) {
    for(const key of ["normal_seconds","powered_seconds"])
        if(!Array.isArray(d[key]) || d[key].length!==3 || !d[key].every(n=>Number.isInteger(n)&&n>=0&&n<=3600))return false;
    if(!Array.isArray(d.offers) || d.offers.length!==commands.length)return false;
    if(new Set(d.offers.map(o=>o?.command_id)).size!==commands.length)return false;
    for(const c of commands){const o=d.offers.find(o=>o?.command_id===c.id);
        if(!o || typeof o.enabled!=="boolean" || typeof o.reason!=="string" || o.reason.length>256
            || !Number.isSafeInteger(o.cost) || o.cost<0 || o.cost>4294967295)return false;
        if([1,3,4].includes(c.id) && (!Number.isSafeInteger(o.amount) || o.amount<=0 || o.amount>(c.id===4?100:4294967295) || o.unit!==(c.id===4?"%":"发")))return false;}
    return true;
}
var supportActions=[
    {id:"forward",title:"发送地图标记",local:"map_forward"},
    {id:"ammo50",title:"50允许发弹量",local:"ammo",quantity:50},
    commands.find(c=>c.id===6),{id:"ammo100",title:"100允许发弹量",local:"ammo",quantity:100},
    commands.find(c=>c.id===5),{id:"ammo200",title:"200允许发弹量",local:"ammo",quantity:200},
    commands.find(c=>c.id===3),commands.find(c=>c.id===4)
];
function supportView(projection,id,now,previewOnly,telemetry) {
    if(!projection)return null;
    const d=Rune.source([projection],id,now,previewOnly);
    if(!d || d.version!==1 || d.operator_role!=="gimbal" || d.target_robot_id!==(id>100?107:7)
        || d.round!==telemetry?.gameStatus?.current_round || d.target_round!==d.round
        || Data.state(telemetry,"gameStatus","current_round")!=="fresh" || ![0,1].includes(d.control_mode)
        || !Number.isSafeInteger(d.intervention_cost) || d.intervention_cost<0 || d.intervention_cost>4294967295)return null;
    for(const key of ["posture_id","is_powered","is_weakened"])
        if(Data.state(telemetry,"sentryStatus",key)!=="fresh" || d[key]!==telemetry?.sentryStatus?.[key])return null;
    if(!validDetails(d) || !Array.isArray(d.ammo_offers) || d.ammo_offers.length!==3)return null;
    const valid=o=>o && typeof o.enabled==="boolean" && typeof o.reason==="string" && o.reason.length<=256
        && Number.isSafeInteger(o.cost) && o.cost>=0 && o.cost<=4294967295;
    for(const n of [50,100,200])if(d.ammo_offers.filter(o=>o.amount===n && o.unit==="发" && valid(o)).length!==1)return null;
    if(!valid(d.map_offer) || typeof d.map_offer.active!=="boolean")return null;
    if(d.pending!==null && (!d.pending || ![3,4].includes(d.pending.command_id)
        || !Number.isInteger(d.pending.remaining_seconds) || d.pending.remaining_seconds<0 || d.pending.remaining_seconds>60))return null;
    if(d.result!==null && (!d.result || !Number.isSafeInteger(d.result.sequence) || d.result.sequence<=0
        || !["command","map_forward"].includes(d.result.operation) || !["pending","applied","rejected"].includes(d.result.status)
        || typeof d.result.error!=="string" || d.result.error.length>256))return null;
    return Object.assign({},d,{source:d});
}
function actionOffer(action,model) {
    if(action.local==="map_forward")return model?.map_offer;
    if(action.local==="ammo")return model?.ammo_offers.find(o=>o.amount===action.quantity);
    return model?.offers.find(o=>o.command_id===action.id);
}
function detail(action,model) {
    const o=actionOffer(action,model);
    if(action.local==="map_forward" && o?.active)return "已激活 · 取消";
    if(action.revive && o && !o.enabled)return o.reason;
    const cost=o ? o.cost===0 ? "免费" : o.cost+"金币" : "费用 —";
    if(action.posture!==undefined){const seconds=(action.powered?model?.powered_seconds:model?.normal_seconds)?.[action.posture-1];
        return cost+" · "+(seconds===undefined?"—":seconds+"s");}
    return cost+(o?.amount ? " · "+o.amount+o.unit : "");
}
function result(telemetry) {
    const commandState = Data.state(telemetry, "sentryCtrlResult", "command_id"), resultState = Data.state(telemetry, "sentryCtrlResult", "result_code");
    const value = telemetry?.sentryCtrlResult ?? {};
    if (commandState === "missing" || resultState === "missing"
        || !Data.notOlderThan(telemetry,"sentryCtrlResult","result_code","command_id")) return "控制结果：等待完整回传";
    const name = commands.find(item => item.id === value.command_id)?.title ?? "未知指令";
    return "最新反馈：" + name + " · " + (value.result_code === 0 ? "成功" : "失败 " + value.result_code) + (commandState === "stale" || resultState === "stale" ? " · 旧" : "");
}
function supportResult(model,telemetry) {
    if(model?.pending)return (model.pending.command_id===3?"远程补弹":"远程回血")+" · "+model.pending.remaining_seconds+"s 后生效";
    const r=model?.result;
    if(!r)return result(telemetry);
    if(r.status==="rejected")return "操作未执行："+r.error;
    if(r.operation==="map_forward")return "地图标记 · "+(r.active?"转发已激活":"已停止转发");
    if(r.command_id===1)return "补弹"+r.amount+"发 · 已生效";
    if(r.command_id===3)return "远程补弹"+r.amount+"发 · 已生效";
    if(r.command_id===4)return "远程回血"+r.amount+"% · 已生效";
    return result(telemetry);
}
function radarRows(telemetry, clientID) {
    const entries = telemetry?.radar?.radar_single_robot_info;
    if (!Array.isArray(entries)) return [];
    const roles = [1, 2, 3, 4, 6, 7], own = clientID > 100 ? 100 : 0, enemy = own ? 0 : 100;
    return entries.slice(0, 12).map((entry, index) => {
        const robot = entry && typeof entry === "object" ? entry : {};
        const number = roles[index % 6] + (index < 6 ? enemy : own);
        const x = robot.target_pos_x, y = robot.target_pos_y, mark = robot.is_high_light;
        const coordinates = Number.isInteger(x) && Number.isInteger(y) && x >= 0 && x <= 2800 && y >= 0 && y <= 1500;
        return {robotId: number, side: index < 6 ? "对方" : "己方", position: coordinates ? (x / 100).toFixed(2) + ", " + (y / 100).toFixed(2) + " m" : "坐标未提供 / 越界",
            mark: ({0: "普通标识", 1: "特殊标识", 2: "特殊标识 · 定位离线"})[mark] ?? "标识未知", offline: mark === 2};
    });
}
