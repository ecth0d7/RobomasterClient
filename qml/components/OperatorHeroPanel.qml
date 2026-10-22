import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "OperatorData.js" as Data
import "OperatorRosterData.js" as Roster
import "OperatorShortcutRegistry.js" as Shortcuts

// 手册第17页：部署键在H入口上方，部署操作不占用或替换远程兑换槽。
Item {
    id: root
    objectName: "heroDeployHud"
    property var telemetry: null
    property int clientID: 0
    property bool previewOnly: false
    property bool actionsAvailable: false
    property string hostReason: ""
    property string feedback: ""
    property string videoStatus: ""
    property var projectionItems: []
    property double drawingNow: Date.now()
    property bool holding: false
    property bool holdEnter: true
    property string holdSource: ""
    property real holdProgress: 0
    property int holdDuration: 1200
    property double holdStartedAt: 0
    property int lastStatus: -1
    property double exitObservedAt: 0
    readonly property var shortcutPreferences: Window.window?.ui?.shortcutPreferencesObject ?? null
    readonly property string deployState: Data.state(telemetry,"deployMode","status")
    readonly property var status: telemetry?.deployMode?.status
    readonly property bool hero: clientID % 100 === 1
    readonly property bool freshMode: deployState==="fresh" && [0,1].includes(status)
    readonly property bool robotConnected: Data.state(telemetry,"robotStatic","connection_state")==="fresh" && telemetry.robotStatic.connection_state===1
    readonly property bool onField: Data.state(telemetry,"robotStatic","field_state")==="fresh" && telemetry.robotStatic.field_state===0
    readonly property bool alive: Data.state(telemetry,"robotStatic","alive_state")==="fresh" && telemetry.robotStatic.alive_state===1
    readonly property var projection: Roster.item(projectionItems,clientID,drawingNow,previewOnly)
    readonly property var cooldownSeconds: {
        if(projection?.deploy_cooldown_remaining_seconds_state==="fresh" && projection.produced_at_ms>=exitObservedAt)
            return Math.max(0,Math.ceil(projection.deploy_cooldown_remaining_seconds-projection.age_ms/1000));
        // 手册规定退出后8秒；只在实际新鲜1→0同步后计时，提交命令不会启动此钟。
        return exitObservedAt>0 ? Math.max(0,Math.ceil((exitObservedAt+8000-drawingNow)/1000)) : null;
    }
    readonly property bool cooling: typeof cooldownSeconds==="number" && cooldownSeconds>0
    readonly property bool canEnter: hero && actionsAvailable && freshMode && status===0 && alive && robotConnected && onField && !cooling
    readonly property bool canExit: hero && actionsAvailable && freshMode && status===1 && robotConnected
    readonly property bool heldActionAllowed: holdEnter ? canEnter : canExit
    readonly property string blockedReason: !hero ? "本机非英雄" : !actionsAvailable ? hostReason : !freshMode ? "部署状态未新鲜接收"
        : !robotConnected ? "机器人离线，无法进入部署模式" : status===0 && !alive ? "机器人已战亡，无法进入部署模式"
        : status===0 && !onField ? "机器人未上场，无法进入部署模式" : ""
    signal deployIntent(bool enter)
    signal closeRequested
    width:266
    height:84
    function shortcutLabel(id) { return shortcutPreferences ? shortcutPreferences.sequence(id) : Shortcuts.sequence(id,{}); }
    onProjectionItemsChanged: drawingNow=Date.now()
    onVisibleChanged: { drawingNow=Date.now();if(!visible)cancelHold(); }
    onClientIDChanged: { cancelHold();feedback="";lastStatus=-1;exitObservedAt=0; }
    onActionsAvailableChanged: {
        if(!actionsAvailable) { lastStatus=-1;exitObservedAt=0;cancelHold(); }
        else if(freshMode)lastStatus=status;
    }
    onStatusChanged: {
        if(freshMode && actionsAvailable && lastStatus===1 && status===0) { exitObservedAt=Date.now();drawingNow=exitObservedAt; }
        if(status===1)exitObservedAt=0;
        lastStatus=[0,1].includes(status) ? status : -1;
    }
    onHeldActionAllowedChanged: if(!heldActionAllowed)cancelHold()
    Timer { interval:250;repeat:true;running:root.visible;onTriggered:root.drawingNow=Date.now() }
    function beginHold(enter,source) {
        if(!visible || holding || !(enter ? canEnter : canExit))return;
        holdEnter=enter;holdSource=source;holdProgress=0;feedback="";holdStartedAt=Date.now();holding=true;
    }
    function endHold(source) {
        if(!holding || holdSource!==source)return;
        if(Date.now()-holdStartedAt>=holdDuration)finishHold();else cancelHold();
    }
    function cancelHold() { holding=false;holdProgress=0;holdSource="";holdStartedAt=0; }
    function finishHold() {
        const enter=holdEnter;
        const allowed=holding && visible && heldActionAllowed && Window.window?.active===true;
        cancelHold();
        if(allowed)deployIntent(enter);
    }
    // 长按按实际持续时间判断，录屏或低帧率不能把1.2秒变成动画帧数门槛。
    Timer {
        interval:25;repeat:true;running:root.holding
        onTriggered: {
            root.holdProgress=Math.min(1,Math.max(0,(Date.now()-root.holdStartedAt)/root.holdDuration));
            if(root.holdProgress>=1)root.finishHold();
        }
    }
    Connections { target:root.Window.window;function onActiveChanged(){if(!root.Window.window?.active)root.cancelHold();} }
    Button {
        id:keycap
        objectName:"heroDeployKey"
        x:(parent.width-width)/2;width:46;height:46
        enabled:root.canEnter || root.canExit
        Accessible.name:root.status===1 ? "长按L退出部署模式" : "长按K进入部署模式"
        background:Image {source:"../resources/player/rune_tab/key_"+(keycap.enabled ? "able" : "unable")+".png";fillMode:Image.PreserveAspectFit;mipmap:true}
        contentItem:Item {
            OperatorText { y:0;width:parent.width;height:23;text:root.shortcutLabel(root.status===1 ? "heroExit" : "heroEnter");size:16;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:keycap.enabled ? Theme.text : Theme.muted }
            OperatorText { y:24;width:parent.width;height:12;text:root.holding ? "等待中" : root.status===1 ? "长按退出" : root.canEnter ? "长按部署" : "无法部署";size:8;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:keycap.enabled ? "#c8e6de" : Theme.muted }
        }
        onPressedChanged: { if(pressed)root.beginHold(root.status===0,"button");else root.endHold("button"); }
        onCanceled:root.endHold("button")
    }
    Rectangle {
        x:48;y:54;width:parent.width-96;height:6;radius:2;color:"#a223302a";visible:root.holding
        Rectangle { width:parent.width*root.holdProgress;height:parent.height;radius:2;color:"#a6f9b5" }
    }
    OperatorText {
        x:-40;y:62;width:parent.width+80;height:20
        text:root.cooling ? "冷却倒计时："+root.cooldownSeconds+"s" : root.blockedReason
        visible:text.length>0
        size:12;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:root.cooling ? Theme.text : Theme.red
    }
    HoverHandler {id:hover}
    ToolTip.visible:hover.hovered && (root.feedback.length>0 || (root.status===1 && root.videoStatus.length>0))
    ToolTip.delay:700
    ToolTip.text:[root.feedback,root.status===1 && root.videoStatus.length>0?"吊射图传："+root.videoStatus:""].filter(s=>s.length>0).join("\n")
}
