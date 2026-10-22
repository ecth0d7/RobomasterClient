import QtQuick

QtObject {
    id:root
    property string mode:"auto"
    property int robotId:3
    property string aggregationPhase:"ready"
    property string sourcePhase:"absent"
    property int step:0
    property double generatedAt:Date.now()
    readonly property var phases:["none","local","both","partial","expired","withdrawn","conflict","duplicate",
        "frame","calibration-old","unknown-time","future","team-offline","player-offline","zero","local"]
    readonly property string current:mode === "sequence" ? phases[step % phases.length] : mode
    readonly property bool mapFixture:current.startsWith("map-") && ["map-dense","map-coincident","map-edges","map-motion"].includes(current)
    onCurrentChanged:generatedAt=Date.now()
    onStepChanged:if (mode === "map-motion") generatedAt=Date.now()
    onAggregationPhaseChanged:generatedAt=Date.now()
    onSourcePhaseChanged:generatedAt=Date.now()
    property Timer motion:Timer { interval:root.mode === "map-motion" ? 400 : 1200;repeat:true;running:["sequence","map-motion"].includes(root.mode);onTriggered:root.step+=1 }
    readonly property var context:({session_id:"mock-discovery-session",local_revision:step+1,team_revision:step+1,
        team_id:robotId > 100 ? "mock-blue" : "mock-red",match_id:"mock-match",team_epoch:"mock-epoch",team_issuer_id:"mock-leader",
        field_frame_revision:"mock-field-calibration-1",transform_revisions:{"mock-camera-to-field":"mock-transform-1"}})
    readonly property bool localAvailable:!(["none","team","team-identity","peer-official-offline","local-offline","legacy"].includes(current))
        && (current !== "auto" || sourcePhase === "ready")
    readonly property bool teamAvailable:["team","both","team-identity","peer-official-offline","local-offline"].includes(current)
        || mapFixture
        || current === "auto" && ["ready","partial","conflict","zero"].includes(aggregationPhase)
    readonly property bool playerConnected:!["player-offline","requires-player","peer-official-offline"].includes(current)
    readonly property var localView:["none","legacy","team","team-identity","peer-official-offline"].includes(current) || current === "auto" && sourcePhase === "absent" ? null : makeView("local")
    readonly property var teamView:mapFixture || ["team","both","team-identity","peer-official-offline","local-offline","team-offline"].includes(current) || current === "auto" && ["ready","partial","conflict","zero","offline"].includes(aggregationPhase) ? makeView("team") : null
    function observation(channel,id) {
        const source=channel === "local" ? robotId : (robotId > 100 ? 100 : 0) + (robotId % 100 === 1 ? 3 : 1);
        const item={item_id:id,revision:1,source_node:"mock-client-"+source,source_session_id:"mock-source-session-"+source,
            source_id:"mock-camera-"+source,source_robot:source,source_kind:"local_vision",sensor_id:"mock-front-camera",
            producer_version:"drawing.1",data_type:"target.observation",unit:"px",spatial:true,
            frame_id:"camera.front",frame_revision:"mock-image-1",requires_player_client:false,
            source_time_ms:generatedAt-100,source_clock_domain:"mock-camera-clock",produced_at_ms:generatedAt-100,
            received_at_ms:generatedAt-10,clock_basis:"host_epoch_ms",ttl_ms:60000,fresh_for_ms:60000,
            state:"fresh",lifecycle:"active",validation:"mock",mock:true,measurement_validation:"unverified",
            confidence:0.72,priority:1,summary:(channel === "local" ? "本机" : "队友")+"视觉：待确认目标（样例）"};
        if (current === "expired" || current === "auto" && channel === "team" && aggregationPhase === "partial") item.lifecycle="expired";
        if (current === "withdrawn") item.lifecycle="withdrawn";
        if (current === "conflict" || current === "auto" && channel === "team" && aggregationPhase === "conflict") item.lifecycle="conflict";
        if (current === "unknown-time") delete item.produced_at_ms;
        if (current === "future") {item.produced_at_ms=generatedAt+10000;item.received_at_ms=generatedAt+10010;}
        if (current === "unverified") item.validation="unverified";
        if (current === "zero") item.confidence=0;
        if (current === "long") item.summary="本机视觉："+"这是一条明确标注为离线样例的长观察描述，完整出处留在详情。".repeat(5);
        if (current === "frame") {item.frame_id="camera.unknown";item.frame_revision=null;}
        if (current === "expires") {item.ttl_ms=1300;item.fresh_for_ms=1300;}
        if (current === "urgent") {item.priority=3;item.measurement_validation="validated";item.summary="本机感知：紧急状态绘制样例";}
        if (current === "sensor") {
            item.source_kind="local_sensor";item.source_id="mock-board";item.sensor_id="mock-control-board";
            item.data_type="sensor.warning";item.unit="degC";item.spatial=false;item.confidence=null;item.summary="本机电控：温度关注（样例）";
        }
        if (current === "derived") {
            item.source_kind="derived";item.source_id="mock-fusion";item.algorithm_id="mock-association";item.dependencies=["mock-observation-a"];
            item.data_type="derived.notice";item.unit="dimensionless";item.spatial=false;item.summary="本机推导：需再次确认（样例）";
        }
        if (["official","requires-player","peer-official-offline"].includes(current)) {
            item.source_kind="official_player_client";item.player_export_id="mock-player-export";item.requires_player_client=current !== "peer-official-offline";
            item.source_id="mock-player-adapter";item.spatial=false;item.confidence=null;item.unit="dimensionless";
            item.data_type="notification.reference";delete item.sensor_id;
            delete item.frame_id;delete item.frame_revision;item.source_clock_domain="mock-player-clock";
            item.summary="选手端转述：独立通知样例";
        }
        return item;
    }
    function marker(item,channel) {
        return {observation_key:JSON.stringify([item.source_node,item.source_session_id,item.source_id,item.item_id]),observation_revision:item.revision,
            observation_frame_id:item.frame_id,observation_frame_revision:item.frame_revision,
            frame_id:"rm2026.field",frame_revision:"mock-field-calibration-1",unit:"m",x:channel === "local" ? 10.4 : 18.2,y:8.1,
            transform_id:"mock-camera-to-field",transform_revision:"mock-transform-1",transform_validation:"mock",transform_produced_at_ms:generatedAt-500,
            transform_ttl_ms:60000,lifecycle:"active",state:"fresh"};
    }
    function makeView(channel) {
        const item=observation(channel,channel === "local" ? "mock-local-1" : "mock-team-1");
        const view=Object.assign({},context,{version:1,channel:channel,receiver_robot:robotId,revision:step+1,
            view_id:"mock-"+channel+"-view-"+(step+1),mock:true,validation:"mock",clock_basis:"host_epoch_ms",
            published_at_ms:generatedAt,ttl_ms:60000,items:[item],markers:item.spatial ? [marker(item,channel)] : []});
        if (mapFixture) {
            // 明确mock：同点不是合并观测，边界使用真实0/28/15；不挪原有两条样例的位置。
            const count=current === "map-dense" ? 8 : current === "map-edges" ? 4 : 2;
            const edges=[[0,0],[28,0],[0,15],[28,15],[0,7.5],[28,7.5],[14,0],[14,15]];
            view.items=[];view.markers=[];
            for (let i=0;i<count;++i) {
                const observationItem=observation(channel,"mock-"+channel+"-map-"+(i+1));
                observationItem.revision=step+1;
                observationItem.summary=(channel === "local" ? "本机" : "队友")+"地图观察 "+(i+1)+"（离线mock）";
                const point=marker(observationItem,channel),n=i+(channel === "team" ? count : 0);
                if (current === "map-dense") {point.x=18.2+(n%4-1.5)*0.55;point.y=8.1+(Math.floor(n/4)-1.5)*0.55;}
                if (current === "map-coincident") {point.x=19;point.y=9;}
                if (current === "map-edges") {point.x=edges[n][0];point.y=edges[n][1];}
                if (current === "map-motion") {
                    const phase=Math.max(0,step-3)*0.28;
                    point.x=(channel === "local" ? 10.4 : 18.2)+Math.sin(phase+i*0.45)*2.5;
                    point.y=8.1+Math.sin(phase*0.7+i*0.5)*1.2;
                }
                view.items.push(observationItem);view.markers.push(point);
            }
            // 同一几何位置先交替数组顺序，核对布局不能依赖输入数组顺序或刷新年龄。
            if (current === "map-motion" && step%2) {view.items.reverse();view.markers.reverse();}
        }
        if (current === "partial") {
            const expired=Object.assign({},item,{item_id:"mock-expired-first",lifecycle:"expired",priority:3});
            view.items=[expired,item];
        }
        if (current === "duplicate") view.items.push(Object.assign({},item,{revision:2,summary:"同一观测的另一版本（样例）"}));
        if (current === "session") view.session_id="mock-old-session";
        if (current === "foreign") view.receiver_robot=robotId+1;
        if (current === "revision") view.revision+=1;
        if (current === "team-identity" && channel === "team") view.team_id="mock-other-team";
        if (current === "map-mismatch" && view.markers.length) view.markers[0].observation_revision+=1;
        if (current === "calibration-old" && view.markers.length) view.markers[0].transform_produced_at_ms=generatedAt-61000;
        if (current === "calibration-revision" && view.markers.length) view.markers[0].transform_revision="mock-retired-transform";
        if (current === "map-duplicate" && view.markers.length) view.markers.push(Object.assign({},view.markers[0],{x:4.2}));
        return view;
    }
}
