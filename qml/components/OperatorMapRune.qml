import QtQuick
import QtQuick.Controls

Item {
    id:root
    required property var node
    required property var placement
    property real glyphSize:28
    readonly property bool displaced:placement!==undefined && placement!==null
        && Math.hypot(placement.x+glyphSize/2-placement.anchorX,placement.y+glyphSize/2-placement.anchorY)>3
    visible:node!==undefined && node!==null && placement!==undefined && placement!==null
    Canvas {
        anchors.fill:parent
        visible:root.displaced
        Connections {target:root;function onPlacementChanged(){leader.requestPaint()}}
        id:leader
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        onPaint:{
            const c=getContext("2d");c.reset();
            if(!root.placement)return;
            c.beginPath();c.moveTo(root.placement.anchorX,root.placement.anchorY);
            c.lineTo(root.placement.x+root.glyphSize/2,root.placement.y+root.glyphSize/2);
            c.strokeStyle="#a8adbaac";c.lineWidth=1;c.stroke();
            c.beginPath();c.arc(root.placement.anchorX,root.placement.anchorY,2,0,Math.PI*2);c.fillStyle="#d4ddd7";c.fill();
        }
    }
    Image {
        objectName:"mapRuneGlyph"
        x:root.placement?.x??0;y:root.placement?.y??0
        width:root.glyphSize;height:width
        source:root.node?.texture??""
        fillMode:Image.PreserveAspectFit
        mipmap:true
        Accessible.role:Accessible.StaticText
        Accessible.name:root.node ? root.node.caption+" · 本机地图配置 · 来源机器人 "+root.node.source_robot_id
            +" · 坐标 "+root.node.x+", "+root.node.y+(root.displaced?" · 图标避让，细线指向坐标":"") : ""
        HoverHandler {id:hover;blocking:false}
        ToolTip.visible:hover.hovered
        ToolTip.delay:450
        ToolTip.text:Accessible.name
    }
}
