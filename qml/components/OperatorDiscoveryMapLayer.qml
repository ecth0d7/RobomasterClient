import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "FieldGeometry.js" as Geometry
import "OperatorMapLabelLayout.js" as Labels

Item {
    id:root
    property var markers:[]
    property var obstacles:[]
    property bool previewOnly:false
    property bool compact:false
    readonly property real hudScale:Window.window?.ui?.layoutScale ?? 1
    property real stroke:Theme.hudStroke(hudScale,false)
    property real badgeWidth:Math.ceil(metrics.advanceWidth("视9"))+12
    property real badgeHeight:Math.ceil(metrics.height)+6
    property real gap:Math.max(2,2/Math.max(0.1,hudScale))
    // 年龄/说明每250ms刷新不触发几何重排，字体/尺寸/坐标/身份真正变化时才计算。
    readonly property string geometrySignature:JSON.stringify(geometry())
    function geometry() {
        const result=[];
        for (let index=0;index<Math.min(markers.length,16);++index) {
            const marker=markers[index];
            if (marker?.validated_for_ui !== true || (!previewOnly && marker.mock !== false)
                || marker.renderable !== true || marker.lifecycle !== "active" || marker.frame_id !== "rm2026.field"
                || marker.unit !== "m" || !Geometry.valid(marker.x,marker.y,28,15)) continue;
            result.push({key:JSON.stringify([marker.display_channel,marker.observation_key]),sourceIndex:index,
                source:JSON.stringify([marker.display_channel,marker.source_robot]),
                x:marker.x,y:marker.y,priority:marker.display_priority ?? 0,text:(marker.label ?? "感")+(marker.source_robot%100)});
        }
        return result;
    }
    readonly property string obstacleSignature:JSON.stringify(obstacles)
    // 每个地图实例各自持有小型JS缓存；不把上一次标签位置写回数据或跨地图共享。
    property var layoutMemory:({labels:[],sizeKey:""})
    readonly property var placements:Labels.layout(geometrySignature,JSON.parse(obstacleSignature),width,height,badgeWidth,badgeHeight,gap,
        Math.max(badgeWidth*(compact ? 1.2 : 1.6),Math.min(width,height)*(compact ? 0.26 : 0.38)),layoutMemory)
    readonly property int labelCount:placements.labels.length
    readonly property int hiddenCount:placements.hiddenCount
    FontMetrics {
        id:metrics
        font.family:Theme.fontFamily
        font.pixelSize:Math.max(root.compact ? 12 : 14,9.5/Math.max(0.1,root.hudScale))
    }
    Canvas {
        id:leaders
        anchors.fill:parent
        onPaint:{
            const ctx=getContext("2d");ctx.clearRect(0,0,width,height);
            ctx.strokeStyle=Theme.warning;ctx.lineWidth=root.stroke;ctx.globalAlpha=0.6;
            for (const label of root.placements.labels) {
                ctx.beginPath();ctx.moveTo(label.anchor.x,label.anchor.y);ctx.lineTo(label.end.x,label.end.y);ctx.stroke();
            }
            ctx.globalAlpha=1;
            const radius=2*root.stroke;
            for (const point of root.placements.anchors) {
                ctx.beginPath();ctx.moveTo(point.x,point.y-radius);ctx.lineTo(point.x+radius,point.y);
                ctx.lineTo(point.x,point.y+radius);ctx.lineTo(point.x-radius,point.y);ctx.closePath();ctx.stroke();
            }
        }
        Connections {
            target:root
            function onPlacementsChanged() {leaders.requestPaint();}
            function onStrokeChanged() {leaders.requestPaint();}
        }
    }
    Repeater {
        model:root.labelCount
        Rectangle {
            id:badge
            required property int index
            readonly property var placement:root.placements.labels[index]
            readonly property var marker:root.markers[placement.sourceIndex] ?? ({})
            readonly property string description:(marker.description ?? "独立发现")
                +"\n坐标 "+Number(marker.x).toFixed(2)+", "+Number(marker.y).toFixed(2)+" m；细线连接真实坐标，标签偏移仅供阅读。"
            x:placement.x;y:placement.y;width:placement.w;height:placement.h
            color:Theme.hudSolid;radius:1;border.color:Theme.warning;border.width:root.stroke
            Accessible.role:Accessible.StaticText
            Accessible.name:description
            HoverHandler {id:hover}
            ToolTip.visible:hover.hovered
            ToolTip.delay:500
            ToolTip.text:badge.description
            OperatorText {
                anchors.fill:parent;anchors.margins:root.stroke+2
                text:badge.placement.text;color:Theme.warning
                size:root.compact ? 12 : 14
                horizontalAlignment:Text.AlignHCenter
                clip:true
            }
        }
    }
}
