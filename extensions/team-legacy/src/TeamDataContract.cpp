#include "TeamDataContract.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QSet>
#include <algorithm>
#include <cmath>
#include <limits>

namespace TeamDataContract {
namespace {
constexpr qint64 SafeInteger = 9007199254740991LL;
constexpr qsizetype SourceLimit = 16 * 1024;
constexpr qsizetype ViewLimit = 256 * 1024;
constexpr qsizetype ProofLimit = 48 * 1024;

bool fail(QString *error, const char *reason) {
    if (error) *error = QString::fromLatin1(reason);
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
    const double n = v.toDouble();
    if (!std::isfinite(n) || std::abs(n) > double(SafeInteger)) return false;
    if (out) *out = n;
    return true;
}
bool integer(const QVariant &v, qint64 low, qint64 high, qint64 *out = nullptr) {
    double n = 0;
    if (!numeric(v, &n) || std::floor(n) != n || n < double(low) || n > double(high)) return false;
    if (out) *out = qint64(n);
    return true;
}
bool null(const QVariant &v) {
    return !v.isValid() || v.metaType().id() == QMetaType::Nullptr;
}
bool text(const QVariant &v, qsizetype maximum, bool empty = false) {
    if (v.metaType().id() != QMetaType::QString) return false;
    const auto s = v.toString();
    if ((!empty && s.isEmpty()) || s.size() > maximum) return false;
    for (const auto ch : s) if (ch.isNull() || ch.category() == QChar::Other_Control) return false;
    return true;
}
bool id(const QVariant &v, qsizetype maximum = 96) {
    if (!text(v, maximum)) return false;
    for (const auto c : v.toString()) {
        const auto u = c.unicode();
        if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') ||
              (u >= '0' && u <= '9') || u == '_' || u == '-' || u == '.' || u == ':' || u == '/')) return false;
    }
    return true;
}
bool topicId(const QVariant &v) {
    if (!id(v, 64)) return false;
    return !v.toString().contains(':') && !v.toString().contains('/');
}
bool dottedPath(const QVariant &v) {
    if (!id(v, 128)) return false;
    const auto s = v.toString();
    return !s.startsWith('.') && !s.endsWith('.') && !s.contains("..") &&
           !s.contains(':') && !s.contains('/');
}
bool keys(const QVariantMap &map, const QSet<QString> &required, const QSet<QString> &optional = {}) {
    for (const auto &key : required) if (!map.contains(key)) return false;
    for (auto it = map.cbegin(); it != map.cend(); ++it)
        if (!required.contains(it.key()) && !optional.contains(it.key())) return false;
    return true;
}
bool flag(const QVariantMap &map, const QString &key, bool *out) {
    if (!map.contains(key)) { *out = false; return true; }
    if (map.value(key).metaType().id() != QMetaType::Bool) return false;
    *out = map.value(key).toBool(); return true;
}
bool jsonType(const QVariant &v, int depth, qsizetype maximum, qsizetype *cost, int *nodes) {
    if (depth > 8 || ++*nodes > 8192 || *cost > maximum) return false;
    if (null(v)) { *cost += 4; return true; }
    switch (v.metaType().id()) {
    case QMetaType::QVariantMap: {
        const auto map = v.toMap(); *cost += 2;
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            *cost += it.key().size() + 4;
            if (!jsonType(it.value(), depth + 1, maximum, cost, nodes)) return false;
        }
        break;
    }
    case QMetaType::QVariantList:
        *cost += 2;
        for (const auto &entry : v.toList())
            if (!jsonType(entry, depth + 1, maximum, cost, nodes)) return false;
        break;
    case QMetaType::QString: *cost += v.toString().size() + 2; break;
    case QMetaType::Bool: *cost += 5; break;
    default:
        if (!numeric(v)) return false;
        *cost += 1; // A cheap lower bound; the exact UTF-8 size is checked next.
    }
    return *cost <= maximum;
}
QByteArray compact(const QVariantMap &map) {
    return QJsonDocument(QJsonObject::fromVariantMap(map)).toJson(QJsonDocument::Compact);
}
bool bounded(const QVariant &v, qsizetype limit) {
    qsizetype cost = 0; int nodes = 0;
    if (!jsonType(v, 0, limit, &cost, &nodes)) return false;
    return QJsonDocument::fromVariant(v).toJson(QJsonDocument::Compact).size() <= limit;
}
bool times(qint64 utc, qint64 tick) {
    return utc > 0 && utc <= SafeInteger && tick >= 0 && tick <= SafeInteger;
}
qint64 add(qint64 a, qint64 b) {
    if (b > 0 && a > SafeInteger - b) return SafeInteger;
    if (b < 0 && a < -SafeInteger - b) return -SafeInteger;
    return a + b;
}
qint64 age(qint64 now, qint64 then) { return std::max(qint64(0), now - then); }
bool validRobot(qint64 robot) {
    return (robot >= 1 && robot <= 7) || robot == 9 ||
           (robot >= 101 && robot <= 107) || robot == 109;
}
struct Peer { QString node; qint64 robot = 0; bool send = false, aggregate = false; };
struct Config {
    bool configured = false;
    QString team, match, epoch, node, publisher;
    qint64 skew = 0, timeout = 0;
    QMap<QString, Peer> roster;
};
bool sameConfiguration(const Config &a, const Config &b) {
    if (a.team != b.team || a.match != b.match || a.epoch != b.epoch || a.node != b.node ||
        a.publisher != b.publisher || a.skew != b.skew || a.timeout != b.timeout || a.roster.size() != b.roster.size()) return false;
    for (auto it = a.roster.cbegin(); it != a.roster.cend(); ++it) {
        const auto other = b.roster.constFind(it.key());
        if (other == b.roster.cend() || other->robot != it->robot || other->send != it->send || other->aggregate != it->aggregate) return false;
    }
    return true;
}
struct Item {
    QVariantMap content;
    QByteArray bytes;
    qint64 revision = 0, deadline = 0, receivedAge = 0, acceptedTick = 0;
    bool conflict = false;
};
struct Snapshot {
    QVariantMap body, proof;
    QByteArray bytes, proofBytes;
    QString id, session;
    qint64 sequence = 0, deadline = 0;
    QStringList items;
};
struct Member {
    QString session;
    qint64 sessionStarted = 0, sequence = 0, receiveTick = 0, receiveUtc = 0;
    int resets = 0;
    QSet<QString> retired;
    QMap<QString, Item> highwater;
    Snapshot latest;
};
struct Selected {
    QString node, session;
    Snapshot snapshot;
    QMap<QString, Item> items;
};
struct Cut {
    QString id;
    quint64 revision = 0;
    qint64 generated = 0;
    QByteArray identity;
    QMap<QString, Selected> selected;
};
struct State {
    Config config;
    QMap<QString, Member> members;
    Cut cut;
};

