.pragma library
.import "OperatorData.js" as Data

const reasons = {1:"基地被摧毁",2:"基地剩余血量",3:"前哨站剩余血量",4:"前哨站是否被击毁过",
    5:"全队总攻击伤害",6:"全队机器人总剩余血量",7:"平局",8:"异常终止",9:"主裁判手动判定胜负"};

function reading(telemetry, group, key) {
    const value=telemetry?.[group]?.[key], state=Data.state(telemetry,group,key);
    if(!Number.isSafeInteger(value) || value<0 || value>4294967295 || state==="missing")
        return {value:null,text:"—",state:"missing"};
    return {value:value,text:String(value)+(state==="fresh"?"":" · 旧"),state:state};
}
function finalField(telemetry,key) {
    const item=reading(telemetry,"gameStatus",key);
    // 边界取阶段/局次实际变化；重复同值心跳不能让合法分包结果重新变成缺失。
    const sample=typeof telemetry?.fieldObservation==="function"?telemetry.fieldObservation("gameStatus",key):null;
    const anchors=typeof telemetry?.fieldObservation==="function"
        ?["current_stage","current_round"].map(k=>telemetry.fieldObservation("gameStatus",k)):[];
    const belongs=Number.isSafeInteger(sample?.context_revision) && sample.context_revision>0
        && Number.isSafeInteger(sample?.observation_revision) && sample.observation_revision>=sample.context_revision
        && typeof sample?.observation_session_id==="string" && sample.observation_session_id.length>0
        && anchors.length===2 && anchors.every(a=>a?.observation_session_id===sample.observation_session_id && a.context_revision===sample.context_revision);
    return item.state==="fresh" && belongs ? item : {value:null,text:"—",state:"missing"};
}
function result(telemetry,clientID) {
    const winner=finalField(telemetry,"game_result"),reason=finalField(telemetry,"end_reason");
    const known=[0,1,2].includes(winner.value), abnormal=reason.value===8;
    const conflict=known && (reason.value===7 && winner.value!==0 || winner.value===0 && reason.value>=1 && reason.value<=6);
    const won=known && !abnormal && !conflict && winner.value===(clientID>100?2:1);
    const title=conflict ? "比赛结果待核对" : abnormal ? "比赛异常终止" : !known ? "比赛结束" : winner.value===0 ? "平局"
        : won ? (winner.value===1?"红方胜利":"蓝方胜利") : "比赛失利";
    return {winner:known?winner.value:null,won:won,neutral:abnormal || conflict || !known || winner.value===0,conflict:conflict,
        title:title,reason:conflict ? "结果与结束原因不一致" : reason.value===null || reason.value===255 ? "等待结束原因":reasons[reason.value]??("结束原因 "+reason.value),
        reasonCode:reason.value,round:reading(telemetry,"gameStatus","current_round")};
}
function duration(telemetry) {
    const item=finalField(telemetry,"stage_elapsed_sec");
    if(item.value===null || item.value>2147483647)return "—:—";
    return Math.floor(item.value/60)+":"+String(item.value%60).padStart(2,"0");
}
function pair(telemetry,clientID,allyKey,enemyKey) {
    const ally=reading(telemetry,"globalUnit",allyKey),enemy=reading(telemetry,"globalUnit",enemyKey);
    return clientID>100 ? {red:enemy,blue:ally} : {red:ally,blue:enemy};
}
function health(telemetry,clientID) {
    const values=telemetry?.globalUnit?.robot_health,state=Data.state(telemetry,"globalUnit","robot_health");
    if(state==="missing" || !values || values.length!==10 || !Array.from(values).every(v=>Number.isInteger(v)&&v>=0&&v<=4294967295))
        return {red:{value:null,text:"—"},blue:{value:null,text:"—"}};
    const side=start=>{const value=Array.from(values).slice(start,start+5).reduce((a,b)=>a+b,0);return {value:value,text:String(value)+(state==="fresh"?"":" · 旧"),state:state};};
    return clientID>100?{red:side(5),blue:side(0)}:{red:side(0),blue:side(5)};
}
function comparisons(telemetry,clientID) {
    const missing={red:{value:null,text:"—"},blue:{value:null,text:"—"}};
    return [
        Object.assign({label:"基地血量",glyph:"HP",bars:true},pair(telemetry,clientID,"base_health","enemy_base_health")),
        Object.assign({label:"前哨站血量",glyph:"HP",bars:true},pair(telemetry,clientID,"outpost_health","enemy_outpost_health")),
        Object.assign({label:"伤害血量",icon:"validate_icon_totalhurt.png",bars:true},pair(telemetry,clientID,"total_damage_ally","total_damage_enemy")),
        Object.assign({label:"能量机关",icon:"validate_icon_rune.png",bars:false},missing),
        Object.assign({label:"击杀数",icon:"validate_icon_killcount.png",bars:false},missing),
        Object.assign({label:"地面机器人血量",glyph:"HP",bars:true},health(telemetry,clientID))
    ];
}
function barRatio(item,other) {
    if(item.value===null || other.value===null || item.state!=="fresh" || other.state!=="fresh")return 0;
    const maximum=Math.max(item.value,other.value);return maximum>0?item.value/maximum:0;
}
