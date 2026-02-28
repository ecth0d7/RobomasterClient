#ifndef IMQTTHANDLER_H
#define IMQTTHANDLER_H

#include <QObject>
#include <string>
#include <QByteArray>
#include <QVariantMap>

// ===================== 基础MQTT处理器接口 =====================
class IMqttHandler : public QObject
{
    Q_OBJECT
public:
    explicit IMqttHandler(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~IMqttHandler() = default;

    // 获取MQTT消息名（纯虚函数，子类必须实现）
    virtual std::string getTopicName() const = 0;
};

// ===================== 发送处理器接口 =====================
class IMqttSendHandler : public IMqttHandler
{
    Q_OBJECT
public:
    explicit IMqttSendHandler(QObject *parent = nullptr) : IMqttHandler(parent) {}
    ~IMqttSendHandler() override = default;

    // 序列化Protobuf消息为字节数组（供MQTT发送）
    virtual QByteArray serialize() = 0;
    
    // 触发消息发送（核心发送逻辑）
    virtual void send() = 0;

    // 从QVariantMap解析数据（供QML调用）
    virtual void parseFromQmlMap(const QVariantMap& dataMap) = 0;

signals:
    // 发送结果信号
    void sendSuccess(const std::string& topic);
    void sendFailed(const std::string& topic, const std::string& error);
};

// ===================== 接收处理器接口 =====================
class IMqttRecvHandler : public IMqttHandler
{
    Q_OBJECT
public:
    explicit IMqttRecvHandler(QObject *parent = nullptr) : IMqttHandler(parent) {}
    ~IMqttRecvHandler() override = default;

    // 处理接收到的MQTT消息
    virtual void handleMessage(const std::string& topic, const std::string& payload) = 0;

signals:
    // 通用接收完成信号（供上层统一监听）
    void messageReceived(const std::string& topic, const QVariantMap& dataMap);
};

#endif // IMQTTHANDLER_H