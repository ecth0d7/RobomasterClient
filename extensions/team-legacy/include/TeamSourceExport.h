#pragma once

#include <QStringList>
#include <QVariantMap>
#include <memory>

// Purpose-minimal projection of a host-owned local view. This performs neither
// network authentication nor device/calibration verification. Only the optional
// team adapter signs and publishes the complete resulting cut.
namespace TeamSourceExport {
QVariantMap build(const QVariantMap &localView, const QVariantMap &categoryPermissions,
                  const QStringList &shareFields, int robotId, bool sharingEnabled,
                  bool canSend, QString *error = nullptr);

// Outgoing revision is a host transport version. Original source revision stays
// in SourceRegistry; the raw observation, timestamp and provenance stay intact.
// Keep one ledger per team node session and reset only when that session retires.
class VersionLedger final {
public:
    VersionLedger();
    ~VersionLedger();
    VersionLedger(const VersionLedger &);
    VersionLedger &operator=(const VersionLedger &);
    VersionLedger(VersionLedger &&) noexcept;
    VersionLedger &operator=(VersionLedger &&) noexcept;
    QVariantMap apply(const QVariantMap &candidate, const QVariantMap &localView,
                      QString *error = nullptr);
    void reset();

private:
    struct Private;
    std::unique_ptr<Private> d;
};
}
