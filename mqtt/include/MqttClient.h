#ifndef MQTTCLIENT_H
#define MQTTCLIENT_H

#include <QObject>
#include <mosquitto.h>
#include <string>
#include <unordered_map>
#include <memory>
#include <vector>
#include <QString>
#include "IMqttHandler.h"

// MQTT客户端（管理连接、订阅、分发消息到对应处理器）
class MqttClient : public QObject
{
    Q_OBJECT
public:
    // 构造函数
    explicit MqttClient(const std::string& clientId = "robomaster_default", 
                       const std::string& host = "127.0.0.1",
                       int port = 3333,
                       QObject *parent = nullptr);
    ~MqttClient() override;

    // ============================================================
    // 核心修改：使用 public slots 或 Q_INVOKABLE 使得 QML 可以调用
    // ============================================================
public slots:
    // 供登录界面调用：设置新的 Client ID
    void setClientId(const QString &id);

    // 供登录界面调用：初始化并连接服务器
    bool connectToServer();

    // 供登录界面调用：断开连接
    void disconnectFromServer();

    // 切换服务器地址
    void setServerAddress(const QString& host, int port = 3333) {
        m_host = host.toStdString();
        m_port = port;
    }

public:
    // 初始化MQTT客户端内部实例
    bool init();

    // 注册处理器
    void registerHandler(std::shared_ptr<IMqttHandler> handler);
    void registerHandlers(const std::vector<std::shared_ptr<IMqttHandler>>& handlers);

    // MQTT发布消息接口（供发送处理器调用）
    bool publish(const std::string& topic, const QByteArray& payload) {
        if (!m_mosq || !m_isConnected) {
            return false;
        }
        int rc = mosquitto_publish(m_mosq, nullptr, topic.c_str(), 
                                  payload.size(), payload.data(), 1, false);
        return rc == MOSQ_ERR_SUCCESS;
    }

signals:
    // 连接状态变化信号（QML 可以通过 onConnected 监听）
    void connected();
    void disconnected();
    // 错误信号（QML 可以通过 onErrorOccurred 监听）
    void errorOccurred(const std::string& errorMsg);

private:
    // MQTT回调函数（静态）
    static void onConnectCallback(struct mosquitto* mosq, void* obj, int rc);
    static void onDisconnectCallback(struct mosquitto* mosq, void* obj, int rc);
    static void onMessageCallback(struct mosquitto* mosq, void* obj, const struct mosquitto_message* msg);

    // 分分发消息到对应接收处理器
    void dispatchMessage(const std::string& topic, const std::string& payload);

private:
    struct mosquitto* m_mosq = nullptr;       
    std::string m_clientId;                   
    std::string m_host;                       
    int m_port;                               
    bool m_isConnected = false;               
    
    // 存储所有处理器
    std::unordered_map<std::string, std::shared_ptr<IMqttHandler>> m_handlers;
};

#endif // MQTTCLIENT_H