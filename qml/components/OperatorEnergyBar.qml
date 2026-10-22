import QtQuick
import QtQuick.Controls

OperatorEnergyBarForm {
    id:root
    drawingBackgroundVisible: false
    property var display:({ratio:0,ratioState:"none",hasCurrent:false,identity:"",description:""})
    property real displayedFraction:0
    property bool drawingReady:false
    property bool previousLive:false
    property string previousIdentity:""
    property real previousTarget:0
    backgroundOpacity:root.display.ratioState === "live" ? 0.7 : root.display.hasCurrent ? 0.4 : 0.22
    fillFraction:root.displayedFraction
    fillVisible:root.display.ratioState !== "none" && root.display.ratio > 0
    fillOpacity:root.display.ratioState === "live" ? 0.8 : 0.25
    function refresh() {
        const live=display.ratioState === "live",target=display.ratioState === "none" ? 0 : display.ratio;
        // 只在同一主体连续合格且新目标非零时补间；目标零、失效、旧态及换主体立即切换。
        if (live && previousLive && previousIdentity === display.identity && target > 0) {
            if (target !== previousTarget) {
                filling.stop();filling.from=displayedFraction;filling.to=target;filling.start();
            }
        } else {filling.stop();displayedFraction=target;}
        previousLive=live;previousIdentity=display.identity;previousTarget=target;
    }
    onDisplayChanged:{
        if (!drawingReady) return;
        if (display.ratioState !== "live" || display.ratio === 0) refresh();
        else {
            if (previousIdentity !== display.identity) {previousLive=false;filling.stop();}
            // 合并同一GUI回合内的同步绑定通知，不把未绘制过的中间值当作上一帧。
            // 这不提供网络同帧性；零/失效仍在上面的分支立即清空。
            Qt.callLater(root.refresh);
        }
    }
    Component.onCompleted:{drawingReady=true;refresh();}
    NumberAnimation {id:filling;target:root;property:"displayedFraction";duration:Theme.reducedMotion?0:240;easing.type:Easing.OutCubic}
    Accessible.role:Accessible.StaticText
    Accessible.name:display.description
    HoverHandler {id:hover}
    ToolTip.visible:hover.hovered
    ToolTip.delay:450
    ToolTip.text:display.description
}
