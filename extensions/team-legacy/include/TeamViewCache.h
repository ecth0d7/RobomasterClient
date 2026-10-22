#pragma once

#include <QVariantMap>
#include <memory>

// Diagnostic host boundary for a native aggregation adapter. Structural scope
// validation is deliberately separate from source-signature verification and AI
// admission; neither is established by accepting an adapter's projected view.
class TeamViewCache final {
public:
    TeamViewCache();
    ~TeamViewCache();
    TeamViewCache(TeamViewCache &&) noexcept;
    TeamViewCache &operator=(TeamViewCache &&) noexcept;
    TeamViewCache(const TeamViewCache &) = delete;
    TeamViewCache &operator=(const TeamViewCache &) = delete;

    void reset(const QVariantMap &expectedNativeConfiguration = {});
    bool accept(const QVariantMap &message, qint64 utcNow, qint64 steadyNow,
                QString *error = nullptr);
    QVariantMap view(qint64 utcNow, qint64 steadyNow, bool channelConnected) const;

private:
    struct Private;
    std::unique_ptr<Private> d;
};
