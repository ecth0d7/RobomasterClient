import QtQuick
import QtQuick.Effects

// 原飘字材质的独立绘制层；没有遥测、动作或计时逻辑。
Item {
    id:root
    property string caption:""
    property string team:"green"
    property int victim:0
    property int killer:0
    property url iconSource:""
    width:488;height:76
    Image {anchors.verticalCenter:parent.verticalCenter;width:parent.width;height:width*132/976;source:"../resources/player/message/message_"+root.team+".png";fillMode:Image.PreserveAspectFit;mipmap:true;opacity:.75}
    Row {
        anchors.centerIn:parent;spacing:12;visible:root.victim>0
        OperatorNoticePortrait {robotID:root.killer>0?root.killer:root.victim;defeated:root.killer===0}
        OperatorText {height:66;width:root.killer>0?60:72;text:root.caption;size:22;minimumSize:12;font.bold:true;horizontalAlignment:Text.AlignHCenter;styleColor:root.team==="blue"?"#15688f":"#852d2a"}
        OperatorNoticePortrait {robotID:root.victim;defeated:true;visible:root.killer>0}
    }
    Image {x:30;y:12;width:52;height:52;source:root.iconSource;visible:source.toString().length>0;fillMode:Image.PreserveAspectFit;mipmap:true;layer.enabled:root.team==="green";layer.effect:MultiEffect {colorization:1;colorizationColor:"#d1f6a8"}}
    OperatorText {
        x:root.iconSource.toString().length>0?94:40;y:5;width:parent.width-x-40;height:parent.height-10
        visible:root.victim===0;text:root.caption;size:21;minimumSize:11;font.bold:true
        wrapMode:Text.WordWrap;maximumLineCount:2;clip:true;horizontalAlignment:Text.AlignHCenter
        styleColor:root.team==="blue"?"#185c89":root.team==="red"?"#852d2a":"#275763"
    }
}
