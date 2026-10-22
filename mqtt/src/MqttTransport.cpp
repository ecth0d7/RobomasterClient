#include "MqttTransport.h"
#include <QMetaObject>
#include <QMutexLocker>
#include <QPointer>
#include <QDateTime>
#include <QUuid>
#include <algorithm>
#include <cstring>

namespace {
// 库初始化覆盖所有传输实例；先停止回调，再清理全局库资源。
struct Library {
    Library() {
        mosquitto_lib_init();
    }
    ~Library() {
        mosquitto_lib_cleanup();
    }
};
}
MqttTransport::MqttTransport(QObject *parent) : MqttEndpoint(parent) {
    static Library library;
}
MqttTransport::~MqttTransport() {
    blockSignals(true);
    close();
}
bool MqttTransport::open(const QString &id, const QString &host, int port,
                         const QStringList &topics) {
    QPointer<MqttTransport> lifetime(this);
    const auto generation = m_generation.load() + 1;
    close();
    // 诊断通知的接收者可能同步销毁端点或重新连接。
    // 重入 open 建立的新会话优先，外层调用不能覆盖它。
    if (!lifetime || generation != m_generation)
        return false;
    m_topics = topics;
    QString session;
    {
        QMutexLocker lock(&m_inboxMutex);
        m_observationSession = QUuid::createUuid().toString(QUuid::WithoutBraces);
        session = m_observationSession;
    }
    m_callbackContext =
        std::make_unique<CallbackContext>(CallbackContext{this, m_generation.load(), session});
    m_client = mosquitto_new(id.toUtf8().constData(), true, m_callbackContext.get());
    if (!m_client) {
        close();
        if (lifetime && generation + 1 == m_generation)
            emit errorOccurred("Cannot create MQTT client");
        return false;
    }
    mosquitto_connect_callback_set(m_client, onConnect);
    mosquitto_disconnect_callback_set(m_client, onDisconnect);
    mosquitto_message_callback_set(m_client, onMessage);
    mosquitto_reconnect_delay_set(m_client, 1, 5, true);
    int result = mosquitto_connect_async(m_client, host.toUtf8().constData(), port, 30);
    if (result == MOSQ_ERR_SUCCESS) {
        result = mosquitto_loop_start(m_client);
        m_loopStarted = result == MOSQ_ERR_SUCCESS;
    }
    if (result != MOSQ_ERR_SUCCESS) {
        const auto error = QString::fromUtf8(mosquitto_strerror(result));
        close();
        if (lifetime && generation + 1 == m_generation)
            emit errorOccurred(error);
        return false;
    }
    return true;
}
void MqttTransport::close() {
    ++m_generation;
    m_connected = false;
    if (m_client) {
        mosquitto_disconnect(m_client);
        if (m_loopStarted)
            mosquitto_loop_stop(m_client, true);
        mosquitto_destroy(m_client);
    }
    m_client = nullptr;
    m_callbackContext.reset();
    m_loopStarted = false;
    m_connected = false;
    {
        QMutexLocker lock(&m_inboxMutex);
        m_inbox.clear();
        m_inboxBytes = 0;
        m_drainScheduled = false;
        m_observationSession.clear();
        m_packetSequence = m_lastIngressUtc = 0;
        m_lastDispatchQueueAge = m_maximumDispatchQueueAge = 0;
        m_received = m_dropped = m_delivered = 0;
        m_publishSubmitted = m_publishRejected = m_publishBytes = 0;
        m_lastPublishTopic.clear();
        m_lastPublishError.clear();
        m_lastPublishAt.clear();
    }
    emit diagnosticsChanged();
}
bool MqttTransport::publish(const QString &topic, const QByteArray &payload) {
    // 控制消息使用 QoS 0 且不保留，重连后不能重放旧动作。
    const int result = !m_client || !m_connected ? MOSQ_ERR_NO_CONN
        : mosquitto_publish(m_client, nullptr, topic.toUtf8().constData(), payload.size(),
                             payload.constData(), 0, false);
    const bool submitted = result == MOSQ_ERR_SUCCESS;
    {
        QMutexLocker lock(&m_inboxMutex);
        if (submitted) {
            ++m_publishSubmitted;
            m_publishBytes += quint64(payload.size());
        } else ++m_publishRejected;
        m_lastPublishTopic = topic.left(128);
        m_lastPublishError = submitted ? QString{} : QString::fromUtf8(mosquitto_strerror(result));
        m_lastPublishAt = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    }
    // ClientBackend coalesces this notification to 4 Hz, including 75 Hz input.
    // Do not emit connection errors per input packet or log sensitive payloads.
    emit diagnosticsChanged();
    return submitted;
}
void MqttTransport::onConnect(mosquitto *client, void *context, int result) {
    const auto *callback = static_cast<CallbackContext *>(context);
    auto *self = callback->owner;
    const auto generation = callback->generation;
    if (generation != self->m_generation)
        return;
    if (result) {
        QMetaObject::invokeMethod(
            self,
            [self, generation, result] {
                if (generation == self->m_generation)
                    emit self->errorOccurred(QString("MQTT connection refused (%1)").arg(result));
            },
            Qt::QueuedConnection);
        return;
    }
    self->m_connected = true;
    for (const auto &topic : self->m_topics) {
        const int rc = mosquitto_subscribe(client, nullptr, topic.toUtf8().constData(), 0);
        if (rc != MOSQ_ERR_SUCCESS)
            QMetaObject::invokeMethod(
                self,
                [self, generation, rc] {
                    if (generation == self->m_generation)
                        emit self->errorOccurred(QString::fromUtf8(mosquitto_strerror(rc)));
                },
                Qt::QueuedConnection);
    }
    QMetaObject::invokeMethod(
        self,
        [self, generation] {
            if (generation == self->m_generation)
                emit self->connected();
        },
        Qt::QueuedConnection);
}
void MqttTransport::onDisconnect(mosquitto *, void *context, int result) {
    const auto *callback = static_cast<CallbackContext *>(context);
    auto *self = callback->owner;
    const auto generation = callback->generation;
    if (generation != self->m_generation)
        return;
    self->m_connected = false;
    QMetaObject::invokeMethod(
        self,
        [self, generation, result] {
            if (generation != self->m_generation)
                return;
            QPointer<MqttTransport> lifetime(self);
            emit self->disconnected();
            if (!lifetime || generation != self->m_generation)
                return;
            if (result)
                emit self->errorOccurred(
                    QString("MQTT disconnected (%1), reconnecting").arg(result));
        },
        Qt::QueuedConnection);
}
void MqttTransport::onMessage(mosquitto *, void *context, const mosquitto_message *message) {
    const auto *callback = static_cast<CallbackContext *>(context);
    auto *self = callback->owner;
    const auto generation = callback->generation;
    if (generation != self->m_generation)
        return;
    if (!message || !message->topic || message->payloadlen < 0 || message->payloadlen > 64 * 1024
        || (message->payloadlen > 0 && !message->payload))
        return;
    // 复制进界面收件队列前，先限制回调所持 topic 的长度。
    if (strnlen(message->topic, 257) > 256)
        return;
    PacketObservation::Stamp observation;
    {
        QMutexLocker lock(&self->m_inboxMutex);
        if (generation != self->m_generation || callback->session != self->m_observationSession
            || self->m_packetSequence >= PacketObservation::SafeInteger)
            return;
        // Receive time belongs to this callback, before copying bytes or waiting for
        // the GUI queue. A dropped packet may leave a sequence gap, never a new age.
        observation = PacketObservation::capture("mqtt_callback", callback->session,
                                                  ++self->m_packetSequence);
        self->m_lastIngressUtc = observation.receivedUtc;
    }
    const auto topic = QString::fromUtf8(message->topic);
    const auto payload =
        QByteArray(static_cast<const char *>(message->payload), message->payloadlen);
    self->enqueue(generation, topic, payload, std::move(observation));
}
QString MqttTransport::packetObservationSession() const {
    QMutexLocker lock(&m_inboxMutex);
    return m_observationSession;
}
QVariantMap MqttTransport::diagnostics() const {
    QMutexLocker lock(&m_inboxMutex);
    const auto pendingAge = m_inbox.isEmpty() ? 0
        : std::max<qint64>(0, PacketObservation::steadyMilliseconds()
                              - m_inbox.head().observation.receivedTick);
    return {{"received", m_received},
            {"delivered", m_delivered},
            {"dropped", m_dropped},
            {"pending_messages", m_inbox.size()},
            {"pending_bytes", m_inboxBytes},
            {"maximum_messages", MaximumInboxMessages},
            {"maximum_bytes", MaximumInboxBytes},
            {"ingress_timing_available", true},
            {"ingress_timing_basis", "mqtt_callback"},
            {"ingress_session_active", !m_observationSession.isEmpty()},
            {"last_ingress_at_ms", m_lastIngressUtc},
            {"oldest_pending_queue_age_ms", pendingAge},
            {"last_dispatch_queue_age_ms", m_lastDispatchQueueAge},
            {"maximum_dispatch_queue_age_ms", m_maximumDispatchQueueAge},
            {"publish_submitted", m_publishSubmitted},
            {"publish_rejected", m_publishRejected},
            {"publish_bytes", m_publishBytes},
            {"last_publish_topic", m_lastPublishTopic},
            {"last_publish_error", m_lastPublishError},
            {"last_publish_at", m_lastPublishAt},
            {"publish_qos", 0}, {"publish_retained", false},
            {"execution_ack_available", false}};
}
void MqttTransport::enqueue(quint64 generation, QString topic, QByteArray payload,
                            PacketObservation::Stamp observation) {
    bool schedule = false;
    {
        QMutexLocker lock(&m_inboxMutex);
        if (generation != m_generation || observation.session != m_observationSession)
            return;
        ++m_received;
        const auto cost = payload.size() + topic.size() * qsizetype(sizeof(QChar));
        // 正常负载保持消息顺序；超限时丢弃队列中最旧的消息。
        // 此层不合并具体协议的状态或事件。
        while (!m_inbox.isEmpty() && (m_inbox.size() >= MaximumInboxMessages ||
                                      m_inboxBytes + cost > MaximumInboxBytes)) {
            m_inboxBytes -= m_inbox.dequeue().cost;
            ++m_dropped;
        }
        m_inbox.enqueue({std::move(topic), std::move(payload), cost, std::move(observation)});
        m_inboxBytes += cost;
        if (!m_drainScheduled) {
            m_drainScheduled = true;
            schedule = true;
        }
    }
    if (schedule)
        QMetaObject::invokeMethod(
            this, [this, generation] { drain(generation); }, Qt::QueuedConnection);
}
void MqttTransport::drain(quint64 generation) {
    QPointer<MqttTransport> lifetime(this);
    for (int i = 0; i < 32; ++i) {
        Incoming incoming;
        {
            QMutexLocker lock(&m_inboxMutex);
            if (generation != m_generation)
                return;
            if (m_inbox.isEmpty())
                break;
            incoming = m_inbox.dequeue();
            m_inboxBytes -= incoming.cost;
            ++m_delivered;
            m_lastDispatchQueueAge = std::max<qint64>(
                0, PacketObservation::steadyMilliseconds() - incoming.observation.receivedTick);
            m_maximumDispatchQueueAge = std::max(m_maximumDispatchQueueAge, m_lastDispatchQueueAge);
        }
        emit packetObserved(incoming.topic, incoming.payload,
                            PacketObservation::toMap(incoming.observation));
        if (!lifetime || generation != m_generation)
            return;
        // Timed consumers and legacy consumers see the same packet. If a timed
        // receiver retires this session, its old bytes must not reach legacy slots.
        emit packetReceived(incoming.topic, incoming.payload);
        if (!lifetime)
            return;
        // 接收者可能在通知回调中同步关闭或替换当前会话。
        if (generation != m_generation)
            return;
    }
    bool pending;
    {
        QMutexLocker lock(&m_inboxMutex);
        if (generation != m_generation)
            return;
        pending = !m_inbox.isEmpty();
        if (!pending)
            m_drainScheduled = false;
    }
    emit diagnosticsChanged();
    if (!lifetime || generation != m_generation)
        return;
    if (pending)
        QMetaObject::invokeMethod(
            this, [this, generation] { drain(generation); }, Qt::QueuedConnection);
}
