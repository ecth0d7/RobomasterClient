.pragma library
.import "OperatorAirData.js" as Air

const modules=[
 {key:"main_controller",label:"主控",full:"主控"},{key:"power_manager",label:"电源",full:"电源管理"},
 {key:"video_transmission",label:"图传",full:"图传模块"},{key:"armor",label:"装甲",full:"装甲汇总"},
 {key:"rfid",label:"RFID",full:"RFID模块"},{key:"laser_detection_module",label:"激光",full:"激光检测"},
 {key:"uwb",label:"UWB",full:"定位UWB"},{key:"capacitor",label:"电容",full:"电容"},
 {key:"small_shooter",label:"17mm",full:"17mm机构"},{key:"big_shooter",label:"42mm",full:"42mm机构"},
 {key:"light_strip",label:"灯条",full:"灯条"}
];
// 手册p07是混合状态区，不能把11项模块在线值依次换成这些不同含义。
const slots=[
 {kind:"robot_connection",label:"机器人",yes:"连接正常",no:"未连接"},
 {kind:"remote_controller",label:"遥控器",yes:"连接正常",no:"未连接"},
 {kind:"custom_controller",label:"自定义控制器",full:"自定义控制器",yes:"连接正常",no:"未连接"},
 {kind:"video_link",label:"图传",yes:"",no:""},
 {kind:"rfid_recognition",label:"RFID识别",yes:"已识别",no:"未识别"},
 {kind:"module_group",label:"模块",yes:"提供者报告正常",no:"提供者报告异常"},
 {kind:"uwb_connection",label:"UWB",yes:"在线",no:"离线"},
 {kind:"chassis_power",label:"底盘",yes:"已上电",no:"未上电"},
 {kind:"shooter_17_power",label:"17mm电源",full:"17mm机构电源",yes:"已上电",no:"未上电"},
 {kind:"shooter_42_power",label:"42mm电源",full:"42mm机构电源",yes:"已上电",no:"未上电"}
];
const robotIds=[1,2,3,4,5,6,7,8,9,101,102,103,104,105,106,107,108,109];
const states={fresh:"新鲜接收值",stale:"旧值",missing:"未提供",invalid:"类型／值域异常",unverified:"时效待核",offline:"断连保留"};
function enumValue(value) {return [0,1,2].includes(value);}
function prefix(state) {return ({stale:"旧·",offline:"断·",invalid:"数据异常·",unverified:"待核·",conflict:"冲突·"})[state] ?? "";}
// mock由预览窗口横幅和详情页明确标记；HUD留出真实状态名的最小窗口空间。
function sourcePrefix(kind) {return ({local_sensor:"感·",local_vision:"视·",derived:"推·"})[kind] ?? "";}
function actorPrefix(reason) {return ({"身份冲突":"异机·","身份异常":"身份异常·","身份旧":"身份旧·","身份待核":"待核·","选手端断开":"断·"})[reason] ?? "";}
function nativeField(telemetry,group,key,connected,valid) {
    // SDK明确missing的缓存只保留原值作诊断，不能因旧非法值重新出现异常灯。
    if (telemetry?.fieldFreshness?.[group]?.[key] === "missing")
        return {value:telemetry?.[group]?.[key],state:"missing"};
    return Air.nativeField(telemetry,group,key,connected,valid);
}
function subjectView(telemetry,robotId,connected) {
    const field=nativeField(telemetry,"robotStatic","robot_id",connected,Air.uint);
    const same=robotIds.includes(robotId) && field.value === robotId;
    const foreign=field.state !== "missing" && Air.uint(field.value) && field.value > 0 && field.value !== robotId;
    const reason=!robotIds.includes(robotId) ? "身份待核" : !connected ? "选手端断开" : foreign ? "身份冲突"
        : field.state === "invalid" ? "身份异常" : !same || ["missing","unverified"].includes(field.state) ? "身份待核"
        : field.state !== "fresh" ? "身份旧" : "";
    return {field:field,reason:reason,eligible:reason === ""};
}
function nativeView(telemetry,robotId,connected,previewOnly) {
    const subject=subjectView(telemetry,robotId,connected),fields={};
    for (const module of modules) {
        const field=nativeField(telemetry,"robotModule",module.key,connected,enumValue);
        const present=field.state !== "missing";
        const current=subject.eligible && field.state === "fresh";
        const valid=enumValue(field.value);
        const name=({0:"离线",1:"在线",2:"安装异常"})[field.value];
        const text=!present ? "未提供" : subject.reason || (field.state === "invalid" ? "数据异常" : prefix(field.state)+name);
        fields[module.key]=Object.assign({},field,{present:present,current:current,native_module:true,
            text:text,tone:current && valid ? field.value === 1 ? "green" : field.value === 0 ? "red" : "warning" : "muted",
            warning:subject.eligible && field.state === "invalid" || ["身份冲突","身份异常"].includes(subject.reason),description:[
                previewOnly ? "离线mock模块字段；未接选手端。" : "消费接口：官方选手端RobotModuleStatus；字段资格不证明源认证。",
                module.full+" / "+module.key+"="+Air.raw(field.value)+"（"+states[field.state]+"）",
                "本机="+robotId+"；robotStatic.robot_id="+Air.raw(subject.field.value)+"（"+states[subject.field.state]+"）",
                subject.reason || "已核对当前连接和本机编号。",
                "0离线／1在线／2安装不规范且按离线处理；不是供电、RFID识别、链路速率或独立装甲编号。",
                "本机逐字段接收时效；消息没有主体、源端时间、会话或快照ID。"].join("\n")});
    }
    return {subject:subject,fields:fields,connection:nativeField(telemetry,"robotStatic","connection_state",connected,value=>[0,1].includes(value)),present:modules.filter(m => fields[m.key].present).length,
        fresh:modules.filter(m => fields[m.key].current).length};
}
function empty(kind,reason) {return {kind:kind,present:false,state:"missing",tone:"muted",caption:"",text:"未提供",description:reason ?? "未提供",source_kind:""};}

