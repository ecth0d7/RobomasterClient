#include "TerminalDataBus.h"
#include "TerminalPluginSourceIdentity.h"

#include <QDateTime>
#include <QElapsedTimer>
#include <QJsonDocument>
#include <QMap>
#include <QRegularExpression>
#include <QSet>
#include <QThread>
#include <QTimer>
#include <QUuid>
#include <algorithm>
#include <cmath>
#include <utility>

namespace {
constexpr qint64 SafeInteger = 9007199254740991LL;
constexpr qint64 ClockToleranceMs = 250;
constexpr qsizetype MaximumBytes = 64 * 1024;
// Leave room for age/revision digits and state labels to grow in the retained
// projection without ever silently truncating the complete view.
constexpr qsizetype RetainedViewBudget = 48 * 1024;
constexpr int MaximumSources = 32, MaximumItems = 128, MaximumSessions = 8;

bool fail(QString *error, const QString &reason) {
    if (error) *error = reason;
    return false;
}
bool number(const QVariant &value, double *out = nullptr) {
    switch (value.metaType().id()) {
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double: case QMetaType::Float: break;
    default: return false;
    }
    const auto n = value.toDouble();
    if (!std::isfinite(n) || std::abs(n) > double(SafeInteger)) return false;
    if (out) *out = n;
    return true;
}
bool integer(const QVariant &value, qint64 low, qint64 high, qint64 *out = nullptr) {
    double n = 0;
    if (!number(value, &n) || std::floor(n) != n || n < double(low) || n > double(high)) return false;
    if (out) *out = qint64(n);
    return true;
}
bool null(const QVariant &value) {
    return !value.isValid() || value.metaType().id() == QMetaType::Nullptr;
}
bool text(const QVariant &value, qsizetype maximum, bool empty = false) {
    if (value.metaType().id() != QMetaType::QString) return false;
    const auto s = value.toString();
    if ((!empty && s.isEmpty()) || s.size() > maximum) return false;
    for (const auto c : s) if (c.isNull() || c.category() == QChar::Other_Control) return false;
    return true;
}
bool id(const QVariant &value, qsizetype maximum = 96) {
    if (!text(value, maximum)) return false;
    for (const auto c : value.toString()) {
        const auto u = c.unicode();
        if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') ||
              (u >= '0' && u <= '9') || u == '_' || u == '-' || u == '.' || u == ':' || u == '/'))
            return false;
    }
    return true;
}
bool keys(const QVariantMap &map, const QSet<QString> &required,
          const QSet<QString> &optional = {}) {
    for (const auto &key : required) if (!map.contains(key)) return false;
    for (auto it = map.cbegin(); it != map.cend(); ++it)
        if (!required.contains(it.key()) && !optional.contains(it.key())) return false;
    return true;
}
bool contextValid(const QVariantMap &context) {
    return keys(context, {"profile_id", "field_profile_id", "capability_revision"}) &&
           id(context.value("profile_id"), 128) && id(context.value("field_profile_id"), 128) &&
           id(context.value("capability_revision"), 128);
}
bool robotKey(const QVariant &value) {
    if (!text(value, 64)) return false;
    const auto parts = value.toString().split('/');
    if (parts.size() != 3 || (parts[0] != "red" && parts[0] != "blue") ||
        parts[1].isEmpty() || parts[1].size() > 32 || parts[2].isEmpty() || parts[2].size() > 3 ||
        parts[2][0] < '1' || parts[2][0] > '9') return false;
    for (const auto c : parts[1])
        if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '-')) return false;
    for (const auto c : parts[2]) if (c < '0' || c > '9') return false;
    return parts[1][0] >= 'a' && parts[1][0] <= 'z';
}
// Payloads may carry measurements, never another provenance/authority envelope.
// Reject these recursively before QVariant-to-JSON conversion hooks can run.
bool payload(const QVariant &value, int depth, int *nodes, qsizetype *cost) {
    if (depth > 6 || ++*nodes > 4096 || *cost > MaximumBytes) return false;
    if (null(value)) { *cost += 4; return true; }
    if (value.metaType().id() == QMetaType::QVariantMap) {
        static const QSet<QString> forbidden{"authoritative", "authenticated", "host_verified", "verified",
            "source_kind", "validation", "allowed_uses", "ai_input_ready", "production_adapter_connected",
            "received_at_ms", "received_tick_ms", "official_engine", "official_player_client"};
        const auto map = value.toMap();
        if (map.size() > 64) return false;
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            if (!text(it.key(), 96) || forbidden.contains(it.key())) return false;
            *cost += it.key().size() + 4;
            if (!payload(it.value(), depth + 1, nodes, cost)) return false;
        }
    } else if (value.metaType().id() == QMetaType::QVariantList) {
        const auto list = value.toList();
        if (list.size() > 128) return false;
        for (const auto &entry : list) if (!payload(entry, depth + 1, nodes, cost)) return false;
    } else if (value.metaType().id() == QMetaType::QString) {
        if (!text(value, 4096, true)) return false;
        *cost += value.toString().size() + 2;
    } else if (value.metaType().id() == QMetaType::Bool) *cost += 5;
    else { if (!number(value)) return false; *cost += 16; }
    return *cost <= MaximumBytes;
}
QByteArray compact(const QVariantMap &map) {
    return QJsonDocument::fromVariant(map).toJson(QJsonDocument::Compact);
}
struct Item {
    QVariantMap observation;
    QString sourceKey;
    qint64 receivedUtc = 0, receivedTick = 0, deadline = 0, producerAge = 0, revision = 0;
    bool knownClock = false, retired = false;
    QVariantMap transport;
};
struct Source {
    QString session, kind;
    QSet<QString> sessions;
    qint64 sequence = 0;
};
struct State {
    QVariantMap context;
    QMap<QString, Source> sources;
    QMap<QString, Item> items;
    QString lastError, mockSession;
    QSet<QString> retiredActivations;
    qint64 accepted = 0, rejected = 0, revision = 0, mockSequence = 0, lastUtc = 0, lastTick = 0;
    qint64 evictedTransportRecords = 0;
    bool clockQuarantined = false;
};
bool clockConsistent(const State &state, qint64 utc, qint64 tick) {
    return utc > 0 && utc <= SafeInteger && tick >= 0 && tick <= SafeInteger &&
           (!state.lastUtc || (utc >= state.lastUtc && tick >= state.lastTick &&
             std::abs((utc - state.lastUtc) - (tick - state.lastTick)) <= ClockToleranceMs));
}
void observeClock(State &state, qint64 utc, qint64 tick) {
    if (!clockConsistent(state, utc, tick)) state.clockQuarantined = true;
    state.lastUtc = utc; state.lastTick = tick;
}
QVariantMap project(const State &state, qint64 utc, qint64 tick, bool retainDiagnosticValues = false) {
    const bool timeValid = !state.clockQuarantined && clockConsistent(state, utc, tick);
    QVariantList rows;
    bool hasMock = false;
    for (auto it = state.items.cbegin(); it != state.items.cend(); ++it) {
        const auto &item = it.value();
        auto row = item.observation;
        const auto receivedAge = qMax<qint64>(0, tick - item.receivedTick);
        const auto remaining = qMax<qint64>(0, item.deadline - tick);
        const bool withdrawn = row.value("lifecycle") == "withdrawn";
        const bool mock = row.value("source_kind") == "mock";
        hasMock = hasMock || mock;
        row.insert("received_at_ms", item.receivedUtc);
        row.insert("received_age_ms", receivedAge);
        row.insert("age_ms", item.knownClock ? QVariant(item.producerAge + receivedAge) : QVariant{});
        row.insert("remaining_ms", item.retired || withdrawn ? 0 : remaining);
        row.insert("revision", item.revision);
        if (!item.transport.isEmpty()) {
            // Native sensor packages did not arrive over a network transport.
            // Keep their host-stamped package origin distinct in the public view.
            row.insert(item.transport.value("adapter_kind") == "native_package"
                ? "source_provenance" : "transport_provenance", item.transport);
        }
        row.insert("state", item.retired ? "retired" : withdrawn ? "withdrawn" : !remaining ? "expired" :
                   !item.knownClock || !timeValid ? "time_unverified" : "fresh");
        // These flags cannot be supplied or elevated by a producer payload.
        row.insert("mock", mock);
        row.insert("authoritative", false);
        row.insert("producer_clock_authenticated", false);
        row.insert("clock_checked", item.knownClock && timeValid);
        row.insert("allowed_uses", QVariantList{});
        row.insert("renderable", false);
        row.insert("spatial_status", row.contains("frame_id") ? "unverified" : "not_projected");
        row.insert("spatial_reason", row.contains("frame_id")
            ? QStringLiteral("坐标／变换未通过渲染器标定接纳，仅显示文字；frame名称不证明可落图") : QString{});
        if (!retainDiagnosticValues && (withdrawn || item.retired)) row.insert("value", QVariant{});
        rows.append(row);
    }
    return {{"schema", 3}, {"kind", "terminal-data-view"}, {"context", state.context},
            {"items", rows}, {"connected", false}, {"production_adapter_connected", false},
            {"ai_input_ready", false}, {"official_adapter_status", "pending"}, {"mock", hasMock}};
}
bool reclaimRetiredTransport(State &state) {
    QString selected;
    qint64 oldest = SafeInteger;
    for (auto it = state.items.cbegin(); it != state.items.cend(); ++it) {
        const auto activation = it->transport.value("activation_id").toString();
        if (it->retired && state.retiredActivations.contains(activation) &&
            (it->receivedTick < oldest || (it->receivedTick == oldest && activation < selected))) {
            selected = activation; oldest = it->receivedTick;
        }
    }
    if (selected.isEmpty()) return false;
    QSet<QString> sources;
    for (auto it = state.items.begin(); it != state.items.end();) {
        if (it->retired && it->transport.value("activation_id") == selected) {
            sources.insert(it->sourceKey);
            it = state.items.erase(it);
            state.evictedTransportRecords = qMin(SafeInteger, state.evictedTransportRecords + 1);
        } else ++it;
    }
    for (const auto &source : sources) {
        bool retained = false;
        for (auto it = state.items.cbegin(); it != state.items.cend(); ++it)
            if (it->sourceKey == source) { retained = true; break; }
        if (!retained) state.sources.remove(source);
    }
    // Only the owning Gateway or native-package source host can close an
    // activation. Its old callbacks are generation-fenced and its UUID is never
    // reused; ordinary source/session history is never reclaimed here.
    state.retiredActivations.remove(selected);
    return true;
}
bool accept(State &state, const QVariantMap &observation, qint64 utc, qint64 tick,
            bool allowMock, QString *error) {
    static const QSet<QString> required{"schema", "context", "team_id", "robot_key", "source_id", "sensor_id",
        "source_kind", "session_id", "sequence", "item_id", "produced_at_ms", "clock_domain", "ttl_ms",
        "confidence", "validation", "lifecycle", "data_type", "value"};
    if (!contextValid(state.context)) return fail(error, "Select a valid rules context before accepting local observations");
    if (!keys(observation, required, {"unit", "frame_id", "frame_revision", "transform_id"}) ||
        !integer(observation.value("schema"), 3, 3) ||
        observation.value("context").metaType().id() != QMetaType::QVariantMap ||
        !contextValid(observation.value("context").toMap()) ||
        observation.value("context").toMap() != state.context ||
        !id(observation.value("team_id")) || !robotKey(observation.value("robot_key")) ||
        !id(observation.value("source_id")) || !text(observation.value("sensor_id"), 96, true) ||
        !id(observation.value("session_id")) || !id(observation.value("item_id")) ||
        !integer(observation.value("sequence"), 1, SafeInteger) ||
        !integer(observation.value("ttl_ms"), 100, 60000) ||
        !id(observation.value("clock_domain")) ||
        (!null(observation.value("produced_at_ms")) &&
         !integer(observation.value("produced_at_ms"), 0, SafeInteger)) ||
        !text(observation.value("source_kind"), 32) || !text(observation.value("validation"), 32) ||
        !text(observation.value("lifecycle"), 16) || !text(observation.value("data_type"), 16))
        return fail(error, "Invalid schema3 local observation, semantic robot key or exact rules context");
    const auto kind = observation.value("source_kind").toString();
    const auto validation = observation.value("validation").toString();
    if ((kind == "local_sensor" || kind == "local_vision") ? validation != "unverified" ||
            !text(observation.value("sensor_id"), 96)
        : kind == "derived" ? validation != "derived"
        : kind == "mock" ? !allowMock || validation != "mock"
        : true)
        return fail(error, "Only unverified local sources or explicit native mock samples are accepted; official authority is unavailable");
    if (!allowMock && observation.value("source_id").toString().startsWith("mock."))
        return fail(error, "Mock source namespace is reserved for explicit demonstration samples");
    if (kind == "mock" && !observation.value("source_id").toString().startsWith("mock."))
        return fail(error, "Demonstration observations require the explicit mock source namespace");
    double confidence = 0;
    if (!null(observation.value("confidence")) &&
        (!number(observation.value("confidence"), &confidence) || confidence < 0 || confidence > 1))
        return fail(error, "Confidence must be null or a finite number from zero to one");
    if (observation.value("lifecycle") != "active" && observation.value("lifecycle") != "withdrawn")
        return fail(error, "Unknown local observation lifecycle");
    for (const auto &key : {"unit", "frame_id", "frame_revision", "transform_id"})
        if (observation.contains(key) && !text(observation.value(key), 128))
            return fail(error, "Invalid local unit, frame or transform reference");
    const auto type = observation.value("data_type").toString();
    const auto value = observation.value("value");
    bool typeValid = type == "number" ? number(value) : type == "boolean" ? value.metaType().id() == QMetaType::Bool
        : type == "text" ? text(value, 2048, true)
        : type == "object" ? value.metaType().id() == QMetaType::QVariantMap
        : (type == "event" || type == "discovery") ? value.metaType().id() == QMetaType::QVariantMap &&
            text(value.toMap().value("summary"), 512) : false;
    int nodes = 0; qsizetype cost = 0;
    if (!typeValid || !payload(value, 0, &nodes, &cost) || compact(observation).size() > MaximumBytes)
        return fail(error, "Invalid, authority-claiming or oversized typed local payload");
    const bool knownClock = observation.value("clock_domain") == "host_utc";
    qint64 producedAge = 0;
    if (knownClock) {
        qint64 produced = 0;
        if (state.clockQuarantined || !integer(observation.value("produced_at_ms"), 1, utc, &produced) ||
            utc - produced > 60000)
            return fail(error, "Native host UTC observation is future-dated, too old or its clock is quarantined");
        producedAge = utc - produced;
    }
    const auto sourceKey = observation.value("team_id").toString() + QChar(0x1f) +
        observation.value("robot_key").toString() + QChar(0x1f) + observation.value("source_id").toString();
    auto source = state.sources.value(sourceKey);
    const auto session = observation.value("session_id").toString();
    const auto sequence = observation.value("sequence").toLongLong();
    if (source.session == session && (sequence <= source.sequence || source.kind != kind))
        return fail(error, "Duplicate/regressed stream sequence or changed source kind within a session");
    if (source.session != session) {
        if (source.sessions.contains(session)) return fail(error, "Retired local source session cannot return");
        if (source.sessions.size() >= MaximumSessions)
            return fail(error, "Local source session history is full; explicitly clear the bus before replacing sources");
        while (!state.sources.contains(sourceKey) && state.sources.size() >= MaximumSources && reclaimRetiredTransport(state)) {}
        if (!state.sources.contains(sourceKey) && state.sources.size() >= MaximumSources)
            return fail(error, "Local source limit is 32; no source was silently removed");
        for (auto it = state.items.begin(); it != state.items.end(); ++it)
            if (it->sourceKey == sourceKey) it->retired = true;
        source.session = session; source.kind = kind; source.sessions.insert(session);
    }
    const auto itemKey = sourceKey + QChar(0x1f) + session + QChar(0x1f) + observation.value("item_id").toString();
    while (!state.items.contains(itemKey) && state.items.size() >= MaximumItems && reclaimRetiredTransport(state)) {}
    if (!state.items.contains(itemKey) && state.items.size() >= MaximumItems)
        return fail(error, "Local item highwater limit is 128; expired or withdrawn records are not silently pruned");
    if (state.revision >= SafeInteger) return fail(error, "Local bus revision exhausted; explicitly clear its scope");
    source.sequence = sequence;
    state.sources[sourceKey] = source;
    const auto ttl = observation.value("ttl_ms").toLongLong();
    state.items[itemKey] = {observation, sourceKey, utc, tick, tick + qMax<qint64>(0, ttl - producedAge),
                           producedAge, ++state.revision, knownClock, false, {}};
    state.accepted = qMin(SafeInteger, state.accepted + 1);
    state.lastError.clear();
    // Retired/withdrawn values are hidden by the public projection, but still
    // count against storage. Otherwise retractions could hide unbounded data.
    while (compact(project(state, utc, tick, true)).size() > RetainedViewBudget && reclaimRetiredTransport(state)) {}
    if (compact(project(state, utc, tick, true)).size() > RetainedViewBudget)
        return fail(error, "Bounded complete local view exceeds its payload budget; no items were truncated");
    return true;
}
}

