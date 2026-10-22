.pragma library

function valid(x,y,w,h) {
    return typeof x === "number" && typeof y === "number"
        && Number.isFinite(x) && Number.isFinite(y) && x >= 0 && y >= 0 && x <= w && y <= h;
}
function radarMarkers(robots, clientID, fieldW, fieldH) {
    const result = [], types = [1,2,3,4,6,7], ownBlue = clientID > 100;
    for (let i = 0; i < Math.min(robots.length,12); ++i) {
        const robot = robots[i];
        if (!robot || ![robot.target_pos_x,robot.target_pos_y].every(n=>Number.isSafeInteger(n) && n>=0 && n<=4294967295)
            || robot.target_pos_x===0 && robot.target_pos_y===0) continue;
        const blue = i < 6 ? !ownBlue : ownBlue;
        result.push({robotId:types[i % 6] + (blue ? 100 : 0), x:Math.min(fieldW,robot.target_pos_x / 100),
            y:Math.min(fieldH,robot.target_pos_y / 100),rawX:robot.target_pos_x,rawY:robot.target_pos_y,highlight:robot.is_high_light ?? 0});
    }
    return result;
}
function boundedPoint(x,y,w,h) {
    return typeof x==="number" && typeof y==="number" && Number.isFinite(x) && Number.isFinite(y)
        ? {x:Math.max(0,Math.min(w,x)),y:Math.max(0,Math.min(h,y))}:null;
}
function pathPoints(startX,startY,offsetX,offsetY) {
    if (startX === null || startY === null || startX === undefined || startY === undefined) return [];
    let x = startX / 10, y = startY / 10;
    const points = [{x:x,y:y}];
    // 协议第 1.3.1 节（0x0307）定义偏移量相对前一轨迹点逐项累加。
    // 第 2.2.16 节简称起点偏移，实际解读以前者完整定义为准。
    for (let i = 0; i < Math.min(offsetX.length,offsetY.length,49); ++i) {
        x += offsetX[i] / 10; y += offsetY[i] / 10;
        points.push({x:x,y:y});
    }
    return points;
}
