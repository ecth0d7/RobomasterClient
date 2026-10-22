#pragma once

#include <QString>
#include <QVariantList>
#include <QVariantMap>

// Versioned, read-only reference metadata. Capability and opportunity rows are
// not live telemetry, protocol declarations, user consent or command authority.
namespace RulesetCatalog {
QString defaultProfileId();
QVariantList profiles();
QVariantMap profile(const QString &id);
QVariantList opportunities(const QString &id);
}
