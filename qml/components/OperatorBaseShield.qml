import QtQuick

// 手册p02：护盾与HP同尺度，红左／蓝右；两端的斜向不能随填充锚点反转。
// 独立组件只处理护盾，不改变基地HP、追血或其他血槽的裁剪路径。
Item {
    id: root
    property bool blue: false
    property bool slantedEnds: false
    property real fraction: 0
    property url source: "../resources/engine-137/sprites/ServerUI_" + (blue ? "Blue" : "Red") + "BaseShield.png"
    property url slotMask: "../resources/player/" + (blue ? "blue" : "red") + "_base_blood/"
        + (blue ? "blue" : "red") + "_base_blood_bottom.png"
    property rect slotRect: blue ? Qt.rect(0,20,835,68) : Qt.rect(2,2,835,68)
    clip: true
    Accessible.ignored: true
    onFractionChanged: drawing.requestPaint()
    onBlueChanged: drawing.refreshImage()
    onSourceChanged: drawing.refreshImage()
    onSlotMaskChanged: drawing.refreshImage()
    onSlantedEndsChanged: drawing.requestPaint()

    Canvas {
        id: drawing
        width: root.width * 4
        height: root.height * 4
        scale: 0.25
        transformOrigin: Item.TopLeft
        Accessible.ignored: true
        property url loadedSource: ""
        property url loadedMask: ""
        function refreshImage() {
            if (!available) return;
            if (loadedSource.toString() && loadedSource !== root.source) unloadImage(loadedSource);
            loadedSource = root.source;
            if (loadedMask.toString() && loadedMask !== root.slotMask) unloadImage(loadedMask);
            loadedMask = root.slotMask;
            loadImage(root.source);
            loadImage(root.slotMask);
            requestPaint();
        }
        onAvailableChanged: if (available) refreshImage()
        onImageLoaded: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset(); c.scale(4, 4);
            if (!Number.isFinite(root.fraction) || root.fraction <= 0
                || !isImageLoaded(root.source) || !isImageLoaded(root.slotMask)) return;
            const extent = root.width * Math.min(1, root.fraction);
            if (root.slantedEnds) {
                const end = root.height * 0.5;
                c.beginPath();
                c.moveTo(root.blue ? end : 0, 0);
                c.lineTo(root.blue ? root.width : root.width - end, 0);
                c.lineTo(root.blue ? root.width - end : root.width, root.height);
                c.lineTo(root.blue ? 0 : end, root.height);
                c.closePath(); c.clip();
            }
            // 极小正护盾仍保留面积；不能让两个斜端在同一条线上使150HP等小值消失。
            const slope = Math.min(root.height * 0.5, extent * 0.45);
            c.beginPath();
            if (root.blue) {
                c.moveTo(root.width - extent + slope, 0); c.lineTo(root.width, 0);
                c.lineTo(root.width - slope, root.height); c.lineTo(root.width - extent, root.height);
            } else {
                c.moveTo(0, 0); c.lineTo(extent - slope, 0);
                c.lineTo(extent, root.height); c.lineTo(slope, root.height);
            }
            c.closePath(); c.clip();
            // 原35×40浅色护盾直接叠在基地的光泽纹理上，无伪造纹理或红蓝色调转换。
            c.drawImage(root.source, 0, 0, 35, 40, 0, 0, root.width, root.height);
            // 同一底槽的原alpha再裁一次，蓝方曲角／斜端不能由矩形护盾露到槽外。
            if (!root.slantedEnds) {
                c.globalCompositeOperation="destination-in";
                c.drawImage(root.slotMask,root.slotRect.x,root.slotRect.y,root.slotRect.width,root.slotRect.height,
                            0,0,root.width,root.height);
            }
        }
    }
}
