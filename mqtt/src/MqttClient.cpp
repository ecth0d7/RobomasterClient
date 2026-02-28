#include "MqttClient.h"  // 头文件对应改为 MqttClient.h
#include <QDebug>
#include <cstring>
#include <vector>
#include <typeinfo>
#include "IMqttHandler.h"

// 构造函数
MqttClient::MqttClient(const std::string& clientId, const std::string& host, int port, QObject *parent)
    : QObject(parent), m_clientId(clientId), m_host(host), m_port(port)
{
    // 初始化mosquitto库
    mosquitto_lib_init();
}

// 析构函数
MqttClient::~MqttClient()
{
    disconnectFromServer();
    if (m_mosq) {
        mosquitto_destroy(m_mosq);
        m_mosq = nullptr;
    }
    mosquitto_lib_cleanup();
}

// 初始化MQTT客户端
bool MqttClient::init()
{
    // 创建mosquitto客户端实例（开启持久化，传入当前对象作为上下文）
    m_mosq = mosquitto_new(m_clientId.c_str(), true, this);
    if (!m_mosq) {
        emit errorOccurred("创建MQTT客户端失败！");
        return false;
    }
    // 设置回调函数
    mosquitto_connect_callback_set(m_mosq, onConnectCallback);
    mosquitto_disconnect_callback_set(m_mosq, onDisconnectCallback);
    mosquitto_message_callback_set(m_mosq, onMessageCallback);
    return true;
}

// 连接到MQTT服务器
bool MqttClient::connectToServer()
{
    if (!m_mosq) {
        emit errorOccurred("MQTT客户端未初始化！");
        return false;
    }
    if (m_isConnected) {
        emit errorOccurred("已连接到MQTT服务器，无需重复连接！");
        return true;
    }
    // 连接服务器（QoS=1，保持连接=60秒）
    int rc = mosquitto_connect(m_mosq, m_host.c_str(), m_port, 60);
    if (rc != MOSQ_ERR_SUCCESS) {
        emit errorOccurred("连接MQTT服务器失败：" + std::string(mosquitto_strerror(rc)));
        return false;
    }
    // 启动消息循环（非阻塞）
    rc = mosquitto_loop_start(m_mosq);
    if (rc != MOSQ_ERR_SUCCESS) {
        emit errorOccurred("启动MQTT消息循环失败：" + std::string(mosquitto_strerror(rc)));
        mosquitto_disconnect(m_mosq);
        return false;
    }
    return true;
}

// 断开MQTT连接
void MqttClient::disconnectFromServer()
{
    if (m_mosq && m_isConnected) {
        mosquitto_loop_stop(m_mosq, true);
        mosquitto_disconnect(m_mosq);
        m_isConnected = false;
        emit disconnected();
    }
}

// 辅助函数：判断是否为接收处理器
bool MqttClient::isRecvHandler(std::shared_ptr<IMqttHandler> handler)
{
    // 动态转型判断是否为接收处理器类型
    return std::dynamic_pointer_cast<IMqttRecvHandler>(handler) != nullptr;
}

// 注册单个处理器（核心修正：仅接收处理器订阅主题）
void MqttClient::registerHandler(std::shared_ptr<IMqttHandler> handler)
{
    if (!handler) {
        emit errorOccurred("注册处理器失败：处理器为空！");
        return;
    }
    std::string topic = handler->getTopicName();
    if (topic.empty()) {
        emit errorOccurred("注册处理器失败：主题名为空！");
        return;
    }

    // 1. 先保存所有处理器（发送+接收）
    m_handlers[topic] = handler;

    // 2. 仅为接收处理器执行订阅逻辑
    if (isRecvHandler(handler)) {
        // 若已连接，立即订阅主题
        if (m_mosq && m_isConnected) {
            int rc = mosquitto_subscribe(m_mosq, nullptr, topic.c_str(), 1);
            if (rc != MOSQ_ERR_SUCCESS) {
                emit errorOccurred("订阅主题失败：" + topic + "，错误：" + mosquitto_strerror(rc));
                return;
            }
        }
        qDebug() << "成功注册接收处理器并订阅主题：" << QString::fromStdString(topic);
    } else {
        // 发送处理器仅注册，不订阅
        qDebug() << "成功注册发送处理器（无需订阅）：" << QString::fromStdString(topic);
    }
}

