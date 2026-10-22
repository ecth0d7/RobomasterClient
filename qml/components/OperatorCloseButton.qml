import QtQuick
import QtQuick.Controls
import QtQuick.Window

// 全部辅助面板共用安静的关闭控件；热区与图标分开，不让叉号贴在框体边缘。
Button {
    id: root
    property string closeLabel: "关闭面板"
    readonly property real hudScale: Window.window?.ui?.layoutScale ?? 1
    property alias glyphAsset: closeGlyph.asset
    property alias glyphSource: closeGlyph.source
    property alias glyphSize: closeGlyph.glyphSize
    property alias glyphClipRect: closeGlyph.sourceClipRect
    property real disabledOpacity: 0.4
    property real cornerRadius: 3
    property color backgroundColor: "transparent"
    property color hoverColor: Theme.hudHover
    property color borderColor: Theme.line
    property color hoverBorderColor: Theme.hudBorder
    property color focusBorderColor: Theme.green
    property alias borderWidth: closeOutline.thickness
    implicitWidth: 32
    implicitHeight: 32
    padding: 0
    focusPolicy: Qt.StrongFocus
    activeFocusOnTab: true
    Accessible.name: closeLabel
    ToolTip.visible: hovered
    ToolTip.delay: 450
    ToolTip.text: closeLabel
    contentItem: OperatorPanelGlyph {
        id: closeGlyph
        asset: "ServerUI_RobotClose"
        opacity: root.enabled ? 1 : root.disabledOpacity
    }
    background: Rectangle {
        radius: root.cornerRadius
        color: root.down || root.hovered ? root.hoverColor : root.backgroundColor
        OperatorOutline {
            id: closeOutline
            visible: root.activeFocus || root.hovered
            color: root.activeFocus ? root.focusBorderColor : root.hovered ? root.hoverBorderColor : root.borderColor
            emphasized: root.activeFocus
        }
    }
}
