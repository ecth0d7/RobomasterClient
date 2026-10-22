#include "TerminalLinks.h"

#include "MqttTransport.h"
#include "PacketObservation.h"

#include <QDateTime>
#include <QHostAddress>
#include <QMetaObject>
#include <QNetworkDatagram>
#include <QPointer>
#include <QQueue>
#include <QSet>
#include <QStringList>
#include <QTimer>
#include <QUdpSocket>
#include <QUuid>
#include <algorithm>
#include <cmath>

namespace TerminalLinks {
namespace {
constexpr qsizetype MaximumPayload = 64 * 1024;
constexpr qsizetype MaximumUdpPayload = 65507;
constexpr qsizetype MaximumInboxBytes = 1024 * 1024;
constexpr int MaximumInboxMessages = 64;
constexpr int DrainQuota = 16;

bool fail(QString *error, const QString &reason) {
    if (error) *error = reason;
    return false;
}
bool integer(const QVariant &value, qint64 low, qint64 high, qint64 *result = nullptr) {
    switch (value.metaType().id()) {
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double: break;
    default: return false;
    }
    const double n = value.toDouble();
    if (!std::isfinite(n) || std::floor(n) != n || n < low || n > high) return false;
    if (result) *result = qint64(n);
    return true;
}
bool identifier(const QVariant &value, int maximum = 128) {
    if (value.metaType().id() != QMetaType::QString) return false;
    const auto text = value.toString();
    if (text.isEmpty() || text.size() > maximum) return false;
    for (const auto c : text) {
        const auto u = c.unicode();
        if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') ||
              (u >= '0' && u <= '9') || u == '-' || u == '_' || u == '.' || u == ':')) return false;
    }
    return true;
}
bool exactKeys(const QVariantMap &map, const QSet<QString> &keys) {
    if (map.size() != keys.size()) return false;
    for (auto it = map.cbegin(); it != map.cend(); ++it)
        if (!keys.contains(it.key())) return false;
    return true;
}
bool literalTopic(const QString &topic) {
    const auto bytes = topic.toUtf8();
    if (topic.isEmpty() || bytes.size() > 256 || QString::fromUtf8(bytes) != topic) return false;
    for (const auto c : topic)
        if (c.isNull() || c.unicode() < 32 || c.unicode() == 127 || c == '#' || c == '+') return false;
    return true;
}
bool topics(const QVariant &value, QStringList *result) {
    QVariantList list;
    if (value.metaType().id() == QMetaType::QStringList) {
        for (const auto &entry : value.toStringList()) list.append(entry);
    } else if (value.metaType().id() == QMetaType::QVariantList) list = value.toList();
    else return false;
    if (list.size() > 32) return false;
    QSet<QString> seen;
    for (const auto &entry : list) {
        if (entry.metaType().id() != QMetaType::QString || !literalTopic(entry.toString())
            || seen.contains(entry.toString())) return false;
        seen.insert(entry.toString());
        result->append(entry.toString());
    }
    return true;
}
bool hostName(const QVariant &value) {
    if (value.metaType().id() != QMetaType::QString) return false;
    const auto host = value.toString();
    if (host.isEmpty() || host.size() > 253 || host != host.trimmed()) return false;
    const QHostAddress address(host);
    if (!address.isNull())
        return address != QHostAddress::Any && address != QHostAddress::AnyIPv4 &&
               address != QHostAddress::AnyIPv6 && address != QHostAddress::Broadcast && !address.isMulticast();
    for (const auto &label : host.split('.')) {
        if (label.isEmpty() || label.size() > 63 || label.front() == '-' || label.back() == '-') return false;
        for (const auto c : label) {
            const auto u = c.unicode();
            if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') ||
                  (u >= '0' && u <= '9') || u == '-')) return false;
        }
    }
    return true;
}
QString kindName(Kind kind) {
    switch (kind) {
    case Kind::Loopback: return QStringLiteral("loopback");
    case Kind::Mqtt: return QStringLiteral("mqtt");
    case Kind::Udp: return QStringLiteral("udp");
    }
    return {};
}
QString peerName(const QHostAddress &address, quint16 port) {
    return address.protocol() == QAbstractSocket::IPv6Protocol
        ? QStringLiteral("[%1]:%2").arg(address.toString()).arg(port)
        : QStringLiteral("%1:%2").arg(address.toString()).arg(port);
}

