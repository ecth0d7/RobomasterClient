.pragma library
.import "OperatorRosterData.js" as Roster

// 独立本机模型补充，正式协议只有目标和闸门；不按收到open=2自行造倒数。
function view(projection,robotID,now,previewOnly) {
    if(robotID%100!==8)return null;
    const source=Roster.item(projection?[projection]:[],robotID,now,previewOnly);
    if(!source || source.state!=="fresh" || source.source_kind!=="local_shark_server")return null;
    const d=source.dart_control;
    if(!d || d.version!==1 || ![0,1,2].includes(d.gate) || ![1,2,3,4,5].includes(d.target_id)
        || typeof d.detection_moving!=="boolean" || typeof d.grant_applied!=="boolean" || typeof d.operations_allowed!=="boolean")return null;
    for(const key of ["remaining_openings","opening_remaining_seconds","close_remaining_seconds","cooldown_remaining_seconds","launches"])
        if(!Number.isSafeInteger(d[key]) || d[key]<0 || d[key]>4294967295)return null;
    if(d.next_opening_remaining_seconds!==null && (!Number.isSafeInteger(d.next_opening_remaining_seconds)
        || d.next_opening_remaining_seconds<0 || d.next_opening_remaining_seconds>240))return null;
    return Object.assign({},d,{source:source});
}
