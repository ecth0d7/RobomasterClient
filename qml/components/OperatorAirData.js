.pragma library

const metrics=["ammoMaximum","countermeasureProgress","countermeasureMaximum","countermeasureCount","countermeasureCountMaximum"];
const states={fresh:"新鲜接收值",stale:"旧值",missing:"未提供",invalid:"类型／值域异常",unverified:"时效待核",offline:"断连保留值"};
function uint(value) {return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 4294967295;}
function token(value) {return typeof value === "string" && value.length > 0 && value.length <= 128;}
function raw(value) {return value === undefined || value === null ? "未提供" : typeof value === "object" ? "非标量对象" : String(value).slice(0,256);}
function field(value,reported,connected,valid) {
    if (value === undefined || value === null) return {value:value,state:"missing"};
    if (!valid(value)) return {value:value,state:"invalid"};
    if (reported === "missing") return {value:value,state:"missing"};
    if (!connected) return {value:value,state:"offline"};
    return {value:value,state:["fresh","stale"].includes(reported) ? reported : "unverified"};
}
function nativeField(telemetry,group,key,connected,valid) {
    return field(telemetry?.[group]?.[key],telemetry?.fieldFreshness?.[group]?.[key],connected,valid);
}
function empty(reason) {return {value:undefined,state:"missing",reason:reason ?? "未提供",source_kind:"",source_id:"",snapshot_id:"",scale_id:""};}

