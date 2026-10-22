import QtQuick
import QtQuick.Controls
import QtQuick.Window

FocusScope {
    id: root
    objectName: "operatorBootSequence"
    property string connectionStatus: "未连接"
    property string videoStatus: "等待码流"
    property real time: 0
    property bool finished: false
    property bool forcePlayback: false
    readonly property real opening: Math.max(0, Math.min(1, (time-3550)/850))
    signal completed
    clip: true
    focus: true
    function finish() {
        if (finished) return;
        finished = true;
        sequence.stop();
        completed();
    }
    Component.onCompleted: {
        if (Theme.reducedMotion || !forcePlayback && !Theme.startupAnimationEnabled) Qt.callLater(root.finish);
        else { forceActiveFocus(); sequence.start(); }
    }
    Connections {
        target: root.Window.window
        function onActiveChanged() {
            if (!root.finished && root.Window.window?.active) root.forceActiveFocus();
        }
        function onActiveFocusItemChanged() {
            if (!root.finished && root.Window.window?.active && !root.activeFocus)
                Qt.callLater(root.forceActiveFocus);
        }
    }
    Connections { target: Theme; function onReducedMotionChanged() { if (Theme.reducedMotion) root.finish(); } }
    NumberAnimation { id: sequence; target: root; property: "time"; from: 0; to: 4450; duration: 4450; onFinished: root.finish() }
    Keys.onShortcutOverride: event => event.accepted = true
    Keys.onPressed: event => {
        if ([Qt.Key_Escape,Qt.Key_Return,Qt.Key_Enter,Qt.Key_Space].includes(event.key)) root.finish();
        event.accepted = true;
    }
    Keys.onReleased: event => event.accepted = true
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.finish()
        onWheel: wheel => wheel.accepted = true
    }
    Repeater {
        model: 2
        Item {
            required property int index
            x: 0; y: index ? root.height/2 : 0
            width: root.width; height: root.height/2
            clip: true
            transform: Translate { y: (index ? 1 : -1)*root.opening*root.opening*(root.height/2+16) }
            OperatorBootStage {
                width: root.width; height: root.height; y: parent.index ? -root.height/2 : 0
                time: root.time
                connectionStatus: root.connectionStatus
                videoStatus: root.videoStatus
            }
        }
    }
    Rectangle {
        x: 0; y: root.height/2-1
        width: root.width; height: 2
        color: "#a3debf"
        opacity: root.time>=3380 && root.time<3710 ? .9 : 0
    }
    OperatorButton {
        objectName: "skipBootSequence"
        x: parent.width-width-22; y: 18; width: 124; height: 36
        text: "跳过 / Esc"
        textColor: root.time<600 ? Theme.text : "#182522"
        background: Rectangle {
            color: root.time<600 ? "#c0182522" : "#dce9e9df"
            border.color: root.time<600 ? Theme.accent : "#66334437"
        }
        opacity: 1-root.opening
        onClicked: root.finish()
    }
}