struct Configuration {
    QVariantMap context;
    QString host, clientId;
    QStringList receiveTopics, sendTopics;
    QHostAddress bindAddress, peerAddress;
    quint16 port = 0, bindPort = 0, peerPort = 0;
};
bool configuration(Kind kind, const QVariantMap &map, Configuration *result, QString *error) {
    QSet<QString> keys{"schema", "context"};
    if (kind == Kind::Mqtt)
        keys.unite({"host", "port", "client_id", "receive_topics", "send_topics"});
    else if (kind == Kind::Udp)
        keys.unite({"bind_address", "bind_port", "peer_address", "peer_port"});
    if (!exactKeys(map, keys) || !integer(map.value("schema"), 1, 1)
        || map.value("context").metaType().id() != QMetaType::QVariantMap)
        return fail(error, "Invalid terminal-link configuration shape or schema");
    Configuration config;
    config.context = map.value("context").toMap();
    if (!exactKeys(config.context, {"profile_id", "field_profile_id", "capability_revision"}))
        return fail(error, "Terminal link needs an explicit versioned context");
    for (auto it = config.context.cbegin(); it != config.context.cend(); ++it)
        if (!identifier(it.value())) return fail(error, "Invalid terminal-link context identifier");
    if (kind == Kind::Mqtt) {
        qint64 port = 0;
        if (!hostName(map.value("host")) || !integer(map.value("port"), 1, 65535, &port)
            || !identifier(map.value("client_id"), 96)
            || !topics(map.value("receive_topics"), &config.receiveTopics)
            || !topics(map.value("send_topics"), &config.sendTopics)
            || (config.receiveTopics.isEmpty() && config.sendTopics.isEmpty()))
            return fail(error, "MQTT needs explicit host, port, client ID and literal topic allowlists");
        for (const auto &topic : config.receiveTopics)
            if (config.sendTopics.contains(topic))
                return fail(error, "MQTT send and receive topics must be disjoint to prevent self loops");
        config.host = map.value("host").toString();
        config.clientId = map.value("client_id").toString();
        config.port = quint16(port);
    } else if (kind == Kind::Udp) {
        qint64 bindPort = 0, peerPort = 0;
        if (map.value("bind_address").metaType().id() != QMetaType::QString
            || map.value("peer_address").metaType().id() != QMetaType::QString
            || !config.bindAddress.setAddress(map.value("bind_address").toString())
            || !config.peerAddress.setAddress(map.value("peer_address").toString())
            || !integer(map.value("bind_port"), 0, 65535, &bindPort)
            || !integer(map.value("peer_port"), 1, 65535, &peerPort)
            || config.bindAddress.isMulticast() || config.bindAddress == QHostAddress::Broadcast
            || config.peerAddress.isMulticast() || config.peerAddress == QHostAddress::Broadcast
            || config.peerAddress == QHostAddress::Any || config.peerAddress == QHostAddress::AnyIPv4
            || config.peerAddress == QHostAddress::AnyIPv6)
            return fail(error, "UDP needs explicit numeric bind/peer addresses and ports; peer must be unicast");
        config.bindPort = quint16(bindPort);
        config.peerPort = quint16(peerPort);
    }
    *result = std::move(config);
    return true;
}

