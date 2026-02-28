#include "MqttRecvHandlers.h"
#include <QDebug>
#include <QString>
#include <QByteArray>
#include <QVariantList>

// ===================== 基础接收处理器通用方法实现 =====================
std::string BaseMqttRecvHandler::mapToString(const QVariantMap& map) const {
    QString str;
    for (auto it = map.constBegin(); it != map.constEnd(); ++it) {
        str += QString("%1: %2, ").arg(it.key()).arg(it.value().toString());
    }
    if (!str.isEmpty()) {
        str.chop(2); // 移除最后一个逗号和空格
    }
    return str.toStdString();
}

// ===================== 1. GameStatusRecvHandler =====================
GameStatusRecvHandler::GameStatusRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string GameStatusRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap GameStatusRecvHandler::toQmlMap(const robomaster::custom_client::GameStatus& status) {
    QVariantMap map;
    map["current_round"] = static_cast<int>(status.current_round());
    map["total_rounds"] = static_cast<int>(status.total_rounds());
    map["red_score"] = static_cast<int>(status.red_score());
    map["blue_score"] = static_cast<int>(status.blue_score());
    map["current_stage"] = static_cast<int>(status.current_stage());
    map["stage_countdown_sec"] = static_cast<int>(status.stage_countdown_sec());
    map["stage_elapsed_sec"] = static_cast<int>(status.stage_elapsed_sec());
    map["is_paused"] = static_cast<bool>(status.is_paused());
    return map;
}

void GameStatusRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析GameStatus消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== GameStatus 数据 ==========";
    qDebug() << "当前局号：" << m_status.current_round() << " 总局数：" << m_status.total_rounds();
    qDebug() << "红方得分：" << m_status.red_score() << " 蓝方得分：" << m_status.blue_score();
    
    QString stageDesc;
    switch (m_status.current_stage()) {
        case 0: stageDesc = "未开始比赛（赛前准备阶段）"; break;
        case 1: stageDesc = "准备阶段（选手就位，设备检查）"; break;
        case 2: stageDesc = "十五秒裁判系统自检阶段"; break;
        case 3: stageDesc = "五秒倒计时（比赛即将开始）"; break;
        case 4: stageDesc = "比赛中（正常竞技阶段）"; break;
        case 5: stageDesc = "比赛结算中（统计比分、判定胜负）"; break;
        case 6: stageDesc = "比赛暂停"; break;
        default: stageDesc = "未知阶段"; break;
    }
    qDebug() << "当前阶段：" << m_status.current_stage() << "(" << stageDesc << ")";
    qDebug() << "阶段剩余时间：" << m_status.stage_countdown_sec() << "s 阶段已过时间：" << m_status.stage_elapsed_sec() << "s";
    qDebug() << "比赛是否暂停：" << (m_status.is_paused() ? "是" : "否");
    
    // 发射信号
    emit gameStatusReceived(m_status);
    emit gameStatusUpdated(toQmlMap(m_status));
}

// ===================== 2. GlobalUnitStatusRecvHandler =====================
GlobalUnitStatusRecvHandler::GlobalUnitStatusRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string GlobalUnitStatusRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap GlobalUnitStatusRecvHandler::toQmlMap(const robomaster::custom_client::GlobalUnitStatus& status) {
    QVariantMap map;
    map["base_health"] = static_cast<int>(status.base_health());
    map["base_status"] = static_cast<int>(status.base_status());
    map["base_shield"] = static_cast<int>(status.base_shield());
    map["outpost_health"] = static_cast<int>(status.outpost_health());
    map["outpost_status"] = static_cast<int>(status.outpost_status());
    map["enemy_base_health"] = static_cast<int>(status.enemy_base_health());
    map["enemy_base_status"] = static_cast<int>(status.enemy_base_status());
    map["enemy_base_shield"] = static_cast<int>(status.enemy_base_shield());
    map["enemy_outpost_health"] = static_cast<int>(status.enemy_outpost_health());
    map["enemy_outpost_status"] = static_cast<int>(status.enemy_outpost_status());
    map["total_damage_ally"] = static_cast<int>(status.total_damage_ally());
    map["total_damage_enemy"] = static_cast<int>(status.total_damage_enemy());
    
    // 数组类型转QVariantList
    QVariantList robotHealthList;
    for (int i = 0; i < status.robot_health_size(); ++i) {
        robotHealthList.append(static_cast<int>(status.robot_health(i)));
    }
    map["robot_health"] = robotHealthList;
    
    QVariantList robotBulletsList;
    for (int i = 0; i < status.robot_bullets_size(); ++i) {
        robotBulletsList.append(static_cast<int>(status.robot_bullets(i)));
    }
    map["robot_bullets"] = robotBulletsList;
    
    return map;
}

void GlobalUnitStatusRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析GlobalUnitStatus消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== GlobalUnitStatus 数据 ==========";
    qDebug() << "己方基地血量：" << m_status.base_health() << "点 基地状态：" << m_status.base_status();
    qDebug() << "己方基地护盾：" << m_status.base_shield() << "点 前哨站血量：" << m_status.outpost_health() << "点";
    
    QString outpostStatusDesc;
    switch (m_status.outpost_status()) {
        case 0: outpostStatusDesc = "无敌（赛前保护）"; break;
        case 1: outpostStatusDesc = "存活，中部装甲旋转"; break;
        case 2: outpostStatusDesc = "存活，中部装甲停转"; break;
        case 3: outpostStatusDesc = "被击毁，不可重建"; break;
        case 4: outpostStatusDesc = "被击毁，可重建"; break;
        case 5: outpostStatusDesc = "被击毁，重建中"; break;
        default: outpostStatusDesc = "未知状态"; break;
    }
    qDebug() << "前哨站状态：" << outpostStatusDesc << " 对方基地血量：" << m_status.enemy_base_health() << "点";
    qDebug() << "对方基地状态：" << m_status.enemy_base_status() << " 对方基地护盾：" << m_status.enemy_base_shield() << "点";
    qDebug() << "对方前哨站血量：" << m_status.enemy_outpost_health() << "点 对方前哨站状态：" << m_status.enemy_outpost_status();
    
     qDebug() << "所有机器人血量列表：";
    if (m_status.robot_health_size() > 0) {
        for (int i = 0; i < m_status.robot_health_size(); ++i) {
            qDebug() << "  机器人[" << i << "]：" << m_status.robot_health(i) << "点";
        }
    } else {
        qDebug() << "  无机器人血量数据";
    }
    
    // 修改2：去掉条件判断，始终打印，无数据时提示
    qDebug() << "己方机器人剩余发弹量列表：";
    if (m_status.robot_bullets_size() > 0) {
        for (int i = 0; i < m_status.robot_bullets_size(); ++i) {
            qDebug() << "  机器人[" << i << "]：" << m_status.robot_bullets(i) << "发";
        }
    } else {
        qDebug() << "  无机器人发弹量数据";
    }
    qDebug() << "己方累计造成伤害：" << m_status.total_damage_ally() << "点 对方累计造成伤害：" << m_status.total_damage_enemy() << "点";
    
    // 发射信号
    emit globalUnitStatusReceived(m_status);
    emit globalUnitStatusUpdated(toQmlMap(m_status));
}

