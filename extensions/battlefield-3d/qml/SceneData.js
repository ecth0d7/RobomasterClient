.pragma library
.import "../../../qml/components/OperatorData.js" as Data
.import "../../../qml/components/OperatorMapState.js" as MapState
.import "../../../qml/components/OperatorMapHeadingData.js" as Headings
.import "../../../qml/components/OperatorVisionIdentityData.js" as Identity

// Presentation adapters consume accepted host views, never network packets.
// Current MQTT coordinates retain their 2026 identity on the 2027 model.
function list(value, limit) {
    return value && Number.isInteger(value.length) && value.length <= limit ? Array.from(value) : [];
}
function point(x,y,height) {
    return typeof x === "number" && typeof y === "number" && Number.isFinite(x) && Number.isFinite(y)
        && x >= 0 && x <= 28 && y >= 0 && y <= (height??15);
}
function robot(id) { return Number.isInteger(id) && [1,2,3,4,5,6,7].includes(id%100) && (id<100 || id>100 && id<110); }
function camp(id) { return id>100 ? "blue" : "red"; }
function observation(telemetry,group,key,now) {
    if (Data.state(telemetry,group,key)!=="fresh" || typeof telemetry?.fieldObservation!=="function") return null;
    const m=telemetry.fieldObservation(group,key);
    return m?.ingress_clock_verified===true && m.remaining_ms>0 && Number.isSafeInteger(m.received_at_ms)
        && now>=m.received_at_ms && now-m.received_at_ms<Math.min(5000,m.lifetime_ms) ? m : null;
}
function row(key,id,x,y,kind,source,stamp,expires,confidence,heading,team,estimated,frame) {
    const coordinateFrame=frame??"field.2026",height=coordinateFrame==="field.2027"?16:15;
    return {key:key+"@"+coordinateFrame,robotId:id,x,y,kind,source,stamp,expires,coordinateFrame,
        sceneX:(x-14)*100,sceneZ:(height/2-y)*100,
        uncertaintyM:null,sourceNodes:[],evidenceCount:1,
        confidenceText:Number.isFinite(confidence)?Math.round(confidence*100)+"%（内部评分）":"未提供",
        headingValid:heading!==null && Number.isFinite(heading),headingDeg:heading??0,
        team:team??(robot(id)?camp(id):"unknown"),estimated:estimated===true,
        label:robot(id)?(camp(id)==="red"?"红":"蓝")+(id%100):String(id).slice(0,22),
        // Display offset only. The input contract has no measured Z coordinate.
        coordinateNote:coordinateFrame==="field.2027"?"2027来源坐标；高度未知":"2026坐标居中适配到2027模型；高度未知"};
}
function collect(telemetry,connected,clientID,projections,headings,markers,view,viewReceived,now) {
    const rows=[],notes=[],imageObservations=[];let omitted=0;
    function add(r) { if(rows.length>=512){omitted++;return;}if(point(r.x,r.y,r.coordinateFrame==="field.2027"?16:15) && r.expires>now && now>=r.stamp && now-r.stamp<=5000)rows.push(r); }
    const own=telemetry?.robotPosition??{},mx=connected?observation(telemetry,"robotPosition","x",now):null,
        my=connected?observation(telemetry,"robotPosition","y",now):null;
    const ownId=robot(own.robot_id)?own.robot_id:clientID;
    if(mx && my && robot(ownId) && point(own.x,own.y)) {
        const yaw=observation(telemetry,"robotPosition","yaw",now)?own.yaw:null;
        add(row("position:"+ownId,ownId,own.x,own.y,"own","RobotPosition · 接收时间",Math.min(mx.received_at_ms,my.received_at_ms),
            now+Math.min(mx.remaining_ms,my.remaining_ms),null,yaw,camp(ownId),false));
    }
    const radar=connected?observation(telemetry,"radar","radar_single_robot_info",now):null;
    if(radar) {
        const types=[1,2,3,4,6,7],data=list(telemetry?.radar?.radar_single_robot_info,12);
        for(let i=0;i<data.length;i++) {
            const p=data[i];if(!Number.isInteger(p?.target_pos_x)||!Number.isInteger(p?.target_pos_y))continue;
            const x=p.target_pos_x/100,y=p.target_pos_y/100;
            if(!point(x,y)||x===0&&y===0)continue;
            const blue=i<6?clientID<100:clientID>100,id=types[i%6]+(blue?100:0);
            const heading=Headings.headingFor(headings,id,now,false);
            add(row("radar:"+id,id,x,y,"radar","雷达回传 · 接收时间",radar.received_at_ms,now+radar.remaining_ms,
                null,heading?(heading.clockwise?heading.yaw_deg:-heading.yaw_deg):null,camp(id),false));
        }
    }
    if(connected)for(const p of list(projections,18)) {
        const id=p?.robot_id;if(!robot(id))continue;
        const local=MapState.local(projections,id,telemetry?.gameStatus?.current_round??0,now,false);
        if(!local || !local.alive || !local.location_online || !point(local.x_cm/100,local.y_cm/100))continue;
        const s=local.source;
        add(row("local:"+id,id,local.x_cm/100,local.y_cm/100,"local","本地位置来源 · 非官方字段",s.produced_at_ms,
            s.produced_at_ms+s.ttl_ms,null,local.clockwise?local.yaw_deg:-local.yaw_deg,camp(id),false));
    }
    // Discovery has already passed host provenance, frame and lifecycle checks.
    for(const m of list(markers,16)) {
        if(m?.validated_for_ui!==true || m.renderable!==true || m.frame_id!=="rm2026.field" || !point(m.x,m.y))continue;
        const end=Math.min(m.transform_produced_at_ms+m.transform_ttl_ms,now+1000);
        add(row("discovery:"+m.observation_key,"观测",m.x,m.y,m.source_kind==="local_vision"?"vision":"sensor",
            String(m.description??m.source_kind).slice(0,160),m.transform_produced_at_ms,end,null,null,"unknown",true));
    }
    if(view?.schema==="rm.situation.view/1" && view.display_only===true && ["field.2026","field.2027"].includes(view.frame_id)
            && Number.isSafeInteger(view.stamp_ms) && now>=view.stamp_ms && now-view.stamp_ms<=1500) {
        const elapsed=Math.max(0,now-viewReceived);
        function decorate(r,t,e) {
            r.uncertaintyM=Number.isFinite(t.uncertainty_m)?t.uncertainty_m:null;
            r.sourceNodes=Array.from(new Set(e.map(v=>String(v.id).split('/')[0])));
            r.evidenceCount=e.length;
            if(String(t.id).startsWith('anonymous:') || String(t.id).startsWith('vision:'))r.label='未知目标 · '+String(t.id).slice(-6);
            if(e.some(v=>v.kind==='vision')) {
                r.identityCandidate=true;
                r.relationText=Identity.relation(r.team,connected?clientID:0);
                if(robot(r.robotId))r.label+=' · '+(r.relationText==='阵营未知'?'身份候选':r.relationText);
            }
            return r;
        }
        function tracks(items,peer) {
            for(const t of list(items,256)) {
                if(!Number.isSafeInteger(t.stamp_ms)||t.remaining_ms<=elapsed)continue;
                const e=list(t.evidence,16),match=/^(red|blue):([1-7])$/.exec(t.id??""),
                    id=match?Number(match[2])+(match[1]==="blue"?100:0):String(t.id??"未知");
                const expiry=now+t.remaining_ms-elapsed;
                if(!connected && !peer && e.length && e.every(v=>String(v.id).includes("/official.")))continue;
                // Show disagreement at its actual evidence positions; no average winner.
                if(t.conflict===true) {
                    notes.push(String(t.id)+"：来源冲突，未采用融合位置");
                    for(let j=0;j<e.length;j++)if(e[j].position?.length===2)
                        add(decorate(row("conflict:"+peer+":"+t.id+":"+j,id,...e[j].position,"conflict",String(e[j].id).slice(0,160),
                            e[j].stamp_ms,expiry,e[j].confidence,null,t.team,true,view.frame_id),e[j],[e[j]]));
                    continue;
                }
                if(t.position?.length!==2)continue;
                // A plain local radar observation is already shown from the native group.
                if(!peer && radar && e.length===1 && String(e[0].id).includes("/official.radar/"))continue;
                const kind=e.some(v=>v.kind==="vision")?"vision":t.state==="fused_estimate"?"fused":"sensor";
                const source=(peer?"队友 "+peer+" · ":"")+e.map(v=>String(v.id)).join(" + ");
                add(decorate(row("fusion:"+peer+":"+t.id,id,...t.position,kind,source.slice(0,240),t.stamp_ms,expiry,
                    t.confidence,Number.isFinite(t.heading)?90-t.heading*180/Math.PI:null,t.team,true,view.frame_id),t,e));
            }
        }
        tracks(view.tracks,"");
        for(const peer of list(view.peer_views,16))if(peer.frame_id===view.frame_id && peer.remaining_ms>elapsed)tracks(peer.tracks,peer.node_id);
        const represented=new Set();
        for(const t of list(view.tracks,256))if(t.remaining_ms>elapsed)for(const e of list(t.evidence,16))represented.add(view.frame_id+'|'+String(e.id)+'|'+e.stamp_ms);
        for(const peer of list(view.peer_views,16))if(peer.remaining_ms>elapsed)for(const t of list(peer.tracks,32))if(t.remaining_ms>elapsed)for(const e of list(t.evidence,4))represented.add(peer.frame_id+'|'+String(e.id)+'|'+e.stamp_ms);
        // Preserve accepted sources in other calibrated frames as separate
        // candidates. The receiver's chosen fusion frame must not hide them.
        for(const o of list(view.observations,512)) {
            const identity=String(o.origin)+'/'+o.source_id+'/'+o.target_id;
            if(o.position?.length!==2 || !['field.2026','field.2027'].includes(o.frame_id) || represented.has(o.frame_id+'|'+identity+'|'+o.stamp_ms) ||
                    String(o.source_id).startsWith('official.') || !Number.isSafeInteger(o.stamp_ms) || o.stamp_ms>now || o.stamp_ms+o.ttl_ms<=now)continue;
            const match=/^(red|blue):([1-7])$/.exec(o.target_id??''),id=match?Number(match[2])+(match[1]==='blue'?100:0):String(o.target_id);
            const evidence={id:identity,calibration_id:o.calibration_id,kind:o.kind};
            add(decorate(row('raw:'+identity,id,...o.position,o.kind==='vision'?'vision':'sensor',identity,o.stamp_ms,o.stamp_ms+o.ttl_ms,
                o.confidence,Number.isFinite(o.heading)?90-o.heading*180/Math.PI:null,o.team,true,o.frame_id),
                {id:o.target_id,uncertainty_m:o.uncertainty_m},[evidence]));
        }
        for(const o of list(view.observations,512)) {
            if(o.kind!=='vision' || !String(o.frame_id).startsWith('camera.') || o.position?.length===2 || !o.bbox ||
                    !Number.isSafeInteger(o.stamp_ms) || o.stamp_ms+o.ttl_ms<=now || o.stamp_ms>now)continue;
            imageObservations.push({key:String(o.origin)+'/'+o.source_id+'/'+o.target_id,sourceNode:String(o.origin),
                label:String(o.label??'图像目标'),confidence:o.confidence,bbox:o.bbox,stamp:o.stamp_ms,expires:o.stamp_ms+o.ttl_ms});
        }
        for(const event of list(view.journal?.events,128)) {
            const frame=event.frame_id,height=frame==="field.2027"?16:15;
            if(event.offline || !["field.2026","field.2027"].includes(frame) || !Number.isSafeInteger(event.stamp_ms)
                || !Number.isSafeInteger(event.expires_ms) || event.expires_ms-event.stamp_ms>5000 || event.expires_ms<=now
                || now<event.stamp_ms || event.point?.length!==2 || !point(event.point[0],event.point[1],height))continue;
            const mark=row("manual:"+event.id,event.id,event.point[0],event.point[1],"annotation",
                "人工标注 · "+event.origin,event.stamp_ms,event.expires_ms,null,null,"unknown",true,frame);
            mark.label="人工 / "+String(event.text).slice(0,28);mark.sourceNodes=[event.origin];
            mark.coordinateNote+="；人工选择位置，非传感器测量";add(mark);
        }
        const localCandidates=list(view.boxes,64).filter(b=>b.localization?.positioned!==true).length;
        if(imageObservations.length || localCandidates)notes.push('本机未定位候选 '+localCandidates+' · 已接纳图像观测 '+imageObservations.length+'；未投影到地面');
        if(view.capacity_rejected>0)notes.push('容量保护累计拒绝 '+view.capacity_rejected+' 条观测，请缩小接入范围');
        if(view.omitted_tracks>0)notes.push('态势容量限制：还有'+view.omitted_tracks+'个目标未纳入当前快照');
        const projection=view.vision?.projection;
        if(view.replay_history?.failed)notes.push('防重放记录不可用，新观测已拒绝；请重新启动态势会话');
        if(projection?.enabled && (!projection.ready || String(projection.status).startsWith('图像目标尚未定位')))notes.push(String(projection.status));
    } else if(view?.tracks?.length)notes.push("融合视图过期或坐标系不匹配，未投影");
    const byRobot={};
    for(const r of rows)if(robot(r.robotId)) {
        const key=r.robotId+"@"+r.coordinateFrame;
        (byRobot[key]??(byRobot[key]=[])).push(r);
    }
    for(const id of Object.keys(byRobot)) {
        const group=byRobot[id];
        if(group.some(a=>group.some(b=>Math.hypot(a.x-b.x,a.y-b.y)>2))) {
            notes.push("机器人 "+id+"：来源位置相差超过2m，分别显示冲突候选");
            for(const r of group){r.kind="conflict";r.headingValid=false;r.estimated=true;}
        }
    }
    if(omitted)notes.push('当前显示容量限制：省略'+omitted+'条来源记录');
    return {rows,notes,imageObservations};
}
