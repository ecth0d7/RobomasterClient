#include "TerminalTeamVerifier.h"

#include "TerminalTeamContract.h"
#include "TeamNetwork.h"
#include <QMetaObject>
#include <QMutex>
#include <QMutexLocker>
#include <QObject>
#include <QPointer>
#include <QThread>

namespace {
bool fail(QString *error, const QString &message) {
    if (error) *error = message;
    return false;
}

class VerificationWorker final : public QObject {
public:
    bool configure(const QVariantMap &configuration, QString *error) {
        shutdown();
        if (!TerminalTeamContract::validateConfiguration(configuration, error)) return false;
        auto network = std::make_unique<TeamNetwork>();
        // This is a verifier-local label, never a publishing session. Source
        // envelopes retain their ORIGINAL signed session and sequence fields.
        const auto native = TerminalTeamContract::networkConfiguration(
            configuration, QStringLiteral("host-proof-verifier"));
        if (!network->configureVerification(native, error)) return false;
        m_publisher = configuration.value("publisher_id").toString();
        m_network = std::move(network);
        return true;
    }

    void shutdown() {
        if (m_network) m_network->stop();
        m_network.reset();
        m_publisher.clear();
    }

    bool verify(const QVariantMap &proof, QVariantMap *body,
                const QString &kind, QString *error) const {
        if (!m_network || !body) return fail(error, "Independent native team verifier is not configured");
        QVariantMap verified;
        // Every trust claim in the package's projected view is ignored. This
        // parses and verifies the ORIGINAL canonical-base64 signed envelope,
        // including certificate validity, CA chain, SPKI pin, role and scope.
        if (!m_network->verifyEnvelope(proof, &verified, error)) return false;
        if (verified.value("kind") != kind ||
            (kind == "team-view" && verified.value("source_node") != m_publisher))
            return fail(error, "Proof kind or designated team-view publisher does not match native configuration");
        *body = std::move(verified);
        return true;
    }

private:
    std::unique_ptr<TeamNetwork> m_network;
    QString m_publisher;
};
}

struct TerminalTeamVerifier::Private {
    QMutex mutex;
    QThread thread;
    QPointer<VerificationWorker> worker;

    // Called only with mutex held. No asynchronous proof result or callback is
    // ever posted to the caller; a successful stop therefore leaves no queued
    // old-context results capable of reviving the retired trust configuration.
    void shutdown() {
        if (worker && thread.isRunning()) {
            const auto target = worker;
            QMetaObject::invokeMethod(target, [target] {
                if (target) target->shutdown();
            }, Qt::BlockingQueuedConnection);
        }
        thread.quit();
        thread.wait();
        worker = nullptr;
    }
};

TerminalTeamVerifier::TerminalTeamVerifier() : d(std::make_unique<Private>()) {}
TerminalTeamVerifier::~TerminalTeamVerifier() { stop(); }

bool TerminalTeamVerifier::configure(const QVariantMap &configuration, QString *error) {
    if (error) error->clear();
    QMutexLocker lock(&d->mutex);
    d->shutdown();
    auto *worker = new VerificationWorker;
    worker->moveToThread(&d->thread);
    d->worker = worker;
    QObject::connect(&d->thread, &QThread::finished, worker, &QObject::deleteLater);
    d->thread.setObjectName("rm-terminal-team-proof-verifier");
    d->thread.start();
    bool configured = false;
    const bool invoked = QMetaObject::invokeMethod(worker, [&] {
        configured = worker->configure(configuration, error);
    }, Qt::BlockingQueuedConnection);
    if (!invoked || !configured) {
        d->shutdown();
        if (error && error->isEmpty()) *error = "Cannot configure the independent native team verifier worker";
        return false;
    }
    return true;
}

void TerminalTeamVerifier::stop() {
    QMutexLocker lock(&d->mutex);
    d->shutdown();
}

bool TerminalTeamVerifier::verifySourceProof(const QVariantMap &proof, QVariantMap *body, QString *error) {
    return verify(proof, body, QStringLiteral("node-snapshot"), error);
}

bool TerminalTeamVerifier::verifyTeamViewProof(const QVariantMap &proof, QVariantMap *body, QString *error) {
    return verify(proof, body, QStringLiteral("team-view"), error);
}

bool TerminalTeamVerifier::verify(const QVariantMap &proof, QVariantMap *body,
                                  const QString &kind, QString *error) {
    if (error) error->clear();
    if (body) body->clear();
    QMutexLocker lock(&d->mutex);
    if (!body || !d->worker || !d->thread.isRunning())
        return fail(error, "Independent native team verifier configuration/output is unavailable");
    bool accepted = false;
    const auto worker = d->worker;
    const bool invoked = QMetaObject::invokeMethod(worker, [&] {
        if (worker) accepted = worker->verify(proof, body, kind, error);
    }, Qt::BlockingQueuedConnection);
    if (!invoked || !accepted) {
        body->clear();
        if (error && error->isEmpty()) *error = "Independent native team proof verification failed";
        return false;
    }
    return true;
}
