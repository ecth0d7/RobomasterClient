import QtQuick
import QtQuick.Controls
import QtQuick.Window

// 来源字符串只作纯文字；限制外部元数据气泡的宽度和行数，完整记录仍在可访问名称中。
ToolTip {
    id: root
    readonly property var hostWindow: parent?.Window.window ?? null
    readonly property real hudScale: hostWindow?.ui?.layoutScale ?? 1
    delay: 450
    padding: 10
    width: Math.min(560,Math.max(240,(hostWindow?.width ?? 560)/Math.max(0.1,hudScale)-32))
    contentItem: Text {
        text: root.text
        textFormat: Text.PlainText
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 20
        elide: Text.ElideRight
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(11,10/Math.max(0.1,root.hudScale))
    }
    background: Rectangle {
        color: Theme.hudSolid
        OperatorOutline {color:Theme.hudBorder}
    }
}
