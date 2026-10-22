import QtQuick
import QtQuick.Controls
import QtQuick.Window

CheckBox {
    id: root
    implicitWidth: 240
    implicitHeight: 38
    property bool centerIndicator: false
    readonly property real hudScale: Window.window?.ui?.layoutScale ?? 1
    property real indicatorSize: 22
    property real textSpacing: 12
    property color textColor: Theme.text
    property real disabledOpacity: 0.4
    property alias uncheckedSource: uncheckedImage.source
    property alias checkedSource: checkedImage.source
    property color focusColor: Theme.green
    property real focusBorderWidth: 1
    property real focusMargin: 2
    font.family: Theme.fontFamily
    font.pixelSize: Math.max(12, 9.5 / Math.max(0.1, hudScale))
    leftPadding: 0
    rightPadding: 0
    Accessible.name: text
    indicator: Item {
        opacity: root.enabled ? 1 : root.disabledOpacity
        x: root.centerIndicator ? (root.width - width) / 2 : 0
        y: (root.height - height) / 2
        width: root.indicatorSize
        height: root.indicatorSize
        OperatorSprite { id: uncheckedImage; anchors.fill: parent; asset: "ServerUI_CheckNormal" }
        OperatorSprite { id: checkedImage; anchors.fill: parent; asset: "ServerUI_Checked"; visible: root.checked }
        Rectangle { anchors.fill: parent; anchors.margins: -root.focusMargin; color: "transparent"; border.color: root.focusColor; border.width: root.focusBorderWidth; visible: root.activeFocus }
    }
    contentItem: OperatorText { leftPadding: root.indicatorSize + root.textSpacing; text: root.text; font: root.font; color: root.textColor; opacity: root.enabled ? 1 : root.disabledOpacity }
}
