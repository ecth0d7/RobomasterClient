pragma Singleton
import QtQuick
import QtCore

QtObject {
    property Settings presentation: Settings {
        category: "Presentation"
        location: StandardPaths.writableLocation(StandardPaths.AppConfigLocation) + "/presentation.ini"
        property bool reducedMotion: false
        property bool startupAnimationEnabled: true
    }
    readonly property bool startupAnimationEnabled: presentation.startupAnimationEnabled
    function setStartupAnimationEnabled(value) { presentation.startupAnimationEnabled = value; }
    readonly property bool reducedMotion: presentation.reducedMotion
    function setReducedMotion(value) { presentation.reducedMotion = value; }
    readonly property int mapSignalHoldMs: 250
    readonly property int transitionMs: reducedMotion ? 0 : 140
    readonly property color accent: "#94d9c0"
    readonly property color panelRaised: "#203238"
    // 字体随 UI 包分发，换电脑时不依赖操作系统已安装的中文字体。
    property FontLoader chineseFont: FontLoader {
        source: "../resources/fonts/NotoSansCJK-Regular.ttc"
    }
    property FontLoader numberFont: FontLoader {
        source: "../resources/fonts/DejaVuSansMono.ttf"
    }
    property FontLoader rosterNumberFont: FontLoader {
        source: "../resources/fonts/DejaVuSansMono-Bold.ttf"
    }
    property FontLoader keyFont: FontLoader {
        source: "../resources/fonts/DejaVuSansCondensed.ttf"
    }
    readonly property string fontFamily: chineseFont.name
    readonly property string numberFamily: numberFont.name
    readonly property string rosterNumberFamily: rosterNumberFont.name
    readonly property string keyFontFamily: keyFont.name
    readonly property color text: "#e5eeec"
    readonly property color muted: "#a8bbb9"
    readonly property color red: "#fc5447"
    readonly property color blue: "#33b7e7"
    readonly property color green: "#94d9c0"
    readonly property color actionGreen: "#4daf99"
    readonly property color warning: "#f4df6a"
    readonly property color panel: "#eb182428"
    readonly property color line: "#66465d64"
    // 无图传时的中性暗底；不叠加到真实视频，红蓝官方贴图保持原色。
    readonly property color background: "#1a272b"
    readonly property color videoBackground: "#000000"
    // 视频上的常驻提示共用轻透底，只给背景着色，文字、图标与状态条保持清晰。
    readonly property color hudSurface: "#70162226"
    readonly property color hudSolid: "#172429"
    readonly property color hudBorder: "#4b6870"
    readonly property color hudHover: "#b0274147"
    readonly property real hudGap: 16
    function hudStroke(scale, emphasized) {
        // 逻辑 1px 缩至物理 <1px 时软件后端会丢边；保持至少一个完整物理像素。
        return (emphasized ? 2 : 1) / Math.min(1, Math.max(0.1, scale));
    }
}
