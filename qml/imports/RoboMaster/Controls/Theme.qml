pragma Singleton
import QtQuick
import "../../../components" as Internal

// Public values forward to the actual HUD theme; fonts and textures remain
// owned by the UI pack instead of being copied into every community package.
QtObject {
    readonly property string fontFamily: Internal.Theme.fontFamily
    readonly property string numberFamily: Internal.Theme.numberFamily
    readonly property string rosterNumberFamily: Internal.Theme.rosterNumberFamily
    readonly property string keyFontFamily: Internal.Theme.keyFontFamily
    readonly property color text: Internal.Theme.text
    readonly property color muted: Internal.Theme.muted
    readonly property color red: Internal.Theme.red
    readonly property color blue: Internal.Theme.blue
    readonly property color green: Internal.Theme.green
    readonly property color warning: Internal.Theme.warning
    readonly property color panel: Internal.Theme.panel
    readonly property color line: Internal.Theme.line
    readonly property color background: Internal.Theme.background
    readonly property color hudSurface: Internal.Theme.hudSurface
    readonly property color hudSolid: Internal.Theme.hudSolid
    readonly property color hudBorder: Internal.Theme.hudBorder
    readonly property color hudHover: Internal.Theme.hudHover
    readonly property real hudGap: Internal.Theme.hudGap
    function hudStroke(scale, emphasized) {
        return Internal.Theme.hudStroke(scale, emphasized);
    }
}