// 可选宿主显示视图；不是AirSupportStatusSync的新字段，也不是认证实现。
// 每项独立来源／时间／生命周期；插件缺失不妨碍既有选手端字段绘制。
function projection(data,robotId,sessionId,available,now,previewOnly) {
    const result={fields:{},notes:[]};
    for (const key of metrics) result.fields[key]=empty();
    if (!data) return result;
    if (data.version !== 1 || data.robot_id !== robotId || ![6,106].includes(robotId)
        || !token(sessionId) || data.session_id !== sessionId || !Array.isArray(data.items) || data.items.length > 16) {
        result.notes.push("可选空中视图版本／主体／会话／集合不合格；旧裸字典只作诊断，不补成有效上限或反制数据。");
        return result;
    }
    for (const key of metrics) {
        const matches=data.items.filter(item => item && item.kind === key);
        if (matches.length !== 1) {
            if (matches.length > 1) result.notes.push(key+"同槽重复，全部隔离，不选择最后一项。");
            continue;
        }
        const item=matches[0];
        const mock=previewOnly && item.source_kind === "mock" && item.validation === "mock";
        const trusted=item.host_verified === true && item.validation === "verified"
            && ["official_player_client","local_sensor","local_vision","derived"].includes(item.source_kind);
        const sensor=["local_sensor","local_vision"].includes(item.source_kind);
        const derived=item.source_kind === "derived";
        if ((!mock && !trusted) || item.kind_verified !== true || item.applies_to_robot_verified !== true
            || item.source_robot_id !== robotId || !token(item.source_id) || !token(item.snapshot_id)
            || !token(item.scale_id) || sensor && !token(item.sensor_id)
            || derived && (item.dependencies_verified !== true || !Array.isArray(item.based_on) || item.based_on.length < 1 || item.based_on.length > 8
                || item.based_on.some(dep => !token(dep?.source_id) || !token(dep?.snapshot_id)))) {
            result.notes.push(key+"来源／语义／适用主体／依赖未核对，不进入活动读数。");
            continue;
        }
        const produced=item.produced_at_ms,received=item.received_at_ms;
        if (!["local_receive","host_utc"].includes(item.clock_basis) || !Number.isSafeInteger(produced) || !Number.isSafeInteger(received)
            || produced < 0 || produced > received || received > now
            || item.clock_basis === "local_receive" && produced !== received
            || !Number.isSafeInteger(item.ttl_ms) || item.ttl_ms <= 0 || item.ttl_ms > 60000) {
            result.notes.push(key+"时间／时钟基准不合格；不把原始传感器时钟当UTC。");
            continue;
        }
        const age=now-produced;
        if (item.lifecycle !== "active" || age >= item.ttl_ms) {
            result.notes.push(key+"已过期／结束／撤回；隐藏可选子项，不推移其他槽。");
            continue;
        }
        const freshWindow=Number.isSafeInteger(item.fresh_for_ms) && item.fresh_for_ms > 0 && item.fresh_for_ms <= item.ttl_ms;
        // 年龄只能把明确fresh降为stale，不能把missing／待核状态养成可用旧值。
        let reported=item.state;
        if (!freshWindow) reported=item.state === "missing" ? "missing" : undefined;
        else if (item.state === "fresh" && age >= item.fresh_for_ms) reported="stale";
        result.fields[key]=Object.assign({},item,field(item.value,reported,available,uint),{age_ms:age});
        if (!available) result.notes.push(key+"提供者断开，原值仅作断连保留。");
    }
    return result;
}
function pair(current,maximum,identity,eligible,retained,reason,label) {
    const hasValue=current.state !== "missing";
    const numbers=hasValue && maximum.state !== "missing" && uint(current.value) && uint(maximum.value);
    const over=numbers && current.value > maximum.value;
    const scaleConflict=hasValue && maximum.state !== "missing" && current.scale_id && maximum.scale_id && current.scale_id !== maximum.scale_id;
    const usable=numbers && maximum.value > 0 && !over && !scaleConflict;
    const live=usable && eligible && current.state === "fresh" && maximum.state === "fresh";
    const old=usable && retained && [current,maximum].every(item => ["fresh","stale"].includes(item.state));
    const notes=[];
    if (reason) notes.push(reason);
    if (current.state === "stale") notes.push("旧");
    else if (current.state === "offline") notes.push("断");
    else if (current.state === "unverified" && reason !== "身份待核") notes.push("待核");
    if (maximum.state === "missing") notes.push("限—");
    else if (maximum.state === "stale") notes.push("限旧");
    else if (maximum.state === "offline") notes.push("限断");
    else if (maximum.state === "unverified") notes.push("限待核");
    else if (maximum.state === "invalid") notes.push("限异常");
    if (numbers && maximum.value === 0) notes.push("限0");
    if (over) notes.push("值>限");
    if (scaleConflict) notes.push("尺度冲突");
    const warning=current.state === "invalid" || maximum.state === "invalid" || over || scaleConflict || reason === "身份冲突";
    const text=current.state === "invalid" ? "异常" : raw(current.value)+" / "+(maximum.state === "missing" ? "—" : maximum.state === "invalid" ? "异常" : raw(maximum.value));
    return {current:current,maximum:maximum,hasValue:hasValue,identity:identity,ratio:usable ? current.value/maximum.value : 0,
        ratioState:live ? "live" : old ? "retained" : "none",text:text,notes:notes,caption:(notes.length ? notes.join(" ")+"·" : "")+label,
        tone:warning && eligible ? "warning" : live ? "text" : "muted",numeric:current.state !== "invalid"};
}
function sourcePrefix(a,b) {
    const kinds=[a,b].filter(item => item.state !== "missing").map(item => item.source_kind);
    if (kinds.length === 0) return "";
    if (new Set(kinds).size > 1) return "混·";
    return ({mock:"样·",derived:"推·",local_sensor:"感·",local_vision:"视·"})[kinds[0]] ?? "";
}
function view(telemetry,robotId,connected,data,sessionId,available,now,previewOnly) {
    const subject=nativeField(telemetry,"robotStatic","robot_id",connected,uint);
    const same=[6,106].includes(robotId) && subject.value === robotId;
    const currentSubject=same && connected && subject.state === "fresh";
    const retainedSubject=same && connected && ["fresh","stale"].includes(subject.state);
    const wrong=subject.state !== "missing" && uint(subject.value) && subject.value > 0 && subject.value !== robotId;
    const subjectReason=wrong ? "身份冲突" : !same || !["fresh","stale","offline"].includes(subject.state) ? "身份待核" : subject.state === "stale" ? "身份旧" : "";
    const ammo=nativeField(telemetry,"robotDynamic","remaining_ammo",connected,uint);
    const shooter=nativeField(telemetry,"airSupport","shooter_status",connected,value => [0,1,2].includes(value));
    const extra=projection(data,robotId,sessionId,available,now,previewOnly),fields=extra.fields;
    const ammoView=pair(ammo,fields.ammoMaximum,robotId+":"+raw(subject.value)+":"+sessionId+":"+fields.ammoMaximum.source_id+":"+fields.ammoMaximum.scale_id,
        currentSubject,retainedSubject,subjectReason,"允许发弹量");
    if (ammo.state === "invalid") ammoView.text="弹量异常";
    if (wrong && connected && subject.state === "fresh") ammoView.tone="warning";
    if (fields.ammoMaximum.state !== "missing" && fields.ammoMaximum.source_kind !== "official_player_client")
        ammoView.caption=(ammoView.notes.length ? ammoView.notes.join(" ")+"·" : "")+sourcePrefix(fields.ammoMaximum,empty())+"允许发弹量";
    const progress=pair(fields.countermeasureProgress,fields.countermeasureMaximum,
        robotId+":"+sessionId+":"+fields.countermeasureProgress.source_id+":"+fields.countermeasureProgress.scale_id+":"+fields.countermeasureMaximum.source_id+":"+fields.countermeasureMaximum.scale_id,available,available,"","被瞄");
    const count=pair(fields.countermeasureCount,fields.countermeasureCountMaximum,
        robotId+":"+sessionId+":"+fields.countermeasureCount.source_id+":"+fields.countermeasureCount.scale_id+":"+fields.countermeasureCountMaximum.source_id+":"+fields.countermeasureCountMaximum.scale_id,available,available,"","次数");
    for (const value of [progress,count]) {
        const label=value === progress ? "被瞄" : "次数";
        // 降级标记放最前，长数字省略时仍能看见旧／断／待核，避免只靠灰色区分。
        value.caption=(value.notes.length ? value.notes.join(" ")+"·" : "")+sourcePrefix(value.current,value.maximum)+label+" "+value.text;
    }
    let shooterLabel="",shooterTone="muted";
    const shooterNames={0:"锁定·不可解除",1:"发射正常",2:"锁定·可付费解"};
    if (shooter.state !== "missing") {
        if (!connected) shooterLabel="断·"+(shooterNames[shooter.value] ?? "发射待核");
        else if (subjectReason) {shooterLabel="发射·"+subjectReason;if(wrong && subject.state === "fresh")shooterTone="warning";}
        else if (shooter.state === "invalid") {shooterLabel="发射状态异常";shooterTone="warning";}
        else if (shooter.state === "unverified") shooterLabel="发射待核";
        else if (shooter.state === "stale") shooterLabel="旧·"+shooterNames[shooter.value];
        else {shooterLabel=shooterNames[shooter.value];shooterTone=shooter.value === 1 ? "green" : "warning";}
    }
    const result={ammo:ammoView,progress:progress,count:count,shooter:shooter,shooterLabel:shooterLabel,shooterTone:shooterTone,
        displayable:ammoView.hasValue || progress.hasValue || count.hasValue || shooter.state !== "missing",description:""};
    const detail=item => raw(item.value)+"（"+states[item.state]+"）";
    const notes=[previewOnly ? "离线mock绘制，非实机空中遥测。" : "选手端导出字段与可选宿主投影分开；不证明认证、会话隔离或同帧。",
        "客户端 "+robotId+"；RobotStaticStatus.robot_id "+detail(subject),
        "RobotDynamicStatus.remaining_ammo "+detail(ammo),"AirSupportStatusSync.shooter_status "+detail(shooter)+"；0不可解除锁定／1正常／2可付费解除锁定",
        "原协议没有弹量上限／反制进度及次数，本视图不从手册750／50／5或当前弹量猜上限。"];
    for (const key of metrics) {
        const item=fields[key];
        notes.push(key+" "+detail(item)+(item.source_id ? "；来源 "+item.source_kind+"/"+item.source_id+"；快照 "+item.snapshot_id+"；尺度 "+item.scale_id
            +"；"+(item.clock_basis === "local_receive" ? "接收龄 " : "宿主映射源龄 ")+item.age_ms+"ms；时钟 "+item.clock_basis
            +"；产生／接收 "+item.produced_at_ms+"/"+item.received_at_ms+"；新鲜窗／TTL "+item.fresh_for_ms+"/"+item.ttl_ms+"ms"
            +(item.sensor_id ? "；传感器 "+item.sensor_id : "")
            +(Array.isArray(item.based_on) ? "；依赖 "+item.based_on.map(dep => dep.source_id+"/"+dep.snapshot_id).join(", ") : "") : ""));
    }
    notes.push(...extra.notes);
    notes.push("官方字段无逐字段数值年龄／源时间／AirSupport主体ID，不能以同机缓存证明同帧或发布者认证。left_time是免费支援剩余，不能用作本次呼叫倒数；UI不本地减秒、不修改真实状态或发出动作。");
    result.description=notes.join("\n");
    return result;
}
