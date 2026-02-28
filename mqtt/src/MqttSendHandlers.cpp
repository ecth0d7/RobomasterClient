#include "MqttSendHandlers.h"
#include <QDebug>
#include <QString>
#include <QByteArray>
#include <stdexcept>

// ===================== 基础发送处理器实现 =====================
BaseMqttSendHandler::BaseMqttSendHandler(MqttClient* client, QObject *parent)
    : IMqttSendHandler(parent), m_mqttClient(client)
{
    // 校验MQTT客户端实例是否有效
    if (!m_mqttClient) {
        qWarning() << "MQTT客户端实例为空！发送处理器初始化失败";
    }
}

bool BaseMqttSendHandler::validateCustomDataLength(const QByteArray& data, int maxLen) {
    if (data.size() > maxLen) {
        qWarning() << QString("自定义数据长度超限！最大允许%1字节，实际%2字节")
                      .arg(maxLen).arg(data.size());
        return false;
    }
    return true;
}

void BaseMqttSendHandler::send() {
    // 空指针校验
    if (!m_mqttClient) {
        emit sendFailed(getTopicName(), "MQTT客户端未初始化");
        return;
    }

    // 序列化Protobuf消息
    QByteArray payload = serialize();
    if (payload.isEmpty()) {
        emit sendFailed(getTopicName(), "Protobuf消息序列化失败");
        return;
    }

    // 发送MQTT消息
    bool sendResult = m_mqttClient->publish(getTopicName(), payload);
    if (sendResult) {
        qDebug() << QString("MQTT消息发送成功 | 主题：%1 | 数据长度：%2字节")
                    .arg(QString::fromStdString(getTopicName())).arg(payload.size());
        emit sendSuccess(getTopicName());
    } else {
        qWarning() << QString("MQTT消息发送失败 | 主题：%1").arg(QString::fromStdString(getTopicName()));
        emit sendFailed(getTopicName(), "MQTT客户端发布消息失败");
    }
}

// ===================== 1. 键鼠遥控发送处理器 =====================
KeyboardMouseSendHandler::KeyboardMouseSendHandler(MqttClient* client, QObject *parent)
    : BaseMqttSendHandler(client, parent)
{
    // 初始化Protobuf消息默认值
    m_msg.set_mouse_x(0);
    m_msg.set_mouse_y(0);
    m_msg.set_mouse_z(0);
    m_msg.set_left_button_down(false);
    m_msg.set_right_button_down(false);
    m_msg.set_mid_button_down(false);
    m_msg.set_keyboard_value(0);
}

std::string KeyboardMouseSendHandler::getTopicName() const {
    return TOPIC;
}

QByteArray KeyboardMouseSendHandler::serialize() {
    return serializeProto(m_msg);
}

void KeyboardMouseSendHandler::parseFromQmlMap(const QVariantMap& dataMap) {
    // 从QML传参解析键鼠数据
    if (dataMap.contains("mouseX")) {
        m_msg.set_mouse_x(dataMap["mouseX"].toInt());
    }
    if (dataMap.contains("mouseY")) {
        m_msg.set_mouse_y(dataMap["mouseY"].toInt());
    }
    if (dataMap.contains("mouseZ")) {
        m_msg.set_mouse_z(dataMap["mouseZ"].toInt());
    }
    if (dataMap.contains("leftBtnDown")) {
        m_msg.set_left_button_down(dataMap["leftBtnDown"].toBool());
    }
    if (dataMap.contains("rightBtnDown")) {
        m_msg.set_right_button_down(dataMap["rightBtnDown"].toBool());
    }
    if (dataMap.contains("midBtnDown")) {
        m_msg.set_mid_button_down(dataMap["midBtnDown"].toBool());
    }
    if (dataMap.contains("keyboardValue")) {
        m_msg.set_keyboard_value(static_cast<uint32_t>(dataMap["keyboardValue"].toUInt()));
    }

    qDebug() << "解析QML键鼠数据完成："
             << "X=" << m_msg.mouse_x()
             << "Y=" << m_msg.mouse_y()
             << "按键值=" << m_msg.keyboard_value()
             <<"滚轮值="<<m_msg.mouse_z()
             <<"右键按下="<<m_msg.right_button_down();
}

