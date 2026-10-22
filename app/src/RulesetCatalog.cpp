#include "RulesetCatalog.h"

#include <QDebug>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QResource>

// Keep Q_INIT_RESOURCE outside a namespace. The explicit call also keeps the
// resource object linked when client_app is consumed as a static library.
static void initializeRulesetResources() {
    Q_INIT_RESOURCE(ruleset_catalog);
}

namespace {
const QJsonObject &catalog() {
    static const QJsonObject value = [] {
        initializeRulesetResources();
        QFile file(QStringLiteral(":/robomaster/rulesets/rulesets.json"));
        if (!file.open(QIODevice::ReadOnly)) {
            qWarning("Cannot open compiled ruleset catalogue");
            return QJsonObject{};
        }
        QJsonParseError error;
        const auto document = QJsonDocument::fromJson(file.readAll(), &error);
        const auto object = document.object();
        if (error.error != QJsonParseError::NoError || !document.isObject()
            || object.value(QStringLiteral("schema")).toInt() != 1
            || !object.value(QStringLiteral("profiles")).isArray()
            || !object.value(QStringLiteral("default_profile_id")).isString()) {
            qWarning("Invalid compiled ruleset catalogue");
            return QJsonObject{};
        }
        return object;
    }();
    return value;
}
}

namespace RulesetCatalog {
QString defaultProfileId() {
    return catalog().value(QStringLiteral("default_profile_id")).toString();
}

QVariantList profiles() {
    return catalog().value(QStringLiteral("profiles")).toArray().toVariantList();
}

QVariantMap profile(const QString &id) {
    for (const auto &entry : catalog().value(QStringLiteral("profiles")).toArray()) {
        const auto object = entry.toObject();
        if (object.value(QStringLiteral("id")).toString() == id)
            return object.toVariantMap();
    }
    // Unknown versions do not silently inherit another season's permissions.
    return {};
}

QVariantList opportunities(const QString &id) {
    return profile(id).value(QStringLiteral("data_opportunities")).toList();
}
}
