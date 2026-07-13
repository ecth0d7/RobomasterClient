pragma ComponentBehavior: Bound

import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import QtQuick.Window 6.5

ApplicationWindow {
    id: root
    width: 1280
    height: 720
    minimumWidth: 960
    minimumHeight: 600
    visible: true
    color: "#05080b"
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

    // 固定宽度的数据行，数值变化时不会推动标签或面板位置。
    component DataRow: Item {
        id: dataRow
        required property string label
        required property string value
        property color valueColor: "#f2f7fa"
        width: 224
        height: 27

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 96
            text: dataRow.label
            color: "#9badbc"
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
        width: 224
        height: 30
        radius: 3
        color: stateRow.active ? "#9920523c" : "#99291922"
        border.width: 1
        border.color: stateRow.active ? "#7ce9ae" : "#8b5260"

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
            color: "#eef5f8"
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
        }
    }

    component TrimButton: Button {
        id: trimButton
        required property int stepValue
        width: 58
        height: 40
        focusPolicy: Qt.NoFocus
        enabled: root.clientBackend.connected && root.stepReady
        text: (stepValue > 0 ? "+" : "−") + Math.abs(stepValue)
        onClicked: root.sendStep(stepValue)

        contentItem: Text {
            text: trimButton.text
            color: trimButton.enabled ? "#ffffff" : "#68747e"
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 15
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 4
            color: trimButton.down ? "#397fb9"
                 : (root.activeFeedbackStep === trimButton.stepValue
                    ? (root.feedbackAccepted ? "#297052" : "#743044")
                    : "#b3111a23")
            border.width: 1
            border.color: trimButton.activeFocus ? "#85c8ff" : "#667b8c"
            scale: trimButton.down || root.activeFeedbackStep === trimButton.stepValue ? 0.95 : 1.0
            Behavior on scale { NumberAnimation { duration: 70 } }
            Behavior on color { ColorAnimation { duration: 100 } }
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
            radius: 5
            color: windowButton.down
                   ? (windowButton.danger ? "#d9364d" : "#435562")
                   : (windowButton.hovered
                      ? (windowButton.danger ? "#b92d42" : "#344550")
                      : "#8f101820")
            border.width: 1
            border.color: windowButton.hovered
                          ? (windowButton.danger ? "#ff7a8d" : "#8298a7")
                          : "#4f6574"
            Behavior on color { ColorAnimation { duration: 100 } }
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
            color: "#8f071019"
            border.color: "#6f8292"
            border.width: 1

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
                radius: 3
                color: Number(root.tlm.mode) === 4 ? "#b34e3515" : "#b3232930"
                border.color: Number(root.tlm.mode) === 4 ? "#e9a94f" : "#768692"

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
                    radius: 3
                    color: "#a30a1118"
                    border.color: root.clientBackend.connected ? "#55ef9f" : "#ef657a"

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
                    radius: 3
                    color: "#a30a1118"
                    border.color: root.clientBackend.telemetryOnline ? "#55ef9f" : "#ef657a"

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
                color: "#6a9fb9"
                opacity: 0.55
            }
        }

        // 左上先展示瞄准所需的目标与解算结果，符合从目标到误差的阅读顺序。
        Rectangle {
            id: targetSolutionPanel
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.top: topBar.bottom
            anchors.topMargin: 18
            width: 252
            height: 190
            z: 10
            radius: 5
            color: "#a5081017"
            border.color: "#738999"
            border.width: 1

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                width: 58
                height: 2
                color: "#63b8dc"
            }

            Text {
                x: 14
                y: 12
                width: 224
                height: 22
                text: "目标与解算"
                color: "#ffffff"
                font.pixelSize: 15
                font.bold: true
            }

            Column {
                x: 14
                y: 42
                spacing: 1

                DataRow { label: "水平距离"; value: (root.tlm.radar_fresh || root.tlm.radar_hold) ? root.fmt(root.tlm.distance_m, 2, " m") : "无雷达" }
                DataRow { label: "高度差"; value: (root.tlm.radar_fresh || root.tlm.radar_hold) ? root.fmt(root.tlm.height_m, 2, " m") : "无雷达" }
                DataRow { label: "飞行时间"; value: root.fmt(root.tlm.tof_s, 3, " s") }
                DataRow { label: "Yaw 误差"; value: root.fmt(root.tlm.yaw_err_deg, 2, "°") }
                DataRow { label: "Pitch 误差"; value: root.fmt(root.tlm.pitch_err_deg, 2, "°") }
            }
        }

        // 武器与云台参数放在目标解算下方，作为二级确认信息。
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.top: targetSolutionPanel.bottom
            anchors.topMargin: 10
            width: 252
            height: 128
            z: 10
            radius: 5
            color: "#a5081017"
            border.color: "#738999"
            border.width: 1

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                width: 58
                height: 2
                color: "#d6ad62"
            }

            Text {
                x: 14
                y: 12
                width: 224
                height: 22
                text: "武器与云台"
                color: "#ffffff"
                font.pixelSize: 15
                font.bold: true
            }

            Column {
                x: 14
                y: 42
                spacing: 1

                DataRow { label: "实测弹速"; value: root.fmt(root.tlm.bullet_speed_rx, 2, " m/s") }
                DataRow { label: "RK45 弹速"; value: root.fmt(root.tlm.solver_v0, 2, " m/s") }
                DataRow { label: "云台 Pitch"; value: root.fmt(root.tlm.pitch_meas_deg, 2, "°") }
            }
        }

        // 右侧按视觉决策链顺序展示，操作手从上到下即可定位阻断环节。
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.top: topBar.bottom
            anchors.topMargin: 18
            width: 252
            height: 260
            z: 10
            radius: 5
            color: "#a5081017"
            border.color: "#738999"
            border.width: 1

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                width: 58
                height: 2
                color: "#62d49a"
            }

            Text {
                x: 14
                y: 12
                width: 224
                height: 22
                text: "发射安全链"
                color: "#ffffff"
                font.pixelSize: 15
                font.bold: true
            }

            Column {
                x: 14
                y: 42
                spacing: 6

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
            radius: 3
            color: root.tlm.fire_allowed ? "#bd16573f" : "#bd431d29"
            border.color: root.tlm.fire_allowed ? "#69f0ae" : "#ff6b81"

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
            radius: 3
            color: "#9e071019"
            border.color: Number(root.tlm.solver_status) === 0 ? "#65dca0" : "#e06b7e"

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

        // 底部控制区悬浮在视频上方，宽高固定，避免回传值变化导致抖动。
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: 760
            height: 136
            z: 20
            radius: 6
            color: "#b8071018"
            border.color: "#8295a3"
            border.width: 1

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: 180
                height: 2
                color: "#d6ad62"
            }

            Item {
                x: 18
                y: 14
                width: 196
                height: 108

                Text {
                    x: 0
                    y: 0
                    width: 196
                    height: 18
                    text: "PITCH TRIM · 回传真值"
                    color: "#a9bac7"
                    font.pixelSize: 11
                    font.bold: true
                }

                Text {
                    x: 0
                    y: 22
                    width: 196
                    height: 46
                    text: root.fmt(root.tlm.pitch_trim_deg, 2, "°")
                    color: root.tlm.trim_at_limit ? "#ff7187" : "#ffffff"
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 34
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                Text {
                    x: 0
                    y: 74
                    width: 196
                    height: 18
                    text: root.tlm.trim_at_limit ? "已到视觉限幅"
                          : (root.tlm.trim_active ? "TRIM ACTIVE" : "TRIM STANDBY")
                    color: root.tlm.trim_at_limit ? "#ff7187" : "#65e3a5"
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    x: 0
                    y: 92
                    width: 196
                    height: 16
                    visible: root.expectedMismatchVisible
                    text: "期望值与回传暂不一致"
                    color: "#ff7187"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                x: 224
                y: 14
                width: 1
                height: 108
                color: "#637786"
            }

            Row {
                x: 246
                y: 14
                spacing: 8

                TrimButton { stepValue: -4 }
                TrimButton { stepValue: -2 }
                TrimButton { stepValue: -1 }
                TrimButton { stepValue: 1 }
                TrimButton { stepValue: 2 }
                TrimButton { stepValue: 4 }
            }

            Button {
                id: resetButton
                x: 642
                y: 14
                width: 100
                height: 40
                focusPolicy: Qt.NoFocus
                enabled: root.clientBackend.connected
                text: root.resetFeedbackActive ? "清零 ✓" : "ENTER 清零"
                onClicked: root.resetTrim()

                contentItem: Text {
                    text: resetButton.text
                    color: resetButton.enabled ? "#ffffff" : "#68747e"
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 4
                    color: resetButton.down || root.resetFeedbackActive ? "#276e52" : "#ad321d28"
                    border.color: root.resetFeedbackActive ? "#70efb0" : "#b86a78"
                    scale: resetButton.down || root.resetFeedbackActive ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            Text {
                id: trimFeedback
                x: 246
                y: 62
                width: 210
                height: 22
                visible: root.activeFeedbackStep !== 0
                text: root.activeFeedbackStep > 0 ? "▲ 上调 " + root.activeFeedbackStep + " 步"
                                                  : "▼ 下调 " + Math.abs(root.activeFeedbackStep) + " 步"
                color: root.feedbackAccepted ? "#65e3a5" : "#ff7187"
                font.pixelSize: 14
                font.bold: true
                opacity: 0

                SequentialAnimation {
                    id: trimFeedbackAnimation
                    NumberAnimation { target: trimFeedback; property: "opacity"; from: 0; to: 1; duration: 70 }
                    PauseAnimation { duration: 300 }
                    NumberAnimation { target: trimFeedback; property: "opacity"; from: 1; to: 0; duration: 180 }
                }
            }

            Text {
                x: 246
                y: 88
                width: 496
                height: 18
                text: root.commandHint
                color: "#bac7d0"
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            Text {
                x: 246
                y: 108
                width: 496
                height: 16
                text: "↑/↓ 1步 · Shift 2步 · Ctrl 4步 · Enter 清零 · ESC 退出全屏"
                color: "#7f909d"
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    // 登录层保持独立；点击进入后立即关闭，不等待 MQTT 连接结果。
    Rectangle {
        anchors.fill: parent
        z: 1000
        visible: !root.loggedIn
        color: "#ed05090d"

        Rectangle {
            anchors.centerIn: parent
            width: 440
            height: 310
            radius: 8
            color: "#f00d1720"
            border.color: "#708493"

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

                TextField {
                    id: hostInput
                    text: "192.168.12.1"
                    placeholderText: "MQTT Broker"
                    Layout.fillWidth: true
                }

                TextField {
                    id: clientInput
                    text: "0x0101"
                    placeholderText: "MQTT Client ID"
                    Layout.fillWidth: true
                }

                Button {
                    text: "确认身份并进入"
                    focusPolicy: Qt.NoFocus
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    onClicked: {
                        root.loggedIn = true
                        root.clientBackend.connectToServer(clientInput.text, hostInput.text, 3333)
                        scene.forceActiveFocus()
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