void KeyboardMouseSendHandler::setMouseData(int32_t x, int32_t y, int32_t z,
                                           bool leftBtnDown, bool rightBtnDown, bool midBtnDown) {
    m_msg.set_mouse_x(x);
    m_msg.set_mouse_y(y);
    m_msg.set_mouse_z(z);
    m_msg.set_left_button_down(leftBtnDown);
    m_msg.set_right_button_down(rightBtnDown);
    m_msg.set_mid_button_down(midBtnDown);
}

void KeyboardMouseSendHandler::setKeyboardValue(uint32_t keyValue) {
    // 仅保留低16位（协议规定bit0-bit15有效）
    m_msg.set_keyboard_value(keyValue & 0xFFFF);
}

// ===================== 2. 自定义控制数据发送处理器 =====================
CustomControlSendHandler::CustomControlSendHandler(MqttClient* client, QObject *parent)
    : BaseMqttSendHandler(client, parent)
{
    // 初始化空数据
    m_msg.clear_data();
}

std::string CustomControlSendHandler::getTopicName() const {
    return TOPIC;
}

QByteArray CustomControlSendHandler::serialize() {
    return serializeProto(m_msg);
}

void CustomControlSendHandler::parseFromQmlMap(const QVariantMap& dataMap) {
    if (dataMap.contains("customData")) {
        // QML传入的16进制字符串转二进制数据
        QByteArray hexData = dataMap["customData"].toString().toUtf8();
        QByteArray binaryData = QByteArray::fromHex(hexData);
        
        // 校验长度
        if (validateCustomDataLength(binaryData, MAX_DATA_LEN)) {
            m_msg.set_data(binaryData.data(), binaryData.size());
            qDebug() << "解析QML自定义控制数据完成：长度=" << m_msg.data().size() << "字节";
        } else {
            m_msg.clear_data();
        }
    }
}

void CustomControlSendHandler::setCustomData(const QByteArray& data) {
    if (validateCustomDataLength(data, MAX_DATA_LEN)) {
        m_msg.set_data(data.data(), data.size());
    } else {
        m_msg.clear_data();
    }
}

// ===================== 3. 云台手地图点击标记发送处理器 =====================
MapClickInfoSendHandler::MapClickInfoSendHandler(MqttClient* client, QObject *parent)
    : BaseMqttSendHandler(client, parent)
{
    // 初始化默认值
    m_msg.set_is_send_all(0);
    m_msg.set_mode(0);
    m_msg.set_enemy_id(0);
    m_msg.set_ascii(0);
    m_msg.set_type(0);
    m_msg.set_screen_x(0);
    m_msg.set_screen_y(0);
    m_msg.set_map_x(0.0f);
    m_msg.set_map_y(0.0f);
    
    // 初始化robot_id为7字节空数据
    std::string robotId(ROBOT_ID_LEN, '\0');
    m_msg.set_robot_id(robotId);
}

std::string MapClickInfoSendHandler::getTopicName() const {
    return TOPIC;
}

QByteArray MapClickInfoSendHandler::serialize() {
    return serializeProto(m_msg);
}

void MapClickInfoSendHandler::parseFromQmlMap(const QVariantMap& dataMap) {
    // 解析基础字段
    if (dataMap.contains("isSendAll")) {
        m_msg.set_is_send_all(static_cast<uint32_t>(dataMap["isSendAll"].toUInt()));
    }
    if (dataMap.contains("mode")) {
        m_msg.set_mode(static_cast<uint32_t>(dataMap["mode"].toUInt()));
    }
    if (dataMap.contains("enemyId")) {
        m_msg.set_enemy_id(static_cast<uint32_t>(dataMap["enemyId"].toUInt()));
    }
    if (dataMap.contains("ascii")) {
        m_msg.set_ascii(static_cast<uint32_t>(dataMap["ascii"].toUInt()));
    }
    if (dataMap.contains("type")) {
        m_msg.set_type(static_cast<uint32_t>(dataMap["type"].toUInt()));
    }
    if (dataMap.contains("screenX")) {
        m_msg.set_screen_x(static_cast<uint32_t>(dataMap["screenX"].toUInt()));
    }
    if (dataMap.contains("screenY")) {
        m_msg.set_screen_y(static_cast<uint32_t>(dataMap["screenY"].toUInt()));
    }
    if (dataMap.contains("mapX")) {
        m_msg.set_map_x(static_cast<float>(dataMap["mapX"].toDouble()));
    }
    if (dataMap.contains("mapY")) {
        m_msg.set_map_y(static_cast<float>(dataMap["mapY"].toDouble()));
    }
    
    // 解析robot_id（16进制字符串转7字节二进制）
    if (dataMap.contains("robotId")) {
        QByteArray hexRobotId = dataMap["robotId"].toString().toUtf8();
        QByteArray binaryRobotId = QByteArray::fromHex(hexRobotId);
        
        // 补零或截断至7字节
        if (binaryRobotId.size() > ROBOT_ID_LEN) {
            binaryRobotId = binaryRobotId.left(ROBOT_ID_LEN);
        } else if (binaryRobotId.size() < ROBOT_ID_LEN) {
            binaryRobotId.append(ROBOT_ID_LEN - binaryRobotId.size(), '\0');
        }
        
        m_msg.set_robot_id(binaryRobotId.data(), binaryRobotId.size());
    }

    qDebug() << "解析QML地图点击标记数据完成："
             << "模式=" << m_msg.mode()
             << "坐标(" << m_msg.map_x() << "," << m_msg.map_y() << ")";
}

