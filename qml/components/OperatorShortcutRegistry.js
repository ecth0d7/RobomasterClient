.pragma library

// One source for displayed bindings and executable QML routes. Panel actions
// retain their existing eligibility/confirmation checks; a key is never a bypass.
const actions = [
    {id:"settings",key:"P",title:"设置",scope:"hud",panel:"settings",text:"打开／关闭设置"},
    {id:"exchange",key:"H",title:"兑换／工程／空中支援",scope:"hud",roles:[1,2,3,4,5,6],text:"按本机角色与远程资格打开；再次按下关闭"},
    {id:"status",key:"Tab",title:"机器人状态",scope:"hud",panel:"status",fixed:true,hold:true,text:"按住查看，松开关闭；面板库打开可固定"},
    {id:"injury",key:"`",title:"伤害面板与模块状态",scope:"hud",panel:"injury",hold:true,text:"按住查看，松开收起"},
    {id:"help",key:"F12",title:"帮助提示",scope:"hud",panel:"help",fixed:true,hold:true,text:"按住查看常用操作说明，松开关闭"},
    {id:"shortcutPanel",key:"Ctrl+Shift+K",title:"快捷键管理",scope:"always",panel:"help",text:"查看、搜索和修改按键"},
    {id:"fullscreen",key:"F11",title:"全屏",scope:"always",fixed:true,text:"切换全屏，恢复之前窗口状态"},
    {id:"capture",key:"Ctrl+Shift+I",title:"捕获／释放键鼠",scope:"always",text:"持续捕获开关；面板关闭自动恢复，Esc临时打开设置；始终保留唯一退出组合键"},
    {id:"layout",key:"Ctrl+Shift+U",title:"HUD与面板库",scope:"always",panel:"layout",text:"隐藏、恢复、重新添加界面"},
    {id:"login",key:"Ctrl+Shift+L",title:"MQTT / UDP 连接与身份",scope:"always",panel:"login",text:"比赛中可改连接地址、图传参数和机器人身份；手动应用生效"},
    {id:"role",key:"Ctrl+Shift+R",title:"本机角色面板",scope:"hud",panel:"role",text:"打开当前机器人的专用界面"},
    {id:"map",key:"M",title:"大地图",scope:"always",panel:"map",text:"打开／关闭大地图；A攻击、B防御、I警戒，点击标记"},
    {id:"protocol",key:"Ctrl+Shift+P",title:"协议字段",scope:"always",panel:"protocol",text:"查看原始消息与字段状态"},
    {id:"bytes",key:"Ctrl+Shift+B",title:"自定义数据",scope:"always",panel:"custom",text:"打开字节编辑，不自动发送"},
    {id:"situation",key:"Ctrl+Shift+F9",title:"战场态势",scope:"always",text:"打开可选态势窗口，只读采集与队内共享"},
    {id:"services",key:"Ctrl+Shift+E",title:"服务与插件",scope:"always",panel:"services",text:"查看已加载插件和连接状态"},
    {id:"controlSetup",key:"Ctrl+Alt+C",title:"操作权限与参数",scope:"always",panel:"control-setup",text:"本机命令配置；可在比赛中编辑，保存不发送机器人动作"},
    {id:"decision",key:"Ctrl+Shift+A",title:"模型与建议",scope:"always",panel:"decision",text:"可在比赛中编辑配置；不自动请求或执行动作"},
    {id:"speech",key:"Ctrl+Shift+V",title:"语音播报",scope:"always",panel:"speech",text:"打开语音设置与当前状态"},
    {id:"aggregation",key:"Ctrl+Shift+T",title:"队伍数据汇总",scope:"always",panel:"aggregation",text:"查看可选共享插件与汇总状态"},
    {id:"team",key:"Ctrl+Alt+T",title:"队伍连接配置",scope:"always",panel:"team-config",text:"配置可信节点和共享范围"},
    {id:"sources",key:"Ctrl+Alt+S",title:"数据源配置",scope:"always",panel:"sources",text:"官方导出、本地传感器与视觉适配器"},
    {id:"provider",key:"Ctrl+Alt+M",title:"模型提供者",scope:"always",panel:"provider",text:"外部／本地模型连接配置"},
    {id:"startup",key:"Ctrl+Alt+O",title:"连接与图传",scope:"always",panel:"login",text:"直接修改本次连接、UDP与机器人身份"},
    {id:"bridge",key:"Ctrl+Alt+B",title:"外部画面接口",scope:"always",panel:"bridge",text:"查看外部渲染桥接，不启动UE"},
    {id:"buffs",key:"Ctrl+Shift+F",title:"增益详情",scope:"always",panel:"buffs",text:"查看有来源的增益记录"},
    {id:"dart",key:"Ctrl+Shift+J",title:"飞镖云台手",scope:"always",panel:"dart",text:"独立权限与选中后确认"},
    {id:"ammo42",key:"I",title:"42mm补弹",scope:"hud",roles:[1],panel:"commands",text:"打开兑换页；选择、数量与确认分开"},
    {id:"ammo17",key:"O",title:"17mm补弹",scope:"hud",roles:[3,4,5],panel:"commands",text:"打开兑换页；不直接发送兑换"},
    {id:"respawnPaid",key:"F1",title:"兑换立即复活",scope:"respawn",text:"战亡时核对资格、费用和金币后请求"},
    {id:"respawnFree",key:"Y",title:"免费复活",scope:"respawn",text:"复活读条完成且服务器允许时请求"},
    {id:"heroEnter",key:"K",title:"进入部署",scope:"hero",roles:[1],panel:"hero",hold:true,text:"保持1.2秒，松开／失焦取消"},
    {id:"heroExit",key:"L",title:"退出部署",scope:"hero",roles:[1],panel:"hero",hold:true,text:"保持1.2秒，松开／失焦取消"},
    {id:"runeHold",key:"F",title:"开启能量机关",scope:"rune",roles:[3,4,5],panel:"rune",hold:true,text:"保持1.2秒，资格有效才提交"},
    {id:"airEnd",key:"N",title:"结束空中支援",scope:"hud",roles:[6],panel:"air",text:"请求结束当前空中支援"},
    {id:"exchange1",key:"Ctrl+1",title:"兑换：选择第1项",scope:"exchange",text:"只选择当前页项目"},
    {id:"exchange2",key:"Ctrl+2",title:"兑换：选择第2项",scope:"exchange",text:"只选择当前页项目"},
    {id:"exchange3",key:"Ctrl+3",title:"兑换：选择第3项",scope:"exchange",text:"只选择当前页项目"},
    {id:"exchangeConfirm",key:"Y",title:"兑换：确认",scope:"exchange",text:"校验当前项目和数量后提交"},
    {id:"exchangeEnter",key:"Return",title:"兑换：确认（Enter）",scope:"exchange",text:"主键盘／数字键盘Enter均可"},
    {id:"exchangeCancel",key:"N",title:"兑换：撤销选择",scope:"exchange",text:"不发送命令"},
    {id:"engineerStart",key:"Return",title:"工程：开始装配",scope:"engineer",roles:[2],text:"选择页；按当前难度请求"},
    {id:"engineerConfirm",key:"Y",title:"工程：装配确认",scope:"engineer",roles:[2],text:"状态页；依赖宿主确认的难度"},
    {id:"engineerContext",key:"Ctrl+Y",title:"工程：确认本轮难度",scope:"engineer",roles:[2],text:"状态页；记录人工选择的参数，不发送装配命令"},
    {id:"engineerPage",key:"L",title:"工程：退出装配",scope:"engineer",roles:[2],text:"退出当前装配或收起结果返回难度选择"},
    {id:"airFree",key:"Ctrl+1",title:"支援：免费呼叫",scope:"air",roles:[6],text:"提交明确支援请求"},
    {id:"airPaid",key:"Ctrl+2",title:"支援：付费呼叫",scope:"air",roles:[6],text:"提交明确支援请求"},
    {id:"airCounter",key:"Ctrl+3",title:"支援：解除反制",scope:"air",roles:[6],text:"可解除状态下提交付费解除请求"},
    {id:"airCancel",key:"N",title:"支援：结束",scope:"air",roles:[6],text:"提交明确支援请求"},
    {id:"sentry1",key:"Ctrl+1",title:"哨兵：选择第1项",scope:"sentry",roles:[7],text:"当前页可用项目；Y确认"},
    {id:"sentry2",key:"Ctrl+2",title:"哨兵：选择第2项",scope:"sentry",roles:[7],text:"当前页可用项目；Y确认"},
    {id:"sentry3",key:"Ctrl+3",title:"哨兵：选择第3项",scope:"sentry",roles:[7],text:"当前页可用项目；Y确认"},
    {id:"sentry4",key:"Ctrl+4",title:"哨兵：选择第4项",scope:"sentry",roles:[7],text:"当前页可用项目；Y确认"},
    {id:"sentry5",key:"Ctrl+5",title:"哨兵：选择第5项",scope:"sentry",roles:[7],text:"当前页可用项目；Y确认"},
    {id:"sentry6",key:"Ctrl+6",title:"哨兵：选择第6项",scope:"sentry",roles:[7],text:"当前页可用项目；Y确认"},
    {id:"sentryPage",key:"L",title:"哨兵：切换分组",scope:"sentry",roles:[7],text:"姿态／补给与复活；清除旧选择"},
    {id:"sentryConfirm",key:"Y",title:"哨兵：确认",scope:"sentry",roles:[7],text:"仅确认当前合资格项目"},
    {id:"sentryCancel",key:"N",title:"哨兵：撤销选择",scope:"sentry",roles:[7],text:"不发送命令"},
    {id:"dartTarget",key:"J",title:"飞镖：下一个目标",scope:"dart",text:"切换目标；需云台手权限"},
    {id:"dartOpen",key:"F",title:"飞镖：选择开闸",scope:"dart",text:"Y另行确认"},
    {id:"dartClose",key:"C",title:"飞镖：选择关闸",scope:"dart",text:"Y另行确认"},
    {id:"dartLaunch",key:"L",title:"飞镖：发射",scope:"dart",text:"闸门开启且资格允许时发射"},
    {id:"dartConfirm",key:"Y",title:"飞镖：确认",scope:"dart",text:"不跳过目标／闸门／权限校验"},
    {id:"dartCancel",key:"N",title:"飞镖：撤销选择",scope:"dart",text:"不发送命令"}
];
actions.push(
    {id:"loginConnect",key:"Return",title:"登录：连接所选身份",scope:"login",text:"显式应用当前MQTT／UDP参数"},
    {id:"loginReconnect",key:"Ctrl+R",title:"登录：重新连接",scope:"login",text:"取消旧MQTT会话后重新连接"},
    {id:"loginVideo",key:"Ctrl+Alt+V",title:"登录：应用UDP",scope:"login",text:"独立重建图传接收，不改变MQTT"},
    {id:"loginTeam",key:"T",title:"登录：切换红蓝方",scope:"login",text:"只切换选择，不自动连接"}
);
for(const role of [1,2,3,4,5,6,7,8,9])actions.push({id:"loginRobot"+role,key:String(role),title:"登录：选择"+role+"号机器人",scope:"login",text:"只切换选择，不自动连接"});
for(const level of [1,2,3,4])actions.push({id:"engineerDifficulty"+level,key:String(level),title:"工程：选择"+level+"级",scope:"engineer",roles:[2],text:"只选择装配难度，Enter另行确认"});
function action(id) { return actions.find(item=>item.id===id); }
function sequence(id,bindings) { return bindings?.[id] ?? action(id)?.key ?? ""; }
function keyCode(sequence) {
    const key=sequence.split("+").pop();
    if (/^[A-Z0-9]$/.test(key)) return key.charCodeAt(0);
    if (/^F([1-9]|1[0-2])$/.test(key)) return Qt.Key_F1+Number(key.slice(1))-1;
    return ({Tab:Qt.Key_Tab,Return:Qt.Key_Return,Enter:Qt.Key_Enter,"`":Qt.Key_QuoteLeft})[key] ?? 0;
}
function releases(sequence,key) {
    return keyCode(sequence)===key || key===Qt.Key_Control && sequence.includes("Ctrl+")
        || key===Qt.Key_Shift && sequence.includes("Shift+") || key===Qt.Key_Alt && sequence.includes("Alt+");
}
function eventSequence(event) {
    let key="";
    if (event.key>=Qt.Key_A && event.key<=Qt.Key_Z || event.key>=Qt.Key_0 && event.key<=Qt.Key_9)
        key=String.fromCharCode(event.key);
    else if (event.key>=Qt.Key_F1 && event.key<=Qt.Key_F12) key="F"+(event.key-Qt.Key_F1+1);
    else if (event.key===Qt.Key_QuoteLeft) key="`";
    else if (event.key===Qt.Key_Return || event.key===Qt.Key_Enter) key="Return";
    else return "";
    let prefix="";
    if (event.modifiers & Qt.ControlModifier) prefix+="Ctrl+";
    if (event.modifiers & Qt.AltModifier) prefix+="Alt+";
    if (event.modifiers & Qt.ShiftModifier) prefix+="Shift+";
    if (event.modifiers & Qt.MetaModifier) return "";
    return prefix+key;
}
function matches(sequence,event) { return sequence.length>0 && eventSequence(event)===sequence; }
function overlap(a,b) {
    if (a.roles && b.roles && !a.roles.some(role=>b.roles.includes(role))) return false;
    if (a.scope==="always" || b.scope==="always" || a.scope===b.scope) return true;
    const hud=["hud","hero","rune"];
    return hud.includes(a.scope) && hud.includes(b.scope);
}
function problem(id,value,bindings) {
    const item=action(id);
    if (!item || item.fixed) return "这个按键保留为固定导航键";
    if (value==="") return id==="capture" ? "持续捕获必须保留退出快捷键，不能停用" : "";
    if (value.length>48 || !/^(Ctrl\+)?(Alt\+)?(Shift\+)?([A-Z0-9]|F([1-9]|1[0-2])|Return|`)$/.test(value))
        return "请选择单个按键组合";
    if (["F11","F12","Tab","Return"].includes(value) && item.scope==="always") return "此键保留为窗口／面板导航";
    if (id==="capture" && !value.startsWith("Ctrl+Shift+") && !value.startsWith("Ctrl+Alt+"))
        return "捕获开关需使用Ctrl+Shift或Ctrl+Alt组合；编辑面板文字时仍可退出";
    // Raw robot keys stay on the official bitmap; UI commands must not steal them.
    if (["always","hud","hero","rune"].includes(item.scope)
        && /^[WSADQERFGZXCVB]$/.test(value.split("+").pop())
        && !value.startsWith("Ctrl+Shift+") && !value.startsWith("Ctrl+Alt+")
        && !(id==="runeHold" && value==="F"))
        return "该字母属于机器人原始输入；请使用Ctrl+Shift或Ctrl+Alt组合";
    const other=actions.find(candidate=>candidate.id!==id && overlap(item,candidate)
        && sequence(candidate.id,bindings)===value);
    return other ? "与「"+other.title+"」冲突" : "";
}
function clean(value) {
    const result={};
    if (!value || typeof value!=="object" || Array.isArray(value)) return result;
    // Restore as a whole; reject conflicts with later overrides as well as defaults.
    for(const item of actions) if (!item.fixed && Object.prototype.hasOwnProperty.call(value,item.id)
        && typeof value[item.id]==="string" && value[item.id].length<=48) result[item.id]=value[item.id];
    // A rejected override restores its default, which can expose another conflict.
    for(let pass=0;pass<actions.length;++pass) {
        let changed=false;
        for(const item of actions) if(result[item.id]!==undefined && problem(item.id,result[item.id],result)) {
            delete result[item.id];changed=true;
        }
        if(!changed)break;
    }
    return result;
}
function scopeLabel(scope) { return ({always:"窗口",hud:"比赛HUD",hero:"英雄／HUD",rune:"步兵／HUD",exchange:"兑换面板",engineer:"工程面板",air:"支援面板",sentry:"哨兵面板",dart:"飞镖面板",login:"登录与连接"})[scope] ?? scope; }