bool configureState(const QVariantMap &config, Config *out, QString *error) {
    static const QSet<QString> required{"team_id", "match_id", "epoch", "node_id", "publisher_id", "robot_id",
        "peers", "max_clock_skew_ms", "clocks_synchronized", "timeout_ms"};
    static const QSet<QString> optional{"can_send", "can_aggregate"};
    Config c; qint64 robot = 0; bool synchronized = false; Peer own;
    if (!keys(config, required, optional) || !topicId(config.value("team_id")) ||
        !topicId(config.value("match_id")) || !topicId(config.value("epoch")) ||
        !topicId(config.value("node_id")) || !topicId(config.value("publisher_id")) ||
        !integer(config.value("robot_id"), 1, 109, &robot) || !validRobot(robot) ||
        !integer(config.value("max_clock_skew_ms"), 0, 1000, &c.skew) ||
        !integer(config.value("timeout_ms"), 750, 60000, &c.timeout) ||
        !flag(config, "clocks_synchronized", &synchronized) || !synchronized ||
        !flag(config, "can_send", &own.send) || !flag(config, "can_aggregate", &own.aggregate) ||
        config.value("peers").metaType().id() != QMetaType::QVariantList || config.value("peers").toList().size() > 15)
        return fail(error, "Invalid bounded team scope/clock declaration/roster configuration");
    c.team = config.value("team_id").toString(); c.match = config.value("match_id").toString();
    c.epoch = config.value("epoch").toString(); c.node = config.value("node_id").toString();
    c.publisher = config.value("publisher_id").toString();
    own.node = c.node; own.robot = robot; c.roster.insert(own.node, own);
    QSet<qint64> robots{robot};
    for (const auto &value : config.value("peers").toList()) {
        if (value.metaType().id() != QMetaType::QVariantMap) return fail(error, "Invalid team roster entry");
        const auto p = value.toMap(); Peer peer;
        if (!keys(p, {"node_id", "robot_id", "can_send", "can_aggregate"}) || !topicId(p.value("node_id")) ||
            !integer(p.value("robot_id"), 1, 109, &peer.robot) || !validRobot(peer.robot) ||
            (peer.robot >= 100) != (robot >= 100) || robots.contains(peer.robot) ||
            !flag(p, "can_send", &peer.send) || !flag(p, "can_aggregate", &peer.aggregate))
            return fail(error, "Invalid, mixed-camp or duplicate team roster robot");
        peer.node = p.value("node_id").toString();
        if (c.roster.contains(peer.node)) return fail(error, "Duplicate team roster node");
        c.roster.insert(peer.node, peer); robots.insert(peer.robot);
    }
    if (!c.roster.contains(c.publisher) || !c.roster.value(c.publisher).aggregate)
        return fail(error, "Configured publisher lacks explicit aggregate permission");
    c.configured = true; *out = std::move(c); return true;
}

