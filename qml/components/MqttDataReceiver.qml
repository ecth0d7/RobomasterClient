import QtQuick 6.2

// MQTT数据接收模块（完整支持RoboMaster 2026通信协议V1.2.0）
// 核心修正：所有信号处理函数名严格匹配C++发射的信号名
Item {
    id: root

    // ========== 1. GameStatus（比赛全局状态） ==========
    property int gameStatus_current_round: -1
    property int gameStatus_total_rounds: 0
    property int gameStatus_red_score: 0
    property int gameStatus_blue_score: 0
    property int gameStatus_current_stage: 0
    property int gameStatus_stage_countdown_sec: 0
    property int gameStatus_stage_elapsed_sec: 0
    property bool gameStatus_is_paused: false

    // ========== 2. GlobalUnitStatus（基地/前哨站/机器人全局状态） ==========
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
    property var globalUnit_robot_health: []  // 动态数组，对应repeated uint32
    property var globalUnit_robot_bullets: [] // 动态数组，对应repeated int32
    property int globalUnit_total_damage_ally: 0
    property int globalUnit_total_damage_enemy: 0

    // ========== 3. GlobalLogisticsStatus（全局后勤信息） ==========
    property int globalLogistics_remaining_economy: 0
    property int globalLogistics_total_economy_obtained: 0
    property int globalLogistics_tech_level: 0
    property int globalLogistics_encryption_level: 0

    // ========== 4. GlobalSpecialMechanism（全局特殊机制） ==========
    property var globalSpecial_mechanism_id: []      // 生效的机制ID数组
    property var globalSpecial_mechanism_time_sec: [] // 对应机制剩余时间数组

    // ========== 5. Event（全局事件通知） ==========
    property int event_id: 0
    property string event_param: ""

    // ========== 6. RobotInjuryStat（机器人单次存活受伤统计） ==========
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

    // ========== 7. RobotRespawnStatus（机器人复活状态） ==========
    property bool robotRespawn_is_pending_respawn: false
    property int robotRespawn_total_respawn_progress: 0
    property int robotRespawn_current_respawn_progress: 0
    property bool robotRespawn_can_free_respawn: false
    property int robotRespawn_gold_cost_for_respawn: 0
    property bool robotRespawn_can_pay_for_respawn: false

    // ========== 8. RobotStaticStatus（机器人固定属性配置） ==========
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

    // ========== 9. RobotDynamicStatus（机器人实时动态数据） ==========
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

    // ========== 10. RobotModuleStatus（机器人各模块运行状态） ==========
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

    // ========== 11. RobotPosition（机器人空间坐标与朝向） ==========
    property real robotPosition_x: 0.0
    property real robotPosition_y: 0.0
    property real robotPosition_z: 0.0
    property real robotPosition_yaw: 0.0

    // ========== 12. Buff（Buff效果信息） ==========
    property int buff_robot_id: 0
    property int buff_type: 0
    property int buff_level: 0
    property int buff_max_time: 0
    property int buff_left_time: 0

    // ========== 13. PenaltyInfo（判罚信息） ==========
    property int penalty_type: 0
    property int penalty_effect_sec: 0
    property int penalty_total_penalty_num: 0

    // ========== 14. RobotPathPlanInfo（哨兵轨迹规划信息） ==========
    property int robotPath_intention: 0
    property int robotPath_start_pos_x: 0
    property int robotPath_start_pos_y: 0
    property var robotPath_offset_x: []
    property var robotPath_offset_y: []
    property int robotPath_sender_id: 0

    // ========== 15. RadarInfoToClient（雷达机器人位置信息） ==========
    property int radar_target_robot_id: 0
    property real radar_target_pos_x: 0.0
    property real radar_target_pos_y: 0.0
    property real radar_toward_angle: 0.0
    property int radar_is_high_light: 0

    // ========== 16. CustomByteBlock（自定义数据流） ==========
    property string customByteBlock_data: ""  // 二进制数据转16进制字符串存储

    // ========== 17. TechCoreMotionStateSync（科技核心运动状态同步） ==========
    property int techCore_maximum_difficulty_level: 1
    property int techCore_status: 1
    property int techCore_enemy_core_status: 0
    property int techCore_remain_time_all: 0
    property int techCore_remain_time_step: 0

    // ========== 18. RobotPerformanceSelectionSync（性能体系状态同步） ==========
    property int robotPerfSync_shooter: 1
    property int robotPerfSync_chassis: 1
    property int robotPerfSync_sentry_control: 0

    // ========== 19. DeployModeStatusSync（英雄部署模式状态同步） ==========
    property int deployMode_current_status: 0

    // ========== 20. RuneStatusSync（能量机关状态同步） ==========
    property int runeStatus_rune_status: 1
    property int runeStatus_activated_arms: 0
    property int runeStatus_average_rings: 0

    // ========== 21. SentryStatusSync（哨兵状态同步） ==========
    property int sentryStatus_posture_id: 1
    property bool sentryStatus_is_weakened: false

    // ========== 22. DartSelectTargetStatusSync（飞镖目标选择状态同步） ==========
    property int dartTarget_status_target_id: 0
    property int dartTarget_status_open: 1

    // ========== 23. SentryCtrlResult（哨兵控制指令结果反馈） ==========
    property int sentryCtrlResult_command_id: 0
    property int sentryCtrlResult_result_code: 0

    // ========== 24. AirSupportStatusSync（空中支援状态反馈） ==========
    property int airSupport_status: 0
    property int airSupport_left_time: 0
    property int airSupport_cost_coins: 0
    property int airSupport_is_being_targeted: 0
    property int airSupport_shooter_status: 1

    // ========== 信号连接：严格匹配C++发射的信号名 ==========
    // 1. GameStatus更新（C++信号：gameStatusUpdated）
    Connections {
        target: gameStatusHandler
        function onGameStatusUpdated(map) {
            root.gameStatus_current_round = map.current_round || -1
            root.gameStatus_total_rounds = map.total_rounds || 0
            root.gameStatus_red_score = map.red_score || 0
            root.gameStatus_blue_score = map.blue_score || 0
            root.gameStatus_current_stage = map.current_stage || 0
            root.gameStatus_stage_countdown_sec = map.stage_countdown_sec || 0
            root.gameStatus_stage_elapsed_sec = map.stage_elapsed_sec || 0
            root.gameStatus_is_paused = map.is_paused || false
            console.log("[GameStatus更新] 局数=", root.gameStatus_current_round, 
                        "红方分数=", root.gameStatus_red_score, 
                        "阶段=", root.gameStatus_current_stage)
        }
    }

    // 2. GlobalUnitStatus更新（C++信号：globalUnitStatusUpdated）
    Connections {
        target: globalUnitHandler
        function onGlobalUnitStatusUpdated(map) {
            root.globalUnit_base_health = map.base_health || 0
            root.globalUnit_base_status = map.base_status || 0
            root.globalUnit_base_shield = map.base_shield || 0
            root.globalUnit_outpost_health = map.outpost_health || 0
            root.globalUnit_outpost_status = map.outpost_status || 0
            root.globalUnit_enemy_base_health = map.enemy_base_health || 0
            root.globalUnit_enemy_base_status = map.enemy_base_status || 0
            root.globalUnit_enemy_base_shield = map.enemy_base_shield || 0
            root.globalUnit_enemy_outpost_health = map.enemy_outpost_health || 0
            root.globalUnit_enemy_outpost_status = map.enemy_outpost_status || 0
            root.globalUnit_robot_health = map.robot_health || []
            root.globalUnit_robot_bullets = map.robot_bullets || []
            root.globalUnit_total_damage_ally = map.total_damage_ally || 0
            root.globalUnit_total_damage_enemy = map.total_damage_enemy || 0
            console.log("[GlobalUnit更新] 基地血量=", root.globalUnit_base_health, 
                        "前哨站状态=", root.globalUnit_outpost_status,
                        "己方总伤害=", root.globalUnit_total_damage_ally)
        }
    }

    // 3. GlobalLogisticsStatus更新（C++信号：globalLogisticsUpdated）
    Connections {
        target: globalLogisticsHandler
        function onGlobalLogisticsUpdated(map) {
            root.globalLogistics_remaining_economy = map.remaining_economy || 0
            root.globalLogistics_total_economy_obtained = map.total_economy_obtained || 0
            root.globalLogistics_tech_level = map.tech_level || 0
            root.globalLogistics_encryption_level = map.encryption_level || 1
            console.log("[全局后勤更新] 剩余经济=", root.globalLogistics_remaining_economy, 
                        "科技等级=", root.globalLogistics_tech_level)
        }
    }

    // 4. GlobalSpecialMechanism更新（C++信号：globalSpecialMechanismUpdated）
    Connections {
        target: globalSpecialMechanismHandler
        function onGlobalSpecialMechanismUpdated(map) {
            root.globalSpecial_mechanism_id = map.mechanism_id || []
            root.globalSpecial_mechanism_time_sec = map.mechanism_time_sec || []
            console.log("[特殊机制更新] 生效机制ID=", root.globalSpecial_mechanism_id,
                        "剩余时间=", root.globalSpecial_mechanism_time_sec)
        }
    }

    // 5. Event全局事件通知（C++信号：eventUpdated）
    Connections {
        target: eventHandler
        function onEventUpdated(map) {
            root.event_id = map.event_id || 0
            root.event_param = map.param || ""
            console.log("[全局事件] ID=", root.event_id, "参数=", root.event_param)
        }
    }

    // 6. RobotInjuryStat机器人受伤统计（C++信号：robotInjuryStatUpdated）
    Connections {
        target: robotInjuryStatHandler
        function onRobotInjuryStatUpdated(map) {
            root.robotInjury_total_damage = map.total_damage || 0
            root.robotInjury_collision_damage = map.collision_damage || 0
            root.robotInjury_small_projectile_damage = map.small_projectile_damage || 0
            root.robotInjury_large_projectile_damage = map.large_projectile_damage || 0
            root.robotInjury_dart_splash_damage = map.dart_splash_damage || 0
            root.robotInjury_module_offline_damage = map.module_offline_damage || 0
            root.robotInjury_offline_damage = map.offline_damage || 0
            root.robotInjury_penalty_damage = map.penalty_damage || 0
            root.robotInjury_server_kill_damage = map.server_kill_damage || 0
            root.robotInjury_killer_id = map.killer_id || 0
            console.log("[机器人受伤统计] 总伤害=", root.robotInjury_total_damage,
                        "击杀者ID=", root.robotInjury_killer_id)
        }
    }

    // 7. RobotRespawnStatus机器人复活状态（C++信号：robotRespawnUpdated）
    Connections {
        target: robotRespawnStatusHandler
        function onRobotRespawnUpdated(map) {
            root.robotRespawn_is_pending_respawn = map.is_pending_respawn || false
            root.robotRespawn_total_respawn_progress = map.total_respawn_progress || 0
            root.robotRespawn_current_respawn_progress = map.current_respawn_progress || 0
            root.robotRespawn_can_free_respawn = map.can_free_respawn || false
            root.robotRespawn_gold_cost_for_respawn = map.gold_cost_for_respawn || 0
            root.robotRespawn_can_pay_for_respawn = map.can_pay_for_respawn || false
            console.log("[复活状态] 待复活=", root.robotRespawn_is_pending_respawn,
                        "读条进度=", root.robotRespawn_current_respawn_progress)
        }
    }

    // 8. RobotStaticStatus机器人固定属性（C++信号：robotStaticStatusUpdated）
    Connections {
        target: robotStaticStatusHandler
        function onRobotStaticStatusUpdated(map) {
            root.robotStatic_connection_state = map.connection_state || 0
            root.robotStatic_field_state = map.field_state || 0
            root.robotStatic_alive_state = map.alive_state || 0
            root.robotStatic_robot_id = map.robot_id || 0
            root.robotStatic_robot_type = map.robot_type || 0
            root.robotStatic_performance_system_shooter = map.performance_system_shooter || 1
            root.robotStatic_performance_system_chassis = map.performance_system_chassis || 1
            root.robotStatic_level = map.level || 1
            root.robotStatic_max_health = map.max_health || 0
            root.robotStatic_max_heat = map.max_heat || 0
            root.robotStatic_heat_cooldown_rate = map.heat_cooldown_rate || 0.0
            root.robotStatic_max_power = map.max_power || 0
            root.robotStatic_max_buffer_energy = map.max_buffer_energy || 0
            root.robotStatic_max_chassis_energy = map.max_chassis_energy || 0
            console.log("[机器人固定属性] ID=", root.robotStatic_robot_id,
                        "类型=", root.robotStatic_robot_type, "等级=", root.robotStatic_level)
        }
    }

    // 9. RobotDynamicStatus机器人实时动态（C++信号：robotDynamicStatusUpdated）
    Connections {
        target: robotDynamicStatusHandler
        function onRobotDynamicStatusUpdated(map) {
            root.robotDynamic_current_health = map.current_health || 0
            root.robotDynamic_current_heat = map.current_heat || 0.0
            root.robotDynamic_last_projectile_fire_rate = map.last_projectile_fire_rate || 0.0
            root.robotDynamic_current_chassis_energy = map.current_chassis_energy || 0
            root.robotDynamic_current_buffer_energy = map.current_buffer_energy || 0
            root.robotDynamic_current_experience = map.current_experience || 0
            root.robotDynamic_experience_for_upgrade = map.experience_for_upgrade || 0
            root.robotDynamic_total_projectiles_fired = map.total_projectiles_fired || 0
            root.robotDynamic_remaining_ammo = map.remaining_ammo || 0
            root.robotDynamic_is_out_of_combat = map.is_out_of_combat || false
            root.robotDynamic_out_of_combat_countdown = map.out_of_combat_countdown || 0
            root.robotDynamic_can_remote_heal = map.can_remote_heal || false
            root.robotDynamic_can_remote_ammo = map.can_remote_ammo || false
            console.log("[机器人动态数据] 血量=", root.robotDynamic_current_health,
                        "剩余弹药=", root.robotDynamic_remaining_ammo,
                        "脱战状态=", root.robotDynamic_is_out_of_combat)
        }
    }

    // 10. RobotModuleStatus机器人模块状态（C++信号：robotModuleStatusUpdated）
    Connections {
        target: robotModuleStatusHandler
        function onRobotModuleStatusUpdated(map) {
            root.robotModule_power_manager = map.power_manager || 0
            root.robotModule_rfid = map.rfid || 0
            root.robotModule_light_strip = map.light_strip || 0
            root.robotModule_small_shooter = map.small_shooter || 0
            root.robotModule_big_shooter = map.big_shooter || 0
            root.robotModule_uwb = map.uwb || 0
            root.robotModule_armor = map.armor || 0
            root.robotModule_video_transmission = map.video_transmission || 0
            root.robotModule_capacitor = map.capacitor || 0
            root.robotModule_main_controller = map.main_controller || 0
            root.robotModule_laser_detection_module = map.laser_detection_module || 0
            console.log("[模块状态] 主控=", root.robotModule_main_controller,
                        "17mm发射机构=", root.robotModule_small_shooter)
        }
    }

    // 11. RobotPosition机器人坐标朝向（C++信号：robotPositionUpdated）
    Connections {
        target: robotPositionHandler
        function onRobotPositionUpdated(map) {
            root.robotPosition_x = map.x || 0.0
            root.robotPosition_y = map.y || 0.0
            root.robotPosition_z = map.z || 0.0
            root.robotPosition_yaw = map.yaw || 0.0
            console.log("[机器人位置] X=", root.robotPosition_x, "Y=", root.robotPosition_y,
                        "朝向=", root.robotPosition_yaw)
        }
    }

    // 12. Buff效果信息（C++信号：buffUpdated）
    Connections {
        target: buffHandler
        function onBuffUpdated(map) {
            root.buff_robot_id = map.robot_id || 0
            root.buff_type = map.buff_type || 0
            root.buff_level = map.buff_level || 0
            root.buff_max_time = map.max_time || 0
            root.buff_left_time = map.left_time || 0
            console.log("[Buff效果] 机器人ID=", root.buff_robot_id,
                        "类型=", root.buff_type, "剩余时间=", root.buff_left_time)
        }
    }

    // 13. PenaltyInfo判罚信息（C++信号：penaltyInfoUpdated）
    Connections {
        target: penaltyInfoHandler
        function onPenaltyInfoUpdated(map) {
            root.penalty_type = map.penalty_type || 0
            root.penalty_effect_sec = map.penalty_effect_sec || 0
            root.penalty_total_penalty_num = map.total_penalty_num || 0
            console.log("[判罚信息] 类型=", root.penalty_type,
                        "持续时间=", root.penalty_effect_sec, "累计次数=", root.penalty_total_penalty_num)
        }
    }

    // 14. RobotPathPlanInfo哨兵轨迹规划（C++信号：robotPathPlanUpdated）
    Connections {
        target: robotPathPlanHandler
        function onRobotPathPlanUpdated(map) {
            root.robotPath_intention = map.intention || 0
            root.robotPath_start_pos_x = map.start_pos_x || 0
            root.robotPath_start_pos_y = map.start_pos_y || 0
            root.robotPath_offset_x = map.offset_x || []
            root.robotPath_offset_y = map.offset_y || []
            root.robotPath_sender_id = map.sender_id || 0
            console.log("[哨兵轨迹] 意图=", root.robotPath_intention,
                        "起始坐标(", root.robotPath_start_pos_x, ",", root.robotPath_start_pos_y, ")")
        }
    }

    // 15. RadarInfoToClient雷达位置信息（C++信号：radarInfoUpdated）
    Connections {
        target: radarInfoHandler
        function onRadarInfoUpdated(map) {
            root.radar_target_robot_id = map.target_robot_id || 0
            root.radar_target_pos_x = map.target_pos_x || 0.0
            root.radar_target_pos_y = map.target_pos_y || 0.0
            root.radar_toward_angle = map.toward_angle || 0.0
            root.radar_is_high_light = map.is_high_light || 0
            console.log("[雷达信息] 目标ID=", root.radar_target_robot_id,
                        "坐标(", root.radar_target_pos_x, ",", root.radar_target_pos_y, ")")
        }
    }

    // 16. CustomByteBlock自定义数据流（C++信号：customByteBlockUpdated）
    Connections {
        target: customByteBlockHandler
        function onCustomByteBlockUpdated(map) {
            // 二进制数据转16进制字符串存储，方便QML显示
            root.customByteBlock_data = map.data_hex || ""
            console.log("[自定义数据流] 长度=", root.customByteBlock_data.length/2, "字节")
        }
    }

    // 17. TechCoreMotionStateSync科技核心状态（C++信号：techCoreMotionUpdated）
    Connections {
        target: techCoreMotionHandler
        function onTechCoreMotionUpdated(map) {
            root.techCore_maximum_difficulty_level = map.maximum_difficulty_level || 1
            root.techCore_status = map.status || 1
            root.techCore_enemy_core_status = map.enemy_core_status || 0
            root.techCore_remain_time_all = map.remain_time_all || 0
            root.techCore_remain_time_step = map.remain_time_step || 0
            console.log("[科技核心] 最高难度=", root.techCore_maximum_difficulty_level,
                        "状态=", root.techCore_status, "剩余总时间=", root.techCore_remain_time_all)
        }
    }

    // 18. RobotPerformanceSelectionSync性能体系同步（C++信号：robotPerformanceSyncUpdated）
    Connections {
        target: robotPerformanceSyncHandler
        function onRobotPerformanceSyncUpdated(map) {
            root.robotPerfSync_shooter = map.shooter || 1
            root.robotPerfSync_chassis = map.chassis || 1
            root.robotPerfSync_sentry_control = map.sentry_control || 0
            console.log("[性能体系同步] 发射机构=", root.robotPerfSync_shooter,
                        "底盘=", root.robotPerfSync_chassis, "哨兵控制=", root.robotPerfSync_sentry_control)
        }
    }

    // 19. DeployModeStatusSync英雄部署模式同步（C++信号：deployModeStatusUpdated）
    Connections {
        target: deployModeStatusHandler
        function onDeployModeStatusUpdated(map) {
            root.deployMode_current_status = map.current_status || 0
            console.log("[英雄部署模式] 当前状态=", root.deployMode_current_status)
        }
    }

    // 20. RuneStatusSync能量机关状态（C++信号：runeStatusUpdated）
    Connections {
        target: runeStatusHandler
        function onRuneStatusUpdated(map) {
            root.runeStatus_rune_status = map.rune_status || 1
            root.runeStatus_activated_arms = map.activated_arms || 0
            root.runeStatus_average_rings = map.average_rings || 0
            console.log("[能量机关] 状态=", root.runeStatus_rune_status,
                        "激活灯臂数=", root.runeStatus_activated_arms, "平均环数=", root.runeStatus_average_rings)
        }
    }

    // 21. SentryStatusSync哨兵状态（C++信号：sentryStatusUpdated）
    Connections {
        target: sentryStatusHandler
        function onSentryStatusUpdated(map) {
            root.sentryStatus_posture_id = map.posture_id || 1
            root.sentryStatus_is_weakened = map.is_weakened || false
            console.log("[哨兵状态] 姿态ID=", root.sentryStatus_posture_id,
                        "弱化状态=", root.sentryStatus_is_weakened)
        }
    }

    // 22. DartSelectTargetStatusSync飞镖目标状态（C++信号：dartTargetStatusUpdated）
    Connections {
        target: dartTargetStatusHandler
        function onDartTargetStatusUpdated(map) {
            root.dartTarget_status_target_id = map.target_id || 0
            root.dartTarget_status_open = map.open || 1
            console.log("[飞镖状态] 目标ID=", root.dartTarget_status_target_id,
                        "闸门状态=", root.dartTarget_status_open)
        }
    }

    // 23. SentryCtrlResult哨兵指令结果（C++信号：sentryCtrlResultUpdated）
    Connections {
        target: sentryCtrlResultHandler
        function onSentryCtrlResultUpdated(map) {
            root.sentryCtrlResult_command_id = map.command_id || 0
            root.sentryCtrlResult_result_code = map.result_code || 0
            console.log("[哨兵指令结果] 指令ID=", root.sentryCtrlResult_command_id,
                        "结果码=", root.sentryCtrlResult_result_code)
        }
    }

    // 24. AirSupportStatusSync空中支援状态（C++信号：airSupportStatusUpdated）
    Connections {
        target: airSupportStatusHandler
        function onAirSupportStatusUpdated(map) {
            root.airSupport_status = map.airsupport_status || 0
            root.airSupport_left_time = map.left_time || 0
            root.airSupport_cost_coins = map.cost_coins || 0
            root.airSupport_is_being_targeted = map.is_being_targeted || 0
            root.airSupport_shooter_status = map.shooter_status || 1
            console.log("[空中支援] 状态=", root.airSupport_status,
                        "免费剩余时间=", root.airSupport_left_time, "花费金币=", root.airSupport_cost_coins)
        }
    }
}