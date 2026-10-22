import QtQuick

Item {
    id: root
    visible: false
    property var items: []
    property var unitViews: []
    property var dartViews: []
    property var sentryViews: []
    property var runeMapViews: []
    property var buffViews: []
    function buffProjection(robotId) {
        const matches=buffViews.filter(view=>view.robot_id===robotId);
        return matches.length===1?matches[0]:null;
    }
    property var supportRequest: null
    property double minimumSentryProducedAt:0
    readonly property bool supportBusy:supportRequest!==null
    signal supportFinished(int operatorID,bool accepted,string message)
    property bool running: true
    property var request: null
    readonly property string endpoint: "http://127.0.0.1:2026/api/roster"
    function sentryProjection(robotId) {
        const matches=sentryViews.filter(view=>view.robot_id===robotId);
        return matches.length===1?matches[0]:null;
    }
    function invalidateSentry(producedAt) {minimumSentryProducedAt=Number.isSafeInteger(producedAt)?producedAt:Date.now();sentryViews=[];}
    function submitSentry(operatorID,fields) {
        if(!running || supportRequest)return false;
        const xhr=new XMLHttpRequest();supportRequest=xhr;
        xhr.onreadystatechange=function(){
            if(xhr.readyState!==XMLHttpRequest.DONE || root.supportRequest!==xhr)return;
            supportTimeout.stop();root.supportRequest=null;
            let accepted=false,message="未收到操作结果，请检查服务器回传";
            let producedAt=Date.now();
            try{const response=JSON.parse(xhr.responseText);
                accepted=xhr.status===200 && response.accepted===true;
                if(Number.isSafeInteger(response.result?.received_at_ms))producedAt=response.result.received_at_ms;
                message=accepted?(response.result?.status==="pending"?"远程补给已受理，等待生效":"本机服务器已执行操作")
                    :String(response.result?.error??response.error??message).slice(0,256);
            }catch(error){}
            root.invalidateSentry(producedAt);root.supportFinished(operatorID,accepted,message);root.refresh();
        };
        xhr.open("POST","http://127.0.0.1:2026/api/sentry-support");
        xhr.setRequestHeader("Content-Type","application/json");
        supportTimeout.operatorID=operatorID;supportTimeout.start();
        xhr.send(JSON.stringify({operator_robot_id:operatorID,request:fields}));return true;
    }
    function dartProjection(robotId) {
        const matches=dartViews.filter(view=>view.robot_id===robotId);
        return matches.length===1 ? matches[0] : null;
    }
    function fortressScale(robotId) {
        const matches=unitViews.filter(view=>view.robot_id===robotId);
        return matches.length===1 ? Object.assign({},matches[0],{seconds:matches[0].fortress_scale_seconds,unit:"s"}) : null;
    }
    function unitProjections(robotId, baseDefense) {
        const matches=unitViews.filter(view=>view.robot_id===robotId);
        if(matches.length!==1)return [];
        const view=matches[0];
        return [view.ally,view.enemy].filter(side=>side && ["red","blue"].includes(side.team)).map(side=>Object.assign({},view,{
            team:side.team,unit:"percent",
            team_progress:side.team_progress,team_progress_state:typeof side.team_progress==="number" ? "fresh" : "missing",
            robot_progress:side.robot_progress,robot_progress_state:typeof side.robot_progress==="number" ? "fresh" : "missing",
            remaining_count:side.remaining_count,remaining_count_state:"fresh",
            defense_percent:baseDefense ? side.base_defense_percent : side.outpost_defense_percent,
            defense_percent_state:"fresh"
        }));
    }
    function refresh() {
        if (!running || request) return;
        const xhr = new XMLHttpRequest();
        request = xhr;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || root.request !== xhr) return;
            timeout.stop();
            root.request = null;
            if (!root.running || xhr.status !== 200) { root.items = []; root.unitViews=[]; root.dartViews=[]; root.sentryViews=[]; root.runeMapViews=[]; root.buffViews=[]; return; }
            try {
                const response = JSON.parse(xhr.responseText);
                if (response.schema !== "shark-local-roster/1" || !Array.isArray(response.robots) || response.robots.length > 18)
                    throw new Error("Unexpected local roster response");
                const received = Date.now();
                const stamp={source_kind:"local_shark_server",validation:"local_server",source_id:"SharkDataSever",endpoint:root.endpoint,
                    snapshot_id:String(response.produced_at_ms),produced_at_ms:response.produced_at_ms,received_at_ms:received,ttl_ms:3500,
                    lifecycle:"active",state:"fresh"};
                root.unitViews=Array.isArray(response.unit_views) && response.unit_views.length<=18
                    ? response.unit_views.map(view=>Object.assign({},view,stamp)) : [];
                root.dartViews=Array.isArray(response.dart_views) && response.dart_views.length<=2
                    ? response.dart_views.map(view=>Object.assign({},view,stamp)) : [];
                root.sentryViews=response.produced_at_ms>=root.minimumSentryProducedAt && Array.isArray(response.sentry_views) && response.sentry_views.length<=18
                    ? response.sentry_views.map(view=>Object.assign({},view,stamp)) : [];
                root.runeMapViews=Array.isArray(response.rune_map) && response.rune_map.length<=2
                    ?response.rune_map.map(view=>Object.assign({},view,stamp)):[];
                root.buffViews=Array.isArray(response.buff_views) && response.buff_views.length<=18
                    ?response.buff_views.map(view=>Object.assign({},view,stamp)):[];
                root.items = response.robots.map(robot => ({
                    robot_id: robot.robot_id, source_robot_id: robot.robot_id,
                    source_kind: "local_shark_server", validation: "local_server",
                    source_id: "SharkDataSever", endpoint: root.endpoint,
                    snapshot_id: String(response.produced_at_ms),
                    produced_at_ms: response.produced_at_ms, received_at_ms: received, ttl_ms: 3500,
                    lifecycle: "active", state: "fresh",
                    exchange: robot.exchange,
                    combat_effects:robot.combat_effects,
                    rune_control:robot.rune_control,
                    sentry_rfid:robot.sentry_rfid,
                    sentry_control:robot.sentry_control,
                    assembly_control:robot.assembly_control,
                    map_display:robot.map_display,
                    operator_registered:robot.operator_registered,operator_registered_state:"fresh",
                    expelled:robot.expelled,expelled_state:"fresh",
                    yellow_card:robot.yellow_card,yellow_card_state:"fresh",
                    respawn_invulnerable:robot.respawn_invulnerable,respawn_invulnerable_state:"fresh",
                    rune_active:robot.rune_active,rune_active_state:"fresh",
                    air_support_status:robot.air_support_status,air_support_status_state:"fresh",
                    air_shooter_status:robot.air_shooter_status,air_shooter_status_state:"fresh",
                    air_ammo:robot.air_ammo,air_ammo_state:"fresh",
                    max_health: robot.max_health, max_health_state: "fresh",
                    level: robot.level, level_state: "fresh",
                    max_heat: robot.max_heat, max_heat_state: "fresh",
                    heat_cooldown_rate: robot.heat_cooldown_rate, heat_cooldown_rate_state: "fresh",
                    max_power: robot.max_power, max_power_state: "fresh",
                    connection_state: robot.connection_state, connection_state_state: "fresh",
                    deploy_cooldown_remaining_seconds: robot.deploy_cooldown_remaining_seconds, deploy_cooldown_remaining_seconds_state: "fresh",
                    air_call_remaining_seconds: robot.air_call_remaining_seconds, air_call_remaining_seconds_state: "fresh",
                    air_paid_call: robot.air_paid_call, air_paid_call_state: "fresh",
                    current_respawn_progress: robot.current_respawn_progress, current_respawn_progress_state: "fresh",
                    total_respawn_progress: robot.total_respawn_progress, total_respawn_progress_state: "fresh"
                }));
            } catch (error) { root.items = []; root.unitViews=[]; root.dartViews=[]; root.sentryViews=[]; root.runeMapViews=[]; root.buffViews=[]; }
        };
        xhr.open("GET", endpoint);
        timeout.start();
        xhr.send();
    }
    function stopRequest(cancelSupport) {
        const pending = request;
        request = null;
        timeout.stop();
        if (pending) pending.abort();
        if(cancelSupport!==false){const action=supportRequest;supportRequest=null;supportTimeout.stop();if(action)action.abort();}
    }
    onRunningChanged: {
        if (running) refresh();
        else { stopRequest(); items = []; unitViews=[]; dartViews=[]; sentryViews=[]; runeMapViews=[]; buffViews=[]; }
    }
    Component.onCompleted: refresh()
    Component.onDestruction: stopRequest()
    Timer { interval: 1000; running: root.running; repeat: true; onTriggered: root.refresh() }
    Timer { id: timeout; interval: 1500; onTriggered: { root.stopRequest(false); root.items = []; root.unitViews=[]; root.dartViews=[]; root.sentryViews=[]; root.runeMapViews=[]; root.buffViews=[]; } }
    Timer {id:supportTimeout;property int operatorID:0;interval:2500;onTriggered:{const pending=root.supportRequest;root.supportRequest=null;if(pending)pending.abort();root.invalidateSentry();root.supportFinished(operatorID,false,"请求超时，请核对回传后再操作");}}
}
