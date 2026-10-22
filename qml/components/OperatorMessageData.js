.pragma library
.import "UiFormat.js" as Format

// HUD通知的本机观察时间／显示窗口，不是官方事件发生时间或处罚有效期。
function observed(text, critical, source, clientId, revision, serial, now, previewOnly) {
    return {version:1,notification_id:"race."+revision+"."+serial,
        text:text,critical:critical===true,source_kind:previewOnly?"mock":"client_observation",
        source_id:source,validation:previewOnly?"mock":"observed_local",
        client_id:clientId,view_revision:revision,observed_at_ms:now,
        clock_basis:"local_ui_receive",hud_window_ms:30000,lifecycle:"active"};
}

function records(items, clientId, revision, now, previewOnly) {
    if (!Array.isArray(items) || !Number.isSafeInteger(now) || !Format.validLogin(clientId)) return [];
    const candidates=items.slice(-30), counts=Object.create(null);
    candidates.forEach(item=>{
        if(typeof item?.notification_id==="string")
            counts[item.notification_id]=(counts[item.notification_id]??0)+1;
    });
    return candidates.filter(item=>{
        if (!item || item.version!==1 || item.lifecycle!=="active"
            || typeof item.text!=="string" || !item.text.trim() || item.text.length>1024
            || typeof item.notification_id!=="string" || !item.notification_id || item.notification_id.length>128
            || counts[item.notification_id]!==1 || item.client_id!==clientId || item.view_revision!==revision
            || typeof item.source_id!=="string" || !item.source_id || item.source_id.length>128
            || item.clock_basis!=="local_ui_receive" || !Number.isSafeInteger(item.observed_at_ms)
            || item.observed_at_ms<0 || item.observed_at_ms>now
            || !Number.isSafeInteger(item.hud_window_ms) || item.hud_window_ms<=0 || item.hud_window_ms>60000)
            return false;
        const source=previewOnly && item.source_kind==="mock" && item.validation==="mock"
            || item.source_kind==="client_observation" && item.validation==="observed_local";
        return source && now-item.observed_at_ms<item.hud_window_ms;
    }).slice(-4);
}

function ageText(item, now) {
    if (!item) return "";
    const age=Math.max(0,now-item.observed_at_ms);
    return age<1000 ? "刚收到" : Math.floor(age/1000)+"s前";
}

function localClockText(item) {
    const date=new Date(item.observed_at_ms);
    return [date.getHours(),date.getMinutes(),date.getSeconds()].map(n=>String(n).padStart(2,"0")).join(":");
}

function clockText(item) {
    return item.match_clock_fresh_at_observation===true && Number.isSafeInteger(item.match_clock_sec) && item.match_clock_sec>=0
        ? Format.time(item.match_clock_sec) : localClockText(item);
}

function explanation(item, now) {
    return item.text+"。"+(item.source_kind==="mock"?"离线mock绘制。":"本机通知观察记录，发布者身份未在此核验。")
        +"来源 "+item.source_id+"；接收显示于 "+localClockText(item)+"（本机UI时钟），"+ageText(item,now)
        +(item.match_clock_fresh_at_observation===true?"；行首为接收时本机所见比赛倒计时 "+clockText(item):"；行首为本机UI接收时刻")
        +"；本地HUD显示窗口 "+item.hud_window_ms/1000+"s。"
        +(item.event_id!==undefined?"事件原编号 "+item.event_id+"；param "+JSON.stringify(item.param)+"。":"")
        +"接收客户端 "+item.client_id+"；本地记录 "+item.notification_id+"；本地消息视图修订 "+item.view_revision+"。"
        +"这不是官方发生时间、处罚剩余时长或机器人动作执行回执。";
}
