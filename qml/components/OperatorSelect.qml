import QtQuick
import QtQuick.Controls
import QtQuick.Window

ComboBox {
    id: root
    property string label: ""
    property string emptyText: "请选择"
    readonly property real hudScale: Window.window?.ui?.layoutScale ?? 1
    property color textColor: Theme.text
    property real disabledOpacity: 0.4
    property color backgroundColor: "#282f2c"
    property color pressedColor: "#39443f"
    property color borderColor: Theme.line
    property color focusBorderColor: Theme.green
    property alias borderWidth: selectOutline.thickness
    property color indicatorColor: Theme.muted
    property size indicatorSize: Qt.size(12, 8)
    property real indicatorStrokeWidth: 1
    property real indicatorRightMargin: 11
    property color popupColor: "#222b26"
    property color optionHoverColor: "#415448"
    property real optionHeight: 38
    property real popupGap: 4
    property real popupMaximumHeight: 260
    property alias popupPadding: optionsPopup.padding
    font.family: Theme.fontFamily
    font.pixelSize: Math.max(12, 9.5 / Math.max(0.1, hudScale))
    implicitWidth: 240
    implicitHeight: 38
    leftPadding: 12
    rightPadding: 30
    Accessible.name: label
    contentItem: OperatorText { text: root.currentIndex < 0 ? root.emptyText : root.displayText; font: root.font; color: root.textColor; opacity: root.enabled ? 1 : root.disabledOpacity }
    background: Rectangle {
        color: root.down ? root.pressedColor : root.backgroundColor
        OperatorOutline { id: selectOutline; color: root.activeFocus ? root.focusBorderColor : root.borderColor }
    }
    indicator: Item {
        opacity: root.enabled ? 1 : root.disabledOpacity
        x: root.width - width - root.indicatorRightMargin
        y: (root.height - height) / 2
        width: root.indicatorSize.width
        height: root.indicatorSize.height
        Rectangle { x: parent.width / 12; y: parent.height / 4; width: parent.width * 7 / 12; height: root.indicatorStrokeWidth; rotation: 40; color: root.indicatorColor }
        Rectangle { x: parent.width / 2; y: parent.height / 4; width: parent.width * 7 / 12; height: root.indicatorStrokeWidth; rotation: -40; color: root.indicatorColor }
    }
    delegate: ItemDelegate {
        required property var modelData
        required property int index
        width: root.width
        height: root.optionHeight
        contentItem: OperatorText { text: String(parent.modelData); font: root.font; color: root.textColor }
        background: Rectangle { color: parent.highlighted || parent.hovered ? root.optionHoverColor : root.popupColor }
        highlighted: root.highlightedIndex === index
    }
    popup: Popup {
        id: optionsPopup
        // Popup 进入窗口浮层后不继承 HUD 画布的缩放，需要保持同一比例。
        scale: root.hudScale
        transformOrigin: Popup.TopLeft
        y: root.height + root.popupGap
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + padding * 2, root.popupMaximumHeight)
        padding: 4
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
        background: Rectangle { color: root.popupColor; OperatorOutline { color: root.borderColor; thickness: root.borderWidth } }
    }
}
