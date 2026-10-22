import QtQuick
import QtQuick.Controls

Item {
    id: root
    property bool blue: false
    property var projection: null
    property real heightBudget: 0
    readonly property real artworkScale: Math.min(width / 154, heightBudget > 20 ? (heightBudget - 20) / 76 : width / 154)
    readonly property string freshness: projection?.state ?? "missing"
    readonly property string sourceText: projection ? (projection.source_kind === "mock" ? "mock · " : "")
        + projection.source_id + " · " + projection.snapshot_id + " · " + (projection.age_ms / 1000).toFixed(1) + "s"
        : "暂无有效重建进度 · 生产适配待接"
    implicitWidth: 154
    implicitHeight: 76 * artworkScale + 20
    Accessible.role: Accessible.StaticText
    Accessible.name: "前哨重建，队伍进度 " + progressText(projection?.team_progress,projection?.team_progress_state)
        + "，本机进度 " + progressText(projection?.robot_progress,projection?.robot_progress_state) + "，剩余重建次数 "
        + (projection?.remaining_count ?? "未知") + (projection?.remaining_count_state === "stale" ? "，旧数据" : "") + "，" + sourceText
    function progressText(value,state) { return typeof value === "number" ? Math.round(value * 100) + "%" + (state === "stale" ? " · 旧" : "") : "未知"; }
    // 原图圈/头像共用154宽设计坐标；计数文字独立留槽，缩小时仍可读。
    Item {
        width:154;height:76
        x: (root.width - width * root.artworkScale) / 2
        scale:root.artworkScale
        transformOrigin:Item.TopLeft
        Canvas {
            id: rings
            x: 39
            width: 76; height: 76
            Accessible.ignored: true
            opacity: root.freshness === "fresh" ? 0.95 : 0.4
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: root
                function onBlueChanged() { rings.requestPaint(); }
                function onProjectionChanged() { rings.requestPaint(); }
            }
            onPaint: {
                const c = getContext("2d"); c.reset();
                c.translate(width / 2, height / 2);
                const radii = [35,28], values = [root.projection?.team_progress, root.projection?.robot_progress];
                const states = [root.projection?.team_progress_state,root.projection?.robot_progress_state];
                for (let i = 0; i < 2; ++i) {
                    c.beginPath();c.arc(0,0,radii[i],0,Math.PI*2);c.strokeStyle="#805c6660";c.lineWidth=4;c.stroke();
                    if (typeof values[i] !== "number" || values[i] <= 0) continue;
                    c.globalAlpha = states[i] === "fresh" ? 1 : 0.35;
                    c.beginPath();c.arc(0,0,radii[i],-Math.PI/2,-Math.PI/2+Math.PI*2*values[i]);
                    c.strokeStyle = i === 0 ? root.blue ? Theme.blue : Theme.red : Theme.green;
                    c.stroke();c.globalAlpha=1;
                }
            }
        }
        Image {
            x: 63; y: 23; width: 28; height: 30
            source: "../resources/player/top_outpost/" + (root.blue ? "blue" : "red") + "_outpost_avatar.png"
            fillMode: Image.PreserveAspectFit; mipmap: true
            Accessible.ignored: true
        }
    }
    OperatorText {
        y: 76 * root.artworkScale; width: parent.width; height: 20
        text: "可重建 " + (root.projection?.remaining_count ?? "—") + (root.projection?.remaining_count_state === "stale" ? " · 旧" : "")
        size: 9.5; horizontalAlignment: Text.AlignHCenter
        color: root.projection?.remaining_count_state === "fresh" ? Theme.text : Theme.muted
    }
    HoverHandler { id: hover }
    ToolTip.visible: hover.hovered; ToolTip.delay: 450
    ToolTip.text: root.Accessible.name + "；外圈队伍，内圈本机。未知进度没有彩色段。"
}
