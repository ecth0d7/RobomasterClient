import QtQuick

// 同一来源连续live值才补间；零／旧／断连即停止，首次值不从0假装增长。
QtObject {
    id:root
    property var display:({ratio:0,ratioState:"none",identity:""})
    property int duration:Theme.reducedMotion?0:240
    property real fraction:0
    property bool ready:false
    property bool previousLive:false
    property string previousIdentity:""
    property real previousTarget:0
    property NumberAnimation motion:NumberAnimation {target:root;property:"fraction";duration:Theme.reducedMotion?0:root.duration;easing.type:Easing.OutCubic}
    function refresh() {
        const live=display.ratioState === "live",target=display.ratioState === "none" ? 0 : display.ratio;
        if (live && previousLive && previousIdentity === display.identity && target > 0) {
            if (target !== previousTarget) {motion.stop();motion.from=fraction;motion.to=target;motion.start();}
        } else {motion.stop();fraction=target;}
        previousLive=live;previousIdentity=display.identity;previousTarget=target;
    }
    onDisplayChanged:{
        if (!ready) return;
        if (display.ratioState !== "live" || display.ratio === 0) refresh();
        else {
            if (previousIdentity !== display.identity) {previousLive=false;motion.stop();}
            Qt.callLater(root.refresh);
        }
    }
    Component.onCompleted:{ready=true;refresh();}
}
