import QtQuick
import QtQuick.Controls

OperatorVitalsEnergyCaptionForm {
    id: root
    property var display: ({hasCurrent: false, description: "", caption: "", warning: false,
                            ratioState: "none", subject: {state: "missing"}, current: {state: "missing"}})
    property bool connectedToPlayer: false
    valuePresent: root.display.hasCurrent
    captionText: root.display.caption
    descriptionText: root.display.description
    captionColor: root.display.warning && root.connectedToPlayer && root.display.subject.state === "fresh"
        && ["fresh", "invalid"].includes(root.display.current.state) ? Theme.warning
        : root.display.ratioState === "live" ? Theme.text : Theme.muted
    HoverHandler { id: hover }
    ToolTip.visible: hover.hovered
    ToolTip.delay: 450
    ToolTip.text: root.display.description
}