void MapClickInfoSendHandler::setMapClickInfo(uint32_t isSendAll, const QByteArray& robotId,
                                             uint32_t mode, uint32_t enemyId, uint32_t ascii,
                                             uint32_t type, uint32_t screenX, uint32_t screenY,
                                             float mapX, float mapY) {
    m_msg.set_is_send_all(isSendAll);
    m_msg.set_mode(mode);
    m_msg.set_enemy_id(enemyId);
    m_msg.set_ascii(ascii);
    m_msg.set_type(type);
    m_msg.set_screen_x(screenX);
    m_msg.set_screen_y(screenY);
    m_msg.set_map_x(mapX);
    m_msg.set_map_y(mapY);
    
    // 处理robot_id（确保7字节）
    QByteArray fixedRobotId = robotId;
    if (fixedRobotId.size() > ROBOT_ID_LEN) {
        fixedRobotId = fixedRobotId.left(ROBOT_ID_LEN);
    } else if (fixedRobotId.size() < ROBOT_ID_LEN) {
        fixedRobotId.append(ROBOT_ID_LEN - fixedRobotId.size(), '\0');
    }
    m_msg.set_robot_id(fixedRobotId.data(), fixedRobotId.size());
}

// ===================== 4. 工程装配指令发送处理器 =====================
AssemblyCommandSendHandler::AssemblyCommandSendHandler(MqttClient* client, QObject *parent)
    : BaseMqttSendHandler(client, parent)
{
    // 初始化默认值
    m_msg.set_operation(0);
    m_msg.set_difficulty(1); // 默认简单难度
}

std::string AssemblyCommandSendHandler::getTopicName() const {
    return TOPIC;
}

QByteArray AssemblyCommandSendHandler::serialize() {
    return serializeProto(m_msg);
}

void AssemblyCommandSendHandler::parseFromQmlMap(const QVariantMap& dataMap) {
    if (dataMap.contains("operation")) {
        m_msg.set_operation(static_cast<uint32_t>(dataMap["operation"].toUInt()));
    }
    if (dataMap.contains("difficulty")) {
        uint32_t difficulty = static_cast<uint32_t>(dataMap["difficulty"].toUInt());
        // 校验难度范围（1-4）
        if (difficulty >= 1 && difficulty <= 4) {
            m_msg.set_difficulty(difficulty);
        } else {
            qWarning() << "装配难度值非法！仅支持1-4，输入值：" << difficulty;
            m_msg.set_difficulty(1); // 重置为默认值
        }
    }

    qDebug() << "解析QML工程装配指令完成："
             << "操作类型=" << m_msg.operation()
             << "难度=" << m_msg.difficulty();
}

void AssemblyCommandSendHandler::setAssemblyCommand(uint32_t operation, uint32_t difficulty) {
    m_msg.set_operation(operation);
    // 安全校验难度值
    if (difficulty >= 1 && difficulty <= 4) {
        m_msg.set_difficulty(difficulty);
    } else {
        qWarning() << "装配难度值非法，已重置为1！输入值：" << difficulty;
        m_msg.set_difficulty(1);
    }
}

