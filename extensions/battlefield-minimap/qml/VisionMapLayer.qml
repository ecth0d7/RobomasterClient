import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "../../../qml/components/OperatorMapLabelLayout.js" as Labels
import "../../../qml/components" as Client
import "VisionMapData.js" as Vision

Item {
    id:root
    objectName:"visionMinimapLayer"
    property var markers:[]
    property var obstacles:[]
    property bool compact:false
    property double now:Date.now()
    readonly property real hudScale:Window.window?.ui?.layoutScale ?? 1
    readonly property real stroke:Client.Theme.hudStroke(hudScale,false)
    readonly property real glyphSize:compact?28:42
    readonly property real badgeWidth:metrics.advanceWidth("视敌7?")+10
    readonly property real badgeHeight:metrics.height+4
    readonly property real gap:Math.max(2,2/Math.max(.1,hudScale))
    readonly property string geometrySignature:JSON.stringify(markers.map((m,i)=>({key:m.key,source:m.sourceNode,
        sourceIndex:i,x:m.x,y:m.y,text:m.text,priority:m.conflict?3:2})))
    property var layoutMemory:({labels:[],sizeKey:""})
    readonly property var placements:Labels.layout(geometrySignature,obstacles,width,height,badgeWidth,badgeHeight,gap,
        Math.min(width,height)*.3,layoutMemory)
    readonly property var labels:placements.labels.slice(0,14)
    readonly property int hiddenLabels:markers.length-labels.length
    readonly property var labelObstacles:labels.map(p=>({x:p.x,y:p.y,w:p.w,h:p.h}))
    FontMetrics {id:metrics;font.family:Client.Theme.fontFamily;font.pixelSize:Math.max(root.compact?11:13,9/Math.max(.1,root.hudScale))}
    Canvas {
        id:ink
        anchors.fill:parent
        onPaint:{
            const ctx=getContext("2d");ctx.clearRect(0,0,width,height);ctx.lineWidth=root.stroke;
            for(const m of root.markers) {
                const x=m.x/28*width,y=(1-m.y/15)*height;
                ctx.strokeStyle=m.conflict?Client.Theme.red:Client.Theme.warning;
                // Elliptical screen footprint preserves the metre radius on a
                // non-square map; clipping is visual only, never coordinate clamping.
                if(m.uncertainty!==null && m.uncertainty>0) {
                    ctx.globalAlpha=.4;ctx.setLineDash([4*root.stroke,3*root.stroke]);ctx.beginPath();
                    ctx.ellipse(x-m.uncertainty/28*width,y-m.uncertainty/15*height,
                        2*m.uncertainty/28*width,2*m.uncertainty/15*height);ctx.stroke();
                }
                ctx.globalAlpha=1;ctx.setLineDash([]);ctx.strokeRect(x-root.glyphSize/2,y-root.glyphSize/2,root.glyphSize,root.glyphSize);
                if(m.conflict){ctx.beginPath();ctx.moveTo(x-3,y-3);ctx.lineTo(x+3,y+3);ctx.moveTo(x+3,y-3);ctx.lineTo(x-3,y+3);ctx.stroke();}
            }
            ctx.strokeStyle=Client.Theme.warning;ctx.globalAlpha=.7;
            for(const p of root.labels){ctx.beginPath();ctx.moveTo(p.anchor.x,p.anchor.y);ctx.lineTo(p.end.x,p.end.y);ctx.stroke();}
        }
        Connections {
            target:root
            function onMarkersChanged(){ink.requestPaint();}
            function onPlacementsChanged(){ink.requestPaint();}
            function onStrokeChanged(){ink.requestPaint();}
            function onGlyphSizeChanged(){ink.requestPaint();}
        }
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
    }
    Repeater {
        model:root.markers.length
        Item {
            required property int index
            objectName:"visionMapAnchor"+index
            readonly property var marker:root.markers[index]
            x:marker.x/28*root.width-width/2;y:(1-marker.y/15)*root.height-height/2
            width:root.glyphSize+6;height:width
            Accessible.role:Accessible.StaticText
            Accessible.name:Vision.description(marker,root.now)
        }
    }
    Repeater {
        model:root.labels.length
        Rectangle {
            required property int index
            objectName:"visionMapLabel"+index
            readonly property var placement:root.labels[index]
            readonly property var marker:root.markers[placement.sourceIndex]
            x:placement.x;y:placement.y;width:placement.w;height:placement.h
            color:Client.Theme.hudSolid;radius:1;border.color:marker.conflict?Client.Theme.red:Client.Theme.warning;border.width:root.stroke
            Accessible.role:Accessible.StaticText
            Accessible.name:Vision.description(marker,root.now)
            Client.OperatorText {anchors.fill:parent;text:parent.placement.text;size:metrics.font.pixelSize;color:parent.border.color;horizontalAlignment:Text.AlignHCenter}
        }
    }
}
