import QtQuick
import "OperatorData.js" as Data

Item {
    id:root
    property int robotID:0
    property bool defeated:false
    readonly property bool blue:robotID>100
    readonly property int role:robotID%100
    readonly property url portraitSource:role===11 ? "../resources/player/message/"+(blue?"blue":"red")+"_message_outpost.png"
        :role===8 ? "../resources/player/silo/tab_icon_silo.png" :role===9 ? "" :Data.portrait(robotID)
    implicitWidth:56;implicitHeight:66
    Canvas {
        id:drawing
        width:root.width*3;height:root.width*3;scale:1/3;transformOrigin:Item.TopLeft
        property url loadedSource:""
        function reload(){
            if(!available)return;
            if(loadedSource.toString())unloadImage(loadedSource);
            loadedSource=root.portraitSource;
            if(loadedSource.toString())loadImage(loadedSource);
            requestPaint();
        }
        onAvailableChanged:if(available)reload()
        onImageLoaded:requestPaint()
        onWidthChanged:requestPaint()
        Connections {target:root;function onPortraitSourceChanged(){drawing.reload();}}
        onPaint:{
            const c=getContext("2d");c.reset();c.scale(width/56,height/56);
            c.beginPath();c.arc(28,28,27,0,Math.PI*2);c.fillStyle="#e019211e";c.fill();c.save();c.clip();
            if(isImageLoaded(root.portraitSource)) {
                if([1,2,3,4,5,6].includes(root.role))c.drawImage(root.portraitSource,8,14,120,120,0,0,56,56);
                else if(root.role===11)c.drawImage(root.portraitSource,0,-(56*355/330-56)/2,56,56*355/330);
                else c.drawImage(root.portraitSource,0,0,56,56);
            }
            c.restore();c.beginPath();c.arc(28,28,27,0,Math.PI*2);c.strokeStyle=root.blue?"#3386a1":"#a14c48";c.lineWidth=1;c.stroke();
        }
    }
    OperatorRadarGlyph {x:8;y:8;width:parent.width-16;height:width;visible:root.role===9;accent:root.blue?Theme.blue:Theme.red}
    Image {x:-3;y:-3;width:parent.width+6;height:width;source:"../resources/player/message/message_kill.png";visible:root.defeated;fillMode:Image.PreserveAspectFit;mipmap:true}
    Rectangle {
        x:(parent.width-width)/2;y:parent.width-10;width:20;height:20;radius:10
        color:root.blue?"#175575":"#842d2a"
        OperatorText {anchors.fill:parent;text:String(root.role);numeric:true;size:13;minimumSize:9.5;horizontalAlignment:Text.AlignHCenter}
    }
}
