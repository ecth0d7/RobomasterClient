#include "TeamViewCache.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QSet>
#include <algorithm>
#include <cmath>

namespace {
constexpr qint64 SafeInteger = 9007199254740991LL;
constexpr qsizetype ViewLimit = 256 * 1024;
constexpr qsizetype EnvelopeLimit = ViewLimit + 1024;
const QSet<QString> Purposes{"hud", "alerts", "localAi", "externalAi", "voice"};
const QSet<QString> Categories{"health", "resources", "position", "objective", "sensorEvents", "visionDiscoveries", "derived"};

bool fail(QString *error, const char *message) {
    if (error) *error = QString::fromLatin1(message);
    return false;
}
bool numeric(const QVariant &v, double *out = nullptr) {
    switch (v.metaType().id()) {
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double: case QMetaType::Float:
    case QMetaType::Long: case QMetaType::ULong: case QMetaType::Short:
    case QMetaType::UShort: case QMetaType::Char: case QMetaType::UChar: break;
    default: return false;
    }
    const auto n = v.toDouble();
    if (!std::isfinite(n) || std::abs(n) > double(SafeInteger)) return false;
    if (out) *out = n;
    return true;
}
bool integer(const QVariant &v, qint64 low, qint64 high, qint64 *out = nullptr) {
    double n = 0;
    if (!numeric(v, &n) || n != std::floor(n) || n < double(low) || n > double(high)) return false;
    if (out) *out = qint64(n);
    return true;
}
bool null(const QVariant &v) { return !v.isValid() || v.metaType().id() == QMetaType::Nullptr; }
bool text(const QVariant &v, qsizetype limit, bool empty = false) {
    if (v.metaType().id() != QMetaType::QString) return false;
    const auto s = v.toString();
    if ((!empty && s.isEmpty()) || s.size() > limit) return false;
    for (auto ch : s) if (ch.isNull() || ch.category() == QChar::Other_Control) return false;
    return true;
}
bool id(const QVariant &v, qsizetype limit = 96) {
    if (!text(v, limit)) return false;
    for (auto ch : v.toString()) {
        const auto u = ch.unicode();
        if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') || (u >= '0' && u <= '9') ||
              u == '_' || u == '-' || u == '.' || u == ':' || u == '/')) return false;
    }
    return true;
}
bool nodeId(const QVariant &v) {
    return id(v, 64) && !v.toString().contains(':') && !v.toString().contains('/');
}
bool path(const QVariant &v) {
    if (!id(v, 128)) return false;
    const auto s = v.toString();
    return !s.startsWith('.') && !s.endsWith('.') && !s.contains("..") && !s.contains(':') && !s.contains('/');
}
bool keys(const QVariantMap &map, const QSet<QString> &required, const QSet<QString> &optional = {}) {
    for (const auto &key : required) if (!map.contains(key)) return false;
    for (auto it = map.cbegin(); it != map.cend(); ++it)
        if (!required.contains(it.key()) && !optional.contains(it.key())) return false;
    return true;
}
bool boolean(const QVariant &v) { return v.metaType().id() == QMetaType::Bool; }
bool robotNumber(const QVariant &v, qint64 *out) {
    qint64 robot = 0;
    if (!integer(v, 1, 109, &robot) || !((robot <= 7) || robot == 9 ||
        (robot >= 101 && robot <= 107) || robot == 109)) return false;
    *out = robot; return true;
}
// Check shape before QVariant -> JSON conversion: arbitrary registered metatypes
// must never invoke conversion hooks or bypass the size/depth budget.
bool jsonShape(const QVariant &v, int depth, qsizetype *cost, int *nodes, qsizetype limit) {
    if (depth > 8 || ++*nodes > 32768 || *cost > limit) return false;
    if (null(v)) { *cost += 4; return true; }
    switch (v.metaType().id()) {
    case QMetaType::QVariantMap:
        *cost += 2;
        {
            const auto map = v.toMap();
            for (auto it = map.cbegin(); it != map.cend(); ++it) {
                *cost += it.key().size() + 4;
                if (!jsonShape(it.value(), depth + 1, cost, nodes, limit)) return false;
            }
        }
        break;
    case QMetaType::QVariantList:
        *cost += 2;
        for (const auto &entry : v.toList()) if (!jsonShape(entry, depth + 1, cost, nodes, limit)) return false;
        break;
    case QMetaType::QString: *cost += v.toString().size() + 2; break;
    case QMetaType::Bool: *cost += 5; break;
    default: if (!numeric(v)) return false; ++*cost;
    }
    return *cost <= limit;
}
QByteArray compact(const QVariantMap &map) {
    return QJsonDocument(QJsonObject::fromVariantMap(map)).toJson(QJsonDocument::Compact);
}
bool bounded(const QVariantMap &map, qsizetype limit) {
    qsizetype cost = 0; int nodes = 0;
    return jsonShape(map, 0, &cost, &nodes, limit) && compact(map).size() <= limit;
}
bool choices(const QVariant &v, const QSet<QString> &allowed, QSet<QString> *out) {
    if (v.metaType().id() != QMetaType::QVariantList || v.toList().size() > allowed.size()) return false;
    QSet<QString> result;
    for (const auto &entry : v.toList()) {
        if (!text(entry, 32) || !allowed.contains(entry.toString()) || result.contains(entry.toString())) return false;
        result.insert(entry.toString());
    }
    *out = std::move(result); return true;
}
QVariantList list(const QSet<QString> &values) {
    auto sorted = values.values(); std::sort(sorted.begin(), sorted.end()); QVariantList result;
    for (const auto &s : sorted) result.append(s);
    return result;
}
qint64 age(qint64 now, qint64 then) { return std::max(qint64(0), now - then); }
qint64 saturatedAdd(qint64 a, qint64 b) {
    return std::clamp(a + b, -SafeInteger, SafeInteger);
}
QString fieldKey(const QVariantMap &field) {
    return field.value("source_node").toString() + QChar(0x1f) + field.value("source_session_id").toString()
        + QChar(0x1f) + field.value("item_id").toString();
}
QVariantMap immutableField(QVariantMap field) {
    for (const auto &key : {"kind", "state", "accepted", "remaining_ms", "received_age_ms", "trust",
                            "field_revision", "snapshot_id", "allowed_uses"}) field.remove(key);
    // source_allowed_uses carries the original immutable source grant. The
    // effective allowed_uses is an intersection which may only narrow.
    return field;
}
bool discovery(const QVariant &v) {
    if (v.metaType().id() != QMetaType::QVariantMap) return false;
    const auto map = v.toMap();
    if (!keys(map, {"summary"}, {"x", "y", "yaw", "frame_id", "frame_revision", "unit", "transform_id"}) ||
        !text(map.value("summary"), 180)) return false;
    bool positioned = false;
    for (const auto &key : {"x", "y", "yaw"}) {
        if (!map.contains(key)) continue;
        positioned = true;
        if (!numeric(map.value(key))) return false;
    }
    for (const auto &key : {"frame_id", "frame_revision", "unit", "transform_id"})
        if ((positioned || map.contains(key)) && !text(map.value(key), 96)) return false;
    return true;
}

