#include "DecisionContext.h"
#include <QStringList>
#include <QSet>
#include <cmath>

namespace {
QVariant bounded(const QVariant &value, int depth = 0) {
    if (depth >= 4)
        return QStringLiteral("[省略深层字段]");
    if (value.metaType().id() == QMetaType::QVariantMap) {
        QVariantMap result;
        const auto map = value.toMap();
        for (auto it = map.cbegin(); it != map.cend() && result.size() < 48; ++it)
            result[it.key()] = bounded(it.value(), depth + 1);
        return result;
    }
    if (value.metaType().id() == QMetaType::QVariantList) {
        QVariantList result;
        const auto list = value.toList();
        for (qsizetype i = 0; i < qMin<qsizetype>(list.size(), 64); ++i)
            result.append(bounded(list[i], depth + 1));
        return result;
    }
    if (value.metaType().id() == QMetaType::QString)
        return value.toString().left(500);
    if (value.metaType().id() == QMetaType::QByteArray)
        return QStringLiteral("[二进制省略]");
    return value;
}
void ratio(QVariantMap &facts, const QVariantMap &dynamic, const QVariantMap &fixed,
           const QString &current, const QString &maximum, const QString &name) {
    if (!dynamic.contains(current) || !fixed.contains(maximum))
        return;
    const auto a = dynamic.value(current), b = fixed.value(maximum);
    if (a.metaType().id() == QMetaType::QString || b.metaType().id() == QMetaType::QString ||
        a.metaType().id() == QMetaType::Bool || b.metaType().id() == QMetaType::Bool)
        return;
    bool currentOk = false, maxOk = false;
    const double amount = a.toDouble(&currentOk), limit = b.toDouble(&maxOk);
    if (currentOk && maxOk && std::isfinite(amount) && std::isfinite(limit) && amount >= 0 &&
        limit > 0) {
        const double percentage = amount / limit * 100.0;
        if (std::isfinite(percentage) && percentage <= 1000000)
            facts[name] = std::round(percentage * 10.0) / 10.0;
    }
}
}
QVariantMap DecisionContext::build(const QVariantMap &snapshot) {
    QVariantMap groups;
    QStringList unavailable, omitted, unavailableFields;
    const auto freshness = snapshot.value("freshness").toMap();
    const auto received = snapshot.value("groups").toMap();
    const auto fieldFreshness = snapshot.value("field_freshness").toMap();
    for (auto it = freshness.cbegin(); it != freshness.cend(); ++it) {
        if (it.value() != "fresh") {
            unavailable.append(it.key());
            continue;
        }
        // 不透明字节及累计轨迹数组不适合作为简明决策依据。
        // 它们仍保留在接收状态和实验室桥接快照中。
        if (it.key() == "customByteBlock" || it.key() == "robotPath") {
            omitted.append(it.key());
            continue;
        }
        if (received.contains(it.key())) {
            auto values = received.value(it.key()).toMap();
            if (fieldFreshness.contains(it.key())) {
                const auto states = fieldFreshness.value(it.key()).toMap();
                for (auto field = values.begin(); field != values.end();) {
                    if (states.value(field.key()) != "fresh") {
                        unavailableFields.append(it.key() + "." + field.key());
                        field = values.erase(field);
                    } else
                        ++field;
                }
            }
            groups[it.key()] = bounded(values);
        }
    }
    QVariantMap facts;
    if (groups.contains("robotDynamic") && groups.contains("robotStatic")) {
        const auto dynamic = groups.value("robotDynamic").toMap(),
                   fixed = groups.value("robotStatic").toMap();
        ratio(facts, dynamic, fixed, "current_health", "max_health", "health_percent");
        ratio(facts, dynamic, fixed, "current_heat", "max_heat", "heat_percent");
    }
    QVariantMap result{{"client_id", snapshot.value("client_id")},
                       {"connected", snapshot.value("connected")},
                       {"groups", groups},
                       {"freshness", freshness},
                       {"unavailable_groups", unavailable},
                       {"omitted_groups", omitted},
                       {"unavailable_fields", unavailableFields},
                       {"computed_facts", facts}};
    if (snapshot.contains("fixture"))
        result["fixture"] = snapshot.value("fixture");
    return result;
}

