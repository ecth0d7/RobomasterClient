import QtQuick
import QtCore

// The optional scene loads on M and can remain hidden for 30 seconds for reuse.
// Core QML never imports QtQuick3D; missing dependencies retain the 2D map.
Item {
    id: root
    signal modeRequested(int mode)
    signal pointPicked(real mapX, real mapY)
    Connections {
        target: scene.item
        function onModeRequested(mode) { root.modeRequested(mode); }
        function onPointPicked(mapX,mapY) { root.pointPicked(mapX,mapY); }
    }
    property bool requested: true
    property bool previewOnly: false
    property bool mapOpen: false
    property bool connected: false
    property bool warmed: false
    // 高频开关M时短暂复用场景；关闭约30秒后卸载，停用插件时立即卸载。
    onMapOpenChanged: if (mapOpen && requested && !previewOnly) warmed = true
    property var telemetry: null
    property int clientID: 3
    property var headingItems: []
    property var projectionItems: []
    property var discoveryMarkers: []
    property var fusionView: ({})
    property real hudScale: 1
    readonly property bool graphicsAvailable: GraphicsInfo.api !== GraphicsInfo.Software
    readonly property bool sceneReady: scene.status === Loader.Ready && scene.item?.sceneUsable === true
    readonly property var renderer: scene.item
    readonly property string statusText: !requested ? "已停用 · M 使用二维地图"
        : !graphicsAvailable ? "当前为软件渲染 · M 保留二维地图，3D需auto/OpenGL"
        : scene.status === Loader.Error ? "3D插件或依赖加载失败 · 已保留二维地图"
        : scene.status === Loader.Ready && scene.item?.loadError ? "模型加载失败 · 已保留二维地图"
        : sceneReady ? "2027立体地图已接入 · 数据坐标适配见地图说明"
        : mapOpen ? "正在加载2027场地模型 · 暂用二维地图" : "已启用 · 按M加载2027立体地图"
    function releaseScene() {
        if (scene.item && typeof scene.item.releaseResources === "function") scene.item.releaseResources();
    }
    function setEnabled(value) {
        if (!value) releaseScene();
        requested=value;
    }
    Component.onCompleted: if (mapOpen && requested && !previewOnly) warmed = true
    onRequestedChanged: {
        if (preferences.item) preferences.item.enabledMap = requested;
        if (!requested) warmed = false;
    }
    Timer {
        interval: 30000
        running: root.warmed && !root.mapOpen && root.requested && !root.previewOnly
        onTriggered: {root.releaseScene();root.warmed=false;}
    }
    Loader {
        id: preferences
        active: !root.previewOnly
        sourceComponent: Component {
            Settings { category: "OptionalPlugins/Battlefield3D"; property bool enabledMap: true }
        }
        onLoaded: root.requested = item.enabledMap
    }
    Loader {
        id: scene
        anchors.fill: parent
        active: root.requested && (root.mapOpen || root.warmed) && !root.previewOnly && root.graphicsAvailable
        visible: root.sceneReady
        asynchronous: true
        source: active ? Qt.resolvedUrl("../../extensions/battlefield-3d/qml/Field3D.qml") : ""
        onLoaded: {
            if (root.mapOpen) root.warmed = true;
            item.telemetry = Qt.binding(() => root.telemetry);
            item.connected = Qt.binding(() => root.connected);
            item.clientID = Qt.binding(() => root.clientID);
            item.headingItems = Qt.binding(() => root.headingItems);
            item.projectionItems = Qt.binding(() => root.projectionItems);
            item.discoveryMarkers = Qt.binding(() => root.discoveryMarkers);
            item.fusionView = Qt.binding(() => root.fusionView);
            item.hudScale = Qt.binding(() => root.hudScale);
            if (typeof item.refresh === "function") item.refresh();
        }
    }
}
