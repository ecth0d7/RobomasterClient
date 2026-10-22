import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "OperatorData.js" as Data
import "UiFormat.js" as Format
import "OperatorStatusData.js" as Status

FocusScope {
    id: root
    objectName: "statusTable"
    property var telemetry: null
    property int clientID: 0
    property bool previewOnly: false
    property bool heldOpen: false
    property var projectionItems: []
    property double drawingNow: Date.now()
    signal closeRequested
    width: 1120
    height: 620
    readonly property var healthArray: telemetry?.globalUnit?.robot_health
    readonly property string healthTotal: {
        const values = healthArray && typeof healthArray.length === "number" ? Array.from(healthArray) : [];
        if (Data.state(telemetry,"globalUnit","robot_health") !== "fresh"
            || values.length !== 10 || !values.slice(0,5).every(v => Number.isSafeInteger(v) && v >= 0)) return "—";
        return String(values.slice(0,5).reduce((sum,value) => sum+value,0));
    }
    function reading(robot,key) { return Status.reading(telemetry,clientID,robot,key,projectionItems,drawingNow,previewOnly); }
    onProjectionItemsChanged: drawingNow = Date.now()
    onVisibleChanged: { if (visible) { drawingNow=Date.now();forceActiveFocus(); } else heldOpen=false; }
    Timer { interval: 500; repeat: true; running: root.visible; onTriggered: root.drawingNow=Date.now() }
    Keys.onEscapePressed: event => { event.accepted=true;root.closeRequested(); }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Tab && heldOpen && !event.isAutoRepeat) { event.accepted=true;root.closeRequested(); }
    }
    Connections {
        target: root.Window.window
        function onActiveChanged() { if(root.heldOpen && root.Window.window?.active !== true)root.closeRequested(); }
    }
    Rectangle {
        anchors.fill: parent; radius: 3
        gradient: Gradient {
            GradientStop { position: 0; color: "#e524211f" }
            GradientStop { position: 1; color: "#fa071011" }
        }
        border.width: 1; border.color: "#74535754"
    }
    Image {
        x: (parent.width-width)/2-8; y: 32; width: 350; height: 47
        source: "../resources/player/tab/tab_header_hurt.png"
        fillMode: Image.Stretch; mipmap: true
        OperatorText { x: 45; width: 85; height: parent.height; text: Status.damage(root.telemetry,root.clientID,false).text; size: 29; minimumSize: 0; numeric: true; color: Theme.red; horizontalAlignment: Text.AlignHCenter }
        OperatorText { x: parent.width-130; width: 85; height: parent.height; text: Status.damage(root.telemetry,root.clientID,true).text; size: 29; minimumSize: 0; numeric: true; color: Theme.blue; horizontalAlignment: Text.AlignHCenter }
    }
    OperatorText { x: parent.width-338; y: 39; width: 142; height: 30; text: "机器人总剩余血量"; size: 12; minimumSize: 0; horizontalAlignment: Text.AlignRight }
    OperatorText { x: parent.width-184; y: 39; width: 65; height: 30; text: root.healthTotal; size: 18; minimumSize: 0; numeric: true; fontSizeMode: Text.Fit; minimumPixelSize: 10; color: root.clientID>100 ? Theme.blue : Theme.red }
    Image { x: parent.width-110; y: 41; width: 26; height: 26; source: "../resources/player/silo/silo_icon_darts.png"; fillMode: Image.PreserveAspectFit; mipmap: true }
    OperatorText {
        x: parent.width-79; y: 39; width: 64; height: 30; text: "— | —"; size: 13; minimumSize: 0; numeric: true
        HoverHandler { id: dartHover }
        ToolTip.visible: dartHover.hovered
        ToolTip.text: "当前协议未提供飞镖命中数和总数"
    }
    Row {
        x: 14; y: 124; width: parent.width-28; spacing: 14
        Repeater {
            model: [false,true]
            Item {
                id: team
                required property bool modelData
                readonly property bool allied: modelData === (root.clientID>100)
                readonly property var roles: Status.roles(modelData,root.clientID)
                readonly property real columnWidth: (width-240)/4
                readonly property int rowHeight: roles.length>6 ? 52 : 58
                width: (parent.width-14)/2
                height: root.height-138
                OperatorText { x: 18; width: 30; height: 24; text: "#"; size: 11; minimumSize: 0; horizontalAlignment: Text.AlignHCenter; color: Theme.muted }
                OperatorText { x: 90; width: 144; height: 24; text: "机器人信息"; size: 11; minimumSize: 0; horizontalAlignment: Text.AlignHCenter; color: Theme.muted }
                Row {
                    x: 240; width: parent.width-240
                    Repeater {
                        model: ["底盘功率上限","热量上限","热量冷却","射速上限"]
                        OperatorText { required property string modelData; width: team.columnWidth; height: 24; text: modelData; size: 10; minimumSize: 0; horizontalAlignment: Text.AlignHCenter; color: Theme.muted }
                    }
                }
                Rectangle { y: 32; width: parent.width; height: 3; color: team.modelData ? Theme.blue : Theme.red }
                Column {
                    y: 43; width: parent.width; spacing: 6
                    Repeater {
                        model: team.roles
                        Item {
                            id: robot
                            required property int modelData
                            readonly property int robotID: modelData+(team.modelData ? 100 : 0)
                            objectName: "statusRobot"+robotID
                            readonly property bool allied: team.allied
                            readonly property var health: root.reading(robotID,"current_health")
                            readonly property var maximum: root.reading(robotID,"max_health")
                            readonly property var level: root.reading(robotID,"level")
                            readonly property bool ratioKnown: team.allied && health.state === "fresh" && maximum.state === "fresh"
                                && maximum.value>0 && health.value>=0 && health.value<=maximum.value
                            width: parent.width; height: team.rowHeight
                            Rectangle { anchors.fill: parent; color: "#87222928"; border.width: 1; border.color: "#98404b4a" }
                            Image {
                                x: 14; y: (parent.height-height)/2; width: 24; height: 24
                                source: "../resources/player/my_robot/"+(team.modelData ? "blue" : "red")+"_statusbar_id_border.png"
                                fillMode: Image.PreserveAspectFit; mipmap: true
                                OperatorText { anchors.fill: parent; text: robot.modelData; size: 12; minimumSize: 0; numeric: true; horizontalAlignment: Text.AlignHCenter }
                            }
                            Item {
                                x: 49; y: (parent.height-height)/2; width: 52; height: 54; clip: true
                                OperatorRobotPortrait { assetScale: 0.4; clientID: robot.robotID; defeated: robot.health.state === "fresh" && robot.health.value===0 }
                            }
                            Image {
                                x: 112; y: 5; width: 15; height: 18
                                visible: team.allied && robot.level.state === "fresh" && robot.level.value>=1 && robot.level.value<=10
                                source: visible ? "../resources/player/top_robots/levels/tab_level_"+robot.level.value+".png" : ""
                                fillMode: Image.PreserveAspectFit; mipmap: true
                            }
                            OperatorText { x: 130; y: 5; width: 101; height: 18; text: [3,4,5].includes(robot.modelData) ? "步兵" : Format.role(robot.robotID); size: 12; minimumSize: 0 }
                            Rectangle {
                                x: 112; y: 29; width: 112; height: 6; radius: 2
                                color: "#354342"; visible: robot.ratioKnown
                                Rectangle { width: parent.width*Data.fraction(robot.health.value,robot.maximum.value); height: parent.height; radius: 2; color: team.modelData ? Theme.blue : Theme.red }
                            }
                            OperatorText {
                                x: 105; y: 38; width: 126; height: 16
                                objectName: "statusHealth"+robot.robotID
                                text: !team.allied || !Number.isFinite(robot.health.value) || robot.health.state === "missing" ? "—" : robot.health.text+" / "+robot.maximum.text
                                size: 10; minimumSize: 0; numeric: true; fontSizeMode: Text.Fit; minimumPixelSize: 8; horizontalAlignment: Text.AlignHCenter
                            }
                            Row {
                                x: 240; width: parent.width-240; height: parent.height
                                Repeater {
                                    model: ["max_power","max_heat","heat_cooldown_rate","maximum_fire_rate"]
                                    OperatorText {
                                        required property string modelData
                                        objectName: "statusValue"+robot.robotID+"_"+modelData
                                        readonly property var reading: root.reading(robot.robotID,modelData)
                                        width: team.columnWidth; height: parent.height
                                        text: team.allied ? reading.text : "—"
                                        size: 17; minimumSize: 0; numeric: true; fontSizeMode: Text.Fit; minimumPixelSize: 10; horizontalAlignment: Text.AlignHCenter
                                        color: reading.state === "fresh" ? Theme.text : Theme.muted
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
