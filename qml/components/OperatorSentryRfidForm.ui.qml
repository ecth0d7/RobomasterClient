import QtQuick

// 手册第12页四角提示；没有对应独立贴图，原生线段保留其形状。
Item {
    id:root
    property bool recognized:false
    property color accent:recognized?Theme.green:Theme.red
    width:384;height:74
    Repeater {
        model:4
        Item {
            required property int index
            x:index%2===0?0:root.width-width;y:index<2?0:root.height-height
            width:24;height:24
            Rectangle {width:24;height:3;y:parent.index<2?0:21;color:root.accent}
            Rectangle {width:3;height:24;x:parent.index%2===0?0:21;color:root.accent}
        }
    }
    OperatorText {
        objectName:"sentryRfidCaption"
        x:28;width:parent.width-56;height:parent.height
        text:root.recognized?"哨兵已识别RFID":"哨兵未识别RFID"
        size:22;font.bold:true;horizontalAlignment:Text.AlignHCenter;styleColor:root.accent
    }
}
