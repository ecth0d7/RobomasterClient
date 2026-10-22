#include "TerminalPluginSourceHost.h"
#include "PacketObservation.h"
#include "SeasonConfiguration.h"
#include "TerminalDataBus.h"
#include "TerminalObservationSource.h"
#include "TerminalPluginSourceIdentity.h"

#include <QDateTime>
#include <QJsonDocument>
#include <QMap>
#include <QPointer>
#include <QRegularExpression>
#include <QSet>
#include <QThread>
#include <QUuid>
#include <cmath>

namespace {
constexpr qsizetype MaximumSampleBytes = 4096;
constexpr int MaximumLeases = 16;

bool exact(const QVariantMap &map, const QSet<QString> &required,
           const QSet<QString> &optional = {}) {
    for (const auto &key : required) if (!map.contains(key)) return false;
    for (auto it = map.cbegin(); it != map.cend(); ++it)
        if (!required.contains(it.key()) && !optional.contains(it.key())) return false;
    return true;
}
bool text(const QVariant &value, qsizetype maximum, bool empty = false) {
    if (value.metaType().id() != QMetaType::QString) return false;
    const auto s = value.toString();
    if ((!empty && s.isEmpty()) || s.size() > maximum) return false;
    for (const auto c : s) if (c.isNull() || c.category() == QChar::Other_Control) return false;
    return true;
}
bool identifier(const QVariant &value, qsizetype maximum = 96) {
    if (!text(value, maximum)) return false;
    for (const auto c : value.toString()) {
        const auto u = c.unicode();
        if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') ||
              (u >= '0' && u <= '9') || u == '_' || u == '-' || u == '.' || u == ':' || u == '/'))
            return false;
    }
    return true;
}
bool integer(const QVariant &value, qint64 minimum, qint64 maximum, qint64 *result = nullptr) {
    switch (value.metaType().id()) {
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double: case QMetaType::Float: break;
    default: return false;
    }
    const auto n = value.toDouble();
    if (!std::isfinite(n) || std::floor(n) != n || n < double(minimum) || n > double(maximum)) return false;
    if (result) *result = qint64(n);
    return true;
}
bool fingerprint(const QVariant &value) {
    if (!text(value, 64) || value.toString().size() != 64) return false;
    for (const auto c : value.toString())
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return false;
    return true;
}
bool activeOwner(const QObject *owner) {
    if (!owner) return false;
    const auto value = owner->property("active");
    return value.metaType().id() == QMetaType::Bool && value.toBool();
}
bool primitive(const QVariant &value, int depth, int &nodes, qsizetype &cost) {
    if (depth > 6 || ++nodes > 512 || cost > MaximumSampleBytes) return false;
    const auto type = value.metaType().id();
    if (!value.isValid() || type == QMetaType::Nullptr) cost += 4;
    else if (type == QMetaType::QVariantMap) {
        const auto map = value.toMap();
        if (map.size() > 64) return false;
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            if (!text(it.key(), 96)) return false;
            cost += it.key().size() + 4;
            if (!primitive(it.value(), depth + 1, nodes, cost)) return false;
        }
    } else if (type == QMetaType::QVariantList) {
        const auto list = value.toList();
        if (list.size() > 128) return false;
        for (const auto &entry : list) if (!primitive(entry, depth + 1, nodes, cost)) return false;
    } else if (type == QMetaType::QString) {
        if (!text(value, MaximumSampleBytes, true)) return false;
        cost += value.toString().size() + 2;
    } else if (type == QMetaType::Bool) cost += 5;
    else {
        switch (type) {
        case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
        case QMetaType::ULongLong: case QMetaType::Double: case QMetaType::Float: break;
        default: return false;
        }
        const auto n = value.toDouble();
        if (!std::isfinite(n) || std::abs(n) > double(PacketObservation::SafeInteger)) return false;
        cost += 16;
    }
    return cost <= MaximumSampleBytes;
}
QVariantMap rulesContext(const SeasonConfiguration *season) {
    if (!season) return {};
    const auto selected = season->current();
    return {{"profile_id", season->profileId()}, {"field_profile_id", selected.value("field_profile_id")},
            {"capability_revision", selected.value("capability_revision")}};
}
bool semanticRobot(const QString &value, const QVariantList &roster) {
    const auto parts = value.split('/');
    if (parts.size() != 3 || (parts[0] != "red" && parts[0] != "blue") ||
        parts[2].isEmpty() || parts[2].size() > 3 || parts[2][0] < '1' || parts[2][0] > '9') return false;
    for (const auto c : parts[2]) if (c < '0' || c > '9') return false;
    bool ok = false;
    const auto slot = parts[2].toInt(&ok);
    if (!ok) return false;
    for (const auto &entry : roster) {
        const auto role = entry.toMap();
        if (role.value("role_id") == parts[1]) return slot >= 1 && slot <= role.value("count").toInt();
    }
    return false;
}
}

