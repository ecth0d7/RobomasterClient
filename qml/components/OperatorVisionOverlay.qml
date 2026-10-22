import QtQuick
import QtQuick.Window
import "OperatorVisionIdentityData.js" as Identity

Canvas {
    id: root
    property var boxes: []
    property var exclusions: []
    property bool rotate180: false
    property int clientID: typeof clientBackend === "undefined" || !clientBackend.connected ? 0 : clientBackend.clientId
    readonly property bool presentationActive: visible && (!root.Window.window
        || root.Window.window.visible && root.Window.window.visibility !== Window.Minimized)
    function refreshPresentation() {
        if (presentationActive) requestPaint();
    }
    onPresentationActiveChanged: refreshPresentation()
    onBoxesChanged: refreshPresentation()
    onExclusionsChanged: refreshPresentation()
    onRotate180Changed: refreshPresentation()
    onClientIDChanged: refreshPresentation()
    onWidthChanged: refreshPresentation()
    onHeightChanged: refreshPresentation()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const occupied = root.exclusions.slice();
        function overlaps(r) {
            return occupied.some(o => r.x < o.x+o.w && r.x+r.w > o.x && r.y < o.y+o.h && r.y+r.h > o.y);
        }
        for (const box of root.boxes) {
            const source = box.bbox;
            if (!source || source.length !== 4) continue;
            const b = root.rotate180 ? [1-source[0]-source[2], 1-source[1]-source[3], source[2], source[3]] : source;
            const x = b[0] * width, y = b[1] * height;
            const w = b[2] * width, h = b[3] * height;
            const color = box.team === "red" ? "#fc7568" : box.team === "blue" ? "#5bcefa" : "#f4df6a";
            ctx.strokeStyle = color;
            ctx.lineWidth = box.confirmed && !box.occluded ? 2 : 1;
            ctx.setLineDash(box.occluded || !box.confirmed ? [5, 4] : []);
            ctx.strokeRect(x, y, w, h);
            ctx.setLineDash([]);
            const state = box.occluded ? "遮挡/旧帧" : box.confirmed ? "视觉估计" : "候选";
            const label = Identity.relation(box.team, root.clientID) + " · "
                + (box.team === "red" ? "红 " : box.team === "blue" ? "蓝 " : "未知 ")
                + (box.label ?? "目标") + " #" + box.track_id + " · " + Math.round(box.confidence * 100)
                + "% · " + box.age_ms + "ms · " + state;
            ctx.font = "12px sans-serif";
            const labelWidth = Math.min(width, ctx.measureText(label).width + 12);
            let slot = null;
            const left = Math.max(0, Math.min(width-labelWidth, x));
            for (let n = 0; n < 16 && !slot; n++) {
                for (const candidateY of [y-24-n*24, y+h+4+n*24]) {
                    const r = {x:left, y:candidateY, w:labelWidth, h:22};
                    if (r.y >= 0 && r.y+r.h <= height && !overlaps(r)) { slot=r;break; }
                }
            }
            // Keep the rectangle when a label has no free slot; the complete trace remains in the separate window.
            if (!slot) continue;
            const lx = slot.x, ly = slot.y;
            occupied.push(slot);
            ctx.fillStyle = "#c01a2421";
            ctx.fillRect(lx, ly, labelWidth, 22);
            ctx.fillStyle = color;
            ctx.fillText(label, lx + 6, ly + 15, labelWidth - 10);
        }
    }
}
