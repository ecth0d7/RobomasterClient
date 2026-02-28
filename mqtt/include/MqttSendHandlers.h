#ifndef MQTTSENDHANDLERS_H
#define MQTTSENDHANDLERS_H

#include <QObject>
#include <string>
#include <QByteArray>
#include <QVariantMap>
#include "IMqttHandler.h"
#include "MqttClient.h"
#include "robomaster_custom_client.pb.h"

// ===================== 基础发送处理器（封装通用逻辑） =====================
class BaseMqttSendHandler : public IMqttSendHandler
{
    Q_OBJECT
public:
    explicit BaseMqttSendHandler(MqttClient* client, QObject *parent = nullptr);
    ~BaseMqttSendHandler() override = default;

    // 通用发送实现（子类无需重写）
    Q_INVOKABLE void send() override;

protected:
    MqttClient* m_mqttClient = nullptr; // MQTT客户端实例（依赖注入）
    
    // 通用Protobuf序列化工具
    template <typename T>
    QByteArray serializeProto(const T& msg) {
        std::string serialized;
        if (msg.SerializeToString(&serialized)) {
            return QByteArray(serialized.data(), static_cast<int>(serialized.size()));
        }
        return QByteArray();
    }

  
    bool validateCustomDataLength(const QByteArray& data, int maxLen);

private:
   
};

// ===================== 1. 键鼠遥控发送处理器 =====================
class KeyboardMouseSendHandler : public BaseMqttSendHandler
{
    Q_OBJECT
public:
    explicit KeyboardMouseSendHandler(MqttClient* client, QObject *parent = nullptr);
    std::string getTopicName() const override;
    QByteArray serialize() override;
    Q_INVOKABLE void parseFromQmlMap(const QVariantMap& dataMap) override;

    // 直接设置键鼠数据（C++/QML调用）
    Q_INVOKABLE void setMouseData(int32_t x, int32_t y, int32_t z,
                                 bool leftBtnDown, bool rightBtnDown, bool midBtnDown);
    Q_INVOKABLE void setKeyboardValue(uint32_t keyValue);

private:
    robomaster::custom_client::KeyboardMouseControl m_msg;
    static constexpr const char* TOPIC = "KeyboardMouseControl"; // 键鼠控制消息名
};

// ===================== 2. 自定义控制数据发送处理器 =====================
class CustomControlSendHandler : public BaseMqttSendHandler
{
    Q_OBJECT
public:
    explicit CustomControlSendHandler(MqttClient* client, QObject *parent = nullptr);
    std::string getTopicName() const override;
    QByteArray serialize() override;
    Q_INVOKABLE void parseFromQmlMap(const QVariantMap& dataMap) override;

    Q_INVOKABLE void setCustomData(const QByteArray& data);

private:
    robomaster::custom_client::CustomControl m_msg;
    static constexpr const char* TOPIC = "CustomControl"; // 自定义控制数据消息名
    static constexpr int MAX_DATA_LEN = 30; // 协议限制最大30字节
};

// ===================== 3. 云台手地图点击标记发送处理器 =====================
class MapClickInfoSendHandler : public BaseMqttSendHandler
{
    Q_OBJECT
public:
    explicit MapClickInfoSendHandler(MqttClient* client, QObject *parent = nullptr);
    std::string getTopicName() const override;
    QByteArray serialize() override;
    Q_INVOKABLE void parseFromQmlMap(const QVariantMap& dataMap) override;

    Q_INVOKABLE void setMapClickInfo(uint32_t isSendAll, const QByteArray& robotId,
                                    uint32_t mode, uint32_t enemyId, uint32_t ascii,
                                    uint32_t type, uint32_t screenX, uint32_t screenY,
                                    float mapX, float mapY);

private:
    robomaster::custom_client::MapClickInfoNotify m_msg;
    static constexpr const char* TOPIC = "MapClickInfoNotify"; // 地图点击标记消息名
    static constexpr int ROBOT_ID_LEN = 7; // 协议规定robot_id固定7字节
};

// ===================== 4. 工程装配指令发送处理器 =====================
class AssemblyCommandSendHandler : public BaseMqttSendHandler
{
    Q_OBJECT
public:
    explicit AssemblyCommandSendHandler(MqttClient* client, QObject *parent = nullptr);
    std::string getTopicName() const override;
    QByteArray serialize() override;
    Q_INVOKABLE void parseFromQmlMap(const QVariantMap& dataMap) override;

    Q_INVOKABLE void setAssemblyCommand(uint32_t operation, uint32_t difficulty);

private:
    robomaster::custom_client::AssemblyCommand m_msg;
    static constexpr const char* TOPIC = "AssemblyCommand"; // 工程装配指令消息名
};

