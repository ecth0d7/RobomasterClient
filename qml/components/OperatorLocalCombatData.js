.pragma library
.import "OperatorRosterData.js" as Roster

// 同一Shark模型的可选显示来源；不把模块在线、射速数值或缓冲归零当成效果。
function view(items,robotId,now,previewOnly) {
    const record=Roster.item(items,robotId,now,previewOnly);
    if(!record || record.source_kind!=="local_shark_server" || record.state!=="fresh")return null;
    const effects=record.combat_effects;
    if(!effects || effects.version!==1)return null;
    const result={source:record};
    for(const key of ["shooter_lock_remaining_seconds","respawn_weakness_remaining_seconds","chassis_power_cutoff_remaining_seconds"]) {
        const value=effects[key];
        if(Number.isSafeInteger(value) && value>=0 && value<=3600)result[key]=value;
    }
    return result;
}
function hint(kind,seconds,source,robotId,round) {
    return {kind:kind,active:true,state:"fresh",timer_valid:seconds!==null,
        remaining_seconds:seconds,estimated_remaining_seconds:seconds,
        field_states:{remaining_seconds:seconds===null ? "missing" : "fresh"},
        source_kind:source?.source_kind??"mqtt",source_id:source?.source_id??"Buff",
        snapshot_id:source?.snapshot_id??"协议未提供源快照",session_id:"当前本机接收",
        robot_id:robotId,round:round,clock_basis:"server_model"};
}