qint64 DecisionContext::remainingLifetime(const QVariantMap &observation) {
    constexpr qint64 SafeInteger = 9007199254740991LL;
    if (observation.value("clock").metaType().id() != QMetaType::QString ||
        observation.value("clock") != "local_monotonic" ||
        observation.value("ingress_basis").metaType().id() != QMetaType::QString ||
        observation.value("ingress_basis") != "mqtt_callback" ||
        observation.value("ingress_clock_verified").metaType().id() != QMetaType::Bool ||
        !observation.value("ingress_clock_verified").toBool())
        return 0;
    const auto session = observation.value("ingress_session_id");
    if (session.metaType().id() != QMetaType::QString || session.toString().isEmpty() ||
        session.toString().size() > 96)
        return 0;
    for (const auto c : session.toString()) {
        const auto u = c.unicode();
        if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') ||
              (u >= '0' && u <= '9') || u == '-' || u == '_' || u == '.' || u == ':'))
            return 0;
    }
    auto integer = [](const QVariant &value) -> qint64 {
        // QVariant conversion alone would admit booleans, text, dates and
        // custom convertible types. The producer must supply actual numbers.
        switch (value.metaType().id()) {
        case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
        case QMetaType::ULongLong: case QMetaType::Double: case QMetaType::Float:
        case QMetaType::Long: case QMetaType::ULong: case QMetaType::Short:
        case QMetaType::UShort: case QMetaType::Char: case QMetaType::UChar: break;
        default:
            return -1;
        }
        const double number = value.toDouble();
        return std::isfinite(number) && number >= 0 && number <= double(SafeInteger) &&
                       std::floor(number) == number
                   ? qint64(number)
                   : -1;
    };
    const auto age = integer(observation.value("received_age_ms"));
    const auto lifetime = integer(observation.value("lifetime_ms"));
    const auto remaining = integer(observation.value("remaining_ms"));
    const auto queueAge = integer(observation.value("queue_age_ms_at_ingest"));
    const auto sequence = integer(observation.value("ingress_sequence"));
    // The callback-to-apply delay has already consumed the field lifetime. It
    // cannot disappear when the GUI eventually handles a queued packet.
    return sequence > 0 && age >= 0 && queueAge >= 0 && queueAge <= age &&
                   lifetime > 0 && lifetime <= 10000 && remaining > 0 &&
                   remaining == lifetime - age
               ? remaining
               : 0;
}
QVariantMap DecisionContext::permitted(const QVariantMap &snapshot, const QStringList &categories) {
    // Only necessary own-robot data is admitted. Opaque bytes, paths, arbitrary
    // event text, raw bridge peers and unintegrated sensor drafts never enter.
    const QMap<QString, QMap<QString, QStringList>> fields{
        {"health",
         {{"robotDynamic",
           {"current_health", "is_out_of_combat", "out_of_combat_countdown", "can_remote_heal"}},
          {"robotStatic", {"max_health", "alive_state"}},
          {"robotRespawn",
           {"is_pending_respawn", "total_respawn_progress", "current_respawn_progress",
            "can_free_respawn", "gold_cost_for_respawn", "can_pay_for_respawn"}}}},
        {"resources",
         {{"robotDynamic",
           {"current_heat", "remaining_ammo", "current_chassis_energy", "current_buffer_energy",
            "can_remote_ammo", "last_projectile_fire_rate"}},
          {"robotStatic",
           {"max_heat", "heat_cooldown_rate", "max_power", "max_buffer_energy",
            "max_chassis_energy"}},
          {"globalLogistics", {"remaining_economy", "tech_level", "encryption_level"}}}},
        {"position", {{"robotPosition", {"robot_id", "x", "y", "z", "yaw"}}}},
        {"objective",
         {{"gameStatus",
           {"current_round", "current_stage", "stage_countdown_sec", "stage_elapsed_sec",
            "is_paused"}},
          {"robotStatic", {"level", "robot_type"}},
          {"robotDynamic", {"current_experience", "experience_for_upgrade"}},
          {"techCore",
           {"maximum_difficulty_level", "basic_state", "putin_state", "move_state", "rotate_state",
            "enemy_core_status", "remain_time_all", "remain_time_step"}},
          {"deployMode", {"status"}},
          {"runeStatus", {"rune_status", "activated_arms", "average_rings"}},
          {"sentryStatus", {"posture_id", "is_weakened", "is_powered"}},
          {"airSupport",
           {"airsupport_status", "left_time", "cost_coins", "is_being_targeted",
            "shooter_status"}}}}};
    QVariantMap admitted, freshness, fieldStates, admittedObservations;
    const auto values = snapshot.value("groups").toMap();
    const auto states = snapshot.value("field_freshness").toMap();
    const auto observations = snapshot.value("field_observations").toMap();
    qint64 remaining = 10000;
    for (const auto &category : categories) {
        const auto selected = fields.value(category);
        for (auto group = selected.cbegin(); group != selected.cend(); ++group) {
            const auto data = values.value(group.key()).toMap();
            // Position can describe a different robot on the gunner endpoint.
            if (group.key() == "robotPosition") {
                const auto owner = data.value("robot_id");
                if (states.value(group.key()).toMap().value("robot_id") != "fresh" ||
                    owner.metaType().id() == QMetaType::Bool ||
                    owner.metaType().id() == QMetaType::QString ||
                    owner.toDouble() != snapshot.value("client_id").toInt() ||
                    remainingLifetime(
                        observations.value(group.key()).toMap().value("robot_id").toMap()) <= 0)
                    continue;
            }
            auto output = admitted.value(group.key()).toMap();
            auto outputStates = fieldStates.value(group.key()).toMap();
            auto metadata = admittedObservations.value(group.key()).toMap();
            for (const auto &field : group.value()) {
                const auto observed = observations.value(group.key()).toMap().value(field).toMap();
                const auto time = remainingLifetime(observed);
                if (!data.contains(field) ||
                    states.value(group.key()).toMap().value(field) != "fresh" || time <= 0)
                    continue;
                const auto value = data.value(field);
                static const QSet<QString> booleans{
                    "is_out_of_combat",   "can_remote_heal",  "can_remote_ammo",
                    "is_pending_respawn", "can_free_respawn", "can_pay_for_respawn",
                    "is_paused",          "is_weakened",      "is_powered"};
                static const QSet<QString> floating{"x",
                                                    "y",
                                                    "z",
                                                    "yaw",
                                                    "current_heat",
                                                    "last_projectile_fire_rate",
                                                    "heat_cooldown_rate",
                                                    "average_rings"};
                if (booleans.contains(field)) {
                    if (value.metaType().id() != QMetaType::Bool)
                        continue;
                } else {
                    bool numeric = false;
                    const auto number = value.toDouble(&numeric);
                    if (value.metaType().id() == QMetaType::QString ||
                        value.metaType().id() == QMetaType::Bool || !numeric ||
                        !std::isfinite(number))
                        continue;
                    if (!floating.contains(field) &&
                        (number < 0 || number > 4294967295.0 || std::floor(number) != number))
                        continue;
                }
                output[field] = value;
                outputStates[field] = "fresh";
                metadata[field] = observed;
                remaining = qMin(remaining, time);
            }
            if (!output.isEmpty()) {
                admitted[group.key()] = output;
                freshness[group.key()] = "fresh";
                fieldStates[group.key()] = outputStates;
                admittedObservations[group.key()] = metadata;
            }
        }
    }
    auto result = build({{"client_id", snapshot.value("client_id")},
                         {"connected", snapshot.value("connected")},
                         {"groups", admitted},
                         {"freshness", freshness},
                         {"field_freshness", fieldStates}});
    result["field_observations"] = admittedObservations;
    result["valid_for_ms"] = admitted.isEmpty() ? 0 : remaining;
    result["source_kind"] = "official_player_client";
    result["producer_timestamp_verified"] = false;
    result["position_units_verified"] = false;
    result["admitted_categories"] = categories;
    return result;
}
