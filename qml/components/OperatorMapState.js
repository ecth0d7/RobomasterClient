.pragma library
.import "OperatorRosterData.js" as Roster
.import "OperatorData.js" as Data
.import "OperatorStatusData.js" as Status
.import "FieldGeometry.js" as Geometry

function local(items,id,round,now,previewOnly) {
    const source=Roster.item(items,id,now,previewOnly),d=source?.map_display;
    if(source?.source_kind!=="local_shark_server" || source.state!=="fresh" || d?.version!==1 || d.round!==round
        || typeof d.alive!=="boolean" || typeof d.location_online!=="boolean" || typeof d.clockwise!=="boolean"
        || typeof d.yaw_deg!=="number" || !Number.isFinite(d.yaw_deg)
        || ![d.x_cm,d.y_cm].every(n=>Number.isSafeInteger(n) && n>=0 && n<=4294967295))return null;
    return Object.assign({},d,{source});
}
function heading(view,point) {
    // The two channels are not atomic. A local heading only joins nearby
    // positions (50cm for this slow simulator); a held unrelated radar edit
    // must not acquire an apparently authoritative direction.
    if(!view || !view.location_online || !point || Math.hypot(view.x_cm-point.rawX,view.y_cm-point.rawY)>50)return null;
    return {yaw_deg:view.yaw_deg,clockwise:view.clockwise,state:"fresh",source_kind:"local_shark_server",
        source_id:"SharkDataSever",produced_at_ms:view.source.produced_at_ms};
}
function dead(telemetry,clientID,id,view) {
    const health=Status.reading(telemetry,clientID,id,"current_health");
    if(health.state==="fresh" && Number.isFinite(health.value))return health.value<=0;
    return view ? !view.alive:false;
}
function path(telemetry,clientID) {
    const d=telemetry?.robotPath??({}),fields=["intention","start_pos_x","start_pos_y","offset_x","offset_y","sender_id"];
    // Native QVariantList is a QML sequence, not necessarily a JavaScript Array.
    const offsets=[d.offset_x,d.offset_y].map(a=>a?.length===49 ? Array.from(a):[]);
    if(fields.some(k=>Data.state(telemetry,"robotPath",k)==="missing") || d.sender_id!==clientID
        || ![1,2,3].includes(d.intention) || ![1,2,3,4,5,7].includes(clientID%100)
        || ![d.start_pos_x,d.start_pos_y].every(n=>Number.isSafeInteger(n) && n>=0 && n<=65535)
        || !offsets.every(a=>a.length===49 && a.every(n=>Number.isInteger(n) && n>=-128 && n<=127)))return null;
    return {points:Geometry.pathPoints(d.start_pos_x,d.start_pos_y,offsets[0],offsets[1])
            .map(p=>Geometry.boundedPoint(p.x,p.y,28,15)),intention:d.intention,
        stale:fields.some(k=>Data.state(telemetry,"robotPath",k)!=="fresh")};
}
