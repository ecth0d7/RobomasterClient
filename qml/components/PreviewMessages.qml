import QtQuick
import "OperatorMessageData.js" as Messages
import "EventFormat.js" as EventFormat

// 仅生成UI通知样例；不创建生产接收器、传感器、共享插件或机器人控制。
QtObject {
    id: root
    property string mode: "nominal"
    property int clientId: 3
    property int raceRevision: 0
    property int robotRevision: 0
    property int step: 0
    property double sampleAt: Date.now()
    readonly property string effectiveMode: mode==="sequence"
        ? ["empty","race","both","robot","partial","duplicate","expired","unknown-time","disconnected","ended"][step%10] : mode
    readonly property bool raceSourcePresent: effectiveMode!=="disconnected"
    readonly property bool robotSourcePresent: ["robot","both","disconnected"].includes(effectiveMode)
    readonly property var raceEntries: makeRace(effectiveMode)
    readonly property var robotEntries: robotSourcePresent?[
        robotRecord("robot-1","mock · 1号：本机视觉发现，等待人工确认"),
        robotRecord("robot-2","mock · 共享插件未启用，本机消息独立")]:[]
    onModeChanged: {step=0;sampleAt=Date.now();}
    property Timer ticker: Timer {
        interval:1600;repeat:true;running:root.mode==="sequence"
        onTriggered:{root.step+=1;root.sampleAt=Date.now();}
    }
    function raceRecord(id,param,index) {
        const record=Messages.observed(EventFormat.notificationText(id,param),EventFormat.critical(id),
            "mock.telemetry.eventReceived",clientId,raceRevision,index,sampleAt,true);
        Object.assign(record,{event_id:id,param:param,tone:EventFormat.notificationTone(id,param,clientId)});
        record.match_clock_sec=Math.max(0,390-step*3-index);record.match_clock_fresh_at_observation=true;
        return record;
    }
    function robotRecord(id,text) {
        const record=Messages.observed(text,true,"mock.local-notification",clientId,robotRevision,id,sampleAt,true);
        record.notification_id=id;record.tone="adverse"; // 机器人消息仍按手册绘制白色。
        return record;
    }
    function makeRace(state) {
        if(["empty","robot"].includes(state))return [];
        const own=clientId>100?103:3,enemy=clientId>100?3:103,killer=clientId>100?101:1;
        const records=[raceRecord(4,"1",1),raceRecord(1,enemy+","+killer,2),raceRecord(1,own+",0",3)];
        if(state==="partial") {
            delete records[0].observed_at_ms;records[1].text=" ";
            records[2]=raceRecord(15,"0",4);
        }
        if(state==="expired")records.forEach(r=>r.observed_at_ms=sampleAt-30001);
        if(state==="unknown-time")records.forEach(r=>delete r.observed_at_ms);
        if(state==="future")records.forEach(r=>r.observed_at_ms=sampleAt+60000);
        if(state==="ended")records.forEach(r=>r.lifecycle="ended");
        if(state==="foreign")records.forEach(r=>r.client_id=clientId>100?3:103);
        if(state==="duplicate")records[1].notification_id=records[0].notification_id;
        if(state==="expires")records.forEach(r=>r.hud_window_ms=1500);
        if(state==="titles")return [raceRecord(7,"",7),raceRecord(10,"",10),raceRecord(13,"",13)];
        if(state==="long")records[2].text="mock · "+"很长的通知参数，需要在原槽内省略并保留完整提示。".repeat(12);
        if(state==="legacy")return [{text:"mock · 没有观察时间的旧格式通知",critical:true}];
        return records;
    }
}
