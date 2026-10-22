.pragma library

const stateLabels = {fresh:"新鲜接收值",stale:"旧值",missing:"未提供",invalid:"类型或取值异常",unverified:"时效待核",offline:"断连保留值"};
function uint(value) {
    return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 4294967295;
}
function raw(value) {
    if (value === undefined || value === null) return "未提供";
    if (typeof value === "object") return "非标量对象";
    return String(value).slice(0,256);
}
function field(telemetry,group,key,connected,valid) {
    const value=telemetry?.[group]?.[key];
    const reported=telemetry?.fieldFreshness?.[group]?.[key];
    if (value === undefined || value === null) return {value:value,state:"missing"};
    if (!valid(value)) return {value:value,state:"invalid"};
    if (reported === "missing") return {value:value,state:"missing"};
    if (!connected) return {value:value,state:"offline"};
    // 分组fresh不证明optional字段本次出现；旧SDK的原值保留为待核。
    return {value:value,state:["fresh","stale"].includes(reported) ? reported : "unverified"};
}
function view(telemetry,clientId,connected,secondsVerified,previewOnly) {
    const flag=field(telemetry,"robotDynamic","is_out_of_combat",connected,value => typeof value === "boolean");
    const counter=field(telemetry,"robotDynamic","out_of_combat_countdown",connected,uint);
    const subject=field(telemetry,"robotStatic","robot_id",connected,uint);
    const alive=field(telemetry,"robotStatic","alive_state",connected,value => [0,1,2].includes(value));
    const sameSubject=[1,2,3,4,5,6,7,8,9,101,102,103,104,105,106,107,108,109].includes(clientId) && subject.value === clientId;
    const currentSubject=connected && sameSubject && subject.state === "fresh";
    const wrongSubject=subject.state !== "missing" && uint(subject.value) && subject.value > 0 && subject.value !== clientId;
    const dead=currentSubject && alive.state === "fresh" && alive.value === 2;
    const conflict=currentSubject && flag.state === "fresh" && flag.value === true
        && counter.state === "fresh" && counter.value > 0;
    const result={flag:flag,counter:counter,subject:subject,alive:alive,clientId:clientId,
        displayable:flag.state !== "missing" || counter.state !== "missing" || dead,dead:dead,
        label:"",tone:"muted",current:false,out:false,description:""};
    if (result.displayable) {
        if (!connected) {
            result.label=sameSubject && typeof flag.value === "boolean" && flag.state !== "missing"
                ? (flag.value ? "已脱战" : "战斗中")+"·断" : "脱战断连";
        } else if (wrongSubject) {
            result.label="身份冲突";
            result.tone="warning";
        } else if (!currentSubject) {
            result.label=sameSubject && subject.state === "stale" ? "脱战·身份旧" : "脱战待核";
        } else if (dead) {
            result.label="已战亡";
            result.tone="red";
        } else if (flag.state === "missing") {
            // 单独的倒数不补成false，不承诺“后脱战”；0也是合法原值。
            if (counter.state === "fresh") result.label="倒数 "+raw(counter.value)+(secondsVerified ? "s" : "");
            else if (counter.state === "stale") result.label="倒数·旧";
            else if (counter.state === "invalid") {result.label="脱战异常";result.tone="warning";}
            else result.label="倒数待核";
        } else if (flag.state === "invalid") {
            result.label="脱战异常";
            result.tone="warning";
        } else if (flag.state === "unverified") {
            result.label="脱战待核";
        } else if (flag.state === "stale") {
            result.label=(flag.value ? "已脱战" : "战斗中")+"·旧";
        } else if (conflict) {
            result.label="脱战待同步";
            result.tone="warning";
        } else {
            result.current=true;
            result.out=flag.value;
            result.tone=flag.value ? "green" : "warning";
            result.label=flag.value ? "已脱战" : "战斗中";
            if (!flag.value && counter.state === "fresh" && counter.value > 0)
                result.label=secondsVerified ? raw(counter.value)+"s后脱战" : "倒数 "+raw(counter.value);
        }
    }
    result.description=description(result,connected,secondsVerified,previewOnly);
    return result;
}
function description(item,connected,secondsVerified,previewOnly) {
    const status=value => previewOnly && value.state === "fresh" ? "mock新鲜态" : stateLabels[value.state];
    const notes=[previewOnly ? "离线mock绘制；不是实时机器人状态。" : "选手端导出本机接收视图；不证明网络来源认证或同一快照。",
        "当前客户端 "+item.clientId+"；RobotStaticStatus.robot_id "+raw(item.subject.value)+"（"+status(item.subject)+"）",
        "RobotDynamicStatus.is_out_of_combat："+raw(item.flag.value)+"（"+status(item.flag)+"）",
        "RobotDynamicStatus.out_of_combat_countdown："+raw(item.counter.value)+"（"+status(item.counter)+"）",
        "RobotStaticStatus.alive_state："+raw(item.alive.value)+"（"+status(item.alive)+"；0未知／1存活／2战亡）"];
    if (!item.displayable) notes.push("没有有效脱战字段或当前已核对的战亡状态：隐藏内容，保留固定布局槽位，不补false或0。");
    if (!connected) notes.push("选手端已断连：立即停止活动状态图标，保留原值并标断。");
    notes.push(secondsVerified ? "倒数显示单位已由宿主能力确认秒。" : "官方V2.0.0该倒数字段未注明单位；宿主能力默认false，不自行加秒单位。");
    notes.push("倒数只显示收到的原值，UI不减秒，不在0时切换脱战；单独倒数不确认布尔状态。旧倒数不使新鲜标记变旧，也不伪装成当前倒数。");
    notes.push("true与新鲜正倒数并存时等待同步；字段独立合并，不据此判定同帧协议错误。战亡只由同主体新鲜alive_state=2确认，不从HP=0推断。");
    notes.push("接口没有逐字段数值年龄／快照ID，UI不编造时间；真实身份、会话与生产接收仍需后续验收。");
    return notes.join("\n");
}