class Link final : public ServiceEndpoint {
    Q_OBJECT
public:
    explicit Link(Kind kind, QObject *parent) : ServiceEndpoint(parent), m_kind(kind) {
        m_notifications.setInterval(250);
        connect(&m_notifications, &QTimer::timeout, this, [this] {
            if (!m_dirty) return;
            m_dirty = false;
            emit statusChanged();
        });
    }
    ~Link() override {
        blockSignals(true);
        stop();
    }
    bool start(const QVariantMap &, QString *) override;
    void stop() override;
    bool submit(const QVariantMap &, QString *) override;
    QString status() const override { return m_lastError.isEmpty() ? m_state : m_state + ": " + m_lastError; }
    QVariantMap details() const override;

private:
    struct Incoming {
        QString channel, peer, timingBasis;
        QByteArray payload;
        PacketObservation::Stamp observation;
        qsizetype cost = 0;
    };
    bool enqueue(QString channel, QByteArray payload, QString peer,
                 PacketObservation::Stamp observation, QString timingBasis);
    void drain(quint64 generation);
    void readUdp(quint64 generation);
    void scheduleUdpRead(quint64 generation);
    void mqttReceived(quint64 generation, const QString &, const QByteArray &, const QVariantMap &);
    bool result(const QString &requestId, bool accepted, const QString &reason, QString *error);
    bool refuseStart(QString *error, const QString &reason);
    void connectionError(quint64 generation, const QString &reason);

    Kind m_kind;
    Configuration m_config;
    QPointer<MqttTransport> m_mqtt;
    QPointer<QUdpSocket> m_udp;
    QTimer m_notifications;
    QQueue<Incoming> m_inbox;
    QString m_session, m_state = "stopped", m_lastError;
    quint64 m_generation = 0, m_received = 0, m_delivered = 0, m_dropped = 0;
    quint64 m_sendSubmitted = 0, m_sendRejected = 0, m_filtered = 0;
    qint64 m_sequence = 0, m_lastQueueAge = 0, m_maximumQueueAge = 0;
    qsizetype m_inboxBytes = 0;
    bool m_active = false, m_connected = false, m_drainScheduled = false;
    bool m_udpReadScheduled = false, m_dirty = false;
};

