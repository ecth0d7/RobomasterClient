import QtQuick
import QtQuick.Shapes

Item {
    id:root
    property var plan:null
    property bool compact:false
    readonly property var points:plan?plan.points.map(p=>Qt.point(p.x/28*width,(1-p.y/15)*height)):[]
    visible:points.length>1
    opacity: plan?.stale ? 0.35 : 0.8
    Shape {
        anchors.fill:parent;antialiasing:true
        ShapePath {
            fillColor:"transparent";strokeColor:"#42e9b6";strokeWidth:root.compact?1.4:2
            capStyle:ShapePath.RoundCap;joinStyle:ShapePath.RoundJoin
            PathPolyline {path:root.points}
        }
    }
    Rectangle {
        width:root.compact?5:8;height:width;radius:width/2;color:"#42e9b6"
        x:Math.max(0,Math.min(root.width-width,(root.points[root.points.length-1]?.x??0)-width/2))
        y:Math.max(0,Math.min(root.height-height,(root.points[root.points.length-1]?.y??0)-height/2))
    }
}
