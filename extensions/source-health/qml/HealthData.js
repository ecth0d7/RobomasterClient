.pragma library
function inspect(view, now, previous) {
    const accepted=view?.schema==="rm.situation.view/1" && view.display_only===true
        && Number.isSafeInteger(view.stamp_ms) && now>=view.stamp_ms && now-view.stamp_ms<=1500;
    const groups=new Map();
    for(const p of (previous??[]).slice(0,32))groups.set(p.key,Object.assign({},p,{current:0,conflicts:0}));
    const conflicts=new Set();
    if(accepted)for(const t of (view.tracks??[]).slice(0,256))if(t.conflict)
        for(const e of (t.evidence??[]).slice(0,16))conflicts.add(e.id);
    if(accepted)for(const o of (view.observations??[]).slice(0,512)) {
        if(typeof o.origin!=="string" || typeof o.source_id!=="string" || !Number.isSafeInteger(o.stamp_ms)
                || !Number.isFinite(o.ttl_ms) || o.ttl_ms<50 || o.ttl_ms>5000)continue;
        const key=o.origin+"/"+o.source_id;
        const g=groups.get(key)??{key,stamp:0,expires:0,current:0,conflicts:0,frame:o.frame_id,score:null};
        g.current++;g.conflicts+=conflicts.has(key+"/"+o.target_id)?1:0;
        if(o.stamp_ms>=g.stamp){g.stamp=o.stamp_ms;g.expires=o.stamp_ms+o.ttl_ms;g.frame=o.frame_id;g.score=o.confidence;}
        groups.set(key,g);
    }
    const all=Array.from(groups.values()).sort((a,b)=>b.stamp-a.stamp);
    const rows=all.slice(0,32).map(g=>Object.assign(g,{age:now-g.stamp,remaining:Math.max(0,g.expires-now),
        state:!accepted?"视图断开":now<g.stamp?"时钟超前":g.expires<=now || !g.current?"已过期":g.conflicts?"来源冲突":g.expires-now<300?"即将过期":"有效",
        scoreText:Number.isFinite(g.score)?Math.round(g.score*100)+"% · 内部评分":"未提供评分"}));
    return {rows,omitted:Math.max(0,all.length-32),accepted,
        rejected:accepted?Number(view.rejected??0):null,networkRejected:accepted?Number(view.team?.rejected??0):null,
        conflicts:rows.reduce((n,g)=>n+g.conflicts,0),online:accepted?(view.team?.peers_online??[]).length:0};
}