bool validateItem(const QVariantMap &item, qint64 sent, const Config &c, QString *error) {
    static const QSet<QString> required{"item_id", "revision", "source_kind", "category", "path", "data_type", "value",
        "lifecycle", "observed_at_ms", "source_time_ms", "source_clock_domain", "received_at_ms", "ttl_ms",
        "source_snapshot_id", "sensor_id", "adapter_id", "producer_version", "confidence", "measurement_validation", "allowed_uses"};
    static const QSet<QString> optional{"player_export_id", "dependencies", "algorithm_id", "algorithm_version", "unit"};
    qint64 observed = 0, received = 0;
    if (!keys(item, required, optional) || !id(item.value("item_id")) || !integer(item.value("revision"), 1, SafeInteger) ||
        !dottedPath(item.value("path")) || !integer(item.value("observed_at_ms"), 1, SafeInteger, &observed) ||
        !integer(item.value("received_at_ms"), 1, SafeInteger, &received) ||
        !integer(item.value("ttl_ms"), 100, 60000) || observed > add(sent, c.skew) ||
        received < add(observed, -c.skew) || received > add(sent, c.skew) ||
        (!null(item.value("source_time_ms")) && !integer(item.value("source_time_ms"), 0, SafeInteger)) ||
        !text(item.value("source_clock_domain"), 96) || !id(item.value("source_snapshot_id")) ||
        !text(item.value("sensor_id"), 96, true) || !text(item.value("adapter_id"), 96, true) ||
        !text(item.value("producer_version"), 96, true) ||
        (item.contains("player_export_id") && !text(item.value("player_export_id"), 128, true)) ||
        (item.contains("unit") && !text(item.value("unit"), 48, true)))
        return fail(error, "Invalid item metadata, timestamp, identity or unknown field");
    double confidence = 0;
    if (!null(item.value("confidence")) && (!numeric(item.value("confidence"), &confidence) || confidence < 0 || confidence > 1))
        return fail(error, "Invalid measurement confidence");
    const auto kind = item.value("source_kind");
    const auto category = item.value("category");
    const auto type = item.value("data_type");
    const auto lifecycle = item.value("lifecycle");
    const auto validation = item.value("measurement_validation");
    if (!text(kind, 32) || !text(category, 32) || !text(type, 16) || !text(lifecycle, 16) || !text(validation, 40) ||
        (lifecycle != "active" && lifecycle != "withdrawn") ||
        !QSet<QString>{"unverified", "operator_confirmed_endpoint", "validated_measurement", "derived"}.contains(validation.toString()))
        return fail(error, "Invalid item source/lifecycle/measurement validation");
    if (kind == "official_player_client") {
        if (!QSet<QString>{"health", "resources", "position", "objective"}.contains(category.toString()) ||
            !text(item.value("player_export_id"), 128) || type == "discovery" || validation == "derived")
            return fail(error, "Official relay data requires an export reference and scalar official category");
    } else if (kind == "local_sensor") {
        if (category != "sensorEvents" || validation == "derived") return fail(error, "Sensor data category/source mismatch");
    } else if (kind == "local_vision") {
        if (category != "visionDiscoveries" || validation == "derived") return fail(error, "Vision data category/source mismatch");
    } else if (kind == "derived") {
        if (category != "derived" || validation != "derived" || !id(item.value("algorithm_id")) || !text(item.value("algorithm_version"), 96))
            return fail(error, "Derived data requires explicit algorithm provenance");
    } else return fail(error, "Unsupported production source kind (mock is not accepted)");
    if (type == "number") {
        if (!numeric(item.value("value"))) return fail(error, "Item number must be finite JSON numeric data");
    } else if (type == "boolean") {
        if (item.value("value").metaType().id() != QMetaType::Bool) return fail(error, "Item boolean must be a JSON boolean");
    } else if (type == "discovery") {
        if (kind == "official_player_client" || item.value("value").metaType().id() != QMetaType::QVariantMap)
            return fail(error, "Discovery source/value mismatch");
        const auto discovery = item.value("value").toMap();
        if (!keys(discovery, {"summary"}, {"x", "y", "yaw", "frame_id", "frame_revision", "unit", "transform_id"}) ||
            !text(discovery.value("summary"), 180)) return fail(error, "Invalid discovery shape/summary");
        bool positioned = false;
        for (const auto &coordinate : {QStringLiteral("x"), QStringLiteral("y"), QStringLiteral("yaw")}) {
            if (discovery.contains(coordinate)) {
                positioned = true;
                if (!numeric(discovery.value(coordinate))) return fail(error, "Invalid discovery coordinate");
            }
        }
        for (const auto &metadata : {QStringLiteral("frame_id"), QStringLiteral("frame_revision"), QStringLiteral("unit"), QStringLiteral("transform_id")})
            if (discovery.contains(metadata) && !text(discovery.value(metadata), 96)) return fail(error, "Invalid discovery coordinate metadata");
        // Never draw a position in an assumed map frame. Adapters must explicitly
        // identify the coordinate transform, even when the transform is identity.
        if (positioned && (!text(discovery.value("frame_id"), 96) || !text(discovery.value("frame_revision"), 96) ||
                           !text(discovery.value("unit"), 96) || !text(discovery.value("transform_id"), 96)))
            return fail(error, "Positioned discovery requires an explicit frame/unit/transform reference");
    } else return fail(error, "Unsupported item data type");
    if (item.value("allowed_uses").metaType().id() != QMetaType::QVariantList) return fail(error, "Item purpose grants must be an array");
    QSet<QString> grants;
    for (const auto &purpose : item.value("allowed_uses").toList()) {
        if (!text(purpose, 16) || !QSet<QString>{"hud", "alerts", "localAi", "externalAi", "voice"}.contains(purpose.toString()) || grants.contains(purpose.toString()))
            return fail(error, "Unknown or repeated item purpose grant");
        grants.insert(purpose.toString());
    }
    if (item.contains("dependencies")) {
        if (item.value("dependencies").metaType().id() != QMetaType::QVariantList || item.value("dependencies").toList().size() > 16)
            return fail(error, "Invalid bounded item dependencies");
        QSet<QString> dependencies;
        for (const auto &dependency : item.value("dependencies").toList()) {
            if (!id(dependency) || dependencies.contains(dependency.toString()) || dependency == item.value("item_id"))
                return fail(error, "Invalid duplicate or self-referencing dependency");
            dependencies.insert(dependency.toString());
        }
    }
    if ((item.contains("algorithm_id") && !id(item.value("algorithm_id"))) ||
        (item.contains("algorithm_version") && !text(item.value("algorithm_version"), 96)))
        return fail(error, "Invalid optional algorithm provenance");
    return true;
}

