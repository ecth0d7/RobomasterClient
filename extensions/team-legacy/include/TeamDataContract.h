#pragma once

#include <QString>
#include <QVariantMap>
#include <memory>

// Pure, optional team aggregation. No sockets, clocks, model calls or commands
// are owned here. The caller supplies current UTC and steady-clock milliseconds.
// Only TeamNetwork::verifyEnvelope output may enter accept()/commit(); _network
// is a transport provenance marker, not independently verifiable authentication.
namespace TeamDataContract {
// Structural/provenance validation shared with native source admission. This is
// deliberately independent of Store's authenticated network envelope boundary;
// success is neither peer authentication nor sensor/calibration verification.
bool validateSourceItem(const QVariantMap &item, qint64 sentUtc, qint64 maxSkewMs,
                        QString *error = nullptr);

class Store final {
public:
    Store();
    ~Store();
    Store(const Store &);
    Store &operator=(const Store &);
    Store(Store &&) noexcept;
    Store &operator=(Store &&) noexcept;

    bool configure(const QVariantMap &config, QString *error = nullptr);
    bool accept(const QVariantMap &verifiedBody, qint64 utcNow, qint64 monotonicNow,
                QString *error = nullptr);
    // Original signed envelopes, sorted by node; never heartbeat envelopes.
    // A latest snapshot containing a locally quarantined conflict is excluded
    // whole: forwarding only its latest proof would hide the conflict from peers.
    QVariantList proofs(qint64 utcNow, qint64 monotonicNow) const;
    // The caller separately authenticates the enclosing team-view issuer against
    // publisher_id; this API receives only its already-verified nested sources.
    bool commit(const QVariantList &verifiedSnapshots, const QString &viewId,
                quint64 revision, qint64 utcNow, qint64 monotonicNow,
                QString *error = nullptr);
    // No fields are exposed before a complete cut is committed. Values and the
    // selected-node set stay fixed; freshness/conflict/withdrawal can invalidate
    // a selected value without admitting a newer, uncommitted value.
    // allowed_uses is narrowed by same-source derived dependencies; the original
    // signed grant list is retained as source_allowed_uses. Peer authentication
    // never upgrades measurement_validation or an unknown producer timestamp.
    QVariantMap view(qint64 utcNow, qint64 monotonicNow) const;
    void clear();

private:
    struct Private;
    std::unique_ptr<Private> d;
};
}
