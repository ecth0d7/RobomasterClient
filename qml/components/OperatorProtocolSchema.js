.pragma library

// Generated from protocol/robomaster_custom_client.proto and TelemetryGroups.def.
// Titles: qml/resources/protocol-labels.json; regenerate with tools/generate_protocol_ui.py.
var messages = [
  {
    "topic": "KeyboardMouseControl",
    "group": "",
    "direction": "send",
    "title": "键鼠输入",
    "fields": [
      {
        "name": "mouse_x",
        "number": 1,
        "type": "int32",
        "cardinality": "optional",
        "title": "鼠标 X 移动量",
        "note": ""
      },
      {
        "name": "mouse_y",
        "number": 2,
        "type": "int32",
        "cardinality": "optional",
        "title": "鼠标 Y 移动量",
        "note": ""
      },
      {
        "name": "mouse_z",
        "number": 3,
        "type": "int32",
        "cardinality": "optional",
        "title": "鼠标滚轮移动量",
        "note": ""
      },
      {
        "name": "left_button_down",
        "number": 4,
        "type": "bool",
        "cardinality": "optional",
        "title": "鼠标左键",
        "note": ""
      },
      {
        "name": "right_button_down",
        "number": 5,
        "type": "bool",
        "cardinality": "optional",
        "title": "鼠标右键",
        "note": ""
      },
      {
        "name": "keyboard_value",
        "number": 6,
        "type": "uint32",
        "cardinality": "optional",
        "title": "键盘位掩码",
        "note": "仅 bit 0~15 有效：W,S,A,D,Shift,Ctrl,Q,E,R,F,G,Z,X,C,V,B。"
      },
      {
        "name": "mid_button_down",
        "number": 7,
        "type": "bool",
        "cardinality": "optional",
        "title": "鼠标中键",
        "note": ""
      }
    ]
  },
  {
    "topic": "CustomControl",
    "group": "",
    "direction": "send",
    "title": "自定义控制数据",
    "fields": [
      {
        "name": "data",
        "number": 1,
        "type": "bytes",
        "cardinality": "optional",
        "title": "字节数据",
        "note": ""
      }
    ]
  },
  {
    "topic": "GameStatus",
    "group": "gameStatus",
    "direction": "receive",
    "title": "比赛状态",
    "fields": [
      {
        "name": "current_round",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "当前局数",
        "note": ""
      },
      {
        "name": "total_rounds",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "总局数",
        "note": ""
      },
      {
        "name": "red_score",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "红方比分",
        "note": ""
      },
      {
        "name": "blue_score",
        "number": 4,
        "type": "uint32",
        "cardinality": "optional",
        "title": "蓝方比分",
        "note": ""
      },
      {
        "name": "current_stage",
        "number": 5,
        "type": "uint32",
        "cardinality": "optional",
        "title": "比赛阶段",
        "note": "0 未开始，1 准备，2 自检，3 倒计时，4 比赛中，5 结算中。"
      },
      {
        "name": "stage_countdown_sec",
        "number": 6,
        "type": "int32",
        "cardinality": "optional",
        "title": "阶段倒计时（秒）",
        "note": ""
      },
      {
        "name": "stage_elapsed_sec",
        "number": 7,
        "type": "int32",
        "cardinality": "optional",
        "title": "阶段已过时间（秒）",
        "note": ""
      },
      {
        "name": "is_paused",
        "number": 8,
        "type": "bool",
        "cardinality": "optional",
        "title": "比赛暂停",
        "note": ""
      },
      {
        "name": "game_result",
        "number": 9,
        "type": "uint32",
        "cardinality": "optional",
        "title": "当局结果",
        "note": "0 平局，1 红方胜，2 蓝方胜；非结算阶段为 255。"
      },
      {
        "name": "end_reason",
        "number": 10,
        "type": "uint32",
        "cardinality": "optional",
        "title": "结束原因",
        "note": "1~9；非结算阶段为 255。"
      }
    ]
  },
  {
    "topic": "GlobalUnitStatus",
    "group": "globalUnit",
    "direction": "receive",
    "title": "全局单位",
    "fields": [
      {
        "name": "base_health",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "己方基地血量",
        "note": ""
      },
      {
        "name": "base_status",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "己方基地状态",
        "note": ""
      },
      {
        "name": "base_shield",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "己方基地护盾",
        "note": ""
      },
      {
        "name": "outpost_health",
        "number": 4,
        "type": "uint32",
        "cardinality": "optional",
        "title": "己方前哨站血量",
        "note": ""
      },
      {
        "name": "outpost_status",
        "number": 5,
        "type": "uint32",
        "cardinality": "optional",
        "title": "己方前哨站状态",
        "note": ""
      },
      {
        "name": "enemy_base_health",
        "number": 6,
        "type": "uint32",
        "cardinality": "optional",
        "title": "对方基地血量",
        "note": ""
      },
      {
        "name": "enemy_base_status",
        "number": 7,
        "type": "uint32",
        "cardinality": "optional",
        "title": "对方基地状态",
        "note": ""
      },
      {
        "name": "enemy_base_shield",
        "number": 8,
        "type": "uint32",
        "cardinality": "optional",
        "title": "对方基地护盾",
        "note": ""
      },
      {
        "name": "enemy_outpost_health",
        "number": 9,
        "type": "uint32",
        "cardinality": "optional",
        "title": "对方前哨站血量",
        "note": ""
      },
      {
        "name": "enemy_outpost_status",
        "number": 10,
        "type": "uint32",
        "cardinality": "optional",
        "title": "对方前哨站状态",
        "note": ""
      },
      {
        "name": "robot_health",
        "number": 11,
        "type": "uint32",
        "cardinality": "repeated",
        "title": "机器人血量数组",
        "note": "数组顺序：己方 1、2、3、4、7；对方 1、2、3、4、7。空缺项不补造血量。"
      },
      {
        "name": "robot_bullets",
        "number": 12,
        "type": "int32",
        "cardinality": "repeated",
        "title": "己方剩余累计发弹量数组",
        "note": "官方V2.0.0字段12为剩余累计发弹量，不是已发射总数。该表未明示数组顺序；当前五槽适配映射仍待选手端导出／设备核验，不推算缺失弹量。"
      },
      {
        "name": "total_damage_ally",
        "number": 13,
        "type": "uint32",
        "cardinality": "optional",
        "title": "己方总伤害",
        "note": ""
      },
      {
        "name": "total_damage_enemy",
        "number": 14,
        "type": "uint32",
        "cardinality": "optional",
        "title": "对方总伤害",
        "note": ""
      }
    ]
  },
  {
    "topic": "GlobalLogisticsStatus",
    "group": "globalLogistics",
    "direction": "receive",
    "title": "队伍后勤",
    "fields": [
      {
        "name": "remaining_economy",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "剩余金币",
        "note": ""
      },
      {
        "name": "total_economy_obtained",
        "number": 2,
        "type": "uint64",
        "cardinality": "optional",
        "title": "累计获得金币",
        "note": ""
      },
      {
        "name": "tech_level",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "科技等级",
        "note": ""
      },
      {
        "name": "encryption_level",
        "number": 4,
        "type": "uint32",
        "cardinality": "optional",
        "title": "加密等级",
        "note": ""
      }
    ]
  },
  {
    "topic": "GlobalSpecialMechanism",
    "group": "globalSpecial",
    "direction": "receive",
    "title": "特殊机制",
    "fields": [
      {
        "name": "mechanism_id",
        "number": 1,
        "type": "uint32",
        "cardinality": "repeated",
        "title": "机制编号数组",
        "note": ""
      },
      {
        "name": "mechanism_time_sec",
        "number": 2,
        "type": "int32",
        "cardinality": "repeated",
        "title": "机制时间数组（秒）",
        "note": ""
      }
    ]
  },
  {
    "topic": "Event",
    "group": "event",
    "direction": "receive",
    "title": "赛场事件",
    "fields": [
      {
        "name": "event_id",
        "number": 1,
        "type": "int32",
        "cardinality": "optional",
        "title": "事件编号",
        "note": ""
      },
      {
        "name": "param",
        "number": 2,
        "type": "string",
        "cardinality": "optional",
        "title": "事件参数",
        "note": ""
      }
    ]
  },
  {
    "topic": "RobotInjuryStat",
    "group": "robotInjury",
    "direction": "receive",
    "title": "受伤统计",
    "fields": [
      {
        "name": "total_damage",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "总扣血量",
        "note": ""
      },
      {
        "name": "collision_damage",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "碰撞扣血",
        "note": ""
      },
      {
        "name": "small_projectile_damage",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "17 mm 弹丸扣血",
        "note": ""
      },
      {
        "name": "large_projectile_damage",
        "number": 4,
        "type": "uint32",
        "cardinality": "optional",
        "title": "42 mm 弹丸扣血",
        "note": ""
      },
      {
        "name": "dart_splash_damage",
        "number": 5,
        "type": "uint32",
        "cardinality": "optional",
        "title": "飞镖溅射扣血",
        "note": ""
      },
      {
        "name": "module_offline_damage",
        "number": 6,
        "type": "uint32",
        "cardinality": "optional",
        "title": "模块离线扣血",
        "note": ""
      },
      {
        "name": "offline_damage",
        "number": 7,
        "type": "uint32",
        "cardinality": "optional",
        "title": "离线扣血",
        "note": ""
      },
      {
        "name": "penalty_damage",
        "number": 8,
        "type": "uint32",
        "cardinality": "optional",
        "title": "判罚扣血",
        "note": ""
      },
      {
        "name": "server_kill_damage",
        "number": 9,
        "type": "uint32",
        "cardinality": "optional",
        "title": "服务器判定扣血",
        "note": ""
      },
      {
        "name": "killer_id",
        "number": 10,
        "type": "uint32",
        "cardinality": "optional",
        "title": "击杀者编号",
        "note": ""
      }
    ]
  },
  {
    "topic": "RobotRespawnStatus",
    "group": "robotRespawn",
    "direction": "receive",
    "title": "复活状态",
    "fields": [
      {
        "name": "is_pending_respawn",
        "number": 1,
        "type": "bool",
        "cardinality": "optional",
        "title": "等待复活",
        "note": ""
      },
      {
        "name": "total_respawn_progress",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "复活读条总长度",
        "note": ""
      },
      {
        "name": "current_respawn_progress",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "当前复活进度",
        "note": ""
      },
      {
        "name": "can_free_respawn",
        "number": 4,
        "type": "bool",
        "cardinality": "optional",
        "title": "可免费复活",
        "note": ""
      },
      {
        "name": "gold_cost_for_respawn",
        "number": 5,
        "type": "uint32",
        "cardinality": "optional",
        "title": "立即复活所需金币",
        "note": ""
      },
      {
        "name": "can_pay_for_respawn",
        "number": 6,
        "type": "bool",
        "cardinality": "optional",
        "title": "可付费复活",
        "note": ""
      }
    ]
  },
  {
    "topic": "RobotStaticStatus",
    "group": "robotStatic",
    "direction": "receive",
    "title": "机器人静态状态",
    "fields": [
      {
        "name": "connection_state",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "连接状态",
        "note": ""
      },
      {
        "name": "field_state",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "上场状态",
        "note": ""
      },
      {
        "name": "alive_state",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "存活状态",
        "note": ""
      },
      {
        "name": "robot_id",
        "number": 4,
        "type": "uint32",
        "cardinality": "optional",
        "title": "机器人编号",
        "note": ""
      },
      {
        "name": "robot_type",
        "number": 5,
        "type": "uint32",
        "cardinality": "optional",
        "title": "机器人类型",
        "note": ""
      },
      {
        "name": "performance_system_shooter",
        "number": 6,
        "type": "uint32",
        "cardinality": "optional",
        "title": "发射机构性能体系",
        "note": ""
      },
      {
        "name": "performance_system_chassis",
        "number": 7,
        "type": "uint32",
        "cardinality": "optional",
        "title": "底盘性能体系",
        "note": ""
      },
      {
        "name": "level",
        "number": 8,
        "type": "uint32",
        "cardinality": "optional",
        "title": "等级",
        "note": ""
      },
      {
        "name": "max_health",
        "number": 9,
        "type": "uint32",
        "cardinality": "optional",
        "title": "血量上限",
        "note": ""
      },
      {
        "name": "max_heat",
        "number": 10,
        "type": "uint32",
        "cardinality": "optional",
        "title": "热量上限",
        "note": ""
      },
      {
        "name": "heat_cooldown_rate",
        "number": 11,
        "type": "float",
        "cardinality": "optional",
        "title": "热量冷却速率",
        "note": ""
      },
      {
        "name": "max_power",
        "number": 12,
        "type": "uint32",
        "cardinality": "optional",
        "title": "功率上限",
        "note": ""
      },
      {
        "name": "max_buffer_energy",
        "number": 13,
        "type": "uint32",
        "cardinality": "optional",
        "title": "缓冲能量上限",
        "note": ""
      },
      {
        "name": "max_chassis_energy",
        "number": 14,
        "type": "uint32",
        "cardinality": "optional",
        "title": "底盘能量上限",
        "note": ""
      }
    ]
  },
  {
    "topic": "RobotDynamicStatus",
    "group": "robotDynamic",
    "direction": "receive",
    "title": "机器人动态状态",
    "fields": [
      {
        "name": "current_health",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "当前血量",
        "note": ""
      },
      {
        "name": "current_heat",
        "number": 2,
        "type": "float",
        "cardinality": "optional",
        "title": "当前热量",
        "note": ""
      },
      {
        "name": "last_projectile_fire_rate",
        "number": 3,
        "type": "float",
        "cardinality": "optional",
        "title": "上一次弹丸射速",
        "note": ""
      },
      {
        "name": "current_chassis_energy",
        "number": 4,
        "type": "uint32",
        "cardinality": "optional",
        "title": "当前底盘能量",
        "note": ""
      },
      {
        "name": "current_buffer_energy",
        "number": 5,
        "type": "uint32",
        "cardinality": "optional",
        "title": "当前缓冲能量",
        "note": ""
      },
      {
        "name": "current_experience",
        "number": 6,
        "type": "uint32",
        "cardinality": "optional",
        "title": "当前经验",
        "note": ""
      },
      {
        "name": "experience_for_upgrade",
        "number": 7,
        "type": "uint32",
        "cardinality": "optional",
        "title": "升级所需经验",
        "note": ""
      },
      {
        "name": "total_projectiles_fired",
        "number": 8,
        "type": "uint32",
        "cardinality": "optional",
        "title": "累计发射弹丸量",
        "note": ""
      },
      {
        "name": "remaining_ammo",
        "number": 9,
        "type": "uint32",
        "cardinality": "optional",
        "title": "允许发弹量",
        "note": ""
      },
      {
        "name": "is_out_of_combat",
        "number": 10,
        "type": "bool",
        "cardinality": "optional",
        "title": "脱战状态",
        "note": ""
      },
      {
        "name": "out_of_combat_countdown",
        "number": 11,
        "type": "uint32",
        "cardinality": "optional",
        "title": "脱战倒计时",
        "note": ""
      },
      {
        "name": "can_remote_heal",
        "number": 12,
        "type": "bool",
        "cardinality": "optional",
        "title": "可远程兑换血量",
        "note": ""
      },
      {
        "name": "can_remote_ammo",
        "number": 13,
        "type": "bool",
        "cardinality": "optional",
        "title": "可远程兑换弹量",
        "note": ""
      }
    ]
  },
  {
    "topic": "RobotModuleStatus",
    "group": "robotModule",
    "direction": "receive",
    "title": "机器人模块",
    "fields": [
      {
        "name": "power_manager",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "电源管理",
        "note": ""
      },
      {
        "name": "rfid",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "RFID",
        "note": ""
      },
      {
        "name": "light_strip",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "灯条",
        "note": ""
      },
      {
        "name": "small_shooter",
        "number": 4,
        "type": "uint32",
        "cardinality": "optional",
        "title": "17 mm 发射机构",
        "note": ""
      },
      {
        "name": "big_shooter",
        "number": 5,
        "type": "uint32",
        "cardinality": "optional",
        "title": "42 mm 发射机构",
        "note": ""
      },
      {
        "name": "uwb",
        "number": 6,
        "type": "uint32",
        "cardinality": "optional",
        "title": "UWB 定位",
        "note": ""
      },
      {
        "name": "armor",
        "number": 7,
        "type": "uint32",
        "cardinality": "optional",
        "title": "装甲",
        "note": ""
      },
      {
        "name": "video_transmission",
        "number": 8,
        "type": "uint32",
        "cardinality": "optional",
        "title": "图传",
        "note": ""
      },
      {
        "name": "capacitor",
        "number": 9,
        "type": "uint32",
        "cardinality": "optional",
        "title": "电容",
        "note": ""
      },
      {
        "name": "main_controller",
        "number": 10,
        "type": "uint32",
        "cardinality": "optional",
        "title": "主控",
        "note": ""
      },
      {
        "name": "laser_detection_module",
        "number": 11,
        "type": "uint32",
        "cardinality": "optional",
        "title": "激光检测",
        "note": ""
      }
    ]
  },
  {
    "topic": "RobotPosition",
    "group": "robotPosition",
    "direction": "receive",
    "title": "机器人位置",
    "fields": [
      {
        "name": "x",
        "number": 1,
        "type": "float",
        "cardinality": "optional",
        "title": "X 坐标",
        "note": ""
      },
      {
        "name": "y",
        "number": 2,
        "type": "float",
        "cardinality": "optional",
        "title": "Y 坐标",
        "note": ""
      },
      {
        "name": "z",
        "number": 3,
        "type": "float",
        "cardinality": "optional",
        "title": "Z 坐标",
        "note": ""
      },
      {
        "name": "yaw",
        "number": 4,
        "type": "float",
        "cardinality": "optional",
        "title": "朝向",
        "note": ""
      },
      {
        "name": "robot_id",
        "number": 5,
        "type": "uint32",
        "cardinality": "optional",
        "title": "机器人编号",
        "note": "云台手客户端：6/106 空中，7/107 哨兵。"
      }
    ]
  },
  {
    "topic": "Buff",
    "group": "buff",
    "direction": "receive",
    "title": "增益",
    "fields": [
      {
        "name": "robot_id",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "机器人编号",
        "note": ""
      },
      {
        "name": "buff_type",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "增益类型",
        "note": ""
      },
      {
        "name": "buff_level",
        "number": 3,
        "type": "int32",
        "cardinality": "optional",
        "title": "增益值",
        "note": ""
      },
      {
        "name": "buff_max_time",
        "number": 4,
        "type": "uint32",
        "cardinality": "optional",
        "title": "增益总时长",
        "note": ""
      },
      {
        "name": "buff_left_time",
        "number": 5,
        "type": "uint32",
        "cardinality": "optional",
        "title": "增益剩余时长",
        "note": ""
      }
    ]
  },
  {
    "topic": "PenaltyInfo",
    "group": "penalty",
    "direction": "receive",
    "title": "判罚",
    "fields": [
      {
        "name": "penalty_type",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "判罚类型",
        "note": ""
      },
      {
        "name": "penalty_effect_sec",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "判罚影响时间（秒）",
        "note": ""
      },
      {
        "name": "total_penalty_num",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "累计判罚次数",
        "note": ""
      }
    ]
  },
  {
    "topic": "RobotPathPlanInfo",
    "group": "robotPath",
    "direction": "receive",
    "title": "规划路径",
    "fields": [
      {
        "name": "intention",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "路径意图",
        "note": ""
      },
      {
        "name": "start_pos_x",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "起点 X 坐标",
        "note": ""
      },
      {
        "name": "start_pos_y",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "起点 Y 坐标",
        "note": ""
      },
      {
        "name": "offset_x",
        "number": 4,
        "type": "int32",
        "cardinality": "repeated",
        "title": "X 增量数组",
        "note": ""
      },
      {
        "name": "offset_y",
        "number": 5,
        "type": "int32",
        "cardinality": "repeated",
        "title": "Y 增量数组",
        "note": ""
      },
      {
        "name": "sender_id",
        "number": 6,
        "type": "uint32",
        "cardinality": "optional",
        "title": "发送者编号",
        "note": ""
      }
    ]
  },
  {
    "topic": "MapClickInfo",
    "group": "mapClick",
    "direction": "receive",
    "title": "地图标记同步",
    "fields": [
      {
        "name": "is_send_all",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "发送范围",
        "note": ""
      },
      {
        "name": "robot_id",
        "number": 2,
        "type": "bytes",
        "cardinality": "optional",
        "title": "接收机器人字节数组",
        "note": "原始字节固定 7 字节，按十六进制显示。"
      },
      {
        "name": "mode",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "交互模式",
        "note": ""
      },
      {
        "name": "enemy_id",
        "number": 4,
        "type": "uint32",
        "cardinality": "optional",
        "title": "目标机器人编号",
        "note": ""
      },
      {
        "name": "ascii",
        "number": 5,
        "type": "uint32",
        "cardinality": "optional",
        "title": "交互字符",
        "note": ""
      },
      {
        "name": "type",
        "number": 6,
        "type": "uint32",
        "cardinality": "optional",
        "title": "交互类型",
        "note": ""
      },
      {
        "name": "map_x",
        "number": 7,
        "type": "float",
        "cardinality": "optional",
        "title": "地图 X 坐标",
        "note": ""
      },
      {
        "name": "map_y",
        "number": 8,
        "type": "float",
        "cardinality": "optional",
        "title": "地图 Y 坐标",
        "note": ""
      }
    ]
  },
  {
    "topic": "MapClickCmd",
    "group": "",
    "direction": "send",
    "title": "地图标记指令",
    "fields": [
      {
        "name": "is_send_all",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "发送范围",
        "note": ""
      },
      {
        "name": "robot_id",
        "number": 2,
        "type": "bytes",
        "cardinality": "optional",
        "title": "接收机器人字节数组",
        "note": "原始字节固定 7 字节，按十六进制显示。"
      },
      {
        "name": "mode",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "交互模式",
        "note": ""
      },
      {
        "name": "enemy_id",
        "number": 4,
        "type": "uint32",
        "cardinality": "optional",
        "title": "目标机器人编号",
        "note": ""
      },
      {
        "name": "ascii",
        "number": 5,
        "type": "uint32",
        "cardinality": "optional",
        "title": "交互字符",
        "note": ""
      },
      {
        "name": "type",
        "number": 6,
        "type": "uint32",
        "cardinality": "optional",
        "title": "交互类型",
        "note": ""
      },
      {
        "name": "map_x",
        "number": 7,
        "type": "float",
        "cardinality": "optional",
        "title": "地图 X 坐标",
        "note": ""
      },
      {
        "name": "map_y",
        "number": 8,
        "type": "float",
        "cardinality": "optional",
        "title": "地图 Y 坐标",
        "note": ""
      }
    ]
  },
  {
    "topic": "RadarSingleRobotInfo",
    "group": "",
    "direction": "structure",
    "title": "单机器人雷达信息",
    "fields": [
      {
        "name": "target_pos_x",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "目标 X 坐标（cm）",
        "note": "cm。"
      },
      {
        "name": "target_pos_y",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "目标 Y 坐标（cm）",
        "note": "cm。"
      },
      {
        "name": "is_high_light",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "高亮标记",
        "note": ""
      }
    ]
  },
  {
    "topic": "RadarInfoToClient",
    "group": "radar",
    "direction": "receive",
    "title": "雷达信息",
    "fields": [
      {
        "name": "radar_single_robot_info",
        "number": 1,
        "type": "RadarSingleRobotInfo",
        "cardinality": "repeated",
        "title": "机器人雷达条目",
        "note": "每一项包含目标 X、Y 坐标（cm）与高亮标记。单条嵌套结构定义来自 RadarSingleRobotInfo。"
      }
    ]
  },
  {
    "topic": "CustomByteBlock",
    "group": "customByteBlock",
    "direction": "receive",
    "title": "机器人自定义数据",
    "fields": [
      {
        "name": "data",
        "number": 1,
        "type": "bytes",
        "cardinality": "optional",
        "title": "字节数据",
        "note": ""
      }
    ]
  },
  {
    "topic": "AssemblyCommand",
    "group": "",
    "direction": "send",
    "title": "科技核心装配指令",
    "fields": [
      {
        "name": "operation",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "装配操作",
        "note": "0 开始兑换，1 确认装配，2 取消装配。"
      },
      {
        "name": "difficulty",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "装配难度",
        "note": ""
      }
    ]
  },
  {
    "topic": "TechCoreMotionStateSync",
    "group": "techCore",
    "direction": "receive",
    "title": "科技核心装配状态",
    "fields": [
      {
        "name": "maximum_difficulty_level",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "最大可选难度",
        "note": ""
      },
      {
        "name": "basic_state",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "基础状态",
        "note": ""
      },
      {
        "name": "putin_state",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "放入步骤",
        "note": ""
      },
      {
        "name": "move_state",
        "number": 4,
        "type": "uint32",
        "cardinality": "optional",
        "title": "平移步骤",
        "note": ""
      },
      {
        "name": "rotate_state",
        "number": 5,
        "type": "uint32",
        "cardinality": "optional",
        "title": "旋转步骤",
        "note": ""
      },
      {
        "name": "enemy_core_status",
        "number": 6,
        "type": "uint32",
        "cardinality": "optional",
        "title": "对方科技核心状态",
        "note": ""
      },
      {
        "name": "remain_time_all",
        "number": 7,
        "type": "uint32",
        "cardinality": "optional",
        "title": "总体剩余时间",
        "note": ""
      },
      {
        "name": "remain_time_step",
        "number": 8,
        "type": "uint32",
        "cardinality": "optional",
        "title": "当前步骤剩余时间",
        "note": ""
      }
    ]
  },
  {
    "topic": "RobotPerformanceSelectionCommand",
    "group": "",
    "direction": "send",
    "title": "性能与控制方式选择",
    "fields": [
      {
        "name": "shooter",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "发射机构体系",
        "note": ""
      },
      {
        "name": "chassis",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "底盘体系",
        "note": ""
      },
      {
        "name": "sentry_control",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "哨兵控制方式",
        "note": ""
      }
    ]
  },
  {
    "topic": "RobotPerformanceSelectionSync",
    "group": "robotPerfSync",
    "direction": "receive",
    "title": "性能与控制方式同步",
    "fields": [
      {
        "name": "shooter",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "发射机构体系",
        "note": ""
      },
      {
        "name": "chassis",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "底盘体系",
        "note": ""
      },
      {
        "name": "sentry_control",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "哨兵控制方式",
        "note": ""
      }
    ]
  },
  {
    "topic": "CommonCommand",
    "group": "",
    "direction": "send",
    "title": "通用兑换与复活",
    "fields": [
      {
        "name": "cmd_type",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "通用指令类型",
        "note": ""
      },
      {
        "name": "param",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "事件参数",
        "note": ""
      }
    ]
  },
  {
    "topic": "HeroDeployModeEventCommand",
    "group": "",
    "direction": "send",
    "title": "英雄部署指令",
    "fields": [
      {
        "name": "mode",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "部署模式",
        "note": ""
      }
    ]
  },
  {
    "topic": "DeployModeStatusSync",
    "group": "deployMode",
    "direction": "receive",
    "title": "英雄部署状态",
    "fields": [
      {
        "name": "status",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "当前状态",
        "note": ""
      }
    ]
  },
  {
    "topic": "RuneActivateCommand",
    "group": "",
    "direction": "send",
    "title": "能量机关激活",
    "fields": [
      {
        "name": "activate",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "激活标志",
        "note": ""
      }
    ]
  },
  {
    "topic": "RuneStatusSync",
    "group": "runeStatus",
    "direction": "receive",
    "title": "能量机关状态",
    "fields": [
      {
        "name": "rune_status",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "能量机关状态",
        "note": ""
      },
      {
        "name": "activated_arms",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "已激活灯臂数",
        "note": ""
      },
      {
        "name": "average_rings",
        "number": 3,
        "type": "float",
        "cardinality": "optional",
        "title": "平均环数",
        "note": ""
      }
    ]
  },
  {
    "topic": "SentryStatusSync",
    "group": "sentryStatus",
    "direction": "receive",
    "title": "哨兵姿态",
    "fields": [
      {
        "name": "posture_id",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "战术姿态",
        "note": ""
      },
      {
        "name": "is_weakened",
        "number": 2,
        "type": "bool",
        "cardinality": "optional",
        "title": "虚弱状态",
        "note": ""
      },
      {
        "name": "is_powered",
        "number": 3,
        "type": "bool",
        "cardinality": "optional",
        "title": "强化状态",
        "note": ""
      }
    ]
  },
  {
    "topic": "DartCommand",
    "group": "",
    "direction": "send",
    "title": "飞镖指令",
    "fields": [
      {
        "name": "target_id",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "目标编号",
        "note": ""
      },
      {
        "name": "open",
        "number": 2,
        "type": "bool",
        "cardinality": "optional",
        "title": "开启闸门请求",
        "note": ""
      },
      {
        "name": "launch_confirm",
        "number": 3,
        "type": "bool",
        "cardinality": "optional",
        "title": "发射确认",
        "note": ""
      }
    ]
  },
  {
    "topic": "DartSelectTargetStatusSync",
    "group": "dartTarget",
    "direction": "receive",
    "title": "飞镖目标与闸门",
    "fields": [
      {
        "name": "target_id",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "目标编号",
        "note": ""
      },
      {
        "name": "open",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "闸门同步状态",
        "note": "0 关闭，1 开启中，2 已开启。"
      }
    ]
  },
  {
    "topic": "SentryCtrlCommand",
    "group": "",
    "direction": "send",
    "title": "哨兵控制指令",
    "fields": [
      {
        "name": "command_id",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "控制指令编号",
        "note": ""
      }
    ]
  },
  {
    "topic": "SentryCtrlResult",
    "group": "sentryCtrlResult",
    "direction": "receive",
    "title": "哨兵控制结果",
    "fields": [
      {
        "name": "command_id",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "控制指令编号",
        "note": ""
      },
      {
        "name": "result_code",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "指令结果码",
        "note": ""
      }
    ]
  },
  {
    "topic": "AirSupportCommand",
    "group": "",
    "direction": "send",
    "title": "空中支援指令",
    "fields": [
      {
        "name": "command_id",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "控制指令编号",
        "note": "0 取消，1 免费呼叫，2 付费呼叫，3 付费解除反制。"
      }
    ]
  },
  {
    "topic": "AirSupportStatusSync",
    "group": "airSupport",
    "direction": "receive",
    "title": "空中支援状态",
    "fields": [
      {
        "name": "airsupport_status",
        "number": 1,
        "type": "uint32",
        "cardinality": "optional",
        "title": "空中支援状态",
        "note": ""
      },
      {
        "name": "left_time",
        "number": 2,
        "type": "uint32",
        "cardinality": "optional",
        "title": "免费支援剩余时间",
        "note": ""
      },
      {
        "name": "cost_coins",
        "number": 3,
        "type": "uint32",
        "cardinality": "optional",
        "title": "付费支援已花费金币",
        "note": ""
      },
      {
        "name": "is_being_targeted",
        "number": 4,
        "type": "uint32",
        "cardinality": "optional",
        "title": "激光照射状态",
        "note": ""
      },
      {
        "name": "shooter_status",
        "number": 5,
        "type": "uint32",
        "cardinality": "optional",
        "title": "发射机构状态",
        "note": "0 不可解除锁定，1 正常，2 可付费解除锁定。"
      }
    ]
  }
];
