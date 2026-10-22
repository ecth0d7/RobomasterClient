#include "TerminalTeamAggregation.h"
#include "TerminalTeamContract.h"
#include "TeamNetwork.h"
#include <QDateTime>
#include <QJsonDocument>
#include <QMutex>
#include <QMutexLocker>
#include <QPointer>
#include <QSet>
#include <QThread>
#include <QTimer>
#include <QUuid>
#include <chrono>
#include <atomic>

namespace {
constexpr qint64 Safe = 9007199254740991LL;
qint64 tickNow() { return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count(); }
bool fail(QString *error, const QString &message) { if (error) *error = message; return false; }
struct Mailbox {
    QMutex mutex;
    QVariantMap details, view;
    QString status;
    int pendingSubmissions = 0;
    std::atomic_bool retired{false};
    bool pendingWake = false, viewChanged = false;
};
}

// All cryptography, certificate parsing, complete-cut admission and networking
// stay on this worker. The GUI gets one coalesced, bounded view mailbox.
class TerminalTeamWorker final : public QObject {
    Q_OBJECT
public:
    TerminalTeamWorker(QVariantMap configuration, std::shared_ptr<Mailbox> box)
        : m_configuration(std::move(configuration)), m_box(std::move(box)) {}
    void begin() {
        if (m_box->retired.load()) return;
        QString error;
        if (!m_store.configure(m_configuration, &error)) { reject(error); return; }
        m_session = QUuid::createUuid().toString(QUuid::WithoutBraces);
        m_started = QDateTime::currentMSecsSinceEpoch();
        m_network = std::make_unique<TeamNetwork>();
        connect(m_network.get(), &TeamNetwork::messageReceived, this, &TerminalTeamWorker::receive);
        connect(m_network.get(), &TeamNetwork::statusChanged, this, [this] { project(); });
        if (!m_network->start(TerminalTeamContract::networkConfiguration(m_configuration, m_session), &error)) {
            reject(error); return;
        }
        m_running = true;
        m_timer = new QTimer(this); m_timer->setInterval(100);
        connect(m_timer, &QTimer::timeout, this, &TerminalTeamWorker::advance);
        m_timer->start(); project();
    }
    void shutdown() {
        m_running = false;
        if (m_timer) m_timer->stop();
        if (m_network) { m_network->disconnect(this); m_network->stop(); m_network.reset(); }
        m_store.clear();
    }
    bool verify(const QVariantMap &proof, QVariantMap *out, const QString &kind, QString *error) {
        if (out) out->clear();
        if (!m_running || !m_network || !out || !m_network->verifyEnvelope(proof, out, error)) return false;
        if (out->value("kind") != kind || (kind == "team-view" && out->value("source_node") != m_configuration.value("publisher_id"))) {
            out->clear(); return fail(error, "Proof does not represent the configured source/publisher kind");
        }
        return true;
    }
    void submitLocal(const QVariantMap &message) {
        { QMutexLocker lock(&m_box->mutex); --m_box->pendingSubmissions; }
        if (m_box->retired.load()) return;
        if (!m_running || !m_network || !m_network->details().value("connected").toBool()) {
            rejectSubmission("Team channel is not subscribed; no old snapshot was queued for reconnect"); return;
        }
        QString error; QVariantList items;
        const auto utc = QDateTime::currentMSecsSinceEpoch(), tick = tickNow();
        if (!m_store.prepareLocal(message.value("items").toList(), utc, tick, &items, &error)) { rejectSubmission(error); return; }
        ++m_submitted;
        m_localSnapshotId = message.value("snapshot_id").toString(); m_localItems = items;
        publishLocal();
    }
signals:
    void wake();
private:
    void publishLocal() {
        if (m_box->retired.load()) return;
        auto body = common("node-snapshot"); if (body.isEmpty()) return;
        body["snapshot_id"] = m_localSnapshotId; body["items"] = m_localItems;
        QString error;
        const auto proof = m_network->signedEnvelope(body, &error); QVariantMap verified;
        if (proof.isEmpty() || !m_network->verifyEnvelope(proof, &verified, &error) ||
            !m_store.accept(verified, QDateTime::currentMSecsSinceEpoch(), tickNow(), &error)) { rejectSubmission(error); return; }
        m_dirty = true;
        if (m_box->retired.load()) return;
        if (!m_network->publishEnvelope(proof, &error)) { rejectSubmission(error); return; }
        ++m_publishedSnapshots; m_error.clear(); project();
    }
    QVariantMap common(const QString &kind) {
        if (m_sequence >= Safe) { reject("Signed node sequence exhausted; a new explicit epoch is required"); return {}; }
        return {{"schema", 3}, {"kind", kind}, {"context", m_configuration.value("context")},
            {"team_id", m_configuration.value("team_id")}, {"match_id", m_configuration.value("match_id")},
            {"epoch", m_configuration.value("epoch")}, {"source_node", m_configuration.value("node_id")},
            {"robot_key", m_configuration.value("robot_key")}, {"session_id", m_session},
            {"session_started_ms", m_started}, {"sequence", ++m_sequence}, {"sent_at_ms", QDateTime::currentMSecsSinceEpoch()}};
    }
    void reject(const QString &error) { m_running = false; m_error = error.left(256); project(); }
    void rejectSubmission(const QString &error) { ++m_rejected; m_error = error.left(256); project(); }
    void project() {
        auto details = m_network ? m_network->details() : QVariantMap{};
        const bool connected = m_running && details.value("connected").toBool();
        // Sample before projection/queueing; the host must charge every later
        // millisecond to remaining_ms. A GUI drain never restamps this view.
        const auto utc = QDateTime::currentMSecsSinceEpoch(), tick = tickNow();
        auto view = m_store.view(utc, tick, connected);
        view["produced_at_ms"] = utc; view["produced_tick_ms"] = tick;
        const bool oversized = QJsonDocument::fromVariant(view).toJson(QJsonDocument::Compact).size() > 1024 * 1024;
        if (oversized) {
            m_running = false; m_error = "Complete native view exceeds 1 MiB; no records or proofs were truncated";
        }
        const bool hasView = !oversized && !view.value("view_id").toString().isEmpty();
        details["schema"] = 3; details["context"] = m_configuration.value("context");
        details["active"] = m_running; details["connected"] = connected;
        details["publisher_id"] = m_configuration.value("publisher_id");
        details["state"] = !m_running ? (m_error.isEmpty() ? "stopped" : "error") : !connected ? "offline" : hasView ? "ready" : "collecting";
        details["error"] = m_error.isEmpty() ? details.value("error") : QVariant(m_error);
        details["view_id"] = view.value("view_id"); details["view_revision"] = view.value("revision");
        details["training_mock"] = m_configuration.value("training_mock");
        details["atomic_complete_view"] = true; details["origin_proofs_required"] = true;
        details["source_proof_verifier"] = true; details["publisher_proof_verifier"] = true;
        details["host_input_connected"] = false; details["ai_input_ready"] = false;
        details["measurement_verified"] = false; details["official_issuer_bound"] = false;
        details["clocks_synchronized_declared"] = m_configuration.value("clocks_synchronized");
        details["clock_sync_verified"] = false; details["team_wide_disclosure"] = true;
        details["recipient_encryption"] = false; details["worker_thread"] = true;
        details["source_body_limit"] = 64 * 1024; details["team_view_body_limit"] = 256 * 1024;
        details["native_view_limit"] = 1024 * 1024;
        details["maximum_cut_members"] = 16; details["maximum_source_items"] = 64;
        details["full_maximum_cartesian_product_supported"] = false;
        details["submissions_accepted"] = m_submitted; details["submissions_rejected"] = m_rejected;
        details["snapshots_locally_published"] = m_publishedSnapshots;
        details["messages_rejected"] = m_rejectedMessages;
        const QString status = !m_running ? "队伍插件已停止／配置错误；本机功能独立" : !connected ? "队伍TLS通道未就绪；本机功能独立"
            : hasView ? "已验证并提交完整队伍截面；主宿主仍需独立核验来源证明" : "队伍通道已接通；等待指定发布者完整截面";
        bool notify = false;
        { QMutexLocker lock(&m_box->mutex);
            m_box->details = details; m_box->status = status;
            if (hasView) { m_box->view = view; m_box->viewChanged = true; }
            if (!m_box->pendingWake) { m_box->pendingWake = true; notify = true; }
        }
        if (notify) emit wake();
    }
    bool commitRemote(const QVariantMap &body, QString *error) {
        const auto values = body.value("proofs");
        if (values.metaType().id() != QMetaType::QVariantList || values.toList().size() > 16)
            return fail(error, "Complete view has invalid original source proof list");
        QVariantList sources; QSet<QString> nodes;
        const auto arrival = body.value("_network").toMap();
        for (const auto &value : values.toList()) {
            QVariantMap source;
            if (value.metaType().id() != QMetaType::QVariantMap || !verify(value.toMap(), &source, "node-snapshot", error) ||
                nodes.contains(source.value("source_node").toString())) return fail(error, "Invalid or repeated original source proof");
            nodes.insert(source.value("source_node").toString());
            auto provenance = source.value("_network").toMap();
            provenance["received_at_ms"] = arrival.value("received_at_ms");
            provenance["received_tick_ms"] = arrival.value("received_tick_ms");
            source["_network"] = provenance; sources.append(source);
        }
        return m_store.commit(body, sources, QDateTime::currentMSecsSinceEpoch(), tickNow(), error);
    }
    void receive(const QVariantMap &body) {
        if (!m_running || m_box->retired.load()) return;
        QString error; const auto kind = body.value("kind").toString();
        const bool accepted = kind == "team-view" ? commitRemote(body, &error)
            : m_store.accept(body, QDateTime::currentMSecsSinceEpoch(), tickNow(), &error);
        if (!accepted) { ++m_rejectedMessages; m_error = error.left(256); }
        else { if (kind == "node-snapshot") m_dirty = true; m_error.clear(); }
        project();
    }
    void publishCut() {
        if (m_box->retired.load()) return;
        m_lastCut = tickNow();
        if (m_revision >= Safe) { reject("Complete cut revision exhausted"); return; }
        auto body = common("team-view"); if (body.isEmpty()) return;
        body["view_id"] = m_configuration.value("node_id").toString() + "." + m_session + "." + QString::number(++m_revision);
        body["view_revision"] = m_revision;
        body["proofs"] = m_store.proofs(QDateTime::currentMSecsSinceEpoch(), tickNow());
        QString error; const auto proof = m_network->signedEnvelope(body, &error); QVariantMap verified;
        if (proof.isEmpty() || !m_network->verifyEnvelope(proof, &verified, &error) ||
            !commitRemote(verified, &error) || m_box->retired.load() || !m_network->publishEnvelope(proof, &error)) { rejectSubmission(error); return; }
        m_dirty = false; m_error.clear(); project();
    }
    void advance() {
        if (!m_running || !m_network || m_box->retired.load()) return;
        const auto now = tickNow(); const bool connected = m_network->details().value("connected").toBool();
        if (connected && now - m_lastHeartbeat >= m_configuration.value("heartbeat_ms").toLongLong()) {
            m_lastHeartbeat = now;
            if (!m_localSnapshotId.isEmpty()) {
                // Refresh the signed NODE proof/liveness, never the original
                // observation sequence/value/grants/relay deadline. This also
                // republishes the latest complete empty/retraction state.
                publishLocal();
            } else {
                auto body = common("heartbeat"); if (body.isEmpty()) return;
                QString error; const auto proof = m_network->signedEnvelope(body, &error); QVariantMap verified;
                if (proof.isEmpty() || !m_network->verifyEnvelope(proof, &verified, &error) ||
                    !m_store.accept(verified, QDateTime::currentMSecsSinceEpoch(), tickNow(), &error) || m_box->retired.load() || !m_network->publishEnvelope(proof, &error))
                    m_error = error.left(256);
            }
        }
        if (connected && m_configuration.value("node_id") == m_configuration.value("publisher_id") &&
            now - m_lastCut >= 250 && (m_dirty || now - m_lastCut >= 1000)) publishCut();
        if (now - m_lastStatus >= 250) { m_lastStatus = now; project(); }
    }
    QVariantMap m_configuration; std::shared_ptr<Mailbox> m_box;
    std::unique_ptr<TeamNetwork> m_network; TerminalTeamContract::Store m_store;
    QTimer *m_timer = nullptr; QString m_session, m_error, m_localSnapshotId; QVariantList m_localItems;
    qint64 m_started = 0, m_sequence = 0, m_revision = 0, m_lastHeartbeat = 0, m_lastCut = 0, m_lastStatus = 0;
    qint64 m_submitted = 0, m_rejected = 0, m_rejectedMessages = 0, m_publishedSnapshots = 0;
    bool m_running = false, m_dirty = true;
};

