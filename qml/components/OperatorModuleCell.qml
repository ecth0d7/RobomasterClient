import QtQuick
import QtQuick.Controls

Item {
    id:root
    property var reading: ({state:"missing",tone:"muted",text:"未提供",description:"未提供"})
    property string label:""
    property bool stacked:false
    readonly property bool coloredFrame:reading.state === "fresh" && (reading.tone === "green" || reading.tone === "red"
        || reading.native_module === true && reading.tone === "warning")
    property color valueColor:reading.warning || reading.tone === "warning" ? Theme.warning
        : reading.tone === "red" ? Theme.red : reading.tone === "green" ? Theme.text : Theme.muted
    implicitWidth:193
    implicitHeight:stacked ? 44 : 34
    Accessible.role:Accessible.StaticText
    Accessible.name:label+"，"+reading.description
    BorderImage {
        anchors.fill:parent
        visible:root.coloredFrame
        source:"../resources/player/panel/sundry_"+(root.reading.tone === "green" ? "online" : "offline")+".png"
        // 152×32原细框只延展中段，角部不随单元格宽度横向拉粗。
        border {left:2;right:2;top:2;bottom:2}
        smooth:true
        Accessible.ignored:true
    }
    Rectangle {
        anchors.fill:parent;visible:!root.coloredFrame
        color:Theme.hudSurface
        OperatorOutline {color:Theme.hudBorder}
    }
    OperatorText {
        x:8;y:0;width:root.stacked ? parent.width-16 : 96;height:root.stacked ? parent.height/2 : parent.height
        text:root.label;size:11;clip:true
        color:root.reading.tone !== "muted" && root.reading.state === "fresh" ? Theme.text : Theme.muted
    }
    OperatorText {
        x:root.stacked ? 8 : 110;y:root.stacked ? parent.height/2 : 0
        width:parent.width-x-8;height:root.stacked ? parent.height/2 : parent.height
        text:root.reading.text+(root.stacked && Number.isFinite(root.reading.age_ms)
            ? " · "+(root.reading.clock_basis === "local_receive" ? "收" : "源")+(root.reading.age_ms/1000).toFixed(1)+"s" : "")
        size:11;clip:true;color:root.valueColor
    }
    HoverHandler {id:hover}
    OperatorDataToolTip {visible:hover.hovered;text:(root.reading && root.reading.description) ? root.reading.description : ""}
}