bool Link::refuseStart(QString *error, const QString &reason) {
    if (error) *error = reason;
    m_lastError = reason.left(256);
    m_state = "error";
    emit statusChanged();
    return false;
}
bool Link::start(const QVariantMap &map, QString *error) {
    if (error) error->clear();
    QPointer<Link> lifetime(this);
    const auto generation = m_generation + 1;
    stop();
    if (!lifetime || generation != m_generation)
        return fail(error, "Terminal-link start superseded during retirement");
    Configuration config;
    QString reason;
    if (!configuration(m_kind, map, &config, &reason)) return refuseStart(error, reason);
    m_config = std::move(config);
    m_session = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_active = true;
    m_state = "connecting";
    m_notifications.start();
    if (m_kind == Kind::Loopback) {
        m_connected = true;
        m_state = "ready";
    } else if (m_kind == Kind::Mqtt) {
        auto *transport = new MqttTransport(this);
        m_mqtt = transport;
        const QPointer<MqttTransport> guarded(transport);
        connect(transport, &MqttEndpoint::connected, this, [this, generation, guarded] {
            if (generation != m_generation || !guarded || m_mqtt != guarded) return;
            m_connected = true;
            m_state = "ready";
            m_lastError.clear();
            emit statusChanged();
        });
        connect(transport, &MqttEndpoint::disconnected, this, [this, generation, guarded] {
            if (generation != m_generation || !guarded || m_mqtt != guarded) return;
            m_connected = false;
            m_state = "disconnected";
            emit statusChanged();
        });
        connect(transport, &MqttEndpoint::errorOccurred, this, [this, generation, guarded](const QString &reason) {
            if (generation != m_generation || !guarded || m_mqtt != guarded) return;
            connectionError(generation, reason);
        });
        connect(transport, &MqttTransport::diagnosticsChanged, this, [this, generation] {
            if (generation == m_generation) m_dirty = true;
        });
        connect(transport, &MqttTransport::packetObserved, this,
            [this, generation, guarded](const QString &topic, const QByteArray &bytes, const QVariantMap &observation) {
                if (generation != m_generation || !guarded || m_mqtt != guarded) return;
                mqttReceived(generation, topic, bytes, observation);
            });
        const bool opened = transport->open(m_config.clientId, m_config.host, m_config.port, m_config.receiveTopics);
        if (!lifetime || generation != m_generation || !guarded || m_mqtt != guarded)
            return fail(error, "Terminal-link start superseded while opening MQTT");
        if (!opened) {
            const auto message = m_lastError.isEmpty() ? QString("Cannot open MQTT transport") : m_lastError;
            stop();
            if (!lifetime || m_generation != generation + 1)
                return fail(error, "Terminal-link start superseded after MQTT failure");
            return refuseStart(error, message);
        }
        m_session = transport->packetObservationSession();
    } else {
        auto *socket = new QUdpSocket(this);
        m_udp = socket;
        const QPointer<QUdpSocket> guarded(socket);
        socket->setReadBufferSize(MaximumInboxBytes);
        socket->setSocketOption(QAbstractSocket::ReceiveBufferSizeSocketOption, int(MaximumInboxBytes));
        connect(socket, &QUdpSocket::readyRead, this, [this, generation, guarded] {
            if (generation == m_generation && guarded && m_udp == guarded) scheduleUdpRead(generation);
        });
        connect(socket, &QUdpSocket::errorOccurred, this,
            [this, generation, guarded](QAbstractSocket::SocketError) {
                if (generation != m_generation || !guarded || m_udp != guarded) return;
                connectionError(generation, guarded->errorString());
            }, Qt::QueuedConnection);
        const bool bound = socket->bind(m_config.bindAddress, m_config.bindPort, QUdpSocket::DontShareAddress);
        if (!lifetime || generation != m_generation || !guarded || m_udp != guarded)
            return fail(error, "Terminal-link start superseded while binding UDP");
        if (!bound) {
            const auto message = socket->errorString();
            stop();
            if (!lifetime || m_generation != generation + 1)
                return fail(error, "Terminal-link start superseded after UDP failure");
            return refuseStart(error, message);
        }
        m_connected = true; // A bound socket is ready, not a peer handshake or delivery ACK.
        m_state = "ready";
    }
    emit statusChanged();
    return lifetime && generation == m_generation;
}

void Link::stop() {
    ++m_generation;
    m_active = m_connected = false;
    m_notifications.stop();
    m_dirty = m_drainScheduled = m_udpReadScheduled = false;
    const auto mqtt = m_mqtt;
    const auto udp = m_udp;
    m_mqtt = nullptr;
    m_udp = nullptr;
    if (mqtt) {
        // Child transport notifications must not reenter a half-retired owner.
        mqtt->blockSignals(true);
        mqtt->disconnect(this);
        mqtt->close();
        mqtt->deleteLater();
    }
    if (udp) {
        udp->blockSignals(true);
        udp->disconnect(this);
        udp->abort();
        udp->deleteLater();
    }
    m_inbox.clear();
    m_inboxBytes = 0;
    m_session.clear();
    m_state = "stopped";
    m_lastError.clear();
    m_config = {};
    m_sequence = m_lastQueueAge = m_maximumQueueAge = 0;
    m_received = m_delivered = m_dropped = m_sendSubmitted = m_sendRejected = m_filtered = 0;
    emit statusChanged();
}

void Link::connectionError(quint64 generation, const QString &reason) {
    if (generation != m_generation) return;
    m_lastError = reason.left(256);
    m_state = "error";
    if (m_kind == Kind::Mqtt) m_connected = false;
    QPointer<Link> lifetime(this);
    emit statusChanged();
    if (!lifetime || generation != m_generation) return;
    const auto message = m_lastError;
    emit errorOccurred(message);
}

