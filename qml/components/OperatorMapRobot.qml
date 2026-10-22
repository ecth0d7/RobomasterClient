import QtQuick
import QtQuick.Window
import QtQuick.Effects

Item {
    id:root
    property int robotId:0
    property bool self:false
    property bool highlighted:false
    property bool dead:false
    property bool locationOffline:false
    property var heading:null
    property string dataState:"fresh"
    readonly property int role:robotId%100
    readonly property string team:self?"self":robotId>100?"blue":"red"
    readonly property bool special:role===6 || role===7
    readonly property real hudScale:Window.window?.ui?.layoutScale??1
    opacity: dead ? 0.25 : (locationOffline || dataState !== "fresh" ? 0.45 : 1)
    Image {
        anchors.centerIn:parent;width:parent.width*1.5;height:width*82/90
        source:"../resources/player/minimap/map_robot_lockline.png"
        fillMode:Image.PreserveAspectFit;mipmap:true;visible:root.highlighted
    }
    Image {
        anchors.fill:parent;fillMode:Image.PreserveAspectFit;mipmap:true
        source:"../resources/player/minimap/"+(root.special?(root.robotId>100?"blue":"red"):root.team)
            +(root.role===6?"_map_airplane.png":root.role===7?"_map_guard.png":root.highlighted?"_map_robot_lockbg.png":"_map_robot.png")
        layer.enabled:root.self && root.special
        layer.effect:MultiEffect {colorization:1;colorizationColor:"#00e1a0"}
    }
    OperatorMapHeading {
        anchors.fill:parent;team:root.team
        angle:root.heading?.yaw_deg??null
        dataState:root.locationOffline?"missing":root.heading?.state??"missing"
        clockwise:root.heading?.clockwise??true
    }
    Image {
        anchors.centerIn:parent
        height:Math.min(parent.height*.85,Math.max(parent.height*.65,10/Math.max(.1,root.hudScale)))
        width:height*2/3
        source:root.role>=1 && root.role<=5?"../resources/player/minimap/map_robot_id_"+root.role+".png":""
        visible:!root.special;fillMode:Image.PreserveAspectFit;mipmap:true
    }
}
