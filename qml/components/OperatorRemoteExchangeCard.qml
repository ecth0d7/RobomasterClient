import QtQuick
import QtQuick.Controls

Item {
    id:root
    required property var controller
    readonly property bool compact:controller.confirming || controller.remoteResponseVisible
    implicitWidth:compact ? 286 : 360
    implicitHeight:compact ? 156 : 266
    Rectangle {anchors.fill:parent;color:Theme.hudSurface;border.width:1;border.color:"#86a4b1a8";radius:6}
    Row {
        x:20;y:26;spacing:8;visible:!root.compact
        Repeater {
            model:[{kind:"remoteHeal",caption:"60%血量",image:"skillup_icon_blood.png"},
                {kind:"remote17",caption:"17mm弹丸",image:"17.png"},{kind:"remote42",caption:"42mm弹丸",image:"42.png"}]
            Button {
                id:option
                required property var modelData
                readonly property bool available:root.controller.reason(modelData.kind).length===0
                objectName:"remoteOption"+modelData.kind
                width:101;height:166;enabled:available;padding:0
                Accessible.name:modelData.caption+"远程兑换"
                background:Rectangle {color:option.hovered && option.enabled ? "#2547413d" : "transparent";radius:4}
                contentItem:Item {
                    Image {x:(parent.width-width)/2;y:8;width:30;height:34;source:"../resources/player/panel/"+option.modelData.image;fillMode:Image.PreserveAspectFit;mipmap:true;opacity:option.enabled ? 1 : .4}
                    OperatorText {y:60;width:parent.width;height:26;text:option.modelData.caption;size:14;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:option.enabled ? Theme.text : Theme.muted}
                    Rectangle {x:16;y:128;width:69;height:25;color:"#401a211c";radius:3
                        OperatorText {anchors.fill:parent;text:root.controller.shortcutLabel(option.modelData.kind);size:11;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:option.enabled ? Theme.actionGreen : Theme.muted}}
                }
                onClicked:root.controller.select(modelData.kind)
                ToolTip.visible:hovered && !available
                ToolTip.delay:700
                ToolTip.text:root.controller.reason(modelData.kind)
            }
        }
    }
    Button {
        objectName:"remoteExchangeClose"
        y:210;width:parent.width;height:56;visible:!root.compact
        background:Rectangle {color:parent.hovered ? Theme.hudHover : "transparent";border.color:"#667e8d82";border.width:1;radius:5}
        contentItem:OperatorText {text:"按 H 关闭远程兑换面板";size:14;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:"#bae0dd"}
        onClicked:root.controller.closeRequested()
    }
    OperatorExchangeConfirm {
        x:(parent.width-width)/2;y:(parent.height-height)/2;width:246;height:138
        visible:root.controller.confirming
        remote:true
        description:root.controller.confirmationText
        confirmationEnabled:root.controller.canConfirm
        onAccepted:root.controller.confirm()
        onRejected:root.controller.cancelSelection()
    }
    OperatorText {
        x:14;y:18;width:parent.width-28;height:parent.height-36;visible:root.controller.remoteResponseVisible
        text:root.controller.responseText;size:17;minimumSize:0;wrapMode:Text.WordWrap;elide:Text.ElideNone;horizontalAlignment:Text.AlignHCenter
        color:root.controller.responseFailed ? Theme.red : root.controller.serverResult ? Theme.actionGreen : Theme.text
    }
}