QVariantMap Link::details() const {
    QVariantMap value{{"active", m_active}, {"connected", m_connected}, {"state", m_state},
        {"kind", kindName(m_kind)}, {"context", m_config.context}, {"session_id", m_session},
        {"received", qulonglong(m_received)}, {"delivered", qulonglong(m_delivered)},
        {"dropped", qulonglong(m_dropped)}, {"filtered", qulonglong(m_filtered)},
        {"send_submitted", qulonglong(m_sendSubmitted)}, {"send_rejected", qulonglong(m_sendRejected)},
        {"pending_messages", m_inbox.size()}, {"pending_bytes", m_inboxBytes},
        {"maximum_messages", MaximumInboxMessages}, {"maximum_bytes", MaximumInboxBytes},
        {"drain_quota", DrainQuota}, {"last_dispatch_queue_age_ms", m_lastQueueAge},
        {"maximum_dispatch_queue_age_ms", m_maximumQueueAge}, {"last_error", m_lastError},
        {"authoritative", false}, {"source_kind", "unclassified"}, {"peer_authenticated", false},
        {"official_protocol_adapter", false}, {"execution_ack_available", false},
        {"kernel_arrival_time_available", false}, {"producer_timestamp_available", false}};
    if (m_kind == Kind::Mqtt) {
        value["peer"] = m_config.host.isEmpty() ? QString{} : m_config.host + ":" + QString::number(m_config.port);
        value["mqtt_transport"] = m_mqtt ? m_mqtt->diagnostics() : QVariantMap{};
        value["queue_limit_scope"] = "wrapper_64_messages_1MiB_plus_MQTT_256_messages_1MiB";
        value["receive_topics"] = m_config.receiveTopics;
        value["send_topics"] = m_config.sendTopics;
    } else if (m_kind == Kind::Udp) {
        value["bind_address"] = m_udp ? m_udp->localAddress().toString() : QString{};
        value["bind_port"] = m_udp ? int(m_udp->localPort()) : 0;
        value["peer"] = m_config.peerAddress.isNull() ? QString{} : peerName(m_config.peerAddress, m_config.peerPort);
        value["pending_socket_bytes"] = m_udp ? m_udp->bytesAvailable() : 0;
        value["pending_output_bytes"] = m_udp ? m_udp->bytesToWrite() : 0;
        value["queue_limit_scope"] = "wrapper_plus_operating_system_datagram_buffer";
    } else {
        value["peer"] = "local";
        value["queue_limit_scope"] = "wrapper";
    }
    return value;
}

