.pragma library

const robotIds=[1,2,3,4,5,6,7,8,9,101,102,103,104,105,106,107,108,109];
const states={fresh:"新鲜接收值",stale:"旧值",missing:"未提供",invalid:"类型／值域异常",unverified:"逐字段时效待核",offline:"断连保留"};
const thresholds=[0,550,1100,1650,2200,2750,3300,3850,4400,5000];
function uint(value) {return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 4294967295;}
function raw(value) {return value === undefined || value === null ? "未提供" : typeof value === "object" ? "非数值对象" : String(value).slice(0,256);}
function field(telemetry,group,key,connected) {
    const value=telemetry?.[group]?.[key],reported=telemetry?.fieldFreshness?.[group]?.[key];
    if (value === undefined || value === null || reported === "missing") return {value:value,state:"missing"};
    if (!uint(value)) return {value:value,state:"invalid"};
    if (!connected) return {value:value,state:"offline"};
    return {value:value,state:["fresh","stale"].includes(reported) ? reported : "unverified"};
}
function subjectView(telemetry,robotId,connected) {
    const source=field(telemetry,"robotStatic","robot_id",connected);
    const same=robotIds.includes(robotId) && source.value === robotId;
    const foreign=source.state !== "missing" && uint(source.value) && source.value > 0 && !same;
    const reason=!robotIds.includes(robotId) ? "身份待核" : foreign ? "身份冲突"
        : source.state === "invalid" ? "身份异常" : !connected ? "选手端断开"
        : !same || ["missing","unverified"].includes(source.state) ? "身份待核"
        : source.state !== "fresh" ? "身份旧" : "";
    return {field:source,reason:reason,eligible:reason === "",
        retained:same && connected && ["fresh","stale"].includes(source.state)};
}
function subjectMarker(subject) {
    return ({"身份冲突":"异机","身份异常":"身份异常","选手端断开":"断","身份待核":"待核","身份旧":"身份旧"})[subject.reason] ?? "";
}
function contextDescription(subject,robotId,previewOnly) {
    return [(previewOnly ? "离线mock绘制；不是实际比赛数据。" : "官方选手端导出消费视图；本界面不证明来源认证。"),
        "本机="+robotId+"；RobotStaticStatus.robot_id="+raw(subject.field.value)+"（"+states[subject.field.state]+"）",
        subject.reason || "当前连接与新鲜同机编号已核对。"].join("\n");
}
function fieldDescription(group,key,item) {return group+"."+key+"="+raw(item.value)+"（"+states[item.state]+"）";}
function healthView(telemetry,robotId,connected,subject,previewOnly) {
    const current=field(telemetry,"robotDynamic","current_health",connected);
    const maximum=field(telemetry,"robotStatic","max_health",connected);
    const present=current.state !== "missing";
    const numeric=present && maximum.state !== "missing" && uint(current.value) && uint(maximum.value);
    const over=numeric && current.value > maximum.value;
    const usable=numeric && maximum.value > 0 && !over;
    const live=usable && subject.eligible && current.state === "fresh" && maximum.state === "fresh";
    const retained=usable && subject.retained && [current,maximum].every(f => ["fresh","stale"].includes(f.state));
    const warning=["身份冲突","身份异常"].includes(subject.reason) || current.state === "invalid" || maximum.state === "invalid" || over;
    let marker=subjectMarker(subject);
    if (!marker) marker=current.state === "invalid" ? "" : current.state === "stale" ? "旧" : current.state === "unverified" ? "待核"
        : maximum.state === "missing" ? "限—" : maximum.state === "invalid" ? "限异常" : maximum.state === "stale" ? "限旧"
        : maximum.state === "unverified" ? "限待核" : maximum.value === 0 ? "限0" : over ? "超限" : "";
    const text=!present ? "" : current.state === "invalid" ? "数据异常" : raw(current.value)+" / "
        +(maximum.state === "missing" ? "—" : maximum.state === "invalid" ? "异常" : raw(maximum.value));
    return {current:current,maximum:maximum,present:present,text:text,marker:present ? marker : "",warning:warning,
        identity:String(robotId)+":"+raw(subject.field.value)+":"+raw(maximum.value),
        ratioState:live ? "live" : retained ? "retained" : "none",ratio:usable ? current.value/maximum.value : 0,
        tone:warning ? "warning" : subject.eligible && current.state === "fresh" ? "text" : "muted",
        description:[contextDescription(subject,robotId,previewOnly),fieldDescription("RobotDynamicStatus","current_health",current),
            fieldDescription("RobotStaticStatus","max_health",maximum),
            !present ? "当前生命未提供：保留中性原槽，不补0、不显示可选数字或彩填。" : "真实0保留；只有合格正上限才计算接收值比例。",
            over ? "当前值大于收到的上限：不截为满条；静态／动态可能异步，不认定机器人硬件故障。" : "生命上限只取原生max_health，不按等级／性能猜测，不在UI结算升级加血。",
            live ? "比例依据独立fresh字段推导；不能证明同帧。" : retained ? "暗色比例仅供旧值参考；不补间。" : "没有合格比例；彩色填充不显示。",
            "HP=0不等于已确认战亡；头像使用独立alive_state资格。",
            "消息没有源会话／快照／逐字段数值年龄；不伪造时间。接收、认证、重连屏障仍待生产验收。"].join("\n")};
}
function levelView(telemetry,connected,subject) {
    const received=field(telemetry,"robotStatic","level",connected);
    const present=received.state !== "missing",valid=uint(received.value) && received.value >= 1 && received.value <= 10;
    const source=present && !valid ? Object.assign({},received,{state:"invalid"}) : received;
    const live=present && valid && subject.eligible && source.state === "fresh";
    const invalid=present && !valid;
    const marker=subjectMarker(subject) || (invalid ? "异常" : source.state === "stale" ? "旧" : source.state === "unverified" ? "待核" : "");
    return {field:source,present:present,valid:valid,live:live,invalid:invalid,marker:marker,
        showGlyph:present && valid && !["身份冲突","身份异常"].includes(subject.reason),
        warning:invalid || ["身份冲突","身份异常"].includes(subject.reason)};
}
function experienceView(telemetry,robotId,connected,subject,level,rulesVersion,previewOnly) {
    const role=robotId%100,eligible=[1,3,4,5,6].includes(role);
    const current=field(telemetry,"robotDynamic","current_experience",connected);
    const remaining=field(telemetry,"robotDynamic","experience_for_upgrade",connected);
    const rulesKnown=rulesVersion === "2026-v2.2.0";
    const span=rulesKnown && level.present && level.valid && level.field.value < 10 ? thresholds[level.field.value]-thresholds[level.field.value-1] : 0;
    const maximumLevel=eligible && rulesKnown && level.live && level.field.value === 10;
    const present=eligible && (current.state !== "missing" || remaining.state !== "missing" || maximumLevel);
    // 当前经验的累计口径未核实，不当作分母，也不把其存在当成同帧证明。
    const usable=eligible && rulesKnown && level.present && span > 0 && remaining.state !== "missing" && uint(remaining.value) && remaining.value <= span;
    const live=usable && subject.eligible && level.field.state === "fresh" && remaining.state === "fresh";
    const retained=usable && subject.retained && [level.field,remaining].every(f => ["fresh","stale"].includes(f.state));
    const warning=level.invalid || current.state === "invalid" || remaining.state === "invalid"
        || span > 0 && remaining.state !== "missing" && uint(remaining.value) && remaining.value > span
        || ["身份冲突","身份异常"].includes(subject.reason);
    const marker=subject.reason ? ({"身份冲突":"异","身份异常":"!","选手端断开":"断","身份待核":"?","身份旧":"旧"})[subject.reason]
        : warning ? "!" : maximumLevel ? "满" : !rulesKnown ? "?"
        : [level.field,remaining].some(f => f.state === "stale") ? "旧"
        : [level.field,remaining].some(f => f.state === "unverified") ? "?"
        : !usable ? "—" : "";
    const ratio=usable ? 1-remaining.value/span : 0;
    return {present:present,current:current,remaining:remaining,maximumLevel:maximumLevel,rulesKnown:rulesKnown,
        ratio:ratio,ratioState:live ? "live" : retained ? "retained" : "none",marker:marker,warning:warning,
        identity:String(robotId)+":"+raw(subject.field.value)+":"+raw(level.field.value)+":"+rulesVersion,
        description:[contextDescription(subject,robotId,previewOnly),fieldDescription("RobotStaticStatus","level",level.field),
            fieldDescription("RobotDynamicStatus","current_experience",current),fieldDescription("RobotDynamicStatus","experience_for_upgrade",remaining),
            "所选规则="+(rulesVersion || "未选择")+(rulesKnown ? "；当前级间距="+(span > 0 ? span : maximumLevel ? "无下一等级" : "未确定") : "；不猜赛季规则或上限"),
            maximumLevel ? "已达所选规则等级上限；没有下一等级分母，不画下一等级进度。" : live || retained
                ? (live ? "推导本级进度=" : "旧值推导本级进度=")+Math.round(ratio*100)+"%；依据1−仍需经验/本级规则跨度，不是收到的官方百分比。"
                : "没有合格经验比例；不把超出跨度或缺失值裁为0%／100%。",
            "当前经验原值的累计口径未核实，未参与计算；该字段缺失不阻止合格的等级＋仍需经验推导。",
            live ? "仅连续合格、同主体／等级／规则且非零的接收目标补间。"
                : retained ? "暗色弧段为旧值参考；失效／换主体／等级／规则时停止补间。" : "无合格当前比例，不显示经验填充或补间。",
            "升级剩余0可画本级100%，UI不自动升级／加血。工程／哨兵／雷达不补经验；5号是已有步兵渲染入口，实际赛事部署适用仍待核实。",
            "原生字段无源会话／快照／逐字段数值年龄；本显示不证明同帧、认证或真实功能验收。"].join("\n")};
}
function view(telemetry,robotId,connected,rulesVersion,previewOnly) {
    const subject=subjectView(telemetry,robotId,connected);
    const level=levelView(telemetry,connected,subject);
    level.description=contextDescription(subject,robotId,previewOnly)+"\n"+fieldDescription("RobotStaticStatus","level",level.field)
        +"\n等级素材只支持1…10；缺失不补1、0不是有效等级。未知／非法等级保留诊断，不能加载不存在的素材。"
        +"\n是否满级取决于明确选择的规则；本机收到等级不等于已验证现场兵种／规则配置。";
    return {subject:subject,health:healthView(telemetry,robotId,connected,subject,previewOnly),level:level,
        experience:experienceView(telemetry,robotId,connected,subject,level,rulesVersion,previewOnly)};
}
