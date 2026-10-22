import QtQuick
import QtQuick.Window

// A second native window shares received state; it never opens another MQTT or
// UDP connection and has no command intent or interactive map handler.
Window {
    id:root
    objectName:"operatorReadOnlyMapWindow"
    property alias fieldMapObject:fieldMap
    property Window operatorWindow:null
    property bool displayEnabled:false
    property var telemetry:null
    property int clientID:3
    property var headingItems:[]
    property var runeMapItems:[]
    property var projectionItems:[]
    property bool dismissed:false
    readonly property var monitors:Array.from(Qt.application.screens)
    readonly property int ownerScreenIndex:{
        const direct=monitors.indexOf(operatorWindow?.screen);
        if(direct>=0)return direct;
        const named=monitors.findIndex(s=>s.name===operatorWindow?.screen?.name
            && s.virtualX===operatorWindow?.screen?.virtualX && s.virtualY===operatorWindow?.screen?.virtualY);
        return Math.max(0,named);
    }
    readonly property var targetScreen:monitors.length>1 ? monitors[(ownerScreenIndex+1)%monitors.length] : null
    transientParent:operatorWindow
    screen:targetScreen??monitors[0]
    title:"战场地图 · 只读"
    color:"#081010"
    width:targetScreen?.width??800
    height:targetScreen?.height??430
    flags:Qt.Window | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput
    visible:displayEnabled && operatorWindow?.visible===true && targetScreen!==null && !dismissed
    onVisibleChanged:if(visible)showFullScreen()
    onDisplayEnabledChanged:if(!displayEnabled)dismissed=false
    onTargetScreenChanged:dismissed=false
    onClosing:dismissed=true
    OperatorFieldMap {
        id:fieldMap
        objectName:"readOnlyFieldMap"
        anchors.fill:parent
        telemetry:root.telemetry;clientID:root.clientID
        headingItems:root.headingItems;projectionItems:root.projectionItems
        runeMapItems:root.runeMapItems
        interactive:false
    }
}
