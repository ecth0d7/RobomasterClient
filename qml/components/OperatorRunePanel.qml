import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "OperatorData.js" as Data
import "OperatorShortcutRegistry.js" as Shortcuts
import "OperatorRuneData.js" as Rune

// 手册第12页：顶部F键条，激活期间才展开原生环数底板。
Item {
    id: root
    objectName: "runeHud"
    property var telemetry: null
    property int clientID: 0
    property bool previewOnly: false
    property bool actionsAvailable: false
    property string hostReason: ""
    property bool activationAllowed: false
    property bool largeRuneConfirmed: false
    property string feedback: ""
    property bool holding: false
    property string holdSource: ""
    property real holdProgress: 0
    property real referenceHoldProgress: 0
    property int holdDuration: 1200
    property double holdStartedAt: 0
    property real availableHeight: 300
    property var projectionItems:[]
    property double displayNow:Date.now()
    readonly property var localDisplay:Rune.view(projectionItems,clientID,displayNow,previewOnly)
    readonly property bool modelMatches:Rune.matches(localDisplay,rune)
    readonly property var shortcutPreferences: Window.window?.ui?.shortcutPreferencesObject ?? null
    readonly property string runeState: Data.state(telemetry,"runeStatus","rune_status")
    readonly property string armsState: Data.state(telemetry,"runeStatus","activated_arms")
    readonly property var rune: telemetry?.runeStatus ?? ({})
    readonly property bool infantry: [3,4,5].includes(clientID%100)
    readonly property bool armsKnown: armsState==="fresh" && Number.isInteger(rune.activated_arms) && rune.activated_arms>=0 && rune.activated_arms<=4294967295
    readonly property bool activeRune: runeState==="fresh" && rune.rune_status===2
    readonly property bool showDetails: activeRune && largeRuneConfirmed
    // 与提示条同宽；压缩行距而不再额外缩字，最小窗口仍可读。
    readonly property real contentScale:1
    readonly property real detailHeight:Math.min(336,Math.max(198,availableHeight-44))
    readonly property real detailHeaderHeight:detailHeight<270?62:100
    readonly property real groupHeight:(detailHeight-detailHeaderHeight-10)/5
    readonly property bool canActivate: infantry && actionsAvailable && activationAllowed && runeState==="fresh" && rune.rune_status===1
        && Data.state(telemetry,"robotStatic","alive_state")==="fresh" && telemetry?.robotStatic?.alive_state===1
        && (localDisplay===null || localDisplay.operations_allowed && localDisplay.remaining_openings>0)
    readonly property string blockedReason: !infantry ? "本机非步兵" : !actionsAvailable ? hostReason : runeState!=="fresh" ? "机关状态未新鲜接收"
        : !canActivate && !activeRune ? hostReason || "当前不可开启能量机关" : ""
    signal activationIntent
    signal closeRequested
    width:384
    height:44+(showDetails ? detailHeight : 0)
    onProjectionItemsChanged:displayNow=Date.now()
    Timer {interval:250;repeat:true;running:root.visible && root.projectionItems.length>0;onTriggered:root.displayNow=Date.now()}
    onVisibleChanged: if(!visible)cancelHold()
    onClientIDChanged: {cancelHold();feedback="";}
    onCanActivateChanged: if(!canActivate)cancelHold()
    function beginHold(source) {
        if(!visible || holding || !canActivate)return;
        holdSource=source;holdProgress=0;feedback="";holdStartedAt=Date.now();holding=true;
    }
    function endHold(source) {
        if(!holding || holdSource!==source)return;
        if(Date.now()-holdStartedAt>=holdDuration)finishHold();else cancelHold();
    }
    function cancelHold() {holding=false;holdProgress=0;holdSource="";holdStartedAt=0;}
    function finishHold() {
        const allowed=holding && visible && canActivate && Window.window?.active===true;
        cancelHold();if(allowed)activationIntent();
    }
    Timer {interval:25;repeat:true;running:root.holding;onTriggered:{
        root.holdProgress=Math.min(1,Math.max(0,(Date.now()-root.holdStartedAt)/root.holdDuration));
        if(root.holdProgress>=1)root.finishHold();
    }}
    Connections {target:root.Window.window;function onActiveChanged(){if(!root.Window.window?.active)root.cancelHold();}}
    Item {
        width:root.width;height:root.height
        Rectangle {
            width:parent.width;height:44;color:Theme.hudSurface
            radius:3;border.width:Theme.hudStroke(root.Window.window?.ui?.layoutScale??1,false);border.color:Theme.hudBorder
        }
        Button {
            id:keycap
            x:12;y:5;width:34;height:34;enabled:root.canActivate
            padding:0
            Accessible.name:"长按F开启能量机关"
            background:Image {source:"../resources/player/rune_tab/key_"+(keycap.enabled ? "able" : "unable")+".png";fillMode:Image.PreserveAspectFit;mipmap:true}
            contentItem:OperatorText {text:root.shortcutPreferences ? root.shortcutPreferences.sequence("runeHold") : Shortcuts.sequence("runeHold",{});size:19;horizontalAlignment:Text.AlignHCenter;color:keycap.enabled ? Theme.text : Theme.muted}
            onPressedChanged:{if(pressed)root.beginHold("button");else root.endHold("button");}
            onCanceled:root.endHold("button")
            Rectangle {anchors.bottom:parent.bottom;width:parent.width*root.holdProgress;height:3;color:Theme.green;visible:root.holding}
        }
        OperatorText {
            objectName:"runeActivationCaption"
            x:58;y:0;width:parent.width-70;height:44;size:14
            text:(root.holding ? "正在开启" : root.activeRune ? "已开启"+(root.modelMatches?"，"+root.localDisplay.remaining_seconds+"s后结束":"")
                : root.modelMatches && root.localDisplay.remaining_openings===0 && root.rune.rune_status===1 ? "次数不足，不可开启"
                : root.runeState==="fresh" && root.rune.rune_status===3 ? "已激活"
                : (root.canActivate ? "长按开启" : "无法开启")+(root.largeRuneConfirmed ? "大能量机关" : "能量机关")+(root.modelMatches?"("+root.localDisplay.remaining_openings+")":""))
                +(root.modelMatches && root.localDisplay.activations>0 ? " 已激活("+root.localDisplay.activations+")":"")
            color:root.activeRune || root.canActivate ? Theme.text : Theme.muted
        }
        Item {
            objectName:"runeHitDetails"
            y:44;width:parent.width;height:root.detailHeight;visible:root.showDetails
            BorderImage {anchors.fill:parent;source:"../resources/player/rune_tab/rune_tab_bg.png";border {left:12;right:12;top:12;bottom:12} opacity:.45}
            Image {x:8;y:8;width:root.detailHeaderHeight<80?44:60;height:width;source:"../resources/player/rune_tab/rune_tab_"+(root.clientID>100 ? "blue" : "red")+".png";fillMode:Image.PreserveAspectFit;mipmap:true}
            OperatorText {x:root.detailHeaderHeight<80?62:76;y:4;width:parent.width-x-12;height:28;text:"平均环数 / 总臂数  "+Data.text(root.telemetry,"runeStatus","average_rings",1)+" / "+(root.armsKnown ? root.rune.activated_arms : "—");size:16}
            OperatorText {x:root.detailHeaderHeight<80?62:76;y:root.detailHeaderHeight<80?32:46;width:parent.width-x-12;height:26;text:"不可命中环数  "+(root.modelMatches?root.localDisplay.disallowed_rings.join(" "):"—");size:14;color:root.modelMatches?Theme.text:Theme.muted}
            Repeater {
                model:5
                Item {
                    required property int index
                    readonly property var shots:root.modelMatches?root.localDisplay.groups[index].shots:null
                    x:16;y:root.detailHeaderHeight+index*root.groupHeight;width:parent.width-32;height:root.groupHeight
                    Image {x:0;y:(parent.height-height)/2;width:Math.min(28,parent.height-4);height:width;source:"../resources/player/rune_tab/rune_tab_"+(!root.modelMatches || index>root.localDisplay.current_group?"nothit":index===root.localDisplay.current_group?"hitting":"hit")+".png";fillMode:Image.PreserveAspectFit;mipmap:true;opacity:root.modelMatches?1:.5}
                    OperatorText {x:40;width:90;height:parent.height;text:"第"+(index+1)+"组";size:16}
                    OperatorText {x:152;width:78;height:parent.height;text:Rune.hitText(parent.shots?.[0],root.modelMatches,0);size:17;horizontalAlignment:Text.AlignHCenter;color:parent.shots?.[0]?.state==="invalid"?Theme.warning:root.modelMatches?Theme.text:Theme.muted}
                    Image {x:238;y:(parent.height-height)/2;width:1;height:14;source:"../resources/player/rune_tab/rune_tab_delimiter.png";fillMode:Image.Stretch}
                    OperatorText {x:247;width:parent.width-x;height:parent.height;text:Rune.hitText(parent.shots?.[1],root.modelMatches,1);size:17;horizontalAlignment:Text.AlignHCenter;color:parent.shots?.[1]?.state==="invalid"?Theme.warning:root.modelMatches?Theme.text:Theme.muted}
                }
            }
        }
    }
    HoverHandler {id:hover}
    ToolTip.visible:hover.hovered && (root.feedback.length>0 || root.blockedReason.length>0 || root.modelMatches)
    ToolTip.delay:700
    ToolTip.text:[root.feedback || root.blockedReason,root.modelMatches ? "剩余开启次数 "+root.localDisplay.remaining_openings+"；已激活 "+root.localDisplay.activations+"次。每组两次击打，+0表示同组第二次未命中，无效表示命中不可击打环数。":""].filter(text=>text.length>0).join("\n")
}
