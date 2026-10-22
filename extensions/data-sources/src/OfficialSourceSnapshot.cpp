#include "OfficialSourceSnapshot.h"
#include "DecisionContext.h"
#include "RobotIdentity.h"

#include <QJsonDocument>
#include <QSet>
#include <QUuid>
#include <algorithm>
#include <cmath>
#include <utility>

namespace {
constexpr qint64 SafeInteger = 9007199254740991LL;
QVariantMap fail(QString *error, const char *reason) {
    if (error)
        *error = QString::fromLatin1(reason);
    return {};
}
bool integer(const QVariant &value, qint64 minimum, qint64 maximum, qint64 *out) {
    switch (value.metaType().id()) {
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double: case QMetaType::Float:
    case QMetaType::Long: case QMetaType::ULong: case QMetaType::Short:
    case QMetaType::UShort: case QMetaType::Char: case QMetaType::UChar: break;
    default: return false;
    }
    const double number = value.toDouble();
    if (!std::isfinite(number) || std::floor(number) != number || number < double(minimum) ||
        number > double(maximum))
        return false;
    *out = qint64(number);
    return true;
}
bool id(const QString &value, qsizetype maximum = 96) {
    if (value.isEmpty() || value.size() > maximum)
        return false;
    for (const auto c : value) {
        const auto u = c.unicode();
        if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') ||
              (u >= '0' && u <= '9') || u == '_' || u == '-' || u == '.' || u == ':' || u == '/'))
            return false;
    }
    return true;
}
QByteArray compact(const QVariant &value) {
    return QJsonDocument::fromVariant(value).toJson(QJsonDocument::Compact);
}
struct Observation {
    QString session, ingressSession;
    qint64 revision = 0, received = 0, lifetime = 0, remaining = 0;
    qint64 ingressSequence = 0, queueAge = 0;
};
bool observation(const QVariantMap &metadata, qint64 utcNow, Observation *out) {
    qint64 age = 0;
    out->session = metadata.value("observation_session_id").toString();
    if (metadata.value("observation_session_id").metaType().id() != QMetaType::QString ||
        !id(out->session) ||
        !integer(metadata.value("observation_revision"), 1, SafeInteger, &out->revision) ||
        !integer(metadata.value("received_at_ms"), 1, SafeInteger - 10000, &out->received) ||
        !integer(metadata.value("received_age_ms"), 0, 10000, &age) ||
        !integer(metadata.value("lifetime_ms"), 1, 10000, &out->lifetime))
        return false;
    out->remaining = DecisionContext::remainingLifetime(metadata);
    out->ingressSession = metadata.value("ingress_session_id").toString();
    out->ingressSequence = metadata.value("ingress_sequence").toLongLong();
    out->queueAge = metadata.value("queue_age_ms_at_ingest").toLongLong();
    // Monotonic ages and actual receive UTC must describe the same sample.
    // remainingLifetime admits only verified callback arrival, so GUI dispatch
    // cannot renew the sample. Receipt is not an official producer timestamp.
    return out->remaining > 0 && std::abs((utcNow - out->received) - age) <= 250;
}
QString newId() {
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}
}

void OfficialSourceSnapshot::reset() {
    m_entries.clear();
    m_lastCut.clear();
    m_lastMembers.clear();
    m_sourceId.clear();
    m_sessionId.clear();
    m_identityContent.clear();
    m_identityRevision = 0;
    m_robotId = 0;
    m_sequence = 0;
    // Host retry/consent retirement is not evidence that the receive clock was
    // repaired. Only a new TelemetryStore session can lift clock quarantine.
    // Historical retired receive sessions remain bounded and non-replayable.
}

