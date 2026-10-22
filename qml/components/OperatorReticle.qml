import QtQuick
import QtQuick.Window
import QtQuick.Effects
import "OperatorData.js" as Data
import "OperatorLocalCombatData.js" as LocalCombat

Item {
    id: root
    property var telemetry: null
    property int clientID: 0
    property bool connectedToPlayer: false
    property bool previewOnly: false
    property var projectionItems: []
    property double drawingNow: Date.now()
    readonly property bool shootingRole: [1,3,4,5,6,7].includes(clientID%100)
    readonly property var localCombat: connectedToPlayer ? LocalCombat.view(projectionItems,clientID,drawingNow,false) : null
    readonly property var lockSeconds: localCombat?.shooter_lock_remaining_seconds ?? null
    readonly property bool localShooterLocked: shootingRole && typeof lockSeconds==="number" && lockSeconds>0
    readonly property bool overspeedPenalty: shootingRole && connectedToPlayer
        && ["penalty_type","penalty_effect_sec","total_penalty_num"].every(key=>Data.state(telemetry,"penalty",key)==="fresh")
        && telemetry?.penalty?.penalty_type===6 && telemetry.penalty.total_penalty_num>0 && telemetry.penalty.penalty_effect_sec>0
    readonly property bool shooterWarning: localShooterLocked || overspeedPenalty
    property real topExclusionHeight: 0
    property real rightDockLeft: -1
    property real rightDockTop: -1
    property alias shootingReadingsObject: shootingReadings
    readonly property var dynamics: telemetry?.robotDynamic ?? ({})
    readonly property var statics: telemetry?.robotStatic ?? ({})
    readonly property real heatFraction: Data.fraction(dynamics.current_heat, statics.max_heat)
    readonly property bool heatFresh: (connectedToPlayer || previewOnly) && shootingRole
        && Data.state(telemetry,"robotStatic","robot_id")==="fresh" && statics.robot_id===clientID
        && Data.state(telemetry, "robotDynamic", "current_heat") === "fresh" && Data.state(telemetry, "robotStatic", "max_heat") === "fresh"
        && typeof dynamics.current_heat==="number" && Number.isFinite(dynamics.current_heat) && dynamics.current_heat>=0
        && Number.isInteger(statics.max_heat) && statics.max_heat>0
    readonly property bool ammoFresh: Data.state(telemetry, "robotDynamic", "remaining_ammo") === "fresh"
    readonly property string heatTone: heatFraction >= 0.75 ? "red" : heatFraction >= 0.5 ? "yellow" : "white"
    readonly property bool overheated: heatFresh && heatFraction >= 1
    width: 660
    height: 660
    onProjectionItemsChanged: drawingNow=Date.now()
    Timer {interval:250;repeat:true;running:root.visible && root.projectionItems.length>0;onTriggered:root.drawingNow=Date.now()}

    // 独立外弧保持原始比例；整图已有水平线，无需再叠加自绘线段。
    Image {
        anchors.centerIn: parent
        width: root.width
        height: width * 1084 / 1608
        source: "../resources/player/crosshair/crosshair_bg_single.png"
        fillMode: Image.PreserveAspectFit
        mipmap: true
        opacity: 0.65
    }
    Image {
        anchors.centerIn: parent
        width: 136
        height: 136
        objectName: "heatRingFrame"
        visible: root.shootingRole
        source: "../resources/player/crosshair/crosshair_slid_circle_bg.png"
        fillMode: Image.PreserveAspectFit
        mipmap: true
        opacity: 0.45
    }
    Item {
        id: heatArc
        objectName: "heatRing"
        anchors.centerIn: parent
        width: 136
        height: 136
        visible: root.heatFresh && root.heatFraction > 0
        property real displayedFraction: root.heatFraction
        property url texture: "../resources/player/crosshair/crosshair_slid_circle_" + root.heatTone + ".png"
        property int textureInset: root.heatTone === "white" ? 12 : 13
        onDisplayedFractionChanged: ringDrawing.requestPaint()
        onTextureChanged: ringDrawing.refreshImage()
        Behavior on displayedFraction {
            enabled: root.heatFresh
            NumberAnimation { duration: Theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic }
        }
        Canvas {
            id: ringDrawing
            width: heatArc.width * 4; height: heatArc.height * 4
            scale: 0.25; transformOrigin: Item.TopLeft
            property url loadedSource: ""
            function refreshImage() {
                if (!available) return;
                if (loadedSource.toString() && loadedSource !== heatArc.texture) unloadImage(loadedSource);
                loadedSource=heatArc.texture;
                loadImage(loadedSource);requestPaint();
            }
            onAvailableChanged: if(available) refreshImage()
            onImageLoaded: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const c=getContext("2d");c.reset();
                if (!isImageLoaded(heatArc.texture) || heatArc.displayedFraction <= 0) return;
                // 底环168×168：主体径向范围72..80；原彩色环192/194画布先居中裁齐。
                // 同一环带／扇区限制原纹理，替代外扩的R39、4px自绘描边。
                c.scale(4*heatArc.width/168,4*heatArc.height/168);
                const start=-Math.PI/2,end=start+2*Math.PI*Math.min(1,heatArc.displayedFraction);
                c.beginPath();c.arc(84,84,80,start,end,false);
                c.arc(84,84,72,end,start,true);c.closePath();c.clip();
                c.drawImage(heatArc.texture,heatArc.textureInset,heatArc.textureInset,168,168,0,0,168,168);
            }
        }
    }
    Image {
        id: crosshair
        anchors.centerIn: parent
        width: Math.max(35, 28 / (Window.window?.ui?.layoutScale ?? 1))
        height: width
        z: 10
        visible: !root.overheated
        source: "../resources/player/crosshair/crosshair_middle.png"
        fillMode: Image.PreserveAspectFit
        mipmap: true
    }
    MultiEffect {
        anchors.fill:crosshair
        source:crosshair
        visible:root.shooterWarning && !root.overheated
        colorization:1
        colorizationColor:Theme.red
        z:11
    }
    Rectangle {
        id: shootingReadings
        visible: root.shootingRole
        // 右下地图／键鼠区始终预留同一槽位；隐藏输入或新建议不改变间距。
        x: root.rightDockLeft >= 0 && root.rightDockTop >= 0
           && root.y + y + height + Theme.hudGap > root.rightDockTop
           ? Math.min(root.width - 8, root.rightDockLeft - root.x - width - Theme.hudGap)
           : root.width - 8
        // 为右上信息保留间距；预留量只随视口比例变化，不随建议更新跳动。
        y: Math.max((root.height - height) / 2, root.topExclusionHeight - root.y)
        width: 74
        height: 108
        color: "transparent"
        Column {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 1
            OperatorText { width: parent.width; height: 17; text: "射击初速度"; size: 10; minimumSize: 0; fontSizeMode: Text.Fit; minimumPixelSize: 8; horizontalAlignment: Text.AlignHCenter }
            OperatorText { width: parent.width; height: 25; text: Data.text(root.telemetry, "robotDynamic", "last_projectile_fire_rate", 1) + (Data.state(root.telemetry, "robotDynamic", "last_projectile_fire_rate") === "stale" ? "旧" : ""); numeric: true; size: 18; color: Data.state(root.telemetry, "robotDynamic", "last_projectile_fire_rate") === "fresh" ? Theme.text : Theme.muted; horizontalAlignment: Text.AlignHCenter }
            OperatorText { width: parent.width; height: 17; text: "允许发弹量"; size: 10; minimumSize: 0; fontSizeMode: Text.Fit; minimumPixelSize: 8; horizontalAlignment: Text.AlignHCenter }
            OperatorText { width: parent.width; height: 25; text: Data.text(root.telemetry, "robotDynamic", "remaining_ammo") + (Data.state(root.telemetry, "robotDynamic", "remaining_ammo") === "stale" ? "旧" : ""); numeric: true; size: 18; color: !root.ammoFresh ? Theme.muted : root.dynamics.remaining_ammo === 0 ? Theme.red : Theme.text; horizontalAlignment: Text.AlignHCenter }
        }
    }
    OperatorText {
        objectName:"overheatCaption"
        anchors.centerIn: heatArc
        width: 76
        height: 24
        visible: root.overheated
        text: "热量超限"
        color: Theme.red
        horizontalAlignment: Text.AlignHCenter
        size: 12
    }
    OperatorText {
        objectName:"shooterLockCaption"
        x:heatArc.x+(heatArc.width-width)/2;y:heatArc.y+heatArc.height+10
        width:280;height:26
        visible:root.shooterWarning
        text:root.localShooterLocked ? "已超限，锁定 "+root.lockSeconds+"s" : "超射速判罚"
        size:12;color:Theme.red;horizontalAlignment:Text.AlignHCenter
    }
}