struct Parsed {
    QVariantMap bare, proof;
    QByteArray bytes, proofBytes;
    QString node, session, kind, snapshot;
    qint64 started = 0, sequence = 0, sent = 0, receiveUtc = 0, receiveTick = 0;
    QVariantList items;
};
bool parse(const QVariantMap &body, const Config &c, qint64 utc, qint64 tick, Parsed *out, QString *error) {
    if (!times(utc, tick)) return fail(error, "Invalid caller clock sample");
    Parsed p; p.bare = body; p.bare.remove("_network");
    static const QSet<QString> common{"schema", "kind", "source_node", "robot_id", "team_id", "match_id", "epoch", "session_id",
        "session_started_ms", "sequence", "sent_at_ms"};
    p.kind = body.value("kind").toString();
    if (p.kind != "heartbeat" && p.kind != "node-snapshot") return fail(error, "Store accepts only node snapshots and heartbeats");
    auto required = common;
    if (p.kind == "node-snapshot") required.unite({"snapshot_id", "items"});
    qint64 robot = 0;
    if (!keys(p.bare, required) || !bounded(p.bare, SourceLimit) || !integer(body.value("schema"), 2, 2) ||
        !topicId(body.value("source_node")) || !topicId(body.value("team_id")) || body.value("team_id") != c.team ||
        !topicId(body.value("match_id")) || body.value("match_id") != c.match || !topicId(body.value("epoch")) || body.value("epoch") != c.epoch ||
        !id(body.value("session_id"), 128) || !integer(body.value("robot_id"), 1, 109, &robot) ||
        !integer(body.value("session_started_ms"), 1, SafeInteger, &p.started) ||
        !integer(body.value("sequence"), 1, SafeInteger, &p.sequence) ||
        !integer(body.value("sent_at_ms"), 1, SafeInteger, &p.sent) || p.started > p.sent)
        return fail(error, "Invalid bounded source body, scope, sequence or timestamp");
    p.node = body.value("source_node").toString(); p.session = body.value("session_id").toString();
    const auto peer = c.roster.constFind(p.node);
    if (peer == c.roster.cend() || peer->robot != robot || (p.kind == "node-snapshot" && !peer->send))
        return fail(error, "Source is outside the configured roster or lacks send permission");
    if (body.value("_network").metaType().id() != QMetaType::QVariantMap) return fail(error, "Missing verified transport provenance");
    const auto network = body.value("_network").toMap();
    if (!keys(network, {"authenticated", "sender_node", "fingerprint", "proof"}, {"received_at_ms", "received_tick_ms", "certificate_sha256"}) ||
        network.value("authenticated").metaType().id() != QMetaType::Bool || !network.value("authenticated").toBool() ||
        network.value("sender_node") != p.node || !text(network.value("fingerprint"), 64) || network.value("fingerprint").toString().size() != 64 ||
        network.value("proof").metaType().id() != QMetaType::QVariantMap || !bounded(network.value("proof"), ProofLimit))
        return fail(error, "Invalid verified transport provenance");
    for (const auto ch : network.value("fingerprint").toString())
        if (!((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'))) return fail(error, "Invalid transport certificate fingerprint");
    const auto certificate = network.value("certificate_sha256", network.value("fingerprint"));
    if (!text(certificate, 64) || certificate.toString().size() != 64) return fail(error, "Invalid transport certificate digest");
    for (const auto ch : certificate.toString())
        if (!((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'))) return fail(error, "Invalid transport certificate digest");
    p.proof = network.value("proof").toMap();
    if (!keys(p.proof, {"schema", "signer", "certificate_sha256", "algorithm", "body_b64", "signature_b64"}) ||
        !integer(p.proof.value("schema"), 2, 2) || p.proof.value("signer") != p.node ||
        p.proof.value("certificate_sha256") != certificate ||
        !text(p.proof.value("body_b64"), 24 * 1024) || !text(p.proof.value("signature_b64"), 12 * 1024) ||
        !QSet<QString>{"Ed25519", "Ed448", "ECDSA-SHA256", "RSA-PSS-SHA256"}.contains(p.proof.value("algorithm").toString()))
        return fail(error, "Invalid original source proof envelope");
    const auto encoded = p.proof.value("body_b64").toString().toLatin1();
    const auto decoded = QByteArray::fromBase64(encoded, QByteArray::AbortOnBase64DecodingErrors);
    const auto signature = p.proof.value("signature_b64").toString().toLatin1();
    const auto signatureBytes = QByteArray::fromBase64(signature, QByteArray::AbortOnBase64DecodingErrors);
    QJsonParseError parseError;
    const auto document = QJsonDocument::fromJson(decoded, &parseError);
    p.bytes = compact(p.bare); p.proofBytes = compact(p.proof);
    if (decoded.isEmpty() || decoded.size() > SourceLimit || decoded.toBase64() != encoded ||
        signatureBytes.isEmpty() || signatureBytes.size() > 8192 || signatureBytes.toBase64() != signature ||
        parseError.error != QJsonParseError::NoError || !document.isObject() ||
        document.toJson(QJsonDocument::Compact) != p.bytes)
        return fail(error, "Source proof does not contain the exact verified source body");
    p.receiveUtc = utc; p.receiveTick = tick;
    const bool receiveUtc = network.contains("received_at_ms"), receiveTick = network.contains("received_tick_ms");
    if (receiveUtc != receiveTick || (receiveUtc &&
        (!integer(network.value("received_at_ms"), 1, utc, &p.receiveUtc) ||
         !integer(network.value("received_tick_ms"), 0, tick, &p.receiveTick) ||
         std::abs((utc - p.receiveUtc) - (tick - p.receiveTick)) > c.skew + 1000)))
        return fail(error, "Invalid transport ingress clock sample");
    if (p.sent > add(p.receiveUtc, c.skew)) return fail(error, "Source timestamp exceeds transport ingress clock skew");
    if (p.kind == "node-snapshot") {
        if (!id(body.value("snapshot_id")) || body.value("items").metaType().id() != QMetaType::QVariantList || body.value("items").toList().size() > 64)
            return fail(error, "Invalid bounded complete source snapshot");
        p.snapshot = body.value("snapshot_id").toString(); p.items = body.value("items").toList();
        QSet<QString> itemIds, paths;
        for (const auto &value : p.items) {
            if (value.metaType().id() != QMetaType::QVariantMap || !validateItem(value.toMap(), p.sent, c, error)) return false;
            const auto item = value.toMap(); const auto itemId = item.value("item_id").toString();
            const auto path = item.value("path").toString();
            if (itemIds.contains(itemId) || paths.contains(path)) return fail(error, "Duplicate source item identity or semantic path");
            itemIds.insert(itemId); paths.insert(path);
        }
    }
    *out = std::move(p); return true;
}

bool apply(State &state, const QVariantMap &body, qint64 utc, qint64 tick, bool allowKnownSnapshot, QString *error) {
    if (!state.config.configured) return fail(error, "Team store is not configured");
    Parsed p;
    if (!parse(body, state.config, utc, tick, &p, error)) return false;
    auto member = state.members.value(p.node);
    // A cut may include the latest exact source proof after later heartbeats.
    // This path deliberately does not touch receive time, sequence or item TTL.
    if (allowKnownSnapshot && p.kind == "node-snapshot" && p.session == member.session &&
        p.proofBytes == member.latest.proofBytes && p.bytes == member.latest.bytes) return true;
    const auto &c = state.config;
    if (p.sent > add(utc, c.skew) || p.sent < add(utc, -(c.timeout + c.skew)))
        return fail(error, "Source message is stale or outside declared clock skew");
    if (!member.session.isEmpty() && p.session != member.session) {
        if (member.retired.contains(p.session) || p.started <= member.sessionStarted || member.resets >= 16)
            return fail(error, "Retired/non-newer source session or epoch reset limit reached");
        member.retired.insert(member.session); ++member.resets;
        member.session.clear(); member.sequence = 0; member.highwater.clear(); member.latest = {};
    }
    if (member.session == p.session && (member.sessionStarted != p.started || p.sequence <= member.sequence))
        return fail(error, "Duplicate, reordered or changed-session source sequence");
    if (member.session.isEmpty()) { member.session = p.session; member.sessionStarted = p.started; }
    if (p.kind == "node-snapshot") {
        auto highwater = member.highwater;
        Snapshot snapshot;
        snapshot.body = p.bare; snapshot.proof = p.proof; snapshot.bytes = p.bytes; snapshot.proofBytes = p.proofBytes;
        snapshot.id = p.snapshot; snapshot.session = p.session; snapshot.sequence = p.sequence;
        snapshot.deadline = add(tick, add(add(p.sent, c.timeout), -utc - c.skew));
        for (const auto &value : p.items) {
            const auto map = value.toMap(); const auto name = map.value("item_id").toString();
            const auto revision = map.value("revision").toLongLong(); const auto bytes = compact(map);
            auto item = highwater.value(name);
            if (item.revision > revision) return fail(error, "A lower item revision cannot revive old data");
            if (item.revision == revision) {
                if (bytes != item.bytes) item.conflict = true;
            } else {
                item = {}; item.content = map; item.bytes = bytes; item.revision = revision; item.acceptedTick = tick;
                item.receivedAge = age(utc, map.value("received_at_ms").toLongLong());
                const auto expires = std::min(add(map.value("observed_at_ms").toLongLong(), map.value("ttl_ms").toLongLong()), add(p.sent, c.timeout));
                item.deadline = add(tick, add(expires, -utc - c.skew));
            }
            highwater.insert(name, std::move(item)); snapshot.items.append(name);
        }
        if (highwater.size() > 128) return fail(error, "Source item highwater exhausted; reset the configured epoch");
        member.highwater = std::move(highwater); member.latest = std::move(snapshot);
    }
    member.sequence = p.sequence;
    // A delayed packet cannot move the liveness deadline forward past ingress.
    member.receiveTick = std::max(member.receiveTick, p.receiveTick);
    member.receiveUtc = std::max(member.receiveUtc, p.receiveUtc);
    state.members.insert(p.node, std::move(member)); return true;
}

bool online(const Member &m, const Config &c, qint64 tick) {
    return !m.session.isEmpty() && tick >= m.receiveTick && tick < add(m.receiveTick, c.timeout);
}
bool conflictingLatest(const Member &member) {
    for (const auto &name : member.latest.items)
        if (member.highwater.value(name).conflict) return true;
    return false;
}
QString fieldState(const State &state, const Selected &selected, const QString &name, qint64 tick) {
    const auto &item = selected.items[name];
    const auto member = state.members.constFind(selected.node);
    if (member != state.members.cend() && member->session == selected.session) {
        const auto current = member->highwater.constFind(name);
        if (current != member->highwater.cend()) {
            if (current->revision == item.revision && current->conflict) return QStringLiteral("conflict");
            if (current->revision >= item.revision && current->content.value("lifecycle") == "withdrawn") return QStringLiteral("withdrawn");
            if (current->revision != item.revision || !member->latest.items.contains(name)) return QStringLiteral("stale");
        }
    }
    if (item.conflict) return QStringLiteral("conflict");
    if (item.content.value("lifecycle") == "withdrawn") return QStringLiteral("withdrawn");
    if (member == state.members.cend() || member->session != selected.session || !online(*member, state.config, tick) ||
        tick < item.acceptedTick || tick >= item.deadline) return QStringLiteral("stale");
    return QStringLiteral("fresh");
}
struct Projection { QString state; QVariantList uses; qint64 remaining = 0; };
Projection projectField(const State &state, const Selected &selected, const QString &name, qint64 tick,
                        QMap<QString, Projection> *cache, QSet<QString> *visiting) {
    if (cache->contains(name)) return cache->value(name);
    Projection result;
    if (!selected.items.contains(name) || visiting->contains(name)) { result.state = "stale"; return result; }
    const auto &item = selected.items[name]; result.state = fieldState(state, selected, name, tick);
    result.uses = item.content.value("allowed_uses").toList(); result.remaining = std::max(qint64(0), item.deadline - tick);
    if (result.state == "fresh" && item.content.value("source_kind") == "derived") {
        visiting->insert(name);
        for (const auto &dependency : item.content.value("dependencies").toList()) {
            const auto parent = projectField(state, selected, dependency.toString(), tick, cache, visiting);
            if (parent.state != "fresh") { result.state = "stale"; break; }
            result.remaining = std::min(result.remaining, parent.remaining);
            for (qsizetype i = result.uses.size(); i-- > 0;)
                if (!parent.uses.contains(result.uses[i])) result.uses.removeAt(i);
        }
        visiting->remove(name);
    }
    if (result.state != "fresh") result.remaining = 0;
    cache->insert(name, result); return result;
}
QVariantMap project(const State &state, qint64 utc, qint64 tick) {
    if (!state.config.configured || state.cut.id.isEmpty() || !times(utc, tick)) return {};
    QVariantList members, fields, excluded;
    for (auto selectedIt = state.cut.selected.cbegin(); selectedIt != state.cut.selected.cend(); ++selectedIt) {
        const auto &selected = selectedIt.value(); const auto member = state.members.value(selected.node);
        const bool live = member.session == selected.session && online(member, state.config, tick);
        QString memberState = live ? QStringLiteral("online") : QStringLiteral("offline");
        if (live && tick >= selected.snapshot.deadline) memberState = "stale";
        QSet<QString> exports;
        for (const auto &item : selected.items)
            if (item.content.value("source_kind") == "official_player_client") exports.insert(item.content.value("player_export_id").toString());
        members.append(QVariantMap{{"node_id", selected.node}, {"robot_id", state.config.roster.value(selected.node).robot},
            {"source_session_id", selected.session},
            {"state", memberState}, {"age_ms", age(tick, member.receiveTick)}, {"auth", "authenticated_peer_relay"},
            {"player_export_id", exports.size() == 1 ? *exports.cbegin() : QString()}, {"snapshot_id", selected.snapshot.id}});
        if (!live) excluded.append(QVariantMap{{"node_id", selected.node}, {"reason", "member_offline"}, {"count", 1}});
        QMap<QString, int> reasons; QMap<QString, Projection> cache; QSet<QString> visiting;
        for (auto it = selected.items.cbegin(); it != selected.items.cend(); ++it) {
            const auto &item = it.value(); auto map = item.content;
            const auto result = projectField(state, selected, it.key(), tick, &cache, &visiting);
            map.insert("source_node", selected.node); map.insert("source_robot", state.config.roster.value(selected.node).robot);
            map.insert("source_session_id", selected.session);
            map.insert("kind", item.content.value("source_kind")); map.insert("state", result.state);
            map.insert("accepted", result.state == "fresh"); map.insert("remaining_ms", result.remaining);
            map.insert("received_age_ms", add(item.receivedAge, age(tick, item.acceptedTick)));
            map.insert("trust", "authenticated_peer_relay"); map.insert("field_revision", item.revision);
            map.insert("snapshot_id", selected.snapshot.id);
            map.insert("source_allowed_uses", item.content.value("allowed_uses"));
            map.insert("allowed_uses", result.uses);
            fields.append(map);
            if (result.state != "fresh") ++reasons[result.state];
        }
        for (auto it = reasons.cbegin(); it != reasons.cend(); ++it)
            excluded.append(QVariantMap{{"node_id", selected.node}, {"reason", it.key()}, {"count", it.value()}});
    }
    return {{"schema", 2}, {"view_id", state.cut.id}, {"revision", QVariant::fromValue<qulonglong>(state.cut.revision)},
        {"team_id", state.config.team}, {"match_id", state.config.match}, {"epoch", state.config.epoch},
        {"issuer_id", state.config.publisher}, {"generated_at_ms", state.cut.generated},
        {"members", members}, {"fields", fields}, {"excluded", excluded}};
}
bool cutBounds(const State &state, qint64 utc, qint64 tick, QString *error) {
    auto projected = project(state, utc, tick); auto fields = projected.value("fields").toList(); int discoveries = 0;
    if (fields.size() > 512) return fail(error, "Team cut exceeds 512 fields");
    for (auto &value : fields) {
        auto f = value.toMap(); if (f.value("data_type") == "discovery") ++discoveries;
        // Reserve space for the largest future age/state projection. A cut that
        // could overflow when it expires is rejected now, never truncated later.
        f.insert("received_age_ms", SafeInteger); f.insert("state", "withdrawn"); f.insert("accepted", false);
        f.insert("remaining_ms", SafeInteger); f.insert("allowed_uses", f.value("source_allowed_uses")); value = f;
    }
    if (discoveries > 64) return fail(error, "Team cut exceeds 64 discoveries");
    projected.insert("fields", fields); auto members = projected.value("members").toList(); QVariantList excluded;
    for (auto &value : members) {
        auto member = value.toMap(); member.insert("age_ms", SafeInteger); member.insert("state", "offline"); value = member;
        for (const auto &reason : {"member_offline", "stale", "conflict", "withdrawn"})
            excluded.append(QVariantMap{{"node_id", member.value("node_id")}, {"reason", reason}, {"count", 512}});
    }
    projected.insert("members", members); projected.insert("excluded", excluded);
    if (compact(projected).size() > ViewLimit) return fail(error, "Team cut exceeds the bounded 256 KiB projected view");
    return true;
}
}

struct Store::Private : State {};
bool validateSourceItem(const QVariantMap &item, qint64 sentUtc, qint64 maxSkewMs, QString *error) {
    if (error) error->clear();
    if (!times(sentUtc, 0) || maxSkewMs < 0 || maxSkewMs > 1000)
        return fail(error, "Invalid source item validation clock bounds");
    Config config; config.skew = maxSkewMs;
    return validateItem(item, sentUtc, config, error);
}
Store::Store() : d(std::make_unique<Private>()) {}
Store::~Store() = default;
Store::Store(const Store &other) : d(std::make_unique<Private>(*other.d)) {}
Store &Store::operator=(const Store &other) { if (this != &other) d = std::make_unique<Private>(*other.d); return *this; }
Store::Store(Store &&) noexcept = default;
Store &Store::operator=(Store &&) noexcept = default;

bool Store::configure(const QVariantMap &config, QString *error) {
    if (error) error->clear();
    Config candidate;
    if (!configureState(config, &candidate, error)) return false;
    if (d->config.configured && d->config.team == candidate.team && d->config.match == candidate.match && d->config.epoch == candidate.epoch) {
        if (!sameConfiguration(d->config, candidate)) return fail(error, "Change the epoch before changing the roster/clock/publisher contract");
        return true; // Reconnect/reapply must not erase replay or withdrawal state.
    }
    d = std::make_unique<Private>(); d->config = std::move(candidate); return true;
}
bool Store::accept(const QVariantMap &body, qint64 utc, qint64 tick, QString *error) {
    if (error) error->clear();
    auto candidate = *d;
    if (!apply(candidate, body, utc, tick, false, error)) return false;
    *d = std::move(candidate); return true;
}
QVariantList Store::proofs(qint64 utc, qint64 tick) const {
    QVariantList result;
    if (!d->config.configured || !times(utc, tick)) return result;
    for (auto it = d->members.cbegin(); it != d->members.cend(); ++it)
        if (!it->latest.id.isEmpty() && online(*it, d->config, tick) && tick < it->latest.deadline && !conflictingLatest(*it))
            result.append(it->latest.proof);
    return result;
}
bool Store::commit(const QVariantList &snapshots, const QString &viewId, quint64 revision,
                   qint64 utc, qint64 tick, QString *error) {
    if (error) error->clear();
    if (!d->config.configured || !times(utc, tick) || !id(viewId, 128) || !revision || revision > quint64(SafeInteger) || snapshots.size() > 16)
        return fail(error, "Invalid bounded team cut identity/revision or clock sample");
    auto candidate = *d; QSet<QString> nodes; QMap<QString, QVariantMap> sorted;
    for (const auto &value : snapshots) {
        if (value.metaType().id() != QMetaType::QVariantMap) return fail(error, "Team cut snapshot must be a verified object");
        const auto body = value.toMap(); const auto node = body.value("source_node").toString();
        if (body.value("kind") != "node-snapshot" || nodes.contains(node)) return fail(error, "Team cut repeats a source or contains a non-snapshot");
        nodes.insert(node); sorted.insert(node, body);
    }
    QVariantList signedProofs;
    for (auto it = sorted.cbegin(); it != sorted.cend(); ++it) {
        if (!apply(candidate, it.value(), utc, tick, true, error)) return false;
        signedProofs.append(it.value().value("_network").toMap().value("proof"));
    }
    const auto identity = QJsonDocument::fromVariant(signedProofs).toJson(QJsonDocument::Compact);
    if (identity.size() > ViewLimit) return fail(error, "Team cut original proofs exceed 256 KiB");
    if (revision <= d->cut.revision) {
        if (revision == d->cut.revision && viewId == d->cut.id && identity == d->cut.identity) return true;
        return fail(error, "A committed cut revision is immutable and must advance monotonically");
    }
    Cut cut; cut.id = viewId; cut.revision = revision; cut.generated = utc; cut.identity = identity;
    for (auto it = sorted.cbegin(); it != sorted.cend(); ++it) {
        const auto &member = candidate.members[it.key()]; Selected selected;
        selected.node = it.key(); selected.session = member.session; selected.snapshot = member.latest;
        for (const auto &name : member.latest.items) selected.items.insert(name, member.highwater.value(name));
        cut.selected.insert(it.key(), std::move(selected));
    }
    candidate.cut = std::move(cut);
    if (!cutBounds(candidate, utc, tick, error)) return false;
    *d = std::move(candidate); return true;
}
QVariantMap Store::view(qint64 utc, qint64 tick) const { return project(*d, utc, tick); }
void Store::clear() { d = std::make_unique<Private>(); }
}