struct Config {
    bool valid = false;
    QString team, match, epoch, node, publisher, revision;
    qint64 timeout = 0, skew = 0;
    QMap<QString, qint64> roster;
    QSet<QString> senders;
    QSet<QString> categories, purposes;
    QMap<QString, QSet<QString>> categoryPurposes;
};
struct Item {
    qint64 revision = 0, deadline = 0, receivedAge = 0, acceptedTick = 0;
    QByteArray content;
    QSet<QString> grants;
    bool quarantined = false;
    QString terminalState;
};
bool validateField(const QVariantMap &field, const Config &c, qint64 producedUtc, QString *error) {
    static const QSet<QString> required{"item_id", "revision", "source_kind", "category", "path", "data_type", "value",
        "lifecycle", "observed_at_ms", "source_time_ms", "source_clock_domain", "received_at_ms", "ttl_ms",
        "source_snapshot_id", "sensor_id", "adapter_id", "producer_version", "confidence", "measurement_validation",
        "allowed_uses", "source_node", "source_robot", "source_session_id", "kind", "state", "accepted", "remaining_ms",
        "received_age_ms", "trust", "field_revision", "snapshot_id", "source_allowed_uses"};
    static const QSet<QString> optional{"player_export_id", "dependencies", "algorithm_id", "algorithm_version", "unit"};
    qint64 revision = 0, robot = 0, observed = 0, received = 0, ttl = 0, remaining = 0;
    if (!keys(field, required, optional) || !id(field.value("item_id")) ||
        !integer(field.value("revision"), 1, SafeInteger, &revision) ||
        !integer(field.value("field_revision"), revision, revision) || !nodeId(field.value("source_node")) ||
        !robotNumber(field.value("source_robot"), &robot) || c.roster.value(field.value("source_node").toString(), 0) != robot ||
        !c.senders.contains(field.value("source_node").toString()) ||
        !id(field.value("source_session_id"), 128) || !id(field.value("source_snapshot_id")) || !id(field.value("snapshot_id")) ||
        !path(field.value("path")) || !integer(field.value("observed_at_ms"), 1, SafeInteger, &observed) ||
        !integer(field.value("received_at_ms"), 1, SafeInteger, &received) ||
        !integer(field.value("ttl_ms"), 100, 60000, &ttl) ||
        !integer(field.value("remaining_ms"), 0, std::min(ttl, c.timeout), &remaining) ||
        !integer(field.value("received_age_ms"), 0, SafeInteger) || observed > saturatedAdd(producedUtc, c.skew) ||
        received < observed - c.skew || received > saturatedAdd(producedUtc, c.skew) ||
        (!null(field.value("source_time_ms")) && !integer(field.value("source_time_ms"), 0, SafeInteger)) ||
        !text(field.value("source_clock_domain"), 96) || !text(field.value("sensor_id"), 96, true) ||
        !text(field.value("adapter_id"), 96, true) || !text(field.value("producer_version"), 96, true) ||
        !boolean(field.value("accepted")) || field.value("trust") != "authenticated_peer_relay" ||
        !text(field.value("trust"), 40) || !text(field.value("kind"), 32) ||
        !text(field.value("source_kind"), 32) || field.value("kind") != field.value("source_kind"))
        return fail(error, "Invalid projected field identity, time or provenance");
    if (field.value("source_clock_domain") == "unknown" && !null(field.value("source_time_ms")))
        return fail(error, "An unknown producer clock cannot supply a claimed producer timestamp");
    const auto state = field.value("state").toString();
    if (!text(field.value("state"), 16) || !QSet<QString>{"fresh", "stale", "conflict", "withdrawn"}.contains(state) ||
        field.value("accepted").toBool() != (state == "fresh") ||
        (state == "fresh" ? remaining <= 0 : remaining != 0)) return fail(error, "Invalid projected field lifecycle");
    if (!text(field.value("lifecycle"), 16) || !QSet<QString>{"active", "withdrawn"}.contains(field.value("lifecycle").toString()) ||
        (field.value("lifecycle") == "withdrawn" && state == "fresh")) return fail(error, "Withdrawn item cannot be fresh");
    const auto kind = field.value("source_kind").toString(), category = field.value("category").toString();
    const auto validation = field.value("measurement_validation").toString();
    if (!text(field.value("category"), 32) || !Categories.contains(category) || !c.categories.contains(category) ||
        !text(field.value("measurement_validation"), 40) ||
        !QSet<QString>{"unverified", "operator_confirmed_endpoint", "validated_measurement", "derived"}.contains(validation))
        return fail(error, "Invalid field category or measurement provenance");
    if (kind == "official_player_client") {
        if (!QSet<QString>{"health", "resources", "position", "objective"}.contains(category) ||
            !text(field.value("player_export_id"), 128) || validation == "derived" || field.value("data_type") == "discovery")
            return fail(error, "Official relay field lacks explicit official export provenance");
    } else if (kind == "local_sensor") {
        if (category != "sensorEvents" || validation == "derived") return fail(error, "Sensor field source/category mismatch");
    } else if (kind == "local_vision") {
        if (category != "visionDiscoveries" || validation == "derived") return fail(error, "Vision field source/category mismatch");
    } else if (kind == "derived") {
        if (category != "derived" || validation != "derived" || !id(field.value("algorithm_id")) ||
            !text(field.value("algorithm_version"), 96)) return fail(error, "Derived field lacks algorithm provenance");
    } else return fail(error, "Unknown or mock production source kind");
    const auto type = field.value("data_type").toString();
    if (!text(field.value("data_type"), 16) ||
        (type == "number" ? !numeric(field.value("value")) :
         type == "boolean" ? !boolean(field.value("value")) :
         type == "discovery" ? !discovery(field.value("value")) : true))
        return fail(error, "Invalid typed projected field value");
    double confidence = 0;
    if (!null(field.value("confidence")) && (!numeric(field.value("confidence"), &confidence) || confidence < 0 || confidence > 1))
        return fail(error, "Invalid measurement confidence");
    QSet<QString> effective, original;
    if (!choices(field.value("allowed_uses"), Purposes, &effective) ||
        !choices(field.value("source_allowed_uses"), Purposes, &original) || !original.contains(effective))
        return fail(error, "Projected field purposes exceed source consent");
    if (field.contains("dependencies")) {
        if (field.value("dependencies").metaType().id() != QMetaType::QVariantList || field.value("dependencies").toList().size() > 16)
            return fail(error, "Invalid derived dependency list");
        QSet<QString> seen;
        for (const auto &v : field.value("dependencies").toList()) {
            if (!id(v) || seen.contains(v.toString()) || v == field.value("item_id")) return fail(error, "Invalid derived dependency identity");
            seen.insert(v.toString());
        }
    }
    for (const auto &key : {"algorithm_id", "algorithm_version", "player_export_id", "unit"})
        if (field.contains(key) && !(QString::fromLatin1(key) == "algorithm_id" ? id(field.value(key)) :
            text(field.value(key), QString::fromLatin1(key) == "unit" ? 48 : QString::fromLatin1(key) == "player_export_id" ? 128 : 96,
                 QString::fromLatin1(key) == "player_export_id"))) return fail(error, "Invalid optional field provenance");
    return true;
}
}

