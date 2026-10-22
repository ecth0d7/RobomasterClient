import QtQuick

QtObject {
    id: root
    property string mode: "telemetry"
    property int step: 0
    readonly property var sequence: ["live","ten","zero","paused","timer-old","stage-old","pause-missing","scores-old",
        "partial","missing","invalid","round-conflict","legacy","map-gap","offline","live"]
    readonly property string current: mode === "sequence" ? sequence[step % sequence.length] : mode
    readonly property bool connected: current !== "offline"
    property Timer drawingTimer: Timer {
        interval: 1200; repeat: true; running: root.mode === "sequence"
        onTriggered: root.step += 1
    }
    // 本对象仅供原生离线绘制，不实现比赛时钟、消息生产或遥测接收。
    readonly property var values: {
        const data = {current_round:1,total_rounds:3,red_score:0,blue_score:2,
            current_stage:4,stage_countdown_sec:300,is_paused:false};
        if (current === "missing") return {};
        if (["ten","paused","stage-old","pause-missing","pause-old"].includes(current)) data.stage_countdown_sec=10;
        if (current === "zero") { data.stage_countdown_sec=0;data.blue_score=0; }
        if (current === "paused") data.is_paused=true;
        if (current === "pause-missing") delete data.is_paused;
        if (current === "partial") { delete data.total_rounds;delete data.blue_score;delete data.is_paused; }
        if (current === "scores-old") {data.red_score=12;data.blue_score=24;}
        if (current === "invalid") { data.stage_countdown_sec=-1;data.red_score="0";data.is_paused=0;data.current_stage=77; }
        if (current === "round-conflict") data.current_round=4;
        if (current === "long" || current === "long-old") {
            data.current_round=4294967295;data.total_rounds=4294967295;
            data.red_score=4294967295;data.blue_score=4294967295;data.stage_countdown_sec=2147483647;
        }
        if (current === "stage-zero") data.current_stage=0;
        if (current === "stage-missing") delete data.current_stage;
        return data;
    }
    readonly property var fieldStates: {
        if (current === "legacy") return null;
        if (current === "map-gap") return {red_score:"fresh"};
        const result = {};
        for (const key of Object.keys(values)) result[key]="fresh";
        if (current === "stale") for (const key of Object.keys(result)) result[key]="stale";
        if (current === "timer-old") result.stage_countdown_sec="stale";
        if (current === "stage-old") result.current_stage="stale";
        if (current === "pause-old") result.is_paused="stale";
        if (current === "scores-old" || current === "long-old") {result.red_score="stale";result.blue_score="stale";}
        return result;
    }
}
