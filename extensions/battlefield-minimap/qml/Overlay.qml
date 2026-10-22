import QtQuick
import "VisionMapData.js" as Data

Item {
    id:root
    property var view:({})
    property var radarPoints:[]
    property var obstacles:[]
    property var discoveryLabelRects:[]
    property int clientID:0
    property bool compact:false
    property double received:Date.now()
    property double now:Date.now()
    onViewChanged:{received=Date.now();now=received;}
    onVisibleChanged:if(visible)now=Date.now()
    Timer {interval:250;repeat:true;running:root.visible;onTriggered:root.now=Date.now()}
    readonly property var snapshot:Data.collect(view,received,now,clientID,radarPoints)
    readonly property int hiddenLabels:layer.hiddenLabels
    readonly property var anchorObstacles:snapshot.markers.map(m=>({
        x:m.x/28*width-layer.glyphSize/2-2,y:(1-m.y/15)*height-layer.glyphSize/2-2,
        w:layer.glyphSize+4,h:layer.glyphSize+4}))
    function hitAt(point) {
        const label=layer.labels.find(r=>point.x>=r.x && point.x<=r.x+r.w && point.y>=r.y && point.y<=r.y+r.h);
        if(label)return layer.markers[label.sourceIndex] ?? null;
        return layer.markers.find(m=>Math.abs(point.x-m.x/28*width)<=layer.glyphSize/2+3
            && Math.abs(point.y-(1-m.y/15)*height)<=layer.glyphSize/2+3) ?? null;
    }
    VisionMapLayer {
        id:layer;anchors.fill:parent;markers:root.snapshot.markers;now:root.now;compact:root.compact
        obstacles:root.obstacles.concat(root.anchorObstacles,root.discoveryLabelRects)
    }
}
