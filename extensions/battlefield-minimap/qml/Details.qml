import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "../../../qml/components" as Client
import "VisionMapData.js" as Data

Item {
    id:root
    objectName:"visionMapDetails"
    property var renderer:null
    HoverHandler {id:hover;blocking:false}
    readonly property var marker:hover.hovered && renderer ? renderer.hitAt(hover.point.position):null
    property bool sourceAvailable:false
    onMarkerChanged:{const available=marker!==null;if(sourceAvailable!==available)sourceAvailable=available;}
    readonly property bool sourceTooltipVisible:tip.visible
    readonly property string sourceTooltipText:tip.text
    ToolTip {
        id:tip;objectName:"visionMapSourceTip";parent:root
        visible:root.sourceAvailable
        // Live records change every 200ms. Delayed shared ToolTips can restart
        // before opening; this short-lived source view opens immediately.
        delay:0;width:Math.min(420,root.Window.window?.width ?? 420)
        x:Math.min(0,parent.width-width);font.family:Client.Theme.fontFamily;font.pixelSize:13
        text:root.marker?Data.description(root.marker,root.renderer.now):""
    }
}