QVariantMap OfficialSourceSnapshot::build(const QVariantMap &snapshot,
                                         const QVariantMap &permissions,
                                         const QString &sourceId, const QString &sessionId,
                                         const QString &playerExportId, qint64 utcNow,
                                         qint64 steadyNow, QString *error) {
    if (error)
        error->clear();
    if (!id(sourceId, 64) || !id(sessionId) || !id(playerExportId) || utcNow <= 0 ||
        utcNow > SafeInteger - 10000 || steadyNow < 0 || steadyNow > SafeInteger - 10000)
        return fail(error, "Invalid official source scope or host clock");
    qint64 robot = 0;
    if (!integer(snapshot.value("client_id"), 1, 109, &robot) || !RobotIdentity::valid(int(robot)) ||
        snapshot.value("connected").metaType().id() != QMetaType::Bool)
        return fail(error, "Invalid official client identity or connection state");
    static const QSet<QString> categories{"health", "resources", "position", "objective"};
    static const QSet<QString> uses{"hud", "alerts", "localAi", "externalAi", "voice"};
    QVariantMap normalizedPermissions;
    for (auto it = permissions.cbegin(); it != permissions.cend(); ++it) {
        if (!categories.contains(it.key()) || it.value().metaType().id() != QMetaType::QVariantList)
            return fail(error, "Invalid official category permission matrix");
        QStringList selected;
        for (const auto &use : it.value().toList()) {
            if (use.metaType().id() != QMetaType::QString || !uses.contains(use.toString()) ||
                selected.contains(use.toString()))
                return fail(error, "Unknown or duplicate official purpose grant");
            selected.append(use.toString());
        }
        std::sort(selected.begin(), selected.end());
        QVariantList grants;
        for (const auto &use : selected)
            grants.append(use);
        normalizedPermissions[it.key()] = grants;
    }
    if (!m_sessionId.isEmpty() &&
        (m_sourceId != sourceId || m_sessionId != sessionId || m_robotId != robot))
        return fail(error, "Official source scope changed without producer reset");

    const auto allObservations = snapshot.value("field_observations").toMap();
    const auto identityMetadata = allObservations.value("robotStatic").toMap().value("robot_id").toMap();
    const auto identityValue = snapshot.value("groups").toMap().value("robotStatic").toMap().value("robot_id");
    qint64 identityRobot = 0;
    Observation identity;
    const bool validIdentity = snapshot.value("connected").toBool() &&
        snapshot.value("field_freshness").toMap().value("robotStatic").toMap().value("robot_id") == "fresh" &&
        integer(identityValue, 1, 109, &identityRobot) && identityRobot == robot &&
        observation(identityMetadata, utcNow, &identity);

    // A telemetry reset creates an independent receive clock/session. Never
    // recover a poisoned old session merely because another poll arrives.
    const bool newObservationSession = validIdentity && identity.session != m_observationSession;
    if (newObservationSession &&
        (m_retiredObservationSessions.contains(identity.session) ||
         m_retiredObservationSessions.size() >= 64))
        return fail(error, "Retired official observation session or session reset limit");
    if (!newObservationSession && m_lastUtc > 0 &&
        (steadyNow < m_lastSteady || utcNow < m_lastUtc ||
         std::abs((utcNow - m_lastUtc) - (steadyNow - m_lastSteady)) > 250))
        m_clockInvalid = true;
    if (newObservationSession) {
        if (!m_observationSession.isEmpty())
            m_retiredObservationSessions.insert(m_observationSession);
        m_observationSession = identity.session;
        m_identityRevision = 0;
        m_identityContent.clear();
        m_clockInvalid = false;
    }
    if (m_clockInvalid)
        return fail(error, "Host clock changed; fresh telemetry session required");
    const QByteArray identityContent = validIdentity ? compact(QVariantMap{
        {"revision", identity.revision}, {"received", identity.received},
        {"lifetime", identity.lifetime}, {"robot", robot},
        {"ingress_session", identity.ingressSession}, {"ingress_sequence", identity.ingressSequence},
        {"queue_age_at_ingest", identity.queueAge}}) : QByteArray{};
    if (validIdentity && (identity.revision < m_identityRevision ||
        (identity.revision == m_identityRevision && identityContent != m_identityContent)))
        return fail(error, "Official identity observation rolled back or changed in place");

    // Work on a copy so a malformed later field cannot partially advance the
    // accepted cut, per-item revisions or source sequence.
    auto nextEntries = m_entries;
    qint64 nextItemRevision = m_itemRevision;
    QVariantList items;
    if (validIdentity) {
        for (auto permission = normalizedPermissions.cbegin(); permission != normalizedPermissions.cend(); ++permission) {
            const auto grants = permission.value().toList();
            if (grants.isEmpty())
                continue;
            const auto admitted = DecisionContext::permitted(snapshot, {permission.key()});
            const auto groups = admitted.value("groups").toMap();
            for (auto group = groups.cbegin(); group != groups.cend(); ++group) {
                Observation positionOwner;
                if (group.key() == "robotPosition" &&
                    (!observation(allObservations.value("robotPosition").toMap().value("robot_id").toMap(),
                                  utcNow, &positionOwner) || positionOwner.session != identity.session))
                    continue;
                const auto fields = group.value().toMap();
                for (auto field = fields.cbegin(); field != fields.cend(); ++field) {
                    const QString path = group.key() + '.' + field.key();
                    const QString itemId = sourceId + ':' + path;
                    if (!id(itemId))
                        return fail(error, "Official source item ID exceeds the wire bound");
                    Observation seen;
                    const auto metadata = allObservations.value(group.key()).toMap().value(field.key()).toMap();
                    if (!observation(metadata, utcNow, &seen) || seen.session != identity.session)
                        continue;
                    qint64 ttl = qMin(seen.lifetime, identity.received + identity.lifetime - seen.received);
                    if (group.key() == "robotPosition")
                        ttl = qMin(ttl, positionOwner.received + positionOwner.lifetime - seen.received);
                    const qint64 remaining = std::min({seen.remaining, identity.remaining,
                                                       seen.received + ttl - utcNow});
                    // The shared scalar contract requires a minimum 100 ms
                    // original lifetime; never round a shorter cap upward.
                    if (ttl < 100 || remaining <= 0)
                        continue;
                    const QByteArray sample = compact(QVariantMap{
                        {"session", seen.session}, {"revision", seen.revision}, {"received", seen.received},
                        {"lifetime", seen.lifetime}, {"value", field.value()},
                        {"ingress_session", seen.ingressSession}, {"ingress_sequence", seen.ingressSequence},
                        {"queue_age_at_ingest", seen.queueAge}});
                    auto entry = nextEntries.value(path);
                    if (entry.observationSession == seen.session &&
                        (seen.revision < entry.observationRevision ||
                         (seen.revision == entry.observationRevision && entry.observationContent != sample)))
                        return fail(error, "Official observation revision rolled back or changed in place");
                    const bool newSample = entry.observationSession != seen.session ||
                                           entry.observationRevision != seen.revision;
                    if (newSample)
                        entry.fieldDeadline = steadyNow + qMin(seen.remaining,
                                                              seen.received + seen.lifetime - utcNow);
                    const QByteArray version = compact(QVariantMap{
                        {"sample", QString::fromUtf8(sample)}, {"grants", grants}, {"ttl", ttl},
                        {"identity_session", identity.session}, {"identity_revision", identity.revision},
                        {"identity_received", identity.received}, {"identity_lifetime", identity.lifetime},
                        {"player_export_id", playerExportId}, {"category", permission.key()},
                        {"position_owner_revision", positionOwner.revision},
                        {"position_owner_received", positionOwner.received},
                        {"position_owner_lifetime", positionOwner.lifetime}});
                    if (entry.versionContent != version) {
                        if (nextItemRevision >= SafeInteger)
                            return fail(error, "Official item revision exhausted");
                        entry.observationSession = seen.session;
                        entry.observationRevision = seen.revision;
                        entry.observationContent = sample;
                        entry.versionContent = version;
                        entry.deadline = qMin(entry.fieldDeadline, steadyNow + remaining);
                        entry.revision = ++nextItemRevision;
                        entry.item = {{"item_id", itemId}, {"revision", entry.revision},
                            {"source_kind", "official_player_client"}, {"category", permission.key()},
                            {"path", path}, {"data_type", field.value().metaType().id() == QMetaType::Bool ? "boolean" : "number"},
                            {"value", field.value()}, {"lifecycle", "active"},
                            {"observed_at_ms", seen.received}, {"received_at_ms", seen.received},
                            {"source_time_ms", QVariant()}, {"source_clock_domain", "unknown"},
                            {"ttl_ms", ttl}, {"source_snapshot_id", newId()},
                            {"sensor_id", ""}, {"adapter_id", "official.telemetry.v2"},
                            {"producer_version", "2"}, {"player_export_id", playerExportId},
                            {"confidence", QVariant()}, {"measurement_validation", "operator_confirmed_endpoint"},
                            {"allowed_uses", grants}};
                        nextEntries[path] = entry;
                    }
                    if (entry.deadline > steadyNow)
                        items.append(entry.item);
                    if (items.size() > 64)
                        return fail(error, "Official source snapshot exceeds 64 items");
                }
            }
        }
    }
    const auto members = compact(items);
    if (members == m_lastMembers && !m_lastCut.isEmpty()) {
        m_lastUtc = utcNow;
        m_lastSteady = steadyNow;
        if (validIdentity) {
            m_identityRevision = identity.revision;
            m_identityContent = identityContent;
        }
        return m_lastCut;
    }
    if (m_sequence >= SafeInteger)
        return fail(error, "Official source sequence exhausted");
    QVariantMap cut{{"schema", 2}, {"kind", "source-snapshot"}, {"source_id", sourceId},
                    {"session_id", sessionId}, {"robot_id", int(robot)}, {"sequence", m_sequence + 1},
                    {"snapshot_id", newId()}, {"items", items}};
    if (compact(cut).size() > 64 * 1024)
        return fail(error, "Official source snapshot exceeds 64 KiB");
    m_entries = std::move(nextEntries);
    m_itemRevision = nextItemRevision;
    m_sourceId = sourceId;
    m_sessionId = sessionId;
    m_robotId = int(robot);
    ++m_sequence;
    m_lastMembers = members;
    m_lastCut = cut;
    m_lastUtc = utcNow;
    m_lastSteady = steadyNow;
    if (validIdentity) {
        m_identityRevision = identity.revision;
        m_identityContent = identityContent;
    }
    return cut;
}
