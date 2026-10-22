import QtQuick
import QtQuick.Window

// 软件后端在分数缩放下可能丢失 Rectangle 的水平细边。
// 四条实心边保持相同物理宽度；只画框体，不承载输入或数据。
Item {
    id: root
    property color color: Theme.hudBorder
    property bool emphasized: false
    readonly property real hudScale: Window.window?.ui?.layoutScale ?? 1
    property real thickness: Theme.hudStroke(hudScale, emphasized)
    anchors.fill: parent
    Accessible.ignored: true
    Rectangle { width: parent.width; height: root.thickness; color: root.color }
    Rectangle { y: parent.height - height; width: parent.width; height: root.thickness; color: root.color }
    Rectangle { width: root.thickness; height: parent.height; color: root.color }
    Rectangle { x: parent.width - width; width: root.thickness; height: parent.height; color: root.color }
}
