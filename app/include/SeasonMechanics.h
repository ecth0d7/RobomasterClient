#pragma once

#include <QString>
#include <QVariantMap>

// Explicit rule-reference calculators. These functions do not read telemetry,
// infer ownership, advance scores, change video, or submit robot commands.
// Unknown profiles/invalid inputs return an empty map; no season fallback.
namespace SeasonMechanics {
QVariantMap logistics(const QString &profileId, double currentBaseHealth);
QVariantMap territoryRate(const QString &profileId, bool controlBothOutpostTerritories,
                         bool controlBothBaseTerritories);
}
