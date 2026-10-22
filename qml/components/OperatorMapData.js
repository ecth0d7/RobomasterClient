.pragma library
.import "OperatorData.js" as Data
.import "FieldGeometry.js" as Geometry

var markerNames = ["攻击", "防御", "警戒", "自定义"];
var letters = "CDEFGHIJKLNOQRSTUVWXYZ".split("");
var robotTypes = [1, 2, 3, 4, 5, 6, 7, 8, 9];
var robotNames = ["英雄", "工程", "步兵 3", "步兵 4", "步兵 5", "空中", "哨兵", "飞镖", "雷达"];
// 目标可以选择各类编号；雷达只提供其中六类的动态位置。
var enemyTypes = [1, 2, 3, 4, 5, 6, 7, 8, 9];

function allowedAscii(ascii) {
    return Number.isInteger(ascii) && ((ascii>=67 && ascii<=76) || ascii===78 || ascii===79 || (ascii>=81 && ascii<=90));
}

function coordinate(text, maximum) {
    if (!/^\d+(?:\.\d{1,2})?$/.test(text.trim())) return null;
    const value = Number(text);
    return Number.isFinite(value) && value >= 0 && value <= maximum ? value : null;
}
function recipientBytes(ids) {
    // 接收者列表固定七字节：ID 在前，剩余填零；不是位掩码。
    return ids.slice(0, 7).concat(Array(Math.max(0, 7 - ids.length)).fill(0))
              .map(id => id.toString(16).padStart(2, "0")).join("");
}
function recipientIds(hex) {
    if (typeof hex !== "string" || !/^[0-9a-f]{14}$/i.test(hex)) return null;
    return hex.match(/../g).map(pair => parseInt(pair, 16)).filter(id => id !== 0);
}
function markerName(mode, ascii) {
    if (mode === 4) return "自定义 " + (allowedAscii(ascii) ? String.fromCharCode(ascii) : "—");
    return markerNames[mode - 1] ?? "未知标记（" + mode + "）";
}
function scopeName(scope) {
    return ["指定机器人", "广播 · 除哨兵", "广播 · 包含哨兵"][scope] ?? "未知范围";
}

// 两种地图共用同一份回传有效性判定，避免旧分量与新mode拼出不存在的标记。
function receivedMarker(telemetry, clientID, previewOnly) {
    const value=telemetry?.mapClick??{},state=Data.state(telemetry,"mapClick","mode");
    if (state==="missing" || ![1,2,3,4].includes(value.mode) || ![1,2].includes(value.type)) return null;
    const keys=["mode","type"].concat(value.type===1?["map_x","map_y"]:["enemy_id"])
        .concat(value.mode===4?["ascii"]:[]);
    if (!keys.every(key=>Data.state(telemetry,"mapClick",key)!=="missing"
        && (previewOnly || Data.notOlderThan(telemetry,"mapClick",key,"mode")))) return null;
    if (value.mode===4 && !allowedAscii(value.ascii)) return null;
    let point=null;
    const radarState=Data.state(telemetry,"radar","radar_single_robot_info");
    if (value.type===1 && Geometry.valid(value.map_x,value.map_y,28,15)) point={x:value.map_x,y:value.map_y};
    else if (value.type===2 && radarState!=="missing")
        point=Geometry.radarMarkers(telemetry?.radar?.radar_single_robot_info??[],clientID,28,15)
            .find(p=>p.robotId===value.enemy_id)??null;
    if (!point) return null;
    return {x:point.x,y:point.y,mode:value.mode,ascii:value.ascii??0,
        stale:keys.some(key=>Data.state(telemetry,"mapClick",key)!=="fresh") || value.type===2 && radarState!=="fresh"};
}
