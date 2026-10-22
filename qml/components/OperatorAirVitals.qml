import QtQuick
import QtQuick.Controls
import "OperatorAirData.js" as Air

OperatorAirVitalsForm {
    id:root
    property var telemetry:null
    property int clientID:0
    property bool connectedToPlayer:false
    property bool previewOnly:false
    // 可选显示插件默认为关闭；协议没有的上限／反制值只接受有来源的v1投影。
    property var displayData:null
    property bool displayProjectionConnected:false
    property string displaySessionId:""
    property double drawingNow:Date.now()
    readonly property var display:Air.view(telemetry,clientID,connectedToPlayer,displayData,
        displaySessionId,displayProjectionConnected,drawingNow,previewOnly)
    readonly property bool displayable:display.displayable
    ammoVisible:display.ammo.hasValue
    ammoText:display.ammo.text
    ammoNumeric:display.ammo.numeric
    ammoColor:Theme[display.ammo.tone]
    ammoCaption:""
    ammoCaptionColor:display.ammo.tone === "warning" ? Theme.warning : Theme.muted
    ammoRatioVisible:display.ammo.ratioState !== "none"
    ammoFraction:ammoMotion.fraction
    ammoFillOpacity:display.ammo.ratioState === "live" ? 0.9 : 0.25
    progressVisible:display.progress.hasValue
    progressRatioVisible:display.progress.ratioState !== "none"
    progressFraction:counterMotion.fraction
    progressFillOpacity:display.progress.ratioState === "live" ? 0.85 : 0.25
    progressCaption:display.progress.caption
    progressColor:Theme[display.progress.tone]
    shooterVisible:display.shooter.state !== "missing" && display.shooter.value !== 1
    shooterText:display.shooterLabel
    shooterColor:Theme[display.shooterTone]
    countVisible:display.count.hasValue
    countCaption:display.count.caption
    countColor:Theme[display.count.tone]
    function refreshClock() {drawingNow=Math.max(drawingNow,Date.now());}
    onDisplayDataChanged:Qt.callLater(root.refreshClock)
    // visible取决于display；不能在其同步通知中回写display所读的时钟。
    onVisibleChanged:if(visible)Qt.callLater(root.refreshClock)
    Timer {interval:250;repeat:true;running:root.visible && root.displayData !== null;onTriggered:root.refreshClock()}
    Accessible.role:Accessible.StaticText
    Accessible.name:display.description
    HoverHandler {id:hover}
    ToolTip.visible:hover.hovered
    ToolTip.delay:450
    ToolTip.text:display.description
    OperatorFractionMotion {id:ammoMotion;display:root.display.ammo;duration:240}
    OperatorFractionMotion {id:counterMotion;display:root.display.progress;duration:180}
}
