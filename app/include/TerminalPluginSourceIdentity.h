#pragma once

#include <QCryptographicHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QVariantMap>
#include <cmath>

// Host-internal logical identity, separate from a source lease's fresh UUID.
// No SDK ABI or official packet format depends on this project-local recipe.
namespace TerminalPluginSourceIdentity {
namespace Detail {
inline bool text(const QVariant &value, qsizetype maximum, bool empty = false) {
    if (value.metaType().id() != QMetaType::QString || value.toString().size() > maximum ||
        (!empty && value.toString().isEmpty())) return false;
    for (const auto c : value.toString())
        if (c.isNull() || c.category() == QChar::Other_Control) return false;
    return true;
}
inline bool configurationValue(const QVariant &value, int depth, int &nodes, qsizetype &cost) {
    constexpr qsizetype MaximumBytes = 64 * 1024;
    if (++nodes > 8192 || depth > 10 || cost > MaximumBytes * 2) return false;
    if (!value.isValid() || value.isNull()) { cost += 4; return true; }
    const auto type = value.metaType().id();
    if (type == QMetaType::QVariantMap) {
        const auto map = value.toMap();
        if (map.size() > 128) return false;
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            if (!text(it.key(), 128)) return false;
            cost += it.key().size() * 2 + 4;
            if (!configurationValue(it.value(), depth + 1, nodes, cost)) return false;
        }
    } else if (type == QMetaType::QVariantList) {
        const auto list = value.toList();
        if (list.size() > 128) return false;
        for (const auto &entry : list)
            if (!configurationValue(entry, depth + 1, nodes, cost)) return false;
    } else if (type == QMetaType::QString) {
        if (!text(value, 8192, true)) return false;
        cost += value.toString().size() * 2 + 2;
    } else if (type == QMetaType::Bool) cost += 5;
    else {
        switch (type) {
        case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
        case QMetaType::ULongLong: case QMetaType::Double: case QMetaType::Float: break;
        default: return false;
        }
        const auto number = value.toDouble();
        if (!std::isfinite(number) || std::abs(number) > 9007199254740991.0) return false;
        cost += 24;
    }
    return cost <= MaximumBytes * 2;
}
}
inline QString configurationFingerprint(const QVariantMap &configuration) {
    int nodes = 0; qsizetype cost = 0;
    if (!Detail::configurationValue(configuration, 0, nodes, cost)) return {};
    // QVariantMap has ordered keys. JSON preserves the reviewed JSON value
    // across settings round-trips without exposing its contents in provenance.
    const auto bytes = QJsonDocument::fromVariant(configuration).toJson(QJsonDocument::Compact);
    if (bytes.size() > 64 * 1024) return {};
    return QString::fromLatin1(QCryptographicHash::hash(bytes, QCryptographicHash::Sha256).toHex());
}
inline QString logicalSourceId(const QVariantMap &binding) {
    const auto contextValue = binding.value("context");
    if (contextValue.metaType().id() != QMetaType::QVariantMap) return {};
    const auto context = contextValue.toMap();
    QVariantList fields{QStringLiteral("robomaster.native-source.logical.v1")};
    for (const auto &key : {"package_id", "package_version", "package_fingerprint", "configuration_fingerprint"}) {
        if (!Detail::text(binding.value(key), 96)) return {};
        fields.append(binding.value(key));
    }
    for (const auto &key : {"profile_id", "field_profile_id", "capability_revision"}) {
        if (!Detail::text(context.value(key), 128)) return {};
        fields.append(context.value(key));
    }
    for (const auto &key : {"environment", "team_id", "robot_key", "original_source_id",
                            "original_sensor_id", "source_kind", "clock_domain"}) {
        if (!Detail::text(binding.value(key), 96, QLatin1String(key) == "original_sensor_id")) return {};
        fields.append(binding.value(key));
    }
    // A JSON array frames every component, so embedded separators cannot merge
    // two bindings. Full SHA256 remains bounded below the bus's 96-byte ID cap.
    const auto bytes = QJsonDocument(QJsonArray::fromVariantList(fields)).toJson(QJsonDocument::Compact);
    const auto digest = QString::fromLatin1(QCryptographicHash::hash(bytes, QCryptographicHash::Sha256).toHex());
    return (binding.value("source_kind") == "mock" ? QStringLiteral("mock.plugin.logical.v1.")
                                                   : QStringLiteral("plugin.logical.v1.")) + digest;
}
}
