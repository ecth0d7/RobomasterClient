#include "TerminalTeamContract.h"
#include <QCryptographicHash>
#include <QJsonDocument>
#include <QSet>
#include <QUrl>
#include <algorithm>
#include <cmath>
#include <utility>

namespace TerminalTeamContract {
namespace {
constexpr qint64 Safe = 9007199254740991LL;
constexpr int Members = 16, Items = 64, History = 128;
bool fail(QString *error, const QString &message) { if (error) *error = message; return false; }
bool integer(const QVariant &v, qint64 lo, qint64 hi, qint64 *out = nullptr) {
    const auto t = v.metaType().id();
    if (t != QMetaType::Int && t != QMetaType::UInt && t != QMetaType::LongLong &&
        t != QMetaType::ULongLong && t != QMetaType::Double && t != QMetaType::Float) return false;
    const double n = v.toDouble();
    if (!std::isfinite(n) || std::floor(n) != n || n < double(lo) || n > double(hi)) return false;
    if (out) *out = qint64(n);
    return true;
}
bool text(const QVariant &v, int max = 96, bool empty = false) {
    if (v.metaType().id() != QMetaType::QString || (!empty && v.toString().isEmpty()) || v.toString().size() > max) return false;
    for (const auto c : v.toString()) if (c.isNull() || c.category() == QChar::Other_Control) return false;
    return true;
}
bool id(const QVariant &v, int max = 96) {
    if (!text(v, max)) return false;
    for (const auto c : v.toString()) {
        const auto u = c.unicode();
        if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') || (u >= '0' && u <= '9') ||
              u == '.' || u == '-' || u == '_' || u == ':' || u == '/')) return false;
    }
    return true;
}
bool topicId(const QVariant &v) {
    if (!id(v, 64)) return false;
    return !v.toString().contains('/') && !v.toString().contains(':');
}
bool robotKey(const QVariant &v) {
    if (!text(v, 64)) return false;
    const auto p = v.toString().split('/');
    if (p.size() != 3 || (p[0] != "red" && p[0] != "blue") || p[1].isEmpty() || p[1].size() > 32 ||
        p[2].isEmpty() || p[2].size() > 3 || p[2][0] < '1' || p[2][0] > '9' || p[1][0] < 'a' || p[1][0] > 'z') return false;
    for (const auto c : p[1]) if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '-')) return false;
    for (const auto c : p[2]) if (c < '0' || c > '9') return false;
    return true;
}
bool keys(const QVariantMap &m, const QSet<QString> &required, const QSet<QString> &optional = {}) {
    for (const auto &key : required) if (!m.contains(key)) return false;
    for (auto it = m.cbegin(); it != m.cend(); ++it) if (!required.contains(it.key()) && !optional.contains(it.key())) return false;
    return true;
}
bool context(const QVariant &v) {
    if (v.metaType().id() != QMetaType::QVariantMap) return false;
    const auto m = v.toMap();
    return keys(m, {"profile_id", "field_profile_id", "capability_revision"}) &&
        id(m.value("profile_id"), 128) && id(m.value("field_profile_id"), 128) && id(m.value("capability_revision"), 128);
}
QByteArray compact(const QVariant &v) { return QJsonDocument::fromVariant(v).toJson(QJsonDocument::Compact); }
QString itemKey(const QVariantMap &o) {
    return QString::fromUtf8(compact(QVariantList{o.value("source_id"), o.value("item_id")}));
}
QString versionKey(const QVariantMap &o) {
    return QString::fromUtf8(compact(QVariantList{o.value("source_id"), o.value("session_id"), o.value("item_id")}));
}
bool bounded(const QVariant &v, int depth = 0, int *count = nullptr, qsizetype *cost = nullptr) {
    int localCount = 0; qsizetype localCost = 0;
    if (!count) count = &localCount;
    if (!cost) cost = &localCost;
    if (++*count > 32768 || depth > 8 || *cost > 256 * 1024) return false;
    if (!v.isValid() || v.isNull()) { *cost += 4; return true; }
    const auto t = v.metaType().id();
    if (t == QMetaType::QVariantMap) {
        const auto map = v.toMap();
        if (map.size() > 512) return false;
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            if (!text(it.key(), 128)) return false;
            *cost += it.key().size() + 4;
            if (!bounded(it.value(), depth + 1, count, cost)) return false;
        }
    } else if (t == QMetaType::QVariantList) {
        const auto list = v.toList(); if (list.size() > 512) return false;
        for (const auto &entry : list) if (!bounded(entry, depth + 1, count, cost)) return false;
    } else if (t == QMetaType::QString) { if (!text(v, 256 * 1024, true)) return false; *cost += v.toString().size() + 2; }
    else if (t == QMetaType::Bool) *cost += 5;
    else {
        if (t != QMetaType::Double && t != QMetaType::Float && !integer(v, -Safe, Safe)) return false;
        if (!std::isfinite(v.toDouble()) || std::abs(v.toDouble()) > double(Safe)) return false;
        *cost += 24;
    }
    return *cost <= 256 * 1024;
}
bool flag(const QVariantMap &m, const QString &key) { return m.value(key).metaType().id() == QMetaType::Bool; }
bool uses(const QVariant &v, QStringList *out = nullptr) {
    if (v.metaType().id() != QMetaType::QVariantList) return false;
    static const QSet<QString> allowed{"hud", "alerts", "localAi", "externalAi", "voice"};
    QStringList list;
    for (const auto &x : v.toList()) {
        if (!text(x, 16) || !allowed.contains(x.toString()) || list.contains(x.toString())) return false;
        list.append(x.toString());
    }
    if (out) *out = list;
    return true;
}
bool grants(const QVariant &v, QMap<QString, QStringList> *out = nullptr) {
    if (v.metaType().id() != QMetaType::QVariantList || v.toList().size() > Items) return false;
    QMap<QString, QStringList> result;
    for (const auto &entry : v.toList()) {
        const auto grant = entry.toMap(); QStringList purposes;
        if (entry.metaType().id() != QMetaType::QVariantMap || !keys(grant, {"source_id", "item_id", "uses"}) ||
            !id(grant.value("source_id")) || !id(grant.value("item_id")) || !uses(grant.value("uses"), &purposes) ||
            result.contains(itemKey(grant))) return false;
        result[itemKey(grant)] = purposes;
    }
    if (out) *out = result;
    return true;
}
bool measurementPayload(const QVariant &value) {
    if (value.metaType().id() == QMetaType::QVariantMap) {
        static const QSet<QString> forbidden{"authoritative", "authenticated", "host_verified", "verified", "source_kind",
            "validation", "allowed_uses", "ai_input_ready", "production_adapter_connected", "received_at_ms",
            "received_tick_ms", "official_engine", "official_player_client"};
        const auto map = value.toMap();
        for (auto it = map.cbegin(); it != map.cend(); ++it)
            if (forbidden.contains(it.key()) || !measurementPayload(it.value())) return false;
    } else if (value.metaType().id() == QMetaType::QVariantList) {
        for (const auto &entry : value.toList()) if (!measurementPayload(entry)) return false;
    }
    return true;
}
bool rawObservation(const QVariantMap &o, const QVariantMap &scope, const QString &team,
                    const QString &robot, bool mock, QString *error) {
    if (!keys(o, {"schema", "context", "team_id", "robot_key", "source_id", "sensor_id", "source_kind",
                  "session_id", "sequence", "item_id", "produced_at_ms", "clock_domain", "ttl_ms", "confidence",
                  "validation", "lifecycle", "data_type", "value"}, {"unit", "frame_id", "frame_revision", "transform_id"}) ||
        !integer(o.value("schema"), 3, 3) || !context(o.value("context")) || o.value("context").toMap() != scope ||
        o.value("team_id").metaType().id() != QMetaType::QString || o.value("team_id") != team ||
        !robotKey(o.value("robot_key")) || o.value("robot_key") != robot ||
        !id(o.value("source_id")) || !id(o.value("session_id")) || !id(o.value("item_id")) ||
        !text(o.value("sensor_id"), 96, true) || !integer(o.value("sequence"), 1, Safe) ||
        !integer(o.value("ttl_ms"), 100, 60000) || !id(o.value("clock_domain")) ||
        !text(o.value("source_kind"), 32) || !text(o.value("validation"), 32) ||
        !text(o.value("lifecycle"), 16) || !text(o.value("data_type"), 16) ||
        (!o.value("produced_at_ms").isNull() && o.value("produced_at_ms").isValid() && !integer(o.value("produced_at_ms"), 0, Safe)) ||
        (o.value("lifecycle") != "active" && o.value("lifecycle") != "withdrawn") || !bounded(o) || compact(o).size() > 16 * 1024)
        return fail(error, "Invalid canonical schema3 observation or source scope");
    const auto kind = o.value("source_kind").toString(), validation = o.value("validation").toString();
    if ((kind == "local_sensor" || kind == "local_vision") ? validation != "unverified" || !text(o.value("sensor_id"))
        : kind == "derived" ? validation != "derived"
        : kind == "mock" ? !mock || validation != "mock" || !o.value("source_id").toString().startsWith("mock.")
        : true) return fail(error, "Official issuers are unbound; only explicit local/derived or authorized training mock sources are accepted");
    if (kind != "mock" && o.value("source_id").toString().startsWith("mock.")) return fail(error, "Mock source namespace cannot claim production data");
    const auto confidence = o.value("confidence");
    if (confidence.isValid() && !confidence.isNull() &&
        ((!integer(confidence, -Safe, Safe) && confidence.metaType().id() != QMetaType::Double && confidence.metaType().id() != QMetaType::Float) ||
         !std::isfinite(confidence.toDouble()) || confidence.toDouble() < 0 || confidence.toDouble() > 1))
        return fail(error, "Invalid confidence");
    for (const auto &key : {"unit", "frame_id", "frame_revision", "transform_id"})
        if (o.contains(key) && !text(o.value(key), 128)) return fail(error, "Invalid unit/frame/transform reference");
    if ((o.contains("frame_id") || o.contains("frame_revision") || o.contains("transform_id")) &&
        !(o.contains("frame_id") && o.contains("frame_revision") && o.contains("transform_id")))
        return fail(error, "Spatial observations require all frame revision and transform references");
    const auto value = o.value("value"); const auto type = o.value("data_type").toString();
    const auto valueType = value.metaType().id();
    const bool numeric = valueType == QMetaType::Double || valueType == QMetaType::Float || integer(value, -Safe, Safe);
    if (!measurementPayload(value) || !(type == "number" ? numeric : type == "boolean" ? valueType == QMetaType::Bool
        : type == "text" ? text(value, 2048, true) : type == "object" ? valueType == QMetaType::QVariantMap
        : (type == "event" || type == "discovery") ? valueType == QMetaType::QVariantMap && text(value.toMap().value("summary"), 512) : false))
        return fail(error, "Typed observation value is invalid");
    return true;
}
struct SourceSession { QString current; QSet<QString> retired; };
struct Record { QVariantMap wrapped; QByteArray bytes; qint64 deadline = 0, received = 0, tick = 0; bool conflict = false; };
struct Node {
    QString robot, session; qint64 started = 0, sequence = 0, snapshotSequence = 0, liveUntil = 0, proofUntil = 0;
    bool send = false, aggregate = false;
    QSet<QString> retired; QMap<QString, QStringList> grants; QMap<QString, SourceSession> sourceSessions;
    QMap<QString, Record> history; QMap<QString, QString> membership;
    QVariantMap proof; QString snapshot;
};
QVariantMap publicConfig(const QVariantMap &c) {
    QVariantMap result;
    for (const auto &key : {"context", "team_id", "match_id", "epoch", "node_id", "robot_key", "publisher_id",
                            "can_send", "can_aggregate", "allowed_fields", "allowed_uses", "clocks_synchronized",
                            "max_clock_skew_ms", "timeout_ms", "training_mock"}) result[QLatin1String(key)] = c.value(QLatin1String(key));
    QVariantList peers;
    for (const auto &v : c.value("peers").toList()) {
        QVariantMap peer;
        for (const auto &key : {"node_id", "robot_key", "can_send", "can_aggregate", "allowed_fields"}) peer[QLatin1String(key)] = v.toMap().value(QLatin1String(key));
        peers.append(peer);
    }
    result["peers"] = peers;
    return result;
}
}

