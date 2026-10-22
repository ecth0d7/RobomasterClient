import QtQuick
import QtQuick.Controls
import "OperatorData.js" as Data
import "OperatorOwnStatusData.js" as Own
import "OperatorEnergyData.js" as Energy
import "OperatorOwnVitalsData.js" as Vitals
import "OperatorLocalCombatData.js" as LocalCombat

OperatorVitalsForm {
    id: root
    property var telemetry: null
    property var airDisplayData: null
    property bool airDisplayProjectionConnected: false
    property string airDisplaySessionId: ""
    property string experienceRulesVersion: ""
    property bool previewOnly: false
    property bool connectedToPlayer: false
    property bool combatCountdownSecondsVerified: false
    property var ownStatusItems: []
    property var projectionItems: []
    property string ownStatusSessionId: ""
    property double statusNowMs: Date.now()
    readonly property int currentRound: Data.state(telemetry,"gameStatus","current_round") === "fresh"
        && Number.isSafeInteger(telemetry?.gameStatus?.current_round) ? telemetry.gameStatus.current_round : 0
    readonly property var retainedStatuses: Own.project(ownStatusItems,clientID,ownStatusSessionId,currentRound,statusNowMs,previewOnly)
    readonly property var activeStatuses: retainedStatuses.filter(record => record.active)
    readonly property var nativePenaltyRecord: {
        const pen = root.telemetry?.penalty;
        if (!pen || !root.connectedToPlayer || Data.state(root.telemetry, "penalty", "penalty_type") !== "fresh") return null;
        const countKnown=Data.state(root.telemetry,"penalty","total_penalty_num")==="fresh"
            && Data.notOlderThan(root.telemetry,"penalty","total_penalty_num","penalty_type")
            && Number.isInteger(pen.total_penalty_num);
        if(countKnown && pen.total_penalty_num<=0)return null;
        const pType = Number(pen.penalty_type);
        if (pType < 1 || pType > 3) return null;
        const kind = pType === 3 ? "red_card" : pType === 2 ? "bilateral_yellow" : "yellow_card";
        const count = countKnown?pen.total_penalty_num:null;
        const sec = Number.isInteger(pen.penalty_effect_sec) ? pen.penalty_effect_sec : null;
        const timerFresh = Data.state(root.telemetry,"penalty","penalty_effect_sec") === "fresh"
            && Data.notOlderThan(root.telemetry,"penalty","penalty_effect_sec","penalty_type");
        return {
            kind: kind,
            active: true,
            state: "fresh",
            count: count,
            count_valid: countKnown,
            count_semantics: "current_penalty_quantity",
            penalty_effect_sec:timerFresh?sec:undefined,
            field_states:{count:countKnown?"fresh":"missing",penalty_effect_sec:timerFresh?"fresh":"missing"},
            remaining_seconds: null,
            timer_valid: false,
            estimated_remaining_seconds: null,
            source_kind: "mqtt",
            source_id: "PenaltyInfo",
            snapshot_id: "协议未提供源快照",
            session_id: "当前本机接收",
            robot_id: root.clientID,
            round: root.currentRound,
            clock_basis: "local_receive"
        };
    }
    // Module offline, pending respawn and attack buffs do not prove a chassis
    // power cutoff, respawn weakness or a power buff. Those need explicit data.
    readonly property var localCombat: root.connectedToPlayer ? LocalCombat.view(projectionItems,clientID,statusNowMs,previewOnly) : null
    readonly property var nativeStatusHints: {
        const sameRobot=Data.state(telemetry,"robotStatic","robot_id")==="fresh" && telemetry?.robotStatic?.robot_id===clientID;
        const alive=Data.state(telemetry,"robotStatic","alive_state")==="fresh" && telemetry?.robotStatic?.alive_state===1;
        if(!connectedToPlayer || !sameRobot || !alive)return [];
        const result=[];
        for(const [kind,key] of [["power_cutoff","chassis_power_cutoff_remaining_seconds"],["respawn_weakness","respawn_weakness_remaining_seconds"]]) {
            const seconds=localCombat?.[key];
            if(typeof seconds==="number" && seconds>0) {
                const record=LocalCombat.hint(kind,seconds,localCombat.source,clientID,currentRound);
                if(kind==="power_cutoff")record.target_modules=["chassis"];
                result.push(record);
            }
        }
        const buff=telemetry?.buff;
        if(["buff_type","buff_level","buff_left_time"].every(key=>Data.state(telemetry,"buff",key)==="fresh")
            && buff?.buff_type===4 && Number.isInteger(buff.buff_left_time) && buff.buff_left_time>0 && buff.buff_level>0)
            result.push(LocalCombat.hint("power_bonus",buff.buff_left_time,null,clientID,currentRound));
        return result;
    }
    readonly property var penaltyRecord: (activeStatuses.find(record => record.kind === "red_card")
        ?? activeStatuses.find(record => record.kind === "yellow_card")
        ?? activeStatuses.find(record => record.kind === "bilateral_yellow"))
        ?? nativePenaltyRecord
    onOwnStatusItemsChanged: statusNowMs = Date.now()
    onProjectionItemsChanged: statusNowMs = Date.now()
    onOwnStatusSessionIdChanged: statusNowMs = Date.now()
    onCurrentRoundChanged: statusNowMs = Date.now()
    onClientIDChanged: statusNowMs = Date.now()
    onVisibleChanged: if (visible) statusNowMs = Date.now()
    Timer { interval: 250; repeat: true; running: root.visible && (root.retainedStatuses.length > 0 || root.projectionItems.length>0); onTriggered: root.statusNowMs = Date.now() }
    readonly property var nativeDisplay: Vitals.view(root.telemetry,root.clientID,root.connectedToPlayer,root.experienceRulesVersion,root.previewOnly)
    // 头像和脱战行共用已核对主体／连接／逐字段存活状态，不由HP=0推断战亡。
    clientID: 0
    drawingReferenceVisible: false
    drawingBackgroundVisible: false
    defeated: root.combatControl.display.dead
    readonly property var energyRows: Energy.rows
    readonly property var energyDisplay: Energy.view(root.telemetry, root.clientID, root.connectedToPlayer, root.previewOnly)
    // 公开的连接线计算保留；Form用相同参数表达实际槽几何。
    function leftBarInset(barY) {
        return Math.max(0, root.wingRight * root.portraitScale
            - (barY - root.healthTop) * root.wingSlopeX / root.wingSlopeY - root.barLeft);
    }
    experienceControl.display: root.nativeDisplay.experience
    levelControl.display: root.nativeDisplay.level
    healthControl.display: root.nativeDisplay.health
    primaryEnergyControl.display: root.energyDisplay[0]
    secondaryEnergyControl.display: root.energyDisplay[1]
    primaryCaptionControl.display: root.energyDisplay[0]
    primaryCaptionControl.connectedToPlayer: root.connectedToPlayer
    secondaryCaptionControl.display: root.energyDisplay[1]
    secondaryCaptionControl.connectedToPlayer: root.connectedToPlayer
    combatControl.telemetry: root.telemetry
    combatControl.clientID: root.clientID
    combatControl.connectedToPlayer: root.connectedToPlayer
    combatControl.countdownSecondsVerified: root.combatCountdownSecondsVerified
    combatControl.previewOnly: root.previewOnly
    penaltyControl.record: root.penaltyRecord
    hintsControl.records: root.aerial ? [] : root.nativeStatusHints.filter(record=>!root.activeStatuses.some(other=>other.kind===record.kind)).concat(root.activeStatuses)
    airControl.telemetry: root.telemetry
    airControl.displayData: root.airDisplayData
    airControl.clientID: root.clientID
    airControl.connectedToPlayer: root.connectedToPlayer
    airControl.previewOnly: root.previewOnly
    airControl.displayProjectionConnected: root.airDisplayProjectionConnected
    airControl.displaySessionId: root.airDisplaySessionId
}
