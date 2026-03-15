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
            visible: dataStore.gameStatus_is_paused || dataStore.gameStatus_current_stage === 6

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
            z:100
            clip: false 

            // ========== 新增：比分栏背景图片 ==========苏丹，有问题，置顶不了
            Image {
                id: scoreBarBg
                // 核心：按父组件（比分栏）高度等比缩放
                anchors.top: root.top  
                anchors.horizontalCenter: parent.horizontalCenter  // 水平仍居中
                height: parent.height-40  // 高度和比分栏一致
                width: implicitWidth   // 宽度按图片原始比例自动计算
                anchors.centerIn: parent  // 图片在比分栏中居中显示（可选，更美观）
                
                
                // 正确的图片路径（你能显示的那个）
                //source: "file:///home/suhezhou/hetengchun_202406050127/RobomasterClient/qml/resources/比分栏.png"
                source: "qrc:/images/resources/比分栏.png"
                // 关键：保持宽高比，完整显示，不拉伸变形
                fillMode: Image.PreserveAspectFit
                smooth: true  // 缩放后更清晰
                opacity: 1.0
                z: 99
                anchors.topMargin: 0
            }
            // 中间比分/回合/倒计时显示
            Item {
                id: middleScoreBlock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 20
                width: 120
                height: 60
                z: 101
                
                Text {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Round: " + (dataStore.gameStatus_current_round > 0 ? dataStore.gameStatus_current_round : "0") + "/" + dataStore.gameStatus_total_rounds
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
                // 比赛倒计时(也是当前阶段倒计时)
                Text {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    // 核心：格式化倒计时为 "m:ss" 格式
                    text: {
                        // 获取总秒数，默认0
                        let totalSec = dataStore.gameStatus_stage_countdown_sec || 0;
                        // 计算分钟和秒
                        let minutes = Math.floor(totalSec / 60);
                        let seconds = totalSec % 60;
                        // 秒数补0（不足10时显示0x）
                        let secondsStr = seconds.toString().padStart(2, '0');
                        // 返回 "分钟:秒" 格式
                        return `${minutes}:${secondsStr}`;
                    }
                    font.pixelSize: 14  // 字体从9放大到14，可根据需要调整
                    font.bold: true  // 加粗
                    color: (dataStore.gameStatus_stage_countdown_sec || 0) <= 10 ? "#ff3333" : "#c3f413ff"
                    // 倒计时≤10秒且处于第4阶段时，闪烁动画（保留原有逻辑）
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: (dataStore.gameStatus_stage_countdown_sec || 0) <= 10 && dataStore.gameStatus_current_stage === 4
                        NumberAnimation { to: 1; duration: 500 }
                        NumberAnimation { to: 0.5; duration: 500 }
                    }
                }
            }

            // 红方基地模块
            Item {
                id: redVictoryPointBar
                anchors.right: middleScoreBlock.left
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.rightMargin: 20
                width: 300
                height: 60

                // 血量进度条
                Rectangle {
                    id: redProgressBar
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 20
                    property int health:dataStore.globalUnit_base_health || 0
                    // 无敌状态金色边框（仅在 base_status === 0 时显示）
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3  // 向外扩展一点，让边框更明显
                        color: "transparent"
                        border.color: "#ffd700"  // 金色
                        border.width: 3
                        radius: 10
                        visible: dataStore.globalUnit_base_status === 0
                        opacity: 0.8
                        
                        // 可选：添加呼吸动画效果
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: dataStore.globalUnit_base_status === 0
                            NumberAnimation { to: 1; duration: 800 }
                            NumberAnimation { to: 0.5; duration: 800 }
                        }
                    }
                    
                    // 背景色：根据血量值决定
                    color: {
                        
                        return health > 2000 ? "#e05330" : "transparent";  // health>2000时背景为浅红色，否则透明
                    }
                    radius: 6
                    border.width: health > 2000 ? 0 : 1  // 当背景透明时加个边框以便看清
                    border.color: "#e05330"  // 透明背景时的边框颜色
                    
                    // 血量条（前景）
                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: Math.min(parent.width, parent.width * (Math.min(dataStore.globalUnit_base_health || 0, 5000) / 5000))
                        // 血量条颜色：根据血量值决定
                        color: {
                            let health = dataStore.globalUnit_base_health || 0;
                            return health > 2000 ? "#8b0000" : "#e05330";  // >2000深红，≤2000浅红
                        }
                        radius: 6
                    }
                    
                    // 可选：显示血量数字（如果需要）
                    // Text {
                    //     anchors.centerIn: parent
                    //     text: (dataStore.globalUnit_base_health || 0) + "/5000"
                    //     color: "white"
                    //     font.pixelSize: 10
                    //     font.bold: true
                    // }
                }

                // 校徽（R标）
                Image {
                    id: redLogo
                    anchors.right: redProgressBar.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 10
                    width: 40
                    height: 40
                    source: "data:image/svg+xml;utf8,<svg width='30' height='30'><circle cx='15' cy='15' r='12' fill='#ff2222' stroke='#ffffff' stroke-width='1'/><text x='15' y='20' text-anchor='middle' font-size='16' font-weight='bold' fill='white'>R</text></svg>"
                }

                // 校名+战队名
                Column {
                    anchors.right: redLogo.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 20
                    spacing: 2
                    Text { 
                        text: " 校名"; 
                        font.pixelSize: 12; 
                        color: "#ffffff";
                        horizontalAlignment: Text.AlignRight
                    }
                    Text { 
                        text: " 红方战队"; 
                        font.pixelSize: 12; 
                        color: "#ffffff";
                        horizontalAlignment: Text.AlignRight
                    }
                    Text { 
                        text: " 前哨站血量" ; 
                        font.pixelSize: 14; 
                        font.bold: true; 
                        color: (dataStore.globalUnit_outpost_health || 0) <= 0 ? "#ff3333" : "#ffffff";
                        horizontalAlignment: Text.AlignRight
                    }
                    
                    // 血量条
                    Rectangle {
                        width: 100
                        height: 8
                        color: "#550000"
                        radius: 4
                        opacity: 0.8
                        
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2  // 向外扩展一点，让边框更明显
                            color: "transparent"
                            border.color: "#ffd700"  // 金色
                            border.width: 2
                            radius: 8
                            visible: dataStore.globalUnit_outpost_status === 0
                            opacity: 0.8
                            
                            // 可选：添加呼吸动画效果
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: dataStore.globalUnit_outpost_status === 0
                                NumberAnimation { to: 1; duration: 800 }
                                NumberAnimation { to: 0.5; duration: 800 }
                            }
                        }

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: parent.width * (Math.min(dataStore.globalUnit_outpost_health || 0, 1500) / 1500)
                            color: "#8b0000"
                            radius: 4
                        }
                    }
                    Text { 
                        text: " "+(dataStore.globalUnit_outpost_health || 0); 
                        font.pixelSize: 14; 
                        font.bold: true; 
                        color: "#ff3333";
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // 蓝方基地模块
            Item {
                id: blueVictoryPointBar
                anchors.left: middleScoreBlock.right
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.leftMargin: 20
                width: redVictoryPointBar.width
                height: redVictoryPointBar.height

                // 血量进度条
                Rectangle {
                    id: blueProgressBar
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 20
                    property int health :dataStore.globalUnit_enemy_base_health || 0
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3  // 向外扩展一点，让边框更明显
                        color: "transparent"
                        border.color: "#ffd700"  // 金色
                        border.width: 3
                        radius: 10
                        visible: dataStore.globalUnit_enemy_base_status === 0
                        opacity: 0.8
                        
                        // 可选：添加呼吸动画效果
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: dataStore.globalUnit_enemy_base_status === 0
                            NumberAnimation { to: 1; duration: 800 }
                            NumberAnimation { to: 0.5; duration: 800 }
                        }
                    }
                    
                    // 背景色：根据血量值决定
                    color: {
                        
                        return health > 2000 ? "#2288ff" : "transparent";  // health>2000时背景为蓝色，否则透明
                    }
                    radius: 6
                    border.width: health > 2000 ? 0 : 1  // 当背景透明时加个边框以便看清
                    border.color: "#2288ff"  // 透明背景时的边框颜色
                    
                    // 血量条（前景）
                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: Math.min(parent.width, parent.width * (Math.min(dataStore.globalUnit_enemy_base_health || 0, 5000) / 5000))
                        // 血量条颜色：根据血量值决定
                        color: {
                            let health = dataStore.globalUnit_enemy_base_health || 0;
                            return health > 2000 ? "#00008b" : "#2288ff";  // >2000深蓝，≤2000浅蓝
                        }
                        radius: 6
                    }
                }

                // 校徽（R标）
                Image {
                    id: blueLogo
                    anchors.left: blueProgressBar.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    width: 40
                    height: 40
                    source: "data:image/svg+xml;utf8,<svg width='30' height='30'><circle cx='15' cy='15' r='12' fill='#2288ff' stroke='#ffffff' stroke-width='1'/><text x='15' y='20' text-anchor='middle' font-size='16' font-weight='bold' fill='white'>R</text></svg>"
                }

                // 校名+战队名
                Column {
                    anchors.left: blueLogo.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 20
                    spacing: 2
                    Text { 
                        text: " 校名"; 
                        font.pixelSize: 12; 
                        color: "#ffffff";
                        horizontalAlignment: Text.AlignLeft
                    }
                    Text { 
                        text: " 蓝方战队"; 
                        font.pixelSize: 12; 
                        color: "#ffffff";
                        horizontalAlignment: Text.AlignLeft
                    }
                    Text { 
                        text: " 前哨站血量"; 
                        font.pixelSize: 14; 
                        font.bold: true; 
                        color: (dataStore.globalUnit_enemy_outpost_health || 0) <= 0 ? "#ff3333" : "#ffffff";
                        horizontalAlignment: Text.AlignLeft
                    }
                    
                    // 血量条
                    Rectangle {
                        width: 100
                        height: 8
                        color: "#000055"
                        radius: 4
                        opacity: 0.8

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2  // 向外扩展一点，让边框更明显
                            color: "transparent"
                            border.color: "#ffd700"  // 金色
                            border.width: 2
                            radius: 8
                            visible: dataStore.globalUnit_enemy_outpost_status === 0
                            opacity: 0.8
                            
                            // 可选：添加呼吸动画效果
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: dataStore.globalUnit_enemy_outpost_status === 0
                                NumberAnimation { to: 1; duration: 800 }
                                NumberAnimation { to: 0.5; duration: 800 }
                            }
                        }

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: parent.width * (Math.min(dataStore.globalUnit_enemy_outpost_health || 0, 1500) / 1500)
                            color: "#00008b"
                            radius: 4
                        }
                    }
                    Text { 
                        text: " " + (dataStore.globalUnit_enemy_outpost_health || 0); 
                        font.pixelSize: 14; 
                        font.bold: true; 
                        color: "#ff3333";
                        horizontalAlignment: Text.AlignLeft
                    }
                }
            }

          
          
        }

        // 4. 右侧参数显示区域
        Column {
            
            x:crosshairItem.x+200
            y:crosshairItem.y-20
           
            spacing: 10
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
            
            // Text { text: "-------------------------"; font.pixelSize: 12; color: "#888888" }
        }

        // 5. 经济显示模块
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 240
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

                // 红方经济 - 注意：协议只提供己方经济，这里假设用remaining_economy显示红方
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
                        text: dataStore.globalLogistics_remaining_economy || 0;  // 使用己方剩余经济
                        font.pixelSize: 14; 
                        font.bold: true; 
                        color: "#ffffff";
                        horizontalAlignment: Text.AlignLeft 
                    }
                }

                // 科技等级显示
                Column {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 2
                    Text { 
                        text: "科技等级"; 
                        font.pixelSize: 10; 
                        color: "#ffff00"; 
                        horizontalAlignment: Text.AlignHCenter 
                    }
                    Text { 
                        text: "Lv." + (dataStore.globalLogistics_tech_level || 0);
                        font.pixelSize: 14; 
                        font.bold: true; 
                        color: "#ffffff";
                        horizontalAlignment: Text.AlignHCenter 
                    }
                }

                // 蓝方经济 - 协议中没有对方经济，这里暂时显示加密等级
                Column {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    spacing: 2
                    Text { 
                        text: "加密等级"; 
                        font.pixelSize: 10; 
                        color: "#2288ff"; 
                        horizontalAlignment: Text.AlignRight 
                    }
                    Text { 
                        text: (dataStore.globalLogistics_encryption_level || 1) + "/3";
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
    id: leftInfoPanel
    anchors.left: parent.left
    y: robotHealthManager.y+150
    anchors.margins: 20
    spacing: 10
    z: 999  // 提高层级，避免被遮挡

    // 系统面板
    Rectangle {
        width: 200
        height: 80
        color: "#00000080"  // 半透明黑（Qt全版本兼容）
        border.color: "#66666680"
        border.width: 1

        Text {
            // 锚点：填满父组件，留5px内边距
            anchors.fill: parent
            padding: 5
            // 文字样式（高对比度，确保能看到）
            font.pixelSize: 12
            color: "#FF0000"  // 纯红色（Qt全版本兼容的十六进制颜色）
            // 换行+垂直对齐
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignTop
            opacity: 1.0      // 强制不透明

            // 动态显示"系统：比赛状态"（简化逻辑，避免语法错误）
            text: {
                
               // 1. 获取比赛阶段值（强制设为4测试，后续恢复动态值）
                var stage = 4; 
                // 后续恢复为动态值：var stage = gameStatus_current_stage || 0;
                
                // 2. 获取当前阶段已过时间（秒）
                var elapsedSec = 50;
                //var elapsedSec = gameStatus_stage_elapsed_sec || 0;
                // 3. 格式化已过时间为 "x分xx秒"
                var minutes = Math.floor(elapsedSec / 60);
                var seconds = elapsedSec % 60;
                var secondsStr = seconds.toString().padStart(2, '0');
                var elapsedText = " 已过" + minutes + "分" + secondsStr + "秒";

                // 4. 匹配比赛阶段文字
                var stageText = "";
                if (stage === 0) stageText = "赛前准备阶段";
                else if (stage === 1) stageText = "准备阶段";
                else if (stage === 2) stageText = "十五秒裁判系统自检阶段";
                else if (stage === 3) stageText = "五秒倒计时";
                else if (stage === 4) stageText = "比赛中";
                else if (stage === 5) stageText = "比赛结算中";
                else if (stage === 6) stageText = "比赛暂停";
                else stageText = "未知状态（" + stage + "）";
                
                // 5. 拼接最终文字：系统：状态 + 已过时间
                return "系统：" + stageText + elapsedText;
            }
        }
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
        // 6.5 全局特殊机制显示
        Item {
            id: specialMechanismDisplay
            anchors.left: parent.left
            anchors.top: leftInfoPanel.bottom
            anchors.topMargin: 20 
            anchors.leftMargin: 20
            width: 200
            height: 80
            z: 11
            // visible: dataStore.globalSpecial_mechanism_id && dataStore.globalSpecial_mechanism_id.length > 0
            visible: true
            Rectangle {
                anchors.fill: parent
                color: "#00000080"
                border.color: "#ffaa00"
                border.width: 2
                radius: 5

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 5

                    Text {
                        text: "⚡ 特殊机制"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#ffaa00"
                    }

                    Repeater {
                        model: dataStore.globalSpecial_mechanism_id.length

                        Row {
                            spacing: 10
                            width: parent.width

                            Text {
                                text: {
                                    var id = dataStore.globalSpecial_mechanism_id[index] || 0;
                                    if (id === 1) return "🔴 己方堡垒被占";
                                    if (id === 2) return "🔵 对方堡垒被占";
                                    return "机制" + id;
                                }
                                font.pixelSize: 10
                                color: "#ffffff"
                                width: 100
                                elide: Text.ElideRight
                            }

                            Text {
                                text: (dataStore.globalSpecial_mechanism_time_sec[index] || 0) + "s"
                                font.pixelSize: 10
                                font.bold: true
                                color: {
                                    var time = dataStore.globalSpecial_mechanism_time_sec[index] || 0;
                                    if (time <= 10) return "#ff3333";
                                    if (time <= 30) return "#ffff00";
                                    return "#22ff22";
                                }
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: (dataStore.globalSpecial_mechanism_time_sec[index] || 0) <= 10
                                    NumberAnimation { to: 1; duration: 500 }
                                    NumberAnimation { to: 0.3; duration: 500 }
                                }
                            }
                        }
                    }
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
                anchors.rightMargin: 30
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
    id:zuo
    anchors.left: parent.left
    anchors.bottom: moduleStatusDisplay.top
    anchors.leftMargin: 20
    width: 320  // 再加宽一点以容纳更多信息
    height: 80  // 加高
    z: 11

    // 辅助函数：获取机器人类型文字
    function getRobotTypeText(type) {
        if (type === 1) return "英";
        if (type === 2) return "工";
        if (type === 3) return "步1";
        if (type === 4) return "步2";
        if (type === 5) return "哨";
        if (type === 6) return "飞";
        if (type === 7) return "雷";
        if (type === 8) return "前";
        if (type === 9) return "基";
        return "机";
    }

    // 辅助函数：获取发射性能文字
    function getShooterTypeText(shooter) {
        if (shooter === 1) return "冷却";
        if (shooter === 2) return "爆发";
        if (shooter === 3) return "近战";
        if (shooter === 4) return "远程";
        return shooter;
    }

    // 辅助函数：获取底盘性能文字
    function getChassisTypeText(chassis) {
        if (chassis === 1) return "血量";
        if (chassis === 2) return "功率";
        if (chassis === 3) return "近战";
        if (chassis === 4) return "远程";
        return chassis;
    }

    // 机器人图标
    Rectangle { 
        id: robotIcon
        width: 50; 
        height: 50; 
        radius: 25; 
        color: "#111111"; 
        border.color: "#666666"
        
        Text {
            anchors.centerIn: parent
            text: zuo.getRobotTypeText(dataStore.robotStatic_robot_type || 0)
            font.pixelSize: 16
            font.bold: true
            color: {
                let alive = dataStore.robotStatic_alive_state || 0;
                if (alive === 1) return "#22ff22";      // 存活
                if (alive === 2) return "#ff2222";      // 战亡
                return "#aaaaaa";                         // 未知/未连接
            }
        }
    }

    // 右侧信息区域
    Column {
        anchors.left: robotIcon.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        // 第一行：血量进度条 + 经验条
        Column {
            width: 240
            spacing: 2

            // 血量进度条
            Rectangle {
                width: parent.width/2
                height: 12
                color: "#222222"
                radius: 6
                border.color: "#444444"
                border.width: 1

                Rectangle { 
                    anchors.fill: parent; 
                    color: {
                        let currentHealth = dataStore.robotDynamic_current_health || 0;
                        let maxHealth = dataStore.robotStatic_max_health || 1;
                        let ratio = currentHealth / Math.max(1, maxHealth);
                        if (ratio > 0.5) return "#22ff22";
                        else if (ratio > 0.2) return "#ffff22";
                        else return "#ff2222";
                    }
                    radius: 6; 
                    width: Math.max(0, parent.width * (
                        (dataStore.robotDynamic_current_health || 0) / 
                        Math.max(1, dataStore.robotStatic_max_health || 1)
                    )) 
                }

                Text {
                    anchors.centerIn: parent
                    text: (dataStore.robotDynamic_current_health || 0) + "/" + 
                          (dataStore.robotStatic_max_health || 0)
                    font.pixelSize: 8
                    color: "white"
                }
            }

            // 经验条
            Rectangle {
                width: parent.width/2
                height: 5
                color: "#333333"
                radius: 3

                Rectangle {
                    anchors.fill: parent
                    color: "#ffaa00"
                    radius: 3
                    width: parent.width * Math.min(
                        (dataStore.robotDynamic_current_experience || 0) / 
                        Math.max(1, dataStore.robotDynamic_experience_for_upgrade || 1), 1
                    )
                }
            }
        }

        // 第二行：机器人ID、等级、连接状态、脱战状态
        Row {
            spacing: 10
            Text {
                text: "ID:" + (dataStore.clientID || 0)
                font.pixelSize: 9
                color: "#cccccc"
            }
            Text {
                text: "Lv." + (dataStore.robotStatic_level || 1)
                font.pixelSize: 9
                color: "#ffaa00"
            }
            Text {
                text: (dataStore.robotStatic_connection_state || 0) === 1 ? "●" : "○"
                font.pixelSize: 9
                color: (dataStore.robotStatic_connection_state || 0) === 1 ? "#22ff22" : "#ff4444"
            }
            Text {
                text: dataStore.robotDynamic_is_out_of_combat ? "脱战" : "战斗"
                font.pixelSize: 9
                color: dataStore.robotDynamic_is_out_of_combat ? "#22ff22" : "#ff9900"
                visible: dataStore.robotDynamic_is_out_of_combat !== undefined
            }
            Text {
                text: dataStore.robotDynamic_out_of_combat_countdown > 0 ? 
                      "⏱" + dataStore.robotDynamic_out_of_combat_countdown + "s" : ""
                font.pixelSize: 8
                color: "#88ccff"
                visible: dataStore.robotDynamic_out_of_combat_countdown > 0
            }
        }

        // 第三行：热量、射速、弹药
        Row {
            spacing: 10
            Text {
                text: "🔥" + (dataStore.robotDynamic_current_heat || 0).toFixed(0) + 
                      "/" + (dataStore.robotStatic_max_heat || 0)
                font.pixelSize: 9
                color: (dataStore.robotDynamic_current_heat || 0) > 
                       (dataStore.robotStatic_max_heat || 0) * 0.8 ? "#ff9900" : "#ffaa00"
            }
            Text {
                text: "⚡" + (dataStore.robotDynamic_last_projectile_fire_rate || 0).toFixed(1) + "Hz"
                font.pixelSize: 9
                color: "#88ccff"
            }
            Text {
                text: "🔫" + (dataStore.robotDynamic_remaining_ammo || 0)
                font.pixelSize: 9
                color: (dataStore.robotDynamic_remaining_ammo || 0) < 100 ? "#ff9900" : "#22ff22"
            }
        }

        // 第四行：能量、经验、远程状态
        Row {
            spacing: 10
            Text {
                text: "⚡" + (dataStore.robotDynamic_current_chassis_energy || 0) + 
                      "/" + (dataStore.robotStatic_max_chassis_energy || 0)
                font.pixelSize: 8
                color: "#aaaaaa"
            }
            Text {
                text: "🔋" + (dataStore.robotDynamic_current_buffer_energy || 0) + 
                      "/" + (dataStore.robotStatic_max_buffer_energy || 0)
                font.pixelSize: 8
                color: "#aaaaaa"
            }
            Text {
                text: "EXP:" + (dataStore.robotDynamic_current_experience || 0) + 
                      "/" + (dataStore.robotDynamic_experience_for_upgrade || 1)
                font.pixelSize: 8
                color: "#ffaa00"
            }
        }

        // 第五行：远程状态提示
        Row {
            spacing: 10
            Text {
                text: dataStore.robotDynamic_can_remote_heal ? "💊可补血" : ""
                font.pixelSize: 8
                color: "#22ff22"
                visible: dataStore.robotDynamic_can_remote_heal
            }
            Text {
                text: dataStore.robotDynamic_can_remote_ammo ? "📦可补弹" : ""
                font.pixelSize: 8
                color: "#22ff22"
                visible: dataStore.robotDynamic_can_remote_ammo
            }
            Text {
                text: "总弹:" + (dataStore.robotDynamic_total_projectiles_fired || 0)
                font.pixelSize: 8
                color: "#888888"
            }
            Text {
        text: "🟨黄:" + (penaltySystem.yellowCardTotal || 0)
        font.pixelSize: 8
        color: penaltySystem.yellowCardTotal > 0 ? "#FFD700" : "#888888"
        font.bold: penaltySystem.yellowCardTotal > 0
        visible: penaltySystem.yellowCardTotal > 0 || penaltySystem.redCardTotal > 0
    }
    // 红牌显示
    Text {
        text: "🟥红:" + (penaltySystem.redCardTotal || 0)
        font.pixelSize: 8
        color: penaltySystem.redCardTotal > 0 ? "#FF4444" : "#888888"
        font.bold: penaltySystem.redCardTotal > 0
        visible: penaltySystem.redCardTotal > 0
    }
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
        height: 90 // 加高
        z: 12
        
        // 控制框背景图片
        Image {
            anchors.fill: parent
            source: "qrc:/images/resources/控制框.png"
            fillMode: Image.Stretch
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
                    // 直接写表达式，QML 会自动建立对 dataStore 属性的监听
                    text: {
                        let btns = [];
                        if (dataStore.input_leftBtnDown) btns.push("左键");
                        if (dataStore.input_rightBtnDown) btns.push("右键");
                        if (dataStore.input_midBtnDown) btns.push("中键");
                        return btns.length > 0 ? "按下：" + btns.join(",") : "无按键按下";
                    }
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
// 12. 机器人复活状态面板（内联实现）
// ==============================================
Item {
    id: respawnPanel
    // 接收外部传入的数据
    property var dataStore: root.dataStore
    
    // 信号：点击复活按钮
    signal freeRespawnClicked()
    signal goldRespawnClicked()
    
    // 面板尺寸
    width: 400
    height: 220

    // 仅当处于待复活状态时显示
    //visible: dataStore.robotRespawn_is_pending_respawn || false
    visible: dataStore.robotRespawn_is_pending_respawn === true
    // 居中显示
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    z: 1000001  // 确保在最上层
    
    // 浅绿色荧光边背景
    Rectangle {
        anchors.fill: parent
        color: "#3300ff00"  // 半透明浅绿
        border.color: "#00ff00"
        border.width: 3
        radius: 15
        
        // 发光效果
        layer {
            enabled: true
            // effect: DropShadow {
            //     color: "#88ff00ff"
            //     radius: 20
            //     samples: 41
            //     spread: 0.2
            // }
        }
    }
    
    // 主内容区域
    Rectangle {
        anchors.fill: parent
        anchors.margins: 5
        color: "#222222"
        radius: 12
        border.color: "#444444"
        border.width: 1
        
        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            // 标题
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "💀 机器人待复活"
                font.pixelSize: 18
                font.bold: true
                color: "#ffffff"
            }
            
            // 复活进度条
            Column {
                width: parent.width
                spacing: 5
                
                Text {
                    text: "复活进度: " + (dataStore.robotRespawn_current_respawn_progress || 0) + 
                          "/" + (dataStore.robotRespawn_total_respawn_progress || 100)
                    font.pixelSize: 12
                    color: "#cccccc"
                }
                
                Rectangle {
                    width: parent.width
                    height: 20
                    color: "#333333"
                    radius: 10
                    border.color: "#555555"
                    border.width: 1
                    
                    Rectangle {
                        width: parent.width * (Math.min(dataStore.robotRespawn_current_respawn_progress || 0, 
                                                       dataStore.robotRespawn_total_respawn_progress || 100) / 
                                              (dataStore.robotRespawn_total_respawn_progress || 100))
                        height: parent.height
                        color: "#22ff22"
                        radius: 10
                        
                        // 进度条动画
                        Behavior on width {
                            NumberAnimation { duration: 200 }
                        }
                    }
                }
            }
            
            // 复活选项
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20
                
                // 免费复活按钮
                Button {
                    id: freeBtn
                    width: 120
                    height: 50
                    enabled: dataStore.robotRespawn_can_free_respawn || false
                    
                    background: Rectangle {
                        color: freeBtn.enabled ? "#22ff22" : "#555555"
                        opacity: freeBtn.enabled ? 0.8 : 0.4
                        radius: 8
                        border.color: freeBtn.enabled ? "#ffffff" : "#888888"
                        border.width: freeBtn.enabled ? 2 : 1
                        
                        // 启用时发光效果
                        layer {
                            enabled: freeBtn.enabled
                            // effect: DropShadow {
                            //     color: "#88ff00ff"
                            //     radius: 10
                            //     samples: 21
                            //     spread: 0.3
                            // }
                        }
                    }
                    
                    contentItem: Column {
                        anchors.centerIn: parent
                        spacing: 2
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "免费复活"
                            color: freeBtn.enabled ? "#000000" : "#888888"
                            font.pixelSize: 14
                            font.bold: true
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: freeBtn.enabled ? "可用" : "不可用"
                            color: freeBtn.enabled ? "#000000" : "#888888"
                            font.pixelSize: 10
                        }
                    }
                    
                    onClicked: {
                        if (freeBtn.enabled) {
                            // 显示确认提示
                            confirmationPopup.show("确认免费复活？", "free")
                        }
                    }
                }
                
                // 金币复活按钮
                Button {
                    id: goldBtn
                    width: 120
                    height: 50
                    enabled: dataStore.robotRespawn_can_pay_for_respawn || false
                    
                    background: Rectangle {
                        color: goldBtn.enabled ? "#ffaa00" : "#555555"
                        opacity: goldBtn.enabled ? 0.8 : 0.4
                        radius: 8
                        border.color: goldBtn.enabled ? "#ffffff" : "#888888"
                        border.width: goldBtn.enabled ? 2 : 1
                        
                        // 启用时发光效果
                        layer {
                            enabled: goldBtn.enabled
                            // effect: DropShadow {
                            //     color: "#88ffaa00"
                            //     radius: 10
                            //     samples: 21
                            //     spread: 0.3
                            // }
                        }
                    }
                    
                    contentItem: Column {
                        anchors.centerIn: parent
                        spacing: 2
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "金币复活"
                            color: goldBtn.enabled ? "#000000" : "#888888"
                            font.pixelSize: 14
                            font.bold: true
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: goldBtn.enabled ? 
                                  "消耗 " + (dataStore.robotRespawn_gold_cost_for_respawn || 0) + " 金币" : 
                                  "金币不足"
                            color: goldBtn.enabled ? "#000000" : "#888888"
                            font.pixelSize: 10
                        }
                    }
                    
                    onClicked: {
                        if (goldBtn.enabled) {
                            // 显示确认提示
                            confirmationPopup.show("确认消耗 " + (dataStore.robotRespawn_gold_cost_for_respawn || 0) + " 金币复活？", "gold")
                        }
                    }
                }
            }
            
            // 状态提示
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (dataStore.robotRespawn_is_pending_respawn) {
                        if (dataStore.robotRespawn_can_free_respawn) return "✨ 可以免费复活"
                        if (dataStore.robotRespawn_can_pay_for_respawn) return "💰 可以用金币复活"
                        return "⏳ 等待复活条件..."
                    }
                    return ""
                }
                font.pixelSize: 12
                color: {
                    if (dataStore.robotRespawn_can_free_respawn) return "#22ff22"
                    if (dataStore.robotRespawn_can_pay_for_respawn) return "#ffaa00"
                    return "#ff6666"
                }
            }
        }
    }
    
    // 确认弹窗
    Popup {
        id: confirmationPopup
        width: 300
        height: 150
        anchors.centerIn: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        property string actionType: ""  // "free" 或 "gold"
        
        function show(message, type) {
            confirmMessage.text = message
            actionType = type
            open()
        }
        
        background: Rectangle {
            color: "#333333"
            radius: 10
            border.color: "#00ff00"
            border.width: 2
        }
        
        contentItem: Column {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 15
            
            Text {
                id: confirmMessage
                width: parent.width
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
            }
            
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20
                
                Button {
                    text: "确认"
                    width: 80
                    height: 35
                    
                    background: Rectangle {
                        color: "#22ff22"
                        radius: 5
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#000000"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        if (confirmationPopup.actionType === "free") {
                            respawnPanel.freeRespawnClicked()
                        } else if (confirmationPopup.actionType === "gold") {
                            respawnPanel.goldRespawnClicked()
                        }
                        confirmationPopup.close()
                        
                        // 显示操作成功提示
                        successToast.show("复活请求已发送")
                    }
                }
                
                Button {
                    text: "取消"
                    width: 80
                    height: 35
                    
                    background: Rectangle {
                        color: "#ff3333"
                        radius: 5
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: confirmationPopup.close()
                }
            }
        }
    }
    
    // 成功提示（短暂显示）
    Popup {
        id: successToast
        width: 200
        height: 50
        anchors.centerIn: Overlay.overlay
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose
        
        function show(message) {
            toastText.text = message
            open()
            hideTimer.start()
        }
        
        Timer {
            id: hideTimer
            interval: 1500
            onTriggered: successToast.close()
        }
        
        background: Rectangle {
            color: "#333333"
            radius: 8
            border.color: "#22ff22"
            border.width: 2
        }
        
        contentItem: Text {
            id: toastText
            anchors.centerIn: parent
            color: "#ffffff"
            font.pixelSize: 14
        }
    }
    
    // 信号处理
    onFreeRespawnClicked: {
        console.log("免费复活点击")
        // TODO: 调用 C++ 的免费复活接口
    }
    
    onGoldRespawnClicked: {
        console.log("金币复活点击，消耗:", dataStore.robotRespawn_gold_cost_for_respawn)
        // TODO: 调用 C++ 的金币复活接口
    }
}

