import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "FieldGeometry.js" as Geometry
import "OperatorData.js" as Data
import "OperatorMapHeadingData.js" as HeadingData
import "OperatorMapState.js" as MapState
import "OperatorMapLabelLayout.js" as LabelLayout
import "OperatorMapData.js" as MapData
import "OperatorMapRuneData.js" as RuneData

Item {
    id: root
    property var telemetry: null
    property int clientID: 3
    property var discoveryMarkers: []
    property var fusionView: ({})
    readonly property var visionSnapshot:visionLayer.item?.snapshot ?? ({markers:[],total:0,omitted:0,otherFrame:0,imageOnly:0})
    readonly property int visionHiddenLabels:visionLayer.item?.hiddenLabels ?? 0
    readonly property var visionAnchorObstacles:visionLayer.item?.anchorObstacles ?? []
    // 可替换renderer输入：真实队友朝向须由宿主汇总／来源校验后投影；不能塞进雷达数组。
    property var headingItems: []
    property var runeMapItems: []
    readonly property var runeNodes:RuneData.project(runeMapItems,clientID,
        Data.state(telemetry,"gameStatus","current_round")==="fresh"
            && Data.state(telemetry,"gameStatus","current_stage")==="fresh" && telemetry.gameStatus.current_stage===4
            ?telemetry.gameStatus.current_round:0,headingNow)
    readonly property var runePlacements:{
        const placed=[],avoid=robotObstacles.slice();
        for(const node of runeNodes) {
            const p=commandPlacement(node,compact?28:42,avoid);
            placed.push(p);avoid.push({x:p.x-3,y:p.y-3,w:p.w+6,h:p.h+6});
        }
        return placed;
    }
    readonly property var runeObstacles:runePlacements.map(p=>({x:p.x-3,y:p.y-3,w:p.w+6,h:p.h+6}))
    property var projectionItems: []
    property bool previewOnly: false
    readonly property int discoveryLabelCount:discoveryLayer.labelCount
    readonly property int discoveryLabelsHidden:discoveryLayer.hiddenCount
    property bool yawClockwise: true
    property double headingNow: Date.now()
    Timer {
        interval: 500
        repeat: true
        running: root.visible && (root.headingItems.length > 0 || root.projectionItems.length > 0 || root.runeMapItems.length>0)
        onTriggered: root.headingNow = Date.now()
    }
    onHeadingItemsChanged: headingNow = Date.now()
    onRuneMapItemsChanged:headingNow=Date.now()
    onProjectionItemsChanged: headingNow = Date.now()
    onVisibleChanged: { if (visible) headingNow = Date.now(); else cancelMarking(); }
    onEnabledChanged: if (!enabled) cancelMarking()
    onClientIDChanged: cancelMarking()
    function localFor(robotId) {
        return MapState.local(projectionItems,robotId,telemetry?.gameStatus?.current_round ?? 0,headingNow,previewOnly);
    }
    function headingFor(robotId, point) {
        return HeadingData.headingFor(headingItems, robotId, headingNow, previewOnly)
            ?? MapState.heading(localFor(robotId),point);
    }
    function markerX(point,size) {
        return Math.max(size*.8,Math.min(coordinates.width-size*.8,(point?.x??0)/28*coordinates.width))-size/2;
    }
    function markerY(point,size) {
        return Math.max(size*.8,Math.min(coordinates.height-size*.8,(1-(point?.y??0)/15)*coordinates.height))-size/2;
    }
    function commandPlacement(point,size,avoid) {
        const obstacles=avoid??robotObstacles.concat(runeObstacles);
        const anchorX=(point?.x??0)/28*coordinates.width,anchorY=(1-(point?.y??0)/15)*coordinates.height;
        const baseX=markerX(point,size),baseY=markerY(point,size),offsets=[[0,0]];
        for(const distance of [size+12,size*2+16])
            for(const pair of [[1,0],[-1,0],[0,-1],[0,1],[1,-1],[-1,-1],[1,1],[-1,1]])offsets.push([pair[0]*distance,pair[1]*distance]);
        for(const offset of offsets) {
            const rect={x:Math.max(size*.3,Math.min(coordinates.width-size*1.3,baseX+offset[0])),
                y:Math.max(size*.3,Math.min(coordinates.height-size*1.3,baseY+offset[1])),w:size,h:size};
            if(!obstacles.some(o=>LabelLayout.overlaps(rect,o,3)))return Object.assign(rect,{anchorX,anchorY});
        }
        return {x:baseX,y:baseY,w:size,h:size,anchorX,anchorY};
    }
    readonly property var markingMenu: pingMenu
    signal modeRequested(int mode)
    function cancelMarking() { pingMenu.close(); }
    OperatorMapPingMenu {
        id: pingMenu
    }
    Connections {
        target: root.Window.window
        function onActiveChanged() { if (!root.Window.window.active) root.cancelMarking(); }
    }
    property bool interactive: false
    onInteractiveChanged: if (!interactive) cancelMarking()
    property bool compact: false
    property var draftPoint: null
    property int draftMode: 1
    property string draftLetter: "C"
    readonly property var radarEntries: telemetry?.radar?.radar_single_robot_info ?? []
    readonly property string radarState: Data.state(telemetry, "radar", "radar_single_robot_info")
    readonly property var radarPoints: Geometry.radarMarkers(radarEntries,clientID,28,15)
    readonly property var pathPlan: MapState.path(telemetry,clientID)
    readonly property var received: telemetry?.mapClick ?? ({})
    readonly property string receivedState: Data.state(telemetry, "mapClick", "mode")
    function receivedHas(keys) {
        return keys.every(key=>Data.state(telemetry,"mapClick",key)!=="missing"
            && (previewOnly || Data.notOlderThan(telemetry,"mapClick",key,"mode")));
    }
    readonly property var receivedProjection: MapData.receivedMarker(telemetry,clientID,previewOnly)
    readonly property bool receivedStale: receivedProjection?.stale ?? false
    readonly property var receivedPoint: receivedProjection
    readonly property var robotObstacles:{
        const obstacles=[];
        function reserve(x,y,size) {
            // 方向点可伸出圆标0.21倍，旋转命令菱形也可超出名义方框。
            const radius=size*0.71+3;
            obstacles.push({x:x-radius,y:y-radius,w:radius*2,h:radius*2});
        }
        if (radarState !== "missing") {
            for (const point of radarPoints) {
                const size=compact ? 22 : 34;
                reserve(markerX(point,size)+size/2,markerY(point,size)+size/2,size);
            }
        }
        if (positionMarker.visible) reserve(positionMarker.x+positionMarker.width/2,positionMarker.y+positionMarker.height/2,positionMarker.width);
        return obstacles;
    }
    readonly property var labelObstacles:{
        const obstacles=robotObstacles.concat(runeObstacles);
        if(receivedMarker.visible)obstacles.push({x:receivedMarker.x-4,y:receivedMarker.y-4,w:receivedMarker.width+8,h:receivedMarker.height+8});
        if(draftMarker.visible)obstacles.push({x:draftMarker.x-4,y:draftMarker.y-4,w:draftMarker.width+8,h:draftMarker.height+8});
        return obstacles;
    }
    signal pointPicked(real mapX, real mapY)
    signal robotPicked(int robotId)
    width: 842
    height: 452
    Image {
        id: field
        anchors.fill: parent
        source: "../resources/player/base_bg_2026_fq_small.png"
        fillMode: Image.PreserveAspectFit
        mipmap: true
        Item {
            id: coordinates
            anchors.centerIn: parent
            width: field.paintedWidth
            height: field.paintedHeight
            clip: true
            OperatorDiscoveryMapLayer {
                id:discoveryLayer
                anchors.fill:parent
                markers:root.discoveryMarkers
                obstacles:root.labelObstacles.concat(root.visionAnchorObstacles)
                compact:root.compact
                previewOnly:root.previewOnly
                // 引线和锚点位于官方图标之下；偏移标签避让图标完整外沿。
                z:0
            }
            Loader {
                id:visionLayer
                anchors.fill:parent;z:.5
                active:!root.previewOnly && root.fusionView?.schema==="rm.situation.view/1"
                source:active?Qt.resolvedUrl("../../extensions/battlefield-minimap/qml/Overlay.qml"):""
                onLoaded:{
                    item.view=Qt.binding(()=>root.fusionView);
                    item.clientID=Qt.binding(()=>root.clientID);
                    item.compact=Qt.binding(()=>root.compact);
                    item.radarPoints=Qt.binding(()=>root.radarState==="fresh"?root.radarPoints:[]);
                    item.obstacles=Qt.binding(()=>root.labelObstacles);
                    item.discoveryLabelRects=Qt.binding(()=>discoveryLayer.placements.labels.map(p=>({x:p.x,y:p.y,w:p.w,h:p.h})));
                }
            }
            Loader {
                anchors.fill:parent;z:.6
                active:!root.previewOnly && root.fusionView?.journal?.enabled===true
                source:active?Qt.resolvedUrl("../../extensions/tactical-timeline/qml/MapLayer.qml"):""
                onLoaded:item.view=Qt.binding(()=>root.fusionView)
            }
            OperatorMapPath {
                objectName:"mapPath"
                anchors.fill:parent
                compact:root.compact
                plan:root.pathPlan
                z:1
            }
            Repeater {
                model:root.runeNodes.length
                OperatorMapRune {
                    required property int index
                    objectName:"mapRune"+(node?.node_id??"retiring")
                    anchors.fill:parent
                    node:root.runeNodes[index]
                    placement:root.runePlacements[index]
                    glyphSize:root.compact?28:42
                    z:1.5
                }
            }
            Repeater {
                // Stable seat count keeps the delegates alive during 1Hz updates.
                model: Math.min(root.radarEntries.length,12)
                OperatorMapRobot {
                    id:radarMarker
                    objectName:"mapRadarRobot"+robotId
                    required property int index
                    readonly property int seatType:[1,2,3,4,6,7][index%6]
                    readonly property bool blue:index<6 ? root.clientID<=100 : root.clientID>100
                    readonly property var point:root.radarPoints.find(p=>p.robotId===robotId)??null
                    readonly property var localState:root.localFor(robotId)
                    robotId:seatType+(blue?100:0)
                    self:robotId===root.clientID
                    highlighted:point?.highlight===1 || locationOffline
                    locationOffline:point?.highlight===2
                    dead:MapState.dead(root.telemetry,root.clientID,robotId,localState)
                    dataState:root.radarState
                    heading:root.headingFor(robotId,point)
                    visible:root.radarState!=="missing" && point!==null
                        && !(positionMarker.visible && positionMarker.robotId===robotId)
                    width:root.compact?22:34
                    height:width
                    x:root.markerX(point,width)
                    y:root.markerY(point,width)
                    z:2
                    Accessible.role:Accessible.StaticText
                    Accessible.name:(blue?"蓝方":"红方")+seatType+(self?" · 本机":"")
                        +(dead?" · 已阵亡":"")+(locationOffline?" · 定位离线":"")
                        +(root.radarState==="stale"?" · 雷达坐标旧值":"")
                        +(heading?" · 朝向 "+heading.yaw_deg.toFixed(1)+"° · "+heading.source_kind:" · 未收到有效朝向")
                    HoverHandler {id:radarHover;blocking:false}
                    ToolTip.visible:radarHover.hovered
                    ToolTip.delay:450
                    ToolTip.text:Accessible.name
                }
            }
            OperatorMapRobot {
                id:positionMarker
                objectName:"mapPositionRobot"
                readonly property var ownRadar:root.radarPoints.find(p=>p.robotId===robotId)??null
                readonly property var point:Geometry.boundedPoint(root.telemetry?.robotPosition?.x,root.telemetry?.robotPosition?.y,28,15)
                robotId:Data.state(root.telemetry,"robotPosition","robot_id")==="missing"
                    ? root.clientID : root.telemetry?.robotPosition?.robot_id??0
                self:robotId===root.clientID
                highlighted:ownRadar?.highlight===1
                dead:MapState.dead(root.telemetry,root.clientID,robotId,root.localFor(robotId))
                dataState:["x","y"].every(k=>Data.state(root.telemetry,"robotPosition",k)==="fresh")?"fresh":"stale"
                heading:Data.state(root.telemetry,"robotPosition","yaw")!=="missing"
                    ? {yaw_deg:root.telemetry.robotPosition.yaw,state:Data.state(root.telemetry,"robotPosition","yaw"),
                        clockwise:root.yawClockwise,source_kind:"official_player_client",source_id:"RobotPosition"}:null
                // Only mobile roles have a robot sprite. 0,0 remains a valid own pose.
                visible:[1,2,3,4,5,6,7].includes(robotId%100) && HeadingData.validRobot(robotId)
                    && ["x","y"].every(k=>Data.state(root.telemetry,"robotPosition",k)!=="missing")
                    && point!==null && ownRadar?.highlight!==2
                width:root.compact?24:38
                height:width
                x:root.markerX(point,width)
                y:root.markerY(point,width)
                z:3
                Accessible.role:Accessible.StaticText
                Accessible.name:(self?"本机":"定位机器人 "+robotId)+" · "+(robotId%100)
                    +" · RobotPosition · 朝向 "+Data.text(root.telemetry,"robotPosition","yaw",1)+"°"
                    +(dataState==="stale"?" · 坐标旧值":"")
                HoverHandler {id:poseHover;blocking:false}
                ToolTip.visible:poseHover.hovered
                ToolTip.delay:450
                ToolTip.text:Accessible.name
            }
            OperatorMapMarker {
                id:receivedMarker
                objectName:"mapReceivedMarker"
                readonly property var placement:root.commandPlacement(root.receivedPoint,width)
                z:4
                visible: root.receivedState !== "missing" && root.receivedPoint !== null && root.received.mode>=1 && root.received.mode<=4
                    && (root.received.mode!==4 || root.receivedHas(["ascii"]) && MapData.allowedAscii(root.received.ascii))
                compact: root.compact
                x: placement.x
                y: placement.y
                mode: root.received.mode ?? 0
                letter: String.fromCharCode(root.received.ascii ?? 0)
                coordinateText:root.receivedPoint ? "("+root.receivedPoint.x.toFixed(2)+", "+root.receivedPoint.y.toFixed(2)+")" : ""
                obstacles:root.labelObstacles
                stale: root.receivedStale || root.received.type === 2 && root.radarState !== "fresh"
            }
            OperatorMapMarker {
                id:draftMarker
                objectName:"mapDraftMarker"
                readonly property var placement:root.commandPlacement(root.draftPoint,width)
                z:4
                visible: root.draftPoint !== null && Geometry.valid(root.draftPoint?.x, root.draftPoint?.y, 28, 15)
                compact: root.compact
                x: placement.x
                y: placement.y
                mode: root.draftMode
                letter: root.draftLetter
                coordinateText:root.draftPoint ? "("+root.draftPoint.x.toFixed(2)+", "+root.draftPoint.y.toFixed(2)+")" : ""
                obstacles:root.labelObstacles
                draft: true
            }
            Repeater {
                model:2
                Rectangle {
                    required property int index
                    readonly property var p:index===0 ? receivedMarker.placement : draftMarker.placement
                    readonly property real markerSize:index===0 ? receivedMarker.width : draftMarker.width
                    readonly property real dx:(index===0 ? receivedMarker.x : draftMarker.x)+markerSize/2-p.anchorX
                    readonly property real dy:(index===0 ? receivedMarker.y : draftMarker.y)+markerSize/2-p.anchorY
                    x:p.anchorX;y:p.anchorY;width:Math.hypot(dx,dy);height:1
                    rotation:Math.atan2(dy,dx)*180/Math.PI;transformOrigin:Item.Left
                    visible:(index===0 ? receivedMarker.visible : draftMarker.visible) && width>markerSize*.8
                    color:index===0 ? receivedMarker.markerColor : draftMarker.markerColor
                    opacity:.55;z:1
                }
            }
            MouseArea {
                objectName: "mapMarkingSurface"
                z:5
                anchors.fill: parent
                enabled: root.interactive
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                pressAndHoldInterval: Theme.mapSignalHoldMs
                property bool held: false
                property point holdPoint
                property int holdEnemyID: 0
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => { held=false; if (mouse.button===Qt.RightButton) root.cancelMarking(); }
                onPressAndHold: mouse => {
                    if (mouse.button!==Qt.LeftButton) return;
                    held=true; holdPoint=Qt.point(mouse.x,mouse.y);
                    const size=root.compact?22:34;
                    const target=root.radarState!=="missing" ? root.radarPoints.find(p=>(p.robotId>100)!==(root.clientID>100)
                        && Math.hypot(holdPoint.x-(root.markerX(p,size)+size/2),holdPoint.y-(root.markerY(p,size)+size/2))<=size*.65):null;
                    holdEnemyID=target?.robotId??0;
                    pingMenu.openAt(this,mouse.x,mouse.y);
                }
                onPositionChanged: mouse => { if (pressed && held) pingMenu.trackHeld(this,mouse.x,mouse.y); }
                onReleased: mouse => {
                    if (!held) return;
                    const mode=pingMenu.finishHeld();
                    if (mode) {
                        root.modeRequested(mode);
                        // 坐标取最初长按处；滑动只选择类型，不能把图标位置误发成落点。
                        if (holdEnemyID) root.robotPicked(holdEnemyID);
                        else root.pointPicked(holdPoint.x/width*28,(1-holdPoint.y/height)*15);
                    }
                }
            }
            Loader {
                anchors.fill:parent;z:5.5
                active:visionLayer.status===Loader.Ready
                source:active?Qt.resolvedUrl("../../extensions/battlefield-minimap/qml/Details.qml"):""
                onLoaded:item.renderer=Qt.binding(()=>visionLayer.item)
            }
            Rectangle { z:6;anchors.fill: parent; color: "transparent"; border.color: Theme.line }
        }
    }
}
