#include "MqttClient.h"
#include <QDebug>
#include <cstring>
#include <vector>

/**
 * @brief 构造函数
 * 修正初始化列表顺序以匹配头文件声明顺序 (m_mosq -> m_clientId -> m_host -> m_port)
 */
MqttClient::MqttClient(const std::string& clientId, const std::string& host, int port, QObject *parent)
    : QObject(parent)
    , m_mosq(nullptr)          // 1. 指针
    , m_clientId(clientId)     // 2. ID
    , m_host(host)             // 3. Host
    , m_port(port)             // 4. Port
    , m_isConnected(false)
{
    mosquitto_lib_init();
}

MqttClient::~MqttClient()
{
    disconnectFromServer();
    if (m_mosq) {
        mosquitto_destroy(m_mosq);
        m_mosq = nullptr;
    }
    mosquitto_lib_cleanup();
}

/**
 * @brief 设置 Client ID (供 QML 调用)
 */
void MqttClient::setClientId(const QString &id)
{
    std::string newId = id.toStdString();
    if (m_clientId != newId) {
        qInfo() << "MQTT ClientId 更改为:" << id;
        m_clientId = newId;

        // 更改 ID 必须销毁并重建 mosquitto 实例
        if (m_mosq) {
            qInfo() << "正在重置 MQTT 实例以应用新 ID...";
            disconnectFromServer();
            mosquitto_destroy(m_mosq);
            m_mosq = nullptr; 
        }
    }
}

/**
 * @brief 初始化 mosquitto 实例
 */
bool MqttClient::init()
{
    if (m_mosq) {
        mosquitto_destroy(m_mosq);
        m_mosq = nullptr;
    }

    m_mosq = mosquitto_new(m_clientId.c_str(), true, this);
    
    if (!m_mosq) {
        emit errorOccurred("创建 MQTT 客户端失败！");
        return false;
    }

    mosquitto_connect_callback_set(m_mosq, onConnectCallback);
    mosquitto_disconnect_callback_set(m_mosq, onDisconnectCallback);
    mosquitto_message_callback_set(m_mosq, onMessageCallback);

    qInfo() << "MQTT 客户端实例初始化成功，ID:" << QString::fromStdString(m_clientId);
    return true;
}

/**
 * @brief 连接至服务器 (供 QML 调用)
 */
bool MqttClient::connectToServer()
{
    if (!m_mosq) {
        if (!init()) return false;
    }

    qInfo() << "正在连接 MQTT 服务器:" << QString::fromStdString(m_host) << ":" << m_port;

    int rc = mosquitto_connect(m_mosq, m_host.c_str(), m_port, 60);
    if (rc != MOSQ_ERR_SUCCESS) {
        std::string errorMsg = "连接发起失败: " + std::string(mosquitto_strerror(rc));
        emit errorOccurred(errorMsg);
        return false;
    }

    mosquitto_loop_start(m_mosq);
    return true;
}

void MqttClient::disconnectFromServer()
{
    if (m_mosq) {
        mosquitto_disconnect(m_mosq);
        mosquitto_loop_stop(m_mosq, true);
        m_isConnected = false;
        qInfo() << "MQTT 连接已断开";
    }
}

/**
 * @brief 注册处理器
 * 修正点：使用 getTopicName() 匹配接口
 */
void MqttClient::registerHandler(std::shared_ptr<IMqttHandler> handler)
{
    if (!handler) return;
    
    // 调用接口中的 getTopicName()
    std::string topic = handler->getTopicName();
    
    if (!topic.empty()) {
        m_handlers[topic] = handler;
        if (m_isConnected && m_mosq) {
            mosquitto_subscribe(m_mosq, nullptr, topic.c_str(), 1);
        }
    }
}

void MqttClient::registerHandlers(const std::vector<std::shared_ptr<IMqttHandler>>& handlers)
{
    for (const auto& h : handlers) {
        registerHandler(h);
    }
}

// ===================== 内部回调处理 =====================

void MqttClient::onConnectCallback(struct mosquitto* mosq, void* obj, int rc)
{
    MqttClient* client = static_cast<MqttClient*>(obj);
    if (rc == 0) {
        client->m_isConnected = true;
        qInfo() << "MQTT 连接成功，开始自动订阅已注册的主题...";
        
        for (auto const& [topic, handler] : client->m_handlers) {
            if (!topic.empty()) {
                mosquitto_subscribe(mosq, nullptr, topic.c_str(), 1);
            }
        }
        emit client->connected();
    } else {
        std::string errorMsg = "MQTT 连接失败，错误码: " + std::to_string(rc);
        emit client->errorOccurred(errorMsg);
    }
}

void MqttClient::onDisconnectCallback(struct mosquitto* mosq, void* obj, int rc)
{
    Q_UNUSED(mosq);
    MqttClient* client = static_cast<MqttClient*>(obj);
    if (client) {
        client->m_isConnected = false;
        emit client->disconnected();
    }
}

void MqttClient::onMessageCallback(struct mosquitto* mosq, void* obj, const struct mosquitto_message* msg)
{
    Q_UNUSED(mosq);
    MqttClient* client = static_cast<MqttClient*>(obj);
    if (!client || !msg || !msg->topic || !msg->payload) return;

    std::string topic = msg->topic;
    std::string payload(static_cast<char*>(msg->payload), msg->payloadlen);

    client->dispatchMessage(topic, payload);
}

/**
 * @brief 消息分发
 * 修正点：将 handle() 改为 handleMessage()，并强制转换类型以调用接收接口
 */
void MqttClient::dispatchMessage(const std::string& topic, const std::string& payload)
{
    auto it = m_handlers.find(topic);
    if (it != m_handlers.end()) {
        // 因为 m_handlers 存的是 IMqttHandler，而 handleMessage 在 IMqttRecvHandler 中
        // 我们需要尝试将基类指针转换为接收处理器子类指针
        auto recvHandler = std::dynamic_pointer_cast<IMqttRecvHandler>(it->second);
        if (recvHandler) {
            recvHandler->handleMessage(topic, payload);
        }
    }
}