import QtQuick
import QtQuick.Controls
import "OperatorCombatData.js" as Combat

// 脱战标记和倒数是两个独立optional字段；倒数归零不改写机器人状态。
OperatorCombatStateForm {
    id: root
    property var telemetry: null
    property int clientID: 0
    property bool connectedToPlayer: false
    property bool countdownSecondsVerified: false
    property bool previewOnly: false
    readonly property var display: Combat.view(telemetry,clientID,connectedToPlayer,countdownSecondsVerified,previewOnly)
    readonly property bool displayable: display.displayable
    accent: Theme[display.tone]
    currentStateVisible: display.current
    labelText: display.label
    outOfCombat: display.out
    Accessible.role: Accessible.StaticText
    Accessible.name: display.label
    Accessible.description: display.description
    HoverHandler { id: hover }
    ToolTip.visible: hover.hovered
    ToolTip.delay: 450
    ToolTip.text: Accessible.description
}
