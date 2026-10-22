import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "OperatorAirSupportData.js" as Support
import "OperatorRosterData.js" as Roster
import "OperatorShortcutRegistry.js" as Shortcuts

// 手册第16页：H展开双卡，呼叫后收为单卡；快捷键直接提交各自明确动作。
FocusScope {
    id:root
    objectName:"airSupportPanel"
    property var telemetry:null
    property int clientID:0
    property bool previewOnly:false
    property bool connectedToPlayer:false
    property bool secondsVerified:false
    property bool actionsAvailable:false
    property string hostReason:""
    property bool commandInputAvailable:false
    property int contextRevision:0
    property int selectedCommand:-1
    property string selectionContext:""
    property string feedback:""
    property var projectionItems:[]
    property double drawingNow:Date.now()
    property bool sawActive:false
    property bool showEnded:false
    readonly property var display:Support.view(telemetry,clientID,connectedToPlayer,secondsVerified,previewOnly)
    readonly property var projection:Roster.item(projectionItems,clientID,drawingNow,previewOnly)
    readonly property var callRemaining:projection?.air_call_remaining_seconds_state==="fresh" ? projection.air_call_remaining_seconds : null
    readonly property var paidCall:projection?.air_paid_call_state==="fresh" ? projection.air_paid_call : null
    readonly property bool windowActive:Window.window?.active===true
    readonly property bool editing:Window.window?.activeFocusItem?.readOnly===false
    readonly property bool inputReady:visible && windowActive && !editing && commandInputAvailable
    readonly property string currentContext:clientID+":"+contextRevision+":"+connectedToPlayer+":"+display.fields.airsupport_status.value
    readonly property bool selectedAllowed:allowed(selectedCommand) && selectionContext===currentContext
    readonly property string blockedReason:display.reason || (!actionsAvailable ? hostReason : "")
    readonly property bool counterVisible:display.active && display.fields.shooter_status.state==="fresh" && display.fields.shooter_status.value!==1
    readonly property real optionWidth:(width-24)/2
    readonly property var shortcutPreferences:Window.window?.ui?.shortcutPreferencesObject ?? null
    signal supportIntent(int commandID)
    signal closeRequested
    width:display.active || showEnded ? 266 : 480
    height:counterVisible ? 204 : 156
    onProjectionItemsChanged:drawingNow=Date.now()
    onVisibleChanged:{clearSelection();if(visible && !display.active)showEnded=false;}
    onClientIDChanged:{sawActive=false;showEnded=false;feedback="";clearSelection();}
    onConnectedToPlayerChanged:if(!connectedToPlayer){sawActive=false;showEnded=false;clearSelection();}
    onDisplayChanged:{
        if(display.active){sawActive=true;showEnded=false;}
        else if(sawActive && display.idle){sawActive=false;showEnded=true;}
        if(selectedCommand>=0 && !allowed(selectedCommand))clearSelection();
    }
    onCurrentContextChanged:clearSelection()
    onInputReadyChanged:if(!inputReady)clearSelection()
    Timer {interval:250;repeat:true;running:root.visible;onTriggered:root.drawingNow=Date.now()}
    function keyLabel(id){return shortcutPreferences ? shortcutPreferences.sequence(id) : Shortcuts.sequence(id,{});}
    function clearSelection(){selectedCommand=-1;selectionContext="";}
    function allowed(command){return Number.isInteger(command) && command>=0 && command<=3 && actionsAvailable && display.allowed[command]===true;}
    function select(command){if(!inputReady || !allowed(command))return;selectionContext=currentContext;selectedCommand=command;feedback="";}
    function confirm(){
        if(!inputReady || !selectedAllowed)return;
        const command=selectedCommand;clearSelection();feedback="";supportIntent(command);
    }
    function request(command){select(command);confirm();}
    OperatorActionShortcut {scopeItem:root;actionId:"airFree";available:root.inputReady && root.allowed(1);onActivated:root.request(1)}
    OperatorActionShortcut {scopeItem:root;actionId:"airPaid";available:root.inputReady && root.allowed(2);onActivated:root.request(2)}
    OperatorActionShortcut {scopeItem:root;actionId:"airCancel";available:root.inputReady && root.allowed(0);onActivated:root.request(0)}
    OperatorActionShortcut {scopeItem:root;actionId:"airCounter";available:root.inputReady && root.allowed(3);onActivated:root.request(3)}
    Row {
        visible:!root.display.active && !root.showEnded
        width:parent.width;spacing:24
        Repeater {
            model:[1,2]
            Item {
                required property int modelData
                width:root.optionWidth;height:156
                Button {
                    id:option
                    objectName:parent.modelData===1 ? "airSupportFreeOption" : "airSupportPaidOption"
                    width:parent.width;height:116;padding:0
                    enabled:root.inputReady && root.allowed(parent.modelData)
                    Accessible.name:parent.modelData===1 ? "免费呼叫空中支援" : "付费呼叫空中支援，优先使用免费时间"
                    background:Rectangle {color:option.hovered && option.enabled ? Theme.hudHover : Theme.hudSurface;radius:5;border.color:option.activeFocus ? Theme.green : "#809baca2";border.width:1}
                    contentItem:Item {
                        OperatorText {x:8;y:14;width:parent.width-16;height:39;text:option.parent.modelData===1 ? "免费时间耗尽后\n自动结束" : "消耗金币\n（优先免费时间）";size:13;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:option.enabled ? Theme.text : Theme.muted}
                        OperatorText {x:8;y:61;width:parent.width-16;height:23;text:root.keyLabel(option.parent.modelData===1 ? "airFree" : "airPaid");size:12;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:option.enabled ? Theme.green : Theme.muted}
                        OperatorText {x:8;y:86;width:parent.width-16;height:22;text:option.parent.modelData===1 ? root.display.freeText : "";size:12;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:Theme.muted}
                    }
                    onClicked:root.request(parent.modelData)
                }
                Button {
                    y:114;width:parent.width;height:42
                    background:Rectangle {color:parent.hovered ? Theme.hudHover : Theme.hudSurface;radius:4;border.width:1;border.color:"#6078886e"}
                    contentItem:OperatorText {text:"按 H 关闭面板";size:13;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:"#b1dbda"}
                    onClicked:root.closeRequested()
                }
            }
        }
    }
    Item {
        visible:root.display.active || root.showEnded
        width:parent.width;height:156
        Rectangle {width:parent.width;height:116;color:Theme.hudSurface;radius:5;border.width:1;border.color:"#809baca2"}
        OperatorText {x:8;y:18;width:parent.width-16;height:35;text:root.showEnded ? "已结束空中支援" : "空中支援中";size:23;minimumSize:0;font.bold:true;horizontalAlignment:Text.AlignHCenter}
        OperatorText {x:8;y:57;width:parent.width-16;height:23;visible:root.display.active
            text:root.paidCall===true && root.display.fields.left_time.state==="fresh" && root.display.fields.left_time.value===0 ? "本次已消耗 "+root.display.fields.cost_coins.value+" 金币兑换时间" : "本次呼叫剩余 "+(root.callRemaining===null ? "—" : root.callRemaining.toFixed(1)+" 秒")
            size:13;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:root.paidCall===true && root.display.fields.left_time.value===0 ? Theme.warning : Theme.text}
        OperatorText {x:8;y:81;width:parent.width-16;height:23;visible:root.display.active;text:root.paidCall===true && root.display.fields.left_time.state==="fresh" && root.display.fields.left_time.value===0 ? "（1金币每秒）" : root.display.freeText;size:12;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:Theme.text}
        Button {
            objectName:"airSupportEndOption"
            y:114;width:parent.width;height:42;enabled:root.inputReady && root.allowed(0)
            background:Rectangle {color:parent.hovered ? Theme.hudHover : Theme.hudSurface;radius:4;border.width:1;border.color:"#6078886e"}
            contentItem:OperatorText {text:"按 "+root.keyLabel("airCancel")+" 结束空中支援";size:13;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:parent.enabled ? "#b1dbda" : Theme.muted}
            onClicked:root.request(0)
        }
    }
    Button {
        objectName:"airSupportUnlock"
        x:0;y:164;width:parent.width;height:40;visible:root.counterVisible
        enabled:root.inputReady && root.allowed(3)
        background:Rectangle {color:Theme.hudSurface;radius:4;border.width:1;border.color:Theme.warning}
        contentItem:OperatorText {text:root.display.fields.shooter_status.value===2 ? root.keyLabel("airCounter")+" 付费解除反制" : "雷达反制中，暂不可解除";size:13;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:Theme.warning}
        onClicked:root.request(3)
    }
    Keys.onEscapePressed:event=>{root.closeRequested();event.accepted=true;}
    HoverHandler {id:hover}
    ToolTip.visible:hover.hovered && (root.feedback.length>0 || root.blockedReason.length>0)
    ToolTip.delay:700
    ToolTip.text:root.feedback || root.blockedReason
}
