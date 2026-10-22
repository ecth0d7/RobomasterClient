.pragma library
.import "OperatorData.js" as Data
.import "UiFormat.js" as Format
.import "OperatorRosterData.js" as Roster

var items = [
    {key: "remoteHeal", tab: 0, type: 6, label: "恢复血量", icon: "ServerUI_BuyBlood", keyLabel: "Ctrl+1", note: "恢复比例与费用由当前规则／选手端确认"},
    {key: "remote17", tab: 0, type: 5, label: "远程17mm发弹量", icon: "ServerUI_Buy17mm", keyLabel: "Ctrl+2", note: "弹种／数量参数需经宿主核验"},
    {key: "remote42", tab: 0, type: 5, label: "远程42mm发弹量", icon: "ServerUI_Buy42mm", keyLabel: "Ctrl+3", note: "弹种／数量参数需经宿主核验"},
    {key: "buy17", tab: 1, type: 1, label: "现场兑换17mm", icon: "ServerUI_Buy17mm", keyLabel: "Ctrl+1", note: "正整数数量 · 必须为10的倍数"},
    {key: "buy42", tab: 1, type: 2, label: "现场兑换42mm", icon: "ServerUI_Buy42mm", keyLabel: "Ctrl+2", note: "正整数数量 · 需宿主确认兑换资格"},
    {key: "free", tab: 2, type: 3, label: "确认免费复活", icon: "", keyLabel: "Ctrl+1", note: "新鲜待复活、资格与已完成读条"},
    {key: "paid", tab: 2, type: 4, label: "兑换立即复活", icon: "", keyLabel: "Ctrl+2", note: "新鲜资格、报价与足够队伍金币"}
];
function item(key) { return items.find(value => value.key === key) ?? null; }
function quantity(text, type) {
    if (typeof text !== "string" || !/^[1-9][0-9]{0,9}$/.test(text)) return null;
    const value = Number(text);
    return value <= 4294967295 && (type !== 1 || value % 10 === 0) ? value : null;
}
function flagReason(telemetry, group, key) {
    const state = Data.state(telemetry, group, key);
    if (state !== "fresh") return state === "stale" ? "资格字段旧" : "资格字段未提供";
    return telemetry?.[group]?.[key] === true ? "" : "当前条件不满足";
}
function eligibility(telemetry, id, entry, policy, available) {
    if (!entry) return "未选择操作";
    if (!Format.validLogin(id)) return "未选择合法选手端身份";
    if (!available) return "生产通用控制入口未接通";
    if (policy?.allowed !== true) return policy?.reason || "宿主未允许本机此项操作";
    const aliveState = Data.state(telemetry, "robotStatic", "alive_state");
    if (aliveState !== "fresh") return "存活状态旧 / 未提供";
    if (entry.type === 3 || entry.type === 4) {
        if (telemetry?.robotStatic?.alive_state !== 2) return "本机尚未确认战亡";
        const pending = flagReason(telemetry, "robotRespawn", "is_pending_respawn");
        if (pending) return pending;
        const permission = flagReason(telemetry, "robotRespawn", entry.type === 3 ? "can_free_respawn" : "can_pay_for_respawn");
        if (permission) return permission;
        if (entry.type === 3) {
            const current = telemetry?.robotRespawn?.current_respawn_progress, total = telemetry?.robotRespawn?.total_respawn_progress;
            if (Data.state(telemetry, "robotRespawn", "current_respawn_progress") !== "fresh" || Data.state(telemetry, "robotRespawn", "total_respawn_progress") !== "fresh") return "读条字段旧 / 未提供";
            if (!Number.isInteger(current) || !Number.isInteger(total) || current < 0 || total < 0 || current !== total) return "复活读条尚未确认完成";
        } else {
            const cost = telemetry?.robotRespawn?.gold_cost_for_respawn, coins = telemetry?.globalLogistics?.remaining_economy;
            if (Data.state(telemetry, "robotRespawn", "gold_cost_for_respawn") !== "fresh" || Data.state(telemetry, "globalLogistics", "remaining_economy") !== "fresh") return "复活费用 / 金币旧或未提供";
            if (!Number.isFinite(cost) || cost < 0 || !Number.isFinite(coins) || coins < cost) return "金币不足或费用未识别";
        }
        return "";
    }
    if (telemetry?.robotStatic?.alive_state !== 1) return "本机尚未确认存活";
    if (entry.type === 5 || entry.type === 6) return flagReason(telemetry, "robotDynamic", entry.type === 6 ? "can_remote_heal" : "can_remote_ammo");
    if (Data.state(telemetry, "globalLogistics", "remaining_economy") !== "fresh") return "队伍金币旧 / 未提供";
    return telemetry?.globalLogistics?.remaining_economy > 0 ? "" : "队伍金币不足";
}
function fields(entry, policy, amount) {
    // 远程param语义没有在本地V2表中完整定义；旧代码“通常为1”不是依据。
    if (!entry || policy?.paramVerified !== true) return null;
    const result = {cmd_type: entry.type};
    if (policy.paramMode === "none") return result;
    const value = policy.paramMode === "quantity" ? quantity(amount, entry.type) : policy.paramMode === "mapped" ? policy.param : null;
    if (!Number.isInteger(value) || value < 0 || value > 4294967295) return null;
    result.param = value;
    return result;
}