struct TeamViewCache::Private {
    Config config;
    QVariantMap cut;
    QByteArray identity;
    qint64 revision = 0, acceptedUtc = 0, acceptedTick = 0, producedTick = 0;
    QMap<QString, Item> highwater;
};
TeamViewCache::TeamViewCache() : d(std::make_unique<Private>()) {}
TeamViewCache::~TeamViewCache() = default;
TeamViewCache::TeamViewCache(TeamViewCache &&) noexcept = default;
TeamViewCache &TeamViewCache::operator=(TeamViewCache &&) noexcept = default;

void TeamViewCache::reset(const QVariantMap &nativeConfiguration) {
    d = std::make_unique<Private>();
    auto &c = d->config;
    auto expected = nativeConfiguration;
    // The host's native configuration uses QStringList for these two unions.
    // Normalize only this known local representation; wire arrays stay strict.
    for (const auto &key : {"allowed_categories", "allowed_uses"}) {
        if (expected.value(key).metaType().id() != QMetaType::QStringList) continue;
        QVariantList entries;
        for (const auto &entry : expected.value(key).toStringList()) entries.append(entry);
        expected[key] = entries;
    }
    // Only copied scope/roster/permission references survive this call. Private
    // key paths, certificate paths and the native adapter configuration do not.
    qint64 ownRobot = 0;
    if (!bounded(expected, 128 * 1024) || !nodeId(expected.value("team_id")) ||
        !nodeId(expected.value("match_id")) || !nodeId(expected.value("epoch")) || !nodeId(expected.value("node_id")) ||
        !nodeId(expected.value("publisher_id")) || !text(expected.value("configuration_revision"), 64) ||
        !robotNumber(expected.value("robot_id"), &ownRobot) || !boolean(expected.value("can_send")) ||
        !boolean(expected.value("can_aggregate")) ||
        !integer(expected.value("timeout_ms"), 750, 60000, &c.timeout) ||
        !integer(expected.value("max_clock_skew_ms", 0), 0, 1000, &c.skew) ||
        expected.value("peers").metaType().id() != QMetaType::QVariantList || expected.value("peers").toList().size() > 15 ||
        !choices(expected.value("allowed_uses", QVariantList{}), Purposes, &c.purposes) ||
        !choices(expected.value("allowed_categories", QVariantList{}), Categories, &c.categories)) return;
    const auto matrixValue = expected.value("category_permissions", QVariantMap{});
    if (matrixValue.metaType().id() != QMetaType::QVariantMap) return;
    const auto matrix = matrixValue.toMap(); QSet<QString> matrixCategories, matrixPurposes;
    for (auto it = matrix.cbegin(); it != matrix.cend(); ++it) {
        QSet<QString> grants;
        if (!Categories.contains(it.key()) || !choices(it.value(), Purposes, &grants) || grants.isEmpty()) return;
        c.categoryPurposes.insert(it.key(), grants); matrixCategories.insert(it.key()); matrixPurposes.unite(grants);
    }
    if (matrixCategories != c.categories || matrixPurposes != c.purposes) return;
    c.team = expected.value("team_id").toString(); c.match = expected.value("match_id").toString();
    c.epoch = expected.value("epoch").toString(); c.node = expected.value("node_id").toString();
    c.publisher = expected.value("publisher_id").toString(); c.revision = expected.value("configuration_revision").toString();
    c.roster.insert(c.node, ownRobot); QSet<qint64> robots{ownRobot};
    if (expected.value("can_send").toBool()) c.senders.insert(c.node);
    QSet<QString> publishers;
    if (boolean(expected.value("can_aggregate")) && expected.value("can_aggregate").toBool()) publishers.insert(c.node);
    for (const auto &v : expected.value("peers").toList()) {
        if (v.metaType().id() != QMetaType::QVariantMap) return;
        const auto peer = v.toMap(); qint64 robot = 0;
        if (!nodeId(peer.value("node_id")) || !robotNumber(peer.value("robot_id"), &robot) ||
            !boolean(peer.value("can_send")) || !boolean(peer.value("can_aggregate")) ||
            c.roster.contains(peer.value("node_id").toString()) || robots.contains(robot) ||
            (robot >= 100) != (ownRobot >= 100)) return;
        c.roster.insert(peer.value("node_id").toString(), robot); robots.insert(robot);
        if (peer.value("can_send").toBool()) c.senders.insert(peer.value("node_id").toString());
        if (boolean(peer.value("can_aggregate")) && peer.value("can_aggregate").toBool()) publishers.insert(peer.value("node_id").toString());
    }
    c.valid = publishers.contains(c.publisher);
}

