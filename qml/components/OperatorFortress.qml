import QtQuick
import QtQuick.Controls
import "OperatorFortressData.js" as FortressData

// 七月手册p05：区域保持所属阵营色；占领环使用相反阵营色并顺时针增长。
Item {
    id: root
    property var telemetry: null
    property int clientID: 0
    property bool blue: false
    property bool previewOnly: false
    property var progressScale: null
    readonly property var reading: FortressData.occupation(telemetry,clientID,blue)
    readonly property var maximumSeconds: FortressData.scaleSeconds(progressScale,previewOnly)
    readonly property bool occupied: reading?.occupied === true
    readonly property real progress: occupied && maximumSeconds !== null ? Math.min(1,reading.seconds/maximumSeconds) : 0
    property real displayedProgress: progress
    Behavior on displayedProgress { NumberAnimation { duration:Theme.reducedMotion?0:150; easing.type:Easing.OutCubic } }
    property color ownerColor: blue ? Theme.blue : Theme.red
    property color occupierColor: blue ? Theme.red : Theme.blue
    readonly property string description: (previewOnly ? "mock · " : "") + (blue ? "蓝方" : "红方")
        + "堡垒，" + (occupied ? (blue ? "红方" : "蓝方") + "占领计时 " + reading.seconds + "秒" : "当前无被对方占领计时")
        + "；GlobalSpecialMechanism / MQTT"
        + (maximumSeconds !== null ? "；显示整圈尺度 " + maximumSeconds + "秒 / " + progressScale.source_kind : "；未取得显示尺度，不绘制进度环")
    width: 58
    height: 74
    visible: occupied
    Accessible.role: Accessible.StaticText
    Accessible.name: description
    Canvas {
        id: drawing
        width: 58 * 4; height: 54 * 4
        scale: 0.25; transformOrigin:Item.TopLeft
        Accessible.ignored: true
        Connections {
            target: root
            function onBlueChanged() { drawing.requestPaint(); }
            function onOwnerColorChanged() { drawing.requestPaint(); }
            function onOccupierColorChanged() { drawing.requestPaint(); }
            function onOccupiedChanged() { drawing.requestPaint(); }
            function onDisplayedProgressChanged() { drawing.requestPaint(); }
            function onMaximumSecondsChanged() { drawing.requestPaint(); }
        }
        onPaint: {
            const c=getContext("2d");c.reset();c.scale(4,4);
            const cx=29,cy=27;
            c.beginPath();c.arc(cx,cy,22,0,Math.PI*2);c.strokeStyle="#70606762";c.lineWidth=3;c.stroke();
            if (root.occupied && root.maximumSeconds !== null && root.displayedProgress > 0) {
                c.beginPath();c.arc(cx,cy,22,-Math.PI/2,-Math.PI/2+root.displayedProgress*Math.PI*2);
                c.strokeStyle=root.occupierColor;c.lineWidth=3;c.stroke();
            }
        }
    }
    Image {
        x:11;y:11;width:36;height:36*50/56
        source:"../resources/player/controlzone_"+(root.blue ? "blue" : "red")+"_icon.png"
        fillMode:Image.PreserveAspectFit;mipmap:true
        Accessible.ignored:true
    }
    OperatorText {
        x:0; y:54; width:parent.width; height:20
        text: root.occupied ? root.reading.seconds<10000 ? "占领 " + root.reading.seconds + "s" : Math.floor(root.reading.seconds/3600)+"h" : ""
        size:11;minimumSize:9.5;fontSizeMode:Text.Fit;minimumPixelSize:9
        horizontalAlignment:Text.AlignHCenter;color:Theme.warning
    }
    HoverHandler { id:hover }
    ToolTip.visible:hover.hovered;ToolTip.delay:450;ToolTip.text:root.description
}
