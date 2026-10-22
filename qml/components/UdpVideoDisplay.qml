import QtQuick 6.2
import QtQuick.Window 6.2

UdpVideoForm {
    id: root
    property var receiver: null
    property int frameSequence: 0
    property bool hasReceivedFrame: false
    property bool pendingPresentation: false
    readonly property bool presentationActive: visible && (!root.Window.window
        || root.Window.window.visible && root.Window.window.visibility !== Window.Minimized)
    function presentLatest() {
        pendingPresentation = false;
        frameSequence = frameSequence === 2147483647 ? 0 : frameSequence + 1;
        const provider = typeof receiver?.imageProvider === "string" ? receiver.imageProvider : "videoProvider";
        videoDisplay.source = "image://" + provider + "/latest?frame=" + frameSequence;
    }
    onPresentationActiveChanged: {
        if (presentationActive && pendingPresentation && hasReceivedFrame) presentLatest();
    }
    property var overlayExclusions: []
    onReceiverChanged: {
        frameSequence = 0;
        hasReceivedFrame = false;
        pendingPresentation = false;
        videoDisplay.source = "";
    }
    readonly property var frameAge: receiver?.diagnostics?.last_frame_age_ms
    readonly property bool stale: receiver?.status === "画面未更新" || (typeof frameAge === "number"
                                                                   && Number.isFinite(frameAge)
                                                                   && frameAge > 2000)
    opacity: stale ? 0.45 : 1.0

    OperatorVisionOverlay {
        id: visionOverlay
        rotate180: Math.abs(root.videoDisplay.rotation % 360) === 180
        z: 20
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: root.videoDisplay.paintedWidth
        height: root.videoDisplay.paintedHeight
        visible: typeof battlefieldHost !== "undefined" && battlefieldHost !== null
            && typeof videoReceiver !== "undefined" && root.receiver === videoReceiver
            && root.hasReceivedFrame && !root.stale
        boxes: visible ? battlefieldHost.view.boxes ?? [] : []
        exclusions: root.overlayExclusions.map(r => ({x:r.x-visionOverlay.x, y:r.y-visionOverlay.y, w:r.w, h:r.h}))
    }

    OperatorProjectileOverlay {
        id: projectileOverlay
        z: 21
        x: (parent.width-width)/2
        y: (parent.height-height)/2
        width: root.videoDisplay.paintedWidth
        height: root.videoDisplay.paintedHeight
        rotate180: Math.abs(root.videoDisplay.rotation % 360) === 180
        visible: typeof battlefieldHost !== "undefined" && battlefieldHost !== null
            && typeof heroVideoReceiver !== "undefined" && root.receiver === heroVideoReceiver
            && root.hasReceivedFrame && !root.stale
        tracks: visible ? battlefieldHost.view.projectile?.tracks ?? [] : []
        trailImage: visible ? battlefieldHost.view.projectile?.trail_image ?? "" : ""
        trailStamp: visible ? battlefieldHost.view.projectile?.trail_stamp_ms ?? 0 : 0
        exclusions: root.overlayExclusions.map(r => ({x:r.x-projectileOverlay.x,y:r.y-projectileOverlay.y,w:r.w,h:r.h}))
    }

    Connections {
        target: root.receiver
        ignoreUnknownSignals: true
        function onStreamReset() {
            root.frameSequence=0;root.hasReceivedFrame=false;root.pendingPresentation=false;root.videoDisplay.source="";
        }
        function onFrameReady() {
            root.hasReceivedFrame = true;
            // 隐藏时只保留最新帧意图，恢复后再更新纹理；解码及视觉订阅不受影响。
            if (root.presentationActive) root.presentLatest();
            else root.pendingPresentation = true;
        }
    }
}
