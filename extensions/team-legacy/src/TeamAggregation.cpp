#include "TeamAggregation.h"
#include "TeamDataContract.h"
#include "TeamNetwork.h"

#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMutex>
#include <QMutexLocker>
#include <QPointer>
#include <QSet>
#include <QThread>
#include <QTimer>
#include <QUuid>
#include <chrono>
#include <cmath>

namespace {
constexpr qsizetype SourceLimit = 16 * 1024;
constexpr qsizetype ViewLimit = 256 * 1024;
constexpr qint64 SafeInteger = 9007199254740991LL;
qint64 tickNow() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}
bool fail(QString *error, const QString &message) {
    if (error) *error = message;
    return false;
}
bool number(const QVariant &value, qint64 minimum, qint64 maximum, qint64 *out = nullptr) {
    const auto type = value.metaType().id();
    if (type != QMetaType::Int && type != QMetaType::UInt && type != QMetaType::LongLong
        && type != QMetaType::ULongLong && type != QMetaType::Double) return false;
    const auto n = value.toDouble();
    if (!std::isfinite(n) || std::floor(n) != n || n < minimum || n > maximum) return false;
    if (out) *out = qint64(n);
    return true;
}
bool keysOnly(const QVariantMap &map, const QSet<QString> &allowed) {
    for (auto it = map.cbegin(); it != map.cend(); ++it)
        if (!allowed.contains(it.key())) return false;
    return true;
}
bool boundedJson(const QVariant &value, int depth, qsizetype *cost, int *nodes, qsizetype maximum) {
    if (depth > 8 || ++*nodes > 32768 || *cost > maximum) return false;
    if (!value.isValid() || value.isNull()) { *cost += 4; return *cost <= maximum; }
    const auto type = value.metaType().id();
    if (type == QMetaType::QVariantMap) {
        const auto map = value.toMap();
        *cost += 2;
        if (map.size() > 512) return false;
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            if (it.key().size() > 128) return false;
            *cost += it.key().toUtf8().size() + 4;
            if (!boundedJson(it.value(), depth + 1, cost, nodes, maximum)) return false;
        }
    } else if (type == QMetaType::QVariantList || type == QMetaType::QStringList) {
        const auto list = value.toList();
        if (list.size() > 512) return false;
        *cost += 2;
        for (const auto &entry : list) {
            ++*cost;
            if (!boundedJson(entry, depth + 1, cost, nodes, maximum)) return false;
        }
    } else if (type == QMetaType::QString) {
        if (value.toString().size() > maximum) return false;
        *cost += value.toString().toUtf8().size() + 2;
    } else if (type == QMetaType::Bool) *cost += 5;
    else {
        if (type == QMetaType::Double || type == QMetaType::Float) {
            const auto n = value.toDouble();
            if (!std::isfinite(n) || std::abs(n) > double(SafeInteger)) return false;
        } else if (!number(value, -SafeInteger, SafeInteger)) return false;
        *cost += 24;
    }
    return *cost <= maximum;
}
bool boundedMap(const QVariantMap &map, qsizetype maximum) {
    qsizetype cost = 0; int nodes = 0;
    return boundedJson(map, 0, &cost, &nodes, maximum)
        && QJsonDocument(QJsonObject::fromVariantMap(map)).toJson(QJsonDocument::Compact).size() <= maximum;
}
bool stringList(const QVariant &value, const QSet<QString> &allowed, QStringList *out) {
    if (value.metaType().id() != QMetaType::QVariantList && value.metaType().id() != QMetaType::QStringList) return false;
    QStringList result;
    for (const auto &entry : value.toList()) {
        if (entry.metaType().id() != QMetaType::QString || !allowed.contains(entry.toString())
            || result.contains(entry.toString())) return false;
        result.append(entry.toString());
    }
    *out = result;
    return true;
}
QVariantMap storeConfiguration(const QVariantMap &configuration) {
    QVariantMap result;
    for (const auto &key : {"team_id", "match_id", "epoch", "node_id", "publisher_id", "robot_id",
                            "can_send", "can_aggregate", "max_clock_skew_ms", "clocks_synchronized", "timeout_ms"})
        if (configuration.contains(QLatin1String(key))) result[QLatin1String(key)] = configuration.value(QLatin1String(key));
    QVariantList peers;
    for (const auto &value : configuration.value("peers").toList()) {
        const auto peer = value.toMap();
        peers.append(QVariantMap{{"node_id", peer.value("node_id")}, {"robot_id", peer.value("robot_id")},
            {"can_send", peer.value("can_send", false)}, {"can_aggregate", peer.value("can_aggregate", false)}});
    }
    result["peers"] = peers;
    return result;
}
QVariantMap networkConfiguration(const QVariantMap &configuration, const QString &session) {
    auto result = configuration;
    for (const auto &key : {"publisher_id", "max_clock_skew_ms", "clocks_synchronized", "team_wide_sharing_confirmed",
                            "allowed_categories", "allowed_uses", "category_permissions", "configuration_revision", "publish_interval_ms"})
        result.remove(QLatin1String(key));
    result["session_id"] = session;
    return result;
}
struct Mailbox {
    QMutex mutex;
    QVariantMap details, view;
    QString status;
    int submissions = 0;
    qint64 viewUtc = 0, viewTick = 0;
    bool pending = false, viewChanged = false;
};
} // namespace

