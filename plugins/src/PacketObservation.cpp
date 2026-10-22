#include "PacketObservation.h"
#include <QDateTime>
#include <QSet>
#include <chrono>
#include <cmath>

namespace PacketObservation {
namespace {
bool fail(QString *error, const QString &reason) {
    if (error) *error = reason;
    return false;
}
bool integer(const QVariant &value, qint64 low, qint64 high, qint64 *out) {
    switch (value.metaType().id()) {
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double: break;
    default: return false;
    }
    const double n = value.toDouble();
    if (!std::isfinite(n) || std::floor(n) != n || n < low || n > high) return false;
    *out = qint64(n); return true;
}
bool sessionId(const QString &id) {
    if (id.isEmpty() || id.size() > 96) return false;
    for (const auto c : id) {
        const auto u = c.unicode();
        if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') ||
              (u >= '0' && u <= '9') || u == '-' || u == '_' || u == '.' || u == ':')) return false;
    }
    return true;
}
}
qint64 steadyMilliseconds() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}
Stamp capture(const QString &basis, const QString &session, qint64 sequence) {
    return {basis, session, sequence, QDateTime::currentMSecsSinceEpoch(), steadyMilliseconds()};
}
QVariantMap toMap(const Stamp &stamp) {
    return {{"schema", 1}, {"basis", stamp.basis}, {"clock", "host_steady"},
            {"session_id", stamp.session}, {"sequence", stamp.sequence},
            {"received_at_ms", stamp.receivedUtc}, {"received_tick_ms", stamp.receivedTick}};
}
bool parse(const QVariantMap &map, Stamp *result, QString *error) {
    if (error) error->clear();
    static const QSet<QString> keys{"schema", "basis", "clock", "session_id", "sequence", "received_at_ms", "received_tick_ms"};
    qint64 schema = 0;
    if (map.size() != keys.size()) return fail(error, "Invalid packet observation shape");
    for (auto it = map.cbegin(); it != map.cend(); ++it)
        if (!keys.contains(it.key())) return fail(error, "Unknown packet observation field");
    Stamp stamp;
    if (!integer(map.value("schema"), 1, 1, &schema) || map.value("clock") != "host_steady"
        || map.value("basis").metaType().id() != QMetaType::QString
        || !QSet<QString>{"mqtt_callback", "host_dispatch", "local_direct"}.contains(map.value("basis").toString())
        || map.value("session_id").metaType().id() != QMetaType::QString
        || !sessionId(map.value("session_id").toString())
        || !integer(map.value("sequence"), 1, SafeInteger, &stamp.sequence)
        || !integer(map.value("received_at_ms"), 1, SafeInteger, &stamp.receivedUtc)
        || !integer(map.value("received_tick_ms"), 0, SafeInteger, &stamp.receivedTick))
        return fail(error, "Invalid packet observation identity, basis or clock");
    stamp.basis = map.value("basis").toString(); stamp.session = map.value("session_id").toString();
    if (result) *result = stamp;
    return true;
}
bool validateAt(const Stamp &stamp, qint64 utc, qint64 tick, qint64 *ageMs, QString *error) {
    if (error) error->clear();
    if (utc <= 0 || utc > SafeInteger || tick < 0 || tick > SafeInteger || stamp.receivedTick < 0
        || stamp.receivedUtc <= 0 || stamp.receivedUtc > utc || stamp.receivedTick > tick)
        return fail(error, "Packet observation is future-dated or host clock is invalid");
    const auto age = tick - stamp.receivedTick;
    if (age > MaximumAgeMs) return fail(error, "Packet exceeded bounded host ingress age");
    if (std::abs((utc - stamp.receivedUtc) - age) > ClockToleranceMs)
        return fail(error, "UTC and steady ingress clocks disagree");
    if (ageMs) *ageMs = age;
    return true;
}
}
