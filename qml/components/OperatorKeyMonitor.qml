import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "OperatorInputMonitorData.js" as InputData

OperatorKeyMonitorForm {
    id: root
    property var inputState: null
    property bool previewOnly: false
    property bool interactionAllowed: false
    property string captureFeedback: ""
    signal captureRequested(bool captured)
    readonly property var snapshot: InputData.snapshot(inputState,previewOnly)
    readonly property bool displayable: snapshot !== null
    hudScale: Window.window?.ui?.layoutScale ?? 1
    measuredKeyHeight: keyMetrics.height
    measuredLabelHeight: labelMetrics.height
    measuredLabelWidth: labelWidthMetrics.advanceWidth
    readonly property real allKeysWidth: {
        // advanceWidth()不是可观察属性；显式依赖font，缩放或字体加载后重新度量。
        const measuredFont=keyMetrics.font;
        return measuredFont.pixelSize>0
            ? InputData.keys.reduce((total,key)=>total+Math.ceil(keyMetrics.advanceWidth(key)),0)
                +(InputData.keys.length-1)*keyGap : 0;
    }
    readonly property var controlKeys: inputActive && keyboardMask >= 0
        ? InputData.orderedKeys(snapshot) : []
    readonly property bool inputActive: InputData.active(snapshot)
    readonly property int keyboardMask: InputData.mask(snapshot?.keyboard_value)
    readonly property bool controlActive: inputActive && keyboardMask > 0
    readonly property bool buttonsKnown: InputData.buttonsKnown(snapshot)
    readonly property bool captured: snapshot?.capture_state === "captured" || snapshot?.capture_state === "emulated"
    readonly property bool captureDesired: typeof snapshot?.capture_desired === "boolean" ? snapshot.capture_desired : captured
    readonly property bool actionAvailable: snapshot?.capture_available === true
        && snapshot?.enabled === true && ["released","captured","failed","paused"].includes(snapshot?.capture_state)
        && typeof inputState?.requestMouseCapture === "function" && interactionAllowed
    readonly property var movement: InputData.movement(snapshot,drawingNow)
    readonly property string triggerText: InputData.trigger(snapshot,drawingNow)
    readonly property string controlText: inputActive ? controlKeys.join(" ") : ""
    readonly property bool wheelFresh: inputActive && Number.isSafeInteger(snapshot?.wheel_delta)
        && InputData.recent(snapshot?.wheel_at_ms,drawingNow,700)
    readonly property bool inputSubmissionBlocked: inputActive && snapshot?.submission_state === "rejected"
    readonly property string statusText: (previewOnly ? "mock · " : "本机 · ") + InputData.status(snapshot)
        + (inputSubmissionBlocked ? " · MQTT 输入提交受阻" : "")
    readonly property string explanation: statusText + "。" + (snapshot?.capture_reason ?? "尚未取得本机输入状态")
        + "。触发为最近本机控制输入事件；控制为当前本机按下状态，不是机器人执行回执。"
        + " 两幅鼠标图形均显示本机当前按钮与短时移动。"
        + (snapshot?.axis_basis === "qt_screen_delta" ? " 屏幕移动右／下为正，箭头350ms后消失。"
            : " 此输入源没有明确坐标基准与动作时间，不显示方向箭头。")
        + (movement.fresh ? " Δx " + snapshot.screen_dx + "，Δy " + snapshot.screen_dy : "")
        + (wheelFresh ? "，滚轮原始增量 " + snapshot.wheel_delta : "")
        + " 当前按键 " + (inputActive?controlText:"无活动控制输入")
        + (InputData.completeKeyOrder(snapshot) ? "，按实际按下先后排列"
            : InputData.keyOrder(snapshot) !== null ? "，顺序不完整或与掩码不一致，其余按键按固定键位补齐"
            : "，此输入源未公开可用按下顺序")
        + " 来源 " + (snapshot?.source_id ?? "未提供")
        + (inputSubmissionBlocked ? "。最近一次本地发送未接受；重试当前按键和按钮，丢弃该次鼠标位移，不补发旧移动。" : "")
        + (captureFeedback ? "。" + captureFeedback : "")
    property double drawingNow: Date.now()
    onSnapshotChanged: drawingNow=Date.now()
    onVisibleChanged: if(visible)drawingNow=Date.now()
    // 预留全部16键的真实字体宽度；状态更新不推挤相邻小地图。
    measuredKeysWidth: allKeysWidth
    sourceDisplayable: displayable
    heldKeysActive: controlActive
    captureEnabled: actionAvailable
    captureIntended: captureDesired
    triggerValue: triggerText
    controlValue: controlText
    keyLabels: controlKeys
    footerText: captureFeedback || statusText
    footerWarning: previewOnly || inputSubmissionBlocked
        || ["emulated","failed","unavailable"].includes(snapshot?.capture_state)
    explanationText: explanation
    triggerFontFamily: /[\u3400-\u9fff]/.test(triggerText) ? fontFamily : keyFontFamily
    triggerStyleName: /[\u3400-\u9fff]/.test(triggerText) ? "" : keyStyleName
    mouseKnown: buttonsKnown
    mouseLeftDown: inputActive && snapshot?.left_button_down === true
    mouseRightDown: inputActive && snapshot?.right_button_down === true
    mouseMiddleDown: inputActive && snapshot?.mid_button_down === true
    mouseMotionX: movement.x
    mouseMotionY: movement.y
    mouseWheelDirection: wheelFresh ? Math.sign(snapshot.wheel_delta) : 0
    FontMetrics { id:keyMetrics; font.family:root.keyFontFamily; font.styleName:root.keyStyleName; font.pixelSize:root.keySize }
    FontMetrics { id:labelMetrics; font.family:root.fontFamily; font.pixelSize:root.labelSize }
    TextMetrics { id:labelWidthMetrics; font:labelMetrics.font; text:"触发" }
    Accessible.role: Accessible.StaticText
    Accessible.name: explanation
    Timer {
        interval:50;repeat:true
        running:root.visible && InputData.needsClock(root.snapshot,root.drawingNow)
        onTriggered:root.drawingNow=Date.now()
    }
    Connections {
        target: root.captureControl
        function onClicked() { root.captureRequested(!root.captureDesired); }
    }
    HoverHandler { id:hover;onHoveredChanged:if(hovered)root.drawingNow=Date.now() }
    ToolTip.visible:hover.hovered
    ToolTip.delay:450
    ToolTip.text:root.explanation
}