struct TerminalDataBus::Private {
    State state;
    // Only current host-owned leases live here. Retired sample reclamation can
    // never restore an old UUID, and a user clear does not stop live devices.
    QMap<QString, QString> pluginActivations;
    QElapsedTimer clock;
    QTimer timer;
};

TerminalDataBus::TerminalDataBus(QObject *parent) : QObject(parent), d(std::make_unique<Private>()) {
    d->clock.start();
    d->timer.setParent(this);
    d->timer.setInterval(250);
    connect(&d->timer, &QTimer::timeout, this, &TerminalDataBus::updateAges);
}
TerminalDataBus::~TerminalDataBus() { d->timer.stop(); }
bool TerminalDataBus::validateObservation(const QVariantMap &observation, const QVariantMap &scope,
                                         bool allowMock, QString *error) {
    if (error) error->clear();
    State candidate;
    candidate.context = scope;
    return accept(candidate, observation, QDateTime::currentMSecsSinceEpoch(), 0, allowMock, error);
}
QVariantMap TerminalDataBus::view() const {
    return project(d->state, QDateTime::currentMSecsSinceEpoch(), d->clock.elapsed());
}
QVariantMap TerminalDataBus::diagnostics() const {
    return {{"context_valid", contextValid(d->state.context)}, {"accepted", d->state.accepted},
            {"rejected", d->state.rejected}, {"source_count", d->state.sources.size()},
            {"item_count", d->state.items.size()}, {"last_error", d->state.lastError},
            {"clock_quarantined", d->state.clockQuarantined}, {"timer_running", d->timer.isActive()},
            {"retired_transport_evictions", d->state.evictedTransportRecords},
            {"production_adapter_connected", false}, {"ai_input_ready", false}};
}
bool TerminalDataBus::reject(const QString &reason, QString *error) {
    d->state.rejected = qMin(SafeInteger, d->state.rejected + 1);
    d->state.lastError = reason;
    if (error) *error = reason;
    emit changed();
    return false;
}
void TerminalDataBus::setRulesContext(const QVariantMap &context) {
    if (QThread::currentThread() != thread()) return;
    if (contextValid(context) && context == d->state.context) return;
    d->timer.stop();
    d->pluginActivations.clear();
    d->state = {};
    if (contextValid(context)) d->state.context = context;
    else d->state.lastError = QStringLiteral("Invalid rules context; old samples have been retired");
    observeClock(d->state, QDateTime::currentMSecsSinceEpoch(), d->clock.elapsed());
    emit changed();
}
void TerminalDataBus::clear() {
    if (QThread::currentThread() != thread()) return;
    d->timer.stop();
    const auto context = d->state.context;
    d->state = {};
    d->state.context = context;
    observeClock(d->state, QDateTime::currentMSecsSinceEpoch(), d->clock.elapsed());
    emit changed();
}
bool TerminalDataBus::acceptLocal(const QVariantMap &observation, QString *error) {
    if (error) error->clear();
    if (QThread::currentThread() != thread())
        return fail(error, "Local observation must be dispatched to the bus owner thread");
    if (observation.value("source_id").metaType().id() == QMetaType::QString &&
        (observation.value("source_id").toString().startsWith("gateway.") ||
         observation.value("source_id").toString().startsWith("mock.gateway.")))
        return reject(QStringLiteral("Gateway source namespace is reserved for host transport admission"), error);
    if (observation.value("source_id").metaType().id() == QMetaType::QString &&
        (observation.value("source_id").toString().startsWith("plugin.") ||
         observation.value("source_id").toString().startsWith("mock.plugin.")))
        return reject(QStringLiteral("Plugin source namespace is reserved for host source admission"), error);
    const auto utc = QDateTime::currentMSecsSinceEpoch(), tick = d->clock.elapsed();
    observeClock(d->state, utc, tick);
    auto candidate = d->state;
    QString reason;
    if (!accept(candidate, observation, utc, tick, false, &reason)) return reject(reason, error);
    d->state = std::move(candidate);
    scheduleExpiry();
    emit changed();
    return true;
}
bool TerminalDataBus::acceptTransportObservation(const QVariantMap &observation,
                                                const QVariantMap &provenance,
                                                bool allowMock, QString *error) {
    if (error) error->clear();
    if (QThread::currentThread() != thread())
        return fail(error, "Transport observation must be dispatched to the bus owner thread");
    qint64 queueAge = 0, packetUtc = 0;
    if (!id(provenance.value("activation_id")) || provenance.value("peer_authenticated") != QVariant(false) ||
        !integer(provenance.value("queue_age_ms"), 0, 60000, &queueAge) ||
        !integer(provenance.value("packet_received_at_ms"), 1, SafeInteger, &packetUtc) ||
        compact(provenance).size() > 4096)
        return reject(QStringLiteral("Invalid host transport provenance"), error);
    const auto utc = QDateTime::currentMSecsSinceEpoch(), tick = d->clock.elapsed();
    observeClock(d->state, utc, tick);
    auto candidate = d->state;
    QString reason;
    if (!accept(candidate, observation, utc, tick, allowMock, &reason)) return reject(reason, error);
    for (auto it = candidate.items.begin(); it != candidate.items.end(); ++it)
        if (it->revision == candidate.revision) {
            it->transport = provenance;
            it->receivedUtc = packetUtc;
            it->receivedTick -= queueAge;
            if (it->knownClock) it->producerAge = qMax<qint64>(0, it->producerAge - queueAge);
            else it->deadline -= queueAge;
        }
    if (compact(project(candidate, utc, tick, true)).size() > RetainedViewBudget)
        while (compact(project(candidate, utc, tick, true)).size() > RetainedViewBudget && reclaimRetiredTransport(candidate)) {}
    if (compact(project(candidate, utc, tick, true)).size() > RetainedViewBudget)
        return reject(QStringLiteral("Transport provenance exceeds the complete local view budget"), error);
    d->state = std::move(candidate);
    scheduleExpiry();
    emit changed();
    return true;
}
void TerminalDataBus::retireTransport(const QString &activationId) {
    if (QThread::currentThread() != thread() || activationId.isEmpty()) return;
    bool retired = false;
    for (auto it = d->state.items.begin(); it != d->state.items.end(); ++it)
        if (!it->retired && it->transport.value("adapter_kind") != "native_package" &&
            it->transport.value("activation_id") == activationId) {
            it->retired = true;
            retired = true;
        }
    if (!retired) return;
    d->state.retiredActivations.insert(activationId);
    scheduleExpiry();
    emit changed();
}
bool TerminalDataBus::registerPluginSource(const QVariantMap &binding, QString *error) {
    if (error) error->clear();
    if (QThread::currentThread() != thread())
        return fail(error, "Native source registration requires the bus owner thread");
    const auto activation = binding.value("activation_id").toString();
    const QUuid uuid(activation);
    const auto source = binding.value("source_id").toString();
    if (!contextValid(d->state.context) || binding.value("context").toMap() != d->state.context ||
        uuid.isNull() || uuid.toString(QUuid::WithoutBraces) != activation ||
        binding.value("session_id") != "plugin." + activation || source.isEmpty() ||
        source != TerminalPluginSourceIdentity::logicalSourceId(binding))
        return fail(error, "Native source registration does not match its logical identity and rules context");
    if (d->pluginActivations.contains(source))
        return fail(error, "An activation already owns this logical native source");
    if (d->pluginActivations.size() >= 16 || d->pluginActivations.values().contains(activation))
        return fail(error, "Native source activation limit or duplicate activation UUID");
    d->pluginActivations.insert(source, activation);
    return true;
}
bool TerminalDataBus::acceptPluginObservation(const QVariantMap &observation,
                                             const QVariantMap &provenance,
                                             bool allowMock, QString *error) {
    if (error) error->clear();
    if (QThread::currentThread() != thread())
        return fail(error, "Plugin observation must be dispatched to the bus owner thread");
    static const QSet<QString> required{"adapter_kind", "activation_id", "package_id", "package_version",
        "package_fingerprint", "configuration_fingerprint", "environment", "original_source_id", "original_sensor_id", "queue_age_ms",
        "packet_received_at_ms", "packet_received_tick_ms", "peer_authenticated"};
    static const QRegularExpression packageId("\\A[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*\\z");
    static const QRegularExpression version("\\A(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)(?:-[A-Za-z0-9.-]+)?(?:\\+[A-Za-z0-9.-]+)?\\z");
    static const QRegularExpression fingerprint("\\A[0-9a-fA-F]{64}\\z");
    const auto activation = provenance.value("activation_id").toString();
    const QUuid uuid(activation);
    qint64 queueAge = 0, packetUtc = 0;
    if (!keys(provenance, required) || provenance.value("adapter_kind") != "native_package" ||
        !text(provenance.value("activation_id"), 36) || uuid.isNull() ||
        uuid.toString(QUuid::WithoutBraces) != activation ||
        !text(provenance.value("package_id"), 64) ||
        !packageId.match(provenance.value("package_id").toString()).hasMatch() ||
        !text(provenance.value("package_version"), 96) ||
        !version.match(provenance.value("package_version").toString()).hasMatch() ||
        !text(provenance.value("package_fingerprint"), 64) ||
        !fingerprint.match(provenance.value("package_fingerprint").toString()).hasMatch() ||
        !text(provenance.value("configuration_fingerprint"), 64) ||
        !fingerprint.match(provenance.value("configuration_fingerprint").toString()).hasMatch() ||
        (provenance.value("environment") != "training" && provenance.value("environment") != "competition") ||
        !id(provenance.value("original_source_id")) ||
        !text(provenance.value("original_sensor_id"), 96, true) ||
        observation.value("sensor_id") != provenance.value("original_sensor_id") ||
        !integer(provenance.value("queue_age_ms"), 0, 60000, &queueAge) ||
        !integer(provenance.value("packet_received_at_ms"), 1, SafeInteger, &packetUtc) ||
        !integer(provenance.value("packet_received_tick_ms"), 0, SafeInteger) ||
        provenance.value("peer_authenticated").metaType().id() != QMetaType::Bool ||
        provenance.value("peer_authenticated").toBool() || compact(provenance).size() > 4096)
        return reject(QStringLiteral("Invalid host native-package source provenance"), error);
    const auto source = observation.value("source_id");
    auto identity = observation;
    for (const auto &key : {"package_id", "package_version", "package_fingerprint", "configuration_fingerprint",
                            "environment", "original_source_id", "original_sensor_id"}) identity[key] = provenance.value(key);
    const auto logicalSource = TerminalPluginSourceIdentity::logicalSourceId(identity);
    if (source.metaType().id() != QMetaType::QString ||
        logicalSource.isEmpty() || source.toString() != logicalSource ||
        observation.value("session_id") != "plugin." + activation)
        return reject(QStringLiteral("Native-package source ID must match its reviewed logical binding and fresh activation session"), error);
    if (d->state.retiredActivations.contains(activation))
        return reject(QStringLiteral("Retired native-package source activation cannot submit observations"), error);
    if (d->pluginActivations.value(logicalSource) != activation)
        return reject(QStringLiteral("Native-package observation does not belong to the current registered source activation"), error);
    const auto utc = QDateTime::currentMSecsSinceEpoch(), tick = d->clock.elapsed();
    observeClock(d->state, utc, tick);
    auto candidate = d->state;
    QString reason;
    const auto sourceKey = observation.value("team_id").toString() + QChar(0x1f) +
        observation.value("robot_key").toString() + QChar(0x1f) + logicalSource;
    for (const auto &retained : std::as_const(candidate.items))
        if (retained.sourceKey == sourceKey && !retained.retired &&
            retained.transport.value("activation_id") != activation)
            return reject(QStringLiteral("A different activation still owns this logical plugin source"), error);
    // Unlike ordinary producer sessions, these activations are retired by a
    // native owner whose closed lease rejects all late callbacks. Reclaim only
    // that existing bounded retired ledger when repeated reconnects fill it.
    while (candidate.sources.contains(sourceKey) &&
           candidate.sources.value(sourceKey).session != observation.value("session_id").toString() &&
           candidate.sources.value(sourceKey).sessions.size() >= MaximumSessions &&
           reclaimRetiredTransport(candidate)) {}
    // The common schema still rejects official/verified authority and unapproved
    // mock samples. Unverified spatial metadata never grants renderability.
    if (!accept(candidate, observation, utc, tick, allowMock, &reason)) return reject(reason, error);
    for (auto it = candidate.items.begin(); it != candidate.items.end(); ++it)
        if (it->revision == candidate.revision) {
            it->transport = provenance;
            it->receivedUtc = packetUtc;
            it->receivedTick -= queueAge;
            // Host UTC already consumes producer age. Other clock domains must
            // consume the measured callback queue age without renewing the TTL.
            if (it->knownClock) {
                it->producerAge = qMax<qint64>(0, it->producerAge - queueAge);
                it->deadline = qMin(it->deadline, tick + observation.value("ttl_ms").toLongLong() - queueAge);
            } else it->deadline -= queueAge;
        }
    while (compact(project(candidate, utc, tick, true)).size() > RetainedViewBudget &&
           reclaimRetiredTransport(candidate)) {}
    if (compact(project(candidate, utc, tick, true)).size() > RetainedViewBudget)
        return reject(QStringLiteral("Native-package provenance exceeds the complete local view budget"), error);
    d->state = std::move(candidate);
    scheduleExpiry();
    emit changed();
    return true;
}
void TerminalDataBus::retirePluginSource(const QString &activationId) {
    if (QThread::currentThread() != thread() || activationId.isEmpty()) return;
    for (auto it = d->pluginActivations.begin(); it != d->pluginActivations.end();)
        if (it.value() == activationId) it = d->pluginActivations.erase(it); else ++it;
    bool retired = false;
    for (auto it = d->state.items.begin(); it != d->state.items.end(); ++it)
        if (!it->retired && it->transport.value("adapter_kind") == "native_package" &&
            it->transport.value("activation_id") == activationId) {
            it->retired = true;
            retired = true;
        }
    if (!retired) return;
    d->state.retiredActivations.insert(activationId);
    scheduleExpiry();
    emit changed();
}
void TerminalDataBus::scheduleExpiry() {
    const auto now = d->clock.elapsed();
    const bool active = std::any_of(d->state.items.cbegin(), d->state.items.cend(), [now](const Item &item) {
        return !item.retired && item.observation.value("lifecycle") == "active" && item.deadline > now;
    });
    if (active && !d->timer.isActive()) d->timer.start();
    else if (!active) d->timer.stop();
}
void TerminalDataBus::updateAges() {
    observeClock(d->state, QDateTime::currentMSecsSinceEpoch(), d->clock.elapsed());
    scheduleExpiry();
    emit changed();
}
bool TerminalDataBus::seedMock(QString *error) {
    if (error) error->clear();
    if (QThread::currentThread() != thread())
        return fail(error, "Mock demonstration must be seeded on the bus owner thread");
    if (!contextValid(d->state.context) || d->state.context.value("profile_id") != "rmuc2027-regional-v1.0.0")
        return reject(QStringLiteral("This explicit demonstration requires the selected 2027 regional V1.0.0 context"), error);
    const auto utc = QDateTime::currentMSecsSinceEpoch(), tick = d->clock.elapsed();
    observeClock(d->state, utc, tick);
    auto candidate = d->state;
    if (candidate.mockSession.isEmpty()) candidate.mockSession = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const auto sample = [&](const QString &item, const QString &sensor, const QString &type,
                            const QVariant &value) -> QVariantMap {
        return {{"schema", 3}, {"context", candidate.context}, {"team_id", "local-demo"},
            {"robot_key", "red/heavy/1"}, {"source_id", "mock.terminal.demo"}, {"sensor_id", sensor},
            {"source_kind", "mock"}, {"session_id", candidate.mockSession}, {"sequence", ++candidate.mockSequence},
            {"item_id", item}, {"produced_at_ms", utc}, {"clock_domain", "host_utc"}, {"ttl_ms", 30000},
            {"confidence", QVariant{}}, {"validation", "mock"}, {"lifecycle", "active"},
            {"data_type", type}, {"value", value}};
    };
    const auto heavy = sample("heavy-lock-sensor", "mock-heavy-lock-switch", "boolean", false);
    auto vision = sample("vision-unverified-event", "mock-vision-detector", "event",
        QVariantMap{{"summary", "离线模拟：发现待核实目标；坐标未标定，仅文本。"}, {"x", 17.2}, {"y", 6.4}});
    vision.insert("unit", "m"); vision.insert("frame_id", "rm2027.field");
    vision.insert("frame_revision", "mock-unverified-1"); vision.insert("transform_id", "unverified");
    const auto logistics = sample("derived-logistics-reference", "mock-manual-reference", "object",
        QVariantMap{{"summary", "离线手动规则参考：假设基地5000HP，λ=0.75；不是实际比赛数据。"},
            {"calculation_mode", "manual_reference"}, {"lambda", 0.75}, {"respawn_time_factor", 4.0 / 3.0},
            {"video_pixel_area_factor", 0.5625}});
    QString reason;
    for (const auto &observation : {heavy, vision, logistics})
        if (!accept(candidate, observation, utc, tick, true, &reason)) return reject(reason, error);
    d->state = std::move(candidate);
    scheduleExpiry();
    emit changed();
    return true;
}
