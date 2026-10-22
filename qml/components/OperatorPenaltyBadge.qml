import QtQuick
import QtQuick.Controls
import "OperatorOwnStatusData.js" as Own

OperatorPenaltyBadgeForm {
    id: root
    property var record: null
    visible: record !== null && record.active === true
    iconSource: record ? "../resources/player/my_robot/statusbar_warning_" + (record.kind === "red_card" ? "red" : "yellow") + ".png" : ""
    labelText: record?.count_valid ? Own.cardText(record) : ""
    labelColor: record?.kind === "red_card" ? Theme.red : Theme.warning
    Accessible.role: Accessible.StaticText
    Accessible.name: record ? Own.cardText(record) : ""
    Accessible.description: record ? Own.description(record) : ""
    HoverHandler { id: hover }
    ToolTip.visible: hover.hovered
    ToolTip.delay: 450
    ToolTip.text: Accessible.description
}
