import QtQuick
import QtQuick.Window
import "OperatorData.js" as Data

Item {
    id: root
    readonly property bool presentationActive: visible && (!root.Window.window
        || root.Window.window.visible && root.Window.window.visibility !== Window.Minimized)
    property var value: null
    property var maximum: null
    property string valueText: "—"
    property string dataState: "missing"
    property string maximumState: "fresh"
    property bool blue: false
    property bool outpost: false
    property bool ownRobot: false
    property bool animate: true
    property bool slantedEnds: false
    property real leftInsetTop: 0
    property real leftInsetBottom: 0
    readonly property bool clippedLeft: leftInsetTop > 0 || leftInsetBottom > 0
    property var statusValue: null
    property string statusState: "missing"
    property var shieldValue: null
    property string shieldState: "missing"
    readonly property bool invulnerable: !useOwnAssets && statusState === "fresh" && statusValue === 0
                                        && dataState === "fresh" && typeof value === "number" && value > 0
    readonly property bool baseLow: !useOwnAssets && fillFresh && fillFraction > 0 && fillFraction < 0.2
    readonly property bool fillFresh: dataState === "fresh" && maximumState === "fresh"
    readonly property real fillFraction: dataState === "missing" || maximumState === "missing" ? 0 : Data.fraction(value, maximum)
    property real displayedFraction: fillFraction
    property real trailFraction: fillFraction
    // 只对比例做动画；窗口变宽时按新宽度立即排版，不能把缩放误画成扣血。
    Behavior on displayedFraction {
        enabled: root.animate && root.fillFresh
        NumberAnimation { duration: Theme.reducedMotion ? 0 : 240; easing.type: Easing.OutCubic }
    }
    Behavior on trailFraction {
        enabled: root.animate && root.fillFresh && !root.useOwnAssets
        NumberAnimation { duration: Theme.reducedMotion ? 0 : 800; easing.type: Easing.OutCubic }
    }
    readonly property string team: blue ? "blue" : "red"
    readonly property bool useOwnAssets: ownRobot || outpost
    property string directory: "../resources/player/"
                                       + (useOwnAssets ? "my_robot/" : team + "_base_blood/")
    property string prefix: team + (useOwnAssets ? "_statusbar_blood_" : "_base_blood_")
    property url backgroundSource: directory + prefix + (useOwnAssets ? "background" : "bottom") + ".png"
    property rect backgroundBody: slantedEnds ? Qt.rect(360,blue ? 20 : 2,80,68)
        : useOwnAssets ? Qt.rect(2,2,357,40)
        : blue ? Qt.rect(0,20,835,68) : Qt.rect(2,2,835,68)
    property real frameSlant: slantedEnds ? height * 0.5 : useOwnAssets ? width*20/357 : width*34/835
    implicitWidth: outpost ? 150 : 360
    implicitHeight: 32
    // 每组纹理的高光也留在本组件内；邻近肖像和队徽不承担裁剪边界。
    clip: true

    Image {
        anchors.fill: parent
        visible: !root.clippedLeft && !root.slantedEnds
        source: root.backgroundSource
        // 蓝方基地的画布为 880×104，条体从 y=20 开始；红方只有 837×72。
        // 按可见主体归一后再排版，两侧空条与满条共用同一高度和基线。
        sourceClipRect: root.backgroundBody
        fillMode: Image.Stretch
        mipmap: true
        opacity: root.fillFresh ? 0.9 : 0.45
    }
    OperatorSlantedFill {
        anchors.fill: parent
        visible: root.clippedLeft || root.slantedEnds
        source: root.backgroundSource
        sourceClipRect: root.backgroundBody
        fraction: 1
        slantWidth: root.slantedEnds ? root.frameSlant : 0
        slantFixedEnd: root.slantedEnds
        anchorRight: root.slantedEnds && !root.blue
        leftInsetTop: root.leftInsetTop
        leftInsetBottom: root.leftInsetBottom
        opacity: root.fillFresh ? 0.9 : 0.45
    }
    OperatorSlantedFill {
        anchors.fill: parent
        source: root.useOwnAssets ? root.directory + root.prefix
            + (root.fillFraction > 0 && root.fillFraction <= 0.2 ? "slid_low" : "slid") + ".png" : ""
        // 原填充实体为(10,12,360,40)，取内部无透明斜端的材质直段，轮廓由原底槽限制。
        sourceClipRect: Qt.rect(20,12,320,40)
        maskSource: root.backgroundSource
        maskClipRect: root.backgroundBody
        slantWidth: root.frameSlant
        leftInsetTop: root.leftInsetTop
        leftInsetBottom: root.leftInsetBottom
        fraction: root.displayedFraction
        visible: root.useOwnAssets && root.dataState !== "missing" && root.maximumState !== "missing"
            && typeof root.value === "number" && root.value > 0 && root.displayedFraction > 0
        opacity: root.fillFresh ? 0.9 : 0.35
    }
    OperatorSlantedFill {
        anchors.fill: parent
        visible: !root.useOwnAssets && root.fillFresh && typeof root.value === "number" && root.value > 0
            && root.trailFraction > root.displayedFraction + 0.002
        source: root.useOwnAssets ? "" : root.directory + root.prefix + "top_full.png"
        sourceClipRect: root.slantedEnds ? Qt.rect(360,8,80,68) : Qt.rect(0,8,840,68)
        maskSource: root.slantedEnds ? "" : root.backgroundSource
        maskClipRect: root.backgroundBody
        slantWidth: root.frameSlant
        fraction: root.trailFraction
        anchorRight: !root.blue
        slantFixedEnd: root.slantedEnds
        opacity: 0.5
    }
    OperatorSlantedFill {
        id: baseFill
        anchors.fill: parent
        visible: !root.useOwnAssets && root.dataState !== "missing"
            && typeof root.value === "number" && root.value > 0 && root.displayedFraction > 0
        source: root.useOwnAssets ? "" : root.directory + root.prefix + (root.baseLow ? "middle_lowhp_0.png" : "top.png")
        sourceClipRect: root.baseLow ? Qt.rect(root.slantedEnds ? 360 : 0,10,root.slantedEnds ? 80 : 840,64)
            : Qt.rect(root.slantedEnds ? 360 : 0,8,root.slantedEnds ? 80 : 840,68)
        maskSource: root.slantedEnds ? "" : root.backgroundSource
        maskClipRect: root.backgroundBody
        slantWidth: root.frameSlant
        fraction: root.displayedFraction
        anchorRight: !root.blue
        slantFixedEnd: root.slantedEnds
        property real pulseOpacity: 0.9
        // 闪烁只写独立因子；不能手工写opacity而解除新鲜度绑定，导致恢复后仍偏暗。
        opacity: root.fillFresh ? (root.baseLow ? pulseOpacity : 0.9) : 0.35
        SequentialAnimation on pulseOpacity {
            running: root.presentationActive && baseFill.visible && root.baseLow && !Theme.reducedMotion
            loops: Animation.Infinite
            onRunningChanged: if (!running) baseFill.pulseOpacity = 0.9
            NumberAnimation { to: 0.5; duration: 650 }
            NumberAnimation { to: 0.9; duration: 650 }
        }
    }
    OperatorBaseShield {
        anchors.fill: parent
        // 护盾与生命共用HP尺度；不假定独立护盾上限，也不把旧护盾当有效段。
        visible: !root.useOwnAssets && root.fillFresh && root.shieldState === "fresh"
            && typeof root.shieldValue === "number" && root.shieldValue > 0
            && typeof root.value === "number" && root.value > 0
        fraction: Data.fraction(root.shieldValue, root.maximum)
        blue: root.blue
        slantedEnds: root.slantedEnds
        opacity: 0.8
    }
    OperatorSlantedFill {
        anchors.fill: parent
        visible: root.invulnerable
        source: root.useOwnAssets ? "" : root.directory + root.prefix + "invincible.png"
        // 金边红图左侧有44px透明画布；两侧按实际条体统一，不能直接拉伸整图。
        sourceClipRect: Qt.rect(root.blue ? 0 : 44, 18, 836, 68)
        fraction: 1
        slantWidth: root.slantedEnds ? root.frameSlant : 0
        slantFixedEnd: root.slantedEnds
        anchorRight: !root.blue
        opacity: 0.85
    }
    OperatorText {
        id: healthValueText
        anchors.fill: parent
        anchors.leftMargin: root.clippedLeft ? Math.max(root.leftInsetTop,root.leftInsetBottom)+8
            : root.slantedEnds ? root.frameSlant + 8 : 18
        anchors.rightMargin: root.useOwnAssets && (root.dataState === "stale" || root.maximumState === "stale") ? 38 : 18
        text: root.valueText
        numeric: true
        size: root.outpost ? 14 : root.ownRobot ? Math.min(24, root.height * 0.48) : 23
        clip: true
        font.bold: true
        horizontalAlignment: root.useOwnAssets ? Text.AlignHCenter : root.blue ? Text.AlignRight : Text.AlignLeft
        color: root.dataState === "fresh" ? Theme.text : Theme.muted
    }
    OperatorText {
        x: root.useOwnAssets ? root.width - width - 6
            : root.blue ? Math.max(0, healthValueText.x + healthValueText.width - healthValueText.contentWidth - 8 - width)
                        : Math.min(root.width - width, healthValueText.x + healthValueText.contentWidth + 8)
        width: 24
        height: 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.dataState === "stale" || root.maximumState === "stale"
        text: root.dataState !== "stale" && root.maximumState === "stale" ? "限旧" : "旧"
        size: 10
        color: Theme.warning
    }
}