// ===================== 3. GlobalLogisticsRecvHandler =====================
GlobalLogisticsRecvHandler::GlobalLogisticsRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string GlobalLogisticsRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap GlobalLogisticsRecvHandler::toQmlMap(const robomaster::custom_client::GlobalLogisticsStatus& status) {
    QVariantMap map;
    map["remaining_economy"] = static_cast<int>(status.remaining_economy());
    map["total_economy_obtained"] = static_cast<qulonglong>(status.total_economy_obtained());
    map["tech_level"] = static_cast<int>(status.tech_level());
    map["encryption_level"] = static_cast<int>(status.encryption_level());
    return map;
}

void GlobalLogisticsRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析GlobalLogisticsStatus消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== GlobalLogisticsStatus 数据 ==========";
    qDebug() << "剩余经济：" << m_status.remaining_economy() << "金币 累计获得经济：" << m_status.total_economy_obtained() << "金币";
    qDebug() << "科技等级：" << m_status.tech_level() << " 加密等级（对方干扰波难度）：" << m_status.encryption_level() << "级";
    
    // 发射信号
    emit globalLogisticsReceived(m_status);
    emit globalLogisticsUpdated(toQmlMap(m_status));
}

// ===================== 4. GlobalSpecialMechanismRecvHandler =====================
GlobalSpecialMechanismRecvHandler::GlobalSpecialMechanismRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string GlobalSpecialMechanismRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap GlobalSpecialMechanismRecvHandler::toQmlMap(const robomaster::custom_client::GlobalSpecialMechanism& status) {
    QVariantMap map;
    
    QVariantList mechanismIdList;
    QVariantList mechanismTimeList;
    for (int i = 0; i < status.mechanism_id_size(); ++i) {
        mechanismIdList.append(static_cast<int>(status.mechanism_id(i)));
        mechanismTimeList.append(static_cast<int>(status.mechanism_time_sec(i)));
    }
    
    map["mechanism_id"] = mechanismIdList;
    map["mechanism_time_sec"] = mechanismTimeList;
    return map;
}

void GlobalSpecialMechanismRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析GlobalSpecialMechanism消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== GlobalSpecialMechanism 数据 ==========";
    if (m_status.mechanism_id_size() == 0) {
        qDebug() << "当前无生效的特殊机制";
    } else {
        for (int i = 0; i < m_status.mechanism_id_size(); ++i) {
            QString mechanismDesc;
            switch (m_status.mechanism_id(i)) {
                case 1: mechanismDesc = "己方堡垒被对方占领计时"; break;
                case 2: mechanismDesc = "对方堡垒被己方占领计时"; break;
                default: mechanismDesc = "未知机制"; break;
            }
            qDebug() << "机制ID：" << m_status.mechanism_id(i) << "(" << mechanismDesc << ") 剩余时间：" << m_status.mechanism_time_sec(i) << "s";
        }
    }
    
    // 发射信号
    emit globalSpecialMechanismReceived(m_status);
    emit globalSpecialMechanismUpdated(toQmlMap(m_status));
}

// ===================== 5. EventRecvHandler =====================
EventRecvHandler::EventRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string EventRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap EventRecvHandler::toQmlMap(const robomaster::custom_client::Event& event) {
    QVariantMap map;
    map["event_id"] = static_cast<int>(event.event_id());
    map["param"] = QString::fromStdString(event.param());
    return map;
}

void EventRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_event)) {
        qWarning() << "解析Event消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== Event 数据 ==========";
    QString eventDesc;
    switch (m_event.event_id()) {
        case 1: eventDesc = "击杀事件"; break;
        case 2: eventDesc = "基地/前哨站被摧毁事件"; break;
        case 3: eventDesc = "能量机关可激活次数变化"; break;
        case 4: eventDesc = "能量单元当前可进入正在激活状态"; break;
        case 5: eventDesc = "能量机关激活结果"; break;
        case 6: eventDesc = "能量机关被激活"; break;
        case 7: eventDesc = "己方英雄进入部署模式"; break;
        case 8: eventDesc = "己方英雄造成狙击伤害"; break;
        case 9: eventDesc = "对方英雄造成狙击伤害"; break;
        case 10: eventDesc = "己方呼叫空中支援"; break;
        case 11: eventDesc = "己方空中支援被打断"; break;
        case 12: eventDesc = "对方呼叫空中支援"; break;
        case 13: eventDesc = "对方空中支援被打断"; break;
        case 14: eventDesc = "飞镖命中"; break;
        case 15: eventDesc = "飞镖闸门开启"; break;
        case 16: eventDesc = "己方基地遭到攻击"; break;
        case 17: eventDesc = "前哨站停转"; break;
        case 18: eventDesc = "基地护甲展开"; break;
        default: eventDesc = "未知事件"; break;
    }
    qDebug() << "事件ID：" << m_event.event_id() << "(" << eventDesc << ") 事件参数：" << QString::fromStdString(m_event.param());
    
    // 发射信号
    emit eventReceived(m_event);
    emit eventUpdated(toQmlMap(m_event));
}

// ===================== 6. RobotInjuryStatRecvHandler =====================
RobotInjuryStatRecvHandler::RobotInjuryStatRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string RobotInjuryStatRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap RobotInjuryStatRecvHandler::toQmlMap(const robomaster::custom_client::RobotInjuryStat& stat) {
    QVariantMap map;
    map["total_damage"] = static_cast<int>(stat.total_damage());
    map["collision_damage"] = static_cast<int>(stat.collision_damage());
    map["small_projectile_damage"] = static_cast<int>(stat.small_projectile_damage());
    map["large_projectile_damage"] = static_cast<int>(stat.large_projectile_damage());
    map["dart_splash_damage"] = static_cast<int>(stat.dart_splash_damage());
    map["module_offline_damage"] = static_cast<int>(stat.module_offline_damage());
    map["offline_damage"] = static_cast<int>(stat.offline_damage());
    map["penalty_damage"] = static_cast<int>(stat.penalty_damage());
    map["server_kill_damage"] = static_cast<int>(stat.server_kill_damage());
    map["killer_id"] = static_cast<int>(stat.killer_id());
    return map;
}

void RobotInjuryStatRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_stat)) {
        qWarning() << "解析RobotInjuryStat消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== RobotInjuryStat 数据 ==========";
    qDebug() << "本次存活累计受伤总量：" << m_stat.total_damage() << "点";
    qDebug() << "  - 撞击伤害：" << m_stat.collision_damage() << "点";
    qDebug() << "  - 17mm弹丸伤害：" << m_stat.small_projectile_damage() << "点";
    qDebug() << "  - 42mm弹丸伤害：" << m_stat.large_projectile_damage() << "点";
    qDebug() << "  - 飞镖溅射伤害：" << m_stat.dart_splash_damage() << "点";
    qDebug() << "  - 模块离线扣血：" << m_stat.module_offline_damage() << "点";
    qDebug() << "  - 异常离线扣血：" << m_stat.offline_damage() << "点";
    qDebug() << "  - 判罚扣血：" << m_stat.penalty_damage() << "点";
    qDebug() << "  - 服务器强制战亡扣血：" << m_stat.server_kill_damage() << "点";
    qDebug() << "击杀者ID：" << m_stat.killer_id() << (m_stat.killer_id() == 0 ? "（未检测到击杀者）" : "");
    
    // 发射信号
    emit robotInjuryStatReceived(m_stat);
    emit robotInjuryStatUpdated(toQmlMap(m_stat));
}

// ===================== 7. RobotRespawnRecvHandler =====================
RobotRespawnRecvHandler::RobotRespawnRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string RobotRespawnRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap RobotRespawnRecvHandler::toQmlMap(const robomaster::custom_client::RobotRespawnStatus& status) {
    QVariantMap map;
    map["is_pending_respawn"] = static_cast<bool>(status.is_pending_respawn());
    map["current_respawn_progress"] = static_cast<int>(status.current_respawn_progress());
    map["total_respawn_progress"] = static_cast<int>(status.total_respawn_progress());
    map["can_free_respawn"] = static_cast<bool>(status.can_free_respawn());
    map["gold_cost_for_respawn"] = static_cast<int>(status.gold_cost_for_respawn());
    map["can_pay_for_respawn"] = static_cast<bool>(status.can_pay_for_respawn());
    return map;
}

void RobotRespawnRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析RobotRespawnStatus消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== RobotRespawnStatus 数据 ==========";
    qDebug() << "是否待复活：" << (m_status.is_pending_respawn() ? "是" : "否");
    qDebug() << "复活进度：" << m_status.current_respawn_progress() << "/" << m_status.total_respawn_progress() 
             << "(" << QString::number((float)m_status.current_respawn_progress()/m_status.total_respawn_progress()*100, 'f', 1) << "%)";
    qDebug() << "是否免费复活：" << (m_status.can_free_respawn() ? "是" : "否");
    if (!m_status.can_free_respawn()) {
        qDebug() << "金币复活消耗：" << m_status.gold_cost_for_respawn() << "金币 是否允许金币复活：" << (m_status.can_pay_for_respawn() ? "是" : "否");
    }
    
    // 发射信号
    emit robotRespawnReceived(m_status);
    emit robotRespawnUpdated(toQmlMap(m_status));
}

// ===================== 8. RobotStaticStatusRecvHandler =====================
RobotStaticStatusRecvHandler::RobotStaticStatusRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string RobotStaticStatusRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap RobotStaticStatusRecvHandler::toQmlMap(const robomaster::custom_client::RobotStaticStatus& status) {
    QVariantMap map;
    map["robot_id"] = static_cast<int>(status.robot_id());
    map["robot_type"] = static_cast<int>(status.robot_type());
    map["connection_state"] = static_cast<int>(status.connection_state());
    map["field_state"] = static_cast<int>(status.field_state());
    map["alive_state"] = static_cast<int>(status.alive_state());
    map["performance_system_shooter"] = static_cast<int>(status.performance_system_shooter());
    map["performance_system_chassis"] = static_cast<int>(status.performance_system_chassis());
    map["level"] = static_cast<int>(status.level());
    map["max_health"] = static_cast<int>(status.max_health());
    map["max_heat"] = static_cast<float>(status.max_heat());
    map["heat_cooldown_rate"] = static_cast<float>(status.heat_cooldown_rate());
    map["max_power"] = static_cast<int>(status.max_power());
    map["max_buffer_energy"] = static_cast<int>(status.max_buffer_energy());
    map["max_chassis_energy"] = static_cast<int>(status.max_chassis_energy());
    return map;
}

void RobotStaticStatusRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析RobotStaticStatus消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== RobotStaticStatus 数据 ==========";
    QString robotTypeDesc;
    switch (m_status.robot_type()) {
        case 1: robotTypeDesc = "英雄"; break;
        case 2: robotTypeDesc = "工程"; break;
        case 3: robotTypeDesc = "步兵"; break;
        case 4: robotTypeDesc = "空中"; break;
        case 5: robotTypeDesc = "哨兵"; break;
        case 6: robotTypeDesc = "飞镖"; break;
        case 7: robotTypeDesc = "雷达"; break;
        case 8: robotTypeDesc = "前哨站"; break;
        case 9: robotTypeDesc = "基地"; break;
        default: robotTypeDesc = "未知类型"; break;
    }
    
    QString connStateDesc = m_status.connection_state() == 0 ? "未连接" : (m_status.connection_state() == 1 ? "已连接" : "安装不规范视为离线");
    QString fieldStateDesc = m_status.field_state() == 0 ? "已上场" : "未上场/被罚下";
    QString aliveStateDesc = m_status.alive_state() == 0 ? "未知（连接异常）" : (m_status.alive_state() == 1 ? "存活" : "战亡");
    
    qDebug() << "机器人ID：" << m_status.robot_id() << " 机器人类型：" << m_status.robot_type() << "(" << robotTypeDesc << ")";
    qDebug() << "连接状态：" << m_status.connection_state() << "(" << connStateDesc << ") 上场状态：" << m_status.field_state() << "(" << fieldStateDesc << ")";
    qDebug() << "存活状态：" << m_status.alive_state() << "(" << aliveStateDesc << ")";
    
    QString shooterDesc;
    switch (m_status.performance_system_shooter()) {
        case 1: shooterDesc = "冷却优先"; break;
        case 2: shooterDesc = "爆发优先"; break;
        case 3: shooterDesc = "英雄近战优先"; break;
        case 4: shooterDesc = "英雄远程优先"; break;
        default: shooterDesc = "未知配置"; break;
    }
    qDebug() << "发射机构性能体系：" << shooterDesc;
    
    QString chassisDesc;
    switch (m_status.performance_system_chassis()) {
        case 1: chassisDesc = "血量优先"; break;
        case 2: chassisDesc = "功率优先"; break;
        case 3: chassisDesc = "英雄近战优先"; break;
        case 4: chassisDesc = "英雄远程优先"; break;
        default: chassisDesc = "未知配置"; break;
    }
    qDebug() << "底盘性能体系：" << chassisDesc;
    
    qDebug() << "等级：" << m_status.level() << " 最大血量：" << m_status.max_health() << "点 最大热量：" << m_status.max_heat() << "点";
    qDebug() << "热量冷却速率：" << QString::number(m_status.heat_cooldown_rate(), 'f', 2) << "点/秒 最大功率：" << m_status.max_power() << "W";
    qDebug() << "最大缓冲能量：" << m_status.max_buffer_energy() << "J 最大底盘能量：" << m_status.max_chassis_energy() << "J";
    
    // 发射信号
    emit robotStaticStatusReceived(m_status);
    emit robotStaticStatusUpdated(toQmlMap(m_status));
}

// ===================== 9. RobotDynamicStatusRecvHandler =====================
RobotDynamicStatusRecvHandler::RobotDynamicStatusRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string RobotDynamicStatusRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap RobotDynamicStatusRecvHandler::toQmlMap(const robomaster::custom_client::RobotDynamicStatus& status) {
    QVariantMap map;
    map["current_health"] = static_cast<int>(status.current_health());
    map["current_heat"] = static_cast<float>(status.current_heat());
    map["last_projectile_fire_rate"] = static_cast<float>(status.last_projectile_fire_rate());
    map["current_chassis_energy"] = static_cast<int>(status.current_chassis_energy());
    map["current_buffer_energy"] = static_cast<int>(status.current_buffer_energy());
    map["current_experience"] = static_cast<int>(status.current_experience());
    map["experience_for_upgrade"] = static_cast<int>(status.experience_for_upgrade());
    map["total_projectiles_fired"] = static_cast<int>(status.total_projectiles_fired());
    map["remaining_ammo"] = static_cast<int>(status.remaining_ammo());
    map["is_out_of_combat"] = static_cast<bool>(status.is_out_of_combat());
    map["out_of_combat_countdown"] = static_cast<int>(status.out_of_combat_countdown());
    map["can_remote_heal"] = static_cast<bool>(status.can_remote_heal());
    map["can_remote_ammo"] = static_cast<bool>(status.can_remote_ammo());
    return map;
}

void RobotDynamicStatusRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析RobotDynamicStatus消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== RobotDynamicStatus 数据 ==========";
    qDebug() << "当前血量：" << m_status.current_health() << "点 当前热量：" << QString::number(m_status.current_heat(), 'f', 2) << "点";
    qDebug() << "上一次射击射速：" << QString::number(m_status.last_projectile_fire_rate(), 'f', 2) << "Hz 底盘剩余能量：" << m_status.current_chassis_energy() << "J";
    qDebug() << "缓冲能量：" << m_status.current_buffer_energy() << "J 当前经验：" << m_status.current_experience() << "点";
    qDebug() << "升级所需经验：" << m_status.experience_for_upgrade() << "点 累计发射弹丸：" << m_status.total_projectiles_fired() << "发";
    qDebug() << "剩余允许发弹量：" << m_status.remaining_ammo() << "发 是否脱战：" << (m_status.is_out_of_combat() ? "是" : "否");
    qDebug() << "脱战倒计时：" << m_status.out_of_combat_countdown() << "s（倒计时结束后可脱战回血）";
    qDebug() << "是否可远程补血：" << (m_status.can_remote_heal() ? "是" : "否") << " 是否可远程补弹：" << (m_status.can_remote_ammo() ? "是" : "否");
    
    // 发射信号
    emit robotDynamicStatusReceived(m_status);
    emit robotDynamicStatusUpdated(toQmlMap(m_status));
}

// ===================== 10. RobotModuleStatusRecvHandler =====================
RobotModuleStatusRecvHandler::RobotModuleStatusRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string RobotModuleStatusRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap RobotModuleStatusRecvHandler::toQmlMap(const robomaster::custom_client::RobotModuleStatus& status) {
    QVariantMap map;
    map["main_controller"] = static_cast<int>(status.main_controller());
    map["power_manager"] = static_cast<int>(status.power_manager());
    map["rfid"] = static_cast<int>(status.rfid());
    map["light_strip"] = static_cast<int>(status.light_strip());
    map["small_shooter"] = static_cast<int>(status.small_shooter());
    map["big_shooter"] = static_cast<int>(status.big_shooter());
    map["uwb"] = static_cast<int>(status.uwb());
    map["armor"] = static_cast<int>(status.armor());
    map["video_transmission"] = static_cast<int>(status.video_transmission());
    map["capacitor"] = static_cast<int>(status.capacitor());
    map["laser_detection_module"] = static_cast<int>(status.laser_detection_module());
    return map;
}

void RobotModuleStatusRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析RobotModuleStatus消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== RobotModuleStatus 数据 ==========";
    auto getModuleStatusDesc = [](uint32_t status) -> QString {
        switch (status) {
            case 0: return "离线";
            case 1: return "在线";
            case 2: return "安装不规范视为离线";
            default: return "未知状态";
        }
    };
    
    qDebug() << "主控模块：" << m_status.main_controller() << "(" << getModuleStatusDesc(m_status.main_controller()) << ")";
    qDebug() << "电源管理模块：" << m_status.power_manager() << "(" << getModuleStatusDesc(m_status.power_manager()) << ")";
    qDebug() << "RFID模块：" << m_status.rfid() << "(" << getModuleStatusDesc(m_status.rfid()) << ")";
    qDebug() << "灯条模块：" << m_status.light_strip() << "(" << getModuleStatusDesc(m_status.light_strip()) << ")";
    qDebug() << "17mm发射机构：" << m_status.small_shooter() << "(" << getModuleStatusDesc(m_status.small_shooter()) << ")";
    qDebug() << "42mm发射机构：" << m_status.big_shooter() << "(" << getModuleStatusDesc(m_status.big_shooter()) << ")";
    qDebug() << "UWB定位模块：" << m_status.uwb() << "(" << getModuleStatusDesc(m_status.uwb()) << ")";
    qDebug() << "装甲模块：" << m_status.armor() << "(" << getModuleStatusDesc(m_status.armor()) << ")";
    qDebug() << "图传模块：" << m_status.video_transmission() << "(" << getModuleStatusDesc(m_status.video_transmission()) << ")";
    qDebug() << "电容模块：" << m_status.capacitor() << "(" << getModuleStatusDesc(m_status.capacitor()) << ")";
    qDebug() << "激光检测模块：" << m_status.laser_detection_module() << "(" << getModuleStatusDesc(m_status.laser_detection_module()) << ")";
    
    // 发射信号
    emit robotModuleStatusReceived(m_status);
    emit robotModuleStatusUpdated(toQmlMap(m_status));
}

// ===================== 11. RobotPositionRecvHandler =====================
RobotPositionRecvHandler::RobotPositionRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string RobotPositionRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap RobotPositionRecvHandler::toQmlMap(const robomaster::custom_client::RobotPosition& pos) {
    QVariantMap map;
    map["x"] = static_cast<float>(pos.x());
    map["y"] = static_cast<float>(pos.y());
    map["z"] = static_cast<float>(pos.z());
    map["yaw"] = static_cast<float>(pos.yaw());
    return map;
}

void RobotPositionRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_pos)) {
        qWarning() << "解析RobotPosition消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== RobotPosition 数据 ==========";
    qDebug() << "世界坐标(X,Y,Z)：" << QString::number(m_pos.x(), 'f', 2) << "," 
             << QString::number(m_pos.y(), 'f', 2) << "," 
             << QString::number(m_pos.z(), 'f', 2) << "米";
    qDebug() << "朝向角度：" << QString::number(m_pos.yaw(), 'f', 1) << "°（正北为0度，顺时针递增）";
    
    // 发射信号
    emit robotPositionReceived(m_pos);
    emit robotPositionUpdated(toQmlMap(m_pos));
}

// ===================== 12. BuffRecvHandler =====================
BuffRecvHandler::BuffRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string BuffRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap BuffRecvHandler::toQmlMap(const robomaster::custom_client::Buff& buff) {
    QVariantMap map;
    map["robot_id"] = static_cast<int>(buff.robot_id());
    map["buff_type"] = static_cast<int>(buff.buff_type());
    map["buff_level"] = static_cast<int>(buff.buff_level());
    map["buff_max_time"] = static_cast<int>(buff.buff_max_time());
    map["buff_left_time"] = static_cast<int>(buff.buff_left_time());
    return map;
}

void BuffRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_buff)) {
        qWarning() << "解析Buff消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== Buff 数据 ==========";
    qDebug() << "机器人ID：" << m_buff.robot_id();
    
    QString buffTypeDesc;
    switch (m_buff.buff_type()) {
        case 1: buffTypeDesc = "攻击增益（提升武器伤害）"; break;
        case 2: buffTypeDesc = "防御增益（降低受到的伤害）"; break;
        case 3: buffTypeDesc = "射击热量冷却增益（提升热量冷却速度）"; break;
        case 4: buffTypeDesc = "底盘功率增益（提升移动速度）"; break;
        case 5: buffTypeDesc = "回血增益（每秒自动恢复血量）"; break;
        case 6: buffTypeDesc = "可兑换允许发弹量（增加最大允许发弹量）"; break;
        case 7: buffTypeDesc = "地形跨越增益（预备）"; break;
        default: buffTypeDesc = "未知Buff类型"; break;
    }
    qDebug() << "Buff类型：" << m_buff.buff_type() << "(" << buffTypeDesc << ")";
    
    QString buffLevelDesc;
    if (m_buff.buff_type() == 1 || m_buff.buff_type() == 2 || m_buff.buff_type() == 4 || m_buff.buff_type() == 5) {
        buffLevelDesc = QString::number(m_buff.buff_level()) + "%";
    } else if (m_buff.buff_type() == 3) {
        buffLevelDesc = QString::number(m_buff.buff_level()) + "点/秒";
    } else if (m_buff.buff_type() == 6) {
        buffLevelDesc = QString::number(m_buff.buff_level()) + "发";
    } else {
        buffLevelDesc = QString::number(m_buff.buff_level());
    }
    qDebug() << "Buff等级：" << m_buff.buff_level() << "(" << buffLevelDesc << ")";
    qDebug() << "Buff最大持续时间：" << m_buff.buff_max_time() << "s 剩余时间：" << m_buff.buff_left_time() << "s";
    
    // 发射信号
    emit buffReceived(m_buff);
    emit buffUpdated(toQmlMap(m_buff));
}

// ===================== 13. PenaltyInfoRecvHandler =====================
PenaltyInfoRecvHandler::PenaltyInfoRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string PenaltyInfoRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap PenaltyInfoRecvHandler::toQmlMap(const robomaster::custom_client::PenaltyInfo& info) {
    QVariantMap map;
    map["penalty_type"] = static_cast<int>(info.penalty_type());
    map["penalty_effect_sec"] = static_cast<int>(info.penalty_effect_sec());
    map["total_penalty_num"] = static_cast<int>(info.total_penalty_num());
    return map;
}

void PenaltyInfoRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_info)) {
        qWarning() << "解析PenaltyInfo消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== PenaltyInfo 数据 ==========";
    QString penaltyTypeDesc;
    switch (m_info.penalty_type()) {
        case 1: penaltyTypeDesc = "黄牌（轻度违规警告）"; break;
        case 2: penaltyTypeDesc = "双方黄牌（双方均有违规）"; break;
        case 3: penaltyTypeDesc = "红牌（严重违规，机器人被罚下）"; break;
        case 4: penaltyTypeDesc = "超功率（底盘功率超过上限）"; break;
        case 5: penaltyTypeDesc = "超热量（发射机构热量超过上限）"; break;
        case 6: penaltyTypeDesc = "超射速（射击频率超过上限）"; break;
        default: penaltyTypeDesc = "未知判罚类型"; break;
    }
    qDebug() << "判罚类型：" << m_info.penalty_type() << "(" << penaltyTypeDesc << ")";
    qDebug() << "判罚效果持续时间：" << m_info.penalty_effect_sec() << "s" << (m_info.penalty_effect_sec() == 0 ? "（永久）" : "");
    qDebug() << "累计判罚次数：" << m_info.total_penalty_num();
    
    // 发射信号
    emit penaltyInfoReceived(m_info);
    emit penaltyInfoUpdated(toQmlMap(m_info));
}

