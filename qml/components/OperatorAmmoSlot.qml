import QtQuick

// 顶部血槽斜边向下延长：红底边右移，蓝底边左移，符号／数值由调用者放在槽内。
// 原弹量槽的暗色核心作为材质，轮廓按上方槽线绘制，不能把另一个模板的斜率拉歪。
Item {
    id: root
    property bool blue: false
    property bool fresh: true
    property real topLeft: 0
    property real topRight: width
    property real bottomLeft: 0
    property real bottomRight: width
    clip: true
    Accessible.ignored: true
    onBlueChanged: drawing.requestPaint()
    onFreshChanged: drawing.requestPaint()
    onTopLeftChanged: drawing.requestPaint()
    onTopRightChanged: drawing.requestPaint()
    onBottomLeftChanged: drawing.requestPaint()
    onBottomRightChanged: drawing.requestPaint()
    Canvas {
        id: drawing
        width: root.width*4;height:root.height*4
        scale:0.25;transformOrigin:Item.TopLeft
        property url material:"../resources/player/my_robot/statusbar_bullet_border.png"
        onAvailableChanged: if(available)loadImage(material)
        onImageLoaded:requestPaint()
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        onPaint: {
            const c=getContext("2d");c.reset();c.scale(4,4);
            c.beginPath();c.moveTo(root.topLeft,0.5);
            c.lineTo(root.topRight,0.5);
            c.lineTo(root.bottomRight,root.height-0.5);
            c.lineTo(root.bottomLeft,root.height-0.5);c.closePath();
            c.fillStyle=root.fresh?"#aa18221d":"#7718221d";c.fill();
            c.save();c.clip();
            if(isImageLoaded(material))c.drawImage(material,4,4,150,48,0,0,root.width,root.height);
            c.restore();
            // 填充保持闭合，只画三段边线；红左／蓝右的后缘开口，不叠第二套封闭框。
            c.beginPath();
            if(root.blue) {
                c.moveTo(root.topRight,0.5);c.lineTo(root.topLeft,0.5);
                c.lineTo(root.bottomLeft,root.height-0.5);c.lineTo(root.bottomRight,root.height-0.5);
            } else {
                c.moveTo(root.topLeft,0.5);c.lineTo(root.topRight,0.5);
                c.lineTo(root.bottomRight,root.height-0.5);c.lineTo(root.bottomLeft,root.height-0.5);
            }
            c.strokeStyle=root.fresh?"#888d9a94":"#44697770";c.lineWidth=0.8;c.stroke();
        }
    }
}