// ======================================================
// 战术雷达图层 (Tactical Radar Layer) - 2026 深度定制版
// 适配协议：RobotPosition(12), RobotPathPlanInfo(15), RadarInfoToClient(16)
// ======================================================
// ======================================================
// 战术雷达图层 (Tactical Radar Layer) - 实战高亮轨迹版
// ------------------------------------------------------
// 视觉策略：机器人圆点采用深色系(压场)，规划轨迹采用亮色系(导引)
// 适配协议：RobotPosition(13), RobotPathPlanInfo(16), RadarInfoToClient(18)
// ======================================================
Item {
    id: radarOverlay
    x: miniMap.x; y: miniMap.y
    width: miniMap.width; height: miniMap.height
    z: 20; clip: true 

    readonly property int dotSize: 14      
    readonly property real fieldW: 28.0    
    readonly property real fieldH: 15.0 
    // 1. 定义一个 ListModel，这是 QML 动态重绘最稳的方式
    ListModel { id: robotListModel }   

    function toX(mX) { return mX * (radarOverlay.width / radarOverlay.fieldW) }
    function toY(mY) { return radarOverlay.height - (mY * (radarOverlay.height / radarOverlay.fieldH)) }

    function getRobotName(fullId) {
        var base = fullId > 100 ? fullId - 100 : fullId;
        var names = {1:"英", 2:"工", 3:"步", 4:"步", 5:"步", 6:"空", 7:"哨", 8:"镖", 9:"雷"};
        return names[base] || "";
    }

    // -------------------------------------------------------------------
    // 1. 自身位置 [Message 13] - 深绿色圆点
    // -------------------------------------------------------------------
    Item {
        id: selfMarker
        x: radarOverlay.toX(dataStore.robotPosition_x)
        y: radarOverlay.toY(dataStore.robotPosition_y)
        visible: dataStore.robotPosition_x !== 0

        Canvas {
            width: 24; height: 24; anchors.centerIn: parent
            rotation: dataStore.robotPosition_yaw 
            onPaint: {
                var ctx = getContext("2d"); ctx.reset(); ctx.fillStyle = "white";
                ctx.beginPath(); ctx.moveTo(12, 0); ctx.lineTo(19, 10); 
                ctx.lineTo(12, 10); ctx.lineTo(5, 10); ctx.closePath(); ctx.fill();
            }
        }

        Rectangle {
            width: radarOverlay.dotSize; height: radarOverlay.dotSize; radius: width/2
            color: "#004d00"; // 深森林绿
            border.color: "white"; border.width: 1.5; anchors.centerIn: parent
            Text {
                text: radarOverlay.getRobotName(dataStore.clientID)
                color: "white"; font.pixelSize: 9; font.bold: true; anchors.centerIn: parent
            }
        }
    }

    // -------------------------------------------------------------------
    // 2. 哨兵轨迹 [Message 16] - 亮色轨迹线 + 深色位置点
    // -------------------------------------------------------------------
    Canvas {
        id: pathLayer
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d"); ctx.reset();
            var curX = dataStore.robotPath_start_pos_x / 10.0;
            var curY = dataStore.robotPath_start_pos_y / 10.0;
            var dxs = dataStore.robotPath_offset_x;
            var dys = dataStore.robotPath_offset_y;
            if (!dxs || dxs.length === 0) return;

            // 轨迹采用【亮色系】：1-鲜红(攻), 2-亮绿(防), 3-明黄(移)
            var intent = dataStore.robotPath_intention;
            var pathColor = (intent === 1) ? "#FF0000" : (intent === 2 ? "#00FF00" : "#FFFF00");

            ctx.strokeStyle = pathColor; ctx.lineWidth = 2.5;
            ctx.shadowColor = pathColor; ctx.shadowBlur = 4; // 增加微弱发光感，提升引导视觉
            ctx.beginPath();
            ctx.moveTo(radarOverlay.toX(curX), radarOverlay.toY(curY));
            for (var i = 0; i < dxs.length; i++) {
                curX += dxs[i] / 10.0; curY += dys[i] / 10.0;
                ctx.lineTo(radarOverlay.toX(curX), radarOverlay.toY(curY));
            }
            ctx.stroke();
        }

        Item {
            x: radarOverlay.toX(dataStore.robotPath_start_pos_x / 10.0)
            y: radarOverlay.toY(dataStore.robotPath_start_pos_y / 10.0)
            visible: dataStore.robotPath_sender_id !== 0

            // 箭头朝向：完全对齐首段轨迹矢量
            Canvas {
                width: 24; height: 24; anchors.centerIn: parent
                visible: dataStore.robotPath_offset_x && dataStore.robotPath_offset_x.length > 0
                rotation: Math.atan2(dataStore.robotPath_offset_x[0], dataStore.robotPath_offset_y[0]) * 180 / Math.PI
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset(); ctx.fillStyle = "white";
                    ctx.beginPath(); ctx.moveTo(12, 0); ctx.lineTo(19, 10); 
                    ctx.lineTo(12, 10); ctx.lineTo(5, 10); ctx.closePath(); ctx.fill();
                }
            }

            Rectangle {
                width: radarOverlay.dotSize; height: radarOverlay.dotSize; radius: width/2
                // 机器人本体圆点依然保持【深色系】
                color: dataStore.robotPath_sender_id < 100 ? "#660000" : "#003366"
                border.color: "white"; border.width: 1.5; anchors.centerIn: parent
                Text { text: "哨"; color: "white"; font.pixelSize: 9; font.bold: true; anchors.centerIn: parent }
            }
        }
        
        Connections {
            target: dataStore
            function onRobotPath_offset_xChanged() { pathLayer.requestPaint() }
        }
    }

    // -------------------------------------------------------------------
   // -------------------------------------------------------------------
    // -------------------------------------------------------------------
    // 3. 全场动态机器人信息 - 彻底修复朝向版
    // -------------------------------------------------------------------
    Repeater {
        model: robotListModel
        delegate: Item {
            // 绑定 model 属性
            readonly property real mPosX: model.posX
            readonly property real mPosY: model.posY
            readonly property real mAngle: model.angle
            readonly property int mRid: model.robotId
            readonly property int mHl: model.isHighLight

            x: radarOverlay.toX(mPosX)
            y: radarOverlay.toY(mPosY)
            z: 20

            // 彻底修复：将旋转逻辑写进 Canvas 内部
            Canvas {
                id: robotArrow
                width: 24; height: 24; anchors.centerIn: parent
                
                // 关键点 1：显式绑定数据源的角度
                property real currentAngle: mAngle
                
                // 关键点 2：监听角度变化强制重绘
                onCurrentAngleChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    
                    // 关键点 3：在绘图层进行坐标变换
                    ctx.save();
                    ctx.translate(12, 12); // 移到中心
                    ctx.rotate(currentAngle * Math.PI / 180); // 弧度转换
                    ctx.translate(-12, -12); // 移回去
                    
                    ctx.fillStyle = "white";
                    ctx.beginPath();
                    ctx.moveTo(12, 0);   // 顶点
                    ctx.lineTo(19, 10);  // 右翼
                    ctx.lineTo(12, 10);  // 尾部凹陷点
                    ctx.lineTo(5, 10);   // 左翼
                    ctx.closePath();
                    ctx.fill();
                    ctx.restore();
                }
            }

            Rectangle {
                width: radarOverlay.dotSize; height: radarOverlay.dotSize; radius: width/2
                color: mRid < 100 ? "#660000" : "#003366"
                border.color: mHl >= 1 ? "#FFFF00" : "white"
                border.width: mHl >= 1 ? 2.5 : 1.5
                anchors.centerIn: parent
                Text {
                    text: radarOverlay.getRobotName(mRid)
                    color: "white"; font.pixelSize: 9; font.bold: true; anchors.centerIn: parent
                }
            }
        }
    }

    // --- 数据源处理核心 (必须包含这一段监听) ---
    Connections {
        target: dataStore
        function updateRobotData() {
            var rid = dataStore.radar_target_robot_id;
            if (rid === 0) return;

            var found = false;
            for (var i = 0; i < robotListModel.count; i++) {
                if (robotListModel.get(i).robotId === rid) {
                    robotListModel.setProperty(i, "posX", dataStore.radar_target_pos_x);
                    robotListModel.setProperty(i, "posY", dataStore.radar_target_pos_y);
                    // 确保 angle 真的被写入了
                    robotListModel.setProperty(i, "angle", dataStore.radar_toward_angle);
                    robotListModel.setProperty(i, "isHighLight", dataStore.radar_is_high_light);
                    found = true;
                    break;
                }
            }

            if (!found) {
                robotListModel.append({
                    "robotId": rid,
                    "posX": dataStore.radar_target_pos_x,
                    "posY": dataStore.radar_target_pos_y,
                    "angle": dataStore.radar_toward_angle,
                    "isHighLight": dataStore.radar_is_high_light
                });
            }
        }

        // 关键点 4：除了坐标，还要监听角度信号变化
        function onRadar_target_pos_xChanged() { updateRobotData() }
        function onRadar_target_pos_yChanged() { updateRobotData() }
        function onRadar_toward_angleChanged() { updateRobotData() }
    }
}// 19. 自定义数据流显示面板 (独立 Item)
Rectangle {
    id: customByteBlockPanel
    x:specialMechanismDisplay.x;
    y:specialMechanismDisplay.y+140;
    width: specialMechanismDisplay.width;
    height: specialMechanismDisplay.height;
    z:999;
    clip: true 
    color: "#AA000000" // 半透明黑色背景
    border.color: "#00FFCC" // 使用青色边框增强识别度
    border.width: 1
    
    radius: 4

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // 标题栏
        Row {
            spacing: 5
            Rectangle {
                width: 3; height: 12; color: "#00FFCC"; anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "自定义数据流 (0x0310)"
                color: "#00FFCC"
                font.pixelSize: 12
                font.bold: true
            }
        }

        // 分割线
        Rectangle {
            width: parent.width
            height: 1
            color: "#33FFFFFF"
        }

        // 数据展示区
        ScrollView {
            width: parent.width
            height: 70
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Text {
                width: parent.width
                // 绑定 Main.qml 中 dataStore 的属性
                text: dataStore.customByteBlock_data !== "" ? dataStore.customByteBlock_data : "无实时数据..."
                color: dataStore.customByteBlock_data !== "" ? "#FFFFFF" : "#666666"
                font.pixelSize: 11
                font.family: "Consolas" // 使用等宽字体方便观察二进制位
                wrapMode: Text.WrapAnywhere // 允许在任何地方换行以适应宽度
                lineHeight: 1.2
            }
        }
    }
    
    // 右下角显示频率提示
    Text {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 4
        text: "50Hz"
        font.pixelSize: 9
        color: "#44FFFFFF"
    }
}
// =============================================
    // 14. 判罚系统（严格参考事件队列逻辑，修复发送过快不显示问题）
    // =============================================
    Item {
        id: penaltySystem
        anchors.fill: parent
        z: 2000000 

        // --- 核心属性 ---
        property var penaltyQueue: []
        property bool isShowing: false
        
        // 累计数值（常驻显示用）
        property int yellowCardTotal: 0
        property int redCardTotal: 0

        // 1. 处理新数据入队
        function handleNewPenalty(pType, pSec, pNum) {
            if (pType <= 0) return;

            // 更新左下角面板数值
            if (pType === 1 || pType === 2) yellowCardTotal = pNum;
            else if (pType === 3) redCardTotal = pNum;

            // 创建独立对象入队
            var info = {
                type: pType,
                sec: pSec,
                num: pNum,
                timestamp: new Date().getTime()
            };
            
            penaltyQueue.push(info);
            console.log("[判罚系统] 收到新数据，当前队列长度:", penaltyQueue.length);
            
            // 如果当前没在显示，则触发显示逻辑
            if (!isShowing) {
                showNextPenalty();
            }
        }

        // 2. 显示下一个判罚 (逻辑同事件通知)
        function showNextPenalty() {
            if (penaltyQueue.length === 0) {
                isShowing = false;
                penaltyPopup.visible = false;
                return;
            }

            isShowing = true;
            var current = penaltyQueue[0]; // 只看，先不删

            // 更新弹窗内容
            popupTitle.text = getPenaltyTitle(current.type);
            popupDesc.text = "持续时间: " + (current.sec === 0 ? "直至比赛结束" : current.sec + "s") + 
                            " | 当前累计次数: " + current.num;
            
            penaltyPopup.visible = true;
            
            // 启动动画序列
            penaltyShowAnimation.start();
        }

        // 3. 完成当前显示 (由动画结束时调用)
        function finishCurrentPenalty() {
            if (penaltyQueue.length > 0) {
                penaltyQueue.shift(); // 此时才弹出队列
            }
            
            penaltyPopup.visible = false;
            
            if (penaltyQueue.length > 0) {
                // 使用 Timer 短暂延迟，防止动画状态机冲突
                nextPenaltyTimer.start();
            } else {
                isShowing = false;
            }
        }

        // 辅助：延迟触发器
        Timer {
            id: nextPenaltyTimer
            interval: 50
            repeat: false
            onTriggered: penaltySystem.showNextPenalty()
        }

        function getPenaltyTitle(type) {
            switch(type) {
                case 1: return "黄牌警告"; case 2: return "双方黄牌";
                case 3: return "红牌罚下"; case 4: return "底盘超功率";
                case 5: return "机构超热量"; case 6: return "射击超频率";
                default: return "违规判罚";
            }
        }

        // 监听 C++ 信号
        Connections {
            target: penaltyInfoHandler 
            function onPenaltyInfoUpdated(map) {
                if (!map) return;
                var pType = map.penalty_type || 0;
                var pSec = map.penalty_effect_sec || 0;
                var pNum = map.total_penalty_num || 0;
                if (pType > 0) {
                    penaltySystem.handleNewPenalty(pType, pSec, pNum);
                }
            }
        }

        // ========== UI A: 弹窗部分 ==========
        Item {
            id: penaltyPopup
            anchors.fill: parent
            visible: false
            opacity: 0

            Rectangle { anchors.fill: parent; color: "#AA000000" }

            Item {
                width: 800; height: 500; anchors.centerIn: parent
                Image {
                    source: "qrc:images/resources/判罚.png"
                    anchors.fill: parent; fillMode: Image.PreserveAspectFit; opacity: 0.8
                }
                Column {
                    anchors.centerIn: parent; spacing: 30; width: parent.width
                    Text {
                        id: popupTitle
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        color: Qt.rgba(1.0, 0.8, 0.8, 0.7); font.pixelSize: 72; font.bold: true
                        style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.5)
                    }
                    Text {
                        id: popupDesc
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        color: Qt.rgba(1.0, 0.8, 0.8, 0.6); font.pixelSize: 26; font.bold: true
                        style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.4)
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 100; width: 400; height: 4; radius: 2; color: "#22FFFFFF"
                Rectangle {
                    id: penaltyProgressBar
                    height: parent.height; radius: 2; color: "#FFCCCC"; opacity: 0.6; width: 0
                }
            }

            // 核心动画序列：严格模仿事件通知的逻辑执行顺序
            SequentialAnimation {
                id: penaltyShowAnimation
                
                // 1. 淡入
                NumberAnimation { target: penaltyPopup; property: "opacity"; from: 0; to: 1; duration: 250 }
                
                // 2. 进度条与停留
                PropertyAnimation { 
                    target: penaltyProgressBar; property: "width"; 
                    from: 400; to: 0; duration: 2000 
                }
                
                // 3. 淡出
                NumberAnimation { target: penaltyPopup; property: "opacity"; from: 1; to: 0; duration: 250 }
                
                // 4. 触发完成回调
                ScriptAction {
                    script: penaltySystem.finishCurrentPenalty()
                }
            }
        }

        // // ========== UI B: 左下角常驻面板 ==========
        // Rectangle {
        //     id: counterPanel
        //     anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 30
        //     width: 170; height: 65; color: "#66000000"; radius: 8; border.color: "#33FFFFFF"
        //     Column {
        //         anchors.centerIn: parent; spacing: 6
        //         Row {
        //             spacing: 10
        //             Rectangle { width: 12; height: 16; color: "#FFD700"; radius: 2; anchors.verticalCenter: parent.verticalCenter }
        //             Text {
        //                 text: "累计黄牌: " + penaltySystem.yellowCardTotal
        //                 color: Qt.rgba(1.0, 0.8, 0.8, 0.8); font.pixelSize: 16; font.bold: true
        //             }
        //         }
        //         Row {
        //             spacing: 10
        //             Rectangle { width: 12; height: 16; color: "#FF4444"; radius: 2; anchors.verticalCenter: parent.verticalCenter }
        //             Text {
        //                 text: "累计红牌: " + penaltySystem.redCardTotal
        //                 color: Qt.rgba(1.0, 0.8, 0.8, 0.8); font.pixelSize: 16; font.bold: true
        //             }
        //         }
        //     }
        // }
    }