bool TeamViewCache::accept(const QVariantMap &message, qint64 utcNow, qint64 steadyNow, QString *error) {
    if (error) error->clear();
    const auto &c = d->config;
    qint64 producedUtc = 0, producedTick = 0;
    if (!c.valid || !integer(utcNow, 1, SafeInteger) || !integer(steadyNow, 0, SafeInteger) ||
        !bounded(message, EnvelopeLimit) || !keys(message, {"schema", "kind", "produced_at_ms", "produced_tick_ms", "payload"}, {"configuration_revision"}) ||
        !integer(message.value("schema"), 2, 2) || message.value("kind") != "aggregation-view" ||
        !text(message.value("kind"), 32) || !integer(message.value("produced_at_ms"), 1, utcNow, &producedUtc) ||
        !integer(message.value("produced_tick_ms"), 0, steadyNow, &producedTick) ||
        std::abs((utcNow - producedUtc) - (steadyNow - producedTick)) > 1000 + c.skew ||
        (message.contains("configuration_revision") && message.value("configuration_revision") != c.revision) ||
        message.value("payload").metaType().id() != QMetaType::QVariantMap)
        return fail(error, "Invalid bounded aggregation envelope, configuration or emission clock sample");
    const auto payload = message.value("payload").toMap(); qint64 revision = 0;
    if (!bounded(payload, ViewLimit) || !keys(payload, {"schema", "view_id", "revision", "team_id", "match_id", "epoch", "issuer_id", "generated_at_ms", "members", "fields", "excluded", "channel_connected"}) ||
        !integer(payload.value("schema"), 2, 2) || !id(payload.value("view_id"), 128) ||
        !integer(payload.value("revision"), 1, SafeInteger, &revision) || payload.value("team_id") != c.team ||
        payload.value("match_id") != c.match || payload.value("epoch") != c.epoch || payload.value("issuer_id") != c.publisher ||
        !text(payload.value("team_id"), 64) || !text(payload.value("match_id"), 64) || !text(payload.value("epoch"), 64) ||
        !text(payload.value("issuer_id"), 64) || !integer(payload.value("generated_at_ms"), 1, saturatedAdd(producedUtc, c.skew)) ||
        !boolean(payload.value("channel_connected")) || payload.value("members").metaType().id() != QMetaType::QVariantList ||
        payload.value("fields").metaType().id() != QMetaType::QVariantList || payload.value("excluded").metaType().id() != QMetaType::QVariantList ||
        payload.value("members").toList().size() > 16 || payload.value("fields").toList().size() > 512 || payload.value("excluded").toList().size() > 64)
        return fail(error, "Invalid complete aggregation cut scope or collection limits");
    if (revision < d->revision || (revision == d->revision && payload.value("view_id") != d->cut.value("view_id")))
        return fail(error, "A lower or changed same-revision aggregation cut cannot replace the host cache");
    QMap<QString, QVariantMap> members; QVariantList memberIdentity;
    for (const auto &v : payload.value("members").toList()) {
        if (v.metaType().id() != QMetaType::QVariantMap) return fail(error, "Invalid aggregation member type");
        const auto member = v.toMap(); qint64 robot = 0;
        if (!keys(member, {"node_id", "robot_id", "state", "age_ms", "auth", "player_export_id", "snapshot_id", "source_session_id"}) ||
            !nodeId(member.value("node_id")) || !robotNumber(member.value("robot_id"), &robot) ||
            c.roster.value(member.value("node_id").toString(), 0) != robot || members.contains(member.value("node_id").toString()) ||
            !id(member.value("source_session_id"), 128) || !id(member.value("snapshot_id")) ||
            !text(member.value("state"), 16) || !QSet<QString>{"online", "offline", "stale"}.contains(member.value("state").toString()) ||
            !integer(member.value("age_ms"), 0, SafeInteger) || !text(member.value("auth"), 40) || member.value("auth") != "authenticated_peer_relay" ||
            !text(member.value("player_export_id"), 128, true)) return fail(error, "Invalid aggregation member identity or provenance");
        if (member.value("state") == "online" && member.value("age_ms").toLongLong() >= c.timeout)
            return fail(error, "An expired heartbeat cannot claim an online member");
        members.insert(member.value("node_id").toString(), member);
    }
    for (const auto &member : members) {
        auto identity = member; identity.remove("state"); identity.remove("age_ms"); memberIdentity.append(identity);
    }
    QMap<QString, QVariantMap> fields; QVariantList fieldIdentity; int discoveries = 0;
    QMap<QString, QSet<QString>> exports;
    QSet<QString> semanticPaths;
    auto highwater = d->highwater;
    for (const auto &v : payload.value("fields").toList()) {
        if (v.metaType().id() != QMetaType::QVariantMap) return fail(error, "Invalid aggregation field type");
        const auto field = v.toMap();
        if (!validateField(field, c, producedUtc, error)) return false;
        const auto node = field.value("source_node").toString(), key = fieldKey(field);
        const auto member = members.value(node);
        if (member.isEmpty() || member.value("source_session_id") != field.value("source_session_id") ||
            member.value("snapshot_id") != field.value("snapshot_id") || fields.contains(key))
            return fail(error, "Aggregation field does not belong to its selected source snapshot/session");
        if (field.value("state") == "fresh" && member.value("state") != "online")
            return fail(error, "Offline or stale member cannot supply a fresh field");
        if (field.value("source_kind") == "official_player_client") exports[node].insert(field.value("player_export_id").toString());
        const auto semantic = node + QChar(0x1f) + field.value("path").toString();
        if (semanticPaths.contains(semantic)) return fail(error, "Duplicate source semantic path");
        semanticPaths.insert(semantic);
        if (field.value("data_type") == "discovery" && ++discoveries > 64) return fail(error, "Aggregation discovery limit exceeded");
        const auto immutable = compact(immutableField(field));
        const auto itemRevision = field.value("revision").toLongLong();
        QSet<QString> grants; choices(field.value("allowed_uses"), Purposes, &grants);
        grants.intersect(c.categoryPurposes.value(field.value("category").toString()));
        auto item = highwater.value(key);
        if (item.revision > itemRevision || (item.revision == itemRevision && item.content != immutable))
            return fail(error, "Lower item revision or changed same-revision item content");
        const auto remaining = field.value("remaining_ms").toLongLong();
        const auto emissionBudget = remaining - (steadyNow - producedTick);
        const auto observedExpiry = saturatedAdd(field.value("observed_at_ms").toLongLong(), field.value("ttl_ms").toLongLong());
        const auto deadline = std::min({saturatedAdd(steadyNow, emissionBudget),
            saturatedAdd(steadyNow, observedExpiry - utcNow - c.skew),
            saturatedAdd(producedTick, c.timeout - member.value("age_ms").toLongLong())});
        if (item.revision == itemRevision) {
            if (!item.grants.contains(grants)) return fail(error, "Same-revision item purpose grants cannot expand");
            item.deadline = std::min(item.deadline, deadline);
            item.grants.intersect(grants);
        } else {
            item = {}; item.revision = itemRevision; item.content = immutable; item.deadline = deadline;
            item.acceptedTick = steadyNow;
            item.receivedAge = saturatedAdd(field.value("received_age_ms").toLongLong(), steadyNow - producedTick);
            item.grants = grants;
        }
        const auto state = field.value("state").toString();
        if (state != "fresh") {
            item.quarantined = true;
            if (state == "conflict" || state == "withdrawn" || item.terminalState.isEmpty()) item.terminalState = state;
        }
        if (item.quarantined && state == "fresh") return fail(error, "A quarantined item needs a higher revision before becoming fresh");
        highwater.insert(key, item);
        if (highwater.size() > 2048) return fail(error, "Host item highwater exhausted; reset the configured epoch");
        fields.insert(key, field);
    }
    for (auto it = members.cbegin(); it != members.cend(); ++it) {
        const auto references = exports.value(it.key());
        const auto expected = references.size() == 1 ? *references.cbegin() : QString();
        if (it->value("player_export_id").toString() != expected)
            return fail(error, "Member official export reference does not match its selected fields");
    }
    for (const auto &field : fields) fieldIdentity.append(immutableField(field));
    for (const auto &v : payload.value("excluded").toList()) {
        if (v.metaType().id() != QMetaType::QVariantMap) return fail(error, "Invalid exclusion type");
        const auto exclusion = v.toMap();
        if (!keys(exclusion, {"node_id", "reason", "count"}) || !members.contains(exclusion.value("node_id").toString()) ||
            !text(exclusion.value("node_id"), 64) || !text(exclusion.value("reason"), 32) ||
            !QSet<QString>{"member_offline", "stale", "conflict", "withdrawn"}.contains(exclusion.value("reason").toString()) ||
            !integer(exclusion.value("count"), 1, 512)) return fail(error, "Invalid exclusion reason or source");
    }
    auto identity = payload;
    identity["members"] = memberIdentity; identity["fields"] = fieldIdentity;
    identity.remove("excluded"); identity.remove("channel_connected");
    const auto identityBytes = compact(identity);
    if (revision == d->revision && identityBytes != d->identity) return fail(error, "A committed cut cannot change its immutable content or selected source set");
    // Commit only after every collection, item and highwater transition passes.
    d->cut = payload; d->identity = identityBytes; d->revision = revision;
    d->acceptedUtc = utcNow; d->acceptedTick = steadyNow; d->producedTick = producedTick;
    d->highwater = std::move(highwater);
    return true;
}

