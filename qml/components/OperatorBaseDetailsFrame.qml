import QtQuick

// 手册页02的血条下沿信息槽。缺少独立可复用贴图时只补轮廓，不绘制假防御数值。
Canvas {
    id: root
    property bool blue: false
    property bool fresh: false
    property bool openBack: true
    property real slantWidth: -1
    Accessible.ignored: true
    opacity: fresh ? 0.48 : 0.24
    onBlueChanged: requestPaint()
    onOpenBackChanged: requestPaint()
    onSlantWidthChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        if (width <= 0 || height <= 0) return;
        const inset = slantWidth >= 0 ? slantWidth : Math.min(9, height * 0.5);
        c.beginPath();
        c.moveTo(blue ? inset : 0.5, 0.5);
        c.lineTo(blue ? width - 0.5 : width - inset, 0.5);
        c.lineTo(blue ? width - inset : width - 0.5, height - 0.5);
        c.lineTo(blue ? 0.5 : inset, height - 0.5);
        c.closePath();
        c.fillStyle = "#99151917";
        c.fill();
        if (openBack) {
            // 与弹量小槽共用开口后缘：保留上下边及外侧斜端，填充仍闭合。
            c.beginPath();
            if (blue) {
                c.moveTo(width - 0.5,0.5); c.lineTo(inset,0.5);
                c.lineTo(0.5,height - 0.5); c.lineTo(width - inset,height - 0.5);
            } else {
                c.moveTo(0.5,0.5); c.lineTo(width - inset,0.5);
                c.lineTo(width - 0.5,height - 0.5); c.lineTo(inset,height - 0.5);
            }
        }
        c.strokeStyle = blue ? Theme.blue : Theme.red;
        c.lineWidth = 1;
        c.stroke();
    }
}
