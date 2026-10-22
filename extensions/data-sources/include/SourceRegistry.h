#pragma once

#include <QString>
#include <QVariantMap>
#include <memory>

// Native host boundary for individually authorized data producers. Registration
// is not exposed as transport authentication; a registry never owns a socket,
// model invocation, robot command or official telemetry store.
class SourceRegistry final {
public:
    SourceRegistry();
    ~SourceRegistry();
    SourceRegistry(const SourceRegistry &);
    SourceRegistry &operator=(const SourceRegistry &);
    SourceRegistry(SourceRegistry &&) noexcept;
    SourceRegistry &operator=(SourceRegistry &&) noexcept;

    // Returns a nonzero host-owned generation, or zero on refusal. Replacing a
    // source retires its previous generation and requires a new session ID.
    quint64 registerSource(const QVariantMap &descriptor, QString *error = nullptr);
    bool accept(const QString &sourceId, quint64 generation,
                const QVariantMap &message, qint64 utcNow, qint64 steadyNow,
                QString *error = nullptr);
    void retire(const QString &sourceId, quint64 generation);
    void clear();
    QVariantMap view(qint64 utcNow, qint64 steadyNow) const;

private:
    struct Private;
    std::unique_ptr<Private> d;
};
