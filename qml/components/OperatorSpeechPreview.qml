import QtQuick

QtObject {
    id: root
    property string visual: "idle"
    property string phase: "idle"
    property int queued: 0
    property int dropped: 0
    property bool playback: false
    property var audio: ({})
    property string note: ""
    readonly property string speechStatus: phase === "disabled" ? "未启用 · 离线样例" : phase === "error" ? "离线样例：音频未生成"
        : phase === "busy" ? "离线演示：正在绘制合成状态" : phase === "playing" ? "离线演示：正在绘制播放状态"
        : note || "待命 · 离线绘制样例"
    readonly property var speechDetails: visual === "unknown" ? ({}) : ({active: phase !== "disabled", engine: "离线示例引擎", voice: "中文显示样例", busy: ["busy", "playing"].includes(phase), queued: queued, dropped: dropped, playback: playback, keyed_cancellation: true, last_audio: audio})
    onVisualChanged: reset()
    Component.onCompleted: reset()
    function reset() {
        finish.stop(); note = ""; queued = 0; dropped = 0; playback = ["playback", "playing"].includes(visual); audio = {};
        phase = visual === "queued" ? "busy" : visual === "complete" || visual === "playback" || visual === "unknown" ? "idle" : visual;
        if (visual === "queued") { queued = 3; dropped = 2; }
        if (["complete", "playback", "playing"].includes(visual)) audio = sampleAudio();
    }
    function sampleAudio() { return {format: "pcm", sample_rate: 22050, channels: 1, bit_depth: 16, frames: 39690, duration_ms: 1800}; }
    function submit() {
        if (phase === "disabled" || visual === "unknown") return;
        if (["busy", "playing"].includes(phase)) queued += 1;
        else { phase = "busy"; finish.restart(); }
        note = "";
    }
    function stop() { finish.stop(); phase = "idle"; queued = 0; note = "离线演示：已停止并清空样例队列"; }
    property Timer finish: Timer {
        interval: 1800
        onTriggered: {
            root.audio = root.sampleAudio();
            if (root.playback && root.phase === "busy") { root.phase = "playing"; restart(); }
            else if (root.queued > 0) { root.queued -= 1; root.phase = "busy"; restart(); }
            else { root.phase = "idle"; root.note = "离线演示：样例状态已完成，未生成或播放音频"; }
        }
    }
}
