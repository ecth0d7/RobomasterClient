import QtQuick
import QtQuick.Window
import QtQuick.Effects
import "OperatorData.js" as Data
import "OperatorResultData.js" as Result

Item {
    id:root
    property var telemetry:null
    property int clientID:0
    property bool ended:false
    property bool obscured:false
    property bool dismissed:false
    property bool showingPanel:false
    property string presentedKey:""
    readonly property var outcome:Result.result(telemetry,clientID)
    readonly property string resultKey:ended && outcome.round.state==="fresh"
        ?clientID+":"+outcome.round.value+":"+(outcome.winner??"unknown"):""
    readonly property bool outsideSettlement:Data.state(telemetry,"gameStatus","current_stage")==="fresh" && telemetry.gameStatus.current_stage!==5
    readonly property bool presentationVisible:ended && !obscured && !dismissed
    property alias panelObject:panel
    visible:ended && !obscured
    function dismiss(){dismissed=true;intro.stop();}
    function updatePresentation(){
        if(!ended || obscured || !resultKey.length || resultKey===presentedKey)return;
        presentedKey=resultKey;dismissed=false;showingPanel=false;reveal.restart();intro.restart();
    }
    onResultKeyChanged:updatePresentation()
    onObscuredChanged:updatePresentation()
    onClientIDChanged:{presentedKey="";dismissed=false;showingPanel=false;intro.stop();}
    // 连接暂时变旧不清除已关闭标记；只有明确离开结算或新身份/局次才开始新一轮。
    onOutsideSettlementChanged:if(outsideSettlement){
        presentedKey="";dismissed=false;showingPanel=false;intro.stop();
    }
    onEndedChanged:updatePresentation()
    Rectangle {anchors.fill:parent;color:"#50000000";visible:root.presentationVisible}
    MouseArea {
        anchors.fill:parent
        visible:root.presentationVisible
        acceptedButtons:Qt.AllButtons
        onWheel:wheel=>wheel.accepted=true
    }
    Item {
        id:emblem
        anchors.centerIn:parent;width:760;height:340
        visible:root.presentationVisible && !root.showingPanel
        property color accent:root.outcome.won?(root.clientID>100?Theme.blue:Theme.red):"#92999c"
        Rectangle {
            anchors.centerIn:parent;width:parent.width;height:180
            gradient:Gradient {GradientStop {position:0;color:"#0015191a"} GradientStop {position:.5;color:Qt.rgba(emblem.accent.r,emblem.accent.g,emblem.accent.b,.5)} GradientStop {position:1;color:"#0015191a"}}
        }
        Image {
            x:270;y:0;width:220;height:220
            source:"../resources/player/"+(root.clientID>100?"blue":"red")+"_team_logo.png"
            fillMode:Image.PreserveAspectFit;mipmap:true
            opacity:root.outcome.won ? .9 : .25
            layer.enabled:!root.outcome.won
            layer.effect:MultiEffect {saturation:-1}
        }
        OperatorText {objectName:"resultTitle";x:40;y:174;width:680;height:86;text:root.outcome.title;size:54;font.bold:true;color:root.outcome.won?Theme.text:"#d5d9da";horizontalAlignment:Text.AlignHCenter}
        OperatorText {x:40;y:270;width:680;height:40;text:root.outcome.reason;size:22;color:Theme.text;horizontalAlignment:Text.AlignHCenter}
    }
    ParallelAnimation {
        id:reveal
        NumberAnimation {target:emblem;property:"opacity";from:0;to:1;duration:Theme.reducedMotion?0:260}
        NumberAnimation {target:emblem;property:"scale";from:.9;to:1;duration:Theme.reducedMotion?0:400;easing.type:Easing.OutCubic}
    }
    Timer {id:intro;interval:Theme.reducedMotion?0:2200;onTriggered:root.showingPanel=true}
    OperatorResultPanel {
        id:panel
        objectName:"resultPanel"
        anchors.centerIn:parent
        visible:root.presentationVisible && root.showingPanel
        telemetry:root.telemetry;clientID:root.clientID
    }
    OperatorText {
        anchors.horizontalCenter:parent.horizontalCenter;y:parent.height/2+196;width:400;height:32
        visible:root.presentationVisible && !root.showingPanel
        text:"按 Esc 关闭结算";size:16;color:Theme.muted;horizontalAlignment:Text.AlignHCenter
    }
    OperatorButton {
        objectName:"reopenResult"
        anchors.horizontalCenter:parent.horizontalCenter;y:132;width:160;height:40
        visible:root.dismissed
        text:"查看比赛结算"
        onClicked:{root.dismissed=false;root.showingPanel=true;}
    }
    Shortcut {sequence:"Escape";enabled:root.presentationVisible && root.Window.window?.active===true;autoRepeat:false;onActivated:root.dismiss()}
}
