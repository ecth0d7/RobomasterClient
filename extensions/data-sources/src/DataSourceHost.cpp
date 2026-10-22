#include "DataSourceHost.h"
#include "ClientBackend.h"
#include "DecisionConfiguration.h"
#include "RobotIdentity.h"
#include "TeamSourceExport.h"
#include <QDateTime>
#include <QUuid>
#include <chrono>

namespace {
qint64 tickNow() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}
bool fail(QString *error, const QString &message) {
    if (error) *error = message;
    return false;
}
QVariantList uses() {
    return {QStringLiteral("hud"), QStringLiteral("alerts"), QStringLiteral("localAi"),
            QStringLiteral("externalAi"), QStringLiteral("voice")};
}
QVariantMap observationIdentity(const QVariantMap &observations) {
    QVariantMap result;
    for (auto group = observations.cbegin(); group != observations.cend(); ++group) {
        QVariantMap fields;
        const auto entries = group.value().toMap();
        for (auto field = entries.cbegin(); field != entries.cend(); ++field) {
            const auto item = field.value().toMap();
            fields[field.key()] = QVariantMap{
                {"revision", item.value("observation_revision")},
                {"session", item.value("observation_session_id")},
                {"received_at_ms", item.value("received_at_ms")}};
        }
        result[group.key()] = fields;
    }
    return result;
}
}
struct DataSourceHost::Source {
    std::unique_ptr<ServiceEndpoint> endpoint;
    QVariantMap descriptor;
    quint64 generation = 0, revision = 0;
    QString error;
};

