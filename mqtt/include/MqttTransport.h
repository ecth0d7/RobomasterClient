#pragma once
#include "ClientPlugin.h"
#include "PacketObservation.h"
#include <QByteArray>
#include <QStringList>
#include <mosquitto.h>
#include <atomic>
#include <QMutex>
#include <QQueue>
#include <memory>

// MQTT 只管理连接和字节，不依赖 Protobuf、界面面板或比赛状态。
class MqttTransport : public MqttEndpoint {
    Q_OBJECT
    Q_PROPERTY(QVariantMap diagnostics READ diagnostics NOTIFY diagnosticsChanged)
    // Concrete optional extension; existing MqttEndpoint implementations remain ABI compatible.
    Q_PROPERTY(QString packetObservationSession READ packetObservationSession)
public:
    explicit MqttTransport(QObject *parent = nullptr);
    ~MqttTransport() override;
    bool open(const QString &id, const QString &host, int port, const QStringList &topics) override;
    void close() override;
    bool publish(const QString &topic, const QByteArray &payload) override;
    QVariantMap diagnostics() const;
    QString packetObservationSession() const;
signals:
    void diagnosticsChanged();
    void packetObserved(const QString &topic, const QByteArray &payload,
                        const QVariantMap &observation);

private:
    struct CallbackContext {
        MqttTransport *owner;
        quint64 generation;
        const QString session;
    };
    struct Incoming {
        QString topic;
        QByteArray payload;
        qsizetype cost;
        PacketObservation::Stamp observation;
    };
    void enqueue(quint64 generation, QString topic, QByteArray payload,
                 PacketObservation::Stamp observation);
    void drain(quint64 generation);
    static void onConnect(mosquitto *, void *, int);
    static void onDisconnect(mosquitto *, void *, int);
    static void onMessage(mosquitto *, void *, const mosquitto_message *);
    mosquitto *m_client = nullptr;
    std::unique_ptr<CallbackContext> m_callbackContext;
    QStringList m_topics;
    std::atomic_bool m_connected{false};
    bool m_loopStarted = false;
    std::atomic<quint64> m_generation{0};
    mutable QMutex m_inboxMutex;
    QQueue<Incoming> m_inbox;
    qsizetype m_inboxBytes = 0;
    bool m_drainScheduled = false;
    QString m_observationSession;
    qint64 m_packetSequence = 0, m_lastIngressUtc = 0;
    qint64 m_lastDispatchQueueAge = 0, m_maximumDispatchQueueAge = 0;
    quint64 m_received = 0, m_dropped = 0, m_delivered = 0;
    // Submission diagnostics only: QoS 0 cannot prove broker/device delivery.
    quint64 m_publishSubmitted = 0, m_publishRejected = 0, m_publishBytes = 0;
    QString m_lastPublishTopic, m_lastPublishError, m_lastPublishAt;
    static constexpr qsizetype MaximumInboxBytes = 1024 * 1024;
    static constexpr int MaximumInboxMessages = 256;
};