// 本机报价与结果来自同一个Shark模型；不把补充接口解释为正式协议ACK。
function localView(items,id,now,previewOnly) {
    const source=Roster.item(items,id,now,previewOnly);
    const view=source?.state==="fresh" ? source.exchange : null;
    if(!view || view.schema!=="shark-exchange/1" || typeof view.inSupplyZone!=="boolean" || !view.offers)return null;
    const uint=value=>Number.isInteger(value) && value>=0 && value<=4294967295;
    const offers={};
    for(const kind of ["remoteHeal","remote17","remote42","buy17","buy42"]) {
        const offer=view.offers[kind];
        if(!offer || typeof offer.enabled!=="boolean" || typeof offer.reason!=="string" || offer.reason.length>128 || !uint(offer.maxQuantity))return null;
        if(kind.startsWith("remote")) {
            if(!uint(offer.cost) || !uint(offer.amount) || offer.amount===0 || !uint(offer.delaySeconds)
                || !["none","mapped"].includes(offer.paramMode) || offer.paramMode==="mapped" && !uint(offer.param))return null;
        }else if(!uint(offer.unitCost) || offer.unitCost===0)return null;
        offers[kind]=offer;
    }
    let result=null;
    const r=view.result;
    if(r!==null && r!==undefined) {
        if(!Number.isSafeInteger(r.sequence) || r.sequence<=0 || !Number.isSafeInteger(r.receivedAtMs) || r.receivedAtMs<0 || r.receivedAtMs>source.produced_at_ms
            || !["pending","applied","rejected"].includes(r.status) || typeof r.kind!=="string" || r.kind.length>32
            || typeof r.error!=="string" || r.error.length>128 || !uint(r.cmdType) || r.param!==undefined && !uint(r.param)
            || r.remainingSeconds!==undefined && !uint(r.remainingSeconds))return null;
        result=r;
    }
    return {offers:offers,result:result,inSupplyZone:view.inSupplyZone,source:source.source_kind};
}
function quote(view,entry,policy,amount) {
    const offer=view?.offers?.[entry?.key];
    if(!entry || !offer || !offer.enabled)return null;
    const fieldsValue=fields(entry,policy,amount);
    if(!fieldsValue)return null;
    if(entry.tab===0) {
        if(policy.paramMode!==offer.paramMode || policy.paramMode==="mapped" && policy.param!==offer.param)return null;
        return {cost:offer.cost,amount:offer.amount,fields:fieldsValue};
    }
    if(entry.tab===1) {
        const count=quantity(amount,entry.type);
        if(count===null || count>offer.maxQuantity || count*offer.unitCost>4294967295)return null;
        return {cost:count*offer.unitCost,amount:count,fields:fieldsValue};
    }
    return null;
}
