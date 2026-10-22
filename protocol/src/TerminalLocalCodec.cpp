#include "TerminalLocalCodec.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <cmath>

namespace {
constexpr qsizetype MaximumPacket = 64 * 1024;
bool fail(QString *error, const QString &reason) { if (error) *error = reason; return false; }
bool bounded(const QVariant &value, int depth, qsizetype *nodes) {
    if (depth > 8 || ++*nodes > 4096) return false;
    if (!value.isValid() || value.metaType().id() == QMetaType::Nullptr) return true;
    switch (value.metaType().id()) {
    case QMetaType::QVariantMap: {
        const auto map = value.toMap();
        if (map.size() > 64) return false;
        for (auto it = map.cbegin(); it != map.cend(); ++it)
            if (it.key().size() > 128 || !bounded(it.value(), depth + 1, nodes)) return false;
        return true;
    }
    case QMetaType::QVariantList: {
        const auto list = value.toList();
        if (list.size() > 128) return false;
        for (const auto &item : list) if (!bounded(item, depth + 1, nodes)) return false;
        return true;
    }
    case QMetaType::QString: return value.toString().size() <= MaximumPacket;
    case QMetaType::Bool: return true;
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double: case QMetaType::Float:
        return std::isfinite(value.toDouble()) && std::abs(value.toDouble()) <= 9007199254740991.0;
    default: return false;
    }
}
bool localObservation(const QVariantMap &map, QString *error) {
    qsizetype nodes = 0;
    const auto schema = map.value("schema");
    const auto kind = map.value("source_kind");
    if (!bounded(map, 0, &nodes) || schema.metaType().id() == QMetaType::Bool ||
        schema.metaType().id() == QMetaType::QString || schema.toDouble() != 3 ||
        kind.metaType().id() != QMetaType::QString ||
        !QSet<QString>{"local_sensor", "local_vision", "derived", "mock"}.contains(kind.toString()) ||
        map.value("context").metaType().id() != QMetaType::QVariantMap ||
        !map.contains("robot_key") || !map.contains("source_id") || !map.contains("session_id") ||
        !map.contains("sequence") || !map.contains("item_id") || !map.contains("value"))
        return fail(error, QStringLiteral("需要项目schema3本地观测；不是官方协议或官方权威数据"));
    // Detailed types, sequence, scope, time and provenance are admitted by the
    // host bus after decoding. The codec never marks them verified or fresh.
    return true;
}
}
bool TerminalLocalCodec::decode(const QString &, const QByteArray &payload, QString *type,
                                QVariantMap *fields, QString *error) const {
    if (type) type->clear();
    if (fields) fields->clear();
    if (error) error->clear();
    if (payload.isEmpty() || payload.size() > MaximumPacket)
        return fail(error, QStringLiteral("本地JSON包为空或超过64KiB"));
    QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(payload, &parse);
    if (parse.error != QJsonParseError::NoError || !document.isObject())
        return fail(error, QStringLiteral("本地JSON包必须是单个有效对象"));
    const auto observation = document.object().toVariantMap();
    if (!localObservation(observation, error)) return false;
    if (type) *type = QStringLiteral("terminal-observation");
    if (fields) *fields = {{"observation", observation}};
    return true;
}
bool TerminalLocalCodec::encode(const QString &type, const QVariantMap &fields, QString *channel,
                                QByteArray *payload, QString *error) const {
    if (channel) channel->clear();
    if (payload) payload->clear();
    if (error) error->clear();
    if (type != QLatin1String("terminal-observation"))
        return fail(error, QStringLiteral("本地观测编解码器不编码机器人动作"));
    if (!localObservation(fields, error)) return false;
    const auto bytes = QJsonDocument(QJsonObject::fromVariantMap(fields)).toJson(QJsonDocument::Compact);
    if (bytes.size() > MaximumPacket) return fail(error, QStringLiteral("本地JSON包超过64KiB"));
    // The host keeps its explicitly configured transport channel. A local data
    // codec must not invent an MQTT topic or an official endpoint address.
    if (channel) channel->clear();
    if (payload) *payload = bytes;
    return true;
}