// ===================== 5. 步兵/英雄性能体系选择指令发送处理器 =====================
RobotPerformanceSendHandler::RobotPerformanceSendHandler(MqttClient* client, QObject *parent)
    : BaseMqttSendHandler(client, parent)
{
    // 初始化默认值
    m_msg.set_shooter(1); // 冷却优先
    m_msg.set_chassis(1); // 血量优先
    m_msg.set_sentry_control(0); // 自动控制
}

std::string RobotPerformanceSendHandler::getTopicName() const {
    return TOPIC;
}

QByteArray RobotPerformanceSendHandler::serialize() {
    return serializeProto(m_msg);
}

void RobotPerformanceSendHandler::parseFromQmlMap(const QVariantMap& dataMap) {
    // 解析发射机构性能体系
    if (dataMap.contains("shooter")) {
        uint32_t shooter = static_cast<uint32_t>(dataMap["shooter"].toUInt());
        if (shooter >= 1 && shooter <= 4) {
            m_msg.set_shooter(shooter);
        } else {
            qWarning() << "发射机构性能体系值非法！仅支持1-4，输入值：" << shooter;
            m_msg.set_shooter(1);
        }
    }
    
    // 解析底盘性能体系
    if (dataMap.contains("chassis")) {
        uint32_t chassis = static_cast<uint32_t>(dataMap["chassis"].toUInt());
        if (chassis >= 1 && chassis <= 4) {
            m_msg.set_chassis(chassis);
        } else {
            qWarning() << "底盘性能体系值非法！仅支持1-4，输入值：" << chassis;
            m_msg.set_chassis(1);
        }
    }
    
    // 解析哨兵控制模式
    if (dataMap.contains("sentryControl")) {
        uint32_t sentryCtrl = static_cast<uint32_t>(dataMap["sentryControl"].toUInt());
        if (sentryCtrl == 0 || sentryCtrl == 1) {
            m_msg.set_sentry_control(sentryCtrl);
        } else {
            qWarning() << "哨兵控制模式值非法！仅支持0/1，输入值：" << sentryCtrl;
            m_msg.set_sentry_control(0);
        }
    }

    qDebug() << "解析QML性能体系指令完成："
             << "发射机构=" << m_msg.shooter()
             << "底盘=" << m_msg.chassis()
             << "哨兵控制=" << m_msg.sentry_control();
}

void RobotPerformanceSendHandler::setPerformanceSelection(uint32_t shooter, uint32_t chassis, uint32_t sentryControl) {
    // 安全校验并设置值
    if (shooter >= 1 && shooter <= 4) {
        m_msg.set_shooter(shooter);
    } else {
        qWarning() << "发射机构性能体系值非法，已重置为1！输入值：" << shooter;
        m_msg.set_shooter(1);
    }

    if (chassis >= 1 && chassis <= 4) {
        m_msg.set_chassis(chassis);
    } else {
        qWarning() << "底盘性能体系值非法，已重置为1！输入值：" << chassis;
        m_msg.set_chassis(1);
    }

    if (sentryControl == 0 || sentryControl == 1) {
        m_msg.set_sentry_control(sentryControl);
    } else {
        qWarning() << "哨兵控制模式值非法，已重置为0！输入值：" << sentryControl;
        m_msg.set_sentry_control(0);
    }
}

// ===================== 6. 机器人通用指令发送处理器 =====================
CommonCommandSendHandler::CommonCommandSendHandler(MqttClient* client, QObject *parent)
    : BaseMqttSendHandler(client, parent)
{
    // 初始化默认值
    m_msg.set_cmd_type(0);
    m_msg.set_param(0);
}

std::string CommonCommandSendHandler::getTopicName() const {
    return TOPIC;
}

QByteArray CommonCommandSendHandler::serialize() {
    return serializeProto(m_msg);
}

void CommonCommandSendHandler::parseFromQmlMap(const QVariantMap& dataMap) {
    if (dataMap.contains("cmdType")) {
        uint32_t cmdType = static_cast<uint32_t>(dataMap["cmdType"].toUInt());
        // 校验指令类型范围（1-6）
        if (cmdType >= 1 && cmdType <= 6) {
            m_msg.set_cmd_type(cmdType);
        } else {
            qWarning() << "通用指令类型值非法！仅支持1-6，输入值：" << cmdType;
            m_msg.set_cmd_type(0);
        }
    }
    if (dataMap.contains("param")) {
        m_msg.set_param(static_cast<uint32_t>(dataMap["param"].toUInt()));
    }

    qDebug() << "解析QML通用指令完成："
             << "指令类型=" << m_msg.cmd_type()
             << "参数=" << m_msg.param();
}

