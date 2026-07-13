pragma ComponentBehavior: Bound

import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import QtQuick.Window 6.5
import "."

ApplicationWindow {
    id: root
    width: 1280
    height: 720
    minimumWidth: 960
    minimumHeight: 600
    visible: true
    color: Theme.background
    title: "HNU 英雄机器人副屏"
    flags: Qt.FramelessWindowHint | Qt.Window

    property var tlm: ({})
    // 将 C++ 上下文对象集中到根属性，子组件统一通过 root 访问。
    property var clientBackend: heroClient
    property bool loggedIn: false
    property real expectedTrim: 0.0
    property bool hasExpectedTrim: false
    property bool stepReady: true
    property string commandHint: ""
    property int activeFeedbackStep: 0
    property bool feedbackAccepted: false
    property bool fullScreenMode: false
    property bool resetFeedbackActive: false
    property bool expectedMismatchVisible: false
    // 鼠标按钮使用当前步长；键盘组合键仍可直接发送 1/2/4 步。
    property int selectedTrimStep: 1

    function modeName(mode) {
        return ["IDLE", "AUTO AIM", "SMALL BUFF", "BIG BUFF", "DEPLOY"][mode] || "UNKNOWN"
    }

    function solverName(status) {
        return ["SUCCESS", "OUT OF RANGE", "NO SOLUTION", "NOT CONVERGED"][status] || "UNKNOWN"
    }

    function fmt(value, digits, suffix) {
        return value === undefined ? "--" : Number(value).toFixed(digits) + suffix
    }

    function toggleFullScreen() {
        if (root.fullScreenMode) {
            root.showNormal()
            root.fullScreenMode = false
        } else {
            root.fullScreenMode = true
            root.showFullScreen()
        }
        // 鼠标点击窗口按钮后，把键盘焦点归还主画面，避免Enter再次激活该按钮。
        Qt.callLater(function() { scene.forceActiveFocus() })
    }

    function resetTrim() {
        if (!root.clientBackend.connected) {
            root.commandHint = "MQTT 未连接，清零命令未发送"
            return
        }
        root.hasExpectedTrim = true
        root.expectedMismatchVisible = false
        root.expectedTrim = 0
        expectedValueGrace.restart()
        root.resetFeedbackActive = true
        resetFeedbackTimer.restart()
        root.clientBackend.trimReset()
    }

    function sendStep(step) {
        root.selectedTrimStep = Math.abs(step)
        root.activeFeedbackStep = step
        root.feedbackAccepted = root.clientBackend.connected && root.stepReady && Number(root.tlm.mode) === 4
        feedbackReset.restart()
        trimFeedbackAnimation.restart()

        if (!root.clientBackend.connected || !root.stepReady || Number(root.tlm.mode) !== 4) {
            root.commandHint = !root.clientBackend.connected ? "MQTT 未连接，微调未发送"
                             : (Number(root.tlm.mode) !== 4 ? "非 DEPLOY 模式，微调未发送"
                                                           : "操作过快，请等待 0.2s")
            return
        }

        root.expectedTrim = Number(root.tlm.pitch_trim_deg || 0) + step * 0.05
        root.hasExpectedTrim = true
        root.expectedMismatchVisible = false
        expectedValueGrace.restart()
        root.clientBackend.trimStep(step)
        root.stepReady = false
        stepCooldown.restart()
    }

    Timer {
        id: stepCooldown
        interval: 200
        onTriggered: root.stepReady = true
    }

    Timer {
        id: feedbackReset
        interval: 560
        onTriggered: root.activeFeedbackStep = 0
    }

    Timer {
        id: resetFeedbackTimer
        interval: 520
        onTriggered: root.resetFeedbackActive = false
    }

    // 命令发出后先等待车端遥测回环，避免旧遥测帧造成“不一致”提示闪烁。
    Timer {
        id: expectedValueGrace
        interval: 600
        onTriggered: root.expectedMismatchVisible = root.hasExpectedTrim
    }

    Shortcut { sequence: "Up"; enabled: root.loggedIn; onActivated: root.sendStep(1) }
    Shortcut { sequence: "Down"; enabled: root.loggedIn; onActivated: root.sendStep(-1) }
    Shortcut { sequence: "Shift+Up"; enabled: root.loggedIn; onActivated: root.sendStep(2) }
    Shortcut { sequence: "Shift+Down"; enabled: root.loggedIn; onActivated: root.sendStep(-2) }
    Shortcut { sequence: "Ctrl+Up"; enabled: root.loggedIn; onActivated: root.sendStep(4) }
    Shortcut { sequence: "Ctrl+Down"; enabled: root.loggedIn; onActivated: root.sendStep(-4) }
    // ESC 只负责退出全屏，不关闭程序；主键盘与小键盘 Enter 都执行 trim 清零。
    Shortcut {
        sequence: "Escape"
        enabled: root.fullScreenMode
        onActivated: {
            root.showNormal()
            root.fullScreenMode = false
        }
    }
    Shortcut { sequence: "Return"; enabled: root.loggedIn && root.clientBackend.connected; onActivated: root.resetTrim() }
    Shortcut { sequence: "Enter"; enabled: root.loggedIn && root.clientBackend.connected; onActivated: root.resetTrim() }

    Connections {
        target: root.clientBackend

        function onTelemetryUpdated(value) {
            root.tlm = value
            if (root.hasExpectedTrim
                    && Math.abs(Number(value.pitch_trim_deg) - root.expectedTrim) < 0.026) {
                root.hasExpectedTrim = false
                root.expectedMismatchVisible = false
                expectedValueGrace.stop()
            }
        }

        function onFrameReady() {
            video.source = "image://heroVideo/latest?" + Date.now()
        }

        function onCommandSent(seq, command, parameter) {
            root.commandHint = "命令已发送  seq=" + seq + " cmd=" + command + " param=" + parameter
        }

        function onCommandRejected(reason) {
            root.commandHint = reason
            root.hasExpectedTrim = false
            root.expectedMismatchVisible = false
            expectedValueGrace.stop()
        }
    }

    // 兼容软件渲染的“液态玻璃”表面：透明渐变、内反光和高光边替代实时模糊。
    component GlassLayer: Item {
        id: glassLayer
        property real cornerRadius: Theme.radiusPanel
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: glassLayer.cornerRadius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.glassTop }
                GradientStop { position: 0.38; color: Theme.glassMiddle }
                GradientStop { position: 1.0; color: Theme.glassBottom }
            }
        }

        // 双层边缘形成玻璃厚度；只使用基础图元，不触发 shader 渲染。
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, glassLayer.cornerRadius - 1)
            color: "transparent"
            border.width: 1
            border.color: Theme.glassInnerHighlight
            opacity: 0.62
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: glassLayer.cornerRadius
            anchors.right: parent.right
            anchors.rightMargin: glassLayer.cornerRadius
            anchors.top: parent.top
            anchors.topMargin: 2
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.28; color: Theme.glassSpecular }
                GradientStop { position: 0.72; color: Theme.glassSpecular }
                GradientStop { position: 1.0; color: "transparent" }
            }
            opacity: 0.78
        }
    }

    // 固定宽度的数据行，数值变化时不会推动标签或面板位置。
    component DataRow: Item {
        id: dataRow
        required property string label
        required property string value
        property color valueColor: Theme.textPrimary
        Layout.fillWidth: true
        height: 27

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 96
            text: dataRow.label
            color: Theme.textSecondary
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 124
            text: dataRow.value
            color: dataRow.valueColor
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 14
            font.bold: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    // 固定尺寸状态条，只通过颜色与文字表达状态变化。
    component StateRow: Rectangle {
        id: stateRow
        required property string label
        required property bool active
        Layout.fillWidth: true
        height: 30
        radius: Theme.radiusSmall
        color: "transparent"
        border.width: 1
        border.color: stateRow.active ? "#a87ce9ae" : "#8f8b5260"
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: stateRow.active ? "#8f39725c" : "#80463242"
            }
            GradientStop {
                position: 1.0
                color: stateRow.active ? "#7a173a2c" : "#70201520"
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: stateRow.active ? "#55ef9f" : "#d5677e"
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: stateRow.label
            color: Theme.textPrimary
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
        }
    }

    // 步长只负责选择幅度，方向由两个固定大按钮表达，降低临场误触概率。
    component StepChip: Button {
        id: stepChip
        required property int stepValue
        Layout.preferredWidth: 54
        Layout.preferredHeight: 30
        focusPolicy: Qt.NoFocus
        text: stepValue + " 步"
        onClicked: root.selectedTrimStep = stepValue

        contentItem: Text {
            text: stepChip.text
            color: root.selectedTrimStep === stepChip.stepValue ? Theme.textPrimary : Theme.textSecondary
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 11
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: Theme.radiusSmall
            color: "transparent"
            border.width: 1
            border.color: root.selectedTrimStep === stepChip.stepValue ? Theme.accent : Theme.borderSoft
            scale: stepChip.down ? 0.94 : 1.0
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: stepChip.down ? "#d04d9bc3"
                          : (root.selectedTrimStep === stepChip.stepValue
                             ? "#a84891b7" : Theme.glassButton)
                }
                GradientStop {
                    position: 1.0
                    color: stepChip.down ? Theme.accentDeep
                          : (root.selectedTrimStep === stepChip.stepValue
                             ? "#99214f69" : "#75101f2b")
                }
            }
            Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: Theme.motionNormal } }
        }
    }

    component TrimDirectionButton: Button {
        id: directionButton
        required property int direction
        readonly property bool feedbackActive: direction > 0
                                               ? root.activeFeedbackStep > 0
                                               : root.activeFeedbackStep < 0
        Layout.preferredWidth: 58
        Layout.preferredHeight: 52
        focusPolicy: Qt.NoFocus
        enabled: root.clientBackend.connected && root.stepReady
        onClicked: root.sendStep(direction * root.selectedTrimStep)
        scale: directionButton.down || directionButton.feedbackActive ? 0.92 : 1.0

        ToolTip.visible: hovered
        ToolTip.delay: 400
        ToolTip.text: (direction > 0 ? "上调  +" : "下调  −")
                      + root.selectedTrimStep + " 步"

        contentItem: Text {
            text: directionButton.direction > 0 ? "↑" : "↓"
            color: !directionButton.enabled ? Theme.textMuted
                 : (directionButton.feedbackActive ? "#ffffff" : Theme.textPrimary)
            font.family: "DejaVu Sans"
            font.pixelSize: 25
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 9
            color: "transparent"
            border.width: directionButton.feedbackActive ? 2 : 1
            border.color: directionButton.feedbackActive
                          ? (root.feedbackAccepted ? Theme.success : Theme.danger)
                          : Theme.border
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: directionButton.down ? "#e14b98be"
                          : (directionButton.feedbackActive
                             ? (root.feedbackAccepted ? "#d0449c76" : "#d0873c52")
                             : "#dc405464")
                }
                GradientStop {
                    position: 1.0
                    color: directionButton.down ? Theme.accentDeep
                          : (directionButton.feedbackActive
                             ? (root.feedbackAccepted ? Theme.successDeep : Theme.dangerDeep)
                             : "#db162630")
                }
            }

            // OBS 键位提示风格的键帽底沿，按下时会变薄。
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 7
                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                height: directionButton.down ? 1 : 3
                radius: 2
                color: directionButton.feedbackActive
                       ? (root.feedbackAccepted ? Theme.success : Theme.danger)
                       : "#b6a6bac7"
                opacity: directionButton.enabled ? 0.72 : 0.30
                Behavior on height { NumberAnimation { duration: Theme.motionFast } }
            }

            Behavior on border.color { ColorAnimation { duration: Theme.motionNormal } }
        }

        Behavior on scale {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutBack }
        }
    }

    // 统一的窗口按钮样式，复用原客户端图标资源。
    component WindowButton: Button {
        id: windowButton
        required property url iconSource
        property bool danger: false
        property string tipText: ""
        width: 36
        height: 36
        focusPolicy: Qt.NoFocus
        display: AbstractButton.IconOnly
        icon.source: iconSource
        icon.color: "#f4f7f9"
        icon.width: 19
        icon.height: 19

        ToolTip.visible: hovered
        ToolTip.delay: 500
        ToolTip.text: tipText

        background: Rectangle {
            radius: 18
            color: windowButton.down
                   ? (windowButton.danger ? "#d9364d" : Theme.glassButtonHover)
                   : (windowButton.hovered
                      ? (windowButton.danger ? "#b92d42" : Theme.glassButtonHover)
                      : Theme.glassButton)
            border.width: 1
            border.color: windowButton.hovered
                          ? (windowButton.danger ? "#ff7a8d" : "#8298a7")
                          : "#4f6574"
            Behavior on color { ColorAnimation { duration: 100 } }
        }
    }

    component GlassTextField: TextField {
        id: glassField
        color: Theme.textPrimary
        placeholderTextColor: Theme.textMuted
        selectionColor: Theme.accentDeep
        leftPadding: 16
        rightPadding: 16
        font.pixelSize: 13
        Layout.fillWidth: true
        Layout.preferredHeight: 42

        background: Rectangle {
            radius: 14
            color: "transparent"
            border.width: glassField.activeFocus ? 2 : 1
            border.color: glassField.activeFocus ? Theme.accent : Theme.borderSoft
            gradient: Gradient {
                GradientStop { position: 0.0; color: glassField.activeFocus ? "#9b365f78" : Theme.glassButton }
                GradientStop { position: 1.0; color: "#8a0d1a25" }
            }
            Behavior on border.color { ColorAnimation { duration: Theme.motionNormal } }
        }
    }

    Item {
        id: scene
        anchors.fill: parent
        focus: true

        // 视频是整个 HUD 的最底层，裁切铺满窗口，不参与任何面板布局。
        Rectangle {
            anchors.fill: parent
            color: "#020406"
            z: 0
        }

        Image {
            id: video
            anchors.fill: parent
            z: 1
            cache: false
            smooth: true
            fillMode: Image.PreserveAspectCrop
        }

        // 视频未到达时保留暗色背景；提示放在准星上方，与下方 RK45 状态分离。
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -82
            z: 2
            visible: video.status !== Image.Ready
            width: 280
            text: "等待 HNU-VID H.264 视频"
            color: "#9babb8"
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
        }

        // 上下渐变只增强 HUD 可读性，不遮挡视频主体。
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 120
            z: 3
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#d9000000" }
                GradientStop { position: 1.0; color: "#00000000" }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 210
            z: 3
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 1.0; color: "#d9000000" }
            }
        }

        // 顶部状态栏采用固定高度，连接状态改变不会改变几何尺寸。
        Rectangle {
            id: topBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 54
            z: 10
            color: "transparent"
            border.width: 0

            GlassLayer { cornerRadius: 0 }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                width: 255
                text: "HNU HERO  ·  DEPLOY CONTROL"
                color: "#f4f8fa"
                font.pixelSize: 17
                font.bold: true
                elide: Text.ElideRight
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 290
                anchors.verticalCenter: parent.verticalCenter
                width: 170
                height: 32
                radius: 16
                color: "transparent"
                border.color: Number(root.tlm.mode) === 4 ? "#cce9b35f" : Theme.borderSoft
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Number(root.tlm.mode) === 4 ? "#a67c572b" : Theme.glassButtonHover }
                    GradientStop { position: 1.0; color: Number(root.tlm.mode) === 4 ? "#8a342814" : "#7010202c" }
                }

                Text {
                    anchors.centerIn: parent
                    width: 156
                    text: root.modeName(Number(root.tlm.mode))
                          + (root.tlm.force_deploy ? " · FORCE" : "")
                    color: Number(root.tlm.mode) === 4 ? "#ffd083" : "#d3dbe1"
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 142
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 190
                    height: 32
                    radius: 16
                    color: "transparent"
                    border.color: root.clientBackend.connected ? "#55ef9f" : "#ef657a"
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.glassButtonHover }
                        GradientStop { position: 1.0; color: "#7010202c" }
                    }

                    Rectangle {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: root.clientBackend.connected ? "#55ef9f" : "#ef657a"
                    }

                    Text {
                        x: 26
                        width: 154
                        anchors.verticalCenter: parent.verticalCenter
                        text: "MQTT  " + root.clientBackend.statusText
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    width: 156
                    height: 32
                    radius: 16
                    color: "transparent"
                    border.color: root.clientBackend.telemetryOnline ? "#55ef9f" : "#ef657a"
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.glassButtonHover }
                        GradientStop { position: 1.0; color: "#7010202c" }
                    }

                    Rectangle {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: root.clientBackend.telemetryOnline ? "#55ef9f" : "#ef657a"
                    }

                    Text {
                        x: 26
                        width: 120
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.clientBackend.telemetryOnline ? "视觉遥测在线" : "视觉遥测超时"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 2
                color: Theme.glassSpecular
                opacity: 0.38
            }
        }

        // 左侧信息按“目标解算 → 武器反馈”排列，操作手可沿同一阅读轴扫视。
        Rectangle {
            anchors.fill: targetSolutionPanel
            anchors.leftMargin: 2
            anchors.topMargin: 4
            z: 9
            radius: Theme.radiusPanel
            color: Theme.shadow
        }

        Rectangle {
            id: targetSolutionPanel
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.top: topBar.bottom
            anchors.topMargin: 18
            width: 252
            height: 190
            z: 10
            radius: Theme.radiusPanel
            color: "transparent"
            border.color: Theme.border
            border.width: 1

            GlassLayer {}
            Rectangle { anchors.left: parent.left; anchors.leftMargin: 18; anchors.top: parent.top; width: 68; height: 2; radius: 1; color: Theme.accent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.panelPadding
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    spacing: 9
                    Image { source: "qrc:/images/target.svg"; sourceSize: Qt.size(20, 20); Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                    Text { text: "目标与解算"; color: Theme.textPrimary; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true }
                    Text {
                        text: Number(root.tlm.solver_status) === 0 ? "READY" : "CHECK"
                        color: Number(root.tlm.solver_status) === 0 ? Theme.success : Theme.danger
                        font.family: "DejaVu Sans Mono"; font.pixelSize: 9; font.bold: true
                    }
                }

                DataRow { label: "水平距离"; value: (root.tlm.radar_fresh || root.tlm.radar_hold) ? root.fmt(root.tlm.distance_m, 2, " m") : "无雷达" }
                DataRow { label: "高度差"; value: (root.tlm.radar_fresh || root.tlm.radar_hold) ? root.fmt(root.tlm.height_m, 2, " m") : "无雷达" }
                DataRow { label: "飞行时间"; value: root.fmt(root.tlm.tof_s, 3, " s") }
                DataRow { label: "Yaw 误差"; value: root.fmt(root.tlm.yaw_err_deg, 2, "°") }
                DataRow { label: "Pitch 误差"; value: root.fmt(root.tlm.pitch_err_deg, 2, "°") }
            }
        }

        Rectangle {
            anchors.fill: weaponPanel
            anchors.leftMargin: 2
            anchors.topMargin: 4
            z: 9
            radius: Theme.radiusPanel
            color: Theme.shadow
        }

        Rectangle {
            id: weaponPanel
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.top: targetSolutionPanel.bottom
            anchors.topMargin: 10
            width: 252
            height: 128
            z: 10
            radius: Theme.radiusPanel
            color: "transparent"
            border.color: Theme.border
            border.width: 1

            GlassLayer {}
            Rectangle { anchors.left: parent.left; anchors.leftMargin: 18; anchors.top: parent.top; width: 68; height: 2; radius: 1; color: Theme.warning }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.panelPadding
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    spacing: 9
                    Image { source: "qrc:/images/gauge.svg"; sourceSize: Qt.size(20, 20); Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                    Text { text: "武器与云台"; color: Theme.textPrimary; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true }
                }

                DataRow { label: "实测弹速"; value: root.fmt(root.tlm.bullet_speed_rx, 2, " m/s") }
                DataRow { label: "RK45 弹速"; value: root.fmt(root.tlm.solver_v0, 2, " m/s") }
                DataRow { label: "云台 Pitch"; value: root.fmt(root.tlm.pitch_meas_deg, 2, "°") }
            }
        }

        // 右侧从上到下就是视觉安全链的判定顺序。
        Rectangle {
            anchors.fill: safetyPanel
            anchors.leftMargin: 2
            anchors.topMargin: 4
            z: 9
            radius: Theme.radiusPanel
            color: Theme.shadow
        }

        Rectangle {
            id: safetyPanel
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.top: topBar.bottom
            anchors.topMargin: 18
            width: 252
            height: 260
            z: 10
            radius: Theme.radiusPanel
            color: "transparent"
            border.color: Theme.border
            border.width: 1

            GlassLayer {}
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 18; anchors.top: parent.top; width: 68; height: 2; radius: 1; color: Theme.success }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.panelPadding
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    spacing: 9
                    Image { source: "qrc:/images/shield-check.svg"; sourceSize: Qt.size(20, 20); Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                    Text { text: "发射安全链"; color: Theme.textPrimary; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true }
                    Text {
                        text: root.tlm.fire_allowed ? "GO" : "HOLD"
                        color: root.tlm.fire_allowed ? Theme.success : Theme.danger
                        font.family: "DejaVu Sans Mono"; font.pixelSize: 10; font.bold: true
                    }
                }

                StateRow { label: "核心已检测"; active: !!root.tlm.core_ok }
                StateRow { label: root.tlm.radar_hold ? "雷达短时保持" : "雷达数据新鲜"; active: !!(root.tlm.radar_fresh || root.tlm.radar_hold) }
                StateRow { label: "RK45 解算成功"; active: !!root.tlm.deploy_solved }
                StateRow { label: "Yaw 已收敛"; active: !!root.tlm.yaw_converged }
                StateRow { label: "FULL ADJUST"; active: !!root.tlm.phase_full_adjust }
                StateRow { label: "视觉允许开火"; active: !!root.tlm.fire_allowed }
            }
        }

        // 与原客户端一致，准星永远锚定在视频画面的几何中心。
        Item {
            id: crosshair
            anchors.centerIn: parent
            width: 60
            height: 60
            z: 20

            Image {
                anchors.fill: parent
                source: "qrc:/images/crosshair.png"
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }
        }

        Rectangle {
            anchors.left: crosshair.right
            anchors.leftMargin: 28
            anchors.verticalCenter: crosshair.verticalCenter
            width: 142
            height: 38
            z: 20
            radius: 19
            color: "transparent"
            border.color: root.tlm.fire_allowed ? "#69f0ae" : "#ff6b81"
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.tlm.fire_allowed ? "#a7438a6c" : "#a47a3b4d" }
                GradientStop { position: 1.0; color: root.tlm.fire_allowed ? "#8a153e30" : "#8a351823" }
            }

            Text {
                anchors.centerIn: parent
                width: 128
                text: root.tlm.fire_allowed ? "视觉请求开火" : "禁止开火"
                color: "#ffffff"
                font.pixelSize: 13
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Rectangle {
            anchors.horizontalCenter: crosshair.horizontalCenter
            anchors.top: crosshair.bottom
            anchors.topMargin: 18
            width: 210
            height: 28
            z: 20
            radius: 14
            color: "transparent"
            border.color: Number(root.tlm.solver_status) === 0 ? "#65dca0" : "#e06b7e"
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.glassButtonHover }
                GradientStop { position: 1.0; color: "#8510202c" }
            }

            Text {
                anchors.centerIn: parent
                width: 196
                text: "RK45  " + root.solverName(Number(root.tlm.solver_status))
                color: Number(root.tlm.solver_status) === 0 ? "#7ff0b5" : "#ff8295"
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        // 底部把“方向”和“步长”拆开：两个方向键始终固定，按下后明确高亮。
        Rectangle {
            anchors.fill: trimPanel
            anchors.leftMargin: 2
            anchors.topMargin: 5
            z: 19
            radius: Theme.radiusPanel
            color: Theme.shadow
        }

        Rectangle {
            id: trimPanel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: Math.min(820, parent.width - 40)
            height: 158
            z: 20
            radius: Theme.radiusPanel
            color: "transparent"
            border.color: Theme.border
            border.width: 1

            GlassLayer {}

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: 210
                height: 2
                radius: 1
                color: Theme.warning
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.panelPadding
                spacing: 16

                ColumnLayout {
                    Layout.preferredWidth: 186
                    Layout.fillHeight: true
                    spacing: 1

                    RowLayout {
                        spacing: 8
                        Image { source: "qrc:/images/adjustments-horizontal.svg"; sourceSize: Qt.size(18, 18); Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
                        Text { text: "PITCH TRIM · 回传真值"; color: Theme.textSecondary; font.pixelSize: 10; font.bold: true }
                    }

                    Text {
                        text: root.fmt(root.tlm.pitch_trim_deg, 2, "°")
                        color: root.tlm.trim_at_limit ? Theme.danger : Theme.textPrimary
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 34
                        font.bold: true
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.tlm.trim_at_limit ? "已到视觉限幅"
                              : (root.tlm.trim_active ? "TRIM ACTIVE" : "TRIM STANDBY")
                        color: root.tlm.trim_at_limit ? Theme.danger : Theme.success
                        font.pixelSize: 10
                        font.bold: true
                    }

                    Text {
                        visible: root.expectedMismatchVisible
                        text: "期望值与回传暂不一致"
                        color: Theme.danger
                        font.pixelSize: 9
                    }
                }

                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.borderSoft }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 7

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text { text: "步长"; color: Theme.textSecondary; font.pixelSize: 10; font.bold: true }
                        StepChip { stepValue: 1 }
                        StepChip { stepValue: 2 }
                        StepChip { stepValue: 4 }
                        Item { Layout.fillWidth: true }
                        Text {
                            id: trimFeedback
                            Layout.preferredWidth: 126
                            text: root.activeFeedbackStep > 0 ? "▲ 上调 " + root.activeFeedbackStep + " 步"
                                                              : "▼ 下调 " + Math.abs(root.activeFeedbackStep) + " 步"
                            color: root.feedbackAccepted ? Theme.success : Theme.danger
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                            opacity: 0

                            SequentialAnimation {
                                id: trimFeedbackAnimation
                                NumberAnimation { target: trimFeedback; property: "opacity"; from: 0; to: 1; duration: 70 }
                                PauseAnimation { duration: 300 }
                                NumberAnimation { target: trimFeedback; property: "opacity"; from: 1; to: 0; duration: 180 }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        RowLayout {
                            Layout.preferredWidth: 142
                            spacing: 9

                            TrimDirectionButton { direction: -1 }

                            ColumnLayout {
                                spacing: 0
                                Text { text: "下调"; color: Theme.textMuted; font.pixelSize: 9; font.bold: true }
                                Text {
                                    text: "−" + root.selectedTrimStep + " 步"
                                    color: Theme.textPrimary
                                    font.family: "DejaVu Sans Mono"
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: "−" + (root.selectedTrimStep * 0.05).toFixed(2) + "°"
                                    color: Theme.textSecondary
                                    font.family: "DejaVu Sans Mono"
                                    font.pixelSize: 9
                                }
                            }
                        }

                        RowLayout {
                            Layout.preferredWidth: 142
                            spacing: 9

                            TrimDirectionButton { direction: 1 }

                            ColumnLayout {
                                spacing: 0
                                Text { text: "上调"; color: Theme.textMuted; font.pixelSize: 9; font.bold: true }
                                Text {
                                    text: "+" + root.selectedTrimStep + " 步"
                                    color: Theme.textPrimary
                                    font.family: "DejaVu Sans Mono"
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: "+" + (root.selectedTrimStep * 0.05).toFixed(2) + "°"
                                    color: Theme.textSecondary
                                    font.family: "DejaVu Sans Mono"
                                    font.pixelSize: 9
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            id: resetButton
                            Layout.preferredWidth: 104
                            Layout.preferredHeight: 48
                            focusPolicy: Qt.NoFocus
                            enabled: root.clientBackend.connected
                            text: root.resetFeedbackActive ? "清零 ✓" : "ENTER 清零"
                            onClicked: root.resetTrim()

                            contentItem: Text {
                                text: resetButton.text
                                color: resetButton.enabled ? Theme.textPrimary : Theme.textMuted
                                font.pixelSize: 11; font.bold: true
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                radius: Theme.radiusSmall
                                color: "transparent"
                                border.color: root.resetFeedbackActive ? Theme.success : "#b86a78"
                                scale: resetButton.down || root.resetFeedbackActive ? 0.96 : 1.0
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0.0
                                        color: resetButton.down || root.resetFeedbackActive
                                               ? "#bd479d79" : "#a15e3544"
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: resetButton.down || root.resetFeedbackActive
                                               ? Theme.successDeep : "#80251620"
                                    }
                                }
                                Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutBack } }
                                Behavior on border.color { ColorAnimation { duration: Theme.motionNormal } }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.commandHint.length > 0 ? root.commandHint
                              : "↑/↓ 1步 · Shift 2步 · Ctrl 4步 · Enter 清零 · ESC 退出全屏"
                        color: root.commandHint.length > 0 ? Theme.textSecondary : Theme.textMuted
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // 登录层保持独立；点击进入后立即关闭，不等待 MQTT 连接结果。
    Rectangle {
        anchors.fill: parent
        z: 1000
        visible: !root.loggedIn
        color: "transparent"
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#f0071420" }
            GradientStop { position: 0.5; color: "#e90b1b29" }
            GradientStop { position: 1.0; color: "#f003080e" }
        }

        Rectangle {
            anchors.fill: loginCard
            anchors.leftMargin: 5
            anchors.topMargin: 8
            radius: 24
            color: Theme.shadow
        }

        Rectangle {
            id: loginCard
            anchors.centerIn: parent
            width: 440
            height: 310
            radius: 24
            color: "transparent"
            border.color: Theme.border
            border.width: 1

            GlassLayer { cornerRadius: 24 }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 14

                Text {
                    text: "HNU 英雄机器人副屏"
                    color: "#ffffff"
                    font.pixelSize: 27
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "CustomByteBlock  /  CustomControl"
                    color: "#8fa2b1"
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
                }

                GlassTextField {
                    id: hostInput
                    text: "192.168.12.1"
                    placeholderText: "MQTT Broker"
                }

                GlassTextField {
                    id: clientInput
                    text: "0x0101"
                    placeholderText: "MQTT Client ID"
                }

                Button {
                    id: loginButton
                    text: "确认身份并进入"
                    focusPolicy: Qt.NoFocus
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    onClicked: {
                        root.loggedIn = true
                        root.clientBackend.connectToServer(clientInput.text, hostInput.text, 3333)
                        scene.forceActiveFocus()
                    }

                    contentItem: Text {
                        text: loginButton.text
                        color: Theme.textPrimary
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 16
                        color: "transparent"
                        border.width: 1
                        border.color: loginButton.hovered ? "#d9dff7ff" : Theme.accent
                        scale: loginButton.down ? 0.98 : 1.0
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: loginButton.down ? "#d0448bb2"
                                      : (loginButton.hovered ? "#c14b94ba" : "#a93c7c9e")
                            }
                            GradientStop { position: 1.0; color: "#b21c4c68" }
                        }
                        Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: Theme.motionNormal } }
                    }
                }

                Text {
                    text: "连接失败不会阻塞界面，可通过顶部状态观察连接结果"
                    color: "#e6c46e"
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }

    // 无边框窗口拖动区；登录界面显示时也可以移动窗口。
    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: 126
        height: 54
        z: 1990

        DragHandler {
            target: null
            acceptedButtons: Qt.LeftButton
            onActiveChanged: {
                if (active && !root.fullScreenMode) {
                    root.startSystemMove()
                }
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onDoubleTapped: root.toggleFullScreen()
        }
    }

    // 右上角保留透明热区；鼠标进入时显示按钮，离开后自动淡出。
    Item {
        anchors.top: parent.top
        anchors.right: parent.right
        width: 132
        height: 54
        z: 2000

        HoverHandler {
            id: windowControlsHover
        }

        Rectangle {
            anchors.fill: parent
            color: "#8a071019"
            opacity: windowControlsHover.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        Row {
            anchors.top: parent.top
            anchors.topMargin: 9
            anchors.right: parent.right
            anchors.rightMargin: 9
            spacing: 4
            opacity: windowControlsHover.hovered ? 1 : 0
            enabled: windowControlsHover.hovered
            Behavior on opacity { NumberAnimation { duration: 140 } }

            WindowButton {
                iconSource: "qrc:/images/minimize.png"
                tipText: "最小化"
                onClicked: root.showMinimized()
            }

            WindowButton {
                iconSource: root.fullScreenMode
                            ? "qrc:/images/restore.png"
                            : "qrc:/images/fullscreen.png"
                tipText: root.fullScreenMode ? "还原窗口" : "全屏"
                onClicked: root.toggleFullScreen()
            }

            WindowButton {
                iconSource: "qrc:/images/close.png"
                tipText: "关闭"
                danger: true
                onClicked: root.close()
            }
        }
    }
}
