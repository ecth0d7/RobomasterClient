import QtQuick

// 单独的离线输入样例，不创建InputController，不grab／warp，不向机器人发包。
QtObject {
    id: root
    property string mode: "idle"
    property int frame: 0
    property double sampleAt: Date.now()
    readonly property bool moving: ["captured","motion","all","emulated","partial"].includes(mode)
    readonly property bool enabled: !["blocked","failed"].includes(mode)
    readonly property bool mouseCaptureEnabled: ["captured","motion","all","emulated","partial","expires","stale","legacy"].includes(mode)
    readonly property int keyMask: mode === "all" ? 65535 : mode === "partial" ? -1
        : !mouseCaptureEnabled ? 0 : mode === "motion" ? [1,2,4,8,17,34,24,36,0,0][frame%10] : 49
    readonly property string keyText: "0x" + Math.max(0,keyMask).toString(16).padStart(4,"0")
    readonly property bool leftButtonDown: mouseCaptureEnabled && (mode !== "motion" || frame%4 === 0)
    readonly property bool rightButtonDown: mouseCaptureEnabled && (mode === "all" || mode === "motion" && frame%4 === 1)
    readonly property bool middleButtonDown: mouseCaptureEnabled && (mode === "all" || mode === "motion" && frame%4 === 2)
    onModeChanged: { frame=0;sampleAt=Date.now(); }
    readonly property var monitorSnapshot: {
        if (mode === "legacy") return null;
        const vectors=[[-12,-8],[0,-12],[12,-8],[12,0],[12,8],[0,12],[-12,8],[-12,0],[0,0],[0,0]];
        const delta=mode === "motion" ? vectors[frame%10] : [-12,-8];
        const captured=mouseCaptureEnabled;
        const eventAt=mode === "stale" ? sampleAt-3000 : sampleAt;
        return {version:1,source_kind:"mock",source_id:"mock-local-key-mouse",validation:"mock",sampled_at_ms:sampleAt,
            sequence:frame,enabled:enabled,capture_available:mode !== "emulated",
            capture_state:mode === "emulated" ? "emulated" : mode === "failed" ? "failed" : mode === "blocked" ? "blocked" : captured ? "captured" : "released",
            capture_reason:"仅离线绘制，未创建平台grab或发送控制。"+(mode === "stale" ? "运动样例时间已过期。" : ""),
            keyboard_value:keyMask<0?undefined:keyMask,left_button_down:leftButtonDown,right_button_down:rightButtonDown,
            mid_button_down:middleButtonDown,last_trigger:captured?mode === "motion"?frame%2?"W":"鼠标左键":"Ctrl":"",
            trigger_at_ms:captured?eventAt:0,axis_basis:"qt_screen_delta",screen_dx:delta[0],screen_dy:delta[1],
            motion_at_ms:captured?eventAt:0,wheel_delta:mode === "motion"&&frame%6===0?frame%12===0?120:-120:0,
            wheel_at_ms:mode === "motion"&&frame%6===0?eventAt:0};
    }
    function requestMouseCapture(capture) { mode=capture?"captured":"idle";return true; }
    property Timer ticker: Timer {
        interval:250;repeat:true;running:root.moving
        onTriggered: { root.frame+=1;root.sampleAt=Date.now(); }
    }
}
