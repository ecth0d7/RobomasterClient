#include "TerminalGatewayContract.h"
#include "TerminalDataBus.h"
#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QSet>
#include <cmath>

namespace {
bool fail(QString *error, const QString &reason) { if (error) *error = reason; return false; }
bool line(const QVariant &value, int maximum, bool empty = false) {
    if (value.metaType().id() != QMetaType::QString) return false;
    const auto text = value.toString();
    if ((!empty && text.isEmpty()) || text.size() > maximum) return false;
    for (const auto c : text) if (c.isNull() || c.category() == QChar::Other_Control) return false;
    return true;
}
bool integer(const QVariant &value, qint64 low, qint64 high) {
    switch (value.metaType().id()) {
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double: break;
    default: return false;
    }
    const auto n = value.toDouble();
    return std::isfinite(n) && std::floor(n) == n && n >= double(low) && n <= double(high);
}
bool exact(const QVariantMap &map, const QSet<QString> &required, const QSet<QString> &optional = {}) {
    for (const auto &key : required) if (!map.contains(key)) return false;
    for (auto it = map.cbegin(); it != map.cend(); ++it)
        if (!required.contains(it.key()) && !optional.contains(it.key())) return false;
    return true;
}
bool rules(const QVariantMap &map) {
    return exact(map, {"profile_id", "field_profile_id", "capability_revision"}) &&
        TerminalGatewayContract::token(map.value("profile_id"), 128) &&
        TerminalGatewayContract::token(map.value("field_profile_id"), 128) &&
        TerminalGatewayContract::token(map.value("capability_revision"), 128);
}
bool topics(const QVariant &value, QVariantList *result) {
    QVariantList list;
    if (value.metaType().id() == QMetaType::QStringList)
        for (const auto &topic : value.toStringList()) list.append(topic);
    else if (value.metaType().id() == QMetaType::QVariantList) list = value.toList();
    else return false;
    if (list.size() > 32) return false;
    QSet<QString> used;
    for (const auto &entry : list) {
        if (!line(entry, 256) || entry.toString().contains('#') || entry.toString().contains('+') ||
            entry.toString().startsWith('$') || used.contains(entry.toString())) return false;
        used.insert(entry.toString());
    }
    *result = list; return true;
}
bool publicValue(const QVariant &value, int depth = 0) {
    if (depth > 5) return false;
    if (!value.isValid() || value.metaType().id() == QMetaType::Nullptr || value.metaType().id() == QMetaType::Bool) return true;
    if (value.metaType().id() == QMetaType::QString) return line(value, 1024, true);
    if (value.metaType().id() == QMetaType::QVariantMap) {
        const auto map = value.toMap();
        if (map.size() > 32) return false;
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            const auto key = it.key().toLower();
            if (!line(it.key(), 64) || key.contains("secret") || key.contains("password") ||
                key.contains("token") || key.contains("credential") || key.contains("private") ||
                key.contains("certificate") || key.contains("tls") || key.contains("key") ||
                !publicValue(it.value(), depth + 1)) return false;
        }
        return true;
    }
    if (value.metaType().id() == QMetaType::QVariantList) {
        const auto list = value.toList(); if (list.size() > 32) return false;
        for (const auto &entry : list) if (!publicValue(entry, depth + 1)) return false;
        return true;
    }
    switch (value.metaType().id()) {
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double: return std::isfinite(value.toDouble()) && std::abs(value.toDouble()) <= 9007199254740991.0;
    default: return false;
    }
}
}