// Parsing certificates, verifying up to sixteen origin proofs and signing a
// complete cut happen on this dedicated thread, never on the QML render path.
class TeamAggregationWorker final : public QObject {
    Q_OBJECT
public:
    TeamAggregationWorker(QVariantMap configuration, std::shared_ptr<Mailbox> mailbox)
        : m_configuration(std::move(configuration)), m_mailbox(std::move(mailbox)) {}
    void begin() {
        m_network = std::make_unique<TeamNetwork>();
        connect(m_network.get(), &TeamNetwork::messageReceived, this, &TeamAggregationWorker::receive);
        connect(m_network.get(), &TeamNetwork::statusChanged, this, [this] { publishStatus(); });
        QString error;
        if (!m_store.configure(storeConfiguration(m_configuration), &error)) { reject(error); return; }
        m_session = QUuid::createUuid().toString(QUuid::WithoutBraces);
        m_started = QDateTime::currentMSecsSinceEpoch();
        m_node = m_configuration.value("node_id").toString();
        m_publisher = m_configuration.value("publisher_id").toString();
        m_revision = quint64(m_started);
        if (!m_network->start(networkConfiguration(m_configuration, m_session), &error)) { reject(error); return; }
        m_running = true;
        m_timer = new QTimer(this);
        m_timer->setInterval(100);
        connect(m_timer, &QTimer::timeout, this, &TeamAggregationWorker::advance);
        m_timer->start();
        publishStatus();
    }
    void shutdown() {
        m_running = false;
        if (m_timer) m_timer->stop();
        if (m_network) {
            m_network->disconnect(this);
            m_network->stop(); // Joins MQTT callbacks before worker event loop ends.
            m_network.reset();
        }
        m_store.clear();
    }
    void submitLocal(const QVariantMap &message) {
        {
            QMutexLocker lock(&m_mailbox->mutex);
            --m_mailbox->submissions;
        }
        if (!m_running || !m_configuration.value("can_send").toBool()) {
            rejectSubmission(QStringLiteral("本节点未获共享发送权限")); return;
        }
        const auto snapshotId = message.value("snapshot_id").toString();
        const auto items = message.value("items").toList();
        const auto categories = m_configuration.value("allowed_categories").toStringList();
        const auto permissionMatrix = m_configuration.value("category_permissions").toMap();
        for (const auto &value : items) {
            const auto item = value.toMap();
            if (value.metaType().id() != QMetaType::QVariantMap || !categories.contains(item.value("category").toString())) {
                rejectSubmission(QStringLiteral("来源类别未经本节点共享授权")); return;
            }
            QStringList uses;
            if (!stringList(item.value("allowed_uses"), {"hud", "alerts", "localAi", "externalAi", "voice"}, &uses)) {
                rejectSubmission(QStringLiteral("来源用途格式不合法")); return;
            }
            const auto purposes = permissionMatrix.value(item.value("category").toString()).toStringList();
            for (const auto &use : uses) if (!purposes.contains(use)) {
                rejectSubmission(QStringLiteral("来源包含未经允许的队伍用途")); return;
            }
        }
        auto body = common("node-snapshot");
        body["snapshot_id"] = snapshotId;
        body["items"] = items;
        QString error;
        const auto proof = m_network->signedEnvelope(body, &error);
        QVariantMap verified;
        if (proof.isEmpty() || !m_network->verifyEnvelope(proof, &verified, &error)
            || !m_store.accept(verified, QDateTime::currentMSecsSinceEpoch(), tickNow(), &error)) {
            rejectSubmission(error); return;
        }
        // No control-message retry queue exists. The source is retained only
        // under its original item deadlines; a later cut may include that proof.
        if (!m_network->publishEnvelope(proof, &error)) {
            rejectSubmission(error); return;
        }
        ++m_submitted;
        m_cutDirty = true;
        m_error.clear();
        publishStatus();
    }
signals:
    void wake();

private:
    QVariantMap common(const QString &kind) {
        return {{"schema", 2}, {"kind", kind}, {"source_node", m_node},
            {"team_id", m_configuration.value("team_id")}, {"match_id", m_configuration.value("match_id")},
            {"epoch", m_configuration.value("epoch")}, {"robot_id", m_configuration.value("robot_id")},
            {"session_id", m_session}, {"session_started_ms", m_started},
            {"sequence", double(++m_sequence)}, {"sent_at_ms", QDateTime::currentMSecsSinceEpoch()}};
    }
    void reject(const QString &error) {
        m_running = false;
        m_error = error.left(200);
        publishStatus();
    }
    void rejectSubmission(const QString &error) {
        ++m_rejected;
        m_error = error.left(200);
        publishStatus();
    }
    void publishStatus(bool withView = false) {
        auto details = m_network ? m_network->details() : QVariantMap{};
        const bool connected = m_running && details.value("connected").toBool();
        const auto producedUtc = QDateTime::currentMSecsSinceEpoch();
        const auto producedTick = tickNow();
        const auto view = m_store.view(producedUtc, producedTick);
        const bool hasView = !view.value("view_id").toString().isEmpty();
        const QString state = !m_running ? !m_error.isEmpty() ? "error" : "stopped"
            : !connected ? "offline" : hasView ? "ready" : "collecting";
        const QMap<QString, QString> names{{"error", "队伍插件配置／来源错误"}, {"stopped", "队伍插件已停止"},
            {"offline", "队伍通道未就绪；本机路径独立"}, {"ready", "已提交完整队伍视图；字段按独立期限失效"},
            {"collecting", "队伍身份已配置；等待授权发布者的完整视图"}};
        details["active"] = m_running;
        details["state"] = state;
        details["error"] = m_error.isEmpty() ? details.value("error") : QVariant(m_error);
        details["publisher_id"] = m_publisher;
        details["view_available"] = connected && hasView;
        details["view_id"] = view.value("view_id");
        details["view_revision"] = view.value("revision");
        details["origin_proofs_required"] = true;
        details["atomic_complete_view"] = true;
        details["host_input_connected"] = false; // Module milestone, not ServiceHub production integration.
        details["clocks_synchronized_declared"] = m_configuration.value("clocks_synchronized");
        details["clock_sync_verified"] = false;
        details["maximum_clock_skew_ms"] = m_configuration.value("max_clock_skew_ms");
        details["team_wide_disclosure"] = true;
        details["recipient_encryption"] = false;
        details["configuration_revision"] = m_configuration.value("configuration_revision");
        details["submissions_accepted"] = double(m_submitted);
        details["submissions_rejected"] = double(m_rejected);
        details["rejected_messages"] = double(m_rejectedMessages);
        details["worker_thread"] = true;
        details["measurement_verified"] = false;
        bool notify = false;
        {
            QMutexLocker lock(&m_mailbox->mutex);
            m_mailbox->details = details;
            m_mailbox->status = names.value(state);
            if (withView && hasView) {
                m_mailbox->view = view;
                m_mailbox->view["channel_connected"] = connected;
                m_mailbox->viewUtc = producedUtc;
                m_mailbox->viewTick = producedTick;
                m_mailbox->viewChanged = true;
            }
            if (!m_mailbox->pending) { m_mailbox->pending = true; notify = true; }
        }
        if (notify) emit wake();
    }
    void advance() {
        if (!m_running || !m_network) return;
        const auto now = tickNow();
        const bool connected = m_network->details().value("connected").toBool();
        if (connected && now - m_lastHeartbeat >= m_configuration.value("heartbeat_ms", 1000).toInt()) {
            m_lastHeartbeat = now;
            auto heartbeat = common("heartbeat");
            QString error;
            const auto proof = m_network->signedEnvelope(heartbeat, &error);
            QVariantMap verified;
            if (!proof.isEmpty() && m_network->verifyEnvelope(proof, &verified, &error)) {
                m_store.accept(verified, QDateTime::currentMSecsSinceEpoch(), now, &error);
                m_network->publishEnvelope(proof, &error);
            }
            if (!error.isEmpty()) m_error = error.left(200);
        }
        if (connected && m_node == m_publisher
            && now - m_lastCut >= m_configuration.value("publish_interval_ms", 250).toInt()
            && (m_cutDirty || now - m_lastCut >= 1000)) publishCut();
        if (now - m_lastStatus >= 250) {
            m_lastStatus = now;
            publishStatus(true);
        }
    }
    void receive(const QVariantMap &body) {
        if (!m_running) return;
        const auto kind = body.value("kind").toString();
        QString error;
        if (kind == "team-view") {
            if (!commitRemote(body, &error)) { ++m_rejectedMessages; m_error = error.left(200); }
        } else if (kind == "heartbeat" || kind == "node-snapshot") {
            if (!m_store.accept(body, QDateTime::currentMSecsSinceEpoch(), tickNow(), &error)) {
                ++m_rejectedMessages; m_error = error.left(200);
            } else if (kind == "node-snapshot") m_cutDirty = true;
        }
        publishStatus(kind == "team-view");
    }
    bool commitRemote(const QVariantMap &body, QString *error) {
        static const QSet<QString> allowed{"schema", "kind", "source_node", "robot_id", "team_id", "match_id",
            "epoch", "session_id", "session_started_ms", "sequence", "sent_at_ms", "view_id", "view_revision",
            "configuration_revision", "proofs", "_network"};
        const auto now = QDateTime::currentMSecsSinceEpoch();
        const auto mono = tickNow();
        qint64 sequence = 0, started = 0, sent = 0, revision = 0;
        if (!keysOnly(body, allowed) || body.value("source_node") != m_publisher
            || body.value("configuration_revision") != m_configuration.value("configuration_revision")
            || !number(body.value("sequence"), 1, SafeInteger, &sequence)
            || !number(body.value("session_started_ms"), 1, SafeInteger, &started)
            || !number(body.value("sent_at_ms"), 1, SafeInteger, &sent)
            || !number(body.value("view_revision"), 1, SafeInteger, &revision)
            || started > sent || sent > now + m_configuration.value("max_clock_skew_ms").toLongLong()
            || now - sent > m_configuration.value("timeout_ms", 5000).toLongLong()
            || body.value("view_id").metaType().id() != QMetaType::QString
            || body.value("view_id").toString().isEmpty() || body.value("view_id").toString().size() > 128
            || body.value("proofs").metaType().id() != QMetaType::QVariantList)
            return fail(error, "完整视图的发布者／配置／时效／版本不匹配");
        const auto session = body.value("session_id").toString();
        if (session != m_viewSession && (!m_viewSession.isEmpty() && started <= m_viewSessionStarted))
            return fail(error, "完整视图来自退休发布会话");
        if (session == m_viewSession && sequence <= m_viewSequence)
            return fail(error, "完整视图重复或倒序");
        if (session != m_viewSession && m_viewSessions >= 16)
            return fail(error, "发布会话重置过多；需赛外更换epoch");
        const auto proofs = body.value("proofs").toList();
        if (proofs.size() > 16) return fail(error, "完整视图来源超过16成员");
        QVariantList verifiedSources;
        QSet<QString> sources;
        const auto arrival = body.value("_network").toMap();
        for (const auto &value : proofs) {
            QVariantMap source;
            if (value.metaType().id() != QMetaType::QVariantMap
                || !m_network->verifyEnvelope(value.toMap(), &source, error)
                || source.value("kind") != "node-snapshot"
                || sources.contains(source.value("source_node").toString()))
                return fail(error, "完整视图的原始来源证明无效／重复");
            sources.insert(source.value("source_node").toString());
            auto provenance = source.value("_network").toMap();
            provenance["received_at_ms"] = arrival.value("received_at_ms");
            provenance["received_tick_ms"] = arrival.value("received_tick_ms");
            source["_network"] = provenance;
            verifiedSources.append(source);
        }
        if (!m_store.commit(verifiedSources, body.value("view_id").toString(), quint64(revision), now, mono, error)) return false;
        if (session != m_viewSession) ++m_viewSessions;
        m_viewSession = session; m_viewSessionStarted = started; m_viewSequence = sequence;
        m_error.clear();
        return true;
    }
    void publishCut() {
        m_lastCut = tickNow();
        QString error;
        auto body = common("team-view");
        body["view_revision"] = double(++m_revision);
        body["view_id"] = m_node + "." + m_session + "." + QString::number(m_revision);
        body["configuration_revision"] = m_configuration.value("configuration_revision");
        body["proofs"] = m_store.proofs(QDateTime::currentMSecsSinceEpoch(), tickNow());
        if (!boundedMap(body, ViewLimit)) {
            m_error = "完整视图超限，整次拒绝；没有截断来源";
            publishStatus(); return;
        }
        const auto proof = m_network->signedEnvelope(body, &error);
        QVariantMap verified;
        if (proof.isEmpty() || !m_network->verifyEnvelope(proof, &verified, &error)
            || !commitRemote(verified, &error) || !m_network->publishEnvelope(proof, &error)) {
            m_error = error.left(200); publishStatus(); return;
        }
        m_cutDirty = false;
        publishStatus(true);
    }
    QVariantMap m_configuration;
    std::shared_ptr<Mailbox> m_mailbox;
    std::unique_ptr<TeamNetwork> m_network;
    TeamDataContract::Store m_store;
    QTimer *m_timer = nullptr;
    QString m_session, m_node, m_publisher, m_error, m_viewSession;
    qint64 m_started = 0, m_lastHeartbeat = 0, m_lastCut = 0, m_lastStatus = 0;
    qint64 m_viewSessionStarted = 0, m_viewSequence = 0;
    quint64 m_sequence = 0, m_revision = 0, m_submitted = 0, m_rejected = 0, m_rejectedMessages = 0;
    int m_viewSessions = 0;
    bool m_running = false, m_cutDirty = true;
};

