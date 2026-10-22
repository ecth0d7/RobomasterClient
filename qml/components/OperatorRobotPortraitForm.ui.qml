import QtQuick 2.15

// 左下角真实头像绘制层：Designer与运行HUD使用同一个文件及原始贴图。
Item {
    id: root
    property int clientID: 3
    property real assetScale: 1
    property bool defeated: false
    readonly property bool blue: root.clientID > 100
    readonly property bool separateSentryFace: root.clientID % 100 === 7
    readonly property bool emptyFace: root.clientID % 100 < 1
                                      || root.clientID % 100 > 7
    property string portraitOverrideSource: ""
    // 与正式角色选择共用同一表达式；Designer切换身份也能看到对应阵营／角色原图。
    property url rolePortraitSource: root.clientID % 100 === 7 ? "../resources/player/top_robots/" + (root.blue ? "blue" : "red") + "_tab_guard.png" : "../resources/player/my_robot/" + (root.blue ? "blue" : "red") + (root.clientID % 100 === 6 ? "_airplane_statusbar_avatar.png" : "_statusbar_avatar_" + (root.clientID % 100 === 1 ? "hero" : root.clientID % 100 === 2 ? "enginner" : root.emptyFace ? "empty" : "infantry") + ".png")
    property url portraitSource: root.portraitOverrideSource
                                 != "" ? root.portraitOverrideSource : root.rolePortraitSource
    implicitWidth: 159 * root.assetScale
    implicitHeight: 134 * root.assetScale
    width: root.implicitWidth
    height: root.implicitHeight

    Image {
        id: emptyPlate
        x: 2 * root.assetScale
        y: 7 * root.assetScale
        width: 157 * root.assetScale
        height: 127 * root.assetScale
        source: "../resources/player/my_robot/" + (root.blue ? "blue" : "red")
                + "_statusbar_avatar_empty.png"
        visible: root.separateSentryFace || root.emptyFace
        fillMode: Image.PreserveAspectFit
        mipmap: true
        opacity: root.defeated ? 0.4 : 1
        Accessible.ignored: true
    }
    Image {
        x: 30 * root.assetScale
        y: 28 * root.assetScale
        width: 80 * root.assetScale
        height: 80 * root.assetScale
        visible: root.clientID % 100 === 8
        source: "../resources/player/silo/tab_icon_silo.png"
        fillMode: Image.PreserveAspectFit
        mipmap: true
        Accessible.ignored: true
    }
    OperatorRadarGlyph {
        id: radarGlyph
        x: 17.5 * root.assetScale
        y: 21 * root.assetScale
        width: 104 * root.assetScale
        height: 104 * root.assetScale
        visible: root.clientID % 100 === 9
        accent: root.blue ? Theme.blue : Theme.red
    }

    Image {
        id: portraitImage
        x: (root.separateSentryFace ? 7.5 : 2) * root.assetScale
        y: (root.separateSentryFace ? 11 : 0) * root.assetScale
        width: (root.separateSentryFace ? 124 : 157) * root.assetScale
        height: (root.separateSentryFace ? 124 : 134) * root.assetScale
        opacity: root.defeated ? 0.4 : 1
        visible: !root.emptyFace
        source: root.portraitSource
        mipmap: true
        fillMode: Image.PreserveAspectFit
        Accessible.ignored: true
    }
}
