import QtQuick
import QtQuick.Controls
import QtQuick.Window

TextField {
    id:root
    font.family:Theme.fontFamily
    font.pixelSize:Math.max(14,9.5/Math.max(.1,Window.window?.ui?.layoutScale??1))
    color:Theme.text
    placeholderTextColor:Theme.muted
    palette.base:Theme.hudSolid;palette.text:Theme.text;palette.highlight:Theme.actionGreen;palette.highlightedText:Theme.text
    implicitHeight:40
    background:Rectangle {color:Theme.hudSolid;radius:2;border.width:root.activeFocus?2:1;border.color:root.activeFocus?Theme.accent:Theme.hudBorder}
}
