import QtQuick
import "OperatorData.js" as Data

OperatorDashboardForm {
    id: root
    designCanvas: false
    economyText: Data.text(root.telemetry, "globalLogistics", "remaining_economy")
    signal panelRequested(string panel)
    signal mapModeRequested(int mode)
    signal mapPointRequested(real mapX, real mapY)
    signal mapEnemyRequested(int robotId)
    Connections {
        target: root.keyMonitorObject
        function onCaptureRequested(capture) { root.mouseCaptureRequested(capture); }
    }
    Connections {
        target: root.buffHudObject
        function onDetailsRequested() { root.panelRequested("buffs"); }
    }
    Connections {
        target: root.adviceHudObject
        function onDetailsRequested() { root.panelRequested("decision-details"); }
    }
    Connections {
        target: root.mapObject
        function onModeRequested(mode) { root.mapModeRequested(mode); }
        function onMarkRequested(mapX, mapY) { root.mapPointRequested(mapX, mapY); }
        function onEnemyRequested(robotId) { root.mapEnemyRequested(robotId); }
    }
    Connections {
        target: root.exchangeHitArea
        function onClicked() { root.panelRequested(root.clientID % 100 === 2 ? "engineer" : root.clientID % 100 === 6 ? "air" : "commands"); }
    }
}