// ========== 独立的工程装配指令模块（右上角） ==========
Item {
    id: assemblyOverlay
    anchors.fill: parent
    // 逻辑判定：仅在机器人ID为 2 (红方工程) 或 102 (蓝方工程) 时显示
    visible: dataStore.clientID === 2 || dataStore.clientID === 102
    z: 1000 // 确保层级在最上方

    Rectangle {
        id: assemblyPanel
        // 定位到右上角，避开可能的退出/最小化按钮区域
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 150
        anchors.rightMargin: 20
        
        width: 220
        height: 120
        color: "#CC111111" // 深色半透明背景
        radius: 8
        border.color: "#44FFFFFF"
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // 标题与状态指示
            RowLayout {
                width: parent.width
                Text {
                    text: "工程装配控制"
                    color: "#00EBFF"
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                }
                // 状态指示小灯
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: dataStore.mqttSend_assemblyOperation === 1 ? "#00FF00" : "#555555"
                }
            }

            // 难度选择 (1-4)
            Row {
                spacing: 4
                property var levels: ["简单", "中等", "困难", "专家"]
                Repeater {
                    model: 4
                    Button {
                        width: 45; height: 26
                        enabled: dataStore.mqttSend_assemblyOperation !== 1 // 装配中禁止修改难度
                        
                        background: Rectangle {
                            color: dataStore.mqttSend_assemblyDifficulty === (modelData + 1) ? "#00EBFF" : "#333333"
                            radius: 3
                            opacity: parent.enabled ? 1.0 : 0.5
                        }

                        contentItem: Text {
                            text: parent.parent.levels[modelData]
                            color: dataStore.mqttSend_assemblyDifficulty === (modelData + 1) ? "black" : "white"
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: dataStore.mqttSend_assemblyDifficulty = modelData + 1
                    }
                }
            }

            // 操作按钮切换逻辑
            RowLayout {
                width: parent.width
                spacing: 8

                // 确认/装配中 按钮
                Button {
                    Layout.fillWidth: true
                    height: 35
                    // 状态切换文字：如果操作码为1，显示“装配中...”，否则显示“确认装配”
                    text: dataStore.mqttSend_assemblyOperation === 1 ? "装配中..." : "确认装配"
                    
                    background: Rectangle {
                        // 装配中变为深绿色，正常为明亮绿
                        color: dataStore.mqttSend_assemblyOperation === 1 ? "#155724" : "#28a745"
                        radius: 4
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (dataStore.mqttSend_assemblyOperation !== 1) {
                            dataStore.mqttSend_assemblyOperation = 1
                            console.log("[Assembly] 开始装配，难度: " + dataStore.mqttSend_assemblyDifficulty)
                        }
                    }
                }

                // 取消按钮
                Button {
                    width: 60; height: 35
                    text: "取消"
                    // 只有在装配状态下，取消按钮才高亮，否则半透明
                    opacity: dataStore.mqttSend_assemblyOperation === 1 ? 1.0 : 0.6
                    
                    background: Rectangle {
                        color: "#dc3545"
                        radius: 4
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        dataStore.mqttSend_assemblyOperation = 2 // 发送取消指令
                        console.log("[Assembly] 已取消装配任务")
                    }
                }
            }
        }
    }
}
// ========== 科技核心状态同步面板 (独立 Item - X/Y 绝对定位版) ==========
Item {
    id: techCoreSyncOverlay
    // 逻辑判定：仅在机器人ID为 2 (红方工程) 或 102 (蓝方工程) 时显示
    visible: dataStore.clientID === 2 || dataStore.clientID=== 102
    z: 1001 

    // --- 核心定位逻辑：利用 id.属性 显式绑定 ---
    // 横向与装配控制面板对齐
    x: assemblyPanel.x
    // 纵向位于装配控制面板上方，间距 8 像素
    y: assemblyPanel.y - height - 8
    
    width: 220
    height: 95 // 增加高度以展示所有协议字段

    // --- 内部逻辑函数 ---
    function getStatusText(status) {
        var map = {
            1: "未进入装配状态",
            2: "核心前往装配位...",
            3: "就绪 (可开始首步)",
            4: "步骤完成 (待下步)",
            5: "装配成功 ✅",
            6: "任务结束 (返回中)"
        };
        return map[status] || "未知状态";
    }

    function getStatusColor(status) {
        if (status === 5) return "#00FF00"; // 成功绿
        if (status === 2 || status === 6) return "#00EBFF"; // 移动蓝
        if (status === 3 || status === 4) return "#FFD700"; // 交互黄
        return "#666666"; // 初始灰
    }

    Rectangle {
        anchors.fill: parent
        color: "#E6111111" 
        radius: 8
        border.color: "#3300EBFF" 
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5

            // 第一行：标题与状态灯
            RowLayout {
                width: parent.width
                Text {
                    text: "科技核心状态同步"
                    color: "#888888"
                    font.pixelSize: 10
                }
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: techCoreSyncOverlay.getStatusColor(dataStore.techCore_status)
                    SequentialAnimation on opacity {
                        running: dataStore.techCore_status >= 2 && dataStore.techCore_status <= 4
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.2; duration: 600 }
                        NumberAnimation { from: 0.2; to: 1.0; duration: 600 }
                    }
                }
            }

            // 第二行：当前状态文字 (status)
            Text {
                text: techCoreSyncOverlay.getStatusText(dataStore.techCore_status)
                color: "#00EBFF"
                font.pixelSize: 14
                font.bold: true
            }

            // 第三行：最高难度 & 敌方状态 (maximum_difficulty_level & enemy_core_status)
            Row {
                spacing: 15
                Text { 
                    text: "最高难度: Lvl." + dataStore.techCore_maximum_difficulty_level
                    color: "#FFFFFF"; font.pixelSize: 10 
                }
                Text { 
                    text: "敌方: " + (["无装配", "非4级", "4级"][dataStore.techCore_enemy_core_status] || "未知")
                    color: dataStore.techCore_enemy_core_status === 2 ? "#FF4444" : "#AAAAAA"
                    font.pixelSize: 10
                    font.bold: dataStore.techCore_enemy_core_status === 2
                }
            }

            // 第四行：时间信息 (remain_time_all & remain_time_step)
            // 仅在己方进行四级装配（有剩余时间）时可见
            Row {
                visible: dataStore.techCore_remain_time_all > 0
                spacing: 12
                Rectangle {
                    width: 80; height: 16; color: "#33FFD700"; radius: 2
                    Text {
                        anchors.centerIn: parent
                        text: "总计: " + dataStore.techCore_remain_time_all + "s"
                        color: "#FFD700"; font.pixelSize: 10; font.bold: true
                    }
                }
                Rectangle {
                    width: 80; height: 16; color: "#33FF4444"; radius: 2
                    Text {
                        anchors.centerIn: parent
                        text: "步余: " + dataStore.techCore_remain_time_step + "s"
                        color: "#FF4444"; font.pixelSize: 10; font.bold: true
                    }
                }
            }
        }
    }
}
// ========== 步兵/英雄/哨兵性能体系面板 (右上角 - 修复逻辑版) ==========
Item {
    id: perfSelectionOverlay
    anchors.fill: parent
    // 逻辑判定：步兵(3,4,5 / 103,104,105)、英雄(1,101)、哨兵(7,107)
    property var validIds: [1, 3, 4, 5, 7, 101, 103, 104, 105, 107]
    visible: validIds.indexOf(dataStore.clientID) !== -1
    z: 1001

    // 内部临时变量：初始值设为-1，确保第一次加载时能从Sync同步
    property int tempShooter: -1
    property int tempChassis: -1
    property int tempSentry: -1

    // 当面板打开或Sync数据变化且用户还没改时，同步一次数据
    // 注意：这里用简单的赋值，不要用属性绑定
    onVisibleChanged: {
        if (visible) {
            tempShooter = dataStore.robotPerfSync_shooter
            tempChassis = dataStore.robotPerfSync_chassis
            tempSentry = dataStore.robotPerfSync_sentry_control
        }
    }

    Rectangle {
        id: perfPanel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 200 
        anchors.rightMargin: 20
        width: 260
        height: isSentry ? 330 : 260 
        color: "#E61A1A1A"
        radius: 8
        border.color: "#66FFFFFF"
        border.width: 1

        property bool isSentry: dataStore.clientID=== 7 || dataStore.clientID=== 107
        
        // 【核心逻辑修复】：显式判断是否有任何一项不同
        // 使用具体的 ID 路径确保 QML 引擎能追踪到每一次点击变化
        property bool hasRealChanges: {
            var sDiff = (perfSelectionOverlay.tempShooter !== dataStore.robotPerfSync_shooter);
            var cDiff = (perfSelectionOverlay.tempChassis !== dataStore.robotPerfSync_chassis);
            var nDiff = isSentry ? (perfSelectionOverlay.tempSentry !== dataStore.robotPerfSync_sentry_control) : false;
            return sDiff || cDiff || nDiff;
        }

        Column {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 12

            Text {
                text: "性能体系配置 (蓝框为当前)"
                color: "#FFD700"; font.pixelSize: 14; font.bold: true
            }

            // 1. 发射机构 (Shooter)
            Column {
                spacing: 4; width: parent.width
                Text { text: "发射体系:"; color: "#AAAAAA"; font.pixelSize: 10 }
                Row {
                    spacing: 4
                    Repeater {
                        model: ["冷却", "爆发", "近战", "远程"]
                        Button {
                            width: 54; height: 28
                            background: Rectangle {
                                // 黄色代表你准备改成的
                                color: (perfSelectionOverlay.tempShooter === index + 1) ? "#FFD700" : "#333333"
                                radius: 4
                                // 蓝色框代表服务器现在的
                                border.color: (dataStore.robotPerfSync_shooter === index + 1) ? "#00EBFF" : "transparent"
                                border.width: 2
                            }
                            contentItem: Text { 
                                text: modelData
                                color: (perfSelectionOverlay.tempShooter === index + 1) ? "black" : "white"
                                font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter 
                            }
                            onClicked: perfSelectionOverlay.tempShooter = index + 1
                        }
                    }
                }
            }

            // 2. 底盘 (Chassis)
            Column {
                spacing: 4; width: parent.width
                Text { text: "底盘体系:"; color: "#AAAAAA"; font.pixelSize: 10 }
                Row {
                    spacing: 4
                    Repeater {
                        model: ["血量", "功率", "近战", "远程"]
                        Button {
                            width: 54; height: 28
                            background: Rectangle {
                                color: (perfSelectionOverlay.tempChassis === index + 1) ? "#FFD700" : "#333333"
                                radius: 4
                                border.color: (dataStore.robotPerfSync_chassis === index + 1) ? "#00EBFF" : "transparent"
                                border.width: 2
                            }
                            contentItem: Text { 
                                text: modelData
                                color: (perfSelectionOverlay.tempChassis === index + 1) ? "black" : "white"
                                font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter 
                            }
                            onClicked: perfSelectionOverlay.tempChassis = index + 1
                        }
                    }
                }
            }

            // 3. 哨兵控制 (仅哨兵显示)
            Column {
                visible: perfPanel.isSentry
                spacing: 4; width: parent.width
                Text { text: "哨兵模式:"; color: "#AAAAAA"; font.pixelSize: 10 }
                Row {
                    spacing: 4
                    Repeater {
                        model: ["自动", "半自动"]
                        Button {
                            width: 112; height: 28
                            background: Rectangle {
                                color: (perfSelectionOverlay.tempSentry === index) ? "#FFD700" : "#333333"
                                radius: 4
                                border.color: (dataStore.robotPerfSync_sentry_control === index) ? "#00EBFF" : "transparent"
                                border.width: 2
                            }
                            contentItem: Text { 
                                text: modelData
                                color: (perfSelectionOverlay.tempSentry === index) ? "black" : "white"
                                font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter 
                            }
                            onClicked: perfSelectionOverlay.tempSentry = index
                        }
                    }
                }
            }

            // --- 确认发送按钮 (始终显示，根据 hasRealChanges 变色) ---
            Button {
                id: finalConfirmBtn
                width: parent.width
                height: 40
                anchors.horizontalCenter: parent.horizontalCenter
                
                // 强制刷新：按钮文字直接取决于 hasRealChanges 属性
                text: perfPanel.hasRealChanges ? "确认修改并下发" : "当前配置已同步"

                background: Rectangle {
                    // 有修改：显示鲜艳的橙红色；无修改：显示深灰色
                    color: perfPanel.hasRealChanges ? "#FF4500" : "#444444"
                    radius: 4
                    border.color: perfPanel.hasRealChanges ? "white" : "transparent"
                    border.width: 1
                }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (perfPanel.hasRealChanges) {
                        // 真正执行赋值操作，将值塞进 Main.qml 的属性里
                        dataStore.mqttSend_robotPerfShooter = perfSelectionOverlay.tempShooter
                        dataStore.mqttSend_robotPerfChassis = perfSelectionOverlay.tempChassis
                        dataStore.mqttSend_robotPerfSentryControl = perfSelectionOverlay.tempSentry
                        
                        console.log("[Performance] 指令已发送: Shooter=" + tempShooter + " Chassis=" + tempChassis)
                    }
                }
            }
        }
    }
}
// --- 通用指令交互面板 (H 键触发) ---
Rectangle {
    id: commonCmdOverlay
    anchors.centerIn: parent
    width: 340
    height: 400
    color: "#F21A1A1A" // 深色半透明背景
    border.color: "#00CCFF" // 赛博蓝边框
    border.width: 2
    radius: 10
    z: 2000 // 确保在最顶层
    
    // 绑定到 dataStore 的显示状态
    visible: dataStore.isCommonCmdVisible

    // 逻辑：当面板显示时，强制获取焦点以允许键盘输入参数
    onVisibleChanged: {
        if (visible) {
            commonCmdOverlay.forceActiveFocus();
        }
    }

    // 拦截鼠标事件，防止操作面板时误触底层的地图或按钮
    MouseArea {
        anchors.fill: parent
        onClicked: (mouse) => {
            mouse.accepted = true;
            commonCmdOverlay.forceActiveFocus();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 25
        spacing: 15

        Text {
            text: "机器人通用指令 (H)"
            color: "#00CCFF"
            font.pixelSize: 20
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        // --- 1. 指令类型选择 (包含所有 6 种协议枚举) ---
        ComboBox {
            id: typeSelector
            Layout.fillWidth: true
            model: [
                { text: "1. 兑换17mm弹药", val: 1 },
                { text: "2. 兑换42mm弹药", val: 2 },
                { text: "3. 确认复活", val: 3 },
                { text: "4. 兑换立即复活", val: 4 },
                { text: "5. 远程兑换发弹量", val: 5 },
                { text: "6. 远程兑换血量", val: 6 }
            ]
            textRole: "text"
            
            // 自动切换默认参数逻辑
            onCurrentIndexChanged: {
                if (currentIndex === 0) paramInputField.text = "10"; // 17mm 通常以10为单位
                else if (currentIndex >= 2) paramInputField.text = "1"; // 复活类通常为1
            }
        }

        // --- 2. 参数输入框 ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            Text { text: "指令参数 (Param):"; color: "#AAAAAA"; font.pixelSize: 12 }
            
            TextField {
                id: paramInputField
                Layout.fillWidth: true
                text: "10"
                color: "white"
                placeholderText: "请输入数值..."
                selectByMouse: true
                focus: true // 允许获取焦点
                
                background: Rectangle {
                    color: paramInputField.activeFocus ? "#333333" : "#222222"
                    border.color: paramInputField.activeFocus ? "#00CCFF" : "#555555"
                    radius: 4
                }
            }
        }

        Item { Layout.fillHeight: true } // 弹性占位

        // --- 3. 操作按钮 ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "确认下发"
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                
                onClicked: {
                    // 1. 将界面数据写入 dataStore
                    dataStore.mqttSend_commonCmdType = typeSelector.model[typeSelector.currentIndex].val;
                    dataStore.mqttSend_commonCmdParam = parseInt(paramInputField.text) || 0;
                    
                    // 2. 触发 MqttDataSender 里的单次发送函数 (不干扰其他定时器)
                    // 注意：这里的 mqttSender 是 Main.qml 中定义的 id
                    mqttSender.triggerCommonCommand(); 
                    
                    // 3. 关闭面板
                    dataStore.isCommonCmdVisible = false;
                    console.log("[UI] 已请求发送指令 Type:", dataStore.mqttSend_commonCmdType);
                }
            }

            Button {
                text: "取消"
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                onClicked: dataStore.isCommonCmdVisible = false
            }
        }
    }
}
// 在UI.qml中，找到自定义数据流面板（id: customByteBlockPanel）的后面，添加以下Buff状态栏
// ======================================================
// Buff状态栏 - 显示机器人当前获得的增益/减益效果
// 位置：放在自定义数据流面板（customByteBlockPanel）的下方
// ======================================================
Item {
    id: buffStatusBar
    // 使用绝对坐标定位：基于customByteBlockPanel的坐标
    x: customByteBlockPanel.x  // 与自定义数据流面板左对齐
    y: customByteBlockPanel.y + customByteBlockPanel.height + 10  // 面板下方+10像素
    width: customByteBlockPanel.width  // 与自定义数据流面板同宽
    height: 80  // 调整为80像素
    z: 999
    visible: dataStore.buff_robot_id > 0 && dataStore.buff_left_time > 0  // 有Buff时才显示

    // 背景
    Rectangle {
        anchors.fill: parent
        color: "#AA000000"  // 半透明黑色
        radius: 4
        border.color: buffStatusBar.getBuffBorderColor()
        border.width: 2
        opacity: 0.9
    }

    // 辅助函数：根据Buff类型获取边框颜色
    function getBuffBorderColor() {
        switch(dataStore.buff_type) {
            case 1: return "#FFD700";  // 攻击增益 - 金色
            case 2: return "#4169E1";  // 防御增益 - 皇家蓝
            case 3: return "#FF4500";  // 热量冷却 - 橙红色
            case 4: return "#32CD32";  // 底盘功率 - 亮绿色
            case 5: return "#FF69B4";  // 回血增益 - 粉红色
            case 6: return "#9370DB";  // 允许发弹量 - 紫色
            case 7: return "#00CED1";  // 地形跨越 - 深青色
            default: return "#00FFCC";  // 默认 - 使用自定义数据流边框颜色
        }
    }

    // 辅助函数：获取Buff图标（使用emoji或文字表示）
    function getBuffIcon() {
        switch(dataStore.buff_type) {
            case 1: return "⚔️";  // 攻击增益 - 交叉剑
            case 2: return "🛡️";  // 防御增益 - 盾牌
            case 3: return "🔥";  // 热量冷却 - 火焰
            case 4: return "⚡";  // 底盘功率 - 闪电
            case 5: return "❤️";  // 回血增益 - 爱心
            case 6: return "🔋";  // 允许发弹量 - 电池
            case 7: return "⛰️";  // 地形跨越 - 山
            default: return "✨";  // 默认 - 星星
        }
    }

    // 辅助函数：获取Buff名称
    function getBuffName() {
        switch(dataStore.buff_type) {
            case 1: return "攻击增益";
            case 2: return "防御增益";
            case 3: return "热量冷却";
            case 4: return "底盘功率";
            case 5: return "回血增益";
            case 6: return "可兑换发弹量";
            case 7: return "地形跨越";
            default: return "未知Buff";
        }
    }

    // 辅助函数：获取Buff描述
    function getBuffDescription() {
        var level = dataStore.buff_level;
        switch(dataStore.buff_type) {
            case 1: return "伤害+" + level + "%";
            case 2: return "减伤+" + level + "%";
            case 3: return "冷却+" + level + "点/秒";
            case 4: return "移速+" + level + "%";
            case 5: return "回血+" + level + "点/秒";
            case 6: return "弹量+" + level + "发";
            case 7: return "准备飞坡";
            default: return "";
        }
    }

    // 布局
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6  // 减小边距
        spacing: 3  // 减小间距

        // 标题行
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            
            Rectangle {
                width: 3
                height: 12
                color: buffStatusBar.getBuffBorderColor()
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: "Buff状态"
                color: "#FFFFFF"
                font.pixelSize: 12
                font.bold: true
            }
            
            Item { Layout.fillWidth: true }
            
            // 机器人ID标签
            Text {
                text: "机器人 #" + dataStore.buff_robot_id
                color: "#AAAAAA"
                font.pixelSize: 10
            }
        }

        // 分割线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#33FFFFFF"
        }

        // Buff图标和主要信息
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Buff图标
            Text {
                text: buffStatusBar.getBuffIcon()
                font.pixelSize: 28  // 减小图标大小
                Layout.preferredWidth: 35
                horizontalAlignment: Text.AlignHCenter
            }

            // Buff详细信息
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                // Buff名称和类型
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: buffStatusBar.getBuffName()
                        font.pixelSize: 13
                        font.bold: true
                        color: "#FFFFFF"
                    }
                    Text {
                        text: buffStatusBar.getBuffDescription()
                        font.pixelSize: 11
                        color: buffStatusBar.getBuffBorderColor()
                        font.bold: true
                        Layout.leftMargin: 5
                    }
                    Item { Layout.fillWidth: true }
                }

                // 进度条和倒计时
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // 进度条（显示剩余时间比例）
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        color: "#333333"
                        radius: 4

                        Rectangle {
                            width: parent.width * (dataStore.buff_left_time / Math.max(1, dataStore.buff_max_time))
                            height: parent.height
                            radius: 4
                            color: buffStatusBar.getBuffBorderColor()
                            
                            // 进度条动画效果
                            Behavior on width {
                                NumberAnimation { duration: 300 }
                            }
                        }
                    }

                    // 倒计时显示
                    Text {
                        text: dataStore.buff_left_time + "s/" + dataStore.buff_max_time + "s"  // 去掉空格，减小宽度
                        font.pixelSize: 11
                        font.bold: true
                        color: dataStore.buff_left_time <= 5 ? "#FF4444" : "#FFD700"
                        
                        // 倒计时闪烁效果
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: dataStore.buff_left_time <= 5
                            NumberAnimation { to: 1; duration: 300 }
                            NumberAnimation { to: 0.3; duration: 300 }
                        }
                    }
                }
            }
        }

        // Buff效果详细说明（如果有多种效果可以显示在这里）
        Text {
            Layout.fillWidth: true
            text: {
                if (dataStore.buff_type === 3) {
                    return "冷却速度提升 " + dataStore.buff_level + " 点/秒";
                } else if (dataStore.buff_type === 6) {
                    return "最大允许发弹量增加 " + dataStore.buff_level + " 发";
                }
                return "";
            }
            font.pixelSize: 9
            color: "#AAAAAA"
            visible: text !== ""
            horizontalAlignment: Text.AlignRight
        }
    }

    // 当窗口大小改变时更新位置
    Connections {
        target: mainWindow
        function onWidthChanged() {
            buffStatusBar.x = customByteBlockPanel.x;
        }
        function onHeightChanged() {
            buffStatusBar.y = customByteBlockPanel.y + customByteBlockPanel.height + 10;
        }
    }
}
// 25 26 英雄部署模式控制面板
Rectangle {
    id: heroDeployPanel
    anchors.top: buffStatusBar.bottom
    anchors.topMargin: 10
    anchors.left: buffStatusBar.left
    width: buffStatusBar.width+140
    height: 60
    color: "#00000080"
    border.color: "#66666680"
    border.width: 1
    radius: 5
    z: 11
    visible:dataStore.clientID==1||dataStore.clientID===101
    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Column {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            spacing: 2
            Text {
                text: "英雄部署模式"
                font.pixelSize: 12
                color: "#aaaaaa"
            }
            Text {
                text: "当前状态: " + (dataStore.deployMode_current_status === 1 ? "已部署" : "未部署")
                font.pixelSize: 14
                font.bold: true
                color: dataStore.deployMode_current_status === 1 ? "#44ff44" : "#aaaaaa"
            }
        }

        Item { Layout.fillWidth: true }

        Button {
            text: "进入部署"
            enabled: dataStore.deployMode_current_status !== 1
            onClicked: {
                dataStore.mqttSend_heroDeployMode = 1;
                console.log("发送英雄部署模式: 进入");
            }
        }

        Button {
            text: "退出部署"
            enabled: dataStore.deployMode_current_status !== 0
            onClicked: {
                dataStore.mqttSend_heroDeployMode = 0;
                console.log("发送英雄部署模式: 退出");
            }
        }
    }
}
// ===== 合并后的能量机关面板（状态+按钮）===== 27 28
Rectangle {
    id: runeCombinedPanel
    anchors.top: scoreBar.bottom
    anchors.right: parent.right
    anchors.topMargin: 10
    anchors.rightMargin: 20
    width: 260
    height: 120
    color: "#00000080"
    border.color: "#66666680"
    border.width: 1
    radius: 5
    z: 11

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // 标题
        Text {
            text: "⚡ 能量机关"
            font.pixelSize: 14
            font.bold: true
            color: "#ffffff"
            Layout.alignment: Qt.AlignHCenter
        }

        // 状态信息行（一行显示三个状态）
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // 状态
            RowLayout {
                spacing: 2
                Text { text: "状态:"; font.pixelSize: 12; color: "#aaaaaa" }
                Text {
                    text: {
                        if (dataStore.runeStatus_rune_status === 1) return "未激活";
                        if (dataStore.runeStatus_rune_status === 2) return "激活中";
                        if (dataStore.runeStatus_rune_status === 3) return "已激活";
                        return "未知";
                    }
                    font.pixelSize: 12
                    font.bold: true
                    color: {
                        if (dataStore.runeStatus_rune_status === 3) return "#44ff44";
                        if (dataStore.runeStatus_rune_status === 2) return "#ffff44";
                        return "#aaaaaa";
                    }
                }
            }

            // 激活灯臂
            RowLayout {
                spacing: 2
                Text { text: "灯臂:"; font.pixelSize: 12; color: "#aaaaaa" }
                Text {
                    text: dataStore.runeStatus_activated_arms + "/6"
                    font.pixelSize: 12
                    color: "#ffffff"
                }
            }

            // 平均环数
            RowLayout {
                spacing: 2
                Text { text: "环数:"; font.pixelSize: 12; color: "#aaaaaa" }
                Text {
                    text: dataStore.runeStatus_average_rings
                    font.pixelSize: 12
                    color: "#ffffff"
                }
            }
        }

        // 按钮行
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "⚡ 激活"
                Layout.fillWidth: true
                enabled: dataStore.runeStatus_rune_status === 1
                onClicked: {
                    dataStore.mqttSend_runeActivate = 1;
                    console.log("发送能量机关激活指令: 激活");
                }
            }

            Button {
                text: "✖ 取消"
                Layout.fillWidth: true
                enabled: dataStore.runeStatus_rune_status === 1
                onClicked: {
                    dataStore.mqttSend_runeActivate = 0;
                    console.log("发送能量机关激活指令: 取消");
                }
            }
        }
    }
}

        // 29 哨兵状态同步面板
        Rectangle {
            id: sentryStatusPanel
            anchors.top: runeCombinedPanel.bottom
            anchors.topMargin: 10
            anchors.right: runeCombinedPanel.right
            width: runeCombinedPanel.width
            height: 80
            color: "#00000080"
            border.color: "#66666680"
            border.width: 1
            radius: 5
            z: 11
            visible:dataStore.clientID===7||dataStore.clientID===107
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // 标题
                Text {
                    text: "🤖 哨兵状态"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#ffffff"
                    Layout.alignment: Qt.AlignHCenter
                }

                // 姿态行
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "姿态:"
                        font.pixelSize: 12
                        color: "#aaaaaa"
                    }
                    Text {
                        text: {
                            var posture = dataStore.sentryStatus_posture_id || 1;
                            switch(posture) {
                                case 1: return "进攻姿态";
                                case 2: return "防御姿态";
                                case 3: return "移动姿态";
                                default: return "未知姿态";
                            }
                        }
                        font.pixelSize: 12
                        font.bold: true
                        color: {
                            var posture = dataStore.sentryStatus_posture_id || 1;
                            if (posture === 1) return "#ff4444";   // 红色代表进攻
                            if (posture === 2) return "#44ff44";   // 绿色代表防御
                            if (posture === 3) return "#ffff44";   // 黄色代表移动
                            return "#ffffff";
                        }
                    }
                }

                // 弱化状态行
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "状态:"
                        font.pixelSize: 12
                        color: "#aaaaaa"
                    }
                    Text {
                        text: dataStore.sentryStatus_is_weakened ? "⚠️ 弱化状态" : "✅ 正常状态"
                        font.pixelSize: 12
                        font.bold: true
                        color: dataStore.sentryStatus_is_weakened ? "#ffaa00" : "#22ff22"
                    }
                }
            }
        }

