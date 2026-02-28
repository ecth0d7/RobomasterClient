import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import QtQuick.Window 6.2
// RoboMaster 2026 自定义客户端 - 核心逻辑层       
// 职责：数据存储、模块引入、数据绑定、窗口基础配置
ApplicationWindow {
    id: root
    visible: true
    width: 1280
    height: 720
    title: "RoboMaster 2026 自定义客户端"
    color: "#222222"
    flags: Qt.FramelessWindowHint | Qt.Window  // 无边框+保留窗口特性

    // ==============================================
    // 核心数据存储：用QtObject封装多维数据结构（QML标准写法）
    // 结构：dataStore.分类_属性名 = 值
    // ==============================================
    QtObject {
        id: dataStore
        
        // 1. 窗口状态（保留数据，逻辑移到UI层）
        property bool isMaximized: false
        property int normalX: 0
        property int normalY: 0
        property int normalWidth: 1280
        property int normalHeight: 720
        
      
        
        // 2. 比赛全局状态
        property int gameStatus_current_round: -1
        property int gameStatus_total_rounds: 0
        property int gameStatus_red_score: 0
        property int gameStatus_blue_score: 0
        property int gameStatus_current_stage: 0
        property int gameStatus_stage_countdown_sec: 0
        property int gameStatus_stage_elapsed_sec: 0
        property bool gameStatus_is_paused: false
        
        // 3. 全局单位状态
        property int globalUnit_base_health: 0
        property int globalUnit_base_status: 0
        property int globalUnit_base_shield: 0
        property int globalUnit_outpost_health: 0
        property int globalUnit_outpost_status: 0
        property int globalUnit_enemy_base_health: 0
        property int globalUnit_enemy_base_status: 0
        property int globalUnit_enemy_base_shield: 0
        property int globalUnit_enemy_outpost_health: 0
        property int globalUnit_enemy_outpost_status: 0
        property var globalUnit_robot_health: []
        property var globalUnit_robot_bullets: []
        property int globalUnit_total_damage_ally: 0
        property int globalUnit_total_damage_enemy: 0
        
        // 4. 全局后勤信息
        property int globalLogistics_remaining_economy: 0
        property int globalLogistics_total_economy_obtained: 0
        property int globalLogistics_tech_level: 0
        property int globalLogistics_encryption_level: 0
       
        
        // 5. 全局特殊机制
        property var globalSpecial_mechanism_id: []
        property var globalSpecial_mechanism_time_sec: []
        
        // 6. 全局事件
        property int event_id: 0
        property string event_param: ""
        
        // 7. 机器人受伤统计
        property int robotInjury_total_damage: 0
        property int robotInjury_collision_damage: 0
        property int robotInjury_small_projectile_damage: 0
        property int robotInjury_large_projectile_damage: 0
        property int robotInjury_dart_splash_damage: 0
        property int robotInjury_module_offline_damage: 0
        property int robotInjury_offline_damage: 0
        property int robotInjury_penalty_damage: 0
        property int robotInjury_server_kill_damage: 0
        property int robotInjury_killer_id: 0
        
        // 8. 机器人复活状态
        property bool robotRespawn_is_pending_respawn: false
        property int robotRespawn_total_respawn_progress: 0
        property int robotRespawn_current_respawn_progress: 0
        property bool robotRespawn_can_free_respawn: false
        property int robotRespawn_gold_cost_for_respawn: 0
        property bool robotRespawn_can_pay_for_respawn: false
        
        // 9. 机器人固定属性
        property int robotStatic_connection_state: 0
        property int robotStatic_field_state: 0
        property int robotStatic_alive_state: 0
        property int robotStatic_robot_id: 0
        property int robotStatic_robot_type: 0
        property int robotStatic_performance_system_shooter: 1
        property int robotStatic_performance_system_chassis: 1
        property int robotStatic_level: 1
        property int robotStatic_max_health: 0
        property int robotStatic_max_heat: 0
        property real robotStatic_heat_cooldown_rate: 0.0
        property int robotStatic_max_power: 0
        property int robotStatic_max_buffer_energy: 0
        property int robotStatic_max_chassis_energy: 0
        
        // 10. 机器人动态状态
        property int robotDynamic_current_health: 0
        property real robotDynamic_current_heat: 0.0
        property real robotDynamic_last_projectile_fire_rate: 0.0
        property int robotDynamic_current_chassis_energy: 0
        property int robotDynamic_current_buffer_energy: 0
        property int robotDynamic_current_experience: 0
        property int robotDynamic_experience_for_upgrade: 0
        property int robotDynamic_total_projectiles_fired: 0
        property int robotDynamic_remaining_ammo: 0
        property bool robotDynamic_is_out_of_combat: false
        property int robotDynamic_out_of_combat_countdown: 0
        property bool robotDynamic_can_remote_heal: false
        property bool robotDynamic_can_remote_ammo: false
        
        // 11. 机器人模块状态
        property int robotModule_power_manager: 0
        property int robotModule_rfid: 0
        property int robotModule_light_strip: 0
        property int robotModule_small_shooter: 0
        property int robotModule_big_shooter: 0
        property int robotModule_uwb: 0
        property int robotModule_armor: 0
        property int robotModule_video_transmission: 0
        property int robotModule_capacitor: 0
        property int robotModule_main_controller: 0
        property int robotModule_laser_detection_module: 0
        
        // 12. 机器人位置
        property real robotPosition_x: 0.0
        property real robotPosition_y: 0.0
        property real robotPosition_z: 0.0
        property real robotPosition_yaw: 0.0
        
        // 13. Buff信息
        property int buff_robot_id: 0
        property int buff_type: 0
        property int buff_level: 0
        property int buff_max_time: 0
        property int buff_left_time: 0
        
        // 14. 判罚信息
        property int penalty_type: 0
        property int penalty_effect_sec: 0
        property int penalty_total_penalty_num: 0
        
        // 15. 哨兵轨迹规划
        property int robotPath_intention: 0
        property int robotPath_start_pos_x: 0
        property int robotPath_start_pos_y: 0
        property var robotPath_offset_x: []
        property var robotPath_offset_y: []
        property int robotPath_sender_id: 0
        
        // 16. 雷达信息
        property int radar_target_robot_id: 0
        property real radar_target_pos_x: 0.0
        property real radar_target_pos_y: 0.0
        property real radar_toward_angle: 0.0
        property int radar_is_high_light: 0
        
        // 17. 自定义数据流
        property string customByteBlock_data: ""
        
        // 18. 科技核心状态
        property int techCore_maximum_difficulty_level: 1
        property int techCore_status: 1
        property int techCore_enemy_core_status: 0
        property int techCore_remain_time_all: 0
        property int techCore_remain_time_step: 0
        
        // 19. 性能体系状态
        property int robotPerfSync_shooter: 1
        property int robotPerfSync_chassis: 1
        property int robotPerfSync_sentry_control: 0
        
        // 20. 英雄部署模式
        property int deployMode_current_status: 0
        
        // 21. 能量机关状态
        property int runeStatus_rune_status: 1
        property int runeStatus_activated_arms: 0
        property int runeStatus_average_rings: 0
        
        // 22. 哨兵状态
        property int sentryStatus_posture_id: 1
        property bool sentryStatus_is_weakened: false
        
        // 23. 飞镖目标状态
        property int dartTarget_status_target_id: 0
        property int dartTarget_status_open: 1
        
        // 24. 哨兵控制结果
        property int sentryCtrlResult_command_id: 0
        property int sentryCtrlResult_result_code: 0
        
        // 25. 空中支援状态
        property int airSupport_status: 0
        property int airSupport_left_time: 0
        property int airSupport_cost_coins: 0
        property int airSupport_is_being_targeted: 0
        property int airSupport_shooter_status: 1
        
        // 26. 键鼠状态
      // 键鼠状态扩展
        property int input_mouseX: 0
        property int input_mouseY: 0
        property int input_mouseZ: 0
        property bool input_leftBtnDown: false
        property bool input_rightBtnDown: false
        property bool input_midBtnDown: false
        property int input_keyboardValue: 0
        property int input_lastMouseX: 0
        property int input_lastMouseY: 0
            // 累计位移（用于累加两次发送之间的所有移动）
        property int input_mouseDeltaX: 0
        property int input_mouseDeltaY: 0
        property int input_mouseDeltaZ: 0     // 新增：累计滚轮值
     // 鼠标捕获模式状态（新增）
        property bool input_mouseCaptureEnabled: false
      // 键盘位掩码常量（与 proto 完全一致）- 注意：必须小写开头
        readonly property int key_W:     1 << 0  // 1
        readonly property int key_S:     1 << 1  // 2
        readonly property int key_A:     1 << 2  // 4
        readonly property int key_D:     1 << 3  // 8
        readonly property int key_Shift: 1 << 4  // 16
        readonly property int key_Ctrl:  1 << 5  // 32
        readonly property int key_Q:     1 << 6  // 64
        readonly property int key_E:     1 << 7  // 128
        readonly property int key_R:     1 << 8  // 256
        readonly property int key_F:     1 << 9  // 512
        readonly property int key_G:     1 << 10 // 1024
        readonly property int key_Z:     1 << 11 // 2048
        readonly property int key_X:     1 << 12 // 4096
        readonly property int key_C:     1 << 13 // 8192
        readonly property int key_V:     1 << 14 // 16384
        readonly property int key_B:     1 << 15 // 32768

         property var allPressedKeys: ({})  // 格式: { keyCode: {name: "W", time: timestamp, isLongPress: false} }
    
            // 新增：键盘信息展示用字段
        property string keyInfoText: ""          // 显示当前按键信息
        property string comboKeysText: ""        // 组合键信息
        property bool isLongPress: false         // 是否长按
        property string mousePosText: ""         // 鼠标位置
        property string wheelInfoText: ""        // 滚轮信息
        // 27. MQTT发送参数
        property bool mqttSend_enableAutoSend: false
        property string mqttSend_customControlHexData: ""
        property int mqttSend_mapClickIsSendAll: 0
        property string mqttSend_mapClickRobotIdHex: "00000000000000"
        property int mqttSend_mapClickMode: 0
        property int mqttSend_mapClickEnemyId: 0
        property int mqttSend_mapClickAscii: 0
        property int mqttSend_mapClickType: 0
        property int mqttSend_mapClickScreenX: 0    
        property int mqttSend_mapClickScreenY: 0
        property real mqttSend_mapClickMapX: 0.0
        property real mqttSend_mapClickMapY: 0.0
        property int mqttSend_assemblyOperation: 1
        property int mqttSend_assemblyDifficulty: 1
        property int mqttSend_robotPerfShooter: 1
        property int mqttSend_robotPerfChassis: 1
        property int mqttSend_robotPerfSentryControl: 0
        property int mqttSend_commonCmdType: 0
        property int mqttSend_commonCmdParam: 0
        property int mqttSend_heroDeployMode: 0
        property int mqttSend_runeActivate: 0
        property int mqttSend_dartTargetId: 0
        property bool mqttSend_dartOpen: false
        property bool mqttSend_dartLaunchConfirm: false
        property int mqttSend_sentryCtrlCommandId: 0
        property int mqttSend_airSupportCommandId: 0
    }

    // ==============================================
    // 辅助函数
    // ==============================================
    // 比赛阶段数字转文字
    function getStageText(stage) {
        switch(stage) {
            case 0: return "未开始比赛";
            case 1: return "准备阶段";
            case 2: return "裁判系统自检(15s)";
            case 3: return "倒计时(5s)";
            case 4: return "比赛中";
            case 5: return "比赛结算中";
            default: return "未知阶段";
        }
    }
    
    // 获取当前机器人在数组中的索引
    function getCurrentRobotIndex() {
        var robotId = dataStore.robotStatic_robot_id || 0;
        
        // 红方机器人索引映射
        if (robotId === 1) return 0;  // 英雄
        if (robotId === 2) return 1;  // 工程
        if (robotId === 3) return 2;  // 步兵1
        if (robotId === 4) return 3;  // 步兵2
        if (robotId === 6) return 4;  // 空中
        if (robotId === 7) return 5;  // 哨兵
        
        // 蓝方机器人索引映射（红方6个之后）
        if (robotId === 101) return 6;  // 英雄
        if (robotId === 102) return 7;  // 工程
        if (robotId === 103) return 8;  // 步兵1
        if (robotId === 104) return 9;  // 步兵2
        if (robotId === 106) return 10; // 空中
        if (robotId === 107) return 11; // 哨兵
        
        return -1; // 无效ID
    }
    
    // 获取当前机器人的血量
    function getCurrentRobotHealth() {
        var index = getCurrentRobotIndex();
        var healthArray = dataStore.globalUnit_robot_health || [];
        
        if (index >= 0 && index < healthArray.length) {
            return healthArray[index];
        }
        return 0;
    }
    
    // 获取当前机器人的子弹数量
    function getCurrentRobotBullets() {
        var index = getCurrentRobotIndex();
        var bulletsArray = dataStore.globalUnit_robot_bullets || [];
        
        // 注意：robot_bullets 只包含己方机器人的子弹数量
        // 需要判断当前机器人是否是己方（红方）
        var robotId = dataStore.robotStatic_robot_id || 0;
        
        // 如果是红方机器人（己方），才显示子弹数量
        if (robotId >= 1 && robotId <= 11) {
            // 己方子弹数组索引与机器人索引一致
            if (index >= 0 && index < bulletsArray.length) {
                return bulletsArray[index];
            }
        }
        
        return 0; // 蓝方机器人（对方）不显示子弹数量
    }
  // 获取所有按下的键的显示文本（用于UI显示）
function getAllPressedKeysText() {
    var keys = [];
    var now = new Date().getTime();
    
    // 遍历所有按下的键
    for (var keyCode in dataStore.allPressedKeys) {
        var keyInfo = dataStore.allPressedKeys[keyCode];
        var pressTime = now - keyInfo.time;
        
        // 根据按下时长显示不同状态
        if (keyInfo.isLongPress) {
            keys.push(keyInfo.name + "[长按]");
        } else if (pressTime > 3000) {
            keys.push(keyInfo.name + "[" + Math.floor(pressTime/1000) + "s]");
        } else if (pressTime > 1000) {
            keys.push(keyInfo.name + "[" + Math.floor(pressTime/1000) + "s]");
        } else {
            keys.push(keyInfo.name);
        }
    }
    
    // 按键名排序，让显示更有序
    keys.sort();
    
    return keys.length > 0 ? keys.join(" + ") : "无按键按下";
}

// 获取协议定义的按键文本（用于显示位掩码对应的按键）
function getProtocolKeysText() {
    var keys = [];
    var value = dataStore.input_keyboardValue;
    
    if (value & dataStore.key_W) keys.push("W");
    if (value & dataStore.key_S) keys.push("S");
    if (value & dataStore.key_A) keys.push("A");
    if (value & dataStore.key_D) keys.push("D");
    if (value & dataStore.key_Shift) keys.push("Shift");
    if (value & dataStore.key_Ctrl) keys.push("Ctrl");
    if (value & dataStore.key_Q) keys.push("Q");
    if (value & dataStore.key_E) keys.push("E");
    if (value & dataStore.key_R) keys.push("R");
    if (value & dataStore.key_F) keys.push("F");
    if (value & dataStore.key_G) keys.push("G");
    if (value & dataStore.key_Z) keys.push("Z");
    if (value & dataStore.key_X) keys.push("X");
    if (value & dataStore.key_C) keys.push("C");
    if (value & dataStore.key_V) keys.push("V");
    if (value & dataStore.key_B) keys.push("B");
    
    return keys.length > 0 ? keys.join(" + ") : "无";
}

// 更新键盘信息展示文本
function updateKeyInfoText() {
    var allKeys = getAllPressedKeysText();
    var protocolKeys = getProtocolKeysText();
    
    dataStore.keyInfoText = allKeys + 
                           " | 协议: " + protocolKeys +
                           " | 值: " + dataStore.input_keyboardValue + 
                           " (0x" + dataStore.input_keyboardValue.toString(16) + ")";
}
    // 更新鼠标位置信息
// 更新鼠标位置信息
function updateMousePosText(x, y) {
    // 计算位移
    var dx = 0, dy = 0;
    if (dataStore.input_lastMouseX !== -1 && dataStore.input_lastMouseY !== -1) {
        dx = x - dataStore.input_lastMouseX;
        dy = y - dataStore.input_lastMouseY;
        
        // 累加到累计位移
        dataStore.input_mouseDeltaX += dx;
        dataStore.input_mouseDeltaY += dy;
        
        // 立即更新当前发送值（也可以等定时器处理）
        dataStore.input_mouseX = dataStore.input_mouseDeltaX;
        dataStore.input_mouseY = dataStore.input_mouseDeltaY;
    }
    
    // 更新记录的上次位置
    dataStore.input_lastMouseX = x;
    dataStore.input_lastMouseY = y;
    
    // 更新显示文本
    dataStore.mousePosText = `鼠标位置：X=${x}, Y=${y}`;
    
    if (dx !== 0 || dy !== 0) {
        console.log("鼠标移动 - 位移:", dx, dy, "累计:", dataStore.input_mouseDeltaX, dataStore.input_mouseDeltaY);
    }
}

    // 更新滚轮信息
function updateWheelInfoText(direction, delta) {
    const dirMap = {1: "上", 2: "下", 3: "左", 4: "右"};
    dataStore.wheelInfoText = `滚轮：${dirMap[direction] || "无"} | 角度：${delta}`;
    
    // 累加滚轮值
    dataStore.input_mouseDeltaZ += delta;
    
    // 立即更新当前发送值
    dataStore.input_mouseZ = dataStore.input_mouseDeltaZ;
    
    console.log("滚轮 - 角度:", delta, "累计:", dataStore.input_mouseDeltaZ);
}

        // ==============================================
        // 绑定全局输入过滤器信号
        // ==============================================
      // 在 Main.qml 中，找到 Connections 部分，替换为：
Connections {
    target: globalInputFilter
    
    // 处理相对位移信号（捕获模式）
    function onMouseMovedRelative(deltaX, deltaY) {
        dataStore.input_mouseX = deltaX;
        dataStore.input_mouseY = deltaY;
    }
    
    function onMousePressed(button, x, y) {
        if (button === 1) dataStore.input_leftBtnDown = true;
        else if (button === 2) dataStore.input_rightBtnDown = true;
        else if (button === 3) dataStore.input_midBtnDown = true;
    }
    
    function onMouseReleased(button, x, y) {
        if (button === 1) dataStore.input_leftBtnDown = false;
        else if (button === 2) dataStore.input_rightBtnDown = false;
        else if (button === 3) dataStore.input_midBtnDown = false;
    }
    
    function onMouseWheelScrolled(direction, delta, x, y) {
        var dirText = "";
        if (direction === 1) dirText = "上";
        else if (direction === 2) dirText = "下";
        else if (direction === 3) dirText = "左";
        else if (direction === 4) dirText = "右";
        dataStore.wheelInfoText = dirText + " (" + delta + ")";
        dataStore.input_mouseZ = delta;
    }
    
    // 键盘按下信号
    function onKeyPressed(key, keyName, text, isLongPress, comboKeys) {
        var bitValue = 0;
        var now = new Date().getTime();
        
        // 使用传入的 keyName（已经由 C++ 的 keyToName 函数转换）
        var displayName = keyName;
        
        // 记录所有按键（用于UI显示）- 使用 C++ 提供的 keyName
        dataStore.allPressedKeys[key] = {
            name: displayName,
            time: now,
            isLongPress: isLongPress,
            keyCode: key
        };
        
        // 将 Qt 键值转换为位掩码（只处理协议定义的16个按键）
        switch(key) {
        case Qt.Key_W: bitValue = dataStore.key_W; break;
        case Qt.Key_S: bitValue = dataStore.key_S; break;
        case Qt.Key_A: bitValue = dataStore.key_A; break;
        case Qt.Key_D: bitValue = dataStore.key_D; break;
        case Qt.Key_Shift: bitValue = dataStore.key_Shift; break;
        case Qt.Key_Control: bitValue = dataStore.key_Ctrl; break;
        case Qt.Key_Q: bitValue = dataStore.key_Q; break;
        case Qt.Key_E: bitValue = dataStore.key_E; break;
        case Qt.Key_R: bitValue = dataStore.key_R; break;
        case Qt.Key_F: bitValue = dataStore.key_F; break;
        case Qt.Key_G: bitValue = dataStore.key_G; break;
        case Qt.Key_Z: bitValue = dataStore.key_Z; break;
        case Qt.Key_X: bitValue = dataStore.key_X; break;
        case Qt.Key_C: bitValue = dataStore.key_C; break;
        case Qt.Key_V: bitValue = dataStore.key_V; break;
        case Qt.Key_B: bitValue = dataStore.key_B; break;
        default:
            // 非协议按键，只记录不计算位掩码
            updateKeyInfoText();
            console.log("非协议按键按下：", displayName);
            return;
        }
        
        // 使用位或运算设置按键值
        dataStore.input_keyboardValue |= bitValue;
        
        // 更新显示文本
        updateKeyInfoText();
        console.log("协议按键按下：", displayName, "当前值:", dataStore.input_keyboardValue);
    }

    // 键盘释放信号
    function onKeyReleased(key, keyName, text, comboKeys) {
        var bitValue = 0;
        
        // 使用传入的 keyName
        var displayName = keyName;
        
        // 从所有按键记录中移除
        delete dataStore.allPressedKeys[key];
        
        // 将 Qt 键值转换为位掩码（只处理协议定义的16个按键）
        switch(key) {
        case Qt.Key_W: bitValue = dataStore.key_W; break;
        case Qt.Key_S: bitValue = dataStore.key_S; break;
        case Qt.Key_A: bitValue = dataStore.key_A; break;
        case Qt.Key_D: bitValue = dataStore.key_D; break;
        case Qt.Key_Shift: bitValue = dataStore.key_Shift; break;
        case Qt.Key_Control: bitValue = dataStore.key_Ctrl; break;
        case Qt.Key_Q: bitValue = dataStore.key_Q; break;
        case Qt.Key_E: bitValue = dataStore.key_E; break;
        case Qt.Key_R: bitValue = dataStore.key_R; break;
        case Qt.Key_F: bitValue = dataStore.key_F; break;
        case Qt.Key_G: bitValue = dataStore.key_G; break;
        case Qt.Key_Z: bitValue = dataStore.key_Z; break;
        case Qt.Key_X: bitValue = dataStore.key_X; break;
        case Qt.Key_C: bitValue = dataStore.key_C; break;
        case Qt.Key_V: bitValue = dataStore.key_V; break;
        case Qt.Key_B: bitValue = dataStore.key_B; break;
        default:
            // 非协议按键，只更新显示
            updateKeyInfoText();
            console.log("非协议按键释放：", displayName);
            return;
        }
        
        // 使用位与和非运算清除按键
        dataStore.input_keyboardValue &= ~bitValue;
        
        // 更新显示文本
        updateKeyInfoText();
        console.log("协议按键释放：", displayName, "当前值:", dataStore.input_keyboardValue);
    }

        

        
    
    function onMouseCaptureEnabledChanged() {
         // 添加鼠标捕获模式状态（新增）
        dataStore.input_mouseCaptureEnabled=globalInputFilter.mouseCaptureEnabled;
        console.log("鼠标捕获模式:", dataStore.input_mouseCaptureEnabled ? "开启" : "关闭");
    }
}


    // ==============================================
    // 模块引入与数据绑定
    // ==============================================
    // 1. MQTT数据接收模块（同步到dataStore）
    MqttDataReceiver {
        id: mqttReceiver
        
        // GameStatus绑定
        onGameStatus_current_roundChanged: dataStore.gameStatus_current_round = mqttReceiver.gameStatus_current_round
        onGameStatus_total_roundsChanged: dataStore.gameStatus_total_rounds = mqttReceiver.gameStatus_total_rounds
        onGameStatus_red_scoreChanged: dataStore.gameStatus_red_score = mqttReceiver.gameStatus_red_score
        onGameStatus_blue_scoreChanged: dataStore.gameStatus_blue_score = mqttReceiver.gameStatus_blue_score
        onGameStatus_current_stageChanged: dataStore.gameStatus_current_stage = mqttReceiver.gameStatus_current_stage
        onGameStatus_stage_countdown_secChanged: dataStore.gameStatus_stage_countdown_sec = mqttReceiver.gameStatus_stage_countdown_sec
        onGameStatus_stage_elapsed_secChanged: dataStore.gameStatus_stage_elapsed_sec = mqttReceiver.gameStatus_stage_elapsed_sec
        onGameStatus_is_pausedChanged: dataStore.gameStatus_is_paused = mqttReceiver.gameStatus_is_paused

        // GlobalUnitStatus绑定
        onGlobalUnit_base_healthChanged: dataStore.globalUnit_base_health = mqttReceiver.globalUnit_base_health
        onGlobalUnit_base_statusChanged: dataStore.globalUnit_base_status = mqttReceiver.globalUnit_base_status
        onGlobalUnit_base_shieldChanged: dataStore.globalUnit_base_shield = mqttReceiver.globalUnit_base_shield
        onGlobalUnit_outpost_healthChanged: dataStore.globalUnit_outpost_health = mqttReceiver.globalUnit_outpost_health
        onGlobalUnit_outpost_statusChanged: dataStore.globalUnit_outpost_status = mqttReceiver.globalUnit_outpost_status
        onGlobalUnit_enemy_base_healthChanged: dataStore.globalUnit_enemy_base_health = mqttReceiver.globalUnit_enemy_base_health
        onGlobalUnit_enemy_base_statusChanged: dataStore.globalUnit_enemy_base_status = mqttReceiver.globalUnit_enemy_base_status
        onGlobalUnit_enemy_base_shieldChanged: dataStore.globalUnit_enemy_base_shield = mqttReceiver.globalUnit_enemy_base_shield
        onGlobalUnit_enemy_outpost_healthChanged: dataStore.globalUnit_enemy_outpost_health = mqttReceiver.globalUnit_enemy_outpost_health
        onGlobalUnit_enemy_outpost_statusChanged: dataStore.globalUnit_enemy_outpost_status = mqttReceiver.globalUnit_enemy_outpost_status
        onGlobalUnit_robot_healthChanged: dataStore.globalUnit_robot_health = mqttReceiver.globalUnit_robot_health
        onGlobalUnit_robot_bulletsChanged: dataStore.globalUnit_robot_bullets = mqttReceiver.globalUnit_robot_bullets
        onGlobalUnit_total_damage_allyChanged: dataStore.globalUnit_total_damage_ally = mqttReceiver.globalUnit_total_damage_ally
        onGlobalUnit_total_damage_enemyChanged: dataStore.globalUnit_total_damage_enemy = mqttReceiver.globalUnit_total_damage_enemy

        // GlobalLogisticsStatus绑定
        onGlobalLogistics_remaining_economyChanged: dataStore.globalLogistics_remaining_economy = mqttReceiver.globalLogistics_remaining_economy
        onGlobalLogistics_total_economy_obtainedChanged: dataStore.globalLogistics_total_economy_obtained = mqttReceiver.globalLogistics_total_economy_obtained
        onGlobalLogistics_tech_levelChanged: dataStore.globalLogistics_tech_level = mqttReceiver.globalLogistics_tech_level
        onGlobalLogistics_encryption_levelChanged: dataStore.globalLogistics_encryption_level = mqttReceiver.globalLogistics_encryption_level
       
        // GlobalSpecialMechanism绑定
        onGlobalSpecial_mechanism_idChanged: dataStore.globalSpecial_mechanism_id = mqttReceiver.globalSpecial_mechanism_id
        onGlobalSpecial_mechanism_time_secChanged: dataStore.globalSpecial_mechanism_time_sec = mqttReceiver.globalSpecial_mechanism_time_sec

        // Event绑定
        onEvent_idChanged: dataStore.event_id = mqttReceiver.event_id
        onEvent_paramChanged: dataStore.event_param = mqttReceiver.event_param

        // RobotInjuryStat绑定
        onRobotInjury_total_damageChanged: dataStore.robotInjury_total_damage = mqttReceiver.robotInjury_total_damage
        onRobotInjury_collision_damageChanged: dataStore.robotInjury_collision_damage = mqttReceiver.robotInjury_collision_damage
        onRobotInjury_small_projectile_damageChanged: dataStore.robotInjury_small_projectile_damage = mqttReceiver.robotInjury_small_projectile_damage
        onRobotInjury_large_projectile_damageChanged: dataStore.robotInjury_large_projectile_damage = mqttReceiver.robotInjury_large_projectile_damage
        onRobotInjury_dart_splash_damageChanged: dataStore.robotInjury_dart_splash_damage = mqttReceiver.robotInjury_dart_splash_damage
        onRobotInjury_module_offline_damageChanged: dataStore.robotInjury_module_offline_damage = mqttReceiver.robotInjury_module_offline_damage
        onRobotInjury_offline_damageChanged: dataStore.robotInjury_offline_damage = mqttReceiver.robotInjury_offline_damage
        onRobotInjury_penalty_damageChanged: dataStore.robotInjury_penalty_damage = mqttReceiver.robotInjury_penalty_damage
        onRobotInjury_server_kill_damageChanged: dataStore.robotInjury_server_kill_damage = mqttReceiver.robotInjury_server_kill_damage
        onRobotInjury_killer_idChanged: dataStore.robotInjury_killer_id = mqttReceiver.robotInjury_killer_id

        // RobotRespawnStatus绑定
        onRobotRespawn_is_pending_respawnChanged: dataStore.robotRespawn_is_pending_respawn = mqttReceiver.robotRespawn_is_pending_respawn
        onRobotRespawn_total_respawn_progressChanged: dataStore.robotRespawn_total_respawn_progress = mqttReceiver.robotRespawn_total_respawn_progress
        onRobotRespawn_current_respawn_progressChanged: dataStore.robotRespawn_current_respawn_progress = mqttReceiver.robotRespawn_current_respawn_progress
        onRobotRespawn_can_free_respawnChanged: dataStore.robotRespawn_can_free_respawn = mqttReceiver.robotRespawn_can_free_respawn
        onRobotRespawn_gold_cost_for_respawnChanged: dataStore.robotRespawn_gold_cost_for_respawn = mqttReceiver.robotRespawn_gold_cost_for_respawn
        onRobotRespawn_can_pay_for_respawnChanged: dataStore.robotRespawn_can_pay_for_respawn = mqttReceiver.robotRespawn_can_pay_for_respawn

        // RobotStaticStatus绑定
        onRobotStatic_connection_stateChanged: dataStore.robotStatic_connection_state = mqttReceiver.robotStatic_connection_state
        onRobotStatic_field_stateChanged: dataStore.robotStatic_field_state = mqttReceiver.robotStatic_field_state
        onRobotStatic_alive_stateChanged: dataStore.robotStatic_alive_state = mqttReceiver.robotStatic_alive_state
        onRobotStatic_robot_idChanged: dataStore.robotStatic_robot_id = mqttReceiver.robotStatic_robot_id
        onRobotStatic_robot_typeChanged: dataStore.robotStatic_robot_type = mqttReceiver.robotStatic_robot_type
        onRobotStatic_performance_system_shooterChanged: dataStore.robotStatic_performance_system_shooter = mqttReceiver.robotStatic_performance_system_shooter
        onRobotStatic_performance_system_chassisChanged: dataStore.robotStatic_performance_system_chassis = mqttReceiver.robotStatic_performance_system_chassis
        onRobotStatic_levelChanged: dataStore.robotStatic_level = mqttReceiver.robotStatic_level
        onRobotStatic_max_healthChanged: dataStore.robotStatic_max_health = mqttReceiver.robotStatic_max_health
        onRobotStatic_max_heatChanged: dataStore.robotStatic_max_heat = mqttReceiver.robotStatic_max_heat
        onRobotStatic_heat_cooldown_rateChanged: dataStore.robotStatic_heat_cooldown_rate = mqttReceiver.robotStatic_heat_cooldown_rate
        onRobotStatic_max_powerChanged: dataStore.robotStatic_max_power = mqttReceiver.robotStatic_max_power
        onRobotStatic_max_buffer_energyChanged: dataStore.robotStatic_max_buffer_energy = mqttReceiver.robotStatic_max_buffer_energy
        onRobotStatic_max_chassis_energyChanged: dataStore.robotStatic_max_chassis_energy = mqttReceiver.robotStatic_max_chassis_energy

        // RobotDynamicStatus绑定
        onRobotDynamic_current_healthChanged: dataStore.robotDynamic_current_health = mqttReceiver.robotDynamic_current_health
        onRobotDynamic_current_heatChanged: dataStore.robotDynamic_current_heat = mqttReceiver.robotDynamic_current_heat
        onRobotDynamic_last_projectile_fire_rateChanged: dataStore.robotDynamic_last_projectile_fire_rate = mqttReceiver.robotDynamic_last_projectile_fire_rate
        onRobotDynamic_current_chassis_energyChanged: dataStore.robotDynamic_current_chassis_energy = mqttReceiver.robotDynamic_current_chassis_energy
        onRobotDynamic_current_buffer_energyChanged: dataStore.robotDynamic_current_buffer_energy = mqttReceiver.robotDynamic_current_buffer_energy
        onRobotDynamic_current_experienceChanged: dataStore.robotDynamic_current_experience = mqttReceiver.robotDynamic_current_experience
        onRobotDynamic_experience_for_upgradeChanged: dataStore.robotDynamic_experience_for_upgrade = mqttReceiver.robotDynamic_experience_for_upgrade
        onRobotDynamic_total_projectiles_firedChanged: dataStore.robotDynamic_total_projectiles_fired = mqttReceiver.robotDynamic_total_projectiles_fired
        onRobotDynamic_remaining_ammoChanged: dataStore.robotDynamic_remaining_ammo = mqttReceiver.robotDynamic_remaining_ammo
        onRobotDynamic_is_out_of_combatChanged: dataStore.robotDynamic_is_out_of_combat = mqttReceiver.robotDynamic_is_out_of_combat
        onRobotDynamic_out_of_combat_countdownChanged: dataStore.robotDynamic_out_of_combat_countdown = mqttReceiver.robotDynamic_out_of_combat_countdown
        onRobotDynamic_can_remote_healChanged: dataStore.robotDynamic_can_remote_heal = mqttReceiver.robotDynamic_can_remote_heal
        onRobotDynamic_can_remote_ammoChanged: dataStore.robotDynamic_can_remote_ammo = mqttReceiver.robotDynamic_can_remote_ammo

        // RobotModuleStatus绑定
        onRobotModule_power_managerChanged: dataStore.robotModule_power_manager = mqttReceiver.robotModule_power_manager
        onRobotModule_rfidChanged: dataStore.robotModule_rfid = mqttReceiver.robotModule_rfid
        onRobotModule_light_stripChanged: dataStore.robotModule_light_strip = mqttReceiver.robotModule_light_strip
        onRobotModule_small_shooterChanged: dataStore.robotModule_small_shooter = mqttReceiver.robotModule_small_shooter
        onRobotModule_big_shooterChanged: dataStore.robotModule_big_shooter = mqttReceiver.robotModule_big_shooter
        onRobotModule_uwbChanged: dataStore.robotModule_uwb = mqttReceiver.robotModule_uwb
        onRobotModule_armorChanged: dataStore.robotModule_armor = mqttReceiver.robotModule_armor
        onRobotModule_video_transmissionChanged: dataStore.robotModule_video_transmission = mqttReceiver.robotModule_video_transmission
        onRobotModule_capacitorChanged: dataStore.robotModule_capacitor = mqttReceiver.robotModule_capacitor
        onRobotModule_main_controllerChanged: dataStore.robotModule_main_controller = mqttReceiver.robotModule_main_controller
        onRobotModule_laser_detection_moduleChanged: dataStore.robotModule_laser_detection_module = mqttReceiver.robotModule_laser_detection_module

        // RobotPosition绑定
        onRobotPosition_xChanged: dataStore.robotPosition_x = mqttReceiver.robotPosition_x
        onRobotPosition_yChanged: dataStore.robotPosition_y = mqttReceiver.robotPosition_y
        onRobotPosition_zChanged: dataStore.robotPosition_z = mqttReceiver.robotPosition_z
        onRobotPosition_yawChanged: dataStore.robotPosition_yaw = mqttReceiver.robotPosition_yaw

        // Buff绑定
        onBuff_robot_idChanged: dataStore.buff_robot_id = mqttReceiver.buff_robot_id
        onBuff_typeChanged: dataStore.buff_type = mqttReceiver.buff_type
        onBuff_levelChanged: dataStore.buff_level = mqttReceiver.buff_level
        onBuff_max_timeChanged: dataStore.buff_max_time = mqttReceiver.buff_max_time
        onBuff_left_timeChanged: dataStore.buff_left_time = mqttReceiver.buff_left_time

        // PenaltyInfo绑定
        onPenalty_typeChanged: dataStore.penalty_type = mqttReceiver.penalty_type
        onPenalty_effect_secChanged: dataStore.penalty_effect_sec = mqttReceiver.penalty_effect_sec
        onPenalty_total_penalty_numChanged: dataStore.penalty_total_penalty_num = mqttReceiver.penalty_total_penalty_num

        // RobotPathPlanInfo绑定
        onRobotPath_intentionChanged: dataStore.robotPath_intention = mqttReceiver.robotPath_intention
        onRobotPath_start_pos_xChanged: dataStore.robotPath_start_pos_x = mqttReceiver.robotPath_start_pos_x
        onRobotPath_start_pos_yChanged: dataStore.robotPath_start_pos_y = mqttReceiver.robotPath_start_pos_y
        onRobotPath_offset_xChanged: dataStore.robotPath_offset_x = mqttReceiver.robotPath_offset_x
        onRobotPath_offset_yChanged: dataStore.robotPath_offset_y = mqttReceiver.robotPath_offset_y
        onRobotPath_sender_idChanged: dataStore.robotPath_sender_id = mqttReceiver.robotPath_sender_id

        // RadarInfoToClient绑定
        onRadar_target_robot_idChanged: dataStore.radar_target_robot_id = mqttReceiver.radar_target_robot_id
        onRadar_target_pos_xChanged: dataStore.radar_target_pos_x = mqttReceiver.radar_target_pos_x
        onRadar_target_pos_yChanged: dataStore.radar_target_pos_y = mqttReceiver.radar_target_pos_y
        onRadar_toward_angleChanged: dataStore.radar_toward_angle = mqttReceiver.radar_toward_angle
        onRadar_is_high_lightChanged: dataStore.radar_is_high_light = mqttReceiver.radar_is_high_light

        // CustomByteBlock绑定
        onCustomByteBlock_dataChanged: dataStore.customByteBlock_data = mqttReceiver.customByteBlock_data

        // TechCoreMotionStateSync绑定
        onTechCore_maximum_difficulty_levelChanged: dataStore.techCore_maximum_difficulty_level = mqttReceiver.techCore_maximum_difficulty_level
        onTechCore_statusChanged: dataStore.techCore_status = mqttReceiver.techCore_status
        onTechCore_enemy_core_statusChanged: dataStore.techCore_enemy_core_status = mqttReceiver.techCore_enemy_core_status
        onTechCore_remain_time_allChanged: dataStore.techCore_remain_time_all = mqttReceiver.techCore_remain_time_all
        onTechCore_remain_time_stepChanged: dataStore.techCore_remain_time_step = mqttReceiver.techCore_remain_time_step

        // RobotPerformanceSelectionSync绑定
        onRobotPerfSync_shooterChanged: dataStore.robotPerfSync_shooter = mqttReceiver.robotPerfSync_shooter
        onRobotPerfSync_chassisChanged: dataStore.robotPerfSync_chassis = mqttReceiver.robotPerfSync_chassis
        onRobotPerfSync_sentry_controlChanged: dataStore.robotPerfSync_sentry_control = mqttReceiver.robotPerfSync_sentry_control

        // DeployModeStatusSync绑定
        onDeployMode_current_statusChanged: dataStore.deployMode_current_status = mqttReceiver.deployMode_current_status

        // RuneStatusSync绑定
        onRuneStatus_rune_statusChanged: dataStore.runeStatus_rune_status = mqttReceiver.runeStatus_rune_status
        onRuneStatus_activated_armsChanged: dataStore.runeStatus_activated_arms = mqttReceiver.runeStatus_activated_arms
        onRuneStatus_average_ringsChanged: dataStore.runeStatus_average_rings = mqttReceiver.runeStatus_average_rings

        // SentryStatusSync绑定
        onSentryStatus_posture_idChanged: dataStore.sentryStatus_posture_id = mqttReceiver.sentryStatus_posture_id
        onSentryStatus_is_weakenedChanged: dataStore.sentryStatus_is_weakened = mqttReceiver.sentryStatus_is_weakened

        // DartSelectTargetStatusSync绑定
        onDartTarget_status_target_idChanged: dataStore.dartTarget_status_target_id = mqttReceiver.dartTarget_status_target_id
        onDartTarget_status_openChanged: dataStore.dartTarget_status_open = mqttReceiver.dartTarget_status_open

        // SentryCtrlResult绑定
        onSentryCtrlResult_command_idChanged: dataStore.sentryCtrlResult_command_id = mqttReceiver.sentryCtrlResult_command_id
        onSentryCtrlResult_result_codeChanged: dataStore.sentryCtrlResult_result_code = mqttReceiver.sentryCtrlResult_result_code

        // AirSupportStatusSync绑定
        onAirSupport_statusChanged: dataStore.airSupport_status = mqttReceiver.airSupport_status
        onAirSupport_left_timeChanged: dataStore.airSupport_left_time = mqttReceiver.airSupport_left_time
        onAirSupport_cost_coinsChanged: dataStore.airSupport_cost_coins = mqttReceiver.airSupport_cost_coins
        onAirSupport_is_being_targetedChanged: dataStore.airSupport_is_being_targeted = mqttReceiver.airSupport_is_being_targeted
        onAirSupport_shooter_statusChanged: dataStore.airSupport_shooter_status = mqttReceiver.airSupport_shooter_status
    }

    // 2. MQTT数据发送模块
    MqttDataSender {
        id: mqttSender
        
        // 基础配置绑定
        enableAutoSend: dataStore.mqttSend_enableAutoSend
        
        // 键鼠控制属性绑定
        mouseX: dataStore.input_mouseX
        mouseY: dataStore.input_mouseY
        mouseZ: dataStore.input_mouseZ
        leftBtnDown: dataStore.input_leftBtnDown
        rightBtnDown: dataStore.input_rightBtnDown
        midBtnDown: dataStore.input_midBtnDown
        keyboardValue: dataStore.input_keyboardValue

        // 自定义控制数据绑定
        customControlHexData: dataStore.mqttSend_customControlHexData
        
        // 地图点击标记属性绑定
        mapClickIsSendAll: dataStore.mqttSend_mapClickIsSendAll
        mapClickRobotIdHex: dataStore.mqttSend_mapClickRobotIdHex
        mapClickMode: dataStore.mqttSend_mapClickMode
        mapClickEnemyId: dataStore.mqttSend_mapClickEnemyId
        mapClickAscii: dataStore.mqttSend_mapClickAscii
        mapClickType: dataStore.mqttSend_mapClickType
        mapClickScreenX: dataStore.mqttSend_mapClickScreenX
        mapClickScreenY: dataStore.mqttSend_mapClickScreenY
        mapClickMapX: dataStore.mqttSend_mapClickMapX
        mapClickMapY: dataStore.mqttSend_mapClickMapY
        
        // 工程装配指令绑定
        assemblyOperation: dataStore.mqttSend_assemblyOperation
        assemblyDifficulty: dataStore.mqttSend_assemblyDifficulty
        
        // 性能体系选择绑定
        robotPerfShooter: dataStore.mqttSend_robotPerfShooter
        robotPerfChassis: dataStore.mqttSend_robotPerfChassis
        robotPerfSentryControl: dataStore.mqttSend_robotPerfSentryControl
        
        // 通用指令绑定
        commonCmdType: dataStore.mqttSend_commonCmdType
        commonCmdParam: dataStore.mqttSend_commonCmdParam
        
        // 英雄部署模式绑定
        heroDeployMode: dataStore.mqttSend_heroDeployMode
        
        // 能量机关激活绑定
        runeActivate: dataStore.mqttSend_runeActivate
        
        // 飞镖控制指令绑定
        dartTargetId: dataStore.mqttSend_dartTargetId
        dartOpen: dataStore.mqttSend_dartOpen
        dartLaunchConfirm: dataStore.mqttSend_dartLaunchConfirm
        
        // 哨兵控制指令绑定
        sentryCtrlCommandId: dataStore.mqttSend_sentryCtrlCommandId
        
        // 空中支援指令绑定
        airSupportCommandId: dataStore.mqttSend_airSupportCommandId
         onDataSent: {
        if (cmdType === "KeyboardMouse") {
            // 发送成功后重置累计位移和滚轮值
            dataStore.input_mouseDeltaX = 0;
            dataStore.input_mouseDeltaY = 0;
            dataStore.input_mouseDeltaZ = 0;
            dataStore.input_mouseX = 0;
            dataStore.input_mouseY = 0;
            dataStore.input_mouseZ = 0;
            console.log("键鼠数据发送成功，重置累计位移和滚轮值");
        }
    }

        
    }

    // ==============================================
    // 引入UI绘制层（传递主窗口引用）
    // ==============================================
    UI {
        id: uiLayer
        anchors.fill: parent
        // 传递核心数据、函数和主窗口引用给UI层
        dataStore: dataStore
        getStageText: root.getStageText
        // updateKeyInfoText: root.updateKeyInfoText
        mainWindow: root  // 新增：传递主窗口引用，用于窗口控制
       
    }

}