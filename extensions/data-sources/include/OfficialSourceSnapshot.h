#pragma once

#include <QByteArray>
#include <QMap>
#include <QSet>
#include <QString>
#include <QVariantMap>

// Native host producer only. The caller must establish the official endpoint,
// operator attestation and per-purpose consent before invoking this producer.
// This class neither authenticates an official server nor opens any transport.
class OfficialSourceSnapshot final {
public:
    // Retires a source session, but keeps the lifetime revision allocator so a
    // surviving team node session cannot mistake reconnect data for a replay.
    // A detected clock fault also survives until a new telemetry session.
    void reset();
    QVariantMap build(const QVariantMap &telemetrySnapshot,
                      const QVariantMap &perCategoryUses, const QString &sourceId,
                      const QString &sessionId, const QString &playerExportId,
                      qint64 utcNow, qint64 steadyNow, QString *error = nullptr);

private:
    struct Entry {
        QString observationSession;
        qint64 observationRevision = 0;
        QByteArray observationContent, versionContent;
        QVariantMap item;
        qint64 deadline = 0, fieldDeadline = 0, revision = 0;
    };
    QMap<QString, Entry> m_entries;
    QVariantMap m_lastCut;
    QByteArray m_lastMembers;
    QString m_sourceId, m_sessionId, m_observationSession;
    QSet<QString> m_retiredObservationSessions;
    QByteArray m_identityContent;
    int m_robotId = 0;
    qint64 m_sequence = 0, m_lastUtc = 0, m_lastSteady = 0;
    qint64 m_itemRevision = 0, m_identityRevision = 0;
    bool m_clockInvalid = false;
};