// ===== 30 31 飞镖控制面板（指令发送 + 状态显示）=====
Rectangle {
    id: dartControlPanel
    anchors.top: sentryStatusPanel.bottom
    anchors.topMargin: 10
    anchors.right: sentryStatusPanel.right
    width: sentryStatusPanel.width
    height: 160
    color: "#00000080"
    border.color: "#66666680"
    border.width: 1
    radius: 5
    z: 11
    visible:dataStore.clientID===6||dataStore.clientID===106
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // 标题
        Text {
            text: "🎯 飞镖控制"
            font.pixelSize: 14
            font.bold: true
            color: "#ffffff"
            Layout.alignment: Qt.AlignHCenter
        }

        // 状态显示行（当前目标 + 闸门状态）
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // 当前目标
            RowLayout {
                spacing: 2
                Text { text: "当前目标:"; font.pixelSize: 12; color: "#aaaaaa" }
                Text {
                    text: {
                        var tid = dataStore.dartTarget_status_target_id || 0;
                        switch(tid) {
                            case 1: return "前哨站";
                            case 2: return "基地固定目标";
                            case 3: return "基地随机固定目标";
                            case 4: return "基地随机移动目标";
                            case 5: return "基地末端移动目标";
                            default: return "未选择";
                        }
                    }
                    font.pixelSize: 12
                    font.bold: true
                    color: "#ffff44"
                }
            }

            // 闸门状态
            RowLayout {
                spacing: 2
                Text { text: "闸门:"; font.pixelSize: 12; color: "#aaaaaa" }
                Text {
                    text: {
                        var stat = dataStore.dartTarget_status_open;
                        if (stat === 0) return "已开启";
                        if (stat === 1) return "关闭";
                        if (stat === 2) return "正在动作";
                        return "未知";
                    }
                    font.pixelSize: 12
                    font.bold: true
                    color: {
                        var stat = dataStore.dartTarget_status_open;
                        if (stat === 0) return "#44ff44";   // 开启 绿色
                        if (stat === 1) return "#ff4444";   // 关闭 红色
                        if (stat === 2) return "#ffff44";   // 动作中 黄色
                        return "#ffffff";
                    }
                }
            }
        }

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#66666680"
        }

        // 目标选择
        RowLayout {
            Layout.fillWidth: true
            Text { text: "选择目标:"; font.pixelSize: 12; color: "#aaaaaa" }

            ComboBox {
                id: targetCombo
                Layout.fillWidth: true
                model: ["前哨站", "基地固定目标", "基地随机固定目标", "基地随机移动目标", "基地末端移动目标"]
                currentIndex: {
                    var tid = dataStore.mqttSend_dartTargetId || 1;
                    return tid - 1;  // 索引0对应ID1
                }
                onActivated: function(index) {
                    dataStore.mqttSend_dartTargetId = index + 1;
                }

                background: Rectangle {
                    color: "#333333"
                    border.color: "#666666"
                    border.width: 1
                    radius: 3
                }
                contentItem: Text {
                    text: targetCombo.displayText
                    color: "#ffffff"
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignLeft
                    leftPadding: 8
                }
                indicator: Canvas {
                    implicitWidth: 20
                    implicitHeight: 20
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.fillStyle = "#ffffff";
                        ctx.moveTo(0, 5);
                        ctx.lineTo(10, 15);
                        ctx.lineTo(20, 5);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
            }
        }

        // 闸门控制按钮行
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "🚪 开启闸门"
                Layout.fillWidth: true
                onClicked: {
                    dataStore.mqttSend_dartOpen = true;
                    console.log("飞镖指令: 开启闸门");
                }
            }

            Button {
                text: "🚪 关闭闸门"
                Layout.fillWidth: true
                onClicked: {
                    dataStore.mqttSend_dartOpen = false;
                    console.log("飞镖指令: 关闭闸门");
                }
            }
        }

        // 发射确认按钮 + 脉冲重置逻辑
        RowLayout {
            Layout.fillWidth: true

            Button {
                text: "🚀 确认发射"
                Layout.fillWidth: true
                enabled: dataStore.dartTarget_status_open === 0  // 仅在闸门已开启时可发射
                onClicked: {
                    dataStore.mqttSend_dartLaunchConfirm = true;
                    console.log("飞镖指令: 确认发射 (脉冲)");

                    // 200ms后自动重置发射确认，避免持续发送
                    launchResetTimer.start();
                }

                // 按钮背景色提示
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#44aa44" : "#22ff22") : "#555555"
                    radius: 4
                }
            }

            // 发射状态指示（可选）
            Text {
                text: dataStore.mqttSend_dartLaunchConfirm ? "⚡发射信号已发送" : ""
                font.pixelSize: 10
                color: "#ffff44"
                visible: dataStore.mqttSend_dartLaunchConfirm
            }
        }

        // 用于重置发射确认的定时器
        Timer {
            id: launchResetTimer
            interval: 200
            repeat: false
            onTriggered: {
                dataStore.mqttSend_dartLaunchConfirm = false;
                console.log("飞镖发射确认已自动重置");
            }
        }
    }
}

