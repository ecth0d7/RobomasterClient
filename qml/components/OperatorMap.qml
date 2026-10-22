import QtQuick
import QtQuick.Controls
import QtQuick.Window

Item {
    id: root
    objectName:"operatorMinimap"
    property var telemetry: null
    property int clientID: 3
    property var discoveryMarkers: []
    property var fusionView: ({})
    readonly property var visionSnapshot:fieldMap.visionSnapshot
    readonly property bool visionLegendVisible:visionSnapshot.total>0 || visionSnapshot.otherFrame>0 || visionSnapshot.imageOnly>0
    readonly property real hudScale:Window.window?.ui?.layoutScale ?? 1
    readonly property real visionLegendHeight:Math.max(24,14/Math.max(.1,hudScale))
    property var headingItems: []
    property var runeMapItems: []
    property var projectionItems: []
    property bool previewOnly: false
    property string feedback:""
    signal modeRequested(int mode)
    signal markRequested(real mapX, real mapY)
    signal enemyRequested(int robotId)
    signal discoveryDetailsRequested
    width: 340
    height: width * 452 / 842 + (root.discoveryMarkers.length ? 32 : 0)+(visionLegendVisible?visionLegendHeight:0)
    OperatorFieldMap {
        id:fieldMap
        objectName:"hudFieldMap"
        width: parent.width
        height: width * 452 / 842
        telemetry: root.telemetry
        discoveryMarkers: root.discoveryMarkers
        fusionView:root.fusionView
        headingItems: root.headingItems
        runeMapItems:root.runeMapItems
        projectionItems: root.projectionItems
        previewOnly: root.previewOnly
        clientID: root.clientID
        compact: true
        interactive: true
        onModeRequested: mode => root.modeRequested(mode)
        onPointPicked: (mapX, mapY) => root.markRequested(mapX, mapY)
        onRobotPicked:robotId=>root.enemyRequested(robotId)
    }
    Loader {
        x:9;y:fieldMap.height;width:parent.width-18;height:root.visionLegendHeight
        active:root.visionLegendVisible
        source:active?Qt.resolvedUrl("../../extensions/battlefield-minimap/qml/Legend.qml"):""
        onLoaded:{
            item.snapshot=Qt.binding(()=>root.visionSnapshot);
            item.hiddenLabels=Qt.binding(()=>fieldMap.visionHiddenLabels);
            item.hudScale=Qt.binding(()=>root.hudScale);
        }
    }
    OperatorText {
        id:caption
        visible: root.discoveryMarkers.length > 0
        x: 9
        y: parent.height - 30
        width:parent.width-18-(detailsButton.visible ? detailsButton.width+8 : 0)
        height: 22
        text:root.discoveryMarkers.length ? (fieldMap.discoveryLabelsHidden
            ? "标签 "+fieldMap.discoveryLabelCount+"/"+root.discoveryMarkers.length+" · 其余见来源"
            : "独立发现 "+root.discoveryMarkers.length+" · 细线连坐标")
            : "地图 28 × 15 m · 点击标记"
        Accessible.role:Accessible.StaticText
        Accessible.name:root.discoveryMarkers.length ? "独立发现 "+root.discoveryMarkers.length+" 项；地图标签 "+fieldMap.discoveryLabelCount
            +" 个。锚点仍在原坐标；未排下的标签请用地图右侧的来源按钮查看，不表示观测被删除。" : text
        HoverHandler {id:captionHover;blocking:false}
        ToolTip.visible:captionHover.hovered
        ToolTip.delay:500
        ToolTip.text:caption.Accessible.name
        size: 10
        color: Theme.muted
    }
    Button {
        id:detailsButton
        objectName:"mapDiscoveryDetailsButton"
        visible:root.discoveryMarkers.length > 0
        x:parent.width-width-9;y:parent.height-32;width:56;height:24
        Accessible.name:"查看全部发现的来源、时间、坐标及未排下的标签记录"
        contentItem:OperatorText {text:"来源";size:10;horizontalAlignment:Text.AlignHCenter}
        background:Rectangle {
            radius:2;color:detailsButton.hovered || detailsButton.down ? Theme.hudHover : "transparent"
            OperatorOutline {color:detailsButton.activeFocus ? Theme.green : Theme.hudBorder}
        }
        onClicked:root.discoveryDetailsRequested()
    }
}
