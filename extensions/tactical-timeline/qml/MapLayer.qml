import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "../../../qml/components" as Client
import "JournalData.js" as Data
Item {
    id:root;objectName:"tacticalMapLayer"
    property var view:({})
    property double now:Date.now()
    readonly property real glyphSize:Math.max(14,14/Math.max(.1,Window.window?.ui?.layoutScale??1))
    // 新快照先推进显示时钟，避免定时器相位把刚收到的时间戳反复判为未来。
    onViewChanged:now=Date.now()
    onVisibleChanged:if(visible)now=Date.now()
    readonly property var marks:Data.points(view,now,"field.2026")
    Timer {interval:250;repeat:true;running:root.visible;onTriggered:root.now=Date.now()}
    Repeater {
        model:root.marks.length
        Item {
            required property int index
            readonly property var modelData:root.marks[index]
            objectName:"tacticalMap:"+modelData.id
            x:modelData.point[0]/28*root.width-root.glyphSize/2;y:(1-modelData.point[1]/15)*root.height-root.glyphSize/2;width:root.glyphSize;height:root.glyphSize
            Rectangle {anchors.centerIn:parent;width:root.glyphSize*.72;height:width;rotation:45;color:"transparent";border.color:Client.Theme.accent;border.width:2}
            Client.OperatorText {anchors.centerIn:parent;width:parent.width;height:parent.height;text:"人";size:9;color:Client.Theme.accent;horizontalAlignment:Text.AlignHCenter}
            HoverHandler {id:hover}
            ToolTip {
                id:tip;visible:hover.hovered;width:Math.min(440,root.Window.window?.width??440);padding:10
                contentItem:Text {text:tip.text;textFormat:Text.PlainText;wrapMode:Text.Wrap;font.family:Client.Theme.fontFamily;font.pixelSize:13;color:Client.Theme.text}
                background:Rectangle {color:Client.Theme.hudSolid;border.color:Client.Theme.hudBorder;radius:2}
                text:"人工标注 · "+modelData.origin+"\n"+modelData.text+"\n原始时间 "+modelData.stamp_ms+" · 剩余 "+Math.max(0,modelData.expires_ms-root.now)+"ms"}
        }
    }
}