// 可选的显示视图，不是RobotModuleStatus扩展字段或认证实现；默认null/false。
function projection(data,robotId,sessionId,available,connected,now,previewOnly) {
    const result={fields:{},notes:[]};
    for (const slot of slots) result.fields[slot.kind]=empty(slot.kind,"该语义尚无提供者／合格记录。");
    if (!data) return result;
    if (data.version !== 1 || !robotIds.includes(robotId) || data.robot_id !== robotId
        || !Air.token(sessionId) || data.session_id !== sessionId || !Array.isArray(data.items) || data.items.length > 32) {
        result.notes.push("底部状态视图的版本／本机／会话／集合不合格。");return result;
    }
    const counts={};
    for (const item of data.items) if (slots.some(s => s.kind === item?.kind)) counts[item.kind]=(counts[item.kind] ?? 0)+1;
    for (const item of data.items) {
        const slot=slots.find(s => s.kind === item?.kind);
        if (!slot) {result.notes.push("未知状态类型未进入HUD。");continue;}
        if (counts[item.kind] !== 1) {result.notes.push(slot.label+"同槽重复，全部隔离；不猜最新来源。");continue;}
        const mock=previewOnly && item.source_kind === "mock" && item.validation === "mock";
        const trusted=item.host_verified === true && item.validation === "verified"
            && ["official_player_client","local_sensor","local_vision","derived"].includes(item.source_kind);
        const sensor=["local_sensor","local_vision"].includes(item.source_kind);
        const derived=item.source_kind === "derived";
        if ((!mock && !trusted) || item.kind_verified !== true || item.applies_to_robot_verified !== true
            || item.source_robot_id !== robotId || !Air.token(item.source_id) || !Air.token(item.snapshot_id)
            || !Number.isFinite(item.confidence) || item.confidence < 0 || item.confidence > 1
            || sensor && !Air.token(item.sensor_id)
            || derived && (item.dependencies_verified !== true || !Array.isArray(item.based_on) || item.based_on.length < 1 || item.based_on.length > 8
                || item.based_on.some(dep => !Air.token(dep?.source_id) || !Air.token(dep?.snapshot_id)))) {
            result.notes.push(slot.label+"来源／语义／主体／置信度／依赖待核，未进入HUD。");continue;
        }
        const produced=item.produced_at_ms,received=item.received_at_ms;
        if (!["local_receive","host_utc"].includes(item.clock_basis) || !Number.isSafeInteger(produced) || !Number.isSafeInteger(received)
            || produced < 0 || produced > received || received > now || item.clock_basis === "local_receive" && produced !== received
            || !Number.isSafeInteger(item.ttl_ms) || item.ttl_ms <= 0 || item.ttl_ms > 60000
            || !Number.isSafeInteger(item.fresh_for_ms) || item.fresh_for_ms <= 0 || item.fresh_for_ms > item.ttl_ms) {
            result.notes.push(slot.label+"时钟／时效窗口未核对，未进入HUD。");continue;
        }
        const age=now-produced;
        if (item.lifecycle !== "active" || age >= item.ttl_ms || !["fresh","stale"].includes(item.state)) {
            result.notes.push(slot.label+"缺失／待核／结束／撤回／过期，未进入HUD。");continue;
        }
        const video=item.kind === "video_link";
        const valid=video ? typeof item.value === "number" && Number.isFinite(item.value) && item.value >= 0 && item.value <= Number.MAX_SAFE_INTEGER
            && item.unit === "Mbps" && ["very_low","low","normal"].includes(item.quality) && Air.token(item.quality_rules_version)
            : typeof item.value === "boolean";
        if (!valid || item.requires_player !== undefined && typeof item.requires_player !== "boolean") {
            result.notes.push(slot.label+"类型／单位／质量语义／依赖不合格，未进入HUD。");continue;
        }
        // local_sensor/local_vision可独立于选手端；官方源失联则立即退出实时状态。
        const online=available && (item.source_kind !== "official_player_client" && item.requires_player !== true || connected);
        const state=!online ? "offline" : item.state === "stale" || age >= item.fresh_for_ms ? "stale" : "fresh";
        const quality=({very_low:"速率极低",low:"速率低",normal:"速率正常"})[item.quality];
        const text=video ? item.value.toFixed(1)+" Mbps · "+quality : item.value ? slot.yes : slot.no;
        // 非确定值仍可查看来源和原值，但不画成已确认的供电／连接灯；这不是认证或赛事阈值。
        const confirmed=item.confidence === 1;
        const uncertain=confirmed ? "" : "待证·";
        const tone=state !== "fresh" || !confirmed ? "muted" : video ? ({very_low:"red",low:"warning",normal:"green"})[item.quality] : item.value ? "green" : "red";
        const receiptAge=now-received;
        result.fields[item.kind]=Object.assign({},item,{present:true,native_module:false,native_summary:false,confirmed:confirmed,state:state,tone:tone,text:prefix(state)+uncertain+text,
            caption:prefix(state)+uncertain+sourcePrefix(item.source_kind)+slot.label,
            age_ms:age,receipt_age_ms:receiptAge,description:[previewOnly ? "离线mock样例（含模拟来源及宿主标志），置信度为人工绘制值；未接实际提供者。" : "可选宿主显示视图；host_verified不是本界面的认证实现。",
                (slot.full ?? slot.label)+"="+Air.raw(item.value)+"；"+text+"；"+states[state],
                "来源="+item.source_kind+" / "+item.source_id+"；机器人="+item.source_robot_id+(sensor ? "；传感器="+item.sensor_id : ""),
                "快照="+item.snapshot_id+"；置信度="+item.confidence+"；validation="+item.validation,
                confirmed ? "确定状态显示；仍不证明来源认证或允许动作。" : "非确定状态仅中性显示待证；不能覆盖已知原生状态。",
                "产生="+produced+"；接收="+received+"；时钟="+item.clock_basis,
                (item.clock_basis === "local_receive" ? "本机接收龄=" : "宿主映射源龄=")+age+"ms；本机接收龄="+receiptAge+"ms",
                "新鲜窗口="+item.fresh_for_ms+"ms；TTL="+item.ttl_ms+"ms；剩余="+(item.ttl_ms-age)+"ms",
                video ? "单位Mbps；质量由提供者规则"+item.quality_rules_version+"给出，UI不猜阈值。" : "Boolean状态不从模块online、游戏存活或本机网络连接推算。",
                derived ? "依赖="+item.based_on.map(dep => dep.source_id+" / "+dep.snapshot_id).join("；") : "",
                "只作renderer显示，不是AI完整快照、权限或机器人命令。"].filter(Boolean).join("\n")});
    }
    return result;
}
function nativeHud(slot,native) {
    // 只有语义完全对应的字段可以进入手册状态槽；模块在线不等于识别、供电或链路速率。
    const robot=slot.kind==="robot_connection";
    const uwb=slot.kind==="uwb_connection";
    if(!robot && !uwb)return empty(slot.kind,"协议未导出"+slot.label+"所需语义；不能从模块在线或本机身份推断。可在模块详情查看原始在线字段。");
    const field=robot ? native.connection : native.fields.uwb;
    if(!field || field.state==="missing")return empty(slot.kind);
    const state=native.subject.eligible ? field.state
        : native.subject.reason==="选手端断开" ? "offline" : "unverified";
    const current=state==="fresh";
    const value=field.value===1;
    const sourceId=robot ? "RobotStaticStatus.connection_state" : "RobotModuleStatus.uwb";
    const text=field.value===2 ? "安装异常" : value ? slot.yes : slot.no;
    return Object.assign({},field,{
        kind:slot.kind,present:true,current:current,native_module:true,
        value:value,state:state,tone:current ? field.value===2 ? "warning" : value ? "green" : "red" : "muted",
        text:current ? text : native.subject.reason || prefix(state)+text,
        caption:(actorPrefix(native.subject.reason) || prefix(state))+slot.label,
        source_kind:"official_player_client",source_id:sourceId,
        description:sourceId+"="+Air.raw(field.value)+"（"+states[state]+"）\n"+(field.description || "只表示该字段定义的连接状态，不推断其他控制器或供电。")
    });
}
function summary(native) {
    const fields=modules.map(m => native.fields[m.key]),present=fields.filter(f => f.present);
    if (!present.length) return empty("module_group");
    const bad=fields.filter(f => f.current && [0,2].includes(f.value));
    const all=fields.every(f => f.current && f.value === 1);
    const current=native.subject.eligible && (bad.length > 0 || all);
    const invalid=fields.some(f => f.state === "invalid");
    const state=current ? "fresh" : fields.some(f => f.state === "offline") ? "offline" : invalid ? "invalid"
        : fields.some(f => f.state === "stale") ? "stale" : "unverified";
    const text=bad.length ? "已收字段中"+bad.length+"项离线／安装异常" : all ? "已收11项在线" : "已收"+present.length+"/11项；不推断整机正常";
    return {kind:"module_group",present:true,state:state,value:all,tone:current ? all ? "green" : "red" : "muted",
        caption:(actorPrefix(native.subject.reason) || prefix(state))+"推·模块"+(current && bad.length ? "!" : ""),
        text:native.subject.reason || (invalid && !current ? "含异常值；" : "")+text,
        source_kind:"derived",source_id:"client.native-module-summary",native_summary:true,
        warning:!current && (invalid || ["身份冲突","身份异常"].includes(native.subject.reason)),
        description:"本客户端从RobotModuleStatus的11项中实际收到的字段汇总，非官方全部硬件总状态。\n"+text+"\n"
            +"\n"+(native.subject.reason || "当前连接与同机编号已核对")+"\n"
            +modules.map(m => m.full+"="+Air.raw(native.fields[m.key].value)+"（"+states[native.fields[m.key].state]+"）").join("\n")};
}
function view(telemetry,robotId,connected,data,sessionId,available,now,previewOnly) {
    const native=nativeView(telemetry,robotId,connected,previewOnly);
    const extra=projection(data,robotId,sessionId,available,connected,now,previewOnly);
    const hud=slots.map(slot => {
        const projected=extra.fields[slot.kind];
        if (slot.kind === "module_group") {
            const known=summary(native);
            if (projected.present && projected.state === "fresh" && projected.confirmed) {
                // 全组正常不能覆盖已知的新鲜模块故障；11项全在线则不证明不存在其他硬件故障。
                if (projected.value === true && known.state === "fresh" && known.value === false)
                    return Object.assign({},known,{state:"conflict",tone:"muted",caption:"冲突·模块",text:"全组正常与已收故障冲突",warning:true,
                        description:known.description+"\n\n"+projected.description});
                return projected;
            }
            return known.state === "fresh" ? known : projected.present ? projected : known;
        }
        const own=nativeHud(slot,native);
        if (projected && projected.present && projected.state === "fresh" && projected.confirmed) {
            if (own.current && own.value !== projected.value)
                return Object.assign({},own,{state:"conflict",tone:"muted",caption:"冲突·"+slot.label,text:"原生／可选来源冲突",warning:true,
                    description:own.description+"\n\n"+projected.description});
            return projected;
        }
        if (own.present && (own.current || !projected?.present)) return own;
        return projected || own;
    });
    return {native:native,hud:hud,notes:extra.notes,displayable:hud.some(f => f.present)};
}
