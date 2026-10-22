.pragma library
.import "../../../qml/components/OperatorVisionIdentityData.js" as Identity

// Accepted host snapshots only. This adapter never supplies official map commands
// or changes coordinates: the current 2D field is strictly field.2026 (28 x 15m).
function list(value, maximum) {
    return value && Number.isInteger(value.length) && value.length <= maximum ? Array.from(value) : [];
}
function collect(view, received, now, clientID, radarPoints) {
    const empty={markers:[],total:0,omitted:0,otherFrame:0,imageOnly:0};
    if(view?.schema!=="rm.situation.view/1" || view.display_only!==true
            || !Number.isSafeInteger(view.stamp_ms) || now<view.stamp_ms || now-view.stamp_ms>1500
            || !Number.isFinite(received) || received>now)return empty;
    const elapsed=now-received, records=new Map(), represented=new Set();
    function accept(id, target, team, frame, position, stamp, expires, confidence, uncertainty, conflict) {
        if(typeof id!=="string" || !id || !Number.isSafeInteger(stamp) || stamp>now || now-stamp>5000
                || !Number.isFinite(expires) || expires<=now || position?.length!==2
                || !Array.from(position).every(n=>typeof n==="number" && Number.isFinite(n)))return;
        if(!["field.2026","field.2027"].includes(frame))return;
        if(position[0]<0 || position[0]>28 || position[1]<0 || position[1]>(frame==="field.2027"?16:15))return;
        const key=frame+"|"+id, previous=records.get(key);
        if(previous && previous.stamp>=stamp){previous.conflict=previous.conflict || conflict===true;return;}
        const match=/^(red|blue):([1-7])$/.exec(String(target)), relation=Identity.relation(team,clientID);
        records.set(key,{key,source:id.slice(0,240),sourceNode:id.split('/')[0].slice(0,80),target:String(target).slice(0,100),
            team,frame,x:position[0],y:position[1],stamp,expires,conflict:conflict===true,
            uncertainty:Number.isFinite(uncertainty) && uncertainty>=0 ? uncertainty:null,
            confidence:Number.isFinite(confidence) && confidence>=0 && confidence<=1 ? confidence:null,
            robotId:match ? Number(match[2])+(match[1]==="blue"?100:0):0,relation,
            text:match ? "视"+(relation==="敌方候选"?"敌":relation==="己方候选"?"友":"?")+match[2]+"?":"视?"});
    }
    for(const o of list(view.observations,512)) {
        if(o.kind!=="vision" || typeof o.origin!=="string" || typeof o.source_id!=="string" || typeof o.target_id!=="string")continue;
        const id=o.origin+"/"+o.source_id+"/"+o.target_id;
        if(!Number.isSafeInteger(o.stamp_ms) || !Number.isFinite(o.ttl_ms) || o.ttl_ms<=0 || o.ttl_ms>5000
                || o.stamp_ms>now || o.stamp_ms+o.ttl_ms<=now)continue;
        if(String(o.frame_id).startsWith("camera.") && o.position?.length!==2 && o.bbox){empty.imageOnly++;continue;}
        accept(id,o.target_id,o.team,o.frame_id,o.position,o.stamp_ms,o.stamp_ms+o.ttl_ms,o.confidence,o.uncertainty_m,false);
        represented.add(o.frame_id+"|"+id+"|"+o.stamp_ms);
    }
    // A compact peer view may arrive without raw observations. Use each visual
    // evidence position, including conflicting evidence; never plot an invented
    // average or silently give a peer's fused estimate official robot artwork.
    function tracks(items, frame, peerRemaining) {
        for(const track of list(items,256)) {
            if(!Number.isFinite(track.remaining_ms) || track.remaining_ms<=elapsed)continue;
            for(const e of list(track.evidence,16)) {
                if(e.kind!=="vision")continue;
                const key=frame+"|"+e.id+"|"+e.stamp_ms;
                if(represented.has(key)) {
                    const r=records.get(frame+"|"+e.id);if(r && track.conflict)r.conflict=true;
                    continue;
                }
                const remaining=Math.min(track.remaining_ms,peerRemaining,
                    Number.isFinite(e.remaining_ms)?e.remaining_ms:track.remaining_ms);
                accept(e.id,track.id,track.team,frame,e.position,e.stamp_ms,now+remaining-elapsed,
                    e.confidence,e.uncertainty_m,track.conflict);
            }
        }
    }
    tracks(view.tracks,view.frame_id,5000);
    for(const peer of list(view.peer_views,16))if(peer.remaining_ms>elapsed)tracks(peer.tracks,peer.frame_id,peer.remaining_ms);
    const all=Array.from(records.values()), current=all.filter(r=>r.frame==="field.2026");
    const byRobot=new Map();
    for(const r of current)if(r.robotId){if(!byRobot.has(r.robotId))byRobot.set(r.robotId,[]);byRobot.get(r.robotId).push(r);}
    for(const r of current)if(r.robotId) {
        const others=byRobot.get(r.robotId).concat(list(radarPoints,12).filter(p=>p.robotId===r.robotId));
        if(others.some(p=>Math.hypot(p.x-r.x,p.y-r.y)>2))r.conflict=true;
    }
    // Stable, bounded rendering; every omission remains visible in the legend.
    current.sort((a,b)=>a.key<b.key?-1:a.key>b.key?1:0);
    const groups=new Map(), markers=[];
    for(const r of current){if(!groups.has(r.sourceNode))groups.set(r.sourceNode,[]);groups.get(r.sourceNode).push(r);}
    for(let round=0;markers.length<Math.min(64,current.length);round++)
        for(const group of groups.values())if(round<group.length && markers.length<64)markers.push(group[round]);
    return {markers,total:current.length,omitted:Math.max(0,current.length-64),
        otherFrame:all.length-current.length,imageOnly:empty.imageOnly};
}
function description(marker, now) {
    const m=marker;
    return "视觉估计 · "+m.relation+(m.robotId?" · "+(m.team==="red"?"红":"蓝")+(m.robotId%100)+"（身份候选）":" · 身份未知")
        +"\n来源 "+m.source+"\n坐标 "+m.x.toFixed(2)+", "+m.y.toFixed(2)+" m · "+m.frame
        +"\n误差范围 "+(m.uncertainty===null?"未提供":m.uncertainty.toFixed(2)+" m（启发式估计）")
        +" · 评分 "+(m.confidence===null?"未提供":Math.round(m.confidence*100)+"%（非准确率）")
        +"\n时间 "+new Date(m.stamp).toISOString()+" · 距今 "+Math.max(0,now-m.stamp)+" ms"
        +(m.conflict?"\n来源位置冲突：分别显示，未采用融合位置":"")
        +"\n空心方框及虚线圈表示估计；不代表官方定位。";
}
