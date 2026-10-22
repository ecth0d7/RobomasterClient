import QtQuick
import QtQuick.Controls
import "OperatorData.js" as Data

// 七月手册页03：独立前哨板，标签／图标在血条上方，不能套用自身机器人血槽。
Item {
    id: root
    property bool blue: false
    property var value: null
    property real maximum: 1500
    property string valueText: "—"
    property string dataState: "missing"
    property var statusValue: null
    property string statusState: "missing"
    property var rebuildProjection: null
    property var defenseProjection: null
    property real heightBudget: 0
    readonly property bool rebuilding: statusState === "fresh" && statusValue === 5 && !conflict
        && rebuildProjection !== null && ["team_progress","robot_progress","remaining_count"]
            .some(key => rebuildProjection[key + "_state"] !== "missing")
    readonly property bool hasDefensePercent: defenseProjection?.state === "fresh"
        && defenseProjection?.defense_percent_state === "fresh" && !destroyed && !conflict
    readonly property bool destroyed: dataState === "fresh" && value === 0
    readonly property bool invulnerable: dataState === "fresh" && typeof value === "number" && value > 0
                                        && statusState === "fresh" && statusValue === 0
    readonly property bool conflict: dataState === "fresh" && typeof value === "number" && statusState === "fresh"
        && (value > 0 && [3,4,5].includes(statusValue) || value === 0 && [0,1,2].includes(statusValue))
    readonly property string statusText: conflict ? "状态冲突"
        : statusState === "missing" ? (destroyed ? "已摧毁 · 状态—" : "状态 —")
        : statusState === "stale" ? (destroyed ? "已摧毁 · 状态旧" : "状态 · 旧")
        : ({0:"无敌",1:"装甲旋转",2:"装甲停转",3:"不可重建",4:"可重建",5:"重建中"})[statusValue] ?? "状态 " + statusValue
    readonly property string team: blue ? "blue" : "red"
    readonly property real artworkScale: width / 154
    // 顶部高度预算包含标题、血条及增益槽；增益暂缺时也不能把预留空间撑进血条。
    readonly property real defenseHeight: heightBudget > 0 ? 12 : 20
    readonly property real reservedDefenseHeight: heightBudget > 0 ? defenseHeight + 2 : 0
    property real barTop: heightBudget > 0 ? 22 : width * 30 / 154
    property real barHeight: heightBudget > 0
        ? Math.max(0, Math.min(width * 32 / 154, heightBudget - barTop - reservedDefenseHeight))
        : width * 32 / 154
    readonly property real headerShear: Math.max(0, (barTop - 2) * 0.5)
    readonly property real headerContentLeft: (blue ? barHeight * 0.5 : 0) + headerShear + 2
    readonly property real headerContentWidth: Math.max(0, width - barHeight * 0.5 - 2 * headerShear - 4)
    readonly property real headerAvatarWidth: Math.min(19, Math.max(0, barTop - 7))
    property real displayedFraction: dataState === "missing" ? 0 : Data.fraction(value, maximum)
    Behavior on displayedFraction {
        enabled: !Theme.reducedMotion && root.dataState === "fresh"
        NumberAnimation { duration: Theme.reducedMotion ? 0 : 240; easing.type: Easing.OutCubic }
    }
    implicitWidth: 150
    implicitHeight: rebuilding ? rebuildDrawing.implicitHeight : barTop + barHeight + (hasDefensePercent ? defenseHeight + 2 : 0)
    Accessible.role: Accessible.StaticText
    Accessible.name: (blue ? "蓝方" : "红方") + "前哨站，血量 " + valueText
        + (dataState === "stale" ? "，旧数据" : "") + "，" + (rebuilding ? rebuildDrawing.Accessible.name : statusText)

    Canvas {
        id: headerPlate
        objectName: "outpostHeaderFrame"
        anchors.fill: parent
        visible: !root.rebuilding
        Accessible.ignored: true
        opacity: root.destroyed ? 0.5 : 1
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onBlueChanged() { headerPlate.requestPaint(); }
            function onBarHeightChanged() { headerPlate.requestPaint(); }
            function onBarTopChanged() { headerPlate.requestPaint(); }
        }
        onPaint: {
            const c = getContext("2d"); c.reset();
            const inset = root.barHeight * 0.5;
            c.beginPath();
            // 手册印刷页03：红方标题与血槽都向右下倾，蓝方镜像；两框内侧斜线连续。
            const shear = root.headerShear;
            c.moveTo(root.blue ? inset + shear : 0.5, 2);
            c.lineTo(root.blue ? width - 0.5 : width - inset - shear, 2);
            c.lineTo(root.blue ? width - shear - 0.5 : width - inset, root.barTop);
            c.lineTo(root.blue ? inset : shear + 0.5, root.barTop);
            c.closePath();
            c.fillStyle = "#99151917"; c.fill();
            c.strokeStyle = root.blue ? "#80368dae" : "#80894343";
            c.lineWidth = 1; c.stroke();
        }
    }
    Image {
        objectName: "outpostTitle"
        x: root.headerContentLeft + (root.blue ? root.headerAvatarWidth + 3 : 0)
        y: 2
        width: Math.max(0, root.headerContentWidth - root.headerAvatarWidth - 3)
        height: Math.min(width * 38 / 117, root.barTop - y)
        source: "../resources/player/top_outpost/" + root.team + "_outpost_panel.png"
        fillMode: Image.PreserveAspectFit
        mipmap: true
        opacity: root.destroyed ? 0.45 : root.dataState === "fresh" ? 1 : 0.6
        Accessible.ignored: true
        visible: !root.rebuilding
    }
    Image {
        objectName: "outpostAvatar"
        x: root.headerContentLeft + (root.blue ? 0 : root.headerContentWidth - width)
        y: 5
        width: root.headerAvatarWidth
        height: Math.min(width * 48 / 44, root.barTop - y)
        source: "../resources/player/top_outpost/" + root.team + "_outpost_avatar.png"
        fillMode: Image.PreserveAspectFit
        mipmap: true
        opacity: root.destroyed ? 0.45 : root.dataState === "fresh" ? 1 : 0.6
        Accessible.ignored: true
        visible: !root.rebuilding
    }
    OperatorSlantedFill {
        y: root.barTop; width: root.width; height: root.barHeight
        source: "../resources/engine-137/sprites/" + (root.destroyed ? "ServerUI_OutpostBloodBG.png" : "ServerUI_OutpostBloodMiddleBG.png")
        sourceClipRect: root.destroyed ? Qt.rect(0,0,226,56) : Qt.rect(0,0,218,48)
        fraction: 1
        anchorRight: !root.blue
        slantFixedEnd: true
        opacity: root.dataState === "fresh" ? 0.85 : 0.45
        visible: !root.rebuilding
    }
    OperatorSlantedFill {
        y: root.barTop; width: root.width; height: root.barHeight
        // 前哨bg是半透明边缘效果，不能当实体填充。复用基地原渐变直段统一材质，
        // 端部单独斜裁，避免拉宽小图时把原斜边拉成巨楔。
        source: "../resources/player/" + root.team + "_base_blood/" + root.team + "_base_blood_top.png"
        sourceClipRect: Qt.rect(400,8,40,70)
        fraction: root.displayedFraction
        anchorRight: !root.blue
        slantFixedEnd: true
        visible: !root.rebuilding && root.dataState !== "missing" && typeof root.value === "number" && root.value > 0
        opacity: root.dataState === "fresh" ? 0.9 : 0.35
    }
    Canvas {
        id: bloodOutline
        visible: !root.rebuilding
        y: root.barTop; width: root.width; height: root.barHeight
        Accessible.ignored: true
        opacity: root.dataState === "fresh" ? 0.85 : 0.4
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onBlueChanged() { bloodOutline.requestPaint(); }
            function onInvulnerableChanged() { bloodOutline.requestPaint(); }
            function onDestroyedChanged() { bloodOutline.requestPaint(); }
        }
        onPaint: {
            const c = getContext("2d");c.reset();const inset = height * 0.5;
            c.beginPath();c.moveTo(root.blue ? inset : 0.5,0.5);
            c.lineTo(root.blue ? width-0.5 : width-inset,0.5);
            c.lineTo(root.blue ? width-inset : width-0.5,height-0.5);
            c.lineTo(root.blue ? 0.5 : inset,height-0.5);c.closePath();
            c.strokeStyle = root.destroyed ? "#99707873" : root.invulnerable ? Theme.warning : root.blue ? "#99368dae" : "#99c34844";
            c.lineWidth = root.invulnerable ? 2 : 1;c.stroke();
        }
    }
    OperatorText {
        x: 14; y: root.barTop; width: root.width - 28; height: root.barHeight
        text: root.valueText
        numeric: true; size: root.barHeight * 0.8; minimumSize: 0; font.bold: true
        fontSizeMode: Text.Fit; minimumPixelSize: 8
        horizontalAlignment: root.blue ? Text.AlignRight : Text.AlignLeft
        color: root.dataState === "fresh" ? Theme.text : Theme.muted
        visible: !root.rebuilding && !root.destroyed
    }
    Item {
        id: defenseSeat
        objectName: "outpostDefenseSeat"
        // 原手册p03：只有防御增益百分比进入这个半宽槽；普通枚举留在提示中。
        // 延续血板外侧斜线dx/dy=±0.5，包含2px分隔，不能让下槽斜边退回板内。
        x: root.blue ? -(2 + height) / 2 : root.width + (2 + height) / 2 - width
        y: root.barTop + root.barHeight + 2
        width: root.width * 0.48
        height: root.defenseHeight
        visible: !root.rebuilding && root.hasDefensePercent
        clip: true
        OperatorBaseDetailsFrame {
            anchors.fill: parent
            blue: root.blue
            fresh: true
            slantWidth: defenseSeat.height / 2
        }
        OperatorText {
            x: 10; width: parent.width - 20; height: parent.height
            text: root.hasDefensePercent ? root.defenseProjection.defense_percent + "%" : ""
            numeric: true
            size: Math.min(18,parent.height-2)
            font.bold: true
            fontSizeMode: Text.Fit
            minimumPixelSize: 8
            color: Theme.text
            horizontalAlignment: root.blue ? Text.AlignRight : Text.AlignLeft
        }
    }
    OperatorOutpostRebuild {
        id: rebuildDrawing
        anchors.fill: parent
        visible: root.rebuilding
        blue: root.blue
        projection: root.rebuildProjection
        heightBudget: root.heightBudget
    }
    HoverHandler { id: hover }
    ToolTip.visible: hover.hovered && !root.rebuilding
    ToolTip.delay: 450
    ToolTip.text: root.Accessible.name + (root.hasDefensePercent
        ? "；防御 " + root.defenseProjection.defense_percent + "% · " + root.defenseProjection.source_kind
            + " / " + root.defenseProjection.source_id + " · " + root.defenseProjection.snapshot_id
        : "；未收到有效防御百分比，隐藏下槽；不能由普通状态猜造。")
}