bool Link::result(const QString &requestId, bool accepted, const QString &reason, QString *error) {
    if (error) *error = reason;
    if (accepted) ++m_sendSubmitted;
    else {
        ++m_sendRejected;
        m_lastError = reason.left(256);
    }
    m_dirty = true;
    const auto generation = m_generation;
    QPointer<Link> lifetime(this);
    emit messageReceived({{"schema", 1}, {"kind", "wire-submit-result"}, {"request_id", requestId},
        {"accepted", accepted}, {"delivery", "local_submission"}, {"execution_confirmed", false}});
    if (!lifetime || generation != m_generation) return false;
    if (!m_active) emit statusChanged();
    return lifetime && generation == m_generation && accepted;
}
bool Link::submit(const QVariantMap &message, QString *error) {
    if (error) error->clear();
    const auto requestId = identifier(message.value("request_id"), 96)
        ? message.value("request_id").toString() : QString{};
    if (!exactKeys(message, {"schema", "kind", "request_id", "channel", "payload"})
        || !integer(message.value("schema"), 1, 1)
        || message.value("kind").metaType().id() != QMetaType::QString || message.value("kind") != "wire-send"
        || requestId.isEmpty() || message.value("channel").metaType().id() != QMetaType::QString
        || message.value("payload").metaType().id() != QMetaType::QByteArray)
        return result(requestId, false, "Invalid raw terminal send shape, request ID or binary payload", error);
    if (!m_active || !m_connected)
        return result(requestId, false, "Terminal link is not connected", error);
    const auto channel = message.value("channel").toString();
    const auto bytes = message.value("payload").toByteArray();
    if (bytes.size() > (m_kind == Kind::Udp ? MaximumUdpPayload : MaximumPayload))
        return result(requestId, false, "Raw terminal packet exceeds transport byte limit", error);
    if ((m_kind == Kind::Loopback && channel != "local") || (m_kind == Kind::Udp && channel != "peer")
        || (m_kind == Kind::Mqtt && !m_config.sendTopics.contains(channel)))
        return result(requestId, false, "Terminal send channel is not allowlisted", error);
    const auto generation = m_generation;
    QPointer<Link> lifetime(this);
    bool accepted = false;
    if (m_kind == Kind::Loopback) {
        if (m_sequence >= PacketObservation::SafeInteger)
            return result(requestId, false, "Local session sequence exhausted", error);
        const auto observation = PacketObservation::capture("local_direct", m_session, ++m_sequence);
        accepted = enqueue(channel, bytes, "local", observation, "local_submission");
        if (!accepted) return result(requestId, false, "Terminal receive queue is full", error);
    } else if (m_kind == Kind::Mqtt) {
        accepted = m_mqtt && m_mqtt->publish(channel, bytes);
        if (!lifetime || generation != m_generation)
            return fail(error, "Terminal send superseded during MQTT publication");
        if (!accepted) return result(requestId, false, "MQTT transport refused local submission", error);
    } else {
        if (!m_udp || m_udp->bytesToWrite() + bytes.size() > MaximumInboxBytes)
            return result(requestId, false, "UDP output buffer is full", error);
        accepted = m_udp->writeDatagram(bytes, m_config.peerAddress, m_config.peerPort) == bytes.size();
        if (!lifetime || generation != m_generation)
            return fail(error, "Terminal send superseded during UDP publication");
        if (!accepted) return result(requestId, false, "UDP transport refused local submission", error);
    }
    return result(requestId, true, {}, error);
}

bool Link::enqueue(QString channel, QByteArray bytes, QString peer,
                   PacketObservation::Stamp observation, QString timingBasis) {
    ++m_received;
    m_dirty = true;
    // Metadata is bounded independently of caller payload. Include its fixed
    // bookkeeping cost so a large number of empty packets cannot bypass limits.
    const qsizetype cost = bytes.size() + (channel.size() + peer.size()) * qsizetype(sizeof(QChar)) + 512;
    if (m_inbox.size() >= MaximumInboxMessages || m_inboxBytes + cost > MaximumInboxBytes) {
        ++m_dropped;
        return false;
    }
    m_inbox.enqueue({std::move(channel), std::move(peer), std::move(timingBasis),
        std::move(bytes), std::move(observation), cost});
    m_inboxBytes += cost;
    if (!m_drainScheduled) {
        m_drainScheduled = true;
        const auto generation = m_generation;
        QMetaObject::invokeMethod(this, [this, generation] { drain(generation); }, Qt::QueuedConnection);
    }
    return true;
}

void Link::drain(quint64 generation) {
    QPointer<Link> lifetime(this);
    for (int count = 0; count < DrainQuota; ++count) {
        if (generation != m_generation || !m_active) return;
        if (m_inbox.isEmpty()) break;
        const auto incoming = m_inbox.dequeue();
        m_inboxBytes -= incoming.cost;
        ++m_delivered;
        m_lastQueueAge = std::max<qint64>(0, PacketObservation::steadyMilliseconds() - incoming.observation.receivedTick);
        m_maximumQueueAge = std::max(m_maximumQueueAge, m_lastQueueAge);
        m_dirty = true;
        const QVariantMap output{{"schema", 1}, {"kind", "wire-received"}, {"context", m_config.context},
            {"session_id", incoming.observation.session}, {"sequence", incoming.observation.sequence},
            {"received_at_ms", incoming.observation.receivedUtc}, {"received_tick_ms", incoming.observation.receivedTick},
            {"channel", incoming.channel}, {"payload", incoming.payload}, {"transport_kind", kindName(m_kind)},
            {"peer", incoming.peer}, {"authoritative", false}, {"source_kind", "unclassified"},
            {"received_timing_basis", incoming.timingBasis}};
        emit messageReceived(output);
        if (!lifetime || generation != m_generation) return;
    }
    if (!m_inbox.isEmpty())
        QMetaObject::invokeMethod(this, [this, generation] { drain(generation); }, Qt::QueuedConnection);
    else m_drainScheduled = false;
}