// ===================== 5. 步兵/英雄性能体系选择指令发送处理器 =====================
class RobotPerformanceSendHandler : public BaseMqttSendHandler
{
    Q_OBJECT
public:
    explicit RobotPerformanceSendHandler(MqttClient* client, QObject *parent = nullptr);
    std::string getTopicName() const override;
    QByteArray serialize() override;
    Q_INVOKABLE void parseFromQmlMap(const QVariantMap& dataMap) override;

    Q_INVOKABLE void setPerformanceSelection(uint32_t shooter, uint32_t chassis, uint32_t sentryControl);

private:
    robomaster::custom_client::RobotPerformanceSelectionCommand m_msg;
    static constexpr const char* TOPIC = "RobotPerformanceSelectionCommand"; // 性能体系选择指令消息名
};

// ===================== 6. 机器人通用指令发送处理器 =====================
class CommonCommandSendHandler : public BaseMqttSendHandler
{
    Q_OBJECT
public:
    explicit CommonCommandSendHandler(MqttClient* client, QObject *parent = nullptr);
    std::string getTopicName() const override;
    QByteArray serialize() override;
    Q_INVOKABLE void parseFromQmlMap(const QVariantMap& dataMap) override;

    Q_INVOKABLE void setCommonCommand(uint32_t cmdType, uint32_t param);

private:
    robomaster::custom_client::CommonCommand m_msg;
    static constexpr const char* TOPIC = "CommonCommand"; // 机器人通用指令消息名
};

// ===================== 7. 英雄部署模式指令发送处理器 =====================
class HeroDeployModeSendHandler : public BaseMqttSendHandler
{
    Q_OBJECT
public:
    explicit HeroDeployModeSendHandler(MqttClient* client, QObject *parent = nullptr);
    std::string getTopicName() const override;
    QByteArray serialize() override;
    Q_INVOKABLE void parseFromQmlMap(const QVariantMap& dataMap) override;

    Q_INVOKABLE void setDeployMode(uint32_t mode);

private:
    robomaster::custom_client::HeroDeployModeEventCommand m_msg;
    static constexpr const char* TOPIC = "HeroDeployModeEventCommand"; // 英雄部署模式指令消息名
};

// ===================== 8. 能量机关激活指令发送处理器 =====================
class RuneActivateSendHandler : public BaseMqttSendHandler
{
    Q_OBJECT
public:
    explicit RuneActivateSendHandler(MqttClient* client, QObject *parent = nullptr);
    std::string getTopicName() const override;
    QByteArray serialize() override;
    Q_INVOKABLE void parseFromQmlMap(const QVariantMap& dataMap) override;

    Q_INVOKABLE void setRuneActivate(uint32_t activate);

private:
    robomaster::custom_client::RuneActivateCommand m_msg;
    static constexpr const char* TOPIC = "RuneActivateCommand"; // 能量机关激活指令消息名
};

// ===================== 9. 飞镖控制指令发送处理器 =====================
class DartCommandSendHandler : public BaseMqttSendHandler
{
    Q_OBJECT
public:
    explicit DartCommandSendHandler(MqttClient* client, QObject *parent = nullptr);
    std::string getTopicName() const override;
    QByteArray serialize() override;
    Q_INVOKABLE void parseFromQmlMap(const QVariantMap& dataMap) override;

    Q_INVOKABLE void setDartCommand(uint32_t targetId, bool open, bool launchConfirm);

private:
    robomaster::custom_client::DartCommand m_msg;
    static constexpr const char* TOPIC = "DartCommand"; // 飞镖控制指令消息名
};

// ===================== 10. 哨兵控制指令请求发送处理器 =====================
class SentryCtrlSendHandler : public BaseMqttSendHandler
{
    Q_OBJECT
public:
    explicit SentryCtrlSendHandler(MqttClient* client, QObject *parent = nullptr);
    std::string getTopicName() const override;
    QByteArray serialize() override;
    Q_INVOKABLE void parseFromQmlMap(const QVariantMap& dataMap) override;

    Q_INVOKABLE void setSentryCtrlCommand(uint32_t commandId);

private:
    robomaster::custom_client::SentryCtrlCommand m_msg;
    static constexpr const char* TOPIC = "SentryCtrlCommand"; // 哨兵控制指令消息名
};

// ===================== 11. 空中支援指令发送处理器 =====================
class AirSupportSendHandler : public BaseMqttSendHandler
{
    Q_OBJECT
public:
    explicit AirSupportSendHandler(MqttClient* client, QObject *parent = nullptr);
    std::string getTopicName() const override;
    QByteArray serialize() override;
    Q_INVOKABLE void parseFromQmlMap(const QVariantMap& dataMap) override;

    Q_INVOKABLE void setAirSupportCommand(uint32_t commandId);

private:
    robomaster::custom_client::AirSupportCommand m_msg;
    static constexpr const char* TOPIC = "AirSupportCommand"; // 空中支援指令消息名
};

#endif // MQTTSENDHANDLERS_H