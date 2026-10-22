#pragma once
#include <QString>
#include <QVariantMap>
#include <QtPlugin>

// Optional ingress-timing extension. These are host arrival times, never a
// producer timestamp, official authentication, or an end-to-end latency claim.
namespace PacketObservation {
constexpr qint64 SafeInteger = 9007199254740991LL;
constexpr qint64 ClockToleranceMs = 250;
constexpr qint64 MaximumAgeMs = 60000;
struct Stamp {
    QString basis, session;
    qint64 sequence = 0, receivedUtc = 0, receivedTick = 0;
};
qint64 steadyMilliseconds();
Stamp capture(const QString &basis, const QString &session, qint64 sequence);
QVariantMap toMap(const Stamp &);
bool parse(const QVariantMap &, Stamp *, QString *error = nullptr);
bool validateAt(const Stamp &, qint64 utcNow, qint64 steadyNow,
                qint64 *ageMs = nullptr, QString *error = nullptr);
}

// A separate Qt interface preserves TelemetryEndpoint's existing vtable/ABI.
// This method is deliberately not a QML-invokable telemetry injection API.
class TelemetryObservationConsumer {
public:
    virtual ~TelemetryObservationConsumer() = default;
    virtual bool applyObserved(const QString &messageType, const QVariantMap &fields,
                               const QVariantMap &observation, QString *error = nullptr) = 0;
};
#define TelemetryObservationConsumer_iid "org.robomaster.client.TelemetryObservationConsumer/1.0"
Q_DECLARE_INTERFACE(TelemetryObservationConsumer, TelemetryObservationConsumer_iid)