DataSourceHost::DataSourceHost(ClientBackend *backend, QObject *parent)
    : QObject(parent), m_backend(backend), m_state(backend ? backend->telemetry() : nullptr),
      m_robot(backend ? backend->clientId() : 0) {
    setStatus("waiting", QStringLiteral("来源登记已接通；先确认官方选手端来源与用途，设备适配器尚未接入"));
    if (backend) {
        connect(backend, &ClientBackend::identityChanged, this, [this] {
            QPointer<DataSourceHost> alive(this);
            ++m_authorizationRevision;
            synchronizeRobot();
            if (!alive) return;
            retireOfficial(); // A new official connection never reuses an old observation cut.
            emit changed();
        });
        connect(backend, &ClientBackend::connectionOptionsChanged, this, [this] {
            // This also notifies phase freshness. Endpoint scope is enforced by
            // DecisionConfiguration; no local source is tied to broker liveness.
            synchronizeRobot();
        });
        connect(backend, &ClientBackend::connectionChanged, this, [this] {
            ++m_authorizationRevision;
            if (m_backend && !m_backend->connected()) retireOfficial();
        });
        connect(backend, &QObject::destroyed, this, [this] {
            QPointer<DataSourceHost> alive(this);
            retireOfficial(); stopSources();
            if (!alive) return;
            setStatus("offline", QStringLiteral("客户端身份宿主已退出，来源已退役"));
            emit changed();
        });
    }
    m_timer.setInterval(100);
    connect(&m_timer, &QTimer::timeout, this, &DataSourceHost::refresh);
    m_timer.start();
}
DataSourceHost::~DataSourceHost() {
    blockSignals(true);
    m_timer.stop();
    stopSources();
}
void DataSourceHost::setDecisionConfiguration(DecisionConfiguration *configuration) {
    if (m_decision) m_decision->disconnect(this);
    m_decision = configuration;
    ++m_authorizationRevision;
    if (configuration) {
        connect(configuration, &DecisionConfiguration::currentChanged, this, [this] {
            ++m_authorizationRevision;
            retireOfficial();
            emit changed();
        });
        connect(configuration, &DecisionConfiguration::scopeChanged, this, [this] {
            ++m_authorizationRevision;
            retireOfficial();
            emit changed();
        });
    }
    retireOfficial();
}
void DataSourceHost::setPhaseGuard(QObject *phase) {
    if (m_phase) m_phase->disconnect(this);
    m_phase = phase;
    if (phase) connect(phase, SIGNAL(stateChanged()), this, SIGNAL(changed()));
    emit changed();
}
bool DataSourceHost::editable() const {
    return m_phase && m_phase->property("editable").metaType().id() == QMetaType::Bool
        && m_phase->property("editable").toBool();
}
QString DataSourceHost::lockReason() const {
    return !m_phase ? QStringLiteral("数据源阶段守卫未接通")
        : editable() ? QString{} : m_phase->property("lockReason").toString();
}
void DataSourceHost::setSharingConfiguration(const QVariantMap &configuration) {
    QVariantMap next;
    for (const auto &key : {"robot_id", "can_send", "category_permissions"})
        if (configuration.contains(QLatin1String(key))) next[QLatin1String(key)] = configuration.value(QLatin1String(key));
    if (next == m_share) return;
    m_share = next;
    if (m_share.isEmpty()) m_teamExportStatus = QStringLiteral("队伍导出未启用；本机视图独立");
    ++m_authorizationRevision;
    retireOfficial();
    emit changed();
}
void DataSourceHost::retireOfficial() {
    if (m_officialGeneration) m_registry.retire("official", m_officialGeneration);
    m_officialGeneration = 0;
    m_officialDescriptor.clear();
    m_officialSession.clear(); m_exportId.clear();
    m_official.reset(); // Item revision allocator deliberately survives reset.
}
void DataSourceHost::setRulesContext(const QVariantMap &context) {
    if (context == m_rulesContext) return;
    m_rulesContext = context;
    ++m_authorizationRevision;
    retireOfficial();
    QPointer<DataSourceHost> alive(this);
    stopSources();
    if (!alive) return;
    m_registry.clear();
    m_share.clear();
    setStatus("waiting", QStringLiteral("赛季／部署范围已更新，旧来源与共享授权已退役；实际设备需按新范围重新接入"));
    emit changed();
}
void DataSourceHost::synchronizeRobot() {
    const int robot = m_backend ? m_backend->clientId() : 0;
    if (robot == m_robot) return;
    m_robot = robot;
    ++m_authorizationRevision;
    retireOfficial();
    stopSources(); // A local camera cannot silently become another robot's camera.
}
void DataSourceHost::stopSources() {
    const auto current = m_sources;
    for (auto it = current.cbegin(); it != current.cend(); ++it) {
        ++m_sourceRevisions[it.key()];
        m_registry.retire(it.key(), it.value()->generation);
    }
    m_sources.clear();
    for (const auto &source : current) {
        source->endpoint->disconnect(this);
        source->endpoint->stop();
    }
}
void DataSourceHost::retireSource(const QString &id) {
    if (id == "official") return;
    ++m_sourceRevisions[id];
    const auto source = m_sources.take(id);
    if (!source) return;
    m_registry.retire(id, source->generation);
    source->endpoint->disconnect(this);
    QPointer<DataSourceHost> alive(this);
    source->endpoint->stop();
    if (alive) emit changed();
}
bool DataSourceHost::startSource(std::unique_ptr<ServiceEndpoint> endpoint,
                               const QVariantMap &descriptor, const QVariantMap &configuration,
                               QString *error) {
    if (!editable()) return fail(error, lockReason());
    const auto id = descriptor.value("source_id").toString();
    if (!endpoint || !m_backend || !RobotIdentity::valid(m_backend->clientId())
        || id == "official" || descriptor.value("source_kind") == "official_player_client"
        || descriptor.value("robot_id").toInt() != m_backend->clientId())
        return fail(error, QStringLiteral("本地来源端点／身份无效，不能冒充官方导出"));
    SourceRegistry descriptorCheck;
    if (!descriptorCheck.registerSource(descriptor, error)) return false;
    if (!m_sourceRevisions.contains(id) && m_sourceRevisions.size() >= 64)
        return fail(error, QStringLiteral("本进程来源标识已达64个，未丢弃旧代次记录"));
    QPointer<DataSourceHost> alive(this);
    QPointer<ClientBackend> backend = m_backend;
    QPointer<QObject> phase = m_phase;
    const auto robot = backend->clientId();
    const auto revision = m_sourceRevisions.value(id) + 1;
    retireSource(id);
    if (!alive || m_sourceRevisions.value(id) != revision) return false;
    const auto generation = m_registry.registerSource(descriptor, error);
    if (!generation) return false;
    auto source = std::make_shared<Source>();
    source->descriptor = descriptor; source->generation = generation; source->revision = revision;
    source->endpoint = std::move(endpoint);
    // Queue output so startup cannot deliver half-installed state or destroy an
    // endpoint while its start() is still on the stack. Each callback rechecks
    // the host generation after retirement/replacement.
    connect(source->endpoint.get(), &ServiceEndpoint::messageReceived, this,
        [this, id, revision, generation](const QVariantMap &message) {
            const auto current = m_sources.value(id);
            if (!current || current->revision != revision || current->generation != generation) return;
            QString error;
            if (!m_registry.accept(id, generation, message, QDateTime::currentMSecsSinceEpoch(), tickNow(), &error))
                current->error = error.left(240);
            else current->error.clear();
            emit changed();
        }, Qt::QueuedConnection);
    connect(source->endpoint.get(), &ServiceEndpoint::errorOccurred, this,
        [this, id, revision](const QString &error) {
            const auto current = m_sources.value(id);
            if (!current || current->revision != revision) return;
            current->error = error.left(240);
            // Error is not permission to renew or replace any observation.
            emit changed();
        }, Qt::QueuedConnection);
    connect(source->endpoint.get(), &ServiceEndpoint::statusChanged, this,
        [this, id, revision] {
            const auto current = m_sources.value(id);
            if (current && current->revision == revision) emit changed();
        }, Qt::QueuedConnection);
    const bool started = source->endpoint->start(configuration, error);
    if (!alive || m_sourceRevisions.value(id) != revision || !started
        || !backend || m_backend != backend || backend->clientId() != robot
        || m_phase != phase || !editable()) {
        if (error && error->isEmpty()) *error = QStringLiteral("来源启动期间身份、阶段或端点代次已改变");
        source->endpoint->disconnect(this);
        source->endpoint->stop();
        if (alive) m_registry.retire(id, generation);
        return false;
    }
    m_sources.insert(id, source);
    emit changed();
    return true;
}
void DataSourceHost::setStatus(const QString &health, const QString &status) {
    m_health = health; m_status = status;
}
void DataSourceHost::refresh() {
    QPointer<DataSourceHost> alive(this);
    synchronizeRobot();
    if (!alive) return;
    const auto authorizationRevision = m_authorizationRevision;
    const auto decision = m_decision;
    const auto decisionRevision = decision ? decision->revision() : 0;
    const auto policy = m_decision ? m_decision->current() : QVariantMap{};
    const auto policyScope = m_decision ? m_decision->state().value("scope").toMap() : QVariantMap{};
    const bool scopeMatches = m_backend && policyScope.value("robot_id").toInt() == m_robot
        && policyScope.value("host").toString() == m_backend->host().trimmed().toLower()
        && policyScope.value("port").toInt() == m_backend->port();
    QVariantMap categoryUses;
    const bool share = policy.value("shareEnabled").toBool() && m_share.value("can_send").toBool()
        && m_share.value("robot_id").toInt() == m_robot;
    for (const auto &category : {QStringLiteral("health"), QStringLiteral("resources"),
                                 QStringLiteral("position"), QStringLiteral("objective")}) {
        QVariantList allowed;
        if (policy.value("localAiFields").toStringList().contains(category)) allowed.append(QStringLiteral("localAi"));
        if (policy.value("externalAiFields").toStringList().contains(category)) allowed.append(QStringLiteral("externalAi"));
        if (share && policy.value("shareFields").toStringList().contains(category))
            for (const auto &use : m_share.value("category_permissions").toMap().value(category).toList())
                if (!allowed.contains(use)) allowed.append(use);
        if (!allowed.isEmpty()) categoryUses[category] = allowed;
    }
    if (!m_backend || !m_state || !m_backend->connected() || !RobotIdentity::valid(m_robot)
        || !scopeMatches || !policy.value("playerSourceConfirmed").toBool() || categoryUses.isEmpty()) {
        retireOfficial();
        setStatus("waiting", QStringLiteral("本机来源簿独立运行；官方快照等待连接、来源确认及明确用途，设备／视觉适配器尚未接入"));
        emit changed(); return;
    }
    const auto robot = m_robot;
    const auto host = m_backend->host(); const auto port = m_backend->port();
    const auto before = m_state->group("fieldObservations");
    if (!alive || !m_state) return;
    QVariantMap groups;
    for (const auto &group : {"robotDynamic", "robotStatic", "robotRespawn", "robotPosition", "globalLogistics",
                              "gameStatus", "techCore", "deployMode", "runeStatus", "sentryStatus", "airSupport"}) {
        groups[QLatin1String(group)] = m_state->group(QLatin1String(group));
        if (!alive || !m_state) return;
    }
    const auto fieldStates = m_state->group("fieldFreshness");
    if (!alive || !m_state) return;
    const auto after = m_state->group("fieldObservations");
    if (!alive || !m_backend || !m_backend->connected() || m_backend->clientId() != robot
        || m_backend->host() != host || m_backend->port() != port
        || m_authorizationRevision != authorizationRevision || m_decision != decision
        || !decision || decision->revision() != decisionRevision) return;
    if (observationIdentity(before) != observationIdentity(after)) return; // Retry a coherent cut next tick.
    if (m_officialSession.isEmpty()) {
        m_officialSession = QUuid::createUuid().toString(QUuid::WithoutBraces);
        m_exportId = QStringLiteral("player-export:") + m_officialSession;
    }
    QVariantMap descriptor{{"source_id", "official"}, {"session_id", m_officialSession}, {"robot_id", robot},
        {"source_kind", "official_player_client"}, {"adapter_id", "official.telemetry.v2"},
        {"sensor_id", ""}, {"producer_version", "2"}, {"allowed_uses", uses()},
        {"share_enabled", share}, {"clock_mapping_verified", true},
        {"measurement_validation", "operator_confirmed_endpoint"}, {"ttl_max_ms", 3500}, {"player_export_id", m_exportId}};
    QString error;
    if (m_officialGeneration && descriptor != m_officialDescriptor) {
        retireOfficial();
        // New disclosure must get a new host session, rather than mutating a
        // descriptor bound to an already-admitted generation.
        emit changed(); return;
    }
    if (!m_officialGeneration) {
        m_officialGeneration = m_registry.registerSource(descriptor, &error);
        if (m_officialGeneration) m_officialDescriptor = descriptor;
    }
    const auto utc = QDateTime::currentMSecsSinceEpoch(); const auto tick = tickNow();
    const auto snapshot = m_official.build({{"client_id", robot}, {"connected", true}, {"groups", groups},
        {"field_freshness", fieldStates}, {"field_observations", after}}, categoryUses, "official",
        m_officialSession, m_exportId, utc, tick, &error);
    if (!m_officialGeneration || snapshot.isEmpty()
        || !m_registry.accept("official", m_officialGeneration, snapshot, utc, tick, &error)) {
        retireOfficial();
        setStatus("rejected", QStringLiteral("官方快照未接纳：") + error.left(220));
    } else {
        setStatus("ready", QStringLiteral("官方选手端接收快照已登记；时间为本机接收，非官方产生时间／密码学认证；队伍AI与地图投影仍待接入"));
    }
    emit changed();
}
QVariantMap DataSourceHost::localView() const {
    auto result = m_registry.view(QDateTime::currentMSecsSinceEpoch(), tickNow());
    result["robot_id"] = m_robot;
    if (!m_rulesContext.isEmpty()) result["rules_context"] = m_rulesContext;
    return result;
}
QVariantMap DataSourceHost::teamSnapshot(QString *error) {
    const auto policy = m_decision ? m_decision->current() : QVariantMap{};
    const auto view = localView();
    const auto candidate = TeamSourceExport::build(view, m_share.value("category_permissions").toMap(),
        policy.value("shareFields").toStringList(), m_robot, policy.value("shareEnabled").toBool(),
        m_share.value("can_send").toBool() && m_share.value("robot_id").toInt() == m_robot, error);
    const auto result = candidate.isEmpty() ? QVariantMap{} : m_exportVersions.apply(candidate, view, error);
    m_teamExportStatus = result.isEmpty() ? QStringLiteral("完整共享快照被拒绝：") + (error ? error->left(180) : QString{})
        : result.value("items").toList().isEmpty() ? QStringLiteral("没有获准共享项；可提交空截面退役旧共享项")
        : QStringLiteral("获准子集已构造，提交／网络送达／队伍AI核验分别判断");
    return result;
}
void DataSourceHost::resetTeamExport() { m_exportVersions.reset(); }
QVariantList DataSourceHost::sources() const {
    const auto view = localView();
    QVariantList result;
    for (const auto &entry : view.value("sources").toList()) {
        auto source = entry.toMap();
        const auto id = source.value("source_id").toString();
        source["id"] = id;
        source["adapter_version"] = source.value("producer_version");
        source["item_type"] = QStringLiteral("逐项类型，非统一固定值");
        source["unit"] = QStringLiteral("逐项单位，未确认的不推断");
        source["verification"] = source.value("measurement_validation");
        source["projection"] = QStringLiteral("生产2D／UE投影未接通");
        source["uses"] = QStringLiteral("逐项用途交集；不自动触发机器人动作");
        if (m_sources.contains(id)) source["rejection"] = m_sources.value(id)->error;
        result.append(source);
    }
    return result;
}
QVariantMap DataSourceHost::capabilities() const {
    return {{"registry", true}, {"officialSnapshots", true}, {"inspectAdapter", false},
        {"activate", false}, {"deviceAdapters", false}, {"modelInput", false}, {"projection", false}};
}
