import QtQuick
import QtQuick.Controls
import QtQuick.Window

Slider {
    id: root
    property string label: ""
    property string unit: ""
    readonly property real hudScale: Window.window?.ui?.layoutScale ?? 1
    property real disabledOpacity: 0.45
    property color labelColor: Theme.text
    property alias valueColor: valueText.color
    property alias valueFont: valueText.font
    property real valueWidth: 48
    property real labelHeight: 25
    property real trackY: 36
    property real trackHeight: 3
    property alias trackSource: trackImage.source
    property alias activeTrackSource: activeTrackImage.source
    property real trackOpacity: 0.25
    property real activeTrackOpacity: 0.9
    property real handleSize: 15
    property real handleRadius: handleSize / 2
    property color handleColor: Theme.text
    property color pressedHandleColor: Theme.green
    property color handleBorderColor: Theme.muted
    property color focusHandleBorderColor: Theme.green
    property real handleBorderWidth: 1
    property real focusHandleBorderWidth: 2
    font.family: Theme.fontFamily
    font.pixelSize: Math.max(12, 9.5 / Math.max(0.1, hudScale))
    from: 0
    to: 100
    stepSize: 1
    implicitWidth: 240
    implicitHeight: 54
    leftPadding: 7
    rightPadding: 7
    topPadding: 0
    bottomPadding: 0
    Accessible.name: label
    OperatorText { x: 0; y: 0; width: parent.width - root.valueWidth; height: root.labelHeight; text: root.label; font: root.font; color: root.labelColor; opacity: root.enabled ? 1 : root.disabledOpacity }
    OperatorText { id: valueText; x: parent.width - root.valueWidth; y: 0; width: root.valueWidth; height: root.labelHeight; text: Math.round(root.value) + root.unit; numeric: true; font.pixelSize: root.font.pixelSize; horizontalAlignment: Text.AlignRight; color: root.enabled ? Theme.text : Theme.muted }
    background: Item {
        opacity: root.enabled ? 1 : root.disabledOpacity
        x: root.leftPadding
        y: root.trackY
        width: root.availableWidth
        height: root.trackHeight
        OperatorSprite { id: trackImage; anchors.fill: parent; asset: "Elements-Slider-Norm_2x"; fillMode: Image.Stretch; opacity: root.trackOpacity }
        Item {
            width: parent.width * root.visualPosition
            height: parent.height
            clip: true
            visible: width > 0
            OperatorSprite { id: activeTrackImage; width: root.availableWidth; height: parent.height; asset: "Elements-Slider-Active_2x"; fillMode: Image.Stretch; opacity: root.activeTrackOpacity }
        }
    }
    handle: Rectangle {
        opacity: root.enabled ? 1 : root.disabledOpacity
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.trackY + (root.trackHeight - height) / 2
        width: root.handleSize
        height: root.handleSize
        radius: root.handleRadius
        color: root.pressed ? root.pressedHandleColor : root.handleColor
        border.color: root.activeFocus ? root.focusHandleBorderColor : root.handleBorderColor
        border.width: root.activeFocus ? root.focusHandleBorderWidth : root.handleBorderWidth
    }
}