class TerminalPluginSourceLease final : public QObject, public TerminalObservationSource {
    Q_OBJECT
    Q_INTERFACES(TerminalObservationSource)
public:
    TerminalPluginSourceLease(TerminalPluginSourceHost *host, QObject *owner, QVariantMap binding)
        : QObject(owner), m_host(host), m_owner(owner), m_binding(std::move(binding)) {
        connect(owner, SIGNAL(activeChanged()), this, SLOT(ownerStateChanged()));
        connect(owner, &QObject::destroyed, this, [this] { close(); });
    }
    ~TerminalPluginSourceLease() override { close(); }
    QVariantMap descriptor() const override { return m_binding; }
    bool submit(const QVariantMap &sample, const PacketObservation::Stamp &stamp, QString *error) override {
        if (error) error->clear();
        if (QThread::currentThread() != thread()) {
            if (error) *error = QStringLiteral("Observation submissions must run on the source owner thread");
            return false;
        }
        const auto host = m_host;
        if (m_closed || !host) {
            if (error) *error = QStringLiteral("Observation source activation is retired");
            return false;
        }
        return host->submit(this, sample, stamp, error);
    }
    void close() noexcept override {
        // The ABI requires owner-thread calls, including close/stop. A worker
        // never touches host state; its queued callbacks must use a QPointer.
        if (QThread::currentThread() != thread() || m_closed) return;
        const auto host = m_host;
        if (host) host->retire(this);
        else m_closed = true;
    }
private slots:
    void ownerStateChanged() {
        if (!activeOwner(m_owner)) close();
    }
private:
    friend class TerminalPluginSourceHost;
    QPointer<TerminalPluginSourceHost> m_host;
    QPointer<QObject> m_owner;
    QVariantMap m_binding;
    bool m_closed = false;
};

struct TerminalPluginSourceHost::Private {
    QPointer<SeasonConfiguration> season;
    QPointer<TerminalDataBus> bus;
    QMap<QString, QPointer<TerminalPluginSourceLease>> leases;
    QString status = QStringLiteral("未注册原生插件数据源；没有自动连接传感器或视觉设备");
    qint64 accepted = 0, rejected = 0;
    bool destroying = false;
};