struct TerminalTeamAggregation::Private {
    QThread workerThread; QPointer<TerminalTeamWorker> worker;
    std::shared_ptr<Mailbox> mailbox; QVariantMap details;
    QString status = QStringLiteral("未启用"); quint64 generation = 0;
};
TerminalTeamAggregation::TerminalTeamAggregation(QObject *parent) : ServiceEndpoint(parent), d(std::make_unique<Private>()) {
    d->details = {{"active", false}, {"state", "stopped"}, {"ai_input_ready", false}};
}
TerminalTeamAggregation::~TerminalTeamAggregation() { blockSignals(true); stop(); }
bool TerminalTeamAggregation::start(const QVariantMap &configuration, QString *error) {
    if (error) error->clear();
    if (QThread::currentThread() != thread()) return fail(error, "Terminal team service requires its owning thread");
    QPointer<TerminalTeamAggregation> alive(this); const auto generation = d->generation + 1;
    stop(); if (!alive || generation != d->generation) return false;
    if (!TerminalTeamContract::validateConfiguration(configuration, error)) return false;
    d->mailbox = std::make_shared<Mailbox>(); auto *worker = new TerminalTeamWorker(configuration, d->mailbox); d->worker = worker;
    worker->moveToThread(&d->workerThread);
    connect(&d->workerThread, &QThread::started, worker, &TerminalTeamWorker::begin);
    connect(&d->workerThread, &QThread::finished, worker, &QObject::deleteLater);
    connect(worker, &TerminalTeamWorker::wake, this, [this, generation] {
        if (generation != d->generation || !d->mailbox) return;
        QVariantMap view; bool changed = false;
        { QMutexLocker lock(&d->mailbox->mutex);
            d->details = d->mailbox->details; d->details["pending_local_submissions"] = d->mailbox->pendingSubmissions;
            d->status = d->mailbox->status; view = d->mailbox->view; changed = d->mailbox->viewChanged;
            d->mailbox->pendingWake = d->mailbox->viewChanged = false;
        }
        QPointer<TerminalTeamAggregation> alive(this); emit statusChanged();
        if (alive && generation == d->generation && changed) emit messageReceived(view);
    }, Qt::QueuedConnection);
    d->details = {{"active", false}, {"state", "starting"}, {"ai_input_ready", false}};
    d->status = QStringLiteral("正在独立线程校验队伍身份与证书；本机无需等待");
    d->workerThread.setObjectName("rm-terminal-team-v3"); d->workerThread.start();
    emit statusChanged(); return alive && generation == d->generation;
}
void TerminalTeamAggregation::stop() {
    if (QThread::currentThread() != thread()) return;
    ++d->generation;
    if (d->mailbox) d->mailbox->retired = true;
    if (d->worker) {
        d->worker->disconnect(this);
        if (d->workerThread.isRunning()) QMetaObject::invokeMethod(d->worker, [worker = d->worker] { if (worker) worker->shutdown(); }, Qt::BlockingQueuedConnection);
    }
    d->workerThread.quit(); d->workerThread.wait(); d->worker = nullptr; d->mailbox.reset();
    d->details = {{"active", false}, {"state", "stopped"}, {"ai_input_ready", false}};
    d->status = QStringLiteral("队伍插件已停止；本机数据独立运行"); emit statusChanged();
}
bool TerminalTeamAggregation::submit(const QVariantMap &message, QString *error) {
    if (error) error->clear();
    if (QThread::currentThread() != thread() || !d->worker || !d->mailbox || !d->details.value("active").toBool())
        return fail(error, "Terminal team service is not active");
    if (!TerminalTeamContract::validateLocalSnapshotRequest(message, error)) return false;
    // Full bounded typed validation is performed by the worker before signing.
    // A JSON serialization is deliberately not used on arbitrary metatypes here.
    { QMutexLocker lock(&d->mailbox->mutex);
        if (d->mailbox->pendingSubmissions >= 4) return fail(error, "Bounded team submission queue is full");
        ++d->mailbox->pendingSubmissions;
    }
    const auto worker = d->worker;
    if (!QMetaObject::invokeMethod(worker, [worker, message] { if (worker) worker->submitLocal(message); }, Qt::QueuedConnection)) {
        QMutexLocker lock(&d->mailbox->mutex); --d->mailbox->pendingSubmissions; return fail(error, "Cannot queue local snapshot");
    }
    return true; // Queue acceptance, never broker/peer receipt or robot execution.
}
QString TerminalTeamAggregation::status() const { return d->status; }
QVariantMap TerminalTeamAggregation::details() const { return d->details; }
bool TerminalTeamAggregation::verifySourceProof(const QVariantMap &proof, QVariantMap *body, QString *error) {
    if (body) body->clear();
    if (QThread::currentThread() != thread() || !body || !d->worker || !d->workerThread.isRunning()) return fail(error, "Source verifier is not active on its owning thread");
    const auto worker = d->worker; bool accepted = false;
    const bool invoked = QMetaObject::invokeMethod(worker, [&] { if (worker) accepted = worker->verify(proof, body, "node-snapshot", error); }, Qt::BlockingQueuedConnection);
    return invoked && accepted;
}
bool TerminalTeamAggregation::verifyTeamViewProof(const QVariantMap &proof, QVariantMap *body, QString *error) {
    if (body) body->clear();
    if (QThread::currentThread() != thread() || !body || !d->worker || !d->workerThread.isRunning()) return fail(error, "Publisher verifier is not active on its owning thread");
    const auto worker = d->worker; bool accepted = false;
    const bool invoked = QMetaObject::invokeMethod(worker, [&] { if (worker) accepted = worker->verify(proof, body, "team-view", error); }, Qt::BlockingQueuedConnection);
    return invoked && accepted;
}
#include "TerminalTeamAggregation.moc"
