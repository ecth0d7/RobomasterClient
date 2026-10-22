import QtQuick

// 手册基地护盾的小实心符号：数值和语义由旁边文字／可访问名称承载。
Canvas {
    id: root
    property color accent: Theme.text
    Accessible.ignored: true
    onAccentChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d"); c.reset(); c.scale(width / 16, height / 18);
        c.fillStyle = accent;
        c.beginPath(); c.moveTo(8, 0); c.lineTo(15, 3); c.lineTo(14, 11);
        c.quadraticCurveTo(12, 15, 8, 18); c.quadraticCurveTo(4, 15, 2, 11);
        c.lineTo(1, 3); c.closePath(); c.fill();
    }
}
