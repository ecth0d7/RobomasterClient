import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtCore

ApplicationWindow {
    id: root
    width: 1280
    height: 750
    minimumWidth: 960
    minimumHeight: 540
    visible: true
    title: "RoboMaster 2027 自定义终端"
    color: Theme.background
    flags: Qt.FramelessWindowHint | Qt.Window
    property alias ui: uiLayer
    property bool designPreview: false
    property bool auxiliaryInteractionBlocked: false
    property bool startupAnimationPending: true
    property bool startupAnimationPreview: false
    readonly property bool bootSequenceActive: !designPreview && startupAnimationPending
        && (startupAnimationPreview || Theme.startupAnimationEnabled) && !Theme.reducedMotion
    property string previewCaption: "离线UI绘制样例 · 非实机数据"
    property bool previewCaptionAlwaysVisible: false
    property string workspaceCaption: ""
    property int beforeFullscreen: Window.Windowed
    property bool fallbackDragging: false
    property point dragStart: Qt.point(0, 0)
    property point windowStart: Qt.point(0, 0)
    readonly property bool fullscreen: visibility === Window.FullScreen
    readonly property bool maximized: visibility === Window.Maximized

    // 预览器没有持久化副作用；正式窗口只保存 UI 偏好，独立于联网配置。
    Loader {
        active: !root.designPreview
        sourceComponent: Component {
            Settings {
                category: "OperatorHudV1"
                property string layoutJson: ""
                property string decisionJson: ""
                property string startupJson: ""
                property string teamConfigJson: ""
                property string sourceJson: ""
                property string providerJson: ""
                property string shortcutsJson: ""
                Component.onCompleted: {
                    root.ui.layoutStateObject.restore(layoutJson);
                    root.ui.decisionPreferencesObject.restore(decisionJson);
                    root.ui.startupPreferencesObject.restore(startupJson);
                    root.ui.teamConfigPreferencesObject.restore(teamConfigJson);
                    root.ui.sourcePreferencesObject.restore(sourceJson);
                    root.ui.providerPreferencesObject.restore(providerJson);
                    root.ui.shortcutPreferencesObject.restore(shortcutsJson);
                }
            }
        }
        onLoaded: {
            storageConnections.target = root.ui.layoutStateObject;
            decisionStorageConnections.target = root.ui.decisionPreferencesObject;
            startupStorageConnections.target = root.ui.startupPreferencesObject;
            teamConfigStorageConnections.target = root.ui.teamConfigPreferencesObject;
            sourceStorageConnections.target = root.ui.sourcePreferencesObject;
            providerStorageConnections.target = root.ui.providerPreferencesObject;
            shortcutStorageConnections.target = root.ui.shortcutPreferencesObject;
        }
        id: layoutStorage
    }
    Connections {
        id: storageConnections
        target: null
        function onEdited() {
            if (layoutStorage.item)
                layoutStorage.item.layoutJson = root.ui.layoutStateObject.serialized;
        }
    }
    Connections {
        id: decisionStorageConnections
        target: null
        function onEdited() {
            if (layoutStorage.item) layoutStorage.item.decisionJson = root.ui.decisionPreferencesObject.serialized;
        }
    }
    Connections {
        id: startupStorageConnections
        target: null
        function onEdited() {
            if (layoutStorage.item) layoutStorage.item.startupJson = root.ui.startupPreferencesObject.serialized;
        }
    }
    Connections {
        id: teamConfigStorageConnections
        target: null
        function onEdited() {
            if (layoutStorage.item) layoutStorage.item.teamConfigJson = root.ui.teamConfigPreferencesObject.serialized;
        }
    }
    Connections {
        id: sourceStorageConnections
        target: null
        function onEdited() {
            if (layoutStorage.item) layoutStorage.item.sourceJson = root.ui.sourcePreferencesObject.serialized;
        }
    }
    Connections {
        id: providerStorageConnections
        target: null
        function onEdited() {
            if (layoutStorage.item) layoutStorage.item.providerJson = root.ui.providerPreferencesObject.serialized;
        }
    }
    Connections {
        id: shortcutStorageConnections
        target: null
        function onEdited() { if(layoutStorage.item)layoutStorage.item.shortcutsJson=root.ui.shortcutPreferencesObject.serialized; }
    }

    function toggleFullscreen() {
        if (fullscreen) {
            if (beforeFullscreen === Window.Maximized)
                showMaximized();
            else
                showNormal();
            return;
        }
        beforeFullscreen = visibility;
        showFullScreen();
    }
    function toggleMaximize() {
        if (fullscreen) {
            beforeFullscreen = Window.Maximized;
            showMaximized();
        } else if (maximized) {
            showNormal();
        } else {
            showMaximized();
        }
    }
    Shortcut {
        sequence: "Escape"
        enabled: !root.auxiliaryInteractionBlocked && !uiLayer.modalActive && !uiLayer.resultPresentationVisible
        autoRepeat: false
        onActivated: uiLayer.openPanel("settings")
    }

    UI {
        id: uiLayer
        objectName: "operatorUi"
        previewOnly: root.designPreview
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.fullscreen ? 0 : 30
        anchors.bottom: parent.bottom
    }
    Connections {
        target: Theme
        function onReducedMotionChanged() {
            if (Theme.reducedMotion) {
                root.startupAnimationPending = false;
                root.startupAnimationPreview = false;
                Qt.callLater(uiLayer.restorePanelFocus);
            }
        }
        function onStartupAnimationEnabledChanged() {
            if (!Theme.startupAnimationEnabled && !root.startupAnimationPreview)
                root.startupAnimationPending = false;
        }
    }
    Connections {
        target: uiLayer
        function onStartupPreviewRequested() {
            root.startupAnimationPreview = true;
            root.startupAnimationPending = true;
        }
    }
    Loader {
        id: bootLoader
        anchors.fill: uiLayer
        z: 200
        active: root.bootSequenceActive
        focus: root.bootSequenceActive
        onLoaded: item.forceActiveFocus()
        Component.onCompleted: {
            if (!Theme.startupAnimationEnabled || Theme.reducedMotion) root.startupAnimationPending = false;
        }
        sourceComponent: Component {
            OperatorBootSequence {
                forcePlayback: root.startupAnimationPreview
                connectionStatus: uiLayer.mqttConnected ? "消息通道已连接"
                    : uiLayer.mqttConnecting ? "消息通道连接中" : "消息通道未连接"
                videoStatus: uiLayer.videoSource?.status ?? "等待码流"
                onCompleted: {
                    root.startupAnimationPending = false;
                    root.startupAnimationPreview = false;
                    Qt.callLater(uiLayer.restorePanelFocus);
                }
            }
        }
    }
    Rectangle {
        // 参考界面在所有窗口状态都明确标样例，避免将旧赛季绘制当成生产数据。
        visible: root.designPreview && (root.fullscreen || root.previewCaptionAlwaysVisible)
            || root.workspaceCaption.length > 0
        x: (parent.width - width) / 2
        y: parent.height - height - 3
        width: Math.min(parent.width - 24, Math.max(278, previewLabel.implicitWidth + 24))
        height: 24
        color: Theme.hudSurface
        z: 100
        OperatorText {
            id: previewLabel
            anchors.fill: parent
            text: root.designPreview ? root.previewCaption : root.workspaceCaption
            size: 11
            scaleWithHud: false
            horizontalAlignment: Text.AlignHCenter
            color: Theme.muted
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.workspaceCaption.length > 0 && !root.ui.captureDesired
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.ui.openPanel(root.ui.loginOpen ? "none" : "login")
        }
    }
    Rectangle {
        id: chrome
        enabled: uiLayer.modalActive || !uiLayer.captureDesired
        anchors.top: parent.top
        width: parent.width
        height: 30
        visible: !root.fullscreen || topEdge.hovered || chromeHover.hovered || controls.hovered
        color: root.fullscreen ? "#df202623" : "#202623"
        z: 100
        HoverHandler { id: chromeHover }
        OperatorText {
            x: 13
            height: parent.height
            width: Math.max(100, parent.width - 260)
            text: root.designPreview ? root.previewCaption : root.title
            size: 10
            scaleWithHud: false
            color: Theme.muted
        }
        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: 152
            enabled: !root.fullscreen && !(uiLayer.inputState?.mouseCaptureEnabled ?? false)
            onDoubleClicked: root.toggleMaximize()
            onPressed: mouse => {
                root.dragStart = mapToGlobal(mouse.x, mouse.y);
                root.windowStart = Qt.point(root.x, root.y);
                root.fallbackDragging = !root.startSystemMove();
            }
            onPositionChanged: mouse => {
                if (!pressed || !root.fallbackDragging)
                    return;
                const point = mapToGlobal(mouse.x, mouse.y);
                root.x = root.windowStart.x + point.x - root.dragStart.x;
                root.y = root.windowStart.y + point.y - root.dragStart.y;
            }
            onReleased: root.fallbackDragging = false
            onCanceled: root.fallbackDragging = false
        }
        Row {
            anchors.right: parent.right
            height: parent.height
            HoverHandler { id: controls }
            Repeater {
                model: ["最小化", "最大化", "全屏", "关闭"]
                Button {
                    required property int index
                    required property string modelData
                    width: 38
                    height: 30
                    focusPolicy: Qt.NoFocus
                    Accessible.name: modelData
                    ToolTip.visible: hovered
                    ToolTip.text: modelData
                    contentItem: Item {
                        property int iconIndex: parent.index
                        Item {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            Rectangle { x: 1; y: 10; width: 12; height: 1; color: Theme.text; visible: parent.parent.iconIndex === 0 }
                            Rectangle { x: 1; y: 1; width: 12; height: 12; color: "transparent"; border.color: Theme.text; visible: parent.parent.iconIndex === 1 }
                            Rectangle { x: 3; y: 3; width: 12; height: 12; color: "transparent"; border.color: Theme.text; visible: parent.parent.iconIndex === 1 && root.maximized }
                            Rectangle { x: 0; y: 0; width: 5; height: 1; color: Theme.text; visible: parent.parent.iconIndex === 2 }
                            Rectangle { x: 0; y: 0; width: 1; height: 5; color: Theme.text; visible: parent.parent.iconIndex === 2 }
                            Rectangle { x: 9; y: 13; width: 5; height: 1; color: Theme.text; visible: parent.parent.iconIndex === 2 }
                            Rectangle { x: 13; y: 9; width: 1; height: 5; color: Theme.text; visible: parent.parent.iconIndex === 2 }
                            Rectangle { anchors.centerIn: parent; width: 16; height: 1; rotation: 45; color: Theme.text; visible: parent.parent.iconIndex === 3 }
                            Rectangle { anchors.centerIn: parent; width: 16; height: 1; rotation: -45; color: Theme.text; visible: parent.parent.iconIndex === 3 }
                        }
                    }
                    background: Rectangle {
                        color: parent.hovered ? (parent.index === 3 ? "#b94d42" : "#42564c") : "transparent"
                    }
                    onClicked: {
                        if (index === 0) root.showMinimized();
                        if (index === 1) root.toggleMaximize();
                        if (index === 2) root.toggleFullscreen();
                        if (index === 3) root.close();
                    }
                }
            }
        }
    }
    Item {
        width: root.width
        height: 30
        // 全屏时保留顶部感应区域，鼠标可以重新唤出窗口控件。
        HoverHandler { id: topEdge }
    }
}
