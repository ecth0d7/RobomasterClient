.pragma library

function project(items,clientID,round,now) {
    if(!Array.isArray(items) || items.length>2 || !Number.isInteger(clientID)
        || !(clientID>=1 && clientID<=9 || clientID>=101 && clientID<=109)
        || !Number.isSafeInteger(round) || round<1)return [];
    const seen={},result=[];
    for(const item of items) {
        if(!item || !['west','east'].includes(item.node_id))continue;
        seen[item.node_id]=(seen[item.node_id]??0)+1;
        const id=item.source_robot_id;
        if(item.source_kind!=="local_shark_server" || item.validation!=="local_server" || item.source_id!=="SharkDataSever"
            || item.endpoint!=="http://127.0.0.1:2026/api/roster" || item.state!=="fresh" || item.lifecycle!=="active"
            || item.schema!=="shark-rune-map/1" || item.position_kind!=="local_configuration"
            || ![item.produced_at_ms,item.received_at_ms,item.ttl_ms].every(Number.isSafeInteger)
            || item.produced_at_ms>item.received_at_ms || item.received_at_ms>now || item.ttl_ms<=0 || item.ttl_ms>3500
            || now-item.produced_at_ms>=item.ttl_ms || item.source_round!==round || item.source_stage!==4
            || typeof item.snapshot_id!=="string" || !item.snapshot_id.length || item.snapshot_id.length>128
            || ![3,4,5,103,104,105].includes(id) || item.enabled!==true || item.wire_matches_model!==true
            || ![item.x_cm,item.y_cm].every(Number.isSafeInteger) || item.x_cm<0 || item.x_cm>2800 || item.y_cm<0 || item.y_cm>1500
            || typeof item.window_open!=="boolean")continue;
        const open=item.phase==="open" && (item.rune_status===2 || item.rune_status===1 && item.window_open) && item.activated_by==="none";
        const activated=item.phase==="activated" && item.rune_status===3 && item.activated_by===(id>100?"blue":"red");
        if(!open && !activated)continue;
        result.push(Object.assign({},item,{x:item.x_cm/100,y:item.y_cm/100,
            texture:"../resources/player/minimap/map_island_"+(open?"active":item.activated_by)+".png",
            caption:open?"大能量机关开启":(item.activated_by==="blue"?"蓝方":"红方")+"已激活"}));
    }
    return result.filter(item=>seen[item.node_id]===1);
}