// ===== 32 33 哨兵控制指令面板（发送请求 + 显示结果）=====
Rectangle {
    id: sentryCommandPanel
    anchors.top: dartControlPanel.bottom
    anchors.topMargin: 10
    anchors.right: dartControlPanel.right
    width: dartControlPanel.width
    height: 320  // 根据按钮数量调整高度
    color: "#00000080"
    border.color: "#66666680"
    border.width: 1
    radius: 5
    z: 11
    visible:dataStore.clientID===7||dataStore.clientID===107
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // 标题
        Text {
            text: "🤖 哨兵控制指令"
            font.pixelSize: 14
            font.bold: true
            color: "#ffffff"
            Layout.alignment: Qt.AlignHCenter
        }

        // 当前指令结果显示
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // 最新指令ID
            RowLayout {
                spacing: 2
                Text { text: "最新指令:"; font.pixelSize: 12; color: "#aaaaaa" }
                Text {
                    text: dataStore.sentryCtrlResult_command_id || 0
                    font.pixelSize: 12
                    font.bold: true
                    color: "#ffff44"
                }
            }

            // 结果码
            RowLayout {
                spacing: 2
                Text { text: "结果:"; font.pixelSize: 12; color: "#aaaaaa" }
                Text {
                    text: {
                        var code = dataStore.sentryCtrlResult_result_code || 0;
                        return code === 0 ? "成功" : "失败(" + code + ")";
                    }
                    font.pixelSize: 12
                    font.bold: true
                    color: dataStore.sentryCtrlResult_result_code === 0 ? "#44ff44" : "#ff4444"
                }
            }
        }

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#66666680"
        }

        // 指令按钮网格（2列，5行）
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 6

            // 辅助函数：生成按钮
            Component {
                id: commandButton
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    text: modelData.label
                    onClicked: {
                        dataStore.mqttSend_sentryCtrlCommandId = modelData.cmd;
                        console.log("哨兵指令发送:", modelData.label, "指令ID=", modelData.cmd);
                    }

                    // 高亮当前正在发送的指令
                    background: Rectangle {
                        color: dataStore.mqttSend_sentryCtrlCommandId === modelData.cmd ? "#44aa44" : (parent.pressed ? "#555555" : "#333333")
                        border.color: "#666666"
                        border.width: 1
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // 按钮数据模型 (label, command_id)
            Repeater {
                model: ListModel {
                    ListElement { label: "补血点补弹"; cmd: 1 }
                    ListElement { label: "补给站补弹"; cmd: 2 }
                    ListElement { label: "远程补弹"; cmd: 3 }
                    ListElement { label: "远程回血"; cmd: 4 }
                    ListElement { label: "确认复活"; cmd: 5 }
                    ListElement { label: "金币复活"; cmd: 6 }
                    ListElement { label: "地图标点"; cmd: 7 }
                    ListElement { label: "进攻姿态"; cmd: 8 }
                    ListElement { label: "防御姿态"; cmd: 9 }
                    ListElement { label: "移动姿态"; cmd: 10 }
                }
                delegate: Loader {
                    sourceComponent: commandButton
                    property var modelData: model
                }
            }
        }

        // 底部提示文字
        Text {
            text: "点击按钮设置指令，将持续以1Hz发送"
            font.pixelSize: 9
            color: "#aaaaaa"
            Layout.alignment: Qt.AlignHCenter
        }
    }
}

        // ===== 34 35 空中支援面板（指令发送 + 状态显示）=====
        Rectangle {
            id: airSupportPanel
            anchors.top: sentryCommandPanel.bottom
            anchors.topMargin: 10
            anchors.right: sentryCommandPanel.right
            width: sentryCommandPanel.width
            height: 220
            color: "#00000080"
            border.color: "#66666680"
            border.width: 1
            radius: 5
            z: 11
            visible:dataStore.clientID===6||dataStore.clientID===106
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // 标题
                Text {
                    text: "✈️ 空中支援"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#ffffff"
                    Layout.alignment: Qt.AlignHCenter
                }

                // 状态信息网格
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 4

                    Text { text: "当前状态:"; font.pixelSize: 12; color: "#aaaaaa" }
                    Text {
                        text: {
                            var status = dataStore.airSupport_status;
                            if (status === 0) return "未进行空中支援";
                            if (status === 1) return "正在空中支援";
                            return "未知";
                        }
                        font.pixelSize: 12
                        font.bold: true
                        color: dataStore.airSupport_status === 1 ? "#44ff44" : "#aaaaaa"
                    }

                    Text { text: "免费剩余时间:"; font.pixelSize: 12; color: "#aaaaaa" }
                    Text {
                        text: dataStore.airSupport_left_time + " 秒"
                        font.pixelSize: 12
                        color: "#ffffff"
                    }

                    Text { text: "已花费金币:"; font.pixelSize: 12; color: "#aaaaaa" }
                    Text {
                        text: dataStore.airSupport_cost_coins + " 金币"
                        font.pixelSize: 12
                        color: "#ffffff"
                    }

                    Text { text: "激光照射状态:"; font.pixelSize: 12; color: "#aaaaaa" }
                    Text {
                        text: dataStore.airSupport_is_being_targeted === 1 ? "被照射" : "未被照射"
                        font.pixelSize: 12
                        font.bold: true
                        color: dataStore.airSupport_is_being_targeted === 1 ? "#ff4444" : "#22ff22"
                    }

                    Text { text: "发射机构状态:"; font.pixelSize: 12; color: "#aaaaaa" }
                    Text {
                        text: dataStore.airSupport_shooter_status === 0 ? "被雷达反制锁定" : "正常未锁定"
                        font.pixelSize: 12
                        font.bold: true
                        color: dataStore.airSupport_shooter_status === 0 ? "#ff4444" : "#22ff22"
                    }
                }

                // 分隔线
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#66666680"
                }

                // 按钮行
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Button {
                        text: "📞 免费呼叫"
                        Layout.fillWidth: true
                        enabled: dataStore.airSupport_status !== 1 // 不在支援中才可呼叫
                        onClicked: {
                            dataStore.mqttSend_airSupportCommandId = 1;
                            console.log("空中支援指令: 免费呼叫");
                        }
                    }

                    Button {
                        text: "💰 付费呼叫"
                        Layout.fillWidth: true
                        enabled: dataStore.airSupport_status !== 1
                        onClicked: {
                            dataStore.mqttSend_airSupportCommandId = 2;
                            console.log("空中支援指令: 付费呼叫");
                        }
                    }

                    Button {
                        text: "🛑 中断"
                        Layout.fillWidth: true
                        enabled: dataStore.airSupport_status === 1
                        onClicked: {
                            dataStore.mqttSend_airSupportCommandId = 3;
                            console.log("空中支援指令: 中断");
                        }
                    }
                }

                // 底部提示
                Text {
                    text: "点击按钮设置指令，将持续以1Hz发送"
                    font.pixelSize: 9
                    color: "#aaaaaa"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
// 6.6 机器人受伤统计显示- 单行单类型版 - 不透明版
Item {
    id: robotInjuryDisplay
    anchors.left: parent.left
    anchors.top: scoreBar.bottom
    anchors.topMargin: 10
    anchors.leftMargin: 20
    width: 450
    height: 770
    z: 999999
    visible: dataStore.isInjuryDisplay === true
    
    // 计算总伤害（确保不为0，避免除零错误）
    property int totalDamage: Math.max(1, dataStore.robotInjury_total_damage || 1)
    
    // 辅助函数：计算百分比
    function getPercentage(value) {
        return ((value / totalDamage) * 100).toFixed(1)
    }
    
    Rectangle {
        anchors.fill: parent
        color: "#FF111122"  // 改为不透明 (FF 代替 CC)
        border.color: "#FFFF6666"  // 边框改为不透明
        border.width: 3
        radius: 8

        Column {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 12

            // 标题
            Text {
                text: "💔 机器人受伤统计"
                font.pixelSize: 22
                font.bold: true
                color: "#FFFF6666"  // 改为不透明
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // 总伤害 - 加大加粗显示
            Rectangle {
                width: parent.width
                height: 50
                color: "#FF333333"  // 深灰色不透明背景
                border.color: "#FFFF6666"  // 边框不透明
                border.width: 2
                radius: 5

                Row {
                    anchors.centerIn: parent
                    spacing: 20

                    Text {
                        text: "总伤害:"
                        font.pixelSize: 20
                        font.bold: true
                        color: "#FFFFFFFF"  // 纯白
                    }
                    
                    Text {
                        text: dataStore.robotInjury_total_damage + " 点"
                        font.pixelSize: 24
                        font.bold: true
                        color: "#FFFFAA00"  // 金黄色不透明
                    }
                }
            }

            // 分隔线
            Rectangle {
                width: parent.width
                height: 2
                color: "#FFFF6666"  // 不透明红色
                radius: 1
            }

            // 标题行（类型 | 数值 | 占比 | 进度条）
            Row {
                width: parent.width
                height: 25
                spacing: 10
                
                Text { text: "伤害类型"; width: 90; font.pixelSize: 14; color: "#FFCCCCCC"; font.bold: true }
                Text { text: "数值"; width: 70; font.pixelSize: 14; color: "#FFCCCCCC"; font.bold: true }
                Text { text: "占比"; width: 70; font.pixelSize: 14; color: "#FFCCCCCC"; font.bold: true }
                Text { text: "进度条"; width: 150; font.pixelSize: 14; color: "#FFCCCCCC"; font.bold: true }
            }

            // 1. 撞击伤害
            Rectangle {
                width: parent.width
                height: 40
                color: dataStore.robotInjury_collision_damage > 0 ? "#33FFAA00" : "transparent"
                radius: 3
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    spacing: 10
                    
                    Text { text: "💥 撞击"; width: 90; font.pixelSize: 16; color: "#FFFFFFFF"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: dataStore.robotInjury_collision_damage + "点"; width: 70; font.pixelSize: 16; font.bold: true; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: robotInjuryDisplay.getPercentage(dataStore.robotInjury_collision_damage) + "%"; width: 70; font.pixelSize: 16; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    
                    // 进度条
                    Rectangle {
                        width: 150
                        height: 16
                        color: "#FF333333"
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: parent.width * (dataStore.robotInjury_collision_damage / robotInjuryDisplay.totalDamage)
                            height: parent.height
                            color: "#FFFFAA00"
                            radius: 8
                        }
                    }
                }
            }

            // 2. 17mm伤害
            Rectangle {
                width: parent.width
                height: 40
                color: dataStore.robotInjury_small_projectile_damage > 0 ? "#33FF4444" : "transparent"
                radius: 3
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    spacing: 10
                    
                    Text { text: "🔫 17mm"; width: 90; font.pixelSize: 16; color: "#FFFFFFFF"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: dataStore.robotInjury_small_projectile_damage + "点"; width: 70; font.pixelSize: 16; font.bold: true; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: robotInjuryDisplay.getPercentage(dataStore.robotInjury_small_projectile_damage) + "%"; width: 70; font.pixelSize: 16; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    
                    Rectangle {
                        width: 150
                        height: 16
                        color: "#FF333333"
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: parent.width * (dataStore.robotInjury_small_projectile_damage / robotInjuryDisplay.totalDamage)
                            height: parent.height
                            color: "#FFFF4444"
                            radius: 8
                        }
                    }
                }
            }

            // 3. 42mm伤害
            Rectangle {
                width: parent.width
                height: 40
                color: dataStore.robotInjury_large_projectile_damage > 0 ? "#33FF8888" : "transparent"
                radius: 3
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    spacing: 10
                    
                    Text { text: "🔫 42mm"; width: 90; font.pixelSize: 16; color: "#FFFFFFFF"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: dataStore.robotInjury_large_projectile_damage + "点"; width: 70; font.pixelSize: 16; font.bold: true; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: robotInjuryDisplay.getPercentage(dataStore.robotInjury_large_projectile_damage) + "%"; width: 70; font.pixelSize: 16; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    
                    Rectangle {
                        width: 150
                        height: 16
                        color: "#FF333333"
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: parent.width * (dataStore.robotInjury_large_projectile_damage / robotInjuryDisplay.totalDamage)
                            height: parent.height
                            color: "#FFFF8888"
                            radius: 8
                        }
                    }
                }
            }

            // 4. 飞镖伤害
            Rectangle {
                width: parent.width
                height: 40
                color: dataStore.robotInjury_dart_splash_damage > 0 ? "#3388FF88" : "transparent"
                radius: 3
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    spacing: 10
                    
                    Text { text: "🎯 飞镖"; width: 90; font.pixelSize: 16; color: "#FFFFFFFF"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: dataStore.robotInjury_dart_splash_damage + "点"; width: 70; font.pixelSize: 16; font.bold: true; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: robotInjuryDisplay.getPercentage(dataStore.robotInjury_dart_splash_damage) + "%"; width: 70; font.pixelSize: 16; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    
                    Rectangle {
                        width: 150
                        height: 16
                        color: "#FF333333"
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: parent.width * (dataStore.robotInjury_dart_splash_damage / robotInjuryDisplay.totalDamage)
                            height: parent.height
                            color: "#FF88FF88"
                            radius: 8
                        }
                    }
                }
            }

            // 5. 模块离线伤害
            Rectangle {
                width: parent.width
                height: 40
                color: dataStore.robotInjury_module_offline_damage > 0 ? "#338888FF" : "transparent"
                radius: 3
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    spacing: 10
                    
                    Text { text: "🔌 模块离线"; width: 90; font.pixelSize: 16; color: "#FFFFFFFF"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: dataStore.robotInjury_module_offline_damage + "点"; width: 70; font.pixelSize: 16; font.bold: true; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: robotInjuryDisplay.getPercentage(dataStore.robotInjury_module_offline_damage) + "%"; width: 70; font.pixelSize: 16; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    
                    Rectangle {
                        width: 150
                        height: 16
                        color: "#FF333333"
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: parent.width * (dataStore.robotInjury_module_offline_damage / robotInjuryDisplay.totalDamage)
                            height: parent.height
                            color: "#FF8888FF"
                            radius: 8
                        }
                    }
                }
            }

            // 6. 异常离线伤害
            Rectangle {
                width: parent.width
                height: 40
                color: dataStore.robotInjury_offline_damage > 0 ? "#33FF88FF" : "transparent"
                radius: 3
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    spacing: 10
                    
                    Text { text: "⚠️ 异常离线"; width: 90; font.pixelSize: 16; color: "#FFFFFFFF"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: dataStore.robotInjury_offline_damage + "点"; width: 70; font.pixelSize: 16; font.bold: true; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: robotInjuryDisplay.getPercentage(dataStore.robotInjury_offline_damage) + "%"; width: 70; font.pixelSize: 16; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    
                    Rectangle {
                        width: 150
                        height: 16
                        color: "#FF333333"
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: parent.width * (dataStore.robotInjury_offline_damage / robotInjuryDisplay.totalDamage)
                            height: parent.height
                            color: "#FFFF88FF"
                            radius: 8
                        }
                    }
                }
            }

            // 7. 判罚伤害
            Rectangle {
                width: parent.width
                height: 40
                color: dataStore.robotInjury_penalty_damage > 0 ? "#33FFFF88" : "transparent"
                radius: 3
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    spacing: 10
                    
                    Text { text: "⚖️ 判罚"; width: 90; font.pixelSize: 16; color: "#FFFFFFFF"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: dataStore.robotInjury_penalty_damage + "点"; width: 70; font.pixelSize: 16; font.bold: true; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: robotInjuryDisplay.getPercentage(dataStore.robotInjury_penalty_damage) + "%"; width: 70; font.pixelSize: 16; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    
                    Rectangle {
                        width: 150
                        height: 16
                        color: "#FF333333"
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: parent.width * (dataStore.robotInjury_penalty_damage / robotInjuryDisplay.totalDamage)
                            height: parent.height
                            color: "#FFFFFF88"
                            radius: 8
                        }
                    }
                }
            }

            // 8. 服务器战亡伤害
            Rectangle {
                width: parent.width
                height: 40
                color: dataStore.robotInjury_server_kill_damage > 0 ? "#33FF8888" : "transparent"
                radius: 3
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    spacing: 10
                    
                    Text { text: "💀 服务器战亡"; width: 90; font.pixelSize: 16; color: "#FFFFFFFF"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: dataStore.robotInjury_server_kill_damage + "点"; width: 70; font.pixelSize: 16; font.bold: true; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    Text { text: robotInjuryDisplay.getPercentage(dataStore.robotInjury_server_kill_damage) + "%"; width: 70; font.pixelSize: 16; color: "#FFFFAA00"; verticalAlignment: Text.AlignVCenter; height: parent.height }
                    
                    Rectangle {
                        width: 150
                        height: 16
                        color: "#FF333333"
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: parent.width * (dataStore.robotInjury_server_kill_damage / robotInjuryDisplay.totalDamage)
                            height: parent.height
                            color: "#FFFF8888"
                            radius: 8
                        }
                    }
                }
            }

            // 分隔线
            Rectangle {
                width: parent.width
                height: 2
                color: "#FFFF6666"
                radius: 1
            }

            // 击杀者信息
            Rectangle {
                width: parent.width
                height: 50
                color: "#FF333333"
                border.color: "#FFFF6666"
                border.width: 1
                radius: 5

                Row {
                    anchors.centerIn: parent
                    spacing: 20
                    
                    Text {
                        text: "🔪 击杀者ID:"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#FFFFFFFF"
                    }
                    
                    Text {
                        text: dataStore.robotInjury_killer_id > 0 ? dataStore.robotInjury_killer_id : "无"
                        font.pixelSize: 22
                        font.bold: true
                        color: dataStore.robotInjury_killer_id > 0 ? "#FFFF6666" : "#FFAAAAAA"
                    }
                    
                    Text {
                        text: dataStore.robotInjury_killer_id > 0 ? 
                              (dataStore.robotInjury_killer_id < 100 ? "(红方)" : "(蓝方)") : ""
                        font.pixelSize: 16
                        color: "#FFFFAA00"
                        visible: dataStore.robotInjury_killer_id > 0
                    }
                }
            }

            // 图例说明
            Flow {
                width: parent.width
                spacing: 15
                
                Row { spacing: 5; Rectangle { width: 16; height: 16; color: "#FFFFAA00"; radius: 3 } 
                      Text { text: "撞击"; font.pixelSize: 12; color: "#FFCCCCCC"; anchors.verticalCenter: parent.verticalCenter } }
                Row { spacing: 5; Rectangle { width: 16; height: 16; color: "#FFFF4444"; radius: 3 } 
                      Text { text: "17mm"; font.pixelSize: 12; color: "#FFCCCCCC"; anchors.verticalCenter: parent.verticalCenter } }
                Row { spacing: 5; Rectangle { width: 16; height: 16; color: "#FFFF8888"; radius: 3 } 
                      Text { text: "42mm"; font.pixelSize: 12; color: "#FFCCCCCC"; anchors.verticalCenter: parent.verticalCenter } }
                Row { spacing: 5; Rectangle { width: 16; height: 16; color: "#FF88FF88"; radius: 3 } 
                      Text { text: "飞镖"; font.pixelSize: 12; color: "#FFCCCCCC"; anchors.verticalCenter: parent.verticalCenter } }
                Row { spacing: 5; Rectangle { width: 16; height: 16; color: "#FF8888FF"; radius: 3 } 
                      Text { text: "模块离线"; font.pixelSize: 12; color: "#FFCCCCCC"; anchors.verticalCenter: parent.verticalCenter } }
                Row { spacing: 5; Rectangle { width: 16; height: 16; color: "#FFFF88FF"; radius: 3 } 
                      Text { text: "异常离线"; font.pixelSize: 12; color: "#FFCCCCCC"; anchors.verticalCenter: parent.verticalCenter } }
                Row { spacing: 5; Rectangle { width: 16; height: 16; color: "#FFFFFF88"; radius: 3 } 
                      Text { text: "判罚"; font.pixelSize: 12; color: "#FFCCCCCC"; anchors.verticalCenter: parent.verticalCenter } }
                Row { spacing: 5; Rectangle { width: 16; height: 16; color: "#FFFF8888"; radius: 3 } 
                      Text { text: "服务器战亡"; font.pixelSize: 12; color: "#FFCCCCCC"; anchors.verticalCenter: parent.verticalCenter } }
            }
        }
    }

}

