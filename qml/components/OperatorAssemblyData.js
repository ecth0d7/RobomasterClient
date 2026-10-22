.pragma library
.import "OperatorRosterData.js" as Roster

function view(items,id,round,now,previewOnly) {
    if(id%100!==2)return null;
    const source=Roster.item(items,id,now,previewOnly),d=source?.assembly_control;
    if(source?.source_kind!=="local_shark_server" || source.state!=="fresh" || d?.version!==1 || d.round!==round)return null;
    for(const key of ["run_id","difficulty","robot_level_cap","coins_per_ten_seconds","level4_cooldown_seconds"])
        if(!Number.isSafeInteger(d[key]) || d[key]<0 || d[key]>(key==="difficulty"?4:key==="robot_level_cap"?10:key==="level4_cooldown_seconds"?90:4294967295))return null;
    for(const key of ["active","operations_allowed","in_assembly_zone","level4_used","waiting_for_partner","paired","awaiting_exit",
                      "unit_present","auto_unit_insertion","settlement_unit_detected"])
        if(typeof d[key]!=="boolean")return null;
    for(const key of ["first_rates","repeat_rates"])
        if(!Array.isArray(d[key]) || d[key].length!==4 || !d[key].every(n=>Number.isSafeInteger(n) && n>=0 && n<=4294967295))return null;
    if(!Array.isArray(d.first_completed) || d.first_completed.length!==4 || !d.first_completed.every(v=>typeof v==="boolean"))return null;
    const other=d.opponent;
    if(!Number.isInteger(d.outside_remaining_seconds) || d.outside_remaining_seconds<0 || d.outside_remaining_seconds>3)return null;
    if(typeof d.temporary_active!=="boolean" || typeof d.attached!=="boolean"
        || !Number.isInteger(d.exit_buffer_remaining_seconds) || d.exit_buffer_remaining_seconds<0 || d.exit_buffer_remaining_seconds>15)return null;
    if(d.last_outcome!==null && (!Number.isInteger(d.last_outcome) || d.last_outcome<0 || d.last_outcome>8))return null;
    if(![1,2,3].includes(d.basic_state) || !other || other.robot_id!==(id>100?2:102) || typeof other.active!=="boolean"
        || !Number.isInteger(other.difficulty) || other.difficulty<0 || other.difficulty>4 || ![1,2,3].includes(other.basic_state))return null;
    for(const steps of [d.own_steps,other.steps])
        if(!Array.isArray(steps) || steps.length!==3 || !steps.every(v=>v===0 || v===1))return null;
    return Object.assign({},d,{source});
}
function coherent(model,core) {
    return model!==null && model.basic_state===core.basic_state
        && ["putin_state","move_state","rotate_state"].every((key,i)=>core[key]===model.own_steps[i]);
}
