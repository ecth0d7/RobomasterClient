import QtQuick
import QtQuick.Controls
import QtQuick.Window

Button {
    id: root
    property bool primary: false
    property bool laboratory: Window.window?.ui?.modalActive === true
    readonly property real hudScale: Window.window?.ui?.layoutScale ?? 1
    property color textColor: Theme.text
    property real disabledOpacity: 0.45
    property alias imageSource: buttonImage.source
    property int imageBorder: 8
    property real edgeInset: 4
    property real edgeThickness: Math.max(1.5, Theme.hudStroke(hudScale, false))
    // 禁用色沿用官方 30% 白描边与共同 HUD 暗底的合成结果。
    property color edgeColor: enabled ? "#ffffff" : Qt.rgba(
        Theme.hudSolid.r + (1 - Theme.hudSolid.r) * 0.3,
        Theme.hudSolid.g + (1 - Theme.hudSolid.g) * 0.3,
        Theme.hudSolid.b + (1 - Theme.hudSolid.b) * 0.3, 1)
    property color focusColor: Theme.green
    property real focusMargin: 2
    font.family: Theme.fontFamily
    font.pixelSize: Math.max(14, 9.5 / Math.max(0.1, hudScale))
    implicitWidth: 146
    implicitHeight: 38
    Accessible.name: text
    contentItem: OperatorText {
        text: root.text
        font: root.font
        color: root.textColor
        horizontalAlignment: Text.AlignHCenter
        opacity: root.enabled ? 1 : root.disabledOpacity
    }
    background: Item {
        Rectangle {
            anchors.fill: parent
            visible: root.laboratory
            color: !root.enabled ? Theme.hudSolid : root.down ? "#395d60"
                : root.primary ? "#28544e" : root.hovered ? Theme.panelRaised : "#1a2b30"
            border.color: root.activeFocus ? Theme.accent : root.primary ? Theme.actionGreen : Theme.hudBorder
            radius: 2
            Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: 100 } }
            Rectangle { x:1;y:1;width:3;height:parent.height-2;visible:root.primary;color:Theme.accent }
        }
        // 240×80原图的边线不能随按钮总宽拉伸，否则长按钮两侧比上下边厚。
        // 8px原圆角按半尺寸保留，只有中段伸缩；原图／状态／颜色都继续复用。
        Item {
            visible: !root.laboratory
            width: parent.width * 2
            height: parent.height * 2
            scale: 0.5
            transformOrigin: Item.TopLeft
            BorderImage {
                id: buttonImage
                anchors.fill: parent
                source: root.laboratory ? "" : "../resources/engine-137/sprites/ServerUI_Button"
                        + (root.primary ? "Green" : "Light")
                        + (root.down ? "Pressed" : !root.enabled ? "Disabled"
                           : root.hovered ? "Highlighted" : "Normal") + ".png"
                border { left: root.imageBorder; right: root.imageBorder; top: root.imageBorder; bottom: root.imageBorder }
                smooth: true
            }
        }
        // 软件后端在分数缩放时可能漏掉任一末边；直边由实心项补足，圆角仍用原图。
        Item {
            anchors.fill: parent
            visible: !root.primary && !root.laboratory
            Rectangle { x: root.edgeInset; width: Math.max(0, parent.width - root.edgeInset * 2); height: root.edgeThickness; color: root.edgeColor }
            Rectangle { x: root.edgeInset; y: parent.height - height; width: Math.max(0, parent.width - root.edgeInset * 2); height: root.edgeThickness; color: root.edgeColor }
            Rectangle { y: root.edgeInset; width: root.edgeThickness; height: Math.max(0, parent.height - root.edgeInset * 2); color: root.edgeColor }
            Rectangle { x: parent.width - width; y: root.edgeInset; width: root.edgeThickness; height: Math.max(0, parent.height - root.edgeInset * 2); color: root.edgeColor }
        }
        Item {
            anchors.fill: parent
            anchors.margins: -root.focusMargin
            visible: root.activeFocus
            OperatorOutline { color: root.focusColor; emphasized: true }
        }
    }
}
