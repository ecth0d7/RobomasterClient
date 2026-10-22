.pragma library
.import "OperatorRosterData.js" as Roster

function source(items,id,now,previewOnly) {
    const item=Roster.item(items,id,now,previewOnly);
    return item?.state==="fresh" && item.source_kind==="local_shark_server"?item:null;
}
function view(items,id,now,previewOnly) {
    if(![3,4,5].includes(id%100))return null;
    const s=source(items,id,now,previewOnly),d=s?.rune_control;
    if(!d || d.version!==1 || ![1,2,3].includes(d.rune_status) || typeof d.operations_allowed!=="boolean")return null;
    for(const key of ["remaining_openings","activations","remaining_seconds","current_group"])
        if(!Number.isSafeInteger(d[key]) || d[key]<0 || d[key]>(key==="current_group"?4:key==="remaining_seconds"?3600:4294967295))return null;
    if(!Array.isArray(d.disallowed_rings) || d.disallowed_rings.length>10 || new Set(d.disallowed_rings).size!==d.disallowed_rings.length
        || !d.disallowed_rings.every(n=>Number.isInteger(n) && n>=1 && n<=10))return null;
    if(!Array.isArray(d.groups) || d.groups.length!==5)return null;
    for(const group of d.groups) {
        if(!Array.isArray(group?.shots) || group.shots.length!==2)return null;
        for(const hit of group.shots) {
            if(!hit || !["pending","hit","miss","invalid"].includes(hit.state))return null;
            if(hit.state==="pending" ? hit.ring!==null : hit.state==="miss" ? hit.ring!==0
                : !Number.isInteger(hit.ring) || hit.ring<1 || hit.ring>10 || (hit.state==="invalid")!==d.disallowed_rings.includes(hit.ring))return null;
        }
    }
    return Object.assign({},d,{source:s});
}
function hitText(hit,known,slot) {
    if(!known)return "—";
    if(hit.state==="pending")return "";
    return hit.state==="invalid" ? "无效" : hit.state==="miss" ? slot===0?"未命中":"+0" : "+"+hit.ring;
}
function matches(model,native) {
    if(!model || model.rune_status!==native?.rune_status)return false;
    const hits=model.groups.reduce((all,g)=>all.concat(g.shots),[]).filter(s=>s.state==="hit");
    if(native.activated_arms!==hits.length)return false;
    if(native.rune_status!==2)return true;
    const average=hits.length?hits.reduce((sum,s)=>sum+s.ring,0)/hits.length:0;
    // 两个独立接收链路只在内容对齐时合并；不由平均环数反推击打记录。
    return typeof native.average_rings==="number" && Number.isFinite(native.average_rings)
        && Math.abs(native.average_rings-average)<=.0001;
}
function rfid(items,id,now,previewOnly) {
    if(id%100!==7)return null;
    const s=source(items,id,now,previewOnly),d=s?.sentry_rfid;
    return d?.version===1 && d.operator_role==="gimbal" && typeof d.recognized==="boolean" ? {recognized:d.recognized,source:s}:null;
}
