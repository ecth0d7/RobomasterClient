import QtQuick
import QtQuick.Window

// 同一标题区的齿轮、角色图标和关闭图标共享可见尺寸；静态图标不伪装成按钮。
Item {
    id: root
    property string asset: ""
    property url imageSource: ""
    readonly property real hudScale: Window.window?.ui?.layoutScale ?? 1
    property real glyphSize: Math.max(18, 11 / Math.max(0.1, hudScale))
    property real glyphMargin: 4
    property alias source: glyphImage.source
    property alias sourceClipRect: glyphImage.sourceClipRect
    property alias fillMode: glyphImage.fillMode
    property alias glyphOpacity: glyphImage.opacity
    implicitWidth: 32
    implicitHeight: 32
    Accessible.ignored: true
    function visibleBounds() {
        if (asset === "ServerUI_Setting") return Qt.rect(2, 2, 42, 42);
        if (asset === "ServerUI_RobotClose") return Qt.rect(2, 2, 30, 30);
        const path = imageSource.toString();
        // 原哨兵符号带较宽低透明辉光；按主体留距显示，不能缩成一个小点。
        if (path.endsWith("_guard_avatar.png")) return Qt.rect(8, 8, 32, 32);
        if (path.endsWith("tab_icon_silo.png")) return Qt.rect(2, 2, 52, 52);
        if (path.endsWith("validate_icon_rune.png")) return Qt.rect(2, 2, 48, 56);
        return Qt.rect(0, 0, 0, 0);
    }
    Image {
        id: glyphImage
        anchors.centerIn: parent
        width: Math.min(parent.width - root.glyphMargin * 2, root.glyphSize)
        height: width
        source: root.asset.length ? "../resources/engine-137/sprites/" + root.asset + ".png" : root.imageSource
        // 按可见主体归一，而非仅让不同透明画布同宽；原位图不修改。
        sourceClipRect: root.visibleBounds()
        fillMode: Image.PreserveAspectFit
        mipmap: true
        opacity: 0.9
    }
}
