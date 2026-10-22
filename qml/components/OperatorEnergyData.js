.pragma library

const rows = [
    {key:"current_chassis_energy",limit:"max_chassis_energy",label:"底盘"},
    {key:"current_buffer_energy",limit:"max_buffer_energy",label:"缓冲"}
];
const labels = {fresh:"新鲜接收值",stale:"旧值",missing:"未提供",invalid:"数值异常",unverified:"时效待核",offline:"断连保留值"};
function uint(value) {return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 4294967295;}
function raw(value) {
    if (value === undefined || value === null) return "未提供";
    if (typeof value === "object") return "非数值对象";
    return String(value).slice(0,256);
}
function field(telemetry,group,key,connected) {
    const value=telemetry?.[group]?.[key],reported=telemetry?.fieldFreshness?.[group]?.[key];
    if (value === undefined || value === null) return {value:value,state:"missing"};
    if (!uint(value)) return {value:value,state:"invalid"};
    if (reported === "missing") return {value:value,state:"missing"};
    if (!connected) return {value:value,state:"offline"};
    // optional字段独立合并；分组新鲜不能证明本字段刚收到，旧SDK只保留待核原值。
    return {value:value,state:["fresh","stale"].includes(reported) ? reported : "unverified"};
}
function view(telemetry,clientId,connected,previewOnly) {
    const subject=field(telemetry,"robotStatic","robot_id",connected);
    const sameSubject=uint(subject.value) && clientId > 0 && subject.value === clientId;
    const wrongSubject=subject.state !== "missing" && uint(subject.value) && subject.value > 0 && subject.value !== clientId;
    const knownSubject=sameSubject && ["fresh","stale","offline"].includes(subject.state);
    return rows.map(spec => {
        const current=field(telemetry,"robotDynamic",spec.key,connected);
        const maximum=field(telemetry,"robotStatic",spec.limit,connected);
        const hasCurrent=current.state !== "missing";
        const numeric=current.state !== "missing" && maximum.state !== "missing" && uint(current.value) && uint(maximum.value);
        const conflict=numeric && current.value > maximum.value;
        const scaleUsable=numeric && maximum.value > 0 && !conflict;
        const states=[current.state,maximum.state,subject.state];
        const live=hasCurrent && scaleUsable && sameSubject && connected && states.every(state => state === "fresh");
        const retained=hasCurrent && scaleUsable && sameSubject && connected && states.every(state => ["fresh","stale"].includes(state));
        const result=Object.assign({},spec,{current:current,maximum:maximum,subject:subject,clientId:clientId,
            identity:String(clientId)+":"+raw(subject.value),hasCurrent:hasCurrent,
            ratioState:live ? "live" : retained ? "retained" : "none",ratio:scaleUsable ? current.value/maximum.value : 0,
            warning:wrongSubject || current.state === "invalid" || maximum.state === "invalid" || conflict,
            caption:"",description:""});
        if (hasCurrent) {
            if (wrongSubject) result.caption=spec.label+" 身份冲突";
            else if (!knownSubject) result.caption=spec.label+" 身份待核";
            else if (current.state === "invalid") result.caption=spec.label+" 数值异常";
            else {
                const notes=[];
                if (!connected) notes.push("断");
                else if (current.state === "stale") notes.push("旧");
                else if (current.state === "unverified") notes.push("待核");
                if (maximum.state === "missing") notes.push("限—");
                else if (maximum.state === "invalid") notes.push("限异常");
                else if (maximum.state === "unverified") notes.push("限待核");
                else if (maximum.state === "stale") notes.push("限旧");
                if (maximum.state !== "missing" && uint(maximum.value) && maximum.value === 0) notes.push("限0");
                else if (conflict) notes.push("值>限");
                if (connected && subject.state === "stale") notes.push("身份旧");
                result.caption=spec.label+" "+raw(current.value)+(notes.length ? " "+notes.join(" ") : "");
            }
        }
        result.description=description(result,connected,previewOnly);
        return result;
    });
}
function description(row,connected,previewOnly) {
    const states=item => previewOnly && item.state === "fresh" ? "mock新鲜态" : labels[item.state];
    const notes=[previewOnly ? "离线mock绘制；不是实际电控、传感器或比赛能量。"
        : "选手端导出本机接收视图；不证明网络来源认证或同一快照。",
        "当前客户端 "+row.clientId+"；RobotStaticStatus.robot_id "+raw(row.subject.value)+"（"+states(row.subject)+"）",
        "RobotDynamicStatus."+row.key+"："+raw(row.current.value)+"（"+states(row.current)+"）",
        "RobotStaticStatus."+row.limit+"："+raw(row.maximum.value)+"（"+states(row.maximum)+"）"];
    if (!row.hasCurrent) notes.push("未提供当前能量：保留原中性槽，隐藏动态填充和可选文字，不补0。");
    if (row.maximum.state !== "missing" && uint(row.maximum.value) && row.maximum.value === 0) notes.push("收到的上限为0；保留原值，无法据此计算比例，不把0/0画成0%或满条。");
    if (row.current.state !== "missing" && row.maximum.state !== "missing" && uint(row.current.value) && uint(row.maximum.value) && row.current.value > row.maximum.value)
        notes.push("当前值大于收到的上限：不截成满条；两字段可能不同快照，不据此确认硬件异常。");
    notes.push(!connected ? "选手端已断连：保留文字并标断，禁止实时填充和补间。"
        : row.ratioState === "live" ? "独立字段均为新鲜接收值；绘制接收值比值，不能证明同帧。"
        : row.ratioState === "retained" ? "暗色比例仅供旧值参考；当前值、上限与主体状态分别说明。" : "没有合格比例：不绘制彩色能量填充。");
    notes.push("本接口没有逐字段数值年龄／快照ID，UI不伪造时间，不猜J／百分比单位或固定上限。真实会话、身份和宿主接线仍须后续验收。");
    return notes.join("\n");
}
