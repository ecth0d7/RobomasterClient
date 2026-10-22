import QtQuick
import QtQuick.Controls

ScrollView {
    id: root
    default property alias entries: contents.data
    property real entrySpacing: 12
    property real contentRightInset: 16
    property real scrollBarWidth: 8
    property real scrollThumbWidth: 6
    property real scrollRadius: 3
    property color scrollTrackColor: "#14201a"
    property color scrollThumbColor: Theme.muted
    property color scrollPressedColor: Theme.text
    clip: true
    contentWidth: availableWidth
    contentHeight: contents.implicitHeight
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical: ScrollBar {
        id: bar
        parent: root
        x: root.width - width
        y: 0
        width: root.scrollBarWidth
        height: root.height
        minimumSize: 0.12
        policy: root.contentHeight > root.availableHeight ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        background: Rectangle { color: root.scrollTrackColor; radius: root.scrollRadius }
        contentItem: Rectangle {
            implicitWidth: root.scrollThumbWidth
            implicitHeight: 40
            radius: root.scrollRadius
            color: bar.pressed ? root.scrollPressedColor : root.scrollThumbColor
            opacity: bar.active ? 0.9 : 0.6
        }
    }
    Column {
        id: contents
        width: root.availableWidth - root.contentRightInset
        spacing: root.entrySpacing
    }
}
