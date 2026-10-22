.pragma library
.import "OperatorData.js" as Data

function nativeContextReady(telemetry,id) {
    if(telemetry?.buff?.robot_id!==id || typeof telemetry?.fieldObservation!=="function")return false;
    // 同类型单独刷新type不产生新上下文；等级/时间可以随后分别补齐，
    // 即使数值与上一个类型相同，也必须有当前上下文中的实际接收。
    return ["buff_type","buff_level","buff_max_time","buff_left_time"].every(key=>{
        const sample=telemetry.fieldObservation("buff",key);
        return Number.isSafeInteger(sample?.context_revision) && sample.context_revision>0
            && Number.isSafeInteger(sample?.observation_revision) && sample.observation_revision>=sample.context_revision;
    });
}

const terrainPhases={flyslope:["on","left"],highland:["on","left"],road:["on","left"],tunnel:["on","middle","exit"]};
const terrainNames={flyslope:"飞坡",highland:"跨越高地",road:"跨越公路",tunnel:"跨越隧道"};
const phaseNames={on:"踩上",left:"离开",middle:"穿过中间",exit:"离开起始点"};
function localCollection(view,telemetry,id,now,connected) {
    if(!connected || !view || view.version!==1 || view.robot_id!==id || view.source_robot_id!==id
        || view.source_kind!=="local_shark_server" || view.validation!=="local_server" || view.source_id!=="SharkDataSever"
        || view.endpoint!=="http://127.0.0.1:2026/api/roster" || view.state!=="fresh" || view.lifecycle!=="active"
        || ![view.produced_at_ms,view.received_at_ms,view.ttl_ms].every(Number.isSafeInteger)
        || view.produced_at_ms>view.received_at_ms || view.received_at_ms>now || view.ttl_ms<=0 || view.ttl_ms>3500
        || now-view.produced_at_ms>=view.ttl_ms || typeof view.snapshot_id!=="string" || !view.snapshot_id.length
        || view.snapshot_id.length>128 || view.complete!==true || view.wire_matches_model!==true
        || !Number.isSafeInteger(view.sequence) || view.sequence<0 || !Array.isArray(view.entries) || view.entries.length>8
        || !nativeContextReady(telemetry,id))return null;
    const game=telemetry.gameStatus??({}),wire=telemetry.buff??({}),latest=view.latest;
    if(["current_round","current_stage","is_paused"].some(k=>Data.state(telemetry,"gameStatus",k)!=="fresh")
        || view.round!==game.current_round || view.stage!==game.current_stage || view.paused!==game.is_paused
        || !latest || latest.robot_id!==id
        || ["robot_id","buff_type","buff_level","buff_max_time","buff_left_time"].some(k=>Data.state(telemetry,"buff",k)!=="fresh")
        || ["robot_id","buff_type","buff_level","buff_max_time"].some(k=>wire[k]!==latest[k])
        || !Number.isInteger(wire.buff_left_time) || wire.buff_left_time<0 || wire.buff_left_time>wire.buff_max_time || !Number.isInteger(latest.buff_left_time)
        || Math.abs(wire.buff_left_time-latest.buff_left_time)>1)return null;
    const stamp={robot_id:id,source_kind:"local_shark_server",source_id:"SharkDataSever",snapshot_id:view.snapshot_id,
        state:"fresh",clock_verified:true,lifecycle:"active",collection_complete:true,latest_only:false,age_ms:now-view.produced_at_ms};
    const result=[],seen={};
    for(const e of view.entries) {
        if(!e || !Number.isInteger(e.buff_type) || e.buff_type<1 || e.buff_type>7
            || !Number.isInteger(e.buff_level) || e.buff_level===0 || e.buff_level< -2147483648 || e.buff_level>2147483647
            || ![e.buff_max_time,e.buff_left_time].every(n=>Number.isInteger(n) && n>0 && n<=4294967295)
            || e.buff_left_time>e.buff_max_time)return null;
        const key=e.buff_type+(e.buff_type===2 && e.buff_level<0?"-":"+");
        if(seen[key])return null;seen[key]=true;
        result.push(Object.assign({},e,stamp,{slot_key:key,time_unit:"s",time_pair_valid:true,time_conflict:false,
            raw_buff_max_time:e.buff_max_time,raw_buff_left_time:e.buff_left_time,estimated_left_time:null,
            field_states:{buff_type:"fresh",buff_level:"fresh",buff_max_time:"fresh",buff_left_time:"fresh"}}));
    }
    result.sort((a,b)=>a.buff_type-b.buff_type || Number(a.buff_level<0)-Number(b.buff_level<0));
    if(view.terrain!==null) {
        const t=view.terrain;
        if(!t || !terrainPhases[t.kind]?.includes(t.phase) || ![t.maximum_seconds,t.remaining_seconds].every(n=>Number.isInteger(n)&&n>0&&n<=300)
            || t.remaining_seconds>t.maximum_seconds)return null;
        result.push(Object.assign({},stamp,{slot_key:"terrain",record_kind:"terrain",terrain_kind:t.kind,terrain_phase:t.phase,
            maximum_seconds:t.maximum_seconds,remaining_seconds:t.remaining_seconds,time_pair_valid:true,time_unit:"s"}));
    }
    return result;
}

