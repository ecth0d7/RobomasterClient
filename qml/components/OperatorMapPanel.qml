import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "OperatorMapData.js" as MapData
import "OperatorFocus.js" as PanelFocus

FocusScope {
    id: root
    objectName: "operatorLargeMap"
    readonly property bool operatorPanelKeyboardBoundary: true
    property var telemetry: null
    property int clientID: 3
    property bool previewOnly: false
    property bool connected: false
    property var discoveryMarkers: []
    property var fusionView: typeof battlefieldHost === "undefined" ? ({}) : battlefieldHost?.view ?? ({})
    readonly property var map3DControl: map3D
    property var headingItems: []
    property var runeMapItems: []
    property var projectionItems: []
    property bool submissionAvailable: false
    property bool teamMarkAllowed: false
    property bool supportVisible: false
    property bool supportConfirming: false
    property bool forwardMode:false
    property bool forwardActive:false
    property real supportHeight: 700
    property string unavailableReason: "地图发送入口未接通"
    property string feedback: ""
    property int markerMode: 1
    property string selectedLetter: "C"
    property var draftPoint: null
    property int targetType: 1
    property int enemyID: 0
    property int sendScope: teamMarkAllowed ? 2 : 0
    readonly property var recipients: [clientID]
    readonly property real hudScale: Window.window?.ui?.layoutScale ?? 1
    readonly property real labelSize: Math.max(15, 10 / Math.max(.1, hudScale))
    readonly property string mapShortcut: Window.window?.ui?.shortcutPreferencesObject?.sequence("map") ?? "M"
    readonly property real sidebarWidth: supportVisible ? 454 : map3D.sceneReady ? 244 : 220
    readonly property real mapWidth: width - sidebarWidth
    readonly property bool draftValid: targetType === 2 ? enemyID > 0 : draftPoint !== null
    readonly property var mapX: draftPoint?.x ?? null
    readonly property var mapY: draftPoint?.y ?? null
    readonly property bool focused: Window.window?.active === true
    signal closeRequested
    signal layoutRequested
    signal mapIntent(var fields)
    width: map3D.sceneReady ? Math.max(0, (parent?.width ?? 1600) - 40)
        : Math.min(1800, (parent?.width ?? 1600) - 64, ((parent?.height ?? 900) - (supportVisible ? 182 : 132)) * 800 / 430 + sidebarWidth)
    height: map3D.sceneReady ? (parent?.height ?? 900) - 44
        : 104 + (supportVisible ? Math.max(mapWidth * 430 / 800 + 50,supportHeight) : mapWidth * 430 / 800)
    onVisibleChanged: if (visible) { feedback=""; forceActiveFocus(); }
    onClientIDChanged: { clearDraft(); markerMode=1; }
    onTeamMarkAllowedChanged: sendScope=teamMarkAllowed ? 2 : 0
    function setPoint(x,y) { draftPoint={x:x,y:y}; targetType=1; feedback=""; }
    function clearDraft() { draftPoint=null; enemyID=0; feedback=""; }
    function commandFields(ownOnly) {
        const scope=ownOnly || !teamMarkAllowed ? 0 : forwardMode ? forwardActive?2:1 : sendScope;
        const ownRecipients=forwardMode && forwardActive?Array.from(new Set([clientID,clientID>100?107:7])):[clientID];
        const fields={is_send_all:scope,robot_id:MapData.recipientBytes(scope===0 ? ownRecipients : []),mode:markerMode,type:targetType};
        if (targetType===1) { fields.map_x=mapX; fields.map_y=mapY; }
        else fields.enemy_id=enemyID;
        if (markerMode===4) fields.ascii=selectedLetter.charCodeAt(0);
        return fields;
    }
    function submitDraft(ownOnly) {
        if (!draftValid) return;
        if (previewOnly) { feedback="设计预览"; return; }
        if (!submissionAvailable) { draftPoint=null; feedback=unavailableReason; return; }
        mapIntent(commandFields(ownOnly===true));
    }
    function submitPoint(x,y) { setPoint(x,y); submitDraft(false); }
    function submitEnemy(id) { targetType=2; enemyID=id; draftPoint=null; submitDraft(false); }
    function submitOwnPoint(x,y) { setPoint(x,y); submitDraft(true); }
    function submitOwnEnemy(id) { targetType=2; enemyID=id; draftPoint=null; submitDraft(true); }
    function recordSubmission(fields,accepted) { draftPoint=null; }
    Keys.onEscapePressed: event => { event.accepted=true; root.closeRequested(); }
    Shortcut {sequence:"Tab";enabled:root.visible && root.focused;autoRepeat:false;onActivated:PanelFocus.move(root,root.Window.window.activeFocusItem,true)}
    Shortcut {sequence:"Shift+Tab";enabled:root.visible && root.focused;autoRepeat:false;onActivated:PanelFocus.move(root,root.Window.window.activeFocusItem,false)}
    Rectangle { anchors.fill:parent; color:map3D.sceneReady ? Theme.hudSolid : Theme.hudSurface; border.color:Theme.hudBorder }
    OperatorText {
        x:16;y:6;width:parent.width-76;height:38
        text:(map3D.sceneReady ? "2027 立体态势 · " : "大地图 · ")+(root.teamMarkAllowed ? "云台手" : "本机 "+root.clientID)
        size:20
    }
    OperatorCloseButton {
        objectName:"largeMapClose";x:parent.width-width-12;y:8;width:32;height:32
        closeLabel:"关闭大地图（"+(root.mapShortcut ? root.mapShortcut+" / " : "")+"Esc）";onClicked:root.closeRequested()
    }
    OperatorFieldMap {
        id:fieldMap
        objectName:"largeFieldMap"
        visible: !map3D.sceneReady
        x:12;y:52;width:root.mapWidth;height:map3D.sceneReady ? root.height-104 : width*430/800
        telemetry:root.telemetry;clientID:root.clientID
        discoveryMarkers:root.discoveryMarkers;fusionView:root.fusionView
        headingItems:root.headingItems;projectionItems:root.projectionItems;previewOnly:root.previewOnly
        runeMapItems:root.runeMapItems
        interactive:!root.previewOnly
        onModeRequested: mode => root.markerMode=mode
        draftPoint:root.draftPoint;draftMode:root.markerMode;draftLetter:root.selectedLetter
        onPointPicked:(x,y)=>root.submitPoint(x,y)
        onRobotPicked:id=>root.submitEnemy(id)
    }
    OperatorMap3DSlot {
        id:map3D
        objectName:"optionalMap3DSlot"
        x:fieldMap.x;y:fieldMap.y;width:fieldMap.width;height:fieldMap.height
        mapOpen:root.visible
        previewOnly:root.previewOnly
        connected:root.connected
        telemetry:root.telemetry;clientID:root.clientID
        projectionItems:root.projectionItems;headingItems:root.headingItems
        discoveryMarkers:root.discoveryMarkers;fusionView:root.fusionView
        hudScale:root.hudScale
        onModeRequested: mode => root.markerMode=mode
        onPointPicked: (x,y) => root.submitPoint(x,y)
    }
    Column {
        x:fieldMap.x+fieldMap.width+16;y:fieldMap.y;width:root.width-x-12;spacing:12
        visible:!root.supportVisible && !map3D.sceneReady
        Repeater {
            model:[{mode:1,title:"进攻"},{mode:2,title:"防守"},{mode:3,title:"警戒"}]
            Item {
                required property var modelData
                width:parent.width;height:52
                OperatorMapMarker {x:4;y:9;width:34;height:34;mode:parent.modelData.mode}
                OperatorText {x:48;width:parent.width-48;height:parent.height;text:parent.modelData.title;size:root.labelSize}
            }
        }
        OperatorText {width:parent.width;height:72;text:"长按地图呼出信号轮盘\n滑向图标，松开标记原位置\n移回中心或按 Esc 取消";size:root.labelSize;wrapMode:Text.WordWrap;color:Theme.muted}
        OperatorSelect {
            objectName:"mapScope"
            width:parent.width
            visible:root.teamMarkAllowed
            label:"地图标记发送范围"
            model:["仅本机","全队 · 除哨兵","全队 · 含哨兵"]
            currentIndex:root.sendScope
            onActivated:index=>root.sendScope=index
        }
        OperatorText {width:parent.width;height:58;text:"坐标单位：米\n原点：左下角";size:root.labelSize;wrapMode:Text.WordWrap;color:Theme.muted}
    }
    // 控件与来源共用滚动区；小窗口不再依靠来源列表的最小高度挤占底部说明。
    ListView {
        id:map3DSources
        objectName:"map3DSourceList"
        x:fieldMap.x+fieldMap.width+16;y:fieldMap.y;width:root.width-x-12;height:fieldMap.height
        visible:!root.supportVisible && map3D.sceneReady
        clip:true;spacing:4;boundsBehavior:Flickable.StopAtBounds
        model:map3D.renderer?.sourceModel??null
        ScrollBar.vertical:ScrollBar{}
        header:Column {
            width:map3DSources.width-12;spacing:8;bottomPadding:8
            OperatorText {width:parent.width;height:30;text:"观测来源 · "+(map3D.renderer?.currentRows?.length??0);size:root.labelSize}
            OperatorButton {width:parent.width;height:36;text:"切换二维地图";onClicked:map3D.setEnabled(false)}
            OperatorText {width:parent.width;height:48;text:"长按地面，滑向图标后松开标记；移回中心取消";size:root.labelSize;wrapMode:Text.WordWrap;color:Theme.muted}
            Row {
                spacing:6;width:parent.width
                OperatorButton {width:(parent.width-6)/2;height:34;text:"左转";Accessible.name:"向左旋转立体地图";onClicked:map3D.renderer.yaw-=15}
                OperatorButton {width:(parent.width-6)/2;height:34;text:"右转";Accessible.name:"向右旋转立体地图";onClicked:map3D.renderer.yaw+=15}
            }
            OperatorCheckBox {
                objectName:"map3DTrails"
                width:parent.width;height:32;text:"显示观测轨迹";font.pixelSize:root.labelSize
                checked:map3D.renderer?.showTrails??true
                onToggled:if(map3D.renderer)map3D.renderer.showTrails=checked
            }
            OperatorCheckBox {
                objectName:"map3DLabels"
                width:parent.width;height:32;text:"显示来源标签";font.pixelSize:root.labelSize
                checked:map3D.renderer?.showLabels??true
                onToggled:if(map3D.renderer)map3D.renderer.showLabels=checked
            }
            OperatorCheckBox {
                objectName:"map3DUncertainty"
                width:parent.width;height:32;text:"显示估计误差范围";font.pixelSize:root.labelSize
                checked:map3D.renderer?.showUncertainty??true
                onToggled:if(map3D.renderer)map3D.renderer.showUncertainty=checked
            }
            OperatorConfigComboBox {
                objectName:"map3DTypeFilter"
                width:parent.width;model:["全部来源","视觉与融合估计","雷达与定位","仅冲突候选"]
                Accessible.name:"按观测类型筛选立体地图"
                currentIndex:Math.max(0,['all','vision','position','conflict'].indexOf(map3D.renderer?.sourceFilter??'all'))
                onActivated:index=>{if(map3D.renderer)map3D.renderer.sourceFilter=['all','vision','position','conflict'][index];}
            }
            OperatorConfigComboBox {
                objectName:'map3DNodeFilter'
                width:parent.width
                readonly property var availableNodes:map3D.renderer?.sourceNodes??[]
                readonly property string selectedNode:map3D.renderer?.nodeFilter??''
                model:['全部节点'].concat(availableNodes).concat(selectedNode && !availableNodes.includes(selectedNode)?[selectedNode]:[])
                currentIndex:Math.max(0,model.indexOf(map3D.renderer?.nodeFilter??''))
                Accessible.name:"按提供观测的客户端筛选"
                onActivated:index=>map3D.renderer.nodeFilter=index>0?String(model[index]):''
            }
            OperatorText {width:parent.width;height:22;size:root.labelSize;color:Theme.muted;text:'未定位图像观测 · '+(map3D.renderer?.imageObservations?.length??0)}
        }
        delegate:Button {
            required property var payload
            width:map3DSources.width-12;height:62
            Accessible.name:payload.label+"，"+payload.source
            contentItem:Column {
                spacing:2
                OperatorText {width:parent.width;height:25;text:payload.label;size:root.labelSize;elide:Text.ElideRight}
                OperatorText {width:parent.width;height:23;text:(map3D.renderer?.sourceName(payload.kind)??'')+' · '+(Number.isFinite(payload.uncertaintyM)?'±'+payload.uncertaintyM.toFixed(1)+'m':payload.confidenceText);size:Math.max(12,9.5/Math.max(.1,root.hudScale));color:Theme.muted;elide:Text.ElideRight}
            }
            background:Rectangle {color:map3D.renderer?.selectedKey===payload.key?Theme.hudHover:"transparent";border.color:parent.activeFocus?Theme.green:Theme.hudBorder}
            onClicked:map3D.renderer.selectedKey=payload.key
        }
    }
    OperatorText {
        x:fieldMap.x;y:root.height-90;width:fieldMap.width;height:38
        visible:root.supportVisible && !map3D.sceneReady
        text:"长按地图 → 向右滑至进攻／防守／警戒 → 松开标记"
        size:root.labelSize;color:Theme.muted
    }
    OperatorText {
        objectName:"mapShortcutCaption"
        x:12;y:root.supportVisible ? root.height-44 : fieldMap.y+fieldMap.height+6;width:root.width-24;height:38
        text:map3D.sceneReady ? (map3D.renderer?.notes?.join("；") || "左拖旋转 · 右拖平移 · 滚轮缩放 · 方框为估计 / 冲突候选 · "+(root.mapShortcut||"Esc")+" 关闭") + (map3D.renderer?.labelCoverage ?? "")
            : root.feedback || (map3D.requested ? map3D.statusText+" · " : "")+"长按并滑向信号图标 · "+(root.mapShortcut || "Esc")+" 关闭"
        size:root.labelSize;color:root.feedback ? Theme.text : Theme.muted
        elide:Text.ElideRight
    }
}