QVariantMap TeamViewCache::view(qint64 utcNow, qint64 steadyNow, bool channelConnected) const {
    if (!d->config.valid || d->cut.isEmpty()) return {};
    auto result = d->cut;
    const bool clockValid = integer(utcNow, d->acceptedUtc, SafeInteger) && integer(steadyNow, d->acceptedTick, SafeInteger) &&
        std::abs((utcNow - d->acceptedUtc) - (steadyNow - d->acceptedTick)) <= 1000 + d->config.skew;
    const bool connected = channelConnected && result.value("channel_connected").toBool() && clockValid;
    QVariantList fields;
    for (const auto &v : result.value("fields").toList()) {
        auto field = v.toMap(); const auto item = d->highwater.value(fieldKey(field));
        const auto remaining = connected && !item.quarantined ? std::max(qint64(0), item.deadline - steadyNow) : qint64(0);
        field["remaining_ms"] = remaining;
        field["received_age_ms"] = saturatedAdd(item.receivedAge, age(steadyNow, item.acceptedTick));
        field["allowed_uses"] = list(item.grants);
        field["host_source_signatures_verified"] = false;
        if (!remaining || item.quarantined || field.value("state") != "fresh") {
            field["accepted"] = false;
            field["state"] = item.terminalState.isEmpty() ? QStringLiteral("stale") : item.terminalState;
        }
        fields.append(field);
    }
    QVariantList members;
    for (const auto &v : result.value("members").toList()) {
        auto member = v.toMap();
        member["age_ms"] = saturatedAdd(member.value("age_ms").toLongLong(), age(steadyNow, d->producedTick));
        if (!connected) member["state"] = "offline";
        else if (member.value("age_ms").toLongLong() >= d->config.timeout) member["state"] = "stale";
        members.append(member);
    }
    result["fields"] = fields; result["members"] = members; result["channel_connected"] = connected;
    result["host_scope_validated"] = true; result["host_source_signatures_verified"] = false;
    result["ai_input_ready"] = false;
    result["configuration_revision"] = d->config.revision;
    result["host_view_age_ms"] = age(steadyNow, d->producedTick);
    result["validation_boundary"] = "native_adapter_diagnostics_only";
    return result;
}
