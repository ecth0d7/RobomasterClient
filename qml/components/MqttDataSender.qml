import QtQuick 6.2
import QtQml 6.2

// MQTT数据发送模块（整合所有指令类型发送逻辑）
// 协议参考：RoboMaster 2026 机甲大师高校系列赛通信协议 V1.2.0
Item {
    id: root

    // ========== 全局配置属性 ==========
    property bool enableAutoSend: false      // 是否启用自动定时发送

    // ========== 各指令发送间隔配置（严格遵循协议定义：Hz → ms） ==========
    // 1. 键鼠控制/自定义控制：75Hz → 13.33ms（协议规定最高发送频率）
    property int keyboardMouseSendInterval: Math.round(1000 / 75)
    property int customControlSendInterval: Math.round(1000 / 75)
    
    // 2. 工程装配/性能体系/英雄部署/能量机关/飞镖/哨兵控制/空中支援：1Hz → 1000ms
    property int assemblyCommandSendInterval: 1000
    property int robotPerformanceSendInterval: 1000
    property int heroDeployModeSendInterval: 1000
    property int runeActivateSendInterval: 1000
    property int dartCommandSendInterval: 1000
    property int sentryCtrlSendInterval: 1000
    property int airSupportSendInterval: 1000
    
    // 3. 通用指令：最高10Hz → 100ms（触发式，协议限制最高频率）
    property int commonCommandSendInterval: 100
    
    // 4. 地图点击标记：触发式（云台手≥0.5s/次，半自动≥3s/次）
    property int mapClickMinInterval: 500       // 云台手最小间隔（ms）
    property int mapClickSemiAutoMinInterval: 3000 // 半自动操作手最小间隔（ms）
    property bool isSemiAutoMode: false         // 是否为半自动操作模式

    // ========== 1. 键鼠控制属性（定时发送） ==========
    property int mouseX: 0                  // 鼠标X位移
    property int mouseY: 0                  // 鼠标Y位移
    property int mouseZ: 0                  // 鼠标滚轮值
    property bool leftBtnDown: false        // 鼠标左键按下状态
    property bool rightBtnDown: false       // 鼠标右键按下状态
    property bool midBtnDown: false         // 鼠标中键按下状态
    property int keyboardValue: 0           // 键盘按键值（仅低16位有效）

    // ========== 2. 自定义控制数据属性 ==========
    property string customControlHexData: "" // 自定义控制数据（16进制字符串）
    property int customControlMaxLen: 30     // 最大数据长度（协议限制）

    // ========== 3. 云台手地图点击标记属性 ==========
    property int mapClickIsSendAll: 0       // 原uint → 改为int（QML兼容）
    property string mapClickRobotIdHex: ""   // 机器人ID（7字节16进制字符串）
    property int mapClickMode: 0            // 原uint → 改为int
    property int mapClickEnemyId: 0         // 原uint → 改为int
    property int mapClickAscii: 0           // 原uint → 改为int
    property int mapClickType: 0            // 原uint → 改为int
    property int mapClickScreenX: 0         // 原uint → 改为int
    property int mapClickScreenY: 0         // 原uint → 改为int
    property real mapClickMapX: 0.0          // 地图X坐标（浮点）
    property real mapClickMapY: 0.0          // 地图Y坐标（浮点）
    property int lastMapClickTime: 0        // 上一次地图点击发送时间（ms）

    // ========== 4. 工程装配指令属性 ==========
    property int assemblyOperation: 1      // 原uint → 改为int
    property int assemblyDifficulty: 1      // 原uint → 改为int（1-4）

    // ========== 5. 步兵/英雄性能体系选择属性 ==========
    property int robotPerfShooter: 1        // 原uint → 改为int（1-4）
    property int robotPerfChassis: 1        // 原uint → 改为int（1-4）
    property int robotPerfSentryControl: 0  // 原uint → 改为int（0/1）

    // ========== 6. 机器人通用指令属性 ==========
    property int commonCmdType: 0           // 原uint → 改为int（1-6）
    property int commonCmdParam: 0          // 原uint → 改为int

    // ========== 7. 英雄部署模式属性 ==========
    property int heroDeployMode: 0       // 原uint → 改为int（0-退出 1-进入）

    // ========== 8. 能量机关激活属性 ==========
    property int runeActivate: 0            // 原uint → 改为int（0-取消 1-激活）

    // ========== 9. 飞镖控制指令属性 ==========
    property int dartTargetId: 0            // 原uint → 改为int（1-5）
    property bool dartOpen: false            // 闸门状态
    property bool dartLaunchConfirm: false   // 发射确认

    // ========== 10. 哨兵控制指令属性 ==========
    property int sentryCtrlCommandId: 0     // 原uint → 改为int（0-10）

    // ========== 11. 空中支援指令属性 ==========
    property int airSupportCommandId: 0     // 原uint → 改为int（1-3）

    // ========== 通用信号 ==========
    signal dataSent(string cmdType)          // 数据发送完成信号（携带指令类型）
    signal sendFailed(string cmdType, string reason) // 发送失败信号

    // ========== 各指令独立定时器（严格遵循协议频率） ==========
    // 1. 键鼠控制定时器（75Hz）
    Timer {
        id: keyboardMouseTimer
        interval: root.keyboardMouseSendInterval
        repeat: true
        running: root.enableAutoSend
        onTriggered: sendKeyboardMouseData()
    }

    // 2. 自定义控制定时器（75Hz）
    Timer {
        id: customControlTimer
        interval: root.customControlSendInterval
        repeat: true
        running: root.enableAutoSend
        onTriggered: sendCustomControlData()
    }

    // 3. 工程装配指令定时器（1Hz）
    Timer {
        id: assemblyCommandTimer
        interval: root.assemblyCommandSendInterval
        repeat: true
        running: root.enableAutoSend
        onTriggered: sendAssemblyCommand()
    }

    // 4. 性能体系选择定时器（1Hz）
    Timer {
        id: robotPerformanceTimer
        interval: root.robotPerformanceSendInterval
        repeat: true
        running: root.enableAutoSend
        onTriggered: sendRobotPerformanceCommand()
    }

    // 5. 英雄部署模式定时器（1Hz）
    Timer {
        id: heroDeployModeTimer
        interval: root.heroDeployModeSendInterval
        repeat: true
        running: root.enableAutoSend
        onTriggered: sendHeroDeployModeCommand()
    }

    // 6. 能量机关激活定时器（1Hz）
    Timer {
        id: runeActivateTimer
        interval: root.runeActivateSendInterval
        repeat: true
        running: root.enableAutoSend
        onTriggered: sendRuneActivateCommand()
    }

    // 7. 飞镖控制定时器（1Hz）
    Timer {
        id: dartCommandTimer
        interval: root.dartCommandSendInterval
        repeat: true
        running: root.enableAutoSend
        onTriggered: sendDartCommand()
    }

    // 8. 哨兵控制定时器（1Hz）
    Timer {
        id: sentryCtrlTimer
        interval: root.sentryCtrlSendInterval
        repeat: true
        running: root.enableAutoSend
        onTriggered: sendSentryCtrlCommand()
    }

    // 9. 空中支援定时器（1Hz）
    Timer {
        id: airSupportTimer
        interval: root.airSupportSendInterval
        repeat: true
        running: root.enableAutoSend
        onTriggered: sendAirSupportCommand()
    }

    // 10. 通用指令定时器（最高10Hz）
    Timer {
        id: commonCommandTimer
        interval: root.commonCommandSendInterval
        repeat: true
        running: root.enableAutoSend
        onTriggered: sendCommonCommand()
    }

    // ========== 1. 发送键鼠控制数据 ==========
   // 修改 sendKeyboardMouseData 函数
function sendKeyboardMouseData() {
    if (!keyboardMouseHandler) {
        root.sendFailed("KeyboardMouse", "处理器实例不存在");
        return;
    }

    // 只在有位移或按键变化时发送
    if (root.mouseX === 0 && root.mouseY === 0 && root.mouseZ === 0 && 
        !root.leftBtnDown && !root.rightBtnDown && !root.midBtnDown && 
        root.keyboardValue === 0) {
        return;
    }

    var dataMap = {
        mouseX: root.mouseX,
        mouseY: root.mouseY,
        mouseZ: root.mouseZ,
        leftBtnDown: root.leftBtnDown,
        rightBtnDown: root.rightBtnDown,
        midBtnDown: root.midBtnDown,
        keyboardValue: root.keyboardValue
    };

    try {
        keyboardMouseHandler.parseFromQmlMap(dataMap);
        keyboardMouseHandler.send();
        root.dataSent("KeyboardMouse");
        
        // 注意：不要在这里重置 mouseX/mouseY，让 GlobalInputFilter 处理
    } catch (e) {
        root.sendFailed("KeyboardMouse", e.toString());
        console.error("[键鼠发送失败]", e);
    }
}

    // ========== 2. 发送自定义控制数据 ==========
    function sendCustomControlData() {
        if (!customControlHandler) {
            root.sendFailed("CustomControl", "处理器实例不存在");
            return;
        }

        // 协议校验：自定义数据最大30字节（60个16进制字符）
        if (root.customControlHexData.length > 60) {
            root.sendFailed("CustomControl", "数据长度超过协议限制（最大30字节）");
            console.error("[自定义数据校验失败] 长度=", root.customControlHexData.length/2, "字节（最大30字节）");
            return;
        }

        var dataMap = {
            customData: root.customControlHexData
        };

        try {
            customControlHandler.parseFromQmlMap(dataMap);
            customControlHandler.send();
            root.dataSent("CustomControl");
            console.log("[自定义数据发送] 长度=", root.customControlHexData.length/2, "字节");
        } catch (e) {
            root.sendFailed("CustomControl", e.toString());
            console.error("[自定义数据发送失败]", e);
        }
    }

    // ========== 3. 发送云台手地图点击标记数据（带频率限制） ==========
    function sendMapClickInfo() {
        // 协议频率限制校验
        var currentTime = new Date().getTime();
        var minInterval = root.isSemiAutoMode ? root.mapClickSemiAutoMinInterval : root.mapClickMinInterval;
        if (currentTime - root.lastMapClickTime < minInterval) {
            root.sendFailed("MapClickInfo", "发送频率超过协议限制（最小间隔" + minInterval + "ms）");
            console.warn("[地图点击标记] 发送频率超限，已忽略本次发送");
            return;
        }

        if (!mapClickInfoHandler) {
            root.sendFailed("MapClickInfo", "处理器实例不存在");
            return;
        }

        // 协议校验：robot_id固定7字节（14个16进制字符）
        if (root.mapClickRobotIdHex.length !== 14) {
            root.sendFailed("MapClickInfo", "robot_id长度不符合协议（必须7字节/14位16进制）");
            console.error("[地图点击标记校验失败] robot_id长度=", root.mapClickRobotIdHex.length, "（需14位）");
            return;
        }

        var dataMap = {
            isSendAll: root.mapClickIsSendAll,
            robotId: root.mapClickRobotIdHex,
            mode: root.mapClickMode,
            enemyId: root.mapClickEnemyId,
            ascii: root.mapClickAscii,
            type: root.mapClickType,
            screenX: root.mapClickScreenX,
            screenY: root.mapClickScreenY,
            mapX: root.mapClickMapX,
            mapY: root.mapClickMapY
        };

        try {
            mapClickInfoHandler.parseFromQmlMap(dataMap);
            mapClickInfoHandler.send();
            root.lastMapClickTime = currentTime; // 更新最后发送时间
            root.dataSent("MapClickInfo");
            console.log("[地图点击标记发送] 坐标(", root.mapClickMapX, ",", root.mapClickMapY, ")");
        } catch (e) {
            root.sendFailed("MapClickInfo", e.toString());
            console.error("[地图点击标记发送失败]", e);
        }
    }

    // ========== 4. 发送工程装配指令 ==========
    function sendAssemblyCommand() {
        if (!assemblyCommandHandler) {
            root.sendFailed("AssemblyCommand", "处理器实例不存在");
            return;
        }

        // 协议校验：操作类型和难度范围
        if (root.assemblyOperation < 1 || root.assemblyOperation > 2) {
            root.sendFailed("AssemblyCommand", "操作类型非法（仅1=确认装配/2=取消装配）");
            console.error("[工程装配校验失败] 操作类型=", root.assemblyOperation);
            return;
        }
        if (root.assemblyDifficulty < 1 || root.assemblyDifficulty > 4) {
            root.sendFailed("AssemblyCommand", "难度等级非法（仅1-4）");
            console.error("[工程装配校验失败] 难度等级=", root.assemblyDifficulty);
            return;
        }

        var dataMap = {
            operation: root.assemblyOperation,
            difficulty: root.assemblyDifficulty
        };

        try {
            assemblyCommandHandler.parseFromQmlMap(dataMap);
            assemblyCommandHandler.send();
            root.dataSent("AssemblyCommand");
            console.log("[工程装配指令发送] 操作=", root.assemblyOperation, "难度=", root.assemblyDifficulty);
        } catch (e) {
            root.sendFailed("AssemblyCommand", e.toString());
            console.error("[工程装配指令发送失败]", e);
        }
    }

    // ========== 5. 发送步兵/英雄性能体系选择指令 ==========
    function sendRobotPerformanceCommand() {
        if (!robotPerformanceHandler) {
            root.sendFailed("RobotPerformance", "处理器实例不存在");
            return;
        }

        // 协议校验：性能体系范围
        if (root.robotPerfShooter < 1 || root.robotPerfShooter > 4) {
            root.sendFailed("RobotPerformance", "发射机构性能体系非法（仅1-4）");
            console.error("[性能体系校验失败] 发射机构=", root.robotPerfShooter);
            return;
        }
        if (root.robotPerfChassis < 1 || root.robotPerfChassis > 4) {
            root.sendFailed("RobotPerformance", "底盘性能体系非法（仅1-4）");
            console.error("[性能体系校验失败] 底盘=", root.robotPerfChassis);
            return;
        }
        if (root.robotPerfSentryControl < 0 || root.robotPerfSentryControl > 1) {
            root.sendFailed("RobotPerformance", "哨兵控制方式非法（仅0=自动/1=半自动）");
            console.error("[性能体系校验失败] 哨兵控制=", root.robotPerfSentryControl);
            return;
        }

        var dataMap = {
            shooter: root.robotPerfShooter,
            chassis: root.robotPerfChassis,
            sentryControl: root.robotPerfSentryControl
        };

        try {
            robotPerformanceHandler.parseFromQmlMap(dataMap);
            robotPerformanceHandler.send();
            root.dataSent("RobotPerformance");
            console.log("[性能体系指令发送] 发射机构=", root.robotPerfShooter, "底盘=", root.robotPerfChassis);
        } catch (e) {
            root.sendFailed("RobotPerformance", e.toString());
            console.error("[性能体系指令发送失败]", e);
        }
    }

    // ========== 6. 发送机器人通用指令 ==========
    function sendCommonCommand() {
        if (!commonCommandHandler) {
            root.sendFailed("CommonCommand", "处理器实例不存在");
            return;
        }

        // 协议校验：指令类型范围
        if (root.commonCmdType < 1 || root.commonCmdType > 6) {
            root.sendFailed("CommonCommand", "指令类型非法（仅1-6）");
            console.error("[通用指令校验失败] 类型=", root.commonCmdType);
            return;
        }

        var dataMap = {
            cmdType: root.commonCmdType,
            param: root.commonCmdParam
        };

        try {
            commonCommandHandler.parseFromQmlMap(dataMap);
            commonCommandHandler.send();
            root.dataSent("CommonCommand");
            console.log("[通用指令发送] 类型=", root.commonCmdType, "参数=", root.commonCmdParam);
        } catch (e) {
            root.sendFailed("CommonCommand", e.toString());
            console.error("[通用指令发送失败]", e);
        }
    }

    // ========== 7. 发送英雄部署模式指令 ==========
    function sendHeroDeployModeCommand() {
        if (!heroDeployModeHandler) {
            root.sendFailed("HeroDeployMode", "处理器实例不存在");
            return;
        }

        // 协议校验：部署模式范围
        if (root.heroDeployMode < 0 || root.heroDeployMode > 1) {
            root.sendFailed("HeroDeployMode", "部署模式非法（仅0=退出/1=进入）");
            console.error("[英雄部署校验失败] 模式=", root.heroDeployMode);
            return;
        }

        var dataMap = {
            mode: root.heroDeployMode
        };

        try {
            heroDeployModeHandler.parseFromQmlMap(dataMap);
            heroDeployModeHandler.send();
            root.dataSent("HeroDeployMode");
            console.log("[英雄部署模式发送] 模式=", root.heroDeployMode === 1 ? "进入" : "退出");
        } catch (e) {
            root.sendFailed("HeroDeployMode", e.toString());
            console.error("[英雄部署模式发送失败]", e);
        }
    }

    // ========== 8. 发送能量机关激活指令 ==========
    function sendRuneActivateCommand() {
        if (!runeActivateHandler) {
            root.sendFailed("RuneActivate", "处理器实例不存在");
            return;
        }

        // 协议校验：激活状态范围
        if (root.runeActivate < 0 || root.runeActivate > 1) {
            root.sendFailed("RuneActivate", "激活状态非法（仅0=取消/1=激活）");
            console.error("[能量机关校验失败] 状态=", root.runeActivate);
            return;
        }

        var dataMap = {
            activate: root.runeActivate
        };

        try {
            runeActivateHandler.parseFromQmlMap(dataMap);
            runeActivateHandler.send();
            root.dataSent("RuneActivate");
            console.log("[能量机关激活发送] 状态=", root.runeActivate === 1 ? "激活" : "取消");
        } catch (e) {
            root.sendFailed("RuneActivate", e.toString());
            console.error("[能量机关激活发送失败]", e);
        }
    }

    // ========== 9. 发送飞镖控制指令 ==========
    function sendDartCommand() {
        if (!dartCommandHandler) {
            root.sendFailed("DartCommand", "处理器实例不存在");
            return;
        }

        // 协议校验：目标ID范围
        if (root.dartTargetId < 1 || root.dartTargetId > 5) {
            root.sendFailed("DartCommand", "目标ID非法（仅1-5）");
            console.error("[飞镖控制校验失败] 目标ID=", root.dartTargetId);
            return;
        }

        var dataMap = {
            targetId: root.dartTargetId,
            open: root.dartOpen,
            launchConfirm: root.dartLaunchConfirm
        };

        try {
            dartCommandHandler.parseFromQmlMap(dataMap);
            dartCommandHandler.send();
            root.dataSent("DartCommand");
            console.log("[飞镖控制发送] 目标ID=", root.dartTargetId, "发射确认=", root.dartLaunchConfirm);
        } catch (e) {
            root.sendFailed("DartCommand", e.toString());
            console.error("[飞镖控制发送失败]", e);
        }
    }

    // ========== 10. 发送哨兵控制指令 ==========
    function sendSentryCtrlCommand() {
        if (!sentryCtrlHandler) {
            root.sendFailed("SentryCtrl", "处理器实例不存在");
            return;
        }

        // 协议校验：指令ID范围
        if (root.sentryCtrlCommandId < 0 || root.sentryCtrlCommandId > 10) {
            root.sendFailed("SentryCtrl", "指令ID非法（仅0-10）");
            console.error("[哨兵控制校验失败] 指令ID=", root.sentryCtrlCommandId);
            return;
        }

        var dataMap = {
            commandId: root.sentryCtrlCommandId
        };

        try {
            sentryCtrlHandler.parseFromQmlMap(dataMap);
            sentryCtrlHandler.send();
            root.dataSent("SentryCtrl");
            console.log("[哨兵控制发送] 指令ID=", root.sentryCtrlCommandId);
        } catch (e) {
            root.sendFailed("SentryCtrl", e.toString());
            console.error("[哨兵控制发送失败]", e);
        }
    }

    // ========== 11. 发送空中支援指令 ==========
    function sendAirSupportCommand() {
        if (!airSupportHandler) {
            root.sendFailed("AirSupport", "处理器实例不存在");
            return;
        }

        // 协议校验：指令ID范围
        if (root.airSupportCommandId < 1 || root.airSupportCommandId > 3) {
            root.sendFailed("AirSupport", "指令ID非法（仅1-3）");
            console.log("[空中支援校验失败] 指令ID=", root.airSupportCommandId);
            return;
        }

        var dataMap = {
            commandId: root.airSupportCommandId
        };

        try {
            airSupportHandler.parseFromQmlMap(dataMap);
            airSupportHandler.send();
            root.dataSent("AirSupport");
            console.log("[空中支援发送] 指令ID=", root.airSupportCommandId);
        } catch (e) {
            root.sendFailed("AirSupport", e.toString());
            console.error("[空中支援发送失败]", e);
        }
    }

    // ========== 辅助工具函数 ==========
    // 重置键鼠位移（发送完成后调用）
    // function resetMouseOffset() {
    //     root.mouseX = 0;
    //     root.mouseY = 0;
    //     root.mouseZ = 0;
    // }

    // 批量设置自定义控制数据（二进制转16进制）
    function setCustomControlBinaryData(binaryData) {
        root.customControlHexData = binaryData.toHex();
    }

    // 设置地图点击机器人ID（字节数组转16进制）
    function setMapClickRobotIdBinary(robotIdBytes) {
        root.mapClickRobotIdHex = robotIdBytes.toHex();
    }

    // 启停所有定时器（统一控制）
    function startAllTimers() {
        root.enableAutoSend = true;
        keyboardMouseTimer.start();
        customControlTimer.start();
        assemblyCommandTimer.start();
        robotPerformanceTimer.start();
        heroDeployModeTimer.start();
        runeActivateTimer.start();
        dartCommandTimer.start();
        sentryCtrlTimer.start();
        airSupportTimer.start();
        commonCommandTimer.start();
        console.log("[定时器] 所有指令定时发送已启动");
    }

    function stopAllTimers() {
        root.enableAutoSend = false;
        keyboardMouseTimer.stop();
        customControlTimer.stop();
        assemblyCommandTimer.stop();
        robotPerformanceTimer.stop();
        heroDeployModeTimer.stop();
        runeActivateTimer.stop();
        dartCommandTimer.stop();
        sentryCtrlTimer.stop();
        airSupportTimer.stop();
        commonCommandTimer.stop();
        console.log("[定时器] 所有指令定时发送已停止");
    }
}