#pragma once
#include "TelemetryEndpoint.h"
#include "PacketObservation.h"
#include <QElapsedTimer>

// 仅管理收到的状态；协议解析与发出的操作意图在其他层处理。
class TelemetryStore : public TelemetryEndpoint, public TelemetryObservationConsumer {
    Q_OBJECT
    Q_INTERFACES(TelemetryObservationConsumer)
    Q_PROPERTY(QVariantMap fieldFreshness READ fieldFreshness NOTIFY freshnessChanged)
public:
    explicit TelemetryStore(QObject *parent = nullptr);
    void apply(const QString &messageType, const QVariantMap &fields) override;
    bool applyObserved(const QString &messageType, const QVariantMap &fields,
                       const QVariantMap &observation, QString *error = nullptr) override;
    void reset() override;
    void setClientId(int id) override;
    void updateFreshness() override;
    QVariantMap group(const QString &name) const override;
    QVariantMap fieldFreshness() const {
        return m_fieldFreshness;
    }
    // 只读本机字段接收标记，供界面区分本次optional字段与保留旧值。
    Q_INVOKABLE QVariantMap fieldObservation(const QString &groupName,
                                           const QString &fieldName) const;

private:
    struct FieldIngress {
        PacketObservation::Stamp stamp;
        qint64 queueAge = 0;
    };
    bool applySample(const QString &messageType, const QVariantMap &fields,
                     const PacketObservation::Stamp &sample, qint64 ageMs,
                     bool observed, QString *error);
    bool rejectIngress(const QString &reason, QString *error);
    bool rebuildRobotData();
    bool refreshFreshness();
    QVariantMap buildFieldObservation(const QString &groupName, const QString &fieldName,
                                     qint64 seenAt, qint64 now) const;
    QVariantMap m_values, m_robotData, m_freshness, m_fieldFreshness;
    QMap<QString, qint64> m_lastSeen;
    QMap<QString, QMap<QString, qint64>> m_fieldSeen;
    QMap<QString, QMap<QString, qint64>> m_fieldReceivedUtc;
    QMap<QString, QMap<QString, quint64>> m_fieldObservationRevision;
    QMap<QString, QMap<QString, FieldIngress>> m_fieldIngress;
    PacketObservation::Stamp m_lastIngress;
    bool m_hasIngress = false;
    quint64 m_directSequence = 0, m_ingressAccepted = 0, m_ingressRejected = 0;
    QString m_ingressRejection;
    qint64 m_lastQueueAge = 0;
    QString m_observationSession;
    QElapsedTimer m_clock;
    int m_clientId = 0;
    quint64 m_revision = 0;
    quint64 m_buffContextRevision = 0;
    quint64 m_gameContextRevision = 0;
};
