import QtQuick
import QtQuick.Controls

Item {
    id:root
    required property var controller
    readonly property bool large:controller.supplyKind==="buy42"
    readonly property var increments:large ? [-10,-5,-2,-1,0,1,2,5,10] : [-100,-50,-20,-10,0,10,20,50,100]
    implicitWidth:620
    implicitHeight:352
    Rectangle {anchors.fill:parent;color:Theme.hudSurface;border.width:1;border.color:"#57655e";radius:5}
    OperatorText {x:28;y:20;width:parent.width-56;height:30;text:(root.large ? "42" : "17")+"mm弹丸补给面板";size:20;minimumSize:0;font.bold:true}
    Rectangle {x:18;y:64;width:parent.width-36;height:222;color:"#261a1b19";border.width:1;border.color:"#626a64";radius:2}
    OperatorText {x:42;y:86;width:parent.width-84;height:25;text:"── 已有/可兑换允许发弹量 ──";size:14;minimumSize:0;horizontalAlignment:Text.AlignHCenter}
    OperatorText {
        objectName:"supplyEligibility"
        x:42;y:117;width:parent.width-84;height:34
        text:root.controller.supplyReason || root.controller.ammoText+"/"+(root.controller.affordable===null ? "—" : root.controller.affordable)
        size:root.controller.supplyReason ? 15 : 24;minimumSize:0;font.bold:!root.controller.supplyReason.length
        horizontalAlignment:Text.AlignHCenter;color:root.controller.supplyReason ? Theme.red : Theme.text
    }
    Row {
        x:34;y:202;width:parent.width-68;height:49
        Repeater {
            model:root.increments
            Button {
                id:step
                required property int modelData
                required property int index
                objectName:modelData===0 ? "supplyQuantity" : "supplyStep"+modelData
                width:modelData===0 ? 104 : (root.width-68-104)/8;height:49;padding:0
                enabled:modelData!==0 && root.controller.supplyReason.length===0 && !root.controller.confirming
                    && (modelData<0 ? root.controller.supplyQuantity>0 : root.controller.supplyQuantity<root.controller.affordable)
                background:Rectangle {color:step.hovered && step.enabled ? Theme.hudHover : step.modelData===0 ? "#78171a18" : "#30252a27";border.width:1;border.color:step.enabled || step.modelData===0 && !root.controller.supplyReason.length ? "#adc8c9" : "#4f5b55"}
                contentItem:OperatorText {text:step.modelData===0 ? root.controller.supplyQuantity : (step.modelData>0 ? "+" : "")+step.modelData;size:step.modelData===0 ? 21 : 15;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:step.enabled || step.modelData===0 && !root.controller.supplyReason.length ? Theme.text : Theme.muted}
                onClicked:root.controller.adjustQuantity(modelData)
                // 第二次快速点击可能成为doubleClicked；该分支替代第二次clicked。
                // 保留真正Button的启用/抓取/键盘行为，每次物理点击只加减一次。
                onDoubleClicked:root.controller.adjustQuantity(modelData)
            }
        }
    }
    Button {
        id:confirmButton
        objectName:"supplyOpenConfirmation"
        x:(parent.width-width)/2;y:302;width:212;height:33;enabled:root.controller.canQuoteSupply && !root.controller.confirming
        // 引擎ServerUI白框是编辑器按钮，不能代替手册中青色补弹确认槽。
        background:Rectangle {
            radius:1;border.width:1;border.color:confirmButton.activeFocus ? "#74bfc4" : confirmButton.enabled ? "#326c72" : "#294043"
            gradient:Gradient {
                GradientStop {position:0;color:confirmButton.enabled ? "#081718" : "#111a1a"}
                GradientStop {position:.48;color:confirmButton.down ? "#245057" : confirmButton.hovered && confirmButton.enabled ? "#1d4249" : "#10282d"}
                GradientStop {position:1;color:confirmButton.enabled ? "#16444a" : "#122528"}
            }
            Rectangle {x:3;y:parent.height-3;width:parent.width-6;height:1;color:"#66b8c0";opacity:confirmButton.enabled ? .65 : .2}
        }
        contentItem:OperatorText {text:"确定";size:14;minimumSize:0;horizontalAlignment:Text.AlignHCenter;color:parent.enabled ? Theme.text : Theme.muted}
        onClicked:root.controller.select(root.controller.supplyKind)
    }
    OperatorExchangeConfirm {
        x:(parent.width-width)/2;y:87;width:246;height:156;visible:root.controller.confirming
        description:root.controller.confirmationText
        confirmationEnabled:root.controller.canConfirm
        onAccepted:root.controller.confirm()
        onRejected:root.controller.cancelSelection()
    }
}