void CommonCommandSendHandler::setCommonCommand(uint32_t cmdType, uint32_t param) {
    // 安全校验指令类型
    if (cmdType >= 1 && cmdType <= 6) {
        m_msg.set_cmd_type(cmdType);
    } else {
        qWarning() << "通用指令类型值非法，已重置为0！输入值：" << cmdType;
        m_msg.set_cmd_type(0);
    }
    m_msg.set_param(param);
}

// ===================== 7. 英雄部署模式指令发送处理器 =====================
HeroDeployModeSendHandler::HeroDeployModeSendHandler(MqttClient* client, QObject *parent)
    : BaseMqttSendHandler(client, parent)
{
    // 初始化默认值
    m_msg.set_mode(0); // 退出部署模式
}

std::string HeroDeployModeSendHandler::getTopicName() const {
    return TOPIC;
}

QByteArray HeroDeployModeSendHandler::serialize() {
    return serializeProto(m_msg);
}

void HeroDeployModeSendHandler::parseFromQmlMap(const QVariantMap& dataMap) {
    if (dataMap.contains("mode")) {
        uint32_t mode = static_cast<uint32_t>(dataMap["mode"].toUInt());
        // 校验模式值（0/1）
        if (mode == 0 || mode == 1) {
            m_msg.set_mode(mode);
        } else {
            qWarning() << "英雄部署模式值非法！仅支持0/1，输入值：" << mode;
            m_msg.set_mode(0);
        }
    }

    qDebug() << "解析QML英雄部署模式指令完成："
             << "模式=" << (m_msg.mode() == 1 ? "进入部署" : "退出部署");
}

void HeroDeployModeSendHandler::setDeployMode(uint32_t mode) {
    if (mode == 0 || mode == 1) {
        m_msg.set_mode(mode);
    } else {
        qWarning() << "英雄部署模式值非法，已重置为0！输入值：" << mode;
        m_msg.set_mode(0);
    }
}

// ===================== 8. 能量机关激活指令发送处理器 =====================
RuneActivateSendHandler::RuneActivateSendHandler(MqttClient* client, QObject *parent)
    : BaseMqttSendHandler(client, parent)
{
    // 初始化默认值
    m_msg.set_activate(0); // 取消激活
}

std::string RuneActivateSendHandler::getTopicName() const {
    return TOPIC;
}

QByteArray RuneActivateSendHandler::serialize() {
    return serializeProto(m_msg);
}

void RuneActivateSendHandler::parseFromQmlMap(const QVariantMap& dataMap) {
    if (dataMap.contains("activate")) {
        uint32_t activate = static_cast<uint32_t>(dataMap["activate"].toUInt());
        // 校验激活值（0/1）
        if (activate == 0 || activate == 1) {
            m_msg.set_activate(activate);
        } else {
            qWarning() << "能量机关激活值非法！仅支持0/1，输入值：" << activate;
            m_msg.set_activate(0);
        }
    }

    qDebug() << "解析QML能量机关激活指令完成："
             << "激活状态=" << (m_msg.activate() == 1 ? "开启激活" : "取消激活");
}

void RuneActivateSendHandler::setRuneActivate(uint32_t activate) {
    if (activate == 0 || activate == 1) {
        m_msg.set_activate(activate);
    } else {
        qWarning() << "能量机关激活值非法，已重置为0！输入值：" << activate;
        m_msg.set_activate(0);
    }
}

// ===================== 9. 飞镖控制指令发送处理器 =====================
DartCommandSendHandler::DartCommandSendHandler(MqttClient* client, QObject *parent)
    : BaseMqttSendHandler(client, parent)
{
    // 初始化默认值
    m_msg.set_target_id(0);
    m_msg.set_open(false);
    m_msg.set_launch_confirm(false);
}

std::string DartCommandSendHandler::getTopicName() const {
    return TOPIC;
}

QByteArray DartCommandSendHandler::serialize() {
    return serializeProto(m_msg);
}

