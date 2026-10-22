.pragma library
.import "OperatorData.js" as Data

// 机制ID是相对登录队伍的堡垒，不是基地状态。整个列表同一消息提交后再绘制。
function occupation(telemetry, clientId, blue) {
    if (![1,2,3,4,5,6,7,8,9,101,102,103,104,105,106,107,108,109].includes(clientId)) return null;
    if (Data.state(telemetry,"globalSpecial","mechanism_id") !== "fresh"
        || Data.state(telemetry,"globalSpecial","mechanism_time_sec") !== "fresh") return null;
    const rawIds=telemetry?.globalSpecial?.mechanism_id,rawTimes=telemetry?.globalSpecial?.mechanism_time_sec;
    if(!rawIds || !rawTimes || typeof rawIds!=="object" || typeof rawTimes!=="object"
        || !Number.isInteger(rawIds.length) || !Number.isInteger(rawTimes.length)
        || rawIds.length!==rawTimes.length || rawIds.length>16 || rawIds.length<0)return null;
    const ids=Array.from(rawIds),times=Array.from(rawTimes);
    const mechanism = blue === (clientId > 100) ? 1 : 2;
    const matches = ids.map((id,index)=>id === mechanism ? index : -1).filter(index=>index >= 0);
    if (matches.length > 1) return null;
    if (!matches.length) return {occupied:false,mechanism_id:mechanism};
    const seconds = times[matches[0]];
    if (!Number.isSafeInteger(seconds) || seconds < 0 || seconds > 2147483647) return null;
    return {occupied:true,seconds:seconds,mechanism_id:mechanism};
}

// 协议只有时间参数，没有整圈进度尺度。必须另有经核实的赛季规则／适配器，mock不能进生产。
function scaleSeconds(scale, previewOnly) {
    if (!scale || scale.state !== "fresh" || scale.unit !== "s" || typeof scale.seconds !== "number"
        || !Number.isFinite(scale.seconds) || scale.seconds <= 0 || scale.seconds > 86400
        || typeof scale.source_id !== "string" || !scale.source_id || scale.source_id.length > 128) return null;
    if (scale.source_kind === "mock") return previewOnly && scale.validation === "mock" ? scale.seconds : null;
    if(scale.source_kind==="local_shark_server") {
        const now=Date.now();
        return scale.validation==="local_server" && scale.source_id==="SharkDataSever"
            && scale.endpoint==="http://127.0.0.1:2026/api/roster"
            && [scale.produced_at_ms,scale.received_at_ms,scale.ttl_ms].every(Number.isSafeInteger)
            && scale.produced_at_ms<=scale.received_at_ms && scale.received_at_ms<=now
            && scale.ttl_ms>0 && scale.ttl_ms<=60000 && now-scale.produced_at_ms<scale.ttl_ms ? scale.seconds : null;
    }
    return scale.source_kind === "season_rules" && scale.host_verified === true && scale.validation === "verified"
        && typeof scale.reference_version === "string" && scale.reference_version ? scale.seconds : null;
}
