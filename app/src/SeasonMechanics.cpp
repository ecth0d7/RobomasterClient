#include "SeasonMechanics.h"

#include <cmath>

namespace {
const QString ProfileId = QStringLiteral("rmuc2027-regional-v1.0.0");
constexpr double BaseHealthMaximum = 10000.0;

QVariantMap reference(const QString &section, const QVariantList &pages,
                      const QString &formula, const QString &explanation) {
    // No receipt time, freshness, or source proof is invented for operator
    // inputs. In particular, this map is not a SourceRegistry telemetry item.
    return {{"profile_id", ProfileId},
            {"source_kind", QStringLiteral("derived")},
            {"status", QStringLiteral("reference_only")},
            {"calculation_mode", QStringLiteral("manual_reference")},
            {"input_source", QStringLiteral("manual")},
            {"authoritative", false},
            {"live", false},
            {"document_id", QStringLiteral("rmuc2027-rules-v1.0.0-20261015")},
            {"document_reference",
             QStringLiteral("docs/references/rm2027/rmuc2027-rules-v1.0.0-20261015.pdf")},
            {"document_title", QStringLiteral("RoboMaster 2027 超级对抗赛比赛规则 V1.0.0")},
            {"document_pages", pages},
            {"section", section},
            {"formula", formula},
            {"explanation", explanation}};
}
}

QVariantMap SeasonMechanics::logistics(const QString &profileId, double currentBaseHealth) {
    if (profileId != ProfileId || !std::isfinite(currentBaseHealth) ||
        currentBaseHealth < 0 || currentBaseHealth > BaseHealthMaximum)
        return {};

    const double loss = BaseHealthMaximum - currentBaseHealth;
    const double lambda = 1.0 - loss / 20000.0;
    auto result = reference(
        QStringLiteral("5.6.1 / 表5-19"), {94, 95},
        QStringLiteral("λ = 1 - (10000 - H) / 20000; 回血与带宽倍率 = λ; "
                       "复活所需读条倍率 = 1/λ; 图传有效像素面积倍率 = λ²"),
        QStringLiteral("手动输入基地血量的规则参考计算，非实时裁判状态。回血倍率用于补给区回血速率及"
                       "远程兑换血量的回血比例，不直接改写机器人血量。图传倍率描述有效像素面积，"
                       "不是长或宽各乘该倍率；不改变收到的视频。基地被击毁时的边界值仅作公式参考，"
                       "不表示比赛仍在进行或允许操作。"));
    result.insert("base_health", currentBaseHealth);
    result.insert("max_base_health", BaseHealthMaximum);
    result.insert("lost_base_health", loss);
    result.insert("lambda", lambda);
    result.insert("health_multiplier", lambda);
    result.insert("bandwidth_multiplier", lambda);
    result.insert("respawn_time_factor", 1.0 / lambda);
    result.insert("video_pixel_area_factor", lambda * lambda);
    result.insert("units", QVariantMap{{"base_health", "HP"}, {"max_base_health", "HP"},
                                      {"lost_base_health", "HP"}, {"lambda", "ratio"},
                                      {"health_multiplier", "ratio"},
                                      {"bandwidth_multiplier", "ratio"},
                                      {"respawn_time_factor", "ratio"},
                                      {"video_pixel_area_factor", "ratio"}});
    return result;
}

QVariantMap SeasonMechanics::territoryRate(const QString &profileId,
                                          bool controlBothOutpostTerritories,
                                          bool controlBothBaseTerritories) {
    if (profileId != ProfileId)
        return {};

    // The two independent conditions on printed p97 contribute separately.
    // "Control" is the document's term; do not strengthen it to full control.
    const int outpostRate = controlBothOutpostTerritories ? 1 : 0;
    const int baseRate = controlBothBaseTerritories ? 3 : 0;
    auto result = reference(
        QStringLiteral("5.6.2"), {97},
        QStringLiteral("每秒控制度 = (控制全部两个前哨阵地 ? 1 : 0) + "
                       "(控制全部两个基地阵地 ? 3 : 0)"),
        QStringLiteral("手动选择阵地控制条件的规则参考速率，非实时控制权或累计控制度。"
                       "原文使用“控制”，不额外要求“完全控制”。两个条件独立满足时合计每秒4点；"
                       "本计算不判断阵地归属、5秒占领进退或争夺暂停，不随时间累计分数。"));
    result.insert("control_both_outpost_territories", controlBothOutpostTerritories);
    result.insert("control_both_base_territories", controlBothBaseTerritories);
    result.insert("outpost_points_per_second", outpostRate);
    result.insert("base_points_per_second", baseRate);
    result.insert("control_points_per_second", outpostRate + baseRate);
    result.insert("units", QVariantMap{{"outpost_points_per_second", "control_points/s"},
                                      {"base_points_per_second", "control_points/s"},
                                      {"control_points_per_second", "control_points/s"}});
    return result;
}