QString TerminalGatewayContract::loopbackId() { return QStringLiteral("terminal.link.loopback.v1"); }
bool TerminalGatewayContract::token(const QVariant &value, int maximum) {
    if (!line(value, maximum)) return false;
    for (const auto c : value.toString()) {
        const auto u = c.unicode();
        if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') || (u >= '0' && u <= '9') ||
              u == '-' || u == '_' || u == '.' || u == ':' || u == '/')) return false;
    }
    return true;
}
QVariantMap TerminalGatewayContract::context(const QVariantMap &season) {
    QVariantMap result{{"profile_id", season.value("profile_id", season.value("id"))},
        {"field_profile_id", season.value("field_profile_id")}, {"capability_revision", season.value("capability_revision")}};
    return rules(result) ? result : QVariantMap{};
}
bool TerminalGatewayContract::configuration(const QString &pluginId, const QVariantMap &publicConfiguration,
                                            const QVariantMap &scope, QVariantMap *normalized, QString *error) {
    if (error) error->clear();
    if (!token(pluginId) || !rules(scope)) return fail(error, "Invalid terminal plugin or rules context");
    auto values = publicConfiguration;
    if (values.contains("schema") && !integer(values.value("schema"), 1, 1)) return fail(error, "Unsupported terminal-link schema");
    if (values.contains("context") && (values.value("context").metaType().id() != QMetaType::QVariantMap ||
        !rules(values.value("context").toMap()) || values.value("context").toMap() != scope))
        return fail(error, "Terminal configuration belongs to another rules context");
    values.remove("schema"); values.remove("context");
    if (pluginId == loopbackId()) {
        if (!values.isEmpty()) return fail(error, "Loopback has no address or credential configuration");
    } else if (pluginId == "terminal.link.mqtt.v1") {
        QVariantList receive, send;
        if (!exact(values, {"host", "port", "client_id", "receive_topics", "send_topics"}) ||
            !line(values.value("host"), 253) || !integer(values.value("port"), 1, 65535) ||
            !token(values.value("client_id"), 96) || !topics(values.value("receive_topics"), &receive) ||
            !topics(values.value("send_topics"), &send) || (receive.isEmpty() && send.isEmpty()))
            return fail(error, "MQTT requires an explicit host, port, client ID and bounded literal topic allowlists");
        const auto host = values.value("host").toString();
        for (const auto c : host) if (c.isSpace() || QStringLiteral("/\\?#@[]").contains(c))
            return fail(error, "MQTT host is not a hostname or numeric IP address");
        QHostAddress numeric;
        if (host.contains(':') && !numeric.setAddress(host))
            return fail(error, "MQTT IPv6 host must be a numeric address without a URI or port");
        for (const auto &entry : receive) if (send.contains(entry))
            return fail(error, "MQTT send and receive topics must be disjoint to prevent self loops");
        values["receive_topics"] = receive; values["send_topics"] = send;
    } else if (pluginId == "terminal.link.udp.v1") {
        QHostAddress bind, peer;
        if (!exact(values, {"bind_address", "bind_port", "peer_address", "peer_port"}) ||
            !line(values.value("bind_address"), 64) || !line(values.value("peer_address"), 64) ||
            !bind.setAddress(values.value("bind_address").toString()) ||
            bind.isMulticast() || bind == QHostAddress::Broadcast ||
            !peer.setAddress(values.value("peer_address").toString()) || peer.isNull() || peer.isMulticast() ||
            peer == QHostAddress::Any || peer == QHostAddress::AnyIPv4 || peer == QHostAddress::AnyIPv6 ||
            peer == QHostAddress::Broadcast || !integer(values.value("bind_port"), 0, 65535) ||
            !integer(values.value("peer_port"), 1, 65535))
            return fail(error, "UDP requires explicit numeric bind and unicast peer addresses/ports");
    } else if (!exact(values, {}, {"options"}) ||
               (values.contains("options") && (values.value("options").metaType().id() != QMetaType::QVariantMap ||
                                               !publicValue(values.value("options"))))) {
        return fail(error, "Third-party terminal links accept only explicitly public bounded options, without credentials");
    }
    values.insert("schema", 1); values.insert("context", scope);
    if (QJsonDocument::fromVariant(values).toJson(QJsonDocument::Compact).size() > 8192)
        return fail(error, "Terminal public configuration exceeds 8 KiB");
    if (normalized) *normalized = values;
    return true;
}
bool TerminalGatewayContract::encodeObservation(const QVariantMap &observation, const QVariantMap &scope,
                                                bool allowMock, QByteArray *payload, QString *error) {
    if (error) error->clear();
    if (!rules(scope) || !integer(observation.value("schema"), 3, 3) ||
        observation.value("context").metaType().id() != QMetaType::QVariantMap ||
        !rules(observation.value("context").toMap()) || observation.value("context").toMap() != scope)
        return fail(error, "Only context-bound project-local schema3 observations are normalized");
    const auto kind = observation.value("source_kind");
    if (kind.metaType().id() != QMetaType::QString ||
        (kind != "local_sensor" && kind != "local_vision" && kind != "derived" && !(allowMock && kind == "mock")))
        return fail(error, "Official engine/player authority has no registered protocol binding");
    // Reuse the pure bus admission rules without adding an item or inventing
    // receipt, freshness, adapter state, or a network connection.
    if (!TerminalDataBus::validateObservation(observation, scope, allowMock, error)) return false;
    const auto bytes = QJsonDocument::fromVariant(observation).toJson(QJsonDocument::Compact);
    if (bytes.isEmpty() || bytes.size() > MaximumPayloadBytes) return fail(error, "Local observation exceeds 64 KiB");
    if (payload) *payload = bytes;
    return true;
}
bool TerminalGatewayContract::decodeObservation(const QByteArray &payload, const QVariantMap &scope,
                                                bool allowMock, QVariantMap *observation, QString *error) {
    if (payload.isEmpty() || payload.size() > MaximumPayloadBytes) return fail(error, "Empty or oversized project-local JSON packet");
    QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(payload, &parse);
    if (parse.error != QJsonParseError::NoError || !document.isObject()) return fail(error, "Raw packet is not a project-local JSON observation");
    const auto map = document.object().toVariantMap();
    auto checked = map;
    if (!(allowMock && map.value("source_kind") == "mock"))
        checked["clock_domain"] = "remote_unverified";
    QByteArray bounded;
    if (!encodeObservation(checked, scope, allowMock, &bounded, error)) return false;
    if (observation) *observation = map;
    return true;
}
bool TerminalGatewayContract::wireReceived(const QVariantMap &message, const QVariantMap &scope,
                                          QVariantMap *normalized, QString *error) {
    if (!exact(message, {"schema", "kind", "context", "session_id", "sequence", "received_at_ms",
                        "received_tick_ms", "channel", "payload", "transport_kind", "peer", "authoritative", "source_kind"},
                       {"received_timing_basis", "request_id"}) || !integer(message.value("schema"), 1, 1) ||
        message.value("kind") != "wire-received" || message.value("context").metaType().id() != QMetaType::QVariantMap ||
        !rules(message.value("context").toMap()) || message.value("context").toMap() != scope ||
        !token(message.value("session_id")) || !integer(message.value("sequence"), 1, 9007199254740991LL) ||
        !integer(message.value("received_at_ms"), 1, 9007199254740991LL) ||
        !integer(message.value("received_tick_ms"), 0, 9007199254740991LL) ||
        !line(message.value("channel"), 256) || !line(message.value("peer"), 256, true) ||
        message.value("payload").metaType().id() != QMetaType::QByteArray ||
        message.value("payload").toByteArray().size() > MaximumPayloadBytes ||
        message.value("authoritative").metaType().id() != QMetaType::Bool || message.value("authoritative").toBool() ||
        message.value("source_kind") != "unclassified" ||
        !line(message.value("transport_kind"), 32))
        return fail(error, "Invalid bounded unclassified terminal-link receive envelope");
    if (message.contains("received_timing_basis") && !line(message.value("received_timing_basis"), 64))
        return fail(error, "Invalid terminal receive timing basis");
    if (normalized) *normalized = message;
    return true;
}
QVariantMap TerminalGatewayContract::wireSend(const QString &channel, const QByteArray &payload,
                                            const QString &requestId) {
    return {{"schema", 1}, {"kind", "wire-send"}, {"request_id", requestId}, {"channel", channel}, {"payload", payload}};
}
