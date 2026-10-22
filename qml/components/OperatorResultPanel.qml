import QtQuick
import QtQuick.Controls
import "OperatorData.js" as Data
import "OperatorResultData.js" as Result

Item {
    id:root
    property var telemetry:null
    property int clientID:0
    readonly property var outcome:Result.result(telemetry,clientID)
    readonly property var comparisons:Result.comparisons(telemetry,clientID)
    implicitWidth:1200
    implicitHeight:700
    Accessible.role:Accessible.Pane
    Accessible.name:"比赛结算，"+outcome.title+"，"+outcome.reason

    // 对齐手册的双侧切角、下沿切口；原包未导出结算底板，使用原生几何适配。
    Canvas {
        anchors.fill:parent
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        onPaint:{
            const c=getContext("2d");c.reset();
            c.beginPath();c.moveTo(22,0);c.lineTo(width-22,0);c.lineTo(width,26);
            c.lineTo(width,height-34);c.lineTo(width-22,height);c.lineTo(width*.74,height);
            c.lineTo(width*.73,height-12);c.lineTo(width*.27,height-12);c.lineTo(width*.26,height);
            c.lineTo(22,height);c.lineTo(0,height-34);c.lineTo(0,26);c.closePath();
            const g=c.createLinearGradient(0,0,width,height);g.addColorStop(0,"#292726");g.addColorStop(1,"#081316");
            c.fillStyle=g;c.fill();
        }
    }
    Rectangle {x:5;y:66;width:3;height:root.height-144;color:Theme.red;opacity:.6}
    Rectangle {x:root.width-8;y:66;width:3;height:root.height-144;color:Theme.blue;opacity:.6}
    Item {
        x:root.outcome.winner===1?35:root.width-280;y:30;width:240;height:90
        visible:!root.outcome.neutral
        Image {anchors.fill:parent;source:"../resources/engine-137/sprites/ServerUI_Winner.png";fillMode:Image.PreserveAspectFit;opacity:.35;Accessible.name:"胜方"}
    }
    OperatorText {
        x:root.width/2-90;y:25;width:180;height:30
        text:"Round "+Result.reading(root.telemetry,"gameStatus","current_round").text+"/"+Result.reading(root.telemetry,"gameStatus","total_rounds").text
        numeric:true;size:17;horizontalAlignment:Text.AlignHCenter
        fontSizeMode:Text.Fit;minimumPixelSize:10
    }
    OperatorText {x:root.width/2-100;y:61;width:200;height:25;text:"Round Duration";size:15;color:Theme.muted;horizontalAlignment:Text.AlignHCenter}
    OperatorText {objectName:"resultDuration";x:root.width/2-100;y:86;width:200;height:32;text:Result.duration(root.telemetry);size:26;numeric:true;horizontalAlignment:Text.AlignHCenter}
    Repeater {
        model:[false,true]
        Item {
            id:team
            required property bool modelData
            readonly property int offset:modelData?100:0
            x:modelData?root.width/2+100:root.width/2-310;y:46;width:210;height:80
            Image {x:team.modelData?110:0;width:76;height:76;source:"../resources/player/"+(team.modelData?"blue":"red")+"_team_logo.png";fillMode:Image.PreserveAspectFit;mipmap:true}
            OperatorText {
                x:team.modelData?0:90;width:90;height:76
                text:Result.reading(root.telemetry,"gameStatus",team.modelData?"blue_score":"red_score").text
                size:48;numeric:true;color:team.modelData?Theme.blue:Theme.red;horizontalAlignment:Text.AlignHCenter
                fontSizeMode:Text.Fit;minimumPixelSize:14
            }
        }
    }
    Repeater {
        model:[false,true]
        Item {
            id:robots
            required property bool modelData
            readonly property int offset:modelData?100:0
            x:modelData?root.width-245:45;y:150;width:200;height:440
            OperatorText {x:robots.modelData?0:82;width:118;height:32;text:"单兵伤害量";size:16;color:Theme.muted;horizontalAlignment:robots.modelData?Text.AlignRight:Text.AlignLeft}
            Repeater {
                model:[1,3,4,6,7]
                Item {
                    id:robot
                    required property int modelData
                    required property int index
                    readonly property int robotID:modelData+robots.offset
                    objectName:"resultRobot"+robotID
                    y:38+index*76;width:200;height:68
                    Image {x:robots.modelData?132:0;width:68;height:68;source:Data.portrait(robot.robotID);fillMode:Image.PreserveAspectFit;mipmap:true}
                    OperatorText {x:robots.modelData?174:4;y:44;width:22;height:24;text:String(robot.modelData);size:15;numeric:true;horizontalAlignment:Text.AlignHCenter}
                    OperatorText {x:robots.modelData?0:82;width:118;height:68;text:"—";size:23;numeric:true;color:Theme.muted;horizontalAlignment:robots.modelData?Text.AlignRight:Text.AlignLeft}
                }
            }
        }
    }
    Column {
        x:root.width/2-270;y:150;width:540;spacing:3
        Repeater {model:root.comparisons;OperatorResultComparison {required property var modelData;entry:modelData;width:540;height:72}}
    }
    OperatorText {
        objectName:"resultReason"
        x:70;y:616;width:root.width-140;height:28;text:root.outcome.reason;size:18;color:Theme.muted;horizontalAlignment:Text.AlignHCenter
    }
    OperatorText {
        x:70;y:650;width:root.width-140;height:26;text:"— 表示未提供成绩　　按 Esc 关闭面板";size:16;color:Theme.muted;horizontalAlignment:Text.AlignHCenter
    }
}