// 机器人血量显示总区域
Item {
    id: robotHealthManager
    width: parent.width; height: 120; y: 50
    anchors.horizontalCenter: parent.horizontalCenter
    z:10

    // 辅助函数
    function getRobotNameById(rId) {
        let baseId = rId > 100 ? rId - 100 : rId;
        let names = {1: "英雄", 2: "工程", 3: "步兵3", 4: "步兵4", 6: "空中", 7: "哨兵"};
        return names[baseId] || "";
    }

    function getDefaultMaxHealthById(rId) {
        let baseId = rId > 100 ? rId - 100 : rId;
        // 这里的数值可以保留作为兜底，或者直接从 dataStore 获取
        let healths = {1: 600, 2: 300, 3: 200, 4: 200, 6: 150, 7: 400};
        return healths[baseId] || 200;
    }

    // 新增：根据机器人 ID 计算在 globalUnit_robot_health 数组中的索引
    function getHealthIndexById(rId) {
        if (rId >= 1 && rId <= 7) {
            return rId - 1; // 己方：1->0, 2->1, ... 7->6
        } else if (rId >= 101 && rId <= 107) {
            return (rId - 101) + 5; // 对方：101->7, 102->8, ... 107->13
        }
        return -1;
    }

    Row {
        anchors.centerIn: parent
        spacing: 200 

        // ================= 左侧：红方机器人组 =================
        Row {
            spacing: 0 
            Repeater {
                model: [1, 2, 3, 4, 6, 7] 
                delegate: RobotHealthUnit {
                    robotId: modelData
                    robotName: robotHealthManager.getRobotNameById(modelData)
                    isRed: true
                    isMe: (modelData === dataStore.clientID)
                    
                    // 绑定到 dataStore 的数组属性
                    currentHealth: {
                        let idx = robotHealthManager.getHealthIndexById(robotId);
                        return (idx !== -1 && dataStore.globalUnit_robot_health[idx] !== undefined) 
                                ? dataStore.globalUnit_robot_health[idx] 
                                : 0;
                    }

                    maxHealth: {
                        // MaxHealth 通常来自实时 map，如果 map 没数据则使用本地默认值
                        var liveData = dataStore.robotDataMap[modelData];
                        return liveData ? (liveData.max_health || robotHealthManager.getDefaultMaxHealthById(modelData)) 
                                        : robotHealthManager.getDefaultMaxHealthById(modelData);
                    }
                    
                    iconSource: "qrc:/images/resources/红方" + (robotName.indexOf("步兵") !== -1 ? "步兵" : robotName) + ".png"
                    templateSource: "qrc:/images/resources/红方血量模版.png"
                }
            }
        }

        // ================= 右侧：蓝方机器人组 =================
        Row {
            spacing: 0 
            Repeater {
                model: [101, 102, 103, 104, 106, 107]
                delegate: RobotHealthUnit {
                    robotId: modelData
                    robotName: robotHealthManager.getRobotNameById(modelData)
                    isRed: false
                    isMe: (modelData === dataStore.clientID)
                    
                    // 绑定到 dataStore 的数组属性
                    currentHealth: {
                        let idx = robotHealthManager.getHealthIndexById(robotId);
                        return (idx !== -1 && dataStore.globalUnit_robot_health[idx] !== undefined) 
                                ? dataStore.globalUnit_robot_health[idx] 
                                : 0;
                    }

                    maxHealth: {
                        var liveData = dataStore.robotDataMap[modelData];
                        return liveData ? (liveData.max_health || robotHealthManager.getDefaultMaxHealthById(modelData)) 
                                        : robotHealthManager.getDefaultMaxHealthById(modelData);
                    }
                    
                    iconSource: "qrc:/images/resources/蓝方" + (robotName.indexOf("步兵") !== -1 ? "步兵" : robotName) + ".png"
                    templateSource: "qrc:/images/resources/蓝方血量模版.png"
                }
            }
        }
    
    }

    // 内部组件定义
    component RobotHealthUnit : Item {
        property string robotName: ""; property int robotId: 0
        property int currentHealth: 0; property int maxHealth: 200
        property bool isRed: true; property bool isMe: false 
        property string iconSource: ""; property string templateSource: ""
        width: 125; height: 125
// --- 修改后的弹药绑定逻辑 ---
    readonly property int currentBullets: {
        // 根据协议，robot_bullets 数组索引 0-5 对应己方的 1,2,3,4,6,7 号机器人
        // 我们通过 ID 映射到 0-5 的索引
        let bulletIdx = -1;
        let baseId = robotId > 100 ? robotId - 100 : robotId;
        
        // 建立 ID 到 bullets 数组索引的映射 (1->0, 2->1, 3->2, 4->3, 6->4, 7->5)
        let idMap = {1:0, 2:1, 3:2, 4:3, 6:4, 7:5};
        bulletIdx = idMap[baseId];

        // 逻辑：只有当该机器人属于己方阵营时，才从 dataStore 取弹药数
        // 假设 dataStore.clientID < 100 表示我是红方，> 100 表示我是蓝方
        let isAlly = (dataStore.clientID < 100) ? isRed : !isRed;

        if (isAlly && bulletIdx !== undefined && dataStore.globalUnit_robot_bullets[bulletIdx] !== undefined) {
            return dataStore.globalUnit_robot_bullets[bulletIdx];
        }
        return 0;
    }
        // “我”的标识 (ME)
        Rectangle {
            visible: isMe; anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; width: 30; height: 14; color: "#FFD700"; radius: 2; z: 20
            anchors.topMargin:50
            Text { text: "ME"; anchors.centerIn: parent; font.pixelSize: 9; font.bold: true }
        }

        // 底部装饰模版及血条逻辑
        Image {
            id: bgTemplate
            source: templateSource; anchors.bottom: parent.bottom; width: parent.width; height: parent.height * 0.4; fillMode: Image.PreserveAspectFit
            
            // 自身高亮边框
            Rectangle { anchors.fill: parent; color: "transparent"; border.color: "#FFD700"; border.width: 2; visible: isMe }
            
            // 实时血条矩形
            Rectangle {
                id: healthBarArea
                x: parent.width * 0.12; y: parent.height * 0.85; height: parent.height * 0.1
                width: (parent.width * 0.55) * (maxHealth > 0 ? Math.max(0, Math.min(currentHealth / maxHealth, 1.0)) : 0)
                color: isRed ? "#FF4444" : "#4444FF"
                Behavior on width { NumberAnimation { duration: 300 } }
            }

            // --- 修改部分：血量文字放置在血条下方 ---
            Text {
                id: healthValueText
                // 将文字顶部对齐到血条区域的底部
                anchors.top: healthBarArea.bottom
                anchors.topMargin: 2 // 文字与血条的间距
                anchors.horizontalCenter: parent.horizontalCenter // 居中显示
                
                text: currentHealth + "/" + maxHealth
                color: "white"
                font.pixelSize: 10 // 放在下方可以稍微大一点点
                font.bold: true
                z: 1
                style: Text.Outline
                styleColor: "black"
            }
            // --- 弹药显示 (无论是哪一方，只要是己方阵营就显示) ---
        Text {
            id: bulletValueText
            // 判断是否显示：如果是己方机器人才显示弹药
            visible: (dataStore.clientID < 100) ? isRed : !isRed 
            
            anchors.top: healthValueText.bottom
            anchors.topMargin: 1
            anchors.horizontalCenter: healthValueText.horizontalCenter
            
            text: "B: " + currentBullets // B 代表 Bullets
            color: currentBullets < 20 ? "#FF4444" : "#00FF7F" 
            font.pixelSize: 9
            font.bold: true
            style: Text.Outline; styleColor: "black"
        }
    
        }
        

        // 机器人图标
        Image {
            source: iconSource; width: parent.width * 0.7; height: parent.height * 0.35
            anchors.centerIn: bgTemplate; anchors.verticalCenterOffset: -7
            fillMode: Image.PreserveAspectFit; z: 10; opacity: currentHealth > 0 ? 1.0 : 0.4
        }
    }
}
// 登录界面 (Rectangle)
Rectangle {
    id: loginMask
    anchors.fill: parent
    color: "#E61A1A1A"
    z: 9999000
    // 逻辑：如果 MQTT 未连接 或者 登录界面显示开关被打开（!isLoginDisplay意为处于登录流程中）
    //visible: !dataStore.mqttConnected || !dataStore.isLoginDisplay
    visible: false
    // 映射表逻辑：计算 MQTT 客户端 ID 和 机器人的数字 ID
    function calculateIds() {
        let side = sideBox.currentText // "红方" 或 "蓝方"
        let type = typeBox.currentText // "英雄", "工程" 等
        let mqttId = "0x8080"          // 默认服务器 ID (哨兵/雷达常用)
        let robotId = 0

        if (side === "红方") {
            if (type === "英雄") { mqttId = "0x0101"; robotId = 1; }
            else if (type === "工程") { mqttId = "0x0102"; robotId = 2; }
            else if (type === "步兵3") { mqttId = "0x0103"; robotId = 3; }
            else if (type === "步兵4") { mqttId = "0x0104"; robotId = 4; }
            else if (type === "步兵5") { mqttId = "0x0105"; robotId = 5; }
            else if (type === "空中") { mqttId = "0x0106"; robotId = 6; }
            else if (type === "哨兵") { mqttId = "0x0107"; robotId = 7; } // 修复补齐 MQTT ID
            else if (type === "雷达") { mqttId = "0x0109"; robotId = 9; }
        } else { // 蓝方
            if (type === "英雄") { mqttId = "0x0165"; robotId = 101; }
            else if (type === "工程") { mqttId = "0x0166"; robotId = 102; }
            else if (type === "步兵3") { mqttId = "0x0167"; robotId = 103; }
            else if (type === "步兵4") { mqttId = "0x0168"; robotId = 104; }
            else if (type === "步兵5") { mqttId = "0x0169"; robotId = 105; }
            else if (type === "空中") { mqttId = "0x016A"; robotId = 106; }
            else if (type === "哨兵") { mqttId = "0x016B"; robotId = 107; }
            else if (type === "雷达") { mqttId = "0x016D"; robotId = 109; }
        }
        return { "mqtt": mqttId, "robot": robotId };
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 25

        Text {
            text: "ROBOMASTER 2026 选手端登录"
            color: "white"
            font.pixelSize: 28
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            spacing: 15
            Layout.alignment: Qt.AlignHCenter

            // 阵营选择
            ComboBox {
                id: sideBox
                model: ["红方", "蓝方"]
                implicitWidth: 120
                currentIndex: 0 // 默认红方
            }

            // 机器人选择
            ComboBox {
                id: typeBox
                model: ["英雄", "工程", "步兵3", "步兵4", "步兵5", "空中", "哨兵", "雷达"]
                implicitWidth: 150
                currentIndex: 0 // 默认英雄
            }
        }

        // 登录按钮
        Button {
            text: "确认身份并连接"
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            
            // 按钮样式美化（可选）
            contentItem: Text {
                text: parent.text
                color: "green"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                let res = loginMask.calculateIds();
                
                // 1. 设置 C++ MQTT ClientID（用于 MQTT 服务器握手）
                mqttClient.setClientId(res.mqtt);
                
                // 2. 修改：设置当前客户端的专属 ID（用于从 DataMap 中筛选自己的数据）
                dataStore.clientID = res.robot;
                
                // 3. 执行连接
                mqttClient.connectToServer();
                
                console.log("登录请求 -> ClientID: " + res.mqtt + " | 绑定机器人 ID: " + res.robot);
                
            }
        }

        Text {
            text: "提示：系统将根据绑定的 ID 自动过滤并显示对应机器人的状态信息"
            color: "#888"
            font.pixelSize: 12
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // 状态监听
    Connections {
        target: mqttClient
        // 当连接成功时，更新连接状态并隐藏登录面板
        function onConnected() { 
            dataStore.mqttConnected = true; 
            dataStore.isLoginDisplay = true; 
            console.log("MQTT 已连接，登录界面隐藏");
        }
        // 当断开连接时，显示登录面板
        function onDisconnected() { 
            dataStore.mqttConnected = false; 
            console.log("MQTT 已断开");
        }
    }
}
// 放在 UI.qml 的适当位置（建议放在根 Item 下方，作为最高层级）
Rectangle {
    id: professionalTabPanel
    anchors.centerIn: parent
    width: 1180
    height: 680
    color: "#F2121212" 
    border.color: "#33FFFFFF"
    border.width: 1
    radius: 10
    visible: dataStore.isRobotStatusDisplay // 绑定 TAB 显示开关
    z:999990
    // --- 1. 顶部全局对比栏 ---
    Rectangle {
        id: topBar
        width: parent.width
        height: 100
        color: "transparent"
        anchors.top: parent.top

        // 左侧：红方统计
        ColumnLayout {
            anchors.left: parent.left
            anchors.leftMargin: 50
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { 
                text: "飞镖命中: " + (dataStore.dart_hitNum || 0) + " / 4"
                color: "#FF4444"; font.pixelSize: 14 
            }
            Text { 
                text: "红方总伤害: " + dataStore.globalUnit_total_damage_ally
                color: "#FF4444"; font.pixelSize: 22; font.bold: true 
            }
        }

        // 中间：伤害数值对比
        RowLayout {
            anchors.centerIn: parent
            spacing: 30
            Text { 
                text: dataStore.globalUnit_total_damage_ally
                color: "#FF4444"; font.pixelSize: 48; font.bold: true 
            }
            Rectangle { width: 2; height: 40; color: "#44FFFFFF" }
            Text { 
                text: dataStore.globalUnit_total_damage_enemy
                color: "#4444FF"; font.pixelSize: 48; font.bold: true 
            }
        }

        // 右侧：蓝方统计
        ColumnLayout {
            anchors.right: parent.right
            anchors.rightMargin: 50
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { 
                text: "对方飞镖命中未知" 
                color: "#4444FF"; Layout.alignment: Qt.AlignRight
            }
            Text { 
                text: "蓝方总伤害: " + dataStore.globalUnit_total_damage_enemy
                color: "#4444FF"; font.pixelSize: 22; font.bold: true; Layout.alignment: Qt.AlignRight
            }
        }
    }

    // --- 2. 核心分栏区域 ---
    RowLayout {
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 20
        spacing: 25

        // 左侧：红方 (已剔除 5 号)
        TeamPanel {
            teamName: "RED SIDE"
            teamColor: "#FF4444"
            robotIds: [1, 2, 3, 4, 6, 7] // 排除 5 号
            isAllySide: dataStore.isRedSide
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // 右侧：蓝方 (已剔除 105 号)
        TeamPanel {
            teamName: "BLUE SIDE"
            teamColor: "#4444FF"
            robotIds: [101, 102, 103, 104, 106, 107] // 排除 105 号
            isAllySide: !dataStore.isRedSide
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    Text {
        text: "按 [TAB] 键隐藏面板"
        anchors.bottom: parent.bottom; anchors.bottomMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#666"; font.pixelSize: 12
    }
}

// ==============================================
// 复用组件：TeamPanel
// ==============================================
component TeamPanel : ColumnLayout {
    property string teamName: ""
    property color teamColor: "white"
    property var robotIds: []
    property bool isAllySide: false // 用于判断是否显示弹药量

    spacing: 10

    Rectangle {
        Layout.fillWidth: true; height: 30; color: teamColor; opacity: 0.8; radius: 3
        Text { text: teamName; anchors.centerIn: parent; color: "white"; font.bold: true }
    }

    RowLayout {
        Layout.fillWidth: true
        Text { text: "ID"; color: "#888"; font.pixelSize: 12; Layout.preferredWidth: 35 }
        Text { text: "机型/血量"; color: "#888"; font.pixelSize: 12; Layout.fillWidth: true }
        Text { text: "弹药"; color: "#888"; font.pixelSize: 12; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignHCenter }
        Text { text: "功率"; color: "#888"; font.pixelSize: 12; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignHCenter }
        Text { text: "热量"; color: "#888"; font.pixelSize: 12; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignHCenter }
        Text { text: "冷却"; color: "#888"; font.pixelSize: 12; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignHCenter }
        Text { text: "上限"; color: "#888"; font.pixelSize: 12; Layout.preferredWidth: 35; horizontalAlignment: Text.AlignHCenter }
    }

    Repeater {
        model: robotIds
        delegate: Rectangle {
            Layout.fillWidth: true; height: 52
            // 只有当前控制的机器人才高亮
            color: (modelData === dataStore.clientID) ? "#33FFFFFF" : "#12FFFFFF"
            border.color: (modelData === dataStore.clientID) ? teamColor : "transparent"
            border.width: 1; radius: 4

            // 使用 dataStore.robotDataMap 进行数据绑定
            readonly property var rData: dataStore.robotDataMap[modelData] || {}

            RowLayout {
                anchors.fill: parent; anchors.margins: 8

                // 1. ID
                Text { text: modelData; color: teamColor; font.bold: true; Layout.preferredWidth: 35 }

                // 2. 名称与血量条
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    RowLayout {
                        Text { 
                            text: getRobotTypeStr(rData.robot_type || 0) + " Lv." + (rData.level || 1)
                            color: "white"; font.pixelSize: 11 
                        }
                        Item { Layout.fillWidth: true }
                        Text { 
                            text: (rData.current_health || 0) + "/" + (rData.max_health || 1)
                            color: "#AAA"; font.pixelSize: 10 
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 6; color: "#222"; radius: 3
                        Rectangle {
                            height: 6; radius: 3
                            // 绑定当前血量比例
                            width: parent.width * Math.max(0, Math.min(1, (rData.current_health || 0) / (rData.max_health || 1)))
                            color: teamColor
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }
                }

                // 3. 弹药 (仅己方显示)
                Text { 
                    text: isAllySide ? (rData.remaining_bullets || 0) : "--"
                    color: isAllySide && rData.remaining_bullets < 20 ? "#FF4444" : "white"
                    Layout.preferredWidth: 40; horizontalAlignment: Text.AlignHCenter 
                }

                // 4. 底盘功率 (max_power)
                Text { 
                    text: (rData.max_power || 0); color: "white"
                    Layout.preferredWidth: 40; horizontalAlignment: Text.AlignHCenter 
                }

                // 5. 热量上限 (max_heat)
                Text { 
                    text: (rData.max_heat || 0); color: "white"
                    Layout.preferredWidth: 40; horizontalAlignment: Text.AlignHCenter 
                }

                // 6. 热量冷却 (heat_cooldown_rate)
                Text { 
                    text: (rData.heat_cooldown_rate || 0).toFixed(0)
                    color: "white"; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignHCenter 
                }

                // 7. 射速上限 (不再硬编码)
                Text { 
                    text: (rData.shoot_speed_limit || 30); color: "white"
                    Layout.preferredWidth: 35; horizontalAlignment: Text.AlignHCenter 
                }
            }
        }
    }

    Item { Layout.fillHeight: true }

    function getRobotTypeStr(type) {
        let names = { 1: "英雄", 2: "工程", 3: "步兵", 4: "空中", 5: "哨兵", 6: "飞镖", 7: "雷达" };
        return names[type] || "未上场";
    }
}
}