// ===================== 14. RobotPathPlanRecvHandler =====================
RobotPathPlanRecvHandler::RobotPathPlanRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string RobotPathPlanRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap RobotPathPlanRecvHandler::toQmlMap(const robomaster::custom_client::RobotPathPlanInfo& info) {
    QVariantMap map;
    map["intention"] = static_cast<int>(info.intention());
    map["sender_id"] = static_cast<int>(info.sender_id());
    map["start_pos_x"] = static_cast<int>(info.start_pos_x());
    map["start_pos_y"] = static_cast<int>(info.start_pos_y());
    map["offset_x_size"] = static_cast<int>(info.offset_x_size());
    map["offset_y_size"] = static_cast<int>(info.offset_y_size());
    
    // 增量数组转List
    QVariantList offsetXList = repeatedFieldToList(info.offset_x());
    QVariantList offsetYList = repeatedFieldToList(info.offset_y());
    map["offset_x"] = offsetXList;
    map["offset_y"] = offsetYList;
    
    return map;
}

void RobotPathPlanRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_info)) {
        qWarning() << "解析RobotPathPlanInfo消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== RobotPathPlanInfo 数据 ==========";
    QString intentionDesc;
    switch (m_info.intention()) {
        case 1: intentionDesc = "攻击（前往目标点攻击）"; break;
        case 2: intentionDesc = "防御（前往目标点防守）"; break;
        case 3: intentionDesc = "移动（仅移动至目标点）"; break;
        default: intentionDesc = "未知意图"; break;
    }
    qDebug() << "哨兵意图：" << m_info.intention() << "(" << intentionDesc << ") 发送方ID：" << m_info.sender_id();
    qDebug() << "轨迹起始点坐标(X,Y)：" << m_info.start_pos_x() << "," << m_info.start_pos_y() << "分米";
    qDebug() << "轨迹X轴偏移量数组长度：" << m_info.offset_x_size() 
             << " Y轴偏移量数组长度：" << m_info.offset_y_size();
    
    // 发射信号
    emit robotPathPlanReceived(m_info);
    emit robotPathPlanUpdated(toQmlMap(m_info));
}

// ===================== 15. RadarInfoRecvHandler =====================
RadarInfoRecvHandler::RadarInfoRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string RadarInfoRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap RadarInfoRecvHandler::toQmlMap(const robomaster::custom_client::RadarInfoToClient& info) {
    QVariantMap map;
    map["target_robot_id"] = static_cast<int>(info.target_robot_id());
    map["target_pos_x"] = static_cast<float>(info.target_pos_x());
    map["target_pos_y"] = static_cast<float>(info.target_pos_y());
    map["torward_angle"] = static_cast<float>(info.toward_angle());
    map["is_high_light"] = static_cast<int>(info.is_high_light());
    return map;
}

void RadarInfoRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_info)) {
        qWarning() << "解析RadarInfoToClient消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== RadarInfoToClient 数据 ==========";
    qDebug() << "目标机器人ID：" << m_info.target_robot_id();
    qDebug() << "目标机器人坐标(X,Y)：" << QString::number(m_info.target_pos_x(), 'f', 2) << "," 
             << QString::number(m_info.target_pos_y(), 'f', 2) << "米";
    qDebug() << "目标机器人朝向角度：" << QString::number(m_info.toward_angle(), 'f', 1) << "°（正北为0度，顺时针递增）";
    
    QString highLightDesc;
    switch (m_info.is_high_light()) {
        case 0: highLightDesc = "否"; break;
        case 1: highLightDesc = "是"; break;
        case 2: highLightDesc = "是但目标定位模块离线"; break;
        default: highLightDesc = "未知状态"; break;
    }
    qDebug() << "目标机器人是否被特殊标识：" << m_info.is_high_light() << "(" << highLightDesc << ")";
    
    // 发射信号
    emit radarInfoReceived(m_info);
    emit radarInfoUpdated(toQmlMap(m_info));
}

// ===================== 16. CustomByteBlockRecvHandler =====================
CustomByteBlockRecvHandler::CustomByteBlockRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string CustomByteBlockRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap CustomByteBlockRecvHandler::toQmlMap(const robomaster::custom_client::CustomByteBlock& data) {
    QVariantMap map;
    map["data_size"] = static_cast<int>(data.data().size());
    // 二进制数据转16进制字符串
    QByteArray byteData(reinterpret_cast<const char*>(data.data().data()), data.data().size());
    map["data_hex"] = byteData.toHex();
    return map;
}

void CustomByteBlockRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_data)) {
        qWarning() << "解析CustomByteBlock消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== CustomByteBlock 数据 ==========";
    qDebug() << "自定义二进制数据长度：" << m_data.data().size() << "字节（最大支持300字节）";
    
    if (m_data.data().size() > 0) {
        QByteArray data(reinterpret_cast<const char*>(m_data.data().data()), m_data.data().size());
        qDebug() << "自定义数据(16进制)：" << data.toHex();
    }
    
    // 发射信号
    emit customByteBlockReceived(m_data);
    emit customByteBlockUpdated(toQmlMap(m_data));
}

// ===================== 17. TechCoreMotionRecvHandler =====================
TechCoreMotionRecvHandler::TechCoreMotionRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string TechCoreMotionRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap TechCoreMotionRecvHandler::toQmlMap(const robomaster::custom_client::TechCoreMotionStateSync& status) {
    QVariantMap map;
    map["maximum_difficulty_level"] = static_cast<int>(status.maximum_difficulty_level());
    map["status"] = static_cast<int>(status.status());
    map["enemy_core_status"] = static_cast<int>(status.enemy_core_status());
    map["remain_time_all"] = static_cast<int>(status.remain_time_all());
    map["remain_time_step"] = static_cast<int>(status.remain_time_step());
    return map;
}

void TechCoreMotionRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析TechCoreMotionStateSync消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== TechCoreMotionStateSync 数据 ==========";
    qDebug() << "当前可选择的最高装配难度等级：" << m_status.maximum_difficulty_level() << "级（1=简单，2=中等，3=困难，4=专家）";
    
    QString coreStatusDesc;
    switch (m_status.status()) {
        case 1: coreStatusDesc = "未进入装配状态（初始状态，未选择装配难度）"; break;
        case 2: coreStatusDesc = "已选择装配难度，科技核心移动中（前往装配位置）"; break;
        case 3: coreStatusDesc = "科技核心移动完成，可进行首个装配步骤"; break;
        case 4: coreStatusDesc = "上一个装配步骤已完成，可进行下一个装配步骤"; break;
        case 5: coreStatusDesc = "所有装配步骤已完成（装配成功）"; break;
        case 6: coreStatusDesc = "已确认装配，科技核心移动中（装配完成后返回初始位置）"; break;
        default: coreStatusDesc = "未知状态"; break;
    }
    qDebug() << "己方科技核心状态：" << m_status.status() << "(" << coreStatusDesc << ")";
    
    QString enemyCoreDesc;
    switch (m_status.enemy_core_status()) {
        case 0: enemyCoreDesc = "对方无装配"; break;
        case 1: enemyCoreDesc = "对方装配非四级"; break;
        case 2: enemyCoreDesc = "对方装配四级"; break;
        default: enemyCoreDesc = "未知状态"; break;
    }
    qDebug() << "对方科技核心状态：" << m_status.enemy_core_status() << "(" << enemyCoreDesc << ")";
    
    if (m_status.maximum_difficulty_level() == 4) {
        qDebug() << "己方四级装配总剩余时长：" << m_status.remain_time_all() << "s 单步骤剩余时长：" << m_status.remain_time_step() << "s";
    }
    
    // 发射信号
    emit techCoreMotionReceived(m_status);
    emit techCoreMotionUpdated(toQmlMap(m_status));
}

// ===================== 18. RobotPerformanceSyncRecvHandler =====================
RobotPerformanceSyncRecvHandler::RobotPerformanceSyncRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string RobotPerformanceSyncRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap RobotPerformanceSyncRecvHandler::toQmlMap(const robomaster::custom_client::RobotPerformanceSelectionSync& status) {
    QVariantMap map;
    map["shooter"] = static_cast<int>(status.shooter());
    map["chassis"] = static_cast<int>(status.chassis());
    map["sentry_control"] = static_cast<int>(status.sentry_control());
    return map;
}

void RobotPerformanceSyncRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析RobotPerformanceSelectionSync消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== RobotPerformanceSelectionSync 数据 ==========";
    QString shooterDesc;
    switch (m_status.shooter()) {
        case 1: shooterDesc = "冷却优先"; break;
        case 2: shooterDesc = "爆发优先"; break;
        case 3: shooterDesc = "英雄近战优先"; break;
        case 4: shooterDesc = "英雄远程优先"; break;
        default: shooterDesc = "未知配置"; break;
    }
    qDebug() << "发射机构性能体系：" << m_status.shooter() << "(" << shooterDesc << ")";
    
    QString chassisDesc;
    switch (m_status.chassis()) {
        case 1: chassisDesc = "血量优先"; break;
        case 2: chassisDesc = "功率优先"; break;
        case 3: chassisDesc = "英雄近战优先"; break;
        case 4: chassisDesc = "英雄远程优先"; break;
        default: chassisDesc = "未知配置"; break;
    }
    qDebug() << "底盘性能体系：" << m_status.chassis() << "(" << chassisDesc << ")";
    
    QString sentryDesc = m_status.sentry_control() == 0 ? "自动控制" : (m_status.sentry_control() == 1 ? "半自动控制" : "未知控制模式");
    qDebug() << "哨兵控制模式：" << m_status.sentry_control() << "(" << sentryDesc << ")";
    
    // 发射信号
    emit robotPerformanceSyncReceived(m_status);
    emit robotPerformanceSyncUpdated(toQmlMap(m_status));
}

// ===================== 19. DeployModeStatusRecvHandler =====================
DeployModeStatusRecvHandler::DeployModeStatusRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string DeployModeStatusRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap DeployModeStatusRecvHandler::toQmlMap(const robomaster::custom_client::DeployModeStatusSync& status) {
    QVariantMap map;
    map["current_status"] = static_cast<int>(status.current_status());
    return map;
}

void DeployModeStatusRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析DeployModeStatusSync消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== DeployModeStatusSync 数据 ==========";
    QString statusDesc = m_status.current_status() == 0 ? "未部署（正常状态）" : "已部署（狙击/防御状态）";
    qDebug() << "英雄部署模式状态：" << m_status.current_status() << "(" << statusDesc << ")";
    
    // 发射信号
    emit deployModeStatusReceived(m_status);
    emit deployModeStatusUpdated(toQmlMap(m_status));
}

// ===================== 20. RuneStatusRecvHandler =====================
RuneStatusRecvHandler::RuneStatusRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string RuneStatusRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap RuneStatusRecvHandler::toQmlMap(const robomaster::custom_client::RuneStatusSync& status) {
    QVariantMap map;
    map["rune_status"] = static_cast<int>(status.rune_status());
    map["activated_arms"] = static_cast<int>(status.activated_arms());
    map["average_rings"] = static_cast<int>(status.average_rings());
    return map;
}

void RuneStatusRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析RuneStatusSync消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== RuneStatusSync 数据 ==========";
    QString runeDesc;
    switch (m_status.rune_status()) {
        case 1: runeDesc = "未激活（初始状态）"; break;
        case 2: runeDesc = "正在激活（激活流程中）"; break;
        case 3: runeDesc = "已激活（增益生效）"; break;
        default: runeDesc = "未知状态"; break;
    }
    qDebug() << "能量机关状态：" << m_status.rune_status() << "(" << runeDesc << ")";
    qDebug() << "已激活灯臂数量：" << m_status.activated_arms() << "/6 平均环数：" << m_status.average_rings() << "（0~100）";
    
    // 发射信号
    emit runeStatusReceived(m_status);
    emit runeStatusUpdated(toQmlMap(m_status));
}

// ===================== 21. SentryStatusRecvHandler =====================
SentryStatusRecvHandler::SentryStatusRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string SentryStatusRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap SentryStatusRecvHandler::toQmlMap(const robomaster::custom_client::SentryStatusSync& status) {
    QVariantMap map;
    map["posture_id"] = static_cast<int>(status.posture_id());
    map["is_weakened"] = static_cast<bool>(status.is_weakened());
    return map;
}

void SentryStatusRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析SentryStatusSync消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== SentryStatusSync 数据 ==========";
    QString postureDesc;
    switch (m_status.posture_id()) {
        case 1: postureDesc = "进攻姿态（优先攻击敌方机器人）"; break;
        case 2: postureDesc = "防御姿态（优先守护己方基地/前哨站）"; break;
        case 3: postureDesc = "移动姿态（优先转移位置）"; break;
        default: postureDesc = "未知姿态"; break;
    }
    qDebug() << "哨兵当前姿态：" << m_status.posture_id() << "(" << postureDesc << ")";
    qDebug() << "哨兵是否弱化：" << (m_status.is_weakened() ? "是（属性下降）" : "否（正常状态）");
    
    // 发射信号
    emit sentryStatusReceived(m_status);
    emit sentryStatusUpdated(toQmlMap(m_status));
}

// ===================== 22. DartTargetStatusRecvHandler =====================
DartTargetStatusRecvHandler::DartTargetStatusRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string DartTargetStatusRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap DartTargetStatusRecvHandler::toQmlMap(const robomaster::custom_client::DartSelectTargetStatusSync& status) {
    QVariantMap map;
    map["target_id"] = static_cast<int>(status.target_id());
    map["open"] = static_cast<int>(status.open());
    return map;
}

void DartTargetStatusRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析DartSelectTargetStatusSync消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== DartSelectTargetStatusSync 数据 ==========";
    QString targetDesc;
    switch (m_status.target_id()) {
        case 1: targetDesc = "前哨站"; break;
        case 2: targetDesc = "基地固定目标"; break;
        case 3: targetDesc = "基地随机固定目标"; break;
        case 4: targetDesc = "基地随机移动目标"; break;
        case 5: targetDesc = "基地末端移动目标"; break;
        default: targetDesc = "未知目标"; break;
    }
    qDebug() << "选中的飞镖目标：" << m_status.target_id() << "(" << targetDesc << ")";
    
    QString gateDesc;
    switch (m_status.open()) {
        case 0: gateDesc = "已开启"; break;
        case 1: gateDesc = "关闭"; break;
        case 2: gateDesc = "正在开启/关闭中"; break;
        default: gateDesc = "未知状态"; break;
    }
    qDebug() << "飞镖闸门状态：" << m_status.open() << "(" << gateDesc << ")";
    
    // 发射信号
    emit dartTargetStatusReceived(m_status);
    emit dartTargetStatusUpdated(toQmlMap(m_status));
}

// ===================== 23. SentryCtrlResultRecvHandler =====================
SentryCtrlResultRecvHandler::SentryCtrlResultRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string SentryCtrlResultRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap SentryCtrlResultRecvHandler::toQmlMap(const robomaster::custom_client::SentryCtrlResult& result) {
    QVariantMap map;
    map["command_id"] = static_cast<int>(result.command_id());
    map["result_code"] = static_cast<int>(result.result_code());
    return map;
}

void SentryCtrlResultRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_result)) {
        qWarning() << "解析SentryCtrlResult消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== SentryCtrlResult 数据 ==========";
    QString cmdDesc;
    switch (m_result.command_id()) {
        case 0: cmdDesc = "无效指令"; break;
        case 1: cmdDesc = "补血点补弹"; break;
        case 2: cmdDesc = "补给站实体补弹"; break;
        case 3: cmdDesc = "远程补弹"; break;
        case 4: cmdDesc = "远程回血"; break;
        case 5: cmdDesc = "确认复活（免费）"; break;
        case 6: cmdDesc = "确认花费金币复活"; break;
        case 7: cmdDesc = "地图标点"; break;
        case 8: cmdDesc = "切换为进攻姿态"; break;
        case 9: cmdDesc = "切换为防御姿态"; break;
        case 10: cmdDesc = "切换为移动姿态"; break;
        default: cmdDesc = "未知指令"; break;
    }
    qDebug() << "哨兵控制指令ID：" << m_result.command_id() << "(" << cmdDesc << ")";
    qDebug() << "指令执行结果：" << (m_result.result_code() == 0 ? "成功" : "失败（错误码：" + QString::number(m_result.result_code()) + "）");
    
    // 发射信号
    emit sentryCtrlResultReceived(m_result);
    emit sentryCtrlResultUpdated(toQmlMap(m_result));
}

// ===================== 24. AirSupportStatusRecvHandler =====================
AirSupportStatusRecvHandler::AirSupportStatusRecvHandler(QObject *parent) : BaseMqttRecvHandler(parent) {}

std::string AirSupportStatusRecvHandler::getTopicName() const { 
    return TOPIC; 
}

QVariantMap AirSupportStatusRecvHandler::toQmlMap(const robomaster::custom_client::AirSupportStatusSync& status) {
    QVariantMap map;
    map["airsupport_status"] = static_cast<int>(status.airsupport_status());
    map["left_time"] = static_cast<int>(status.left_time());
    map["cost_coins"] = static_cast<int>(status.cost_coins());
    map["is_being_targeted"] = static_cast<int>(status.is_being_targeted());
    map["shooter_status"] = static_cast<int>(status.shooter_status());
    return map;
}

void AirSupportStatusRecvHandler::handleMessage(const std::string& topic, const std::string& payload) {
    Q_UNUSED(topic);
    if (!deserialize(payload, m_status)) {
        qWarning() << "解析AirSupportStatusSync消息失败！";
        return;
    }
    
    // 日志打印逻辑
    qDebug() << "========== AirSupportStatusSync 数据 ==========";
    QString supportDesc = m_status.airsupport_status() == 0 ? "未进行空中支援" : "正在空中支援";
    qDebug() << "空中支援状态：" << m_status.airsupport_status() << "(" << supportDesc << ")";
    qDebug() << "免费空中支援剩余时间：" << m_status.left_time() << "s 付费支援已花费金币：" << m_status.cost_coins() << "金币";
    qDebug() << "激光检测模块是否被照射：" << (m_status.is_being_targeted() == 1 ? "是" : "否");
    qDebug() << "空中机器人发射机构状态：" << (m_status.shooter_status() == 0 ? "被雷达反制锁定（无法发射）" : "正常未锁定");
    
    // 发射信号
    emit airSupportStatusReceived(m_status);
    emit airSupportStatusUpdated(toQmlMap(m_status));
}