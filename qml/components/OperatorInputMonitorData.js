.pragma library

const keys = ["W","S","A","D","Shift","Ctrl","Q","E","R","F","G","Z","X","C","V","B"];
function mask(value) {
    if (Number.isSafeInteger(value) && value >= 0 && value <= 65535) return value;
    if (typeof value === "string" && /^0x[0-9a-fA-F]{1,4}$/.test(value)) return parseInt(value.slice(2),16);
    return -1;
}
function keyNames(value) {
    const bits=mask(value);
    return bits < 0 ? "—" : keys.filter((key,index)=>(bits & (1 << index)) !== 0).join(" ");
}
function keyOrder(data) {
    const supplied=data?.keyboard_order;
    // QStringList进入QML时可以是Qt序列；不要求它具备原生JS Array身份。
    if (!supplied || typeof supplied !== "object" || !Number.isInteger(supplied.length)
        || supplied.length < 0 || supplied.length > keys.length) return null;
    const order=Array.from(supplied);
    return order.every(key=>typeof key === "string" && keys.includes(key)) ? order : null;
}
function completeKeyOrder(data) {
    const bits=mask(data?.keyboard_value);
    const order=keyOrder(data);
    if (bits < 0 || order === null) return false;
    const held=keys.filter((key,index)=>(bits & (1<<index)) !== 0);
    return order.length === held.length && held.every(key=>order.includes(key));
}
function orderedKeys(data) {
    const bits=mask(data?.keyboard_value);
    if(bits<0)return [];
    const held=keys.filter((key,index)=>(bits & (1<<index))!==0);
    const supplied=keyOrder(data);
    if(supplied === null)return held;
    const order=[];
    for(const key of supplied)if(held.includes(key) && !order.includes(key))order.push(key);
    // 部分顺序仍可显示，但补齐的固定键位不应被说明成完整物理顺序。
    for(const key of held)if(!order.includes(key))order.push(key);
    return order;
}
function snapshot(endpoint, previewOnly) {
    if (!endpoint) return null;
    const data=endpoint.monitorSnapshot;
    if (data && data.version === 1
        && (data.source_kind === "local_input" && data.validation === "observed_local"
            || previewOnly && data.source_kind === "mock" && data.validation === "mock")
        && typeof data.source_id === "string" && data.source_id.length > 0 && data.source_id.length <= 128
        && (mask(data.keyboard_value) >= 0 || buttonsKnown(data)) && typeof data.capture_state === "string") return data;
    if (data !== null && data !== undefined) return null; // 不把拒绝的mock／未知版本洗成旧插件实时输入。
    // 旧插件继续显示已知按键；没有事件时间时不猜箭头或真实grab成功。
    const bits=mask(endpoint.keyText);
    if (bits < 0 || typeof endpoint.mouseCaptureEnabled !== "boolean") return null;
    return {version:0,source_kind:"legacy_input",source_id:"selected-input-endpoint",keyboard_value:bits,
        capture_state:endpoint.mouseCaptureEnabled ? "emulated" : "released",capture_available:false,
        capture_reason:"旧插件没有可核验捕获状态／事件时钟；不能声明平台grab成功",
        enabled:endpoint.enabled === true,left_button_down:endpoint.leftButtonDown,
        right_button_down:endpoint.rightButtonDown,mid_button_down:endpoint.middleButtonDown};
}
function recent(stamp,now,lifetime) {
    return typeof stamp === "number" && Number.isFinite(stamp) && stamp > 0
        && stamp <= now && now-stamp <= lifetime;
}
function movement(data,now) {
    if (!data || !["captured","emulated"].includes(data.capture_state) || !data.enabled
        || data.axis_basis !== "qt_screen_delta" || !recent(data.motion_at_ms,now,350)
        || !Number.isSafeInteger(data.screen_dx) || !Number.isSafeInteger(data.screen_dy)
        || data.screen_dx < -32768 || data.screen_dx > 32767
        || data.screen_dy < -32768 || data.screen_dy > 32767) return {x:0,y:0,fresh:false};
    return {x:Math.sign(data.screen_dx),y:Math.sign(data.screen_dy),fresh:true};
}
function trigger(data,now) {
    if (!data || typeof data.last_trigger !== "string" || data.last_trigger.length > 64) return "—";
    return recent(data.trigger_at_ms,now,650) ? data.last_trigger : "";
}
function buttonsKnown(data) {
    return !!data && typeof data.left_button_down === "boolean" && typeof data.right_button_down === "boolean"
        && typeof data.mid_button_down === "boolean";
}
function active(data) { return data?.enabled === true && ["captured","emulated"].includes(data?.capture_state); }
function needsClock(data,now) {
    return !!data && (recent(data.motion_at_ms,now,350) || recent(data.trigger_at_ms,now,650)
        || recent(data.wheel_at_ms,now,700));
}
function status(data) {
    if (!data) return "输入源未提供";
    const names={captured:"已捕获",paused:"捕获暂挂 · 自动恢复",emulated:"回中 · 未核验",released:"已释放",requesting:"捕获请求中",
        failed:"捕获失败",blocked:"控制受阻",unavailable:"捕获不可用"};
    return names[data.capture_state] ?? "捕获状态待核验";
}
