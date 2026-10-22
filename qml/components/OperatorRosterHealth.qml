import QtQuick

// 原血槽只画原tab_bar素材的斜格；不新增背景条／边框。
Item {
    id: root
    property url source: ""
    property bool blue: false
    property bool defeated: false
    property bool invulnerable:false
    property bool runeActive:false
    property var maximum: null
    property real pointsPerCell: 100
    property real fraction: 0
    property string dataState: "missing"
    property string maximumState: "missing"
    property real hudScale: 1
    property real topLeft: 0
    property real topRight: width
    property real bottomLeft: 0
    property real bottomRight: width
    readonly property int cellCount: typeof maximum === "number" && Number.isFinite(maximum) && maximum > 0
        && Number.isFinite(pointsPerCell) && pointsPerCell > 0 && maximumState !== "missing"
        && Math.ceil(maximum / pointsPerCell) <= 64 ? Math.ceil(maximum / pointsPerCell) : 0
    clip: true
    Accessible.ignored: true
    onSourceChanged: drawing.refreshImage()
    onCellCountChanged: drawing.requestPaint()
    onMaximumChanged: drawing.requestPaint()
    onPointsPerCellChanged: drawing.requestPaint()
    onFractionChanged: drawing.requestPaint()
    onDataStateChanged: drawing.requestPaint()
    onMaximumStateChanged: drawing.requestPaint()
    onBlueChanged: drawing.requestPaint()
    onDefeatedChanged: drawing.requestPaint()
    onInvulnerableChanged:drawing.requestPaint()
    onRuneActiveChanged:drawing.requestPaint()
    onHudScaleChanged: drawing.requestPaint()
    onTopLeftChanged: drawing.requestPaint()
    onTopRightChanged: drawing.requestPaint()
    onBottomLeftChanged: drawing.requestPaint()
    onBottomRightChanged: drawing.requestPaint()
    // 用真实大画布缩回原槽；canvasSize不是纹理分辨率，不能仅放大坐标后溢出槽位。
    Canvas {
        id: drawing
        width: root.width*4; height: root.height*4
        scale: 0.25
        transformOrigin: Item.TopLeft
        Accessible.ignored: true
        property url loadedSource: ""
        function refreshImage() {
            if (!available) return;
            if (loadedSource.toString() && loadedSource !== root.source) unloadImage(loadedSource);
            loadedSource=root.source;
            if (root.source.toString()) loadImage(root.source);
            requestPaint();
        }
        onAvailableChanged: if (available) refreshImage()
        onImageLoaded: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        function cellPath(c,start,end) {
            // 分格沿原四边形插值，两端外缘完整贴槽，不因格宽或部分血量改变斜率。
            const topSpan=root.topRight-root.topLeft,bottomSpan=root.bottomRight-root.bottomLeft;
            c.beginPath();c.moveTo(root.topLeft+topSpan*start,0);
            c.lineTo(root.topLeft+topSpan*end,0);
            c.lineTo(root.bottomLeft+bottomSpan*end,root.height);
            c.lineTo(root.bottomLeft+bottomSpan*start,root.height);c.closePath();
        }
        onPaint: {
            const c=getContext("2d");c.reset();c.scale(4,4);
            if (!root.cellCount || !isImageLoaded(root.source) || root.width<=0 || root.height<=0) return;
            const fraction=Number.isFinite(root.fraction)?Math.max(0,Math.min(1,root.fraction)):0;
            const gap=Math.min(0.8/Math.max(0.1,root.hudScale),root.width/root.cellCount*0.2);
            cellPath(c,0,1);c.clip();
            const health=fraction*root.maximum;
            for (let i=0;i<root.cellCount;++i) {
                // 末格按真实容量计宽，450上限的末格50HP，不能补成500。
                const capacity=Math.min(root.pointsPerCell,root.maximum-i*root.pointsPerCell);
                const progress=Math.max(0,Math.min(1,(health-i*root.pointsPerCell)/capacity));
                const near=i*root.pointsPerCell/root.maximum;
                const far=(i*root.pointsPerCell+capacity)/root.maximum;
                const left=root.blue?1-far:near,right=root.blue?1-near:far;
                // 只在格间留缝，首尾不再留半个间隙，满血时与原槽两端齐平。
                const start=left===0?0:left+gap/(2*root.width);
                const end=right===1?1:right-gap/(2*root.width);
                c.save();cellPath(c,start,end);c.clip();
                c.globalAlpha=root.defeated ? 0.8 : root.maximumState === "fresh" ? 0.18 : 0.09;
                // 原660×24条的实心主体只有y11..12，缩整图会漏采样使HP消失。
                c.drawImage(root.source,0,11,660,2,0,0,root.width,root.height);
                c.globalCompositeOperation="source-atop";c.fillStyle="#dd90998f";c.fillRect(0,0,root.width,root.height);
                c.restore();
                if (root.maximumState !== "fresh" || root.dataState === "missing" || progress<=0) continue;
                c.save();
                const fillWidth=(end-start)*progress;
                const fillStart=root.blue?end-fillWidth:start;
                cellPath(c,fillStart,fillStart+fillWidth);c.clip();
                c.globalAlpha=root.dataState === "fresh" ? 0.95 : 0.35;
                c.drawImage(root.source,0,11,660,2,0,0,root.width,root.height);
                if(root.runeActive && !root.defeated) {
                    c.globalCompositeOperation="source-atop";c.fillStyle="#c8ef9c";c.fillRect(0,0,root.width,root.height);
                }
                c.restore();
            }
            if(root.invulnerable && root.dataState==="fresh" && !root.defeated) {
                c.beginPath();c.moveTo(root.topLeft+.5,.5);c.lineTo(root.topRight-.5,.5);
                c.lineTo(root.bottomRight-.5,root.height-.5);c.lineTo(root.bottomLeft+.5,root.height-.5);c.closePath();
                c.strokeStyle="#efd36f";c.lineWidth=Math.min(root.height*.3,1/Math.max(.1,root.hudScale));c.stroke();
            }
        }
    }
}
