import QtQuick
import "OperatorData.js" as Data
import "OperatorExchangeData.js" as Exchange

// Match-wide states follow the received stage/alive flags. A zero health value
// alone never starts respawn, and a submitted command never confirms revival.
Item {
    id: root
    property var telemetry: null
    property int clientID: 0
    property bool connected: false
    property bool obscured: false
    property var revivePolicy: ({})
    property bool actionsAvailable: false
    property bool temporaryActivation:false
    readonly property var game: telemetry?.gameStatus ?? ({})
    readonly property var respawn: telemetry?.robotRespawn ?? ({})
    readonly property bool liveMatch: connected && Data.state(telemetry,"gameStatus","current_stage") === "fresh"
    readonly property bool dead: liveMatch && game.current_stage === 4
        && Data.state(telemetry,"robotStatic","alive_state") === "fresh"
        && telemetry?.robotStatic?.robot_id === clientID && telemetry?.robotStatic?.alive_state === 2
    readonly property bool ended: liveMatch && game.current_stage === 5
    readonly property bool paused: liveMatch && Data.state(telemetry,"gameStatus","is_paused") === "fresh" && game.is_paused === true
    readonly property bool progressKnown: Data.state(telemetry,"robotRespawn","current_respawn_progress") === "fresh"
        && Data.state(telemetry,"robotRespawn","total_respawn_progress") === "fresh" && respawn.total_respawn_progress > 0
    readonly property real progress: progressKnown ? Data.fraction(respawn.current_respawn_progress,respawn.total_respawn_progress) : 0
    readonly property bool robotOffline: Data.state(telemetry,"robotStatic","connection_state") === "fresh"
        && telemetry.robotStatic.connection_state === 0
    readonly property bool progressComplete: progressKnown && respawn.current_respawn_progress === respawn.total_respawn_progress
    property alias resultObject:resultOverlay

    signal commonIntent(var fields)
    function reviveReason(kind) {
        if (!dead || obscured || temporaryActivation) return "当前不处于可操作的战亡界面";
        if (robotOffline) return "机器人离线，复活暂停";
        return Exchange.eligibility(telemetry,clientID,Exchange.item(kind),revivePolicy?.[kind],actionsAvailable);
    }
    function reviveFields(kind) { return Exchange.fields(Exchange.item(kind),revivePolicy?.[kind],""); }
    function requestRevive(kind) {
        if (reviveReason(kind).length) return;
        const fields = reviveFields(kind);
        if (fields) commonIntent(fields);
    }
    visible: !obscured && (dead && !temporaryActivation || ended || paused)
    Rectangle {
        anchors.fill: parent
        visible:!root.ended
        color: root.dead && !root.temporaryActivation ? "#807f7f7f" : "#42000000"
    }
    OperatorRespawnCard {
        objectName: "respawnCard"
        anchors.centerIn: parent
        visible: root.dead && !root.temporaryActivation
        robotOffline: root.robotOffline
        complete: root.progressComplete
        progressKnown: root.progressKnown
        progress: root.progress
        cost: Data.text(root.telemetry,"robotRespawn","gold_cost_for_respawn")
        paidReason: root.reviveReason("paid")
        freeReason: root.reviveReason("free")
        paidAllowed: paidReason.length === 0 && root.reviveFields("paid") !== null
        freeAllowed: freeReason.length === 0 && root.reviveFields("free") !== null
        onRequested: kind => root.requestRevive(kind)
    }
    Rectangle {
        anchors.centerIn: parent
        visible:root.paused && !root.ended && (!root.dead || root.temporaryActivation)
        width:440
        height:110
        color: "#e8101614"
        border.width: 1
        border.color: Theme.hudBorder
        Column {
            anchors.fill:parent;anchors.margins:16;spacing:8
            OperatorText {
                width:parent.width;height:32;size:25
                font.bold: true; horizontalAlignment: Text.AlignHCenter
                text:"比赛暂停"
            }
            OperatorText {
                width:parent.width;height:24;size:14
                horizontalAlignment: Text.AlignHCenter
                text:"等待选手端继续比赛"
            }
        }
    }
    OperatorResultOverlay {
        id:resultOverlay
        objectName:"resultOverlay"
        anchors.fill:parent
        telemetry:root.telemetry;clientID:root.clientID
        ended:root.ended;obscured:root.obscured
    }
}
