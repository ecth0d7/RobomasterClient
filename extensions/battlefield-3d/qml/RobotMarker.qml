import QtQuick
import QtQuick3D
import QtQuick3D.AssetUtils
import "RobotVisual.js" as Art

Node {
    id: root
    property var record: ({x:14,y:7.5,kind:"sensor",team:"unknown",headingValid:false,headingDeg:0})
    property bool selected: false
    property bool releasing: false
    function releaseResources() { releasing=true; }
    property bool showUncertainty: true
    // 复用池退回空槽时会清空record；缺少朝向不能产生undefined布尔绑定或有方向外形。
    readonly property bool hasHeading: record.headingValid === true
    readonly property bool manual: record.kind === "annotation"
    readonly property bool boxOnly: record.kind === "vision" || record.kind === "fused" || record.kind === "conflict" || manual
    property bool cageAllocated: false
    function retainCage() { if (boxOnly || selected) cageAllocated = true; }
    onBoxOnlyChanged: retainCage()
    onSelectedChanged: retainCage()
    Component.onCompleted: retainCage()
    readonly property color hue: record.kind === "conflict" ? "#f2ce73" : record.team === "red" ? "#ff6e78" : record.team === "blue" ? "#62bbff" : "#96e7ce"
    // XY is observed. Y-up offset is presentation only, never measured altitude.
    position: Qt.vector3d(record.sceneX??0, 95, record.sceneZ??0)
    eulerRotation.y: hasHeading ? -record.headingDeg : 0
    DefaultMaterial { id: markerMaterial; diffuseColor: root.hue; lighting: DefaultMaterial.NoLighting }
    RuntimeLoader {
        id: robotArt
        property string targetKey: root.record.key ?? ""
        visible: !root.boxOnly && root.hasHeading && status === RuntimeLoader.Success
        // GLB使用米，Qt场景使用厘米；这不改变源数据的场地坐标。
        scale: Qt.vector3d(100, 100, 100)
        source: root.releasing || root.boxOnly || !root.hasHeading ? "" : Qt.resolvedUrl(Art.asset(root.record.robotId,root.record.team))
        onStatusChanged: if (status === RuntimeLoader.Success) Qt.callLater(() => root.enablePicking(robotArt))
    }
    function enablePicking(node) {
        if (node.pickable !== undefined) node.pickable = true;
        for (const child of node.children ?? []) enablePicking(child);
    }
    Model {
        objectName: "map3dTarget:" + (root.record.key ?? "")
        property string targetKey: root.record.key ?? ""
        pickable: root.visible
        source: "#Cylinder"
        scale: Qt.vector3d(.38, .12, .38)
        visible: !root.boxOnly && (!root.hasHeading || robotArt.status === RuntimeLoader.Error)
        materials: markerMaterial
    }
    readonly property bool detailedPose: !boxOnly && hasHeading
    readonly property var visual: Art.visual(record.robotId)
    readonly property real cageMinX: detailedPose ? visual.min[0]-4 : -29
    readonly property real cageMaxX: detailedPose ? visual.max[0]+4 : 29
    readonly property real cageMinZ: detailedPose ? visual.min[2]-4 : -35
    readonly property real cageMaxZ: detailedPose ? visual.max[2]+4 : 35
    readonly property real cageBottom: detailedPose ? visual.min[1]-4 : -24
    readonly property real cageTop: detailedPose ? visual.max[1]+4 : 24
    // 选择框包住显示模型；视觉／冲突候选仍用独立符号，不冒充已测量的机器人外形。

    Repeater3D {
        model: root.cageAllocated ? [
            [root.cageMinX,(root.cageTop+root.cageBottom)/2,root.cageMinZ,.025,(root.cageTop-root.cageBottom)/100,.025],
            [root.cageMaxX,(root.cageTop+root.cageBottom)/2,root.cageMinZ,.025,(root.cageTop-root.cageBottom)/100,.025],
            [root.cageMinX,(root.cageTop+root.cageBottom)/2,root.cageMaxZ,.025,(root.cageTop-root.cageBottom)/100,.025],
            [root.cageMaxX,(root.cageTop+root.cageBottom)/2,root.cageMaxZ,.025,(root.cageTop-root.cageBottom)/100,.025],
            [(root.cageMinX+root.cageMaxX)/2,root.cageTop,root.cageMinZ,(root.cageMaxX-root.cageMinX)/100,.025,.025],
            [(root.cageMinX+root.cageMaxX)/2,root.cageTop,root.cageMaxZ,(root.cageMaxX-root.cageMinX)/100,.025,.025],
            [root.cageMinX,root.cageTop,(root.cageMinZ+root.cageMaxZ)/2,.025,.025,(root.cageMaxZ-root.cageMinZ)/100],
            [root.cageMaxX,root.cageTop,(root.cageMinZ+root.cageMaxZ)/2,.025,.025,(root.cageMaxZ-root.cageMinZ)/100]
        ] : []
        Model {
            required property var modelData
            property string targetKey: root.record.key??""
            visible: root.visible && (root.boxOnly || root.selected)
            pickable: visible
            source:"#Cube";position:Qt.vector3d(modelData[0],modelData[1],modelData[2]);scale:Qt.vector3d(modelData[3],modelData[4],modelData[5])
            materials:markerMaterial
        }
    }
    Model {
        source:"#Rectangle"
        visible:root.showUncertainty && Number.isFinite(root.record.uncertaintyM) && root.record.uncertaintyM>0
        position.y:-91;eulerRotation.x:-90
        scale:Qt.vector3d((root.record.uncertaintyM??0)*2,(root.record.uncertaintyM??0)*2,1)
        materials:DefaultMaterial {
            diffuseColor:root.hue;lighting:DefaultMaterial.NoLighting
            diffuseMap:Texture {source:"../assets/uncertainty-ring.svg"}
            cullMode:Material.NoCulling
        }
        opacity:root.selected ? 0.8 : 0.35
    }
    Model {source:"#Cylinder";position.y:-47;scale:Qt.vector3d(.035,.8,.035);materials:markerMaterial;opacity:.5}
}
