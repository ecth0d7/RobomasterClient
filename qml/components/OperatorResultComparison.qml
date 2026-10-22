import QtQuick
import "OperatorResultData.js" as Result

Item {
    id:root
    required property var entry
    implicitWidth:540
    implicitHeight:72
    Repeater {
        model:[false,true]
        Item {
            id:side
            required property bool modelData
            readonly property var reading:modelData?root.entry.blue:root.entry.red
            readonly property var other:modelData?root.entry.red:root.entry.blue
            width:(root.width-180)/2;height:root.height
            x:modelData?root.width-width:0
            OperatorText {
                objectName:side.modelData?"resultBlueValue":"resultRedValue"
                anchors.fill:parent;anchors.bottomMargin:28
                text:side.reading.text;numeric:true;size:21
                color:side.reading.state==="fresh"?"#bdf9ee":Theme.muted
                horizontalAlignment:side.modelData?Text.AlignLeft:Text.AlignRight
                fontSizeMode:Text.Fit;minimumPixelSize:12
            }
            Rectangle {
                visible:root.entry.bars
                x:side.modelData?0:parent.width-width;y:39
                width:parent.width*Result.barRatio(side.reading,side.other);height:7
                color:"#9cfff0"
                opacity:side.modelData ? .95 : .52
            }
        }
    }
    Image {
        anchors.horizontalCenter:parent.horizontalCenter;y:3;width:24;height:24
        source:root.entry.icon?"../resources/player/message/"+root.entry.icon:""
        fillMode:Image.PreserveAspectFit;mipmap:true
    }
    OperatorText {
        anchors.horizontalCenter:parent.horizontalCenter;y:0;width:80;height:30
        text:root.entry.glyph??"";size:20;numeric:true;horizontalAlignment:Text.AlignHCenter
    }
    OperatorText {
        anchors.horizontalCenter:parent.horizontalCenter;y:32;width:180;height:28
        text:root.entry.label;size:17;color:Theme.muted;horizontalAlignment:Text.AlignHCenter
    }
}
