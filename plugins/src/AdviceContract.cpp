#include "AdviceContract.h"

#include <QJsonArray>
#include <QStringList>
#include <cmath>

namespace {

const QStringList &priorities() {
    static const QStringList values{"info", "caution", "urgent"};
    return values;
}

const QStringList &focuses() {
    static const QStringList values{"health", "heat", "ammo", "map", "communication", "match"};
    return values;
}

const QStringList &requiredFields() {
    static const QStringList fields{"summary", "rationale", "priority", "focus", "expires_in_ms"};
    return fields;
}

QJsonObject stringEnumeration(const QStringList &values) {
    return {{"type", "string"}, {"enum", QJsonArray::fromStringList(values)}};
}

bool validText(const QJsonValue &value, int maximumLength, bool mustHaveContent) {
    if (!value.isString()) {
        return false;
    }

    const QString text = value.toString();
    return text.size() <= maximumLength && (!mustHaveContent || !text.trimmed().isEmpty());
}

}

QJsonObject AdviceContract::schema() {
    // 生成与接收共用字段、枚举定义，避免两端修改后悄悄产生不同契约。
    const QJsonObject properties{
        {"summary", QJsonObject{{"type", "string"}}},
        {"rationale", QJsonObject{{"type", "string"}}},
        {"priority", stringEnumeration(priorities())},
        {"focus", stringEnumeration(focuses())},
        {"expires_in_ms", QJsonObject{{"type", "integer"},
                                      {"enum", QJsonArray{1000, 2000, 3000, 5000, 8000, 10000}}}}};

    return {{"type", "object"},
            {"additionalProperties", false},
            {"properties", properties},
            {"required", QJsonArray::fromStringList(requiredFields())}};
}

bool AdviceContract::validate(const QJsonObject &advice, QString *error) {
    QStringList actualFields = advice.keys();
    QStringList expectedFields = requiredFields();
    actualFields.sort();
    expectedFields.sort();

    const bool fieldsMatch = actualFields == expectedFields;
    const bool textValid = validText(advice.value("summary"), 180, true) &&
                           validText(advice.value("rationale"), 500, false);
    const bool enumsValid = priorities().contains(advice.value("priority").toString()) &&
                            focuses().contains(advice.value("focus").toString());

    // 接收端允许范围内的任意整数毫秒数；生成 schema 仅提供少量候选，
    // 减少小模型生成无效字段的机会。结构合法不代表建议内容正确。
    const QJsonValue lifetimeValue = advice.value("expires_in_ms");
    const double lifetime = lifetimeValue.toDouble(-1);
    const bool lifetimeValid = lifetimeValue.isDouble() && std::isfinite(lifetime) &&
                               lifetime >= 500 && lifetime <= 10000 &&
                               std::floor(lifetime) == lifetime;

    const bool valid = fieldsMatch && textValid && enumsValid && lifetimeValid;
    if (!valid && error) {
        *error = QStringLiteral("模型建议字段不符合契约");
    }
    return valid;
}
