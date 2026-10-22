import QtQuick
import QtQuick.Shapes

// 原创静态角色符号：只表示雷达身份，不包含目标、坐标或虚构扫描结果。
Item {
    id: root
    property color accent: Theme.muted
    implicitWidth: 60
    implicitHeight: 60
    Accessible.ignored: true
    Item {
        anchors.centerIn: parent
        width: 60
        height: 60
        scale: Math.min(root.width, root.height) / 60
        Repeater {
            model: [54, 34, 14]
            Rectangle {
                required property int modelData
                anchors.centerIn: parent
                width: modelData
                height: width
                radius: width / 2
                color: "transparent"
                border.color: root.accent
                border.width: 1
                opacity: modelData === 54 ? 1 : 0.55
            }
        }
        Rectangle { x: 30; y: 3; width: 1; height: 54; color: root.accent; opacity: 0.35 }
        Rectangle { x: 3; y: 30; width: 54; height: 1; color: root.accent; opacity: 0.35 }
        Shape {
            anchors.fill: parent
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.accent
                strokeWidth: 2
                startX: 30; startY: 30
                PathLine { x: 48; y: 11 }
            }
        }
    }
}
