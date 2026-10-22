import QtQuick

// 原填充纹理进入动态斜槽：矩形裁剪会把部分血量的活动端切直。
// Canvas只在比例／尺寸／素材变化时绘制，兼容当前软件后端，不依赖GL遮罩。
Item {
    id: root
    property url source: ""
    property rect sourceClipRect: Qt.rect(0, 0, 1, 1)
    property real fraction: 0
    property bool anchorRight: false
    property bool slantFixedEnd: false
    property real slopeRatio: 0.5
    property color tint: "transparent"
    property real slantWidth: -1
    // 独立的左连接斜线：背景与填充共用，不能靠前景头像遮住矩形端。
    property real leftInsetTop: 0
    property real leftInsetBottom: 0
    property url maskSource: ""
    property rect maskClipRect: Qt.rect(0,0,1,1)
    clip: true
    Accessible.ignored: true
    onSourceChanged: drawing.refreshImage()
    onMaskSourceChanged: drawing.refreshImage()
    onMaskClipRectChanged: drawing.requestPaint()
    onSourceClipRectChanged: drawing.requestPaint()
    onFractionChanged: drawing.requestPaint()
    onAnchorRightChanged: drawing.requestPaint()
    onSlantFixedEndChanged: drawing.requestPaint()
    onSlopeRatioChanged: drawing.requestPaint()
    onSlantWidthChanged: drawing.requestPaint()
    onLeftInsetTopChanged: drawing.requestPaint()
    onLeftInsetBottomChanged: drawing.requestPaint()
    onTintChanged: drawing.requestPaint()
    Canvas {
        id: drawing
        width: root.width*4; height: root.height*4
        scale: 0.25
        transformOrigin: Item.TopLeft
        property url loadedSource: ""
        property url loadedMask: ""
        function refreshImage() {
            if (!available) return;
            if (loadedSource.toString() && loadedSource !== root.source) unloadImage(loadedSource);
            if (loadedMask.toString() && loadedMask !== root.maskSource) unloadImage(loadedMask);
            loadedSource=root.source; loadedMask=root.maskSource;
            if (root.source.toString()) loadImage(root.source);
            if (root.maskSource.toString()) loadImage(root.maskSource);
            requestPaint();
        }
        onAvailableChanged: if(available) refreshImage()
        onImageLoaded: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
        const c = getContext("2d");
        c.reset(); c.scale(4,4);
        const width=root.width,height=root.height;
        if (!Number.isFinite(root.fraction) || root.fraction <= 0 || !isImageLoaded(root.source)
            || root.maskSource.toString() && !isImageLoaded(root.maskSource)) return;
        const fraction = Math.max(0, Math.min(1, root.fraction));
        const remaining = width * fraction;
        const fullSlope = Math.min(width, root.slantWidth >= 0 ? root.slantWidth : height * root.slopeRatio);
        const slope = Math.min(remaining, fullSlope);
        c.beginPath();
        if (root.anchorRight) {
            c.moveTo(width - remaining, 0); c.lineTo(width - (root.slantFixedEnd ? slope : 0), 0);
            c.lineTo(width, height); c.lineTo(width - remaining + slope, height);
        } else if (root.leftInsetTop > 0 || root.leftInsetBottom > 0) {
            const leftTop = Math.max(0, Math.min(width, root.leftInsetTop));
            const leftBottom = Math.max(0, Math.min(width-fullSlope, root.leftInsetBottom));
            // 从可见斜槽起点插值；先画width*f再硬裁会吞掉低血量／低能量。
            c.moveTo(leftTop, 0);
            c.lineTo(leftTop+(width-leftTop)*fraction, 0);
            c.lineTo(leftBottom+(width-fullSlope-leftBottom)*fraction, height);
            c.lineTo(leftBottom, height);
        } else {
            c.moveTo(root.slantFixedEnd ? slope : 0, 0); c.lineTo(remaining, 0);
            c.lineTo(remaining - slope, height); c.lineTo(0, height);
        }
        c.closePath(); c.clip();
        c.drawImage(root.source, root.sourceClipRect.x, root.sourceClipRect.y, root.sourceClipRect.width, root.sourceClipRect.height,
                    0, 0, width, height);
        if (root.tint.a > 0) {
            c.globalCompositeOperation = "source-atop";
            c.fillStyle = root.tint;
            c.fillRect(0, 0, width, height);
        }
        // 原槽alpha与背景共用同一实体裁区，防止纹理留白／斜率差留下内缝或越框。
        if (root.maskSource.toString()) {
            c.globalCompositeOperation="destination-in";
            c.drawImage(root.maskSource,root.maskClipRect.x,root.maskClipRect.y,
                        root.maskClipRect.width,root.maskClipRect.height,0,0,width,height);
        }
        }
    }
}