bool validateConfiguration(const QVariantMap &c, QString *error) {
    if (error) error->clear();
    if (!keys(c, {"schema", "context", "team_id", "match_id", "epoch", "node_id", "robot_key", "publisher_id",
        "can_send", "can_aggregate", "allowed_fields", "allowed_uses", "clocks_synchronized", "max_clock_skew_ms",
        "heartbeat_ms", "timeout_ms", "training_mock", "team_wide_sharing_confirmed", "endpoint", "ca_file",
        "certificate_file", "signing_key_file", "peers"}) || !integer(c.value("schema"), 3, 3) || !context(c.value("context")) ||
        c.value("context").toMap().value("profile_id") != "rmuc2027-regional-v1.0.0" ||
        !topicId(c.value("team_id")) || !topicId(c.value("match_id")) || !topicId(c.value("epoch")) || !topicId(c.value("node_id")) ||
        !topicId(c.value("publisher_id")) || !robotKey(c.value("robot_key")) ||
        !flag(c, "can_send") || !flag(c, "can_aggregate") || !flag(c, "clocks_synchronized") || !flag(c, "training_mock") ||
        !flag(c, "team_wide_sharing_confirmed") || !c.value("team_wide_sharing_confirmed").toBool() ||
        !integer(c.value("max_clock_skew_ms"), 0, 1000) || !integer(c.value("heartbeat_ms"), 250, 10000) ||
        !integer(c.value("timeout_ms"), 750, 60000) || c.value("timeout_ms").toLongLong() < 3 * c.value("heartbeat_ms").toLongLong() ||
        !grants(c.value("allowed_fields")) || !uses(c.value("allowed_uses")) ||
        c.value("peers").metaType().id() != QMetaType::QVariantList || c.value("peers").toList().size() > Members - 1 || !bounded(c))
        return fail(error, "Invalid exact schema3 terminal-team configuration, permissions or disclosure");
    const QUrl endpoint(c.value("endpoint").toString(), QUrl::StrictMode);
    if (!text(c.value("endpoint"), 256) || !endpoint.isValid() || endpoint.scheme() != "mqtts" || endpoint.host().isEmpty() ||
        endpoint.port(-1) < 1 || endpoint.port(-1) > 65535 || !endpoint.userInfo().isEmpty() || !endpoint.query().isEmpty() ||
        !endpoint.fragment().isEmpty() || !endpoint.path().isEmpty()) return fail(error, "Explicit mqtts host and port required, with no default port, credentials, path or query");
    for (const auto &key : {"ca_file", "certificate_file", "signing_key_file"})
        if (!text(c.value(key), 4096)) return fail(error, "Explicit bounded credential file references required");
    QSet<QString> nodes{c.value("node_id").toString()}, robots{c.value("robot_key").toString()}, pins;
    bool publisher = c.value("publisher_id") == c.value("node_id") && c.value("can_aggregate").toBool();
    const auto camp = c.value("robot_key").toString().section('/', 0, 0);
    for (const auto &v : c.value("peers").toList()) {
        const auto p = v.toMap();
        if (v.metaType().id() != QMetaType::QVariantMap || !keys(p, {"node_id", "robot_key", "certificate_file", "fingerprint", "can_send", "can_aggregate", "allowed_fields"}) ||
            !topicId(p.value("node_id")) || !robotKey(p.value("robot_key")) ||
            p.value("robot_key").toString().section('/', 0, 0) != camp || nodes.contains(p.value("node_id").toString()) ||
            robots.contains(p.value("robot_key").toString()) || !text(p.value("certificate_file"), 4096) ||
            !text(p.value("fingerprint"), 64) || p.value("fingerprint").toString().size() != 64 ||
            !flag(p, "can_send") || !flag(p, "can_aggregate") || !grants(p.value("allowed_fields")))
            return fail(error, "Invalid or duplicate pinned semantic team member");
        const auto pin = p.value("fingerprint").toString();
        for (const auto ch : pin) if (!((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'))) return fail(error, "SPKI pins must be lowercase SHA256 hex");
        if (pins.contains(pin)) return fail(error, "A signing public key cannot identify multiple nodes");
        pins.insert(pin); nodes.insert(p.value("node_id").toString()); robots.insert(p.value("robot_key").toString());
        if (p.value("node_id") == c.value("publisher_id") && p.value("can_aggregate").toBool()) publisher = true;
    }
    return publisher || fail(error, "Selected publisher must be an explicitly authorized aggregate member");
}
bool validateLocalSnapshotRequest(const QVariantMap &message, QString *error) {
    if (error) error->clear();
    return (keys(message, {"schema", "kind", "snapshot_id", "items"}) && integer(message.value("schema"), 3, 3) &&
        message.value("kind") == "local-snapshot" && id(message.value("snapshot_id"), 128) &&
        message.value("items").metaType().id() == QMetaType::QVariantList && message.value("items").toList().size() <= Items &&
        bounded(message) && compact(message).size() <= 60 * 1024) || fail(error, "Invalid bounded schema3 local-snapshot request");
}
QVariantMap networkConfiguration(const QVariantMap &c, const QString &session) {
    QVariantMap network;
    for (const auto &key : {"context", "team_id", "match_id", "epoch", "node_id", "robot_key", "can_send", "can_aggregate",
                            "heartbeat_ms", "timeout_ms", "endpoint", "ca_file", "certificate_file", "signing_key_file"}) network[QLatin1String(key)] = c.value(QLatin1String(key));
    QVariantList peers;
    for (const auto &v : c.value("peers").toList()) { auto p = v.toMap(); p.remove("allowed_fields"); peers.append(p); }
    network["peers"] = peers; network["session_id"] = session; network["contract_version"] = 3;
    return network;
}

struct Store::Private {
    QVariantMap config, context; QMap<QString, Node> nodes;
    QMap<QString, Record> local; QMap<QString, QMap<QString, Record>> selected;
    QVariantList committedProofs; QVariantMap committedViewProof;
    QMap<QString, QVariantMap> selectedSources;
    QString viewId, viewSession; qint64 revision = 0;
    qint64 lastUtc = 0, lastTick = 0; bool clockInvalid = false, configured = false;
    void quarantine(const QString &key) {
        if (key.isEmpty()) return;
        const auto sep = key.indexOf(QChar(0x1f));
        auto node = nodes.find(key.left(sep));
        if (node == nodes.end()) return;
        auto record = node->history.find(key.mid(sep + 1));
        if (record == node->history.end()) return;
        record->conflict = true; node->proof.clear();
    }
    bool observe(qint64 utc, qint64 tick) {
        if (utc <= 0 || utc > Safe - 60000 || tick < 0 || tick > Safe - 60000 ||
            (lastUtc && (utc < lastUtc || tick < lastTick || std::abs((utc - lastUtc) - (tick - lastTick)) > 250))) clockInvalid = true;
        lastUtc = utc; lastTick = tick; return !clockInvalid;
    }
    bool header(const QVariantMap &body, qint64 utc, qint64 tick, bool nested, Node **output, QString *error) {
        const auto provenance = body.value("_network").toMap();
        const auto nodeId = body.value("source_node").toString(); auto node = nodes.find(nodeId);
        qint64 sequence = 0, sent = 0, started = 0, arrival = 0, arrivalTick = 0;
        const auto proof = provenance.value("proof").toMap();
        if (node == nodes.end() || !integer(body.value("schema"), 3, 3) || body.value("context").toMap() != context ||
            body.value("team_id") != config.value("team_id") || body.value("match_id") != config.value("match_id") ||
            body.value("epoch") != config.value("epoch") || body.value("robot_key") != node->robot ||
            !id(body.value("session_id")) || !integer(body.value("sequence"), 1, Safe, &sequence) ||
            !integer(body.value("session_started_ms"), 1, Safe, &started) || !integer(body.value("sent_at_ms"), 1, Safe, &sent) ||
            started > sent || provenance.value("authenticated").metaType().id() != QMetaType::Bool || !provenance.value("authenticated").toBool() ||
            provenance.value("sender_node") != nodeId || proof.value("signer") != nodeId || !integer(proof.value("schema"), 3, 3) ||
            !integer(provenance.value("received_at_ms"), 1, utc, &arrival) || !integer(provenance.value("received_tick_ms"), 0, tick, &arrivalTick) ||
            std::abs((utc - arrival) - (tick - arrivalTick)) > 250)
            return fail(error, "Verified schema3 source identity/scope/arrival evidence is inconsistent");
        const auto skew = config.value("max_clock_skew_ms").toLongLong();
        const auto timeout = config.value("timeout_ms").toLongLong();
        if (sent > arrival + skew || arrival - sent > timeout + skew || tick - arrivalTick > timeout)
            return fail(error, "Team source packet is future-dated or expired before admission");
        const auto session = body.value("session_id").toString();
        if (node->session != session) {
            if (node->retired.contains(session) || node->retired.size() >= 16 || (!node->session.isEmpty() && started <= node->started))
                return fail(error, "Retired or excessive node session lineage");
            if (!node->session.isEmpty()) node->retired.insert(node->session);
            node->session = session; node->started = started; node->sequence = 0; node->snapshotSequence = 0;
            node->membership.clear(); node->proof.clear(); node->liveUntil = node->proofUntil = 0;
        }
        if ((!nested && sequence <= node->sequence) || (nested && sequence < node->snapshotSequence))
            return fail(error, "Duplicate or regressed signed node sequence");
        const bool newerSourceProof = nested && body.value("kind") == "node-snapshot" && sequence > node->snapshotSequence;
        node->sequence = qMax(node->sequence, sequence);
        // A genuinely newer ORIGINAL node envelope proves new node liveness,
        // including when the host only sees committed cuts. Repeated relaying
        // of the exact same proof cannot extend it. Item deadlines stay fixed.
        const auto live = tick + qMax<qint64>(0, std::min(timeout - (tick - arrivalTick), sent + timeout - utc - skew));
        if (!nested || newerSourceProof || !node->liveUntil) node->liveUntil = live;
        if (output) *output = &node.value();
        return true;
    }
    bool acceptBody(const QVariantMap &body, qint64 utc, qint64 tick, bool nested, QString *conflict, QString *error) {
        const QString kind = body.value("kind").toString();
        QSet<QString> required{"schema", "kind", "context", "team_id", "match_id", "epoch", "source_node", "robot_key",
                              "session_id", "session_started_ms", "sequence", "sent_at_ms", "_network"};
        if (kind == "node-snapshot") { required.insert("snapshot_id"); required.insert("items"); }
        else if (kind != "heartbeat") return fail(error, "Unsupported schema3 source kind");
        auto unsignedBody = body; unsignedBody.remove("_network");
        if (!keys(body, required) || !bounded(unsignedBody) || compact(unsignedBody).size() > 64 * 1024)
            return fail(error, "Invalid bounded signed source shape");
        Node *node = nullptr;
        if (!header(body, utc, tick, nested, &node, error)) return false;
        if (kind == "heartbeat") return true;
        if (!node->send || !id(body.value("snapshot_id"), 128) || body.value("items").metaType().id() != QMetaType::QVariantList ||
            body.value("items").toList().size() > Items) return fail(error, "Sender has no data grant or snapshot is malformed");
        if (body.value("sequence").toLongLong() == node->snapshotSequence) {
            if (body.value("_network").toMap().value("proof").toMap() != node->proof)
                return fail(error, "A source proof changed at its existing sequence");
            return true;
        }
        QMap<QString, QString> membership;
        QMap<QString, QString> sourceSessions;
        for (const auto &v : body.value("items").toList()) {
            if (v.metaType().id() != QMetaType::QVariantMap) return fail(error, "Snapshot item is not a wrapper");
            const auto wrapper = v.toMap(), observation = wrapper.value("observation").toMap(); QStringList selectedUses;
            qint64 deadline = 0;
            if (!keys(wrapper, {"observation", "allowed_uses", "relay_deadline_ms"}) ||
                wrapper.value("observation").metaType().id() != QMetaType::QVariantMap ||
                !rawObservation(observation, context, config.value("team_id").toString(), node->robot, config.value("training_mock").toBool(), error) ||
                !uses(wrapper.value("allowed_uses"), &selectedUses) || !integer(wrapper.value("relay_deadline_ms"), 1, Safe, &deadline))
                return fail(error, "Invalid original observation wrapper or fixed relay deadline");
            const auto key = itemKey(observation), version = versionKey(observation);
            if (membership.contains(key) || !node->grants.contains(key)) return fail(error, "Duplicate item or no explicitly allowed source/item field");
            const auto globalUses = config.value("allowed_uses").toList();
            for (const auto &use : selectedUses) if (!node->grants.value(key).contains(use) || !globalUses.contains(use))
                return fail(error, "Original purpose grants exceed configured field/recipient consent");
            const auto sourceId = observation.value("source_id").toString(), sourceSession = observation.value("session_id").toString();
            if (sourceSessions.contains(sourceId) && sourceSessions.value(sourceId) != sourceSession)
                return fail(error, "A complete snapshot mixes retired and current sessions of one source");
            sourceSessions[sourceId] = sourceSession;
            auto &lineage = node->sourceSessions[sourceId];
            if (lineage.current != sourceSession) {
                if (lineage.retired.contains(sourceSession) || lineage.retired.size() >= 8 || node->sourceSessions.size() > 32)
                    return fail(error, "Retired or excessive source session lineage");
                if (!lineage.current.isEmpty()) lineage.retired.insert(lineage.current);
                lineage.current = sourceSession;
            }
            const auto ttl = observation.value("ttl_ms").toLongLong(), sent = body.value("sent_at_ms").toLongLong();
            if (deadline > sent + ttl || (observation.value("clock_domain") == "host_utc" &&
                (!integer(observation.value("produced_at_ms"), 1, sent + config.value("max_clock_skew_ms").toLongLong()) ||
                 deadline > observation.value("produced_at_ms").toLongLong() + ttl)))
                return fail(error, "Source relay deadline exceeds original lifetime");
            const auto bytes = compact(wrapper);
            auto previous = node->history.find(version);
            if (previous != node->history.end()) {
                const auto oldSequence = previous->wrapped.value("observation").toMap().value("sequence").toLongLong();
                const auto sequence = observation.value("sequence").toLongLong();
                if (sequence < oldSequence) return fail(error, "Original observation sequence rolled back");
                if (sequence == oldSequence && previous->bytes != bytes) {
                    if (conflict) *conflict = body.value("source_node").toString() + QChar(0x1f) + version;
                    return fail(error, "Original observation mutated or attempted to renew its fixed lifetime");
                }
                if (sequence == oldSequence) { membership[key] = version; continue; }
            } else if (node->history.size() >= History) return fail(error, "Source item history is full; old tombstones were not pruned");
            const auto remaining = qMax<qint64>(0, std::min(ttl, deadline - utc - config.value("max_clock_skew_ms").toLongLong()));
            const auto provenance = body.value("_network").toMap();
            node->history[version] = {wrapper, bytes, tick + remaining, provenance.value("received_at_ms").toLongLong(),
                                      provenance.value("received_tick_ms").toLongLong(), false};
            membership[key] = version;
        }
        node->membership = membership;
        node->snapshot = body.value("snapshot_id").toString(); node->snapshotSequence = body.value("sequence").toLongLong();
        node->proof = body.value("_network").toMap().value("proof").toMap();
        node->proofUntil = tick + qMax<qint64>(0, body.value("sent_at_ms").toLongLong() + config.value("timeout_ms").toLongLong() - utc - config.value("max_clock_skew_ms").toLongLong());
        return true;
    }
};
Store::Store() : d(std::make_unique<Private>()) {}
Store::~Store() = default;
Store::Store(const Store &other) : d(std::make_unique<Private>(*other.d)) {}
Store &Store::operator=(const Store &other) { if (this != &other) d = std::make_unique<Private>(*other.d); return *this; }
void Store::clear() { d = std::make_unique<Private>(); }
bool Store::configure(const QVariantMap &c, QString *error) {
    if (!validateConfiguration(c, error)) return false;
    auto next = std::make_unique<Private>(); next->config = publicConfig(c); next->context = c.value("context").toMap();
    const auto install = [&](const QVariantMap &p) {
        Node node; node.robot = p.value("robot_key").toString(); node.send = p.value("can_send").toBool();
        node.aggregate = p.value("can_aggregate").toBool(); grants(p.value("allowed_fields"), &node.grants);
        next->nodes[p.value("node_id").toString()] = node;
    };
    install(c); for (const auto &p : c.value("peers").toList()) install(p.toMap());
    next->configured = true; d = std::move(next); return true;
}
bool Store::prepareLocal(const QVariantList &items, qint64 utc, qint64 tick, QVariantList *out, QString *error) {
    if (error) error->clear();
    if (!out || !d->configured || !d->observe(utc, tick) || items.size() > Items)
        return fail(error, "Local wrapper preparation has no valid scope/clock or exceeds bounds");
    auto next = d->local; QVariantList result; QSet<QString> keysSeen;
    const auto node = d->nodes.value(d->config.value("node_id").toString());
    if (!node.send) return fail(error, "This node has no data publication permission");
    for (const auto &v : items) {
        const auto o = v.toMap();
        if (v.metaType().id() != QMetaType::QVariantMap || !rawObservation(o, d->context, d->config.value("team_id").toString(),
            node.robot, d->config.value("training_mock").toBool(), error)) return false;
        const auto key = itemKey(o), version = versionKey(o);
        if (keysSeen.contains(key) || !node.grants.contains(key)) return fail(error, "Local item is duplicate or has no explicit purpose permission");
        keysSeen.insert(key);
        QVariantList purposes;
        for (const auto &use : node.grants.value(key)) if (d->config.value("allowed_uses").toList().contains(use)) purposes.append(use);
        auto old = next.find(version); QVariantMap wrapper;
        if (old != next.end() && old->wrapped.value("observation").toMap().value("sequence") == o.value("sequence")) {
            if (old->wrapped.value("observation").toMap() != o) return fail(error, "Local observation mutated at its existing sequence");
            wrapper = old->wrapped;
        } else {
            if (old != next.end() && old->wrapped.value("observation").toMap().value("sequence").toLongLong() > o.value("sequence").toLongLong())
                return fail(error, "Local observation sequence rolled back");
            if (old == next.end() && next.size() >= History) return fail(error, "Local wrapper history limit reached");
            const auto ttl = o.value("ttl_ms").toLongLong(); qint64 base = utc;
            if (o.value("clock_domain") == "host_utc") {
                if (!integer(o.value("produced_at_ms"), 1, utc, &base)) return fail(error, "Local host UTC timestamp is future or invalid");
            }
            wrapper = {{"observation", o}, {"allowed_uses", purposes}, {"relay_deadline_ms", base + ttl}};
            next[version] = {wrapper, compact(wrapper), 0, utc, tick, false};
        }
        result.append(wrapper);
    }
    if (compact(result).size() > 60 * 1024) return fail(error, "Complete local snapshot exceeds the signed source body budget");
    d->local = std::move(next); *out = std::move(result); return true;
}
bool Store::accept(const QVariantMap &body, qint64 utc, qint64 tick, QString *error) {
    if (error) error->clear();
    if (!d->configured || !d->observe(utc, tick)) return fail(error, "Team store clock/scope is invalid");
    auto next = std::make_unique<Private>(*d); QString conflict;
    if (!next->acceptBody(body, utc, tick, false, &conflict, error)) {
        d->quarantine(conflict);
        return false;
    }
    d = std::move(next); return true;
}
QVariantList Store::proofs(qint64 utc, qint64 tick) const {
    QVariantList result;
    if (!d->configured || d->clockInvalid || utc < d->lastUtc || tick < d->lastTick) return result;
    for (auto it = d->nodes.cbegin(); it != d->nodes.cend(); ++it) {
        if (it->proof.isEmpty() || it->liveUntil <= tick || it->proofUntil <= tick) continue;
        bool conflict = false;
        for (const auto &version : it->membership) conflict = conflict || it->history.value(version).conflict;
        if (!conflict) result.append(it->proof);
    }
    return result;
}
bool Store::commit(const QVariantMap &view, const QVariantList &sources, qint64 utc, qint64 tick, QString *error) {
    if (error) error->clear();
    if (!d->configured || !d->observe(utc, tick)) return fail(error, "Team view scope/clock is invalid");
    static const QSet<QString> required{"schema", "kind", "context", "team_id", "match_id", "epoch", "source_node", "robot_key",
        "session_id", "session_started_ms", "sequence", "sent_at_ms", "view_id", "view_revision", "proofs", "_network"};
    auto unsignedView = view; unsignedView.remove("_network");
    if (!keys(view, required) || !bounded(unsignedView) || compact(unsignedView).size() > 256 * 1024 || view.value("kind") != "team-view" ||
        view.value("source_node") != d->config.value("publisher_id") || !id(view.value("view_id"), 128) ||
        !integer(view.value("view_revision"), 1, Safe) || view.value("proofs").metaType().id() != QMetaType::QVariantList ||
        sources.size() > Members || sources.size() != view.value("proofs").toList().size())
        return fail(error, "Invalid atomic publisher cut shape or source proof count");
    auto next = std::make_unique<Private>(*d); Node *publisher = nullptr;
    if (!next->header(view, utc, tick, false, &publisher, error) || !publisher->aggregate) return false;
    const auto session = view.value("session_id").toString();
    const auto revision = view.value("view_revision").toLongLong();
    if (session == d->viewSession && revision <= d->revision) return fail(error, "Committed view revision did not advance");
    QSet<QString> nodes; QMap<QString, QMap<QString, Record>> selected;
    QMap<QString, QVariantMap> selectedSources; qsizetype count = 0;
    for (qsizetype i = 0; i < sources.size(); ++i) {
        const auto source = sources[i].toMap(); const auto nodeId = source.value("source_node").toString(); QString conflict;
        if (sources[i].metaType().id() != QMetaType::QVariantMap || source.value("kind") != "node-snapshot" || nodes.contains(nodeId) ||
            source.value("_network").toMap().value("proof") != view.value("proofs").toList()[i])
            return fail(error, "Original source proof cut has invalid identity/membership");
        if (!next->acceptBody(source, utc, tick, true, &conflict, error)) {
            d->quarantine(conflict); return false;
        }
        nodes.insert(nodeId); const auto node = next->nodes.value(nodeId);
        selected[nodeId] = {};
        selectedSources[nodeId] = {{"session_id", node.session}, {"snapshot_id", node.snapshot}, {"proof", node.proof}};
        for (auto item = node.membership.cbegin(); item != node.membership.cend(); ++item) {
            const auto record = node.history.value(item.value());
            if (record.conflict) return fail(error, "Source contains quarantined conflict");
            selected[nodeId][item.value()] = record;
            if (++count > 512) return fail(error, "Complete view exceeds 512 records; no cut was truncated");
        }
    }
    next->selected = std::move(selected); next->selectedSources = std::move(selectedSources);
    next->committedProofs = view.value("proofs").toList();
    next->committedViewProof = view.value("_network").toMap().value("proof").toMap();
    next->viewId = view.value("view_id").toString(); next->viewSession = session; next->revision = revision;
    d = std::move(next); return true;
}
QVariantMap Store::view(qint64 utc, qint64 tick, bool connected) const {
    QVariantList items, members; bool hasMock = false;
    const bool clock = !d->clockInvalid && utc >= d->lastUtc && tick >= d->lastTick &&
        (!d->lastUtc || std::abs((utc - d->lastUtc) - (tick - d->lastTick)) <= 250);
    for (auto source = d->selected.cbegin(); source != d->selected.cend(); ++source) {
        const auto node = d->nodes.value(source.key()); const auto origin = d->selectedSources.value(source.key());
        members.append(QVariantMap{{"node_id", source.key()}, {"robot_key", node.robot}, {"session_id", origin.value("session_id")},
            {"online", connected && clock && node.liveUntil > tick && node.session == origin.value("session_id")}, {"snapshot_id", origin.value("snapshot_id")}});
        const auto proofHash = QString::fromLatin1(QCryptographicHash::hash(compact(origin.value("proof")), QCryptographicHash::Sha256).toHex());
        for (auto record = source->cbegin(); record != source->cend(); ++record) {
            const auto original = record->wrapped.value("observation").toMap(); auto row = original;
            const auto latest = node.history.value(record.key());
            const bool selectedNow = node.session == origin.value("session_id") && node.membership.value(itemKey(original)) == record.key() && latest.bytes == record->bytes;
            const bool withdrawn = original.value("lifecycle") == "withdrawn";
            const bool mock = original.value("source_kind") == "mock"; hasMock = hasMock || mock;
            const bool knownTime = original.value("clock_domain") == "host_utc" && d->config.value("clocks_synchronized").toBool();
            const auto remaining = qMax<qint64>(0, std::min(record->deadline, latest.deadline) - tick);
            const QString state = !clock ? "clock_invalid" : !connected || node.liveUntil <= tick ? "offline" : latest.conflict ? "conflict"
                : !selectedNow ? "superseded" : withdrawn ? "withdrawn" : !remaining ? "expired" : !knownTime ? "time_unverified" : mock ? "mock" : "fresh";
            row["state"] = state; row["remaining_ms"] = state == "fresh" || state == "mock" || state == "time_unverified" ? remaining : 0;
            row["received_at_ms"] = record->received; row["received_age_ms"] = qMax<qint64>(0, tick - record->tick);
            row["source_node"] = source.key(); row["node_session_id"] = origin.value("session_id"); row["snapshot_id"] = origin.value("snapshot_id");
            row["source_proof_ref"] = proofHash; row["relay_deadline_ms"] = record->wrapped.value("relay_deadline_ms");
            row["source_allowed_uses"] = record->wrapped.value("allowed_uses");
            row["allowed_uses"] = state == "fresh" ? record->wrapped.value("allowed_uses") : QVariant(QVariantList{});
            row["peer_authenticated"] = true; row["measurement_verified"] = false; row["producer_clock_authenticated"] = false;
            row["clock_sync_verified"] = false; row["time_basis"] = knownTime ? "declared_bounded_host_utc" : "unverified_producer_clock";
            row["mock"] = mock; row["authoritative"] = false; row["renderable"] = false;
            if (state != "fresh" && state != "mock" && state != "time_unverified") row["value"] = QVariant{};
            items.append(row);
        }
    }
    return {{"schema", 3}, {"kind", "terminal-team-view"}, {"context", d->context},
        {"team_id", d->config.value("team_id")}, {"match_id", d->config.value("match_id")}, {"epoch", d->config.value("epoch")},
        {"publisher_id", d->config.value("publisher_id")}, {"publisher_session_id", d->viewSession},
        {"view_id", d->viewId}, {"revision", d->revision}, {"items", items}, {"members", members}, {"proofs", d->committedProofs},
        {"publisher_proof", d->committedViewProof},
        {"channel_connected", connected}, {"mock", hasMock}, {"ai_input_ready", false}, {"origin_proofs_required", true},
        {"clock_sync_verified", false}, {"clocks_synchronized_declared", d->config.value("clocks_synchronized")},
        {"official_issuer_bound", false}, {"measurement_verified", false}};
}
}