// 批量注册处理器
void MqttClient::registerHandlers(const std::vector<std::shared_ptr<IMqttHandler>>& handlers)
{
    for (const auto& handler : handlers) {
        registerHandler(handler);
    }
}

// 连接成功回调（修正：仅订阅接收处理器的主题）
void MqttClient::onConnectCallback(struct mosquitto* mosq, void* obj, int rc)
{
    MqttClient* client = static_cast<MqttClient*>(obj);  // 类型改为 MqttClient
    if (!client) return;
    if (rc == 0) {
        client->m_isConnected = true;
        emit client->connected();
        qDebug() << "成功连接到MQTT服务器：" << QString::fromStdString(client->m_host) << ":" << client->m_port;
        
        // 连接成功后，仅订阅接收处理器的主题
        for (const auto& pair : client->m_handlers) {
            const std::string& topic = pair.first;
            auto handler = pair.second;
            
            if (client->isRecvHandler(handler)) { // 仅接收处理器订阅
                int subRc = mosquitto_subscribe(mosq, nullptr, topic.c_str(), 1);
                if (subRc != MOSQ_ERR_SUCCESS) {
                    emit client->errorOccurred("订阅主题失败：" + topic + "，错误：" + mosquitto_strerror(subRc));
                } else {
                    qDebug() << "订阅接收处理器主题成功：" << QString::fromStdString(topic);
                }
            }
        }
    } else {
        emit client->errorOccurred("连接MQTT服务器失败，错误码：" + std::to_string(rc) + 
                                  "，描述：" + mosquitto_strerror(rc));
    }
}

// 断开连接回调
void MqttClient::onDisconnectCallback(struct mosquitto* mosq, void* obj, int rc)
{
    Q_UNUSED(mosq);
    MqttClient* client = static_cast<MqttClient*>(obj);  // 类型改为 MqttClient
    if (!client) return;
    client->m_isConnected = false;
    emit client->disconnected();
    if (rc != 0) {
        emit client->errorOccurred("MQTT连接断开，错误码：" + std::to_string(rc) + 
                                  "，描述：" + mosquitto_strerror(rc));
    } else {
        qDebug() << "MQTT连接正常断开";
    }
}

// 接收消息回调
void MqttClient::onMessageCallback(struct mosquitto* mosq, void* obj, const struct mosquitto_message* msg)
{
    Q_UNUSED(mosq);
    MqttClient* client = static_cast<MqttClient*>(obj);  // 类型改为 MqttClient
    if (!client || !msg) return;
    // 提取主题和负载（避免空指针）
    if (!msg->topic || !msg->payload) return;

    // 构造主题和负载字符串
    std::string topic = msg->topic;
    std::string payload(static_cast<char*>(msg->payload), msg->payloadlen);

    qDebug() << "收到MQTT消息 | 主题：" << QString::fromStdString(topic) 
             << " | 长度：" << msg->payloadlen << "字节";

    // 分发消息到对应接收处理器
    client->dispatchMessage(topic, payload);
}

// 分发消息到对应接收处理器
void MqttClient::dispatchMessage(const std::string& topic, const std::string& payload)
{
    // 查找对应主题的处理器
    auto it = m_handlers.find(topic);
    if (it == m_handlers.end()) {
        qWarning() << "未找到主题[" << QString::fromStdString(topic) << "]的处理器，消息丢弃";
        return;
    }

    // 仅分发给接收处理器（过滤发送处理器）
    auto recvHandler = std::dynamic_pointer_cast<IMqttRecvHandler>(it->second);
    if (recvHandler) {
        recvHandler->handleMessage(topic, payload);
    } else {
        qWarning() << "主题[" << QString::fromStdString(topic) << "]绑定的是发送处理器，无法处理接收消息，消息丢弃";
    }
}