.pragma library
.import "OperatorAirData.js" as Air

const names={airsupport_status:"支援状态",left_time:"免费余量",cost_coins:"付费已耗金币",
    is_being_targeted:"激光照射",shooter_status:"发射状态"};
const enumNames={airsupport_status:{0:"未进行支援",1:"空中支援中"},
    is_being_targeted:{0:"未被照射",1:"正在被照射"},
    shooter_status:{0:"锁定·不可解除",1:"发射正常",2:"锁定·可付费解除"}};
const stateNames={fresh:"新鲜接收值",stale:"旧值",missing:"未提供",offline:"断连保留",
    invalid:"类型／值域异常",unverified:"时效待核"};

function prefix(field) {
    return ({stale:"旧·",offline:"断·",invalid:"异常·",unverified:"待核·"})[field.state] ?? "";
}
function view(telemetry,robotId,connected,secondsVerified,previewOnly) {
    const subject=Air.nativeField(telemetry,"robotStatic","robot_id",connected,Air.uint);
    const aerial=[6,106].includes(robotId);
    const same=aerial && subject.value === robotId;
    const foreign=subject.state !== "missing" && Air.uint(subject.value) && subject.value > 0 && subject.value !== robotId;
    const reason=!aerial ? "本机非空中" : !connected ? "选手端断开"
        : foreign ? "身份冲突" : subject.state === "invalid" ? "身份异常"
        : !same || ["missing","unverified"].includes(subject.state) ? "身份待核"
        : subject.state !== "fresh" ? "身份旧" : "";
    const eligible=reason === "";
    const fields={};
    for (const key of Object.keys(names)) {
        const valid=key === "shooter_status" ? value => [0,1,2].includes(value)
            : enumNames[key] ? value => [0,1].includes(value) : Air.uint;
        fields[key]=Air.nativeField(telemetry,"airSupport",key,connected,valid);
    }
    function text(key) {
        const field=fields[key];
        if (field.state === "missing") return names[key]+"：未提供";
        if (reason) return names[key]+"·"+reason;
        if (field.state === "invalid") return names[key]+"异常";
        const value=enumNames[key]?.[field.value] ?? String(field.value);
        return prefix(field)+value;
    }
    const free=fields.left_time,coins=fields.cost_coins;
    function freeText() {
        if (free.state === "missing") return "免费时长：未提供";
        if (reason) return "免费时长·"+reason;
        if (free.state === "invalid") return "免费时长异常";
        // V2表未写left_time单位；只有显式宿主能力可将原始余量标成秒。
        return prefix(free)+(secondsVerified ? "免费剩余 " + free.value.toFixed(1)+" 秒"
            : "单位待核·免费余量 "+free.value);
    }
    const support=fields.airsupport_status,shooter=fields.shooter_status;
    const known=eligible && support.state === "fresh";
    const active=known && support.value === 1,idle=known && support.value === 0;
    const allowed=[active,idle && free.state === "fresh" && free.value > 0,idle,
        active && shooter.state === "fresh" && shooter.value === 2];
    const description=[previewOnly ? "离线mock：模拟AirSupportStatusSync字段，未接选手端／未发送；样例身份 "+robotId
        : "消费接口：官方选手端导出 AirSupportStatusSync；本机 "+robotId+"；字段资格不证明发布者已认证。",
        "robotStatic.robot_id="+Air.raw(subject.value)+"（"+stateNames[subject.state]+"）",
        ...Object.keys(names).map(key => names[key]+"="+Air.raw(fields[key].value)+"（"+stateNames[fields[key].state]+"）"),
        secondsVerified ? "免费余量单位：宿主已明确为秒。" : "免费余量单位未核验，不换算成秒。",
        "逐字段接收时效；没有源端时间戳、同帧证明、呼叫剩余时间、下一次扣费时间或本次扣费报价。",
        "界面资格不代替宿主认证、会话检查、付费确认和最终命令校验。"].join("\n");
    return {subject:subject,fields:fields,reason:reason,eligible:eligible,active:active,idle:idle,allowed:allowed,
        supportText:text("airsupport_status"),freeText:freeText(),
        coinsText:coins.state === "missing" ? "付费已耗：未提供" : reason ? "付费已耗·"+reason
            : coins.state === "invalid" ? "付费金币异常" : prefix(coins)+"付费已耗 "+coins.value+" 金币",
        laserText:"激光："+(fields.is_being_targeted.state === "missing" ? "未提供" : reason ||
            (fields.is_being_targeted.state === "invalid" ? "状态异常"
                : prefix(fields.is_being_targeted)+enumNames.is_being_targeted[fields.is_being_targeted.value])),
        shooterText:text("shooter_status"),
        description:description};
}
