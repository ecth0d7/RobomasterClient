import QtQuick
import QtQuick.Controls

Item {
    id:root
    property string description:""
    property bool remote:false
    property bool confirmationEnabled:false
    signal accepted
    signal rejected
    implicitWidth:246
    implicitHeight:138
    Rectangle {anchors.fill:parent;color:"#131b18";border.color:"#8cb0b8af";border.width:1;radius:3}
    OperatorText {x:16;y:17;width:parent.width-32;height:65;text:root.description;size:14;minimumSize:0;wrapMode:Text.WordWrap;elide:Text.ElideNone;horizontalAlignment:Text.AlignHCenter}
    Row {
        x:24;y:98;spacing:18
        Button {
            objectName:"exchangeConfirmYes"
            width:90;height:27;enabled:root.confirmationEnabled
            background:Rectangle {color:parent.hovered && parent.enabled ? "#354a46" : "#1e2828";border.width:1;border.color:parent.activeFocus ? Theme.actionGreen : "#8ea8adad";radius:2}
            contentItem:OperatorText {text:root.remote ? "Y  确定" : "是";size:13;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:parent.enabled ? root.remote ? Theme.actionGreen : Theme.text : Theme.muted}
            onClicked:root.accepted()
        }
        Button {
            objectName:"exchangeConfirmNo"
            width:90;height:27
            background:Rectangle {color:parent.hovered ? "#35403b" : "#1e2828";border.width:1;border.color:parent.activeFocus ? Theme.actionGreen : "#8ea8adad";radius:2}
            contentItem:OperatorText {text:root.remote ? "N  取消" : "否";size:13;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:root.remote ? Theme.red : Theme.text}
            onClicked:root.rejected()
        }
    }
}
