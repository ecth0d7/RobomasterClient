pragma Singleton

import QtQuick 6.5

// 英雄客户端统一视觉令牌。液态玻璃使用透明叠层模拟，兼容 Software 场景图。
QtObject {
    readonly property color background: "#03070d"
    readonly property color panel: "#a8142735"
    readonly property color panelSoft: "#8f182d3d"
    readonly property color shadow: "#70000000"
    readonly property color border: "#8cb9d3e3"
    readonly property color borderSoft: "#527993a6"

    // 由亮到暗的三层透明色构成玻璃体；innerHighlight 是内侧反光边。
    readonly property color glassTop: "#784f7188"
    readonly property color glassMiddle: "#7a1b3548"
    readonly property color glassBottom: "#a30a1824"
    readonly property color glassInnerHighlight: "#5cffffff"
    readonly property color glassEdgeDark: "#5011212d"
    readonly property color glassSpecular: "#90dff6ff"
    readonly property color glassButton: "#70304e62"
    readonly property color glassButtonHover: "#a044718e"

    readonly property color textPrimary: "#f4f8fa"
    readonly property color textSecondary: "#c0d0da"
    readonly property color textMuted: "#8299a8"

    readonly property color accent: "#63c8f0"
    readonly property color accentDeep: "#1c6788"
    readonly property color success: "#62e4a2"
    readonly property color successDeep: "#205c45"
    readonly property color warning: "#f0b85e"
    readonly property color danger: "#ff7187"
    readonly property color dangerDeep: "#6d2939"

    readonly property int radiusSmall: 12
    readonly property int radiusPanel: 18
    readonly property int spacingSmall: 8
    readonly property int spacingNormal: 12
    readonly property int panelPadding: 14

    readonly property int motionFast: 90
    readonly property int motionNormal: 180
}
