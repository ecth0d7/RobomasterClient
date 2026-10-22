import QtQuick
import QtQuick.Controls
import "OperatorMessageData.js" as Messages
import "EventFormat.js" as Events

Item {
    id:root
    property var events:[]
    property int clientID:0
    property int revision:0
    property bool previewOnly:false
    property bool dead:false
    property bool enabledDisplay:true
    property double drawingNow:Date.now()
    // 本机接收后的UI展示窗口，与事件发生时刻、处罚效果时长无关。
    readonly property int bannerWindowMs:6000
    readonly property int cardWindowMs:4000
    readonly property var recent:Messages.records(events,clientID,revision,drawingNow,previewOnly)
    readonly property var notices:recent.filter(e=>e.event_id!==undefined && drawingNow-e.observed_at_ms<bannerWindowMs)
        .map(e=>({record:e,view:Events.presentation(e.event_id,e.param,clientID)})).filter(e=>e.view!==null)
    readonly property var bannerNotices:notices.filter(e=>!(e.view.kind==="kill" && e.view.victim===clientID && !dead))
    readonly property var latest:bannerNotices.length?bannerNotices[bannerNotices.length-1]:null
    readonly property var ownDeaths:notices.filter(e=>e.view.kind==="kill" && e.view.victim===clientID)
    readonly property var banner:dead ? ownDeaths.length?ownDeaths[ownDeaths.length-1].view
        :({kind:"kill",team:clientID>100?"blue":"red",caption:"战亡",killer:0,victim:clientID}) :latest?.view??null
    readonly property var cards:notices.filter(e=>["rune","dart"].includes(e.view.kind) && drawingNow-e.record.observed_at_ms<cardWindowMs)
    readonly property var card:{
        if(!cards.length)return null;
        const last=cards[cards.length-1];
        // 同次成绩3与激活4常成对到达，不能立即用无成绩的4覆盖10臂/平均环数。
        if(last.record.event_id===4) {
            const result=cards.filter(e=>e.record.event_id===3 && last.record.observed_at_ms-e.record.observed_at_ms>=0
                && last.record.observed_at_ms-e.record.observed_at_ms<=1000);
            if(result.length)return result[result.length-1].view;
        }
        return last.view;
    }
    readonly property var penalties:recent.filter(e=>[1,2,3].includes(e.penalty_type) && drawingNow-e.observed_at_ms<cardWindowMs)
    readonly property var penalty:penalties.length?penalties[penalties.length-1]:null
    readonly property bool penaltyVisible:enabledDisplay && !dead && penalty!==null
    readonly property bool cardVisible:enabledDisplay && !dead && !penaltyVisible && card!==null
    visible:enabledDisplay
    onEventsChanged:drawingNow=Date.now()
    onClientIDChanged:drawingNow=Date.now()
    onRevisionChanged:drawingNow=Date.now()
    Timer {interval:100;repeat:true;running:root.visible && root.events.length>0;onTriggered:root.drawingNow=Date.now()}
    OperatorFloatingNoticeForm {
        objectName:"floatingNotice"
        x:(parent.width-width)/2;y:184
        visible:root.banner!==null
        caption:root.banner?.caption??"";team:root.banner?.team??"green"
        killer:root.banner?.killer??0;victim:root.banner?.victim??0
        iconSource:root.banner?.icon==="rune"?"../resources/player/rune_tab/rune_tab_"+(root.clientID>100?"blue":"red")+".png":""
        Accessible.name:root.banner?.kind==="kill"?root.banner.killer>0?Events.robotName(root.banner.killer)+"摧毁"+Events.robotName(root.banner.victim):Events.robotName(root.banner.victim)+"战亡":caption
        HoverHandler {id:bannerHover}
        ToolTip.visible:bannerHover.hovered
        ToolTip.delay:400
        ToolTip.text:Accessible.name
    }
    Item {
        objectName:"penaltyNotice"
        anchors.fill:parent;visible:root.penaltyVisible
        Rectangle {anchors.fill:parent;color:"transparent";border.width:4;border.color:"#467c2422"}
        Item {
            x:(parent.width-width)/2;y:parent.height/2-62;width:584;height:124
            Image {anchors.fill:parent;source:"../resources/player/message/warning_box.png";fillMode:Image.PreserveAspectFit;mipmap:true}
            OperatorText {x:30;y:17;width:parent.width-60;height:34;text:({1:"黄牌警告",2:"双方黄牌警告",3:"红牌罚下"})[root.penalty?.penalty_type]??"";size:22;minimumSize:12;horizontalAlignment:Text.AlignHCenter}
            OperatorText {x:30;y:60;width:parent.width-60;height:42;text:[root.penalty?.penalty_quantity===undefined?"":"收到时判罚数量 "+root.penalty.penalty_quantity,root.penalty?.penalty_effect_sec===undefined?"":"收到时效果时长 "+root.penalty.penalty_effect_sec+"s"].filter(text=>text.length>0).join("　");size:14;minimumSize:10;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.WordWrap}
        }
    }
    Item {
        objectName:"eventDetailNotice"
        x:(parent.width-width)/2;y:parent.height/2+120;width:488;height:root.card?.details?110:88
        visible:root.cardVisible
        Accessible.name:(root.card?.caption??"")+" "+(root.card?.details??"")
        HoverHandler {id:cardHover}
        ToolTip.visible:cardHover.hovered
        ToolTip.delay:400
        ToolTip.text:Accessible.name
        Rectangle {anchors.fill:parent;color:Theme.hudSurface;radius:3}
        Image {x:16;y:8;width:72;height:72;source:root.card?.kind==="dart"?"../resources/player/dart_middle_"+(root.card?.team??"red")+".png":"../resources/player/rune_tab/rune_tab_"+(root.clientID>100?"blue":"red")+".png";fillMode:Image.PreserveAspectFit;mipmap:true}
        OperatorText {x:108;y:root.card?.details?14:0;width:parent.width-124;height:root.card?.details?40:parent.height;text:root.card?.caption??"";size:19;minimumSize:11;wrapMode:Text.WordWrap;color:root.card?.kind==="dart"?(root.card.team==="blue"?Theme.blue:Theme.red):Theme.text}
        OperatorText {x:108;y:58;width:parent.width-124;height:36;text:root.card?.details??"";visible:text.length>0;size:15;minimumSize:10;clip:true}
    }
}
