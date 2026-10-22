.pragma library
function records(view, now) {
    const valid=view?.schema==="rm.situation.view/1" && view.display_only===true
        && Number.isSafeInteger(view.stamp_ms) && now>=view.stamp_ms && now-view.stamp_ms<=1500;
    return valid?(view.journal?.events??[]).slice(0,128).filter(e=>typeof e.id==="string" && typeof e.origin==="string"
        && Number.isSafeInteger(e.stamp_ms) && Number.isSafeInteger(e.expires_ms) && e.expires_ms>e.stamp_ms && e.expires_ms-e.stamp_ms<=5000
        && ["observe","defend","rally"].includes(e.intent) && typeof e.text==="string")
        .map(e=>Object.assign({},e,{live:!e.offline && now>=e.stamp_ms && now<e.expires_ms,
            state:e.offline?"来源断开 · 历史":now<e.stamp_ms?"时钟超前":now>=e.expires_ms?"已失效 · 历史":"短时有效"})):[];
}
// QVariantList在原生QML边界表现为序列；按长度和数值校验，不能仅用Array.isArray。
function points(view,now,frame) {
    return records(view,now).filter(e=>e.live && e.frame_id===frame && e.point?.length===2
        && Array.from(e.point).every(n=>typeof n==="number" && Number.isFinite(n)) && e.point[0]>=0 && e.point[0]<=28 && e.point[1]>=0 && e.point[1]<=(frame==="field.2027"?16:15)).slice(0,24);
}
