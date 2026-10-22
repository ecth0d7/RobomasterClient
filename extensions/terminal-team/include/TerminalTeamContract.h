#pragma once
#include <QVariantMap>
#include <memory>

// Project-only schema3. No official robot IDs or 2026 wire fields are inferred.
// accept/commit require actual TeamNetwork::verifyEnvelope output; the pure
// store does not turn a QVariant authentication flag into a signature verifier.
namespace TerminalTeamContract {
bool validateConfiguration(const QVariantMap &, QString *error = nullptr);
bool validateLocalSnapshotRequest(const QVariantMap &, QString *error = nullptr);
QVariantMap networkConfiguration(const QVariantMap &, const QString &session);
class Store final {
public:
    Store();
    ~Store();
    Store(const Store &);
    Store &operator=(const Store &);
    bool configure(const QVariantMap &, QString *error = nullptr);
    bool prepareLocal(const QVariantList &canonicalObservations, qint64 utc, qint64 tick,
                      QVariantList *wrappedItems, QString *error = nullptr);
    bool accept(const QVariantMap &verifiedBody, qint64 utc, qint64 tick, QString *error = nullptr);
    QVariantList proofs(qint64 utc, qint64 tick) const;
    bool commit(const QVariantMap &verifiedView, const QVariantList &verifiedSources,
                qint64 utc, qint64 tick, QString *error = nullptr);
    QVariantMap view(qint64 utc, qint64 tick, bool connected) const;
    void clear();
private:
    struct Private;
    std::unique_ptr<Private> d;
};
}