TerminalPluginSourceHost::TerminalPluginSourceHost(SeasonConfiguration *season, TerminalDataBus *bus, QObject *parent)
    : QObject(parent), d(std::make_unique<Private>()) {
    d->season = season; d->bus = bus;
    if (season) {
        connect(season, &SeasonConfiguration::aboutToChange, this, [this] { retireAll(); });
        connect(season, &QObject::destroyed, this, [this] { retireAll(); });
    }
    if (bus) connect(bus, &QObject::destroyed, this, [this] { retireAll(); });
}
TerminalPluginSourceHost::~TerminalPluginSourceHost() {
    d->destroying = true;
    if (d->season) disconnect(d->season, nullptr, this, nullptr);
    if (d->bus) disconnect(d->bus, nullptr, this, nullptr);
    retireAll();
}
QString TerminalPluginSourceHost::status() const { return d->status; }
QVariantList TerminalPluginSourceHost::sources() const {
    QVariantList result;
    for (const auto &lease : d->leases) {
        if (!lease) continue;
        auto row = lease->m_binding;
        row["active"] = !lease->m_closed;
        row["state"] = lease->m_closed ? "retired" : "registered";
        // The host knows registration and ingress timing, not whether a
        // vendor's adapter actually reached its physical device.
        row["device_connection_verified"] = false;
        row["device_status"] = "not_verified_by_host";
        result.append(row);
    }
    return result;
}
QVariantMap TerminalPluginSourceHost::diagnostics() const {
    int live = 0, active = 0;
    for (const auto &lease : d->leases) if (lease) { ++live; if (!lease->m_closed) ++active; }
    return {{"registered_sources", active}, {"live_leases", live}, {"lease_limit", MaximumLeases},
            {"accepted", d->accepted}, {"rejected", d->rejected},
            {"official_authority_available", false}, {"device_connections_verified", false},
            {"automatic_actions_allowed", false}};
}
bool TerminalPluginSourceHost::reject(const QString &reason, QString *error) {
    if (error) *error = reason;
    d->rejected = qMin(PacketObservation::SafeInteger, d->rejected + 1);
    d->status = reason;
    emit changed();
    return false;
}
QObject *TerminalPluginSourceHost::createSource(QObject *owner, const QVariantMap &package,
                                               const QVariantMap &scope, const QVariantMap &descriptor,
                                               QString *error) {
    if (error) error->clear();
    if (QThread::currentThread() != thread()) {
        if (error) *error = QStringLiteral("Source registration must run on the host owner thread");
        return nullptr;
    }
    auto invalid = [&](const QString &reason) -> QObject * { reject(reason, error); return nullptr; };
    if (d->destroying || !d->season || !d->bus || !owner || owner->thread() != thread() ||
        !activeOwner(owner))
        return invalid(QStringLiteral("Active native package context and source host are required"));
    if (!d->season->editable()) return invalid(d->season->lockReason());
    static const QSet<QString> ScopeKeys{"profile_id", "field_profile_id", "capability_revision", "environment",
                                        "team_id", "robot_key", "endpoint_host", "endpoint_port"};
    if (!exact(scope, ScopeKeys)) return invalid(QStringLiteral("Invalid immutable native package scope"));
    for (auto it = scope.cbegin(); it != scope.cend(); ++it)
        if (!text(it.value(), 128)) return invalid(QStringLiteral("Invalid native package scope value"));
    const auto context = rulesContext(d->season);
    for (auto it = context.cbegin(); it != context.cend(); ++it)
        if (scope.value(it.key()) != it.value()) return invalid(QStringLiteral("Package rules context is no longer current"));
    if (scope.value("environment") != d->season->environment())
        return invalid(QStringLiteral("Package environment is no longer current"));
    static const QRegularExpression packageId("\\A[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*\\z");
    static const QRegularExpression version("\\A(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)(?:-[A-Za-z0-9.-]+)?(?:\\+[A-Za-z0-9.-]+)?\\z");
    if (!exact(package, {"id", "version", "fingerprint", "configuration"}) ||
        !text(package.value("id"), 64) || !packageId.match(package.value("id").toString()).hasMatch() ||
        !text(package.value("version"), 96) || !version.match(package.value("version").toString()).hasMatch() ||
        !fingerprint(package.value("fingerprint")) ||
        package.value("configuration").metaType().id() != QMetaType::QVariantMap)
        return invalid(QStringLiteral("Reviewed package identity and configuration are required"));
    const auto values = package.value("configuration").toMap();
    const auto configurationFingerprint = TerminalPluginSourceIdentity::configurationFingerprint(values);
    if (configurationFingerprint.isEmpty())
        return invalid(QStringLiteral("Reviewed source configuration exceeds its bounded JSON contract"));
    const auto team = values.value("team_id"), robot = values.value("robot_key");
    if (!identifier(team) || team == "unselected" || !text(robot, 64) ||
        !semanticRobot(robot.toString(), d->season->current().value("roster").toList()))
        return invalid(QStringLiteral("Save explicit team_id and semantic robot_key in the package configuration before registration"));
    if ((scope.value("team_id") != "unselected" && scope.value("team_id") != team) ||
        (scope.value("robot_key") != "unselected" && scope.value("robot_key") != robot))
        return invalid(QStringLiteral("Configured source identity differs from the selected native package scope"));
    if (!exact(descriptor, {"source_id", "sensor_id", "source_kind", "clock_domain"}) ||
        !identifier(descriptor.value("source_id")) || !text(descriptor.value("sensor_id"), 96, true) ||
        !text(descriptor.value("source_kind"), 32) || !text(descriptor.value("clock_domain"), 32))
        return invalid(QStringLiteral("Source descriptor accepts only source_id, sensor_id, source_kind and clock_domain"));
    const auto kind = descriptor.value("source_kind").toString();
    if (!QSet<QString>{"local_sensor", "local_vision", "derived", "mock"}.contains(kind) ||
        ((kind == "local_sensor" || kind == "local_vision") && descriptor.value("sensor_id").toString().isEmpty()) ||
        (kind == "mock" && d->season->environment() != "training") ||
        (descriptor.value("clock_domain") != "host_utc" && descriptor.value("clock_domain") != "remote_unverified"))
        return invalid(QStringLiteral("Source kind, sensor and clock binding are not supported; mock is training-only"));
    for (auto it = d->leases.begin(); it != d->leases.end();)
        if (!it.value()) it = d->leases.erase(it); else ++it;
    if (d->leases.size() >= MaximumLeases)
        return invalid(QStringLiteral("Native source limit is 16 live leases; release retired source objects before adding more"));

    const auto activation = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QVariantMap binding{{"context", context}, {"environment", d->season->environment()}, {"team_id", team}, {"robot_key", robot},
        {"sensor_id", descriptor.value("sensor_id")}, {"source_kind", kind},
        {"clock_domain", descriptor.value("clock_domain")}, {"session_id", "plugin." + activation},
        {"ingress_session", activation}, {"activation_id", activation},
        {"original_source_id", descriptor.value("source_id")}, {"original_sensor_id", descriptor.value("sensor_id")},
        {"package_id", package.value("id")}, {"package_version", package.value("version")},
        {"package_fingerprint", package.value("fingerprint")},
        {"configuration_fingerprint", configurationFingerprint},
        {"validation", kind == "mock" ? "mock" : kind == "derived" ? "derived" : "unverified"},
        {"authoritative", false}, {"peer_authenticated", false}};
    const auto source = TerminalPluginSourceIdentity::logicalSourceId(binding);
    if (source.isEmpty()) return invalid(QStringLiteral("Native source logical identity could not be formed"));
    for (const auto &existing : d->leases)
        if (existing && !existing->m_closed && existing->m_binding.value("source_id") == source)
            return invalid(QStringLiteral("An identical logical source lease is already active; close it before reconnecting"));
    binding.insert("source_id", source);
    QString admissionError;
    if (!d->bus->registerPluginSource(binding, &admissionError)) return invalid(admissionError);
    auto *lease = new TerminalPluginSourceLease(this, owner, std::move(binding));
    const QPointer<TerminalPluginSourceLease> result(lease);
    d->leases.insert(activation, lease);
    connect(lease, &QObject::destroyed, this, [this, activation] {
        d->leases.remove(activation);
        if (!d->destroying) emit changed();
    });
    d->status = QStringLiteral("原生插件数据源已注册；设备真实性、时钟和坐标仍按各自证据验证");
    emit changed();
    return result.data();
}
bool TerminalPluginSourceHost::submit(TerminalPluginSourceLease *lease, const QVariantMap &sample,
                                     const PacketObservation::Stamp &stamp, QString *error) {
    if (error) error->clear();
    if (!lease || QThread::currentThread() != thread()) {
        if (error) *error = QStringLiteral("Native source submission requires the owning thread");
        return false;
    }
    if (d->destroying || !d->season || !d->bus || lease->m_closed || !lease->m_owner ||
        !activeOwner(lease->m_owner) ||
        d->leases.value(lease->m_binding.value("activation_id").toString()) != lease)
        return reject(QStringLiteral("Native source activation is no longer active"), error);
    if (lease->m_binding.value("context").toMap() != rulesContext(d->season) ||
        lease->m_binding.value("environment") != d->season->environment()) {
        QPointer<TerminalPluginSourceHost> alive(this);
        retire(lease);
        if (!alive) { if (error) *error = QStringLiteral("Source host retired during scope change"); return false; }
        return reject(QStringLiteral("Native source context or environment has changed"), error);
    }
    static const QSet<QString> SampleKeys{"item_id", "sequence", "produced_at_ms", "ttl_ms", "confidence",
                                         "lifecycle", "data_type", "value"};
    int nodes = 0; qsizetype cost = 0;
    if (!exact(sample, SampleKeys, {"unit", "frame_id", "frame_revision", "transform_id"}) ||
        !primitive(sample, 0, nodes, cost) ||
        QJsonDocument::fromVariant(sample).toJson(QJsonDocument::Compact).size() > MaximumSampleBytes)
        return reject(QStringLiteral("Source sample must be an exact bounded primitive schema3 payload of at most 4 KiB"), error);
    qint64 sequence = 0, ttl = 0;
    if (!integer(sample.value("sequence"), 1, PacketObservation::SafeInteger, &sequence) ||
        !integer(sample.value("ttl_ms"), 100, 60000, &ttl) || stamp.basis != "native_callback" ||
        stamp.session != lease->m_binding.value("ingress_session") || stamp.sequence != sequence)
        return reject(QStringLiteral("Native callback timing must match this source activation and sample sequence"), error);
    qint64 queueAge = 0;
    QString reason;
    if (!PacketObservation::validateAt(stamp, QDateTime::currentMSecsSinceEpoch(),
                                      PacketObservation::steadyMilliseconds(), &queueAge, &reason))
        return reject(reason, error);
    if (sample.value("lifecycle") == "active" && queueAge >= ttl)
        return reject(QStringLiteral("Source observation expired while waiting in the native callback queue"), error);
    const auto &binding = lease->m_binding;
    QVariantMap observation = sample;
    observation["schema"] = 3;
    for (const auto &key : {"context", "team_id", "robot_key", "source_id", "sensor_id", "source_kind",
                            "session_id", "clock_domain", "validation"}) observation[key] = binding.value(key);
    const bool mock = binding.value("source_kind") == "mock";
    if (!TerminalDataBus::validateObservation(observation, binding.value("context").toMap(), mock, &reason))
        return reject(reason, error);
    const QVariantMap provenance{{"adapter_kind", "native_package"}, {"activation_id", binding.value("activation_id")},
        {"package_id", binding.value("package_id")}, {"package_version", binding.value("package_version")},
        {"package_fingerprint", binding.value("package_fingerprint")},
        {"configuration_fingerprint", binding.value("configuration_fingerprint")},
        {"environment", binding.value("environment")},
        {"original_source_id", binding.value("original_source_id")}, {"original_sensor_id", binding.value("original_sensor_id")},
        {"queue_age_ms", queueAge}, {"packet_received_at_ms", stamp.receivedUtc},
        {"packet_received_tick_ms", stamp.receivedTick}, {"peer_authenticated", false}};
    QPointer<TerminalPluginSourceHost> alive(this);
    const auto bus = d->bus;
    const bool accepted = bus->acceptPluginObservation(observation, provenance, mock, &reason);
    if (!alive) { if (error) *error = accepted ? QString{} : reason; return accepted; }
    if (!accepted) return reject(reason, error);
    d->accepted = qMin(PacketObservation::SafeInteger, d->accepted + 1);
    d->status = QStringLiteral("已接纳插件来源观测；非官方权威数据，坐标与设备真实性未自动验证");
    emit changed();
    return true;
}
void TerminalPluginSourceHost::retire(TerminalPluginSourceLease *lease) noexcept {
    if (!lease || lease->m_closed || QThread::currentThread() != thread()) return;
    const auto activation = lease->m_binding.value("activation_id").toString();
    lease->m_closed = true;
    lease->m_host.clear();
    QPointer<TerminalPluginSourceHost> alive(this);
    if (d->bus) d->bus->retirePluginSource(activation);
    if (!alive || d->destroying) return;
    d->status = QStringLiteral("插件来源已退役；旧回调不能恢复或延长数据生命周期");
    emit changed();
}
void TerminalPluginSourceHost::retireAll() noexcept {
    const auto leases = d->leases;
    QPointer<TerminalPluginSourceHost> alive(this);
    for (const auto &lease : leases) {
        if (lease) retire(lease);
        if (!alive) return;
    }
}

#include "TerminalPluginSourceHost.moc"
