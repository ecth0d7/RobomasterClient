import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import QtQuick.Window 6.5

ApplicationWindow {
    id: root
    width: 1280
    height: 720
    visible: true
    color: "#090d13"
    title: "HNU 英雄机器人副屏"

    property var tlm: ({})
    property bool loggedIn: false
    property real expectedTrim: 0.0
    property bool hasExpectedTrim: false
    property bool stepReady: true
    property string commandHint: ""
    property int activeFeedbackStep: 0
    property bool feedbackAccepted: false

    function modeName(mode) {
        return ["IDLE", "AUTO AIM", "SMALL BUFF", "BIG BUFF", "DEPLOY"][mode] || "UNKNOWN"
    }
    function solverName(status) {
        return ["SUCCESS", "OUT OF RANGE", "NO SOLUTION", "NOT CONVERGED"][status] || "UNKNOWN"
    }
    function fmt(value, digits, suffix) {
        return value === undefined ? "--" : Number(value).toFixed(digits) + suffix
    }
    function sendStep(step) {
        activeFeedbackStep = step
        feedbackAccepted = heroClient.connected && stepReady && Number(tlm.mode) === 4
        feedbackReset.restart()
        trimFeedbackAnimation.restart()
        if (!heroClient.connected || !stepReady || Number(tlm.mode) !== 4) {
            commandHint = !heroClient.connected ? "MQTT 未连接，微调未发送"
                        : (Number(tlm.mode) !== 4 ? "非 DEPLOY 模式，微调未发送"
                                                   : "操作过快，请等待 0.2s")
            return
        }
        expectedTrim = Number(tlm.pitch_trim_deg || 0) + step * 0.05
        hasExpectedTrim = true
        heroClient.trimStep(step)
        stepReady = false
        stepCooldown.restart()
    }

    Timer { id: stepCooldown; interval: 200; onTriggered: root.stepReady = true }
    Timer { id: feedbackReset; interval: 560; onTriggered: root.activeFeedbackStep = 0 }

    // 全局快捷键：方向键为 1 步，Shift 为 2 步，Ctrl 为 4 步。
    Shortcut { sequence: "Up"; enabled: root.loggedIn; onActivated: root.sendStep(1) }
    Shortcut { sequence: "Down"; enabled: root.loggedIn; onActivated: root.sendStep(-1) }
    Shortcut { sequence: "Shift+Up"; enabled: root.loggedIn; onActivated: root.sendStep(2) }
    Shortcut { sequence: "Shift+Down"; enabled: root.loggedIn; onActivated: root.sendStep(-2) }
    Shortcut { sequence: "Ctrl+Up"; enabled: root.loggedIn; onActivated: root.sendStep(4) }
    Shortcut { sequence: "Ctrl+Down"; enabled: root.loggedIn; onActivated: root.sendStep(-4) }

    Connections {
        target: heroClient
        function onTelemetryUpdated(value) {
            root.tlm = value
            if (root.hasExpectedTrim && Math.abs(Number(value.pitch_trim_deg) - root.expectedTrim) < 0.026)
                root.hasExpectedTrim = false
        }
        function onFrameReady() { video.source = "image://heroVideo/latest?" + Date.now() }
        function onCommandSent(seq, command, parameter) {
            root.commandHint = "命令已发送  seq=" + seq + " cmd=" + command + " param=" + parameter
        }
        function onCommandRejected(reason) { root.commandHint = reason }
    }

    component StatusLamp: Rectangle {
        required property string label
        required property bool active
        Layout.fillWidth: true
        implicitHeight: 38
        radius: 6
        color: active ? "#193c2d" : "#251d24"
        border.color: active ? "#45e59a" : "#73505f"
        Row {
            anchors.centerIn: parent; spacing: 8
            Rectangle { width: 9; height: 9; radius: 5; color: active ? "#45e59a" : "#9c6277" }
            Text { text: label; color: "#eef5f8"; font.pixelSize: 12; font.bold: true }
        }
    }

    component MetricCard: Rectangle {
        required property string title
        required property string value
        Layout.fillWidth: true
        implicitHeight: 72
        radius: 8
        color: "#141d29"
        border.color: "#26394d"
        Column {
            anchors.centerIn: parent; spacing: 4
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: title; color: "#7890a8"; font.pixelSize: 11 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: value; color: "#f1f7fb"; font.pixelSize: 21; font.bold: true }
        }
    }

    component TrimButton: Button {
        id: trimButton
        required property int stepValue
        text: (stepValue > 0 ? "+" : "−") + Math.abs(stepValue)
        Layout.fillWidth: true
        enabled: heroClient.connected && root.stepReady
        onClicked: root.sendStep(stepValue)
        contentItem: Text {
            text: trimButton.text
            color: trimButton.enabled ? "white" : "#596673"
            font.bold: true; font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 6
            color: trimButton.down ? "#3e82c4"
                 : (root.activeFeedbackStep === trimButton.stepValue
                    ? (root.feedbackAccepted ? "#256f54" : "#743044") : "#1c2a39")
            border.color: trimButton.activeFocus ? "#74b9ff" : "#3b5268"
            scale: trimButton.down || root.activeFeedbackStep === trimButton.stepValue ? 0.96 : 1.0
            Behavior on scale { NumberAnimation { duration: 70 } }
            Behavior on color { ColorAnimation { duration: 100 } }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#090d13"

        Rectangle {
            id: header
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 64
            color: "#101823"
            border.color: "#26394d"
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 22; anchors.rightMargin: 22
                Text { text: "HNU HERO · DEPLOY CONTROL"; color: "white"; font.pixelSize: 20; font.bold: true }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: statusRow.implicitWidth + 24; implicitHeight: 32; radius: 16
                    color: "#0b1119"; border.color: heroClient.connected ? "#45e59a" : "#ff5d73"
                    Row { id: statusRow; anchors.centerIn: parent; spacing: 8
                        Rectangle { width: 9; height: 9; radius: 5; color: heroClient.connected ? "#45e59a" : "#ff5d73" }
                        Text { text: "MQTT " + heroClient.statusText; color: "white"; font.bold: true }
                    }
                }
                Rectangle {
                    implicitWidth: tlmRow.implicitWidth + 24; implicitHeight: 32; radius: 16
                    color: "#0b1119"; border.color: heroClient.telemetryOnline ? "#45e59a" : "#ff5d73"
                    Row { id: tlmRow; anchors.centerIn: parent; spacing: 8
                        Rectangle { width: 9; height: 9; radius: 5; color: heroClient.telemetryOnline ? "#45e59a" : "#ff5d73" }
                        Text { text: heroClient.telemetryOnline ? "视觉遥测在线" : "视觉遥测超时"; color: "white"; font.bold: true }
                    }
                }
            }
        }

        GridLayout {
            anchors.top: header.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 16
            columns: 3
            columnSpacing: 14; rowSpacing: 14

            Rectangle {
                Layout.rowSpan: 2; Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredWidth: 700
                radius: 10; color: "#05080c"; border.color: "#26394d"; clip: true
                Image { id: video; anchors.fill: parent; fillMode: Image.PreserveAspectFit; cache: false }
                Text { anchors.centerIn: parent; visible: video.status !== Image.Ready; text: "等待 HNU-VID H.264 视频"; color: "#60758a"; font.pixelSize: 18 }
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 12
                    width: modeText.implicitWidth + 20; height: 32; radius: 5
                    color: Number(tlm.mode) === 4 ? "#cc5b3510" : "#cc242a31"
                    Text { id: modeText; anchors.centerIn: parent; text: modeName(Number(tlm.mode)); color: Number(tlm.mode) === 4 ? "#ffbd69" : "#c5d0da"; font.bold: true }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12
                    width: 130; height: 40; radius: 6
                    color: tlm.fire_allowed ? "#d11d6948" : "#d13c1d2a"
                    border.color: tlm.fire_allowed ? "#58f0a8" : "#ff5d73"
                    Text { anchors.centerIn: parent; text: tlm.fire_allowed ? "视觉请求开火" : "禁止开火"; color: "white"; font.bold: true }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 270
                radius: 10; color: "#101823"; border.color: "#26394d"
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    Text { text: "弹道遥测"; color: "white"; font.pixelSize: 16; font.bold: true }
                    GridLayout { columns: 2; Layout.fillWidth: true; columnSpacing: 8; rowSpacing: 8
                        MetricCard { title: "水平距离"; value: (tlm.radar_fresh || tlm.radar_hold) ? fmt(tlm.distance_m, 2, " m") : "无雷达" }
                        MetricCard { title: "高度差"; value: (tlm.radar_fresh || tlm.radar_hold) ? fmt(tlm.height_m, 2, " m") : "无雷达" }
                        MetricCard { title: "实测弹速"; value: fmt(tlm.bullet_speed_rx, 2, " m/s") }
                        MetricCard { title: "RK45 弹速"; value: fmt(tlm.solver_v0, 2, " m/s") }
                        MetricCard { title: "飞行时间"; value: fmt(tlm.tof_s, 3, " s") }
                        MetricCard { title: "云台 Pitch"; value: fmt(tlm.pitch_meas_deg, 2, "°") }
                        MetricCard { title: "Yaw 误差"; value: fmt(tlm.yaw_err_deg, 2, "°") }
                        MetricCard { title: "Pitch 误差"; value: fmt(tlm.pitch_err_deg, 2, "°") }
                    }
                    Text { text: "RK45: " + solverName(Number(tlm.solver_status)); color: Number(tlm.solver_status) === 0 ? "#45e59a" : "#ff7d8e"; font.bold: true }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 270
                radius: 10; color: "#101823"; border.color: "#26394d"
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    Text { text: "视觉安全链"; color: "white"; font.pixelSize: 16; font.bold: true }
                    StatusLamp { label: "核心已检测"; active: !!tlm.core_ok }
                    StatusLamp { label: tlm.radar_hold ? "雷达短时保持" : "雷达数据新鲜"; active: !!(tlm.radar_fresh || tlm.radar_hold) }
                    StatusLamp { label: "RK45 解算成功"; active: !!tlm.deploy_solved }
                    StatusLamp { label: "Yaw 已收敛"; active: !!tlm.yaw_converged }
                    StatusLamp { label: "FULL ADJUST"; active: !!tlm.phase_full_adjust }
                    StatusLamp { label: "Force Deploy"; active: !!tlm.force_deploy }
                    Text { text: "最终发射仍受电控热量、弹速及机构安全否决"; color: "#f5c451"; wrapMode: Text.WordWrap; Layout.fillWidth: true; font.pixelSize: 11 }
                }
            }

            Rectangle {
                Layout.columnSpan: 2; Layout.fillWidth: true; Layout.preferredHeight: 250
                radius: 10; color: "#101823"; border.color: "#26394d"
                RowLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 18
                    ColumnLayout {
                        Layout.fillHeight: true; Layout.preferredWidth: 210
                        Text { text: "Pitch Trim（回传真值）"; color: "#8aa0b5"; font.pixelSize: 12 }
                        Text { text: fmt(tlm.pitch_trim_deg, 2, "°"); color: tlm.trim_at_limit ? "#ff5d73" : "#ffffff"; font.pixelSize: 38; font.bold: true }
                        Text { text: tlm.trim_at_limit ? "已到视觉限幅" : (tlm.trim_active ? "Trim 生效中" : "Trim 未启用"); color: tlm.trim_at_limit ? "#ff5d73" : "#45e59a" }
                        Text { visible: hasExpectedTrim; text: "期望值与回传暂不一致"; color: "#ff5d73"; font.bold: true }
                        Text {
                            id: trimFeedback
                            visible: activeFeedbackStep !== 0
                            text: activeFeedbackStep > 0 ? "▲ 上调 " + activeFeedbackStep + " 步"
                                  : "▼ 下调 " + Math.abs(activeFeedbackStep) + " 步"
                            color: feedbackAccepted ? "#45e59a" : "#ff5d73"
                            font.pixelSize: 17; font.bold: true; opacity: 0
                            SequentialAnimation {
                                id: trimFeedbackAnimation
                                NumberAnimation { target: trimFeedback; property: "opacity"; from: 0; to: 1; duration: 70 }
                                PauseAnimation { duration: 300 }
                                NumberAnimation { target: trimFeedback; property: "opacity"; from: 1; to: 0; duration: 180 }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 10
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            TrimButton { stepValue: -4 }
                            TrimButton { stepValue: -2 }
                            TrimButton { stepValue: -1 }
                            TrimButton { stepValue: 1 }
                            TrimButton { stepValue: 2 }
                            TrimButton { stepValue: 4 }
                        }
                        Button {
                            text: "清零 Pitch Trim"; Layout.fillWidth: true; Layout.preferredHeight: 46
                            enabled: heroClient.connected
                            onClicked: { hasExpectedTrim = true; expectedTrim = 0; heroClient.trimReset() }
                        }
                        Button {
                            text: heroClient.heartbeatEnabled ? "暂停 Heartbeat（仅联调）" : "恢复 Heartbeat"
                            Layout.fillWidth: true
                            enabled: heroClient.connected
                            onClicked: {
                                heroClient.setHeartbeatEnabled(!heroClient.heartbeatEnabled)
                                commandHint = heroClient.heartbeatEnabled
                                            ? "Heartbeat 已恢复，将立即发送并继续 1Hz"
                                            : "Heartbeat 已暂停；保持 MQTT 连接，等待 2s 超时清零"
                            }
                            background: Rectangle {
                                radius: 6
                                color: heroClient.heartbeatEnabled ? "#3a2830" : "#24543f"
                                border.color: heroClient.heartbeatEnabled ? "#ff7d8e" : "#45e59a"
                            }
                        }
                        Text { text: commandHint; color: "#8fa4b8"; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: "↑/↓: 1步 · Shift+↑/↓: 2步 · Ctrl+↑/↓: 4步"; color: "#8fa4b8"; font.pixelSize: 11 }
                        Text { text: "每步 0.05° · Step 最小间隔 0.2s · Heartbeat 1Hz 自动发送"; color: "#60758a"; font.pixelSize: 11 }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent; z: 10000; visible: !loggedIn; color: "#ed090d13"
        ColumnLayout {
            anchors.centerIn: parent; width: 430; spacing: 16
            Text { text: "HNU 英雄机器人副屏"; color: "white"; font.pixelSize: 30; font.bold: true; Layout.alignment: Qt.AlignHCenter }
            Text { text: "仅接入 CustomByteBlock / CustomControl"; color: "#7890a8"; Layout.alignment: Qt.AlignHCenter }
            TextField { id: hostInput; text: "192.168.12.1"; placeholderText: "MQTT Broker"; Layout.fillWidth: true }
            TextField { id: clientInput; text: "0x0101"; placeholderText: "MQTT Client ID"; Layout.fillWidth: true }
            Button {
                text: "确认身份并进入"; Layout.fillWidth: true; Layout.preferredHeight: 48
                onClicked: {
                    loggedIn = true
                    heroClient.connectToServer(clientInput.text, hostInput.text, 3333)
                }
            }
            Text { text: "连接失败不会阻塞界面，可通过顶部状态观察连接结果"; color: "#f5c451"; Layout.alignment: Qt.AlignHCenter }
        }
    }
}