void Link::mqttReceived(quint64 generation, const QString &topic, const QByteArray &bytes,
                        const QVariantMap &map) {
    if (generation != m_generation || !m_active) return;
    PacketObservation::Stamp observation;
    if (!m_config.receiveTopics.contains(topic) || bytes.size() > MaximumPayload
        || !PacketObservation::parse(map, &observation) || observation.basis != "mqtt_callback"
        || observation.session != m_session || observation.sequence <= m_sequence
        || !PacketObservation::validateAt(observation, QDateTime::currentMSecsSinceEpoch(),
                                         PacketObservation::steadyMilliseconds())) {
        ++m_filtered;
        m_dirty = true;
        return;
    }
    m_sequence = observation.sequence;
    enqueue(topic, bytes, m_config.host + ":" + QString::number(m_config.port),
            std::move(observation), "mqtt_callback");
}

void Link::scheduleUdpRead(quint64 generation) {
    if (generation != m_generation || !m_active || m_udpReadScheduled) return;
    m_udpReadScheduled = true;
    QMetaObject::invokeMethod(this, [this, generation] { readUdp(generation); }, Qt::QueuedConnection);
}
void Link::readUdp(quint64 generation) {
    if (generation != m_generation || !m_active || !m_udp) return;
    auto socket = m_udp;
    for (int count = 0; count < DrainQuota && socket->hasPendingDatagrams(); ++count) {
        const auto size = socket->pendingDatagramSize();
        if (size < 0) break;
        if (size > MaximumUdpPayload || m_sequence >= PacketObservation::SafeInteger) {
            socket->receiveDatagram(0);
            ++m_dropped;
            m_dirty = true;
            continue;
        }
        // Qt does not expose a portable kernel arrival timestamp here. This
        // sample is deliberately labelled socket dispatch, never producer time.
        const auto observation = PacketObservation::capture("host_dispatch", m_session, ++m_sequence);
        const auto packet = socket->receiveDatagram(MaximumUdpPayload);
        if (!packet.isValid() || packet.senderAddress() != m_config.peerAddress
            || packet.senderPort() != m_config.peerPort) {
            ++m_filtered;
            m_dirty = true;
            continue;
        }
        enqueue("peer", packet.data(), peerName(packet.senderAddress(), packet.senderPort()),
                observation, "socket_dispatch");
    }
    if (socket->hasPendingDatagrams())
        QMetaObject::invokeMethod(this, [this, generation] { readUdp(generation); }, Qt::QueuedConnection);
    else m_udpReadScheduled = false;
}
}

bool validateConfiguration(Kind kind, const QVariantMap &values, QString *error) {
    if (error) error->clear();
    switch (kind) {
    case Kind::Loopback: case Kind::Mqtt: case Kind::Udp: {
        Configuration checked;
        return configuration(kind, values, &checked, error);
    }
    }
    return fail(error, QStringLiteral("Unsupported terminal-link kind"));
}

ServiceEndpoint *create(Kind kind, QObject *parent) {
    switch (kind) {
    case Kind::Loopback: case Kind::Mqtt: case Kind::Udp:
        return new Link(kind, parent);
    }
    return nullptr;
}
}

#include "TerminalLinks.moc"
