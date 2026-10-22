import QtQuick

// 官方小方向点沿机器人外缘移动；编号不旋转，缺失角度不补成朝北。
Item {
    id: root
    property var angle: null
    property string dataState: "missing"
    property string team: "self"
    property bool clockwise: true
    readonly property bool valid: typeof angle === "number" && Number.isFinite(angle)
                                 && (dataState === "fresh" || dataState === "stale")
    visible: valid
    opacity: dataState === "fresh" ? 1 : 0.45
    rotation: valid ? (clockwise ? 1 : -1) * ((angle % 360 + 360) % 360) : 0
    Behavior on rotation {
        enabled: root.valid && root.dataState === "fresh"
        RotationAnimation { duration: Theme.reducedMotion ? 0 : 160; direction: RotationAnimation.Shortest }
    }
    Image {
        width: Math.max(6, parent.width * 0.28)
        height: width
        x: (parent.width - width) / 2
        y: -height * 0.75
        source: "../resources/player/minimap/" + root.team + "_map_arrow.png"
        fillMode:Image.PreserveAspectFit
        mipmap: true
    }
}