void DartCommandSendHandler::parseFromQmlMap(const QVariantMap& dataMap) {
    // 解析目标ID
    if (dataMap.contains("targetId")) {
        uint32_t targetId = static_cast<uint32_t>(dataMap["targetId"].toUInt());
        if (targetId >= 1 && targetId <= 5) {
            m_msg.set_target_id(targetId);
        } else {
            qWarning() << "飞镖目标ID非法！仅支持1-5，输入值：" << targetId;
            m_msg.set_target_id(0);
        }
    }
    
    // 解析闸门状态
    if (dataMap.contains("open")) {
        m_msg.set_open(dataMap["open"].toBool());
    }
    
    // 解析发射确认
    if (dataMap.contains("launchConfirm")) {
        m_msg.set_launch_confirm(dataMap["launchConfirm"].toBool());
    }

    qDebug() << "解析QML飞镖控制指令完成："
             << "目标ID=" << m_msg.target_id()
             << "闸门=" << (m_msg.open() ? "开启" : "关闭")
             << "发射确认=" << (m_msg.launch_confirm() ? "是" : "否");
}

void DartCommandSendHandler::setDartCommand(uint32_t targetId, bool open, bool launchConfirm) {
    // 校验目标ID
    if (targetId >= 1 && targetId <= 5) {
        m_msg.set_target_id(targetId);
    } else {
        qWarning() << "飞镖目标ID非法，已重置为0！输入值：" << targetId;
        m_msg.set_target_id(0);
    }
    
    m_msg.set_open(open);
    m_msg.set_launch_confirm(launchConfirm);
}

// ===================== 10. 哨兵控制指令请求发送处理器 =====================
SentryCtrlSendHandler::SentryCtrlSendHandler(MqttClient* client, QObject *parent)
    : BaseMqttSendHandler(client, parent)
{
    // 初始化默认值
    m_msg.set_command_id(0); // 无效指令
}

std::string SentryCtrlSendHandler::getTopicName() const {
    return TOPIC;
}

QByteArray SentryCtrlSendHandler::serialize() {
    return serializeProto(m_msg);
}

void SentryCtrlSendHandler::parseFromQmlMap(const QVariantMap& dataMap) {
    if (dataMap.contains("commandId")) {
        uint32_t cmdId = static_cast<uint32_t>(dataMap["commandId"].toUInt());
        // 校验指令ID范围（0-10）
        if (cmdId >= 0 && cmdId <= 10) {
            m_msg.set_command_id(cmdId);
        } else {
            qWarning() << "哨兵控制指令ID非法！仅支持0-10，输入值：" << cmdId;
            m_msg.set_command_id(0);
        }
    }

    qDebug() << "解析QML哨兵控制指令完成："
             << "指令ID=" << m_msg.command_id();
}

void SentryCtrlSendHandler::setSentryCtrlCommand(uint32_t commandId) {
    if (commandId >= 0 && commandId <= 10) {
        m_msg.set_command_id(commandId);
    } else {
        qWarning() << "哨兵控制指令ID非法，已重置为0！输入值：" << commandId;
        m_msg.set_command_id(0);
    }
}

// ===================== 11. 空中支援指令发送处理器 =====================
AirSupportSendHandler::AirSupportSendHandler(MqttClient* client, QObject *parent)
    : BaseMqttSendHandler(client, parent)
{
    // 初始化默认值
    m_msg.set_command_id(0); // 无效指令
}

std::string AirSupportSendHandler::getTopicName() const {
    return TOPIC;
}

QByteArray AirSupportSendHandler::serialize() {
    return serializeProto(m_msg);
}

void AirSupportSendHandler::parseFromQmlMap(const QVariantMap& dataMap) {
    if (dataMap.contains("commandId")) {
        uint32_t cmdId = static_cast<uint32_t>(dataMap["commandId"].toUInt());
        // 校验指令ID范围（1-3）
        if (cmdId >= 1 && cmdId <= 3) {
            m_msg.set_command_id(cmdId);
        } else {
            qWarning() << "空中支援指令ID非法！仅支持1-3，输入值：" << cmdId;
            m_msg.set_command_id(0);
        }
    }

    qDebug() << "解析QML空中支援指令完成："
             << "指令ID=" << m_msg.command_id();
}

void AirSupportSendHandler::setAirSupportCommand(uint32_t commandId) {
    if (commandId >= 1 && commandId <= 3) {
        m_msg.set_command_id(commandId);
    } else {
        qWarning() << "空中支援指令ID非法，已重置为0！输入值：" << commandId;
        m_msg.set_command_id(0);
    }
}