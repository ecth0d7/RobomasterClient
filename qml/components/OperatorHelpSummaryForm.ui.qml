import QtQuick

// 手册第26页布局，补充本客户端的协议调试与改键入口。输入和自定义绑定由行为层提供。
Item {
    id:root
    objectName:"helpSummary"
    property var entries:[]
    property string fontFamily:Theme.fontFamily
    implicitWidth:860
    implicitHeight:480
    Rectangle {
        anchors.fill:parent;radius:6;border.width:1;border.color:"#555b55"
        gradient:Gradient {GradientStop {position:0;color:"#292b28"} GradientStop {position:1;color:"#161815"}}
    }
    OperatorText {x:40;y:18;width:parent.width-80;height:32;text:"帮助提示";size:20;minimumSize:0;font.family:root.fontFamily}
    Repeater {
        model:root.entries
        Item {
            required property var modelData
            required property int index
            objectName:"helpSummaryGroup"+index
            x:42+(index%2)*((root.width-84+52)/2);y:70+Math.floor(index/2)*132
            width:(root.width-84-52)/2;height:118
            Rectangle {
                width:Math.max(38,keyLabel.implicitWidth+22);height:39;color:"#111410";radius:2
                OperatorText {id:keyLabel;anchors.centerIn:parent;text:parent.parent.modelData.key;size:19;minimumSize:0;font.family:Theme.keyFontFamily}
            }
            OperatorText {y:52;width:parent.width;height:66;text:parent.modelData.description;size:14;font.family:root.fontFamily;verticalAlignment:Text.AlignTop;wrapMode:Text.WordWrap;elide:Text.ElideNone}
        }
    }
}
