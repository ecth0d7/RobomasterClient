#ifndef MQTTCLIENT_H
#define MQTTCLIENT_H

#include <QObject>
#include <mosquitto.h>
#include <string>
#include <unordered_map>
#include <memory>
#include <vector>
#include "IMqttHandler.h"

// MQTT客户端（管理连接、订阅、分发消息到对应处理器）
class MqttClient : public QObject  // 类名改为 MqttClient
{
    Q_OBJECT
public:
    // 构造函数：clientId=客户端ID，host=MQTT服务器IP，port=端口
    explicit MqttClient(const std::string& clientId, 
                       const std::string& host = "127.0.0.1",
                       int port = 3333,
                       QObject *parent = nullptr);
    ~MqttClient() override;

    // 初始化MQTT客户端
    bool init();

    // 连接到MQTT服务器
    bool connectToServer();

    // 断开MQTT连接
    void disconnectFromServer();

    // 注册主题处理器（核心：仅为接收处理器订阅主题）
    void registerHandler(std::shared_ptr<IMqttHandler> handler);
    void registerHandlers(const std::vector<std::shared_ptr<IMqttHandler>>& handlers);

    // 切换MQTT服务器地址（后续切换局域网用）
    void setServerAddress(const std::string& host, int port = 3333) {
        m_host = host;
        m_port = port;
    }

    // MQTT发布消息接口（供发送处理器调用）
    bool publish(const std::string& topic, const QByteArray& payload) {
        if (!m_mosq || !m_isConnected) {
            return false;
        }
        // mosquitto_publish 参数：客户端实例、消息ID（nullptr自动分配）、主题、负载长度、负载数据、QoS、是否保留
        int rc = mosquitto_publish(m_mosq, nullptr, topic.c_str(), 
                                  payload.size(), payload.data(), 1, false);
        return rc == MOSQ_ERR_SUCCESS;
    }

signals:
    // 连接状态变化信号
    void connected();
    void disconnected();
    // 错误信号
    void errorOccurred(const std::string& errorMsg);

private:
    // MQTT回调函数（静态）
    static void onConnectCallback(struct mosquitto* mosq, void* obj, int rc);
    static void onDisconnectCallback(struct mosquitto* mosq, void* obj, int rc);
    static void onMessageCallback(struct mosquitto* mosq, void* obj, const struct mosquitto_message* msg);

    // 分发消息到对应接收处理器
    void dispatchMessage(const std::string& topic, const std::string& payload);

    // 辅助函数：判断处理器是否为接收处理器
    bool isRecvHandler(std::shared_ptr<IMqttHandler> handler);

private:
    struct mosquitto* m_mosq = nullptr;       // mosquitto客户端实例
    std::string m_clientId;                   // 客户端ID
    std::string m_host;                       // MQTT服务器IP
    int m_port;                               // MQTT端口
    bool m_isConnected = false;               // 连接状态
    // 存储所有处理器（包括发送/接收）
    std::unordered_map<std::string, std::shared_ptr<IMqttHandler>> m_handlers;
};

#endif // MQTTCLIENT_H