struct TeamAggregation::Private {
    QThread thread;
    QPointer<TeamAggregationWorker> worker;
    std::shared_ptr<Mailbox> mailbox;
    QVariantMap details;
    QString status = QStringLiteral("未启用");
    quint64 generation = 0;
};

TeamAggregation::TeamAggregation(QObject *parent) : ServiceEndpoint(parent), d(std::make_unique<Private>()) {}
TeamAggregation::~TeamAggregation() { blockSignals(true); stop(); }
bool TeamAggregation::start(const QVariantMap &configuration, QString *error) {
    if (error) error->clear();
    if (QThread::currentThread() != thread()) return fail(error, "队伍服务需由所属线程配置");
    QPointer<TeamAggregation> alive(this);
    const auto generation = d->generation + 1;
    stop();
    if (!alive || generation != d->generation) return false;
    static const QSet<QString> keys{"team_id", "node_id", "robot_id", "match_id", "epoch", "endpoint", "ca_file",
        "certificate_file", "signing_key_file", "peers", "can_send", "can_aggregate", "heartbeat_ms", "timeout_ms",
        "publisher_id", "max_clock_skew_ms", "clocks_synchronized", "team_wide_sharing_confirmed", "allowed_categories",
        "allowed_uses", "category_permissions", "configuration_revision", "publish_interval_ms"};
    QStringList categories, purposes;
    qint64 interval = 250;
    const auto revision = configuration.value("configuration_revision");
    if (!keysOnly(configuration, keys) || !boundedMap(configuration, 128 * 1024)
        || configuration.value("team_wide_sharing_confirmed").metaType().id() != QMetaType::Bool
        || !configuration.value("team_wide_sharing_confirmed").toBool()
        || !stringList(configuration.value("allowed_categories"), {"health", "resources", "position", "objective", "sensorEvents", "visionDiscoveries", "derived"}, &categories)
        || !stringList(configuration.value("allowed_uses"), {"hud", "alerts", "localAi", "externalAi", "voice"}, &purposes)
        || revision.metaType().id() != QMetaType::QString || revision.toString().isEmpty() || revision.toString().size() > 64
        || (configuration.contains("publish_interval_ms") && !number(configuration.value("publish_interval_ms"), 100, 1000, &interval)))
        return fail(error, "队伍配置／共享用途不合法，或未明确同意向整个可信队伍披露");
    auto effective = configuration;
    effective["heartbeat_ms"] = configuration.value("heartbeat_ms", 1000);
    effective["timeout_ms"] = configuration.value("timeout_ms", 5000);
    effective["publish_interval_ms"] = interval;
    TeamDataContract::Store checked;
    if (!checked.configure(storeConfiguration(effective), error)) return false;
    const auto matrixValue = configuration.value("category_permissions", QVariantMap{});
    if (matrixValue.metaType().id() != QMetaType::QVariantMap)
        return fail(error, "队伍用途矩阵须按数据类别分别授权");
    const auto matrix = matrixValue.toMap();
    QStringList matrixCategories, matrixUses;
    for (auto it = matrix.cbegin(); it != matrix.cend(); ++it) {
        QStringList grants;
        if (!categories.contains(it.key()) || !stringList(it.value(),
            {"hud", "alerts", "localAi", "externalAi", "voice"}, &grants) || grants.isEmpty())
            return fail(error, "队伍用途矩阵含未知类别／用途或空授权");
        matrixCategories.append(it.key());
        for (const auto &use : grants) if (!matrixUses.contains(use)) matrixUses.append(use);
    }
    auto configuredCategories = categories, configuredUses = purposes;
    configuredCategories.sort(); configuredUses.sort(); matrixCategories.sort(); matrixUses.sort();
    if (configuredCategories != matrixCategories || configuredUses != matrixUses)
        return fail(error, "队伍类别／用途范围与逐类别授权不一致");
    effective["category_permissions"] = matrix;
    d->mailbox = std::make_shared<Mailbox>();
    auto *worker = new TeamAggregationWorker(effective, d->mailbox);
    d->worker = worker;
    worker->moveToThread(&d->thread);
    connect(&d->thread, &QThread::started, worker, &TeamAggregationWorker::begin);
    connect(&d->thread, &QThread::finished, worker, &QObject::deleteLater);
    connect(worker, &TeamAggregationWorker::wake, this, [this, generation] {
        if (generation != d->generation || !d->mailbox) return;
        QVariantMap view;
        bool viewChanged = false;
        qint64 producedUtc = 0, producedTick = 0;
        {
            QMutexLocker lock(&d->mailbox->mutex);
            d->details = d->mailbox->details;
            d->details["pending_local_submissions"] = d->mailbox->submissions;
            d->status = d->mailbox->status;
            viewChanged = d->mailbox->viewChanged;
            view = d->mailbox->view;
            producedUtc = d->mailbox->viewUtc;
            producedTick = d->mailbox->viewTick;
            d->mailbox->pending = d->mailbox->viewChanged = false;
        }
        QPointer<TeamAggregation> lifetime(this);
        emit statusChanged();
        if (!lifetime || generation != d->generation) return;
        if (viewChanged) emit messageReceived({{"schema", 2}, {"kind", "aggregation-view"},
            {"produced_at_ms", producedUtc}, {"produced_tick_ms", producedTick}, {"payload", view}});
    }, Qt::QueuedConnection);
    d->details = {{"active", false}, {"state", "starting"}, {"host_input_connected", false}};
    d->status = QStringLiteral("队伍插件正在独立线程校验证书；核心客户端无需等待");
    d->thread.setObjectName(QStringLiteral("rm-team-aggregation"));
    d->thread.start();
    emit statusChanged();
    return alive && generation == d->generation; // Accepted start, not authenticated/connected.
}
void TeamAggregation::stop() {
    if (QThread::currentThread() != thread()) return;
    ++d->generation;
    if (d->worker) {
        d->worker->disconnect(this);
        if (d->thread.isRunning())
            QMetaObject::invokeMethod(d->worker, [worker = d->worker] { if (worker) worker->shutdown(); }, Qt::BlockingQueuedConnection);
    }
    d->thread.quit();
    d->thread.wait();
    d->worker = nullptr;
    d->mailbox.reset();
    d->details = {{"active", false}, {"state", "stopped"}, {"host_input_connected", false}};
    d->status = QStringLiteral("队伍插件已停止；本机数据独立运行");
    emit statusChanged();
}
bool TeamAggregation::submit(const QVariantMap &message, QString *error) {
    if (error) error->clear();
    if (QThread::currentThread() != thread() || !d->worker || !d->mailbox || !d->details.value("active").toBool())
        return fail(error, "队伍服务尚未就绪");
    qint64 schema = 0;
    if (!keysOnly(message, {"schema", "kind", "snapshot_id", "items"})
        || !number(message.value("schema"), 2, 2, &schema) || message.value("kind") != "local-snapshot"
        || message.value("snapshot_id").metaType().id() != QMetaType::QString
        || message.value("snapshot_id").toString().isEmpty() || message.value("snapshot_id").toString().size() > 96
        || message.value("items").metaType().id() != QMetaType::QVariantList || message.value("items").toList().size() > 64
        || !boundedMap(message, SourceLimit - 1024))
        return fail(error, "本机来源快照的结构／类型／大小不合法");
    {
        QMutexLocker lock(&d->mailbox->mutex);
        if (d->mailbox->submissions >= 4) return fail(error, "队伍本机提交队列已满");
        ++d->mailbox->submissions;
    }
    const auto worker = d->worker;
    if (!QMetaObject::invokeMethod(worker, [worker, message] { if (worker) worker->submitLocal(message); }, Qt::QueuedConnection)) {
        QMutexLocker lock(&d->mailbox->mutex);
        --d->mailbox->submissions;
        return fail(error, "本机来源提交未排入服务线程");
    }
    return true; // Queue acceptance only. Worker validation/publication can still fail.
}
QString TeamAggregation::status() const { return d->status; }
QVariantMap TeamAggregation::details() const { return d->details; }

#include "TeamAggregation.moc"
