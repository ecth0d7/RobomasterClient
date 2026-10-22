import QtQuick
import QtQuick.Controls
import "OperatorBuffData.js" as Buff

// 原80px环族共用同一环带；类别、动态值与时效独立，不从TTL猜持续时间。
Button {
    id: root
    property var record: ({})
    readonly property bool terrain:record.record_kind==="terrain"
    readonly property bool unknownPolarity: record.buff_type === 2 && Buff.fieldState(record,"buff_level") !== "fresh"
    readonly property bool negative: !unknownPolarity && record.buff_type === 2 && record.buff_level < 0
    readonly property var ratio: unknownPolarity ? null : Buff.fraction(record)
    readonly property string tone:terrain ? (["left","middle"].includes(record.terrain_phase)?"cyan":"green") : negative || record.buff_type === 3 ? "orange"
        : [1,6].includes(record.buff_type) ? "cyan" : "green"
    readonly property bool yellowDefense: record.buff_type === 2 && !negative && !unknownPolarity
    property url texture: "../resources/engine-137/sprites/buff_2020_cirle_" + tone + ".png"
    property real displayedFraction: ratio ?? 0
    onDisplayedFractionChanged: progressDrawing.requestPaint()
    onTextureChanged: progressDrawing.refreshImage()
    Behavior on displayedFraction {
        enabled: root.ratio !== null && root.record.time_unit === "s"
        NumberAnimation { duration: Theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic }
    }
    width: 48
    height: 48
    padding: 0
    hoverEnabled: true
    Accessible.name: "查看" + Buff.title(record) + "详情，" + Buff.value(record)
    Accessible.description: Buff.stateText(record) + "，剩余／最大剩余 " + Buff.timeText(record)
        + "，" + record.source_kind + " / " + record.source_id + "，快照 " + record.snapshot_id
        + "，" + (Number.isFinite(record.age_ms) ? (record.age_ms/1000).toFixed(1)+"秒前" : "时效未知")
    ToolTip.visible: hovered
    ToolTip.delay: 450
    ToolTip.text: Accessible.name + "。" + Accessible.description
    background: Item {
        Rectangle {
            x:1;y:1;width:parent.width-2;height:parent.height-2;radius:width/2
            color:"#9a161c18"
        }
        Image {
            anchors.fill: parent
            source: "../resources/engine-137/sprites/buff_2020_cirle_empty.png"
            fillMode: Image.PreserveAspectFit
            mipmap: true
            Accessible.ignored: true
        }
        Canvas {
            id: progressDrawing
            width: root.width*4; height:root.height*4
            scale:0.25; transformOrigin:Item.TopLeft
            visible: root.ratio !== null && root.ratio > 0 && root.displayedFraction > 0
            property url loadedSource: ""
            function refreshImage() {
                if (!available) return;
                if (loadedSource.toString() && loadedSource !== root.texture) unloadImage(loadedSource);
                loadedSource=root.texture;loadImage(loadedSource);requestPaint();
            }
            onAvailableChanged: if(available) refreshImage()
            onImageLoaded: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections { target: root; function onYellowDefenseChanged() { progressDrawing.requestPaint(); } }
            onPaint: {
                const c=getContext("2d");c.reset();
                if (!isImageLoaded(root.texture) || root.ratio === null || root.displayedFraction <= 0) return;
                c.scale(4*root.width/80,4*root.height/80);
                const start=-Math.PI/2,end=start+2*Math.PI*Math.min(1,root.displayedFraction);
                c.beginPath();c.arc(40,40,40,start,end,false);c.arc(40,40,34,end,start,true);c.closePath();c.clip();
                // 橙环176画布归一到同一80px环带，内外缘由共同轮廓限制。
                const side=root.tone === "orange" ? 176 : 80;
                c.drawImage(root.texture,0,0,side,side,0,0,80,80);
                if (root.yellowDefense || root.record.buff_type===1) {
                    c.globalCompositeOperation="source-in";
                    c.fillStyle=root.yellowDefense ? "#edf0b7" : "#67c8aa";c.fillRect(0,0,80,80);
                }
            }
            Accessible.ignored: true
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: width/2
            visible: root.activeFocus
            color: "transparent"
            border.width: 1
            border.color: Theme.green
        }
    }
    contentItem: Item {
        OperatorBuffGlyph {
            x: parent.width*(root.terrain ? .18 : .25); y:parent.height*(root.terrain ? .18 : 7/48)
            width:parent.width*(root.terrain ? .64 : .5); height:parent.height*(root.terrain ? .64 : 23/48)
            kind:root.terrain?7:root.unknownPolarity ? 0 : root.record.buff_type ?? 0
            terrainKind:root.record.terrain_kind??""
            terrainPhase:root.record.terrain_phase??""
            negative: root.negative
            robotID:root.record.robot_id ?? 0
            Accessible.ignored: true
        }
        OperatorText {
            x:parent.width/12; y:parent.height*29/48
            width:parent.width*5/6; height:parent.height*13/48
            text: Buff.hudValue(root.record)
            numeric: true; size:11
            horizontalAlignment: Text.AlignHCenter
            font.italic: true
            style: Text.Normal
            color: root.negative ? "#ff8d64" : Theme.text
            Accessible.ignored: true
        }
    }
}
