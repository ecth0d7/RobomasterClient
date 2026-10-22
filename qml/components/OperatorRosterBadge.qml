import QtQuick

// 手册p03：黄牌复用选手端斜置叹号；罚下的禁止符号未在137导出找到匹配原图。
Item {
    id:root
    property string kind:""
    implicitWidth:28
    implicitHeight:28
    Accessible.role:Accessible.StaticText
    Accessible.name:kind==="expelled" ? "红牌罚下" : kind==="prohibited" ? "禁止发射" : "黄牌"
    Image {
        anchors.centerIn:parent
        width:parent.width;height:width*72/62
        source:"../resources/player/my_robot/statusbar_warning_yellow.png"
        visible:root.kind==="yellow"
        fillMode:Image.PreserveAspectFit;mipmap:true
    }
    Canvas {
        id:ban
        anchors.fill:parent
        visible:["expelled","prohibited"].includes(root.kind)
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        onVisibleChanged:if(visible)requestPaint()
        onPaint:{
            const c=getContext("2d");c.reset();
            const r=Math.min(width,height)*.39;
            c.beginPath();c.arc(width/2,height/2,r,0,Math.PI*2);
            c.strokeStyle="#f14b4a";c.lineWidth=4*Math.min(width,height)/28;c.stroke();
            c.beginPath();c.moveTo(width/2-r*.7,height/2+r*.7);c.lineTo(width/2+r*.7,height/2-r*.7);c.stroke();
        }
    }
}
