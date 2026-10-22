import QtQuick
import QtQuick.Window

Canvas {
    id: root
    property var tracks: []
    property var exclusions: []
    property bool rotate180: false
    property string trailImage: ""
    property double trailStamp: 0
    property string loadedTrail: ""
    property double presentationNow: Date.now()
    readonly property bool presentationActive: visible && (!root.Window.window
        || root.Window.window.visible && root.Window.window.visibility !== Window.Minimized)
    readonly property bool hasTimedContent: (trailImage.length > 0 && fresh(trailStamp))
        || tracks.some(track => track.points?.length >= 2 && fresh(track.stamp_ms))
    function fresh(stamp) {
        return Number.isFinite(stamp) && presentationNow >= stamp && presentationNow - stamp <= 450;
    }
    function refreshPresentation() {
        presentationNow = Date.now();
        const desired = presentationActive && fresh(trailStamp) ? trailImage : "";
        if (loadedTrail !== desired) {
            if (loadedTrail.length) unloadImage(loadedTrail);
            loadedTrail = desired;
            if (loadedTrail.length) loadImage(loadedTrail);
        }
        if (presentationActive) requestPaint();
    }
    onPresentationActiveChanged: refreshPresentation()
    onTrailStampChanged: refreshPresentation()
    // 隐藏期间只接收最新地址；恢复时仅加载仍有效的轨迹图，避免无显示需求的PNG解码。
    onTrailImageChanged: refreshPresentation()
    onImageLoaded: refreshPresentation()
    onTracksChanged: refreshPresentation()
    onExclusionsChanged: refreshPresentation()
    onRotate180Changed: refreshPresentation()
    onWidthChanged: refreshPresentation()
    onHeightChanged: refreshPresentation()
    // 失效后的最后一次重绘清空旧轨迹，随后停止计时；隐藏时保留数据而暂停绘制。
    Timer {
        interval: 60
        running: root.presentationActive && root.hasTimedContent
        repeat: true
        onTriggered: root.refreshPresentation()
    }
    onPaint: {
        const c = getContext("2d"); c.reset();
        const occupied = root.exclusions.slice();
        const now = Date.now();
        if (root.trailImage.length && now-root.trailStamp>=0 && now-root.trailStamp<=450 && isImageLoaded(root.trailImage)) {
            c.save();
            if(root.rotate180) { c.translate(width,height); c.rotate(Math.PI); }
            c.drawImage(root.trailImage,0,0,width,height);
            c.restore();
        }
        function point(p) { return {x:(root.rotate180 ? 1-p[0] : p[0])*width, y:(root.rotate180 ? 1-p[1] : p[1])*height}; }
        const shown = root.tracks.slice().sort((a,b)=>Number(b.confirmed)-Number(a.confirmed)||b.confidence-a.confidence).slice(0,6);
        let labels = 0;
        for (const track of shown) {
            if (now-track.stamp_ms > 450 || now < track.stamp_ms || !track.points || track.points.length < 2) continue;
            const color = track.confirmed ? "#62e9e0" : "#f4df6a";
            c.strokeStyle=color; c.lineWidth=2; c.setLineDash(track.confirmed ? [] : [3,4]);
            c.beginPath();
            track.points.forEach((p,i) => { const q=point(p); if(i===0)c.moveTo(q.x,q.y);else c.lineTo(q.x,q.y); });
            c.stroke(); c.setLineDash([]);
            const last=point(track.points[track.points.length-1]);
            c.beginPath(); c.arc(last.x,last.y,5,0,2*Math.PI); c.stroke();
            if (track.confirmed && track.prediction?.length===3 && now-track.stamp_ms<250) {
                const predicted=point(track.prediction); c.strokeStyle="#dda5ff"; c.setLineDash([3,4]);
                c.beginPath(); c.moveTo(last.x,last.y); c.lineTo(predicted.x,predicted.y); c.stroke(); c.setLineDash([]);
            }
            const label=(track.confirmed ? "多帧亮点轨迹·弹丸候选 #" : "运动亮点候选 #") + track.track_id
                + " · 关联评分 " + Math.round(track.confidence*100) + "% · " + (now-track.stamp_ms) + "ms";
            c.font="12px sans-serif";
            const lw=Math.min(width,c.measureText(label).width+12);let slot=null;
            for (let n=0;n<12 && !slot;n++) {
                const r={x:Math.max(0,Math.min(width-lw,last.x+12)),y:last.y-24+n*22,w:lw,h:20};
                if(r.y>=0 && r.y+r.h<=height && !occupied.some(o=>r.x<o.x+o.w && r.x+r.w>o.x && r.y<o.y+o.h && r.y+r.h>o.y))slot=r;
            }
            if(slot && labels<3) { labels++; occupied.push(slot); c.fillStyle="#b01a2421";c.fillRect(slot.x,slot.y,slot.w,slot.h);c.fillStyle=color;c.fillText(label,slot.x+6,slot.y+14,lw-10); }
        }
        // Clear line segments inside actual HUD reservations; labels were placed around them.
        for(const r of root.exclusions)c.clearRect(r.x,r.y,r.w,r.h);
    }
}
