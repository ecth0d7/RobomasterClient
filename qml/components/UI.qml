import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2

// RoboMaster 2026 自定义客户端 - UI绘制层
Item {
    id: root
    focus: false
    // 接收外部传入的核心数据、函数和主窗口引用
    property var dataStore: {}
    property var getStageText: function() {}
    property var mainWindow: null  // 新增：主窗口引用
    property var globalInputFilter: null // 接收输入过滤器实例

    // ==============================================
    // 窗口控制逻辑
    // ==============================================
    function toggleMaximize() {
        if (!dataStore.isMaximized) {
            dataStore.normalX = mainWindow.x; 
            dataStore.normalY = mainWindow.y;
            dataStore.normalWidth = mainWindow.width; 
            dataStore.normalHeight = mainWindow.height;
            mainWindow.showFullScreen();
            dataStore.isMaximized = true;
        } else {
            mainWindow.showNormal();
            mainWindow.x = dataStore.normalX; 
            mainWindow.y = dataStore.normalY;
            mainWindow.width = dataStore.normalWidth; 
            mainWindow.height = dataStore.normalHeight;
            dataStore.isMaximized = false;
        }
    }

    // // 窗口拖动区域
    // MouseArea {
    //     id: dragMouseArea
    //     anchors.fill: parent
    //     anchors.bottomMargin: -40
    //     anchors.rightMargin: -120
    //     anchors.topMargin: -110
    //     hoverEnabled: true
    //     property point clickPos: Qt.point(0, 0)

    //     onClicked: function(mouse) {  // 声明参数
    //         console.log(mouse.x, mouse.y);
    //     }
    //     onPositionChanged: {
    //         if (!dataStore.isMaximized && mainWindow) {
    //             mainWindow.x += mouse.x - clickPos.x;
    //             mainWindow.y += mouse.y - clickPos.y;
    //         }
    //     }
    // }

    // 窗口失焦隐藏按钮
    Connections {
        target: mainWindow
        function onActiveChanged() {
            if (mainWindow && !mainWindow.active) windowBtnBar.opacity = 0
        }
    }

    // ==============================================
    // 根容器
    // ==============================================
    Item {
        id: contentRoot
        anchors.fill: parent
        z: 1
        focus: false

        // 1. UDP视频展示区域
        UdpVideoDisplay {
            id: udpVideo
            anchors.fill: parent  
            z: 1  
        }

        // 2. 比赛暂停遮罩
        Item {
            anchors.fill: parent
            z: 999
            visible: dataStore.gameStatus_is_paused || false

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.7
            }

            Text {
                anchors.centerIn: parent
                text: "比赛暂停"
                font.pixelSize: 48
                font.bold: true
                color: "#ff3333"
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 1; duration: 500 }
                    NumberAnimation { to: 0.5; duration: 500 }
                }
            }
        }

        // 3. 比分栏区域
        Rectangle {
            id: scoreBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 110
            color: "transparent"
            z: 100

            // 中间比分/回合/倒计时显示
            Item {
                id: middleScoreBlock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                width: 120
                height: 60

                Rectangle {
                    anchors.fill: parent
                    color: "#222222"
                    radius: 10
                    border.color: "#555555"
                    border.width: 1
                    opacity: 0.8
                }

                Text {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Round: " + (dataStore.gameStatus_current_round > 0 ? dataStore.gameStatus_current_round : "0")
                    font.pixelSize: 9
                    color: "#aaaaaa"
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: dataStore.gameStatus_red_score || 0; font.pixelSize: 18; font.bold: true; color: "#ff2222" }
                    Text { text: "-"; font.pixelSize: 14; color: "#ffffff" }
                    Text { text: dataStore.gameStatus_blue_score || 0; font.pixelSize: 18; font.bold: true; color: "#2288ff" }
                }

                // 比赛倒计时
                Text {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (dataStore.gameStatus_stage_countdown_sec || 0) + "s"
                    font.pixelSize: 9
                    color: (dataStore.gameStatus_stage_countdown_sec || 0) <= 10 ? "#ff3333" : "#ffff00"
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: (dataStore.gameStatus_stage_countdown_sec || 0) <= 10 && (dataStore.gameStatus_current_stage || 0) === 4
                        NumberAnimation { to: 1; duration: 500 }
                        NumberAnimation { to: 0.5; duration: 500 }
                    }
                }
            }

            // 红方胜利点模块
            Item {
                id: redVictoryPointBar
                anchors.right: middleScoreBlock.left
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.rightMargin: 20
                width: 300
                height: 60

                // 胜利点进度条
                Rectangle {
                    id: redProgressBar
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 20
                    color: "#550000"
                    radius: 6
                    opacity: 0.6
                    Rectangle {
                        anchors.fill: parent
                        color: "#ff2222"
                        radius: 6
                        width: Math.max(0, parent.width * ((dataStore.gameStatus_red_score || 0) / 200))
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: (dataStore.gameStatus_red_score || 0) <= 0
                            NumberAnimation { to: 1; duration: 500 }
                            NumberAnimation { to: 0.3; duration: 500 }
                        }
                    }
                }

                // 校徽（R标）
                Image {
                    id: redLogo
                    anchors.right: redProgressBar.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 10
                    width: 30
                    height: 30
                    source: "data:image/svg+xml;utf8,<svg width='30' height='30'><circle cx='15' cy='15' r='12' fill='#ff2222' stroke='#ffffff' stroke-width='1'/><text x='15' y='20' text-anchor='middle' font-size='16' font-weight='bold' fill='white'>R</text></svg>"
                }

                // 校名+胜利点数
                Column {
                    anchors.right: redLogo.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 20
                    spacing: 2
                    Text { 
                        text: "红方战队"; 
                        font.pixelSize: 12; 
                        color: "#ffffff";
                        horizontalAlignment: Text.AlignRight
                    }
                    Text { 
                        text: (dataStore.gameStatus_red_score || 0) + " 胜利点"; 
                        font.pixelSize: 14; 
                        font.bold: true; 
                        color: (dataStore.gameStatus_red_score || 0) <= 0 ? "#ff3333" : "#ffffff";
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // 蓝方胜利点模块
            Item {
                id: blueVictoryPointBar
                anchors.left: middleScoreBlock.right
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.leftMargin: 20
                width: redVictoryPointBar.width
                height: redVictoryPointBar.height

                // 胜利点进度条
                Rectangle {
                    id: blueProgressBar
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 20
                    color: "#000055"
                    radius: 6
                    opacity: 0.6
                    Rectangle {
                        anchors.fill: parent
                        color: "#2288ff"
                        radius: 6
                        width: Math.max(0, parent.width * ((dataStore.gameStatus_blue_score || 0) / 200))
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: (dataStore.gameStatus_blue_score || 0) <= 0
                            NumberAnimation { to: 1; duration: 500 }
                            NumberAnimation { to: 0.3; duration: 500 }
                        }
                    }
                }

                // 校徽（B标）
                Image {
                    id: blueLogo
                    anchors.left: blueProgressBar.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    width: 30
                    height: 30
                    source: "data:image/svg+xml;utf8,<svg width='30' height='30'><circle cx='15' cy='15' r='12' fill='#2288ff' stroke='#ffffff' stroke-width='1'/><text x='15' y='20' text-anchor='middle' font-size='16' font-weight='bold' fill='white'>B</text></svg>"
                }

                // 校名+胜利点数
                Column {
                    anchors.left: blueLogo.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 20
                    spacing: 2
                    Text { 
                        text: "蓝方战队"; 
                        font.pixelSize: 12; 
                        color: "#ffffff";
                        horizontalAlignment: Text.AlignLeft
                    }
                    Text { 
                        text: (dataStore.gameStatus_blue_score || 0) + " 胜利点"; 
                        font.pixelSize: 14; 
                        font.bold: true; 
                        color: (dataStore.gameStatus_blue_score || 0) <= 0 ? "#2288ff" : "#ffffff";
                        horizontalAlignment: Text.AlignLeft
                    }
                }
            }

            // 红方机器人血量条
            Row {
                anchors.top: redVictoryPointBar.bottom
                anchors.left: redVictoryPointBar.left
                anchors.margins: 3
                spacing: 5
                Repeater {
                    model: 6  // 红方只有6个机器人
                    Rectangle {
                        width: 25
                        height: 10
                        border.color: "#ff2222"
                        border.width: 1
                        radius: 3
                        opacity: 0.8
                        Rectangle {
                            anchors.fill: parent
                            radius: 2
                            width: Math.max(0, parent.width * ((dataStore.globalUnit_robot_health[model.index] || 0) / 1000))
                            color: {
                                let ratio = (dataStore.globalUnit_robot_health[model.index] || 0) / 1000;
                                return ratio > 0.5 ? "#22ff22" : (ratio > 0.2 ? "#ffff22" : "#ff2222");
                            }
                        }
                        Text { 
                            anchors.centerIn: parent; 
                            text: {
                                // 显示对应的机器人类型
                                if (model.index === 0) return "英";
                                if (model.index === 1) return "工";
                                if (model.index === 2) return "步1";
                                if (model.index === 3) return "步2";
                                if (model.index === 4) return "空";
                                if (model.index === 5) return "哨";
                                return model.index + 1;
                            }
                            font.pixelSize: 7; 
                            color: "white" 
                        }
                    }
                }
            }

            // 蓝方机器人血量条
            Row {
                anchors.top: blueVictoryPointBar.bottom
                anchors.right: blueVictoryPointBar.right
                anchors.margins: 3
                spacing: 5
                Repeater {
                    model: 6  // 蓝方也有6个机器人
                    Rectangle {
                        width: 25
                        height: 10
                        border.color: "#2288ff"
                        border.width: 1
                        radius: 3
                        opacity: 0.8
                        Rectangle {
                            anchors.fill: parent
                            radius: 2
                            // 蓝方机器人在数组中的索引是 6 + model.index
                            width: Math.max(0, parent.width * ((dataStore.globalUnit_robot_health[6 + model.index] || 0) / 1000))
                            color: {
                                let ratio = (dataStore.globalUnit_robot_health[6 + model.index] || 0) / 1000;
                                return ratio > 0.5 ? "#22ff22" : (ratio > 0.2 ? "#ffff22" : "#ff2222");
                            }
                        }
                        Text { 
                            anchors.centerIn: parent; 
                            text: {
                                // 显示对应的机器人类型
                                if (model.index === 0) return "英";
                                if (model.index === 1) return "工";
                                if (model.index === 2) return "步1";
                                if (model.index === 3) return "步2";
                                if (model.index === 4) return "空";
                                if (model.index === 5) return "哨";
                                return model.index + 1;
                            }
                            font.pixelSize: 7; 
                            color: "white" 
                        }
                    }
                }
            }
        }

        // 4. 右侧参数显示区域
        Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 20
            spacing: 5
            z: 11

            Text { text: "射击速度"; font.pixelSize: 12; color: "white" }
            Text { text: (dataStore.robotDynamic_last_projectile_fire_rate || 0).toFixed(2); font.pixelSize: 14; font.bold: true; color: "white" }
            Text { text: "允许弹量"; font.pixelSize: 12; color: "white" }
            Text { 
                text: root.getCurrentRobotBullets ? root.getCurrentRobotBullets() : 0
                font.pixelSize: 14; 
                font.bold: true; 
                color: "#22ff22" 
            }
            
            Text { text: "-------------------------"; font.pixelSize: 12; color: "#888888" }
        }

        // 5. 经济显示模块
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 200
            anchors.leftMargin: 20
            width: 200
            height: 60
            color: "#00000080"
            border.color: "#66666680"
            border.width: 1
            z: 100
            visible: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                // 红方经济
                Column {
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    spacing: 2
                    Text { 
                        text: "红方经济"; 
                        font.pixelSize: 10; 
                        color: "#ff2222"; 
                        horizontalAlignment: Text.AlignLeft 
                    }
                    Text { 
                        text: dataStore.globalLogistics_red_economy || 0;
                        font.pixelSize: 14; 
                        font.bold: true; 
                        color: "#ffffff";
                        horizontalAlignment: Text.AlignLeft 
                    }
                }

                // 占位项
                Item {
                    Layout.fillWidth: true
                }

                // 蓝方经济
                Column {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    spacing: 2
                    Text { 
                        text: "蓝方经济"; 
                        font.pixelSize: 10; 
                        color: "#2288ff"; 
                        horizontalAlignment: Text.AlignRight 
                    }
                    Text { 
                        text: dataStore.globalLogistics_blue_economy || 0;
                        font.pixelSize: 14; 
                        font.bold: true; 
                        color: "#ffffff";
                        horizontalAlignment: Text.AlignRight 
                    }
                }
            }
        }

        // 6. 左侧信息面板
        Column {
            anchors.left: parent.left
            anchors.top: scoreBar.bottom
            anchors.margins: 20
            spacing: 10
            z: 11

            // 系统面板
            Rectangle {
                width: 200
                height: 80
                color: "#00000080"
                border.color: "#66666680"
                border.width: 1

                Text { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 5; text: "系统"; font.pixelSize: 12; color: "#aaaaaa" }

               
            }

            // 机器人面板
            Rectangle {
                width: 200
                height: 80
                color: "#00000080"
                border.color: "#66666680"
                border.width: 1

                Text {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 5
                    text: "当前机器人：" + ((dataStore.currentRobotIndex || 0) + 1) + "号"
                    font.pixelSize: 12
                    color: "#aaaaaa"
                }

                
            }
        }
               // 7.5 机器人模块状态显示
        Item {
            id: moduleStatusDisplay
            anchors.left: parent.left
            anchors.bottom: parent.bottom  // 左下角状态条下方
            anchors.topMargin: 10
            anchors.leftMargin: 20
            width: 350  // 稍微减小宽度
            height: 130  // 减小高度
            z: 11

            // 辅助函数：获取模块图标路径
            function getModuleIcon(status) {
                if (status === 1) {
                    return "qrc:/images/resources/模块在线.png";
                } else if(status==0) {
                    return "qrc:/images/resources/模块离线.png";
                }else{
                    return "qrc:/images/resources/模块不规范.png"
                }
            }

            // // 背景框
            // Rectangle {
            //     anchors.fill: parent
            //     color: "#00000080"
            //     border.color: "#66666680"
            //     border.width: 1
            //     radius: 5
            // }

            // 标题
            Text {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 5
                text: "机器人模块状态"
                font.pixelSize: 12
                font.bold: true
                color: "#ffffff"
            }

            // 模块网格显示
            GridLayout {
                anchors.fill: parent
                anchors.margins: 8
                anchors.topMargin: 22
                columns: 4
                columnSpacing: 5  // 减小列间距
                rowSpacing: 2      // 减小行间距

                // 1. 电源管理模块
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Image {
                        source: moduleStatusDisplay.getModuleIcon(dataStore.robotModule_power_manager)
                        sourceSize.width: 22
                        sourceSize.height: 22
                        Layout.alignment: Qt.AlignHCenter
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        text: "电源"
                        font.pixelSize: 8
                        color: "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // 2. RFID模块
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Image {
                        source: moduleStatusDisplay.getModuleIcon(dataStore.robotModule_rfid)
                        sourceSize.width: 22
                        sourceSize.height: 22
                        Layout.alignment: Qt.AlignHCenter
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        text: "RFID"
                        font.pixelSize: 8
                        color: "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // 3. 灯条模块
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Image {
                        source: moduleStatusDisplay.getModuleIcon(dataStore.robotModule_light_strip)
                        sourceSize.width: 22
                        sourceSize.height: 22
                        Layout.alignment: Qt.AlignHCenter
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        text: "灯条"
                        font.pixelSize: 8
                        color: "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // 4. 17mm发射机构
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Image {
                        source: moduleStatusDisplay.getModuleIcon(dataStore.robotModule_small_shooter)
                        sourceSize.width: 22
                        sourceSize.height: 22
                        Layout.alignment: Qt.AlignHCenter
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        text: "17mm"
                        font.pixelSize: 8
                        color: "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // 5. 42mm发射机构
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Image {
                        source: moduleStatusDisplay.getModuleIcon(dataStore.robotModule_big_shooter)
                        sourceSize.width: 22
                        sourceSize.height: 22
                        Layout.alignment: Qt.AlignHCenter
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        text: "42mm"
                        font.pixelSize: 8
                        color: "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // 6. 定位模块(UWB)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Image {
                        source: moduleStatusDisplay.getModuleIcon(dataStore.robotModule_uwb)
                        sourceSize.width: 22
                        sourceSize.height: 22
                        Layout.alignment: Qt.AlignHCenter
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        text: "UWB"
                        font.pixelSize: 8
                        color: "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // 7. 装甲模块
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Image {
                        source: moduleStatusDisplay.getModuleIcon(dataStore.robotModule_armor)
                        sourceSize.width: 22
                        sourceSize.height: 22
                        Layout.alignment: Qt.AlignHCenter
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        text: "装甲"
                        font.pixelSize: 8
                        color: "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // 8. 图传模块
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Image {
                        source: moduleStatusDisplay.getModuleIcon(dataStore.robotModule_video_transmission)
                        sourceSize.width: 22
                        sourceSize.height: 22
                        Layout.alignment: Qt.AlignHCenter
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        text: "图传"
                        font.pixelSize: 8
                        color: "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // 9. 电容模块
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Image {
                        source: moduleStatusDisplay.getModuleIcon(dataStore.robotModule_capacitor)
                        sourceSize.width: 22
                        sourceSize.height: 22
                        Layout.alignment: Qt.AlignHCenter
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        text: "电容"
                        font.pixelSize: 8
                        color: "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // 10. 主控模块
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Image {
                        source: moduleStatusDisplay.getModuleIcon(dataStore.robotModule_main_controller)
                        sourceSize.width: 22
                        sourceSize.height: 22
                        Layout.alignment: Qt.AlignHCenter
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        text: "主控"
                        font.pixelSize: 8
                        color: "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // 11. 激光检测模块
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Image {
                        source: moduleStatusDisplay.getModuleIcon(dataStore.robotModule_laser_detection_module)
                        sourceSize.width: 22
                        sourceSize.height: 22
                        Layout.alignment: Qt.AlignHCenter
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        text: "激光"
                        font.pixelSize: 8
                        color: "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // 状态图例说明
            Row {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 5
                spacing: 8

                // 在线
                Row {
                    spacing: 2
                    Rectangle { width: 8; height: 8; radius: 4; color: "#22ff22" }
                    Text { text: "在线"; font.pixelSize: 7; color: "#cccccc" }
                }

                // 不规范离线
                Row {
                    spacing: 2
                    Rectangle { width: 8; height: 8; radius: 4; color: "#ffff22" }
                    Text { text: "不规范"; font.pixelSize: 7; color: "#cccccc" }
                }

                // 离线
                Row {
                    spacing: 2
                    Rectangle { width: 8; height: 8; radius: 4; color: "#ff2222" }
                    Text { text: "离线"; font.pixelSize: 7; color: "#cccccc" }
                }
            }
        }
                // 7. 左下角状态条
        Item {
            anchors.left: parent.left
            anchors.bottom: moduleStatusDisplay.top
            anchors.margins: 20
            width: 200
            height: 40
            z: 11

            // 机器人图标
            Rectangle { 
                width: 40; 
                height: 40; 
                radius: 20; 
                color: "#111111"; 
                border.color: "#666666"
                
                Text {
                    anchors.centerIn: parent
                    text: dataStore.robotStatic_robot_type === 1 ? "英" :
                          dataStore.robotStatic_robot_type === 2 ? "工" :
                          dataStore.robotStatic_robot_type === 3 ? "步1" :
                          dataStore.robotStatic_robot_type === 4 ? "步2" :
                          dataStore.robotStatic_robot_type === 6 ? "空" :
                          dataStore.robotStatic_robot_type === 7 ? "哨" : "机"
                    font.pixelSize: 14
                    font.bold: true
                    color: dataStore.robotStatic_alive_state === 1 ? "#22ff22" : 
                           dataStore.robotStatic_alive_state === 2 ? "#ff2222" : "#aaaaaa"
                }
            }

            // 血量进度条
            Rectangle {
                anchors.left: parent.children[0].right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 140
                height: 15
                color: "#222222"
                radius: 7

                Rectangle { 
                    anchors.fill: parent; 
                    color: {
                        let currentHealth = root.getCurrentRobotHealth ? root.getCurrentRobotHealth() : 0;
                        let maxHealth = dataStore.robotStatic_max_health || 1;
                        let ratio = currentHealth / Math.max(1, maxHealth);
                        if (ratio > 0.5) return "#22ff22";
                        else if (ratio > 0.2) return "#ffff22";
                        else return "#ff2222";
                    }
                    radius: 7; 
                    width: Math.max(0, parent.width * (
                        (root.getCurrentRobotHealth ? root.getCurrentRobotHealth() : 0) / 
                        Math.max(1, dataStore.robotStatic_max_health || 1)
                    )) 
                }
                
                // 等级标识
                Rectangle { 
                    anchors.bottom: parent.bottom; 
                    height: 5; 
                    color: "#2288ff"; 
                    radius: 3; 
                    width: Math.min(parent.width, parent.width * ((dataStore.robotStatic_level || 1) / 10))
                }

                Text {
                    anchors.centerIn: parent
                    text: (root.getCurrentRobotHealth ? root.getCurrentRobotHealth() : 0) + "/" + 
                          (dataStore.robotStatic_max_health || 0) + " Lv." + 
                          (dataStore.robotStatic_level || 1)
                    font.pixelSize: 10
                    color: "white"
                }
            }
        }
         // 7. 右下角控制框（修改：展示键鼠信息）
    Item {
        id: keyControlBox
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.rightMargin: 20
        width: 350 // 加宽以容纳更多信息
        height: 80 // 加高
        z: 12
        
        // 控制框背景图片
        Image {
            anchors.fill: parent
            source: "qrc:/images/resources/控制框.png"
            fillMode: Image.StretchToCover
            mipmap: true
            
            onStatusChanged: {
                if (status === Image.Error) {
                    console.log("控制框图片加载失败！");
                    keyControlBox.children[1].visible = true;
                }
            }
        }
        
        // 兜底背景
        Rectangle {
            anchors.fill: parent
            color: "#222222"
            border.color: "#666666"
            border.width: 1
            radius: 5
            visible: false
        }

        // 新增：键鼠信息展示布局
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            // 第一行：键盘信息
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "键盘："
                    font.pixelSize: 11
                    color: "#aaaaaa"
                }
                Text {
                    text: dataStore.keyInfoText || "无按键操作"
                    font.pixelSize: 11
                    color: "#ffffff"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            // 第二行：鼠标位置
           RowLayout {
    Layout.fillWidth: true
    Text {
        text: "鼠标位移："
        font.pixelSize: 11
        color: "#aaaaaa"
    }
    Text {
        text: "ΔX=" + dataStore.input_mouseX + ", ΔY=" + dataStore.input_mouseY
        font.pixelSize: 11
        color: "#22ff22"
        Layout.fillWidth: true
    }
}
            
            // 第三行：滚轮信息 + 鼠标按键状态
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "滚轮："
                    font.pixelSize: 11
                    color: "#aaaaaa"
                }
                Text {
                    text: dataStore.wheelInfoText || "无滚动"
                    font.pixelSize: 11
                    color: "#ffffff"
                    Layout.preferredWidth: 150
                }
                Text {
                    text: Qt.binding(() => {
                        let btns = [];
                        if (dataStore.input_leftBtnDown) btns.push("左键");
                        if (dataStore.input_rightBtnDown) btns.push("右键");
                        if (dataStore.input_midBtnDown) btns.push("中键");
                        return btns.length > 0 ? "按下：" + btns.join(",") : "无按键按下";
                    })
                    font.pixelSize: 11
                    color: "#ffff00"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }
            }
            // 第四行：捕获模式状态提示
RowLayout {
    Layout.fillWidth: true
    Text {
        text: "状态："
        font.pixelSize: 11
        color: "#aaaaaa"
    }
    Text {
        text: dataStore.input_mouseCaptureEnabled ? "捕获模式开启 (按 I 键切换)" : "捕获模式关闭 (按 I 键开启)"
        font.pixelSize: 11
        color: dataStore.input_mouseCaptureEnabled ? "#44ff44" : "#ff4444"
        Layout.fillWidth: true
    }
}
        }
    }
// 8. 右下角地图
Rectangle {
    id:miniMap
    anchors.right: parent.right
    anchors.bottom: keyControlBox.top
    anchors.bottomMargin: 10
    anchors.rightMargin: 20
    width: 350
    height: 189
    color: "#222222"
    border.color: "#666666"
    border.width: 1
    z: 11
    clip: true  // 开启裁剪，确保只显示截取区域

    // 地图图片（带裁剪）
    Image {
        id: mapImage
        // 设置源图片
        source: "qrc:/images/resources/地图.png"
        
        // 设置图片填充方式
        fillMode: Image.PreserveAspectFit
        asynchronous: true  // 异步加载，避免阻塞UI
        mipmap: true  // 开启mipmap提高缩放质量
        
        // 初始位置设置
        x: 0
        y: -161
        
        // 设置图片大小
        sourceSize.width: 350 // 确保源图片有足够的分辨率
        sourceSize.height: 350
        
        // 加载状态处理
        onStatusChanged: {
            if (status === Image.Error) {
                console.log("地图图片加载失败！路径：qrc:/images/resources/地图.png")
                // 显示错误提示
                miniMap.children[1].visible = true
            } else if (status === Image.Ready) {
                console.log("地图图片加载成功，尺寸：" + width + "x" + height)
            }
        }
    }
    
    // 图片加载失败时的备用显示
    Rectangle {
        visible: false
        anchors.fill: parent
        color: "#333333"
        
        Column {
            anchors.centerIn: parent
            spacing: 5
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "地图加载失败"
                font.pixelSize: 12
                color: "#ff6666"
            }
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "请检查文件：小地图.png"
                font.pixelSize: 10
                color: "#aaaaaa"
            }
            
            // 备用简易地图
            Rectangle {
                width: 150
                height: 100
                color: "#444444"
                border.color: "#666666"
                border.width: 1
                
                // 简单的示意元素
                Rectangle {
                    x: 20
                    y: 20
                    width: 10
                    height: 10
                    color: "red"
                }
                Rectangle {
                    x: 120
                    y: 70
                    width: 10
                    height: 10
                    color: "blue"
                }
                Rectangle {
                    x: 75
                    y: 50
                    width: 8
                    height: 8
                    radius: 4
                    color: "yellow"
                }
            }
        }
    }
    
    // 添加一个网格线覆盖层（可选，用于调试显示截取区域）
    /*
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: "#44ff44"
        border.width: 1
        opacity: 0.3
        
        // 中心十字线
        Rectangle {
            width: parent.width
            height: 1
            y: parent.height / 2
            color: "#44ff44"
            opacity: 0.5
        }
        Rectangle {
            width: 1
            height: parent.height
            x: parent.width / 2
            color: "#44ff44"
            opacity: 0.5
        }
        
        // 标注截取起点
        Text {
            x: 0
            y: 0
            text: "(50,30)"
            font.pixelSize: 8
            color: "#44ff44"
        }
    }
    */
    
    // 添加缩放控制滑块（可选，用于动态调整截取区域）
    /*
    Column {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 5
        spacing: 2
        z: 2
        
        Text { 
            text: "X: " + Math.round(-mapImage.x)
            font.pixelSize: 8
            color: "white"
        }
        Slider {
            width: 80
            from: 0
            to: 200
            value: 50
            onValueChanged: mapImage.x = -value
        }
        
        Text { 
            text: "Y: " + Math.round(-mapImage.y)
            font.pixelSize: 8
            color: "white"
        }
        Slider {
            width: 80
            from: 0
            to: 200
            value: 30
            onValueChanged: mapImage.y = -value
        }
    }
    */
}
       
    }

    // 9. 准星
    Item {
        id: crosshairItem
        x: (parent.width - 60) / 2
        y: (parent.height - 60) / 2
        width: 60
        height: 60
        z: 99999

        function updatePos() {
            crosshairItem.x = (parent.width - crosshairItem.width) / 2
            crosshairItem.y = (parent.height - crosshairItem.height) / 2
        }

        Connections {
            target: mainWindow
            function onWidthChanged() { crosshairItem.updatePos() }
            function onHeightChanged() { crosshairItem.updatePos() }
        }

        Image {
            id: crosshairImg
            anchors.fill: parent
            source: "qrc:/images/resources/准星.png"
            fillMode: Image.PreserveAspectFit
            mipmap: true

            onStatusChanged: {
                if (status === Image.Error) {
                    console.log("准星图片加载失败！请检查qrc文件配置和图片路径")
                    crosshairImg.source = ""
                    crosshairItem.children[1].visible = true
                }
            }
        }

        // 兜底十字
        Item {
            visible: false
            anchors.fill: parent
            Rectangle { width: parent.width; height: 2; color: "red"; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 2; height: parent.height; color: "red"; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }

    // 10. 窗口控制按钮
    Item {
        id: btnContainer
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 0
        width: 120
        height: 50
        z: 999999

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: windowBtnBar.opacity = 1
            onExited: {
                Qt.callLater(() => {
                    if (!minBtnMouse.containsMouse && !maxBtnMouse.containsMouse && !closeBtnMouse.containsMouse) {
                        windowBtnBar.opacity = 0
                    }
                }, 100)
            }
            propagateComposedEvents: true
            onClicked: mouse.accepted = false
        }

        Row {
            id: windowBtnBar
            anchors.fill: parent
            anchors.centerIn: parent
            spacing: 8
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // 缩小按钮
            Rectangle {
                id: minBtn
                width: 35
                height: 35
                radius: 8
                color: "#333333"
                border.color: "#555555"
                border.width: 1

                MouseArea {
                    id: minBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: minBtn.color = "#555555"
                    onExited: {
                        minBtn.color = "#333333"
                        Qt.callLater(() => {
                            if (!parent.parent.dragMouseArea.containsMouse && !maxBtnMouse.containsMouse && !closeBtnMouse.containsMouse) {
                                windowBtnBar.opacity = 0
                            }
                        }, 50)
                    }
                    onClicked: { if (mainWindow) mainWindow.showMinimized() }
                }

                Image {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: "qrc:/images/resources/缩小.png"
                    fillMode: Image.PreserveAspectFit
                    onStatusChanged: {
                        if (status === Image.Error) {
                            console.log("缩小按钮图片加载失败，使用文本兜底")
                            minBtn.children[2].visible = true
                        }
                    }
                }
                
                // 缩小按钮兜底文本
                Text {
                    visible: false
                    anchors.centerIn: parent
                    text: "-"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#ffffff"
                }
            }

            // 最大化/还原按钮
            Rectangle {
                id: maxBtn
                width: 35
                height: 35
                radius: 8
                color: "#333333"
                border.color: "#555555"
                border.width: 1

                MouseArea {
                    id: maxBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: maxBtn.color = "#555555"
                    onExited: {
                        maxBtn.color = "#333333"
                        Qt.callLater(() => {
                            if (!parent.parent.dragMouseArea.containsMouse && !minBtnMouse.containsMouse && !closeBtnMouse.containsMouse) {
                                windowBtnBar.opacity = 0
                            }
                        }, 50)
                    }
                    onClicked: toggleMaximize()
                }

                Image {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: dataStore.isMaximized ? "qrc:/images/resources/还原.png" : "qrc:/images/resources/大窗.png"
                    fillMode: Image.PreserveAspectFit
                    onStatusChanged: {
                        if (status === Image.Error) {
                            console.log("最大化/还原按钮图片加载失败，使用文本兜底")
                            maxBtn.children[2].visible = true
                        }
                    }
                }
                
                // 最大化/还原按钮兜底文本
                Text {
                    visible: false
                    anchors.centerIn: parent
                    text: dataStore.isMaximized ? "□" : "■"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#ffffff"
                }
            }

            // 关闭按钮
            Rectangle {
                id: closeBtn
                width: 35
                height: 35
                radius: 8
                color: "#333333"
                border.color: "#555555"
                border.width: 1

                MouseArea {
                    id: closeBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: closeBtn.color = "#ff3333"
                    onExited: {
                        closeBtn.color = "#333333"
                        Qt.callLater(() => {
                            if (!parent.parent.dragMouseArea.containsMouse && !minBtnMouse.containsMouse && !maxBtnMouse.containsMouse) {
                                windowBtnBar.opacity = 0
                            }
                        }, 50)
                    }
                    onClicked: { if (mainWindow) mainWindow.close() }
                }

                Image {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: "qrc:/images/resources/关闭.png"
                    fillMode: Image.PreserveAspectFit
                    onStatusChanged: {
                        if (status === Image.Error) {
                            console.log("关闭按钮图片加载失败，使用文本兜底")
                            closeBtn.children[2].visible = true
                        }
                    }
                }
                
                // 关闭按钮兜底文本
                Text {
                    visible: false
                    anchors.centerIn: parent
                    text: "×"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#ffffff"
                }
            }
        }
    }
    
    // 11. 全局事件通知（修复队列显示问题）
Item {
    id: eventNotification
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: scoreBar.bottom
    anchors.topMargin: 20
    width: 700
    height: 100
    z: 1000000
    visible: false
    
    // 事件通知队列
    property var eventQueue: []
    property bool isShowing: false
    property int displayCount: 0 // 显示计数器，用于调试
    
    // ========== 先定义所有辅助函数 ==========
    
    function getRobotName(robotId) {
        if (!robotId || robotId <= 0) return "未知";
        
        if (robotId === 1) return "🔴 红方英雄";
        if (robotId === 2) return "🔴 红方工程";
        if (robotId === 3) return "🔴 红方步兵1号";
        if (robotId === 4) return "🔴 红方步兵2号";
        if (robotId === 5) return "🔴 红方步兵3号";
        if (robotId === 6) return "🔴 红方空中机器人";
        if (robotId === 7) return "🔴 红方哨兵";
        if (robotId === 8) return "🔴 红方飞镖";
        if (robotId === 9) return "🔴 红方雷达";
        if (robotId === 10) return "🔴 红方前哨站";
        if (robotId === 11) return "🔴 红方基地";
        
        if (robotId === 101) return "🔵 蓝方英雄";
        if (robotId === 102) return "🔵 蓝方工程";
        if (robotId === 103) return "🔵 蓝方步兵1号";
        if (robotId === 104) return "🔵 蓝方步兵2号";
        if (robotId === 105) return "🔵 蓝方步兵3号";
        if (robotId === 106) return "🔵 蓝方空中机器人";
        if (robotId === 107) return "🔵 蓝方哨兵";
        if (robotId === 108) return "🔵 蓝方飞镖";
        if (robotId === 109) return "🔵 蓝方雷达";
        if (robotId === 110) return "🔵 蓝方前哨站";
        if (robotId === 111) return "🔵 蓝方基地";
        
        return "机器人(" + robotId + ")";
    }
    
    function getTeamName(robotId) {
        if (robotId >= 1 && robotId <= 11) return "红方";
        if (robotId >= 101 && robotId <= 111) return "蓝方";
        return "未知";
    }
    
    function parseKillParam(param) {
        if (!param || param.length < 3) return { killer: 0, victim: 0 };
        
        var killerId, victimId;
        
        // 示例: "1103" 表示 killer=1 (红方英雄), victim=103 (蓝方步兵3号)
        if (param.length === 4) {
            var possibleKiller = parseInt(param.substring(0, 1));
            var possibleVictim = parseInt(param.substring(1));
            
            if (possibleVictim >= 101 && possibleVictim <= 111) {
                killerId = possibleKiller;
                victimId = possibleVictim;
            } else {
                killerId = parseInt(param.substring(0, 2));
                victimId = parseInt(param.substring(2));
            }
        } else if (param.length === 5) {
            killerId = parseInt(param.substring(0, 2));
            victimId = parseInt(param.substring(2));
        } else if (param.length === 3) {
            killerId = parseInt(param.substring(0, 1));
            victimId = parseInt(param.substring(1));
        } else {
            killerId = parseInt(param);
            victimId = 0;
        }
        
        return { killer: killerId, victim: victimId };
    }
    
    function getEventTitle(eventId) {
        switch(eventId) {
            case 1: return "⚔️ 击杀事件";
            case 2: return "💥 基地/前哨站被摧毁";
            case 3: return "⚡ 能量机关可激活次数变化";
            case 4: return "🔮 能量机关进入可激活状态";
            case 5: return "✨ 能量机关激活结果";
            case 6: return "🌟 能量机关被激活";
            case 7: return "🛡️ 英雄进入部署模式";
            case 8: return "🎯 己方英雄造成狙击伤害";
            case 9: return "⚠️ 对方英雄造成狙击伤害";
            case 10: return "✈️ 己方呼叫空中支援";
            case 11: return "🔫 己方空中支援被打断";
            case 12: return "🛸 对方呼叫空中支援";
            case 13: return "🛡️ 对方空中支援被打断";
            case 14: return "🎯 飞镖命中";
            case 15: return "🚪 飞镖闸门开启";
            case 16: return "🏰 己方基地遭到攻击";
            case 17: return "🔄 前哨站停转";
            case 18: return "🛡️ 基地护甲展开";
            default: return "📢 系统事件 (ID:" + eventId + ")";
        }
    }
    
    function getEventDescription(eventId, param) {
        switch(eventId) {
            case 1: {
                var result = parseKillParam(param);
                if (result.killer > 0 && result.victim > 0) {
                    var killerTeam = getTeamName(result.killer);
                    var victimTeam = getTeamName(result.victim);
                    
                    if (killerTeam === victimTeam) {
                        return "⚠️ " + getRobotName(result.killer) + " 误杀了队友 " + getRobotName(result.victim);
                    } else {
                        return getRobotName(result.killer) + " 击杀了 " + getRobotName(result.victim);
                    }
                }
                return "发生击杀事件";
            }
            case 2: {
                if (param) {
                    var targetId = parseInt(param);
                    var targetName = getRobotName(targetId);
                    if (targetId === 11 || targetId === 111) {
                        return "💔 " + targetName + " 已被摧毁！游戏结束！";
                    } else if (targetId === 10 || targetId === 110) {
                        return "💔 " + targetName + " 已被摧毁！";
                    }
                    return targetName + " 已被摧毁！";
                }
                return "基地/前哨站被摧毁";
            }
            case 3: {
                var remaining = parseInt(param || "0");
                if (remaining === 0) {
                    return "能量机关已无可激活次数";
                } else if (remaining === 1) {
                    return "能量机关剩余最后1次激活机会";
                } else {
                    return "能量机关剩余 " + remaining + " 次激活机会";
                }
            }
            case 4: {
                return "⚡ 能量机关现已可激活！";
            }
            case 5: {
                if (param && param.length >= 3) {
                    var arms = parseInt(param.substring(0, param.length - 2));
                    var rings = parseInt(param.substring(param.length - 2));
                    
                    var buffDesc = "";
                    if (arms === 4) buffDesc = "全体增益";
                    else if (arms === 3) buffDesc = "强力增益";
                    else if (arms === 2) buffDesc = "中等增益";
                    else buffDesc = "微弱增益";
                    
                    return "✨ 能量机关激活成功！" + arms + "个灯臂，平均" + rings + "环 (" + buffDesc + ")";
                }
                return "能量机关激活成功";
            }
            case 6: {
                var activateType = parseInt(param || "0");
                return activateType === 1 ? "🌟 能量机关被常规激活" : 
                       (activateType === 2 ? "⚡ 能量机关被快速激活" : "能量机关被激活");
            }
            case 7: {
                return "🛡️ 英雄已进入部署模式，可造成狙击伤害";
            }
            case 8: {
                var damage = parseInt(param || "0");
                return "🎯 己方英雄造成 " + damage + " 点狙击伤害" + (damage >= 500 ? " (暴击！)" : "");
            }
            case 9: {
                var enemyDamage = parseInt(param || "0");
                return "⚠️ 对方英雄造成 " + enemyDamage + " 点狙击伤害" + (enemyDamage >= 500 ? " (危险！)" : "");
            }
            case 10: {
                return "✈️ 己方呼叫空中支援！";
            }
            case 11: {
                var remainingInterrupts = parseInt(param || "0");
                return "🔫 己方空中支援被打断！对方剩余打断次数: " + remainingInterrupts;
            }
            case 12: {
                return "🛸 对方呼叫空中支援！";
            }
            case 13: {
                var ourRemaining = parseInt(param || "0");
                return "🛡️ 对方空中支援被打断！己方剩余打断次数: " + ourRemaining;
            }
            case 14: {
                var targetType = parseInt(param || "0");
                var targetNames = {
                    1: "前哨站",
                    2: "基地固定目标",
                    3: "基地随机固定目标", 
                    4: "基地随机移动目标",
                    5: "基地末端移动目标"
                };
                var targetName = targetNames[targetType] || "未知目标";
                
                var damageDesc = "";
                if (targetType === 1) damageDesc = "造成800点伤害";
                else if (targetType === 2) damageDesc = "造成500点伤害";
                else if (targetType === 3) damageDesc = "造成350点伤害";
                else if (targetType === 4) damageDesc = "造成200点伤害";
                else if (targetType === 5) damageDesc = "造成100点伤害";
                
                return "🎯 飞镖命中 " + targetName + "！" + (damageDesc ? " (" + damageDesc + ")" : "");
            }
            case 15: {
                var side = parseInt(param || "0");
                return side === 1 ? "🚪 己方飞镖闸门开启，可以发射飞镖" : 
                       (side === 2 ? "🚪 对方飞镖闸门开启" : "飞镖闸门开启");
            }
            case 16: {
                return "⚠️⚠️ 警告：己方基地遭到攻击！ ⚠️⚠️";
            }
            case 17: {
                var stopSide = parseInt(param || "0");
                var sideName = stopSide === 1 ? "己方" : (stopSide === 2 ? "对方" : "");
                return "🔄 " + sideName + "前哨站停转！失去防御能力";
            }
            case 18: {
                var armorSide = parseInt(param || "0");
                var armorSideName = armorSide === 1 ? "己方" : (armorSide === 2 ? "对方" : "");
                return "🛡️ " + armorSideName + "基地护甲展开！防御力提升";
            }
            default: return "事件ID: " + eventId + ", 参数: " + (param || "无");
        }
    }
    
    function setEventColor(eventId) {
        if ([1, 2, 16].indexOf(eventId) >= 0) {
            eventBg.color = "#ff3333";
            eventBg.opacity = 0.95;
        }
        else if ([3, 4, 5, 6, 10, 11, 12, 13, 14, 15].indexOf(eventId) >= 0) {
            eventBg.color = "#ffaa00";
            eventBg.opacity = 0.95;
        }
        else if ([7, 8, 9, 17, 18].indexOf(eventId) >= 0) {
            eventBg.color = "#2288ff";
            eventBg.opacity = 0.95;
        }
        else {
            eventBg.color = "#333333";
            eventBg.opacity = 0.9;
        }
    }
    
    // 处理新事件
    function handleNewEvent(eventId, eventParam) {
        if (eventId <= 0) return;
        
        displayCount++;
        
        // 创建事件对象，每个事件都是独立的
        var eventInfo = {
            id: eventId,
            param: eventParam || "",
            timestamp: new Date().getTime(),
            displayIndex: displayCount // 添加显示索引用于调试
        };
        
        // 加入队列
        eventQueue.push(eventInfo);
        
        console.log("========== 收到全局事件 #" + displayCount + " ==========");
        console.log("事件ID:", eventId);
        console.log("参数:", eventParam || "(空)");
        console.log("描述:", getEventDescription(eventId, eventParam));
        console.log("加入队列前长度:", eventQueue.length - 1);
        console.log("加入队列后长度:", eventQueue.length);
        console.log("当前是否在显示:", isShowing);
        console.log("==================================");
        
        // 如果没有正在显示，开始显示
        if (!isShowing) {
            console.log("开始显示第一个事件");
            showNextEvent();
        } else {
            console.log("正在显示中，事件已加入队列，等待显示");
        }
    }
    
    // 显示下一个事件
    function showNextEvent() {
        if (eventQueue.length === 0) {
            console.log("队列为空，停止显示");
            isShowing = false;
            visible = false;
            return;
        }
        
        isShowing = true;
        var event = eventQueue[0]; // 先查看但不移除
        
        console.log("准备显示事件 #" + event.displayIndex + ", ID:", event.id, "队列长度:", eventQueue.length);
        
        eventTitle.text = getEventTitle(event.id);
        eventDesc.text = getEventDescription(event.id, event.param);
        setEventColor(event.id);
        
        visible = true;
        
        // 启动显示动画
        showAnimation.start();
        
        console.log("开始显示事件 #" + event.displayIndex + ", ID:", event.id);
    }
    
    // 完成当前显示，准备显示下一个
    function finishCurrentDisplay() {
        if (eventQueue.length > 0) {
            var finishedEvent = eventQueue.shift(); // 移除已显示的事件
            console.log("完成显示事件 #" + finishedEvent.displayIndex + ", ID:", finishedEvent.id, "剩余队列:", eventQueue.length);
        }
        
        visible = false;
        
        // 显示下一个事件
        if (eventQueue.length > 0) {
            console.log("准备显示下一个事件，剩余队列:", eventQueue.length);
            // 使用定时器短暂延迟后显示下一个，避免动画冲突
            nextTimer.start();
        } else {
            console.log("所有事件显示完毕");
            isShowing = false;
        }
    }
    
    // 延迟显示下一个事件的定时器
    Timer {
        id: nextTimer
        interval: 50
        repeat: false
        onTriggered: {
            eventNotification.showNextEvent();
        }
    }
    
    // ========== 直接监听eventHandler的信号 ==========
    
    Connections {
        target: eventHandler
        
        function onEventUpdated(map) {
            var eventId = map ? (map.event_id || 0) : 0;
            var eventParam = map ? (map.param || "") : "";
            
            console.log("eventHandler 触发事件: ID=", eventId, "参数=", eventParam);
            
            if (eventId > 0) {
                eventNotification.handleNewEvent(eventId, eventParam);
            }
        }
    }
    
    // ========== UI元素 ==========
    
    Rectangle {
        id: eventBg
        anchors.fill: parent
        radius: 15
        border.color: "#ffffff"
        border.width: 2
        opacity: 0.95
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(eventBg.color.r, eventBg.color.g, eventBg.color.b, 0.9) }
            GradientStop { position: 1.0; color: Qt.rgba(eventBg.color.r * 0.7, eventBg.color.g * 0.7, eventBg.color.b * 0.7, 0.9) }
        }
    }
    
    Rectangle {
        anchors.fill: parent
        radius: 15
        color: "transparent"
        border.color: "#ffffff"
        border.width: 3
        opacity: 0.3
    }
    
    Column {
        anchors.centerIn: parent
        spacing: 8
        
        Text {
            id: eventTitle
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 24
            font.bold: true
            color: "#ffffff"
            style: Text.Outline
            styleColor: "#000000"
        }
        
        Text {
            id: eventDesc
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 20
            color: "#ffffff"
            style: Text.Outline
            styleColor: "#000000"
        }
    }
    
    Rectangle {
        id: progressBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 2
        height: 4
        radius: 2
        color: "#ffffff"
        opacity: 0.5
        
        Rectangle {
            id: progressFill
            height: parent.height
            width: parent.width
            radius: 2
            color: "#ffff00"
            
            PropertyAnimation {
                id: progressAnimation
                target: progressFill
                property: "width"
                from: eventNotification.width - 4
                to: 0
                duration: 2000
                easing.type: Easing.Linear
            }
        }
    }
    
    // 显示动画
    SequentialAnimation {
        id: showAnimation
        
        // 淡入
        PropertyAnimation {
            target: eventNotification
            property: "opacity"
            from: 0
            to: 1
            duration: 200
        }
        
        // 开始进度条动画
        ScriptAction {
            script: {
                progressAnimation.start();
            }
        }
        
        // 显示2秒
        PauseAnimation { duration: 2000 }
        
        // 淡出
        PropertyAnimation {
            target: eventNotification
            property: "opacity"
            from: 1
            to: 0
            duration: 200
        }
        
        // 完成当前显示
        ScriptAction {
            script: {
                eventNotification.finishCurrentDisplay();
            }
        }
    }
    
    opacity: 0
}
}