var names = {1: "攻击增益", 2: "防御增益", 3: "热量冷却", 4: "底盘功率", 5: "回血增益", 6: "可兑换弹量", 7: "地形预备"};
function title(record) {
    if(record.record_kind==="terrain")return terrainNames[record.terrain_kind]+" · "+phaseNames[record.terrain_phase];
    if (record.buff_type === 2 && !Number.isInteger(record.buff_level)) return "防御 / 易伤";
    return record.buff_type === 2 && record.buff_level < 0 ? "易伤" : names[record.buff_type] ?? "未知类型 " + record.buff_type;
}
function value(record) {
    if(record.record_kind==="terrain")return phaseNames[record.terrain_phase]??"—";
    if (!Number.isInteger(record.buff_level)) return "—";
    if ([1, 2, 4, 5].includes(record.buff_type)) return record.buff_level + "%";
    if (record.buff_type === 3) return record.buff_level + " /s";
    // 6没有百分比语义，7不能由增益值猜出是哪块地形。
    return String(record.buff_level);
}
function fieldState(record,key) {
    return record.field_states?.[key] ?? record.state ?? "missing";
}
function hudValue(record) {
    if(record.record_kind==="terrain")return "";
    if (fieldState(record,"buff_level") !== "fresh") return "—";
    // 手册p04用总攻击倍率；协议给的是百分比增益。详情仍保留原始百分比。
    if (record.buff_type === 1 && Number.isInteger(record.buff_level))
        return "×" + Number((1 + record.buff_level / 100).toFixed(2));
    // 冷却协议给增量/s，不能除以未知的基础冷却值伪造×2/×3/×5。
    if (record.buff_type === 3 && record.buff_level > 0) return "UP";
    return value(record).replace(" /s","/s");
}
function hudEligible(record) {
    if(record.record_kind==="terrain")return record.clock_verified===true && record.state==="fresh" && record.lifecycle==="active"
        && terrainPhases[record.terrain_kind]?.includes(record.terrain_phase);
    return record.clock_verified === true && record.state === "fresh" && record.lifecycle === "active"
        && fieldState(record,"buff_type") === "fresh" && record.buff_type >= 1 && record.buff_type <= 7;
}
function stateText(record) {
    if (!record.clock_verified) return "时效待核验";
    if (record.lifecycle === "ended") return "已结束";
    if (record.state === "stale") return "旧";
    if (record.time_conflict) return "时间对冲突";
    const states=Object.values(record.field_states ?? {});
    if (states.includes("stale")) return "部分字段旧";
    if (states.includes("missing")) return "部分字段缺失";
    if (record.buff_type > 7) return "未知类型原值";
    if (!record.time_pair_valid) return "时间比例未确认";
    return "同步有效";
}
function project(items, id, now, previewOnly) {
    if (!Array.isArray(items) || items.length > 16 || !Number.isInteger(id)
        || ![1,2,3,4,5,6,7,8,9].includes(id % 100) || !(id > 0 && id < 10 || id > 100 && id < 110)) return [];
    const result = [], seen = {};
    for (const e of items) {
        if (!e || e.robot_id !== id || !Number.isInteger(e.buff_type) || e.buff_type < 1
            || !["fresh", "stale"].includes(e.state) || !["active", "ended"].includes(e.lifecycle)) continue;
        if (e.source_kind === "mock") { if (!previewOnly || e.validation !== "mock") continue; }
        else if (e.source_kind !== "official_player_client" || e.host_verified !== true || e.validation !== "verified") continue;
        if (typeof e.source_id !== "string" || !e.source_id || e.source_id.length > 128
            || typeof e.snapshot_id !== "string" || !e.snapshot_id || e.snapshot_id.length > 128
            || ![e.produced_at_ms, e.received_at_ms, e.ttl_ms].every(Number.isSafeInteger)
            || e.produced_at_ms > e.received_at_ms || e.received_at_ms > now
            || e.ttl_ms <= 0 || e.ttl_ms > 60000) continue;
        const age = now - e.produced_at_ms;
        if (age < 0 || age >= e.ttl_ms) continue;
        const key = e.buff_type + (e.buff_type === 2 && e.buff_level < 0 ? "-" : "+");
        // 多条同槽记录交由宿主解决，不让renderer挑一条或重复相加。
        seen[key] = (seen[key] ?? 0) + 1;
        if (e.field_states !== undefined && (!e.field_states || typeof e.field_states !== "object"
            || Array.isArray(e.field_states))) continue;
        const r = Object.assign({}, e, {slot_key: key, age_ms: age,
            collection_complete:e.collection_complete === true,latest_only:e.collection_complete !== true});
        if (!Number.isInteger(r.buff_level) || r.buff_level < -2147483648 || r.buff_level > 2147483647) delete r.buff_level;
        for (const key of ["buff_max_time", "buff_left_time"])
            if (!Number.isInteger(r[key]) || r[key] < 0 || r[key] > 4294967295) delete r[key];
        // 新鲜窗口与最终TTL分开；没有源端窗口的旧投影仅保留详情，不能占当前HUD。
        r.clock_verified=Number.isSafeInteger(e.fresh_for_ms) && e.fresh_for_ms > 0 && e.fresh_for_ms <= e.ttl_ms;
        if (!r.clock_verified || age >= e.fresh_for_ms) r.state="stale";
        r.field_states={};
        for (const field of ["buff_type","buff_level","buff_max_time","buff_left_time"]) {
            const supplied=e.field_states === undefined ? e.state : e.field_states[field];
            r.field_states[field]=r[field] === undefined || !["fresh","stale"].includes(supplied) ? "missing"
                : r.state === "stale" || supplied === "stale" ? "stale" : "fresh";
        }
        // 必须先校验原始时间对。不能让40/30经过倒数成为25/30，掩盖源端冲突。
        r.raw_buff_left_time=r.buff_left_time;
        r.raw_buff_max_time=r.buff_max_time;
        r.time_pair_valid=Number.isInteger(r.buff_left_time) && Number.isInteger(r.buff_max_time)
            && r.buff_max_time > 0 && r.buff_left_time <= r.buff_max_time;
        r.time_conflict=Number.isInteger(r.buff_left_time) && Number.isInteger(r.buff_max_time)
            && (r.buff_left_time > r.buff_max_time || r.buff_max_time === 0 && r.buff_left_time > 0);
        if (r.time_unit !== "s" || e.time_unit_verified !== true) r.time_unit = "raw";
        // 本地倒数是显示推导值，单独命名；保持官方buff_left_time原值不变。
        r.estimated_left_time=null;
        if (r.time_unit === "s" && r.state === "fresh" && r.lifecycle === "active" && r.time_pair_valid
            && fieldState(r,"buff_left_time") === "fresh" && fieldState(r,"buff_max_time") === "fresh")
            r.estimated_left_time = Math.max(0, r.buff_left_time - Math.floor(age / 1000));
        r.derived_display = Number.isInteger(r.estimated_left_time) ? {
            field:"estimated_left_time",source_kind:"derived",source_id:"ui.display_clock",
            based_on_source_id:r.source_id,based_on_snapshot_id:r.snapshot_id,computed_at_ms:now
        } : null;
        result.push(r);
    }
    return result.filter(r => seen[r.slot_key] === 1).sort((a, b) => a.buff_type - b.buff_type
        || Number(a.buff_level < 0) - Number(b.buff_level < 0));
}
function timeText(r) {
    if(r.record_kind==="terrain")return r.remaining_seconds+" / "+r.maximum_seconds+" s";
    const left = Number.isInteger(r.buff_left_time) ? r.buff_left_time + (fieldState(r,"buff_left_time") === "stale" ? "旧" : "") : "—";
    const maximum = Number.isInteger(r.buff_max_time) ? r.buff_max_time + (fieldState(r,"buff_max_time") === "stale" ? "旧" : "") : "—";
    return left + " / " + maximum + (r.time_unit === "s" ? " s" : " · 协议值")
        + (Number.isInteger(r.estimated_left_time) ? " · 本地倒数 " + r.estimated_left_time + "s" : "");
}
function fraction(r) {
    if(r.record_kind==="terrain")return hudEligible(r)?r.remaining_seconds/r.maximum_seconds:null;
    return r.clock_verified === true && r.state === "fresh" && r.lifecycle === "active" && r.time_pair_valid
        && fieldState(r,"buff_left_time") === "fresh" && fieldState(r,"buff_max_time") === "fresh"
        && Number.isInteger(r.buff_left_time) && Number.isInteger(r.buff_max_time)
        && r.buff_max_time > 0 && r.buff_left_time <= r.buff_max_time
        ? (Number.isInteger(r.estimated_left_time) ? r.estimated_left_time : r.buff_left_time) / r.buff_max_time : null;
}
