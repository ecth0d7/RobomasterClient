import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Button {
    id:root
    property string caption:""
    property string detail:""
    property string glyphAsset:""
    property url glyphSource:""
    property bool showCoin:false
    property bool selected:false
    property bool activated:false
    property bool weakened:false
    property color iconColor:Theme.text
    property string blockedReason:""
    text:caption
    hoverEnabled:true
    padding:6
    Accessible.name:caption+" · "+detail+(blockedReason?" · "+blockedReason:activated?" · 当前姿态":" · 选择后确认")
    background:Rectangle {
        radius:4
        color:root.selected || root.down ? "#6877aaa7" : root.activated ? "#4777aaa7" : root.hovered ? "#35465352" : "#14253536"
        border.width:root.activeFocus || root.selected ? 2 : 1
        border.color:root.selected || root.activated ? "#afece5" : root.enabled ? "#8eabb0b0" : "#405e6565"
    }
    contentItem:Item {
        opacity:root.enabled?1:.42
        OperatorText {x:0;y:0;width:parent.width-32;height:26;text:root.caption;size:13}
        Image {x:0;y:31;width:16;height:16;source:"../resources/player/panel/ic_gold_2x.png";fillMode:Image.PreserveAspectFit;mipmap:true;visible:root.showCoin}
        OperatorText {x:root.showCoin?20:0;y:26;width:parent.width-32-x;height:26;text:(root.weakened?"↓ ":"")+root.detail;size:11;color:root.weakened?Theme.red:Theme.muted}
        OperatorSprite {id:glyph;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;width:28;height:32;asset:root.glyphAsset;source:root.glyphSource.toString().length?root.glyphSource:root.glyphAsset?"../resources/engine-137/sprites/"+root.glyphAsset+".png":"";visible:false}
        MultiEffect {anchors.fill:glyph;source:glyph;visible:root.glyphAsset.length>0 || root.glyphSource.toString().length>0;colorization:1;colorizationColor:root.iconColor;brightness:.25}
    }
}
