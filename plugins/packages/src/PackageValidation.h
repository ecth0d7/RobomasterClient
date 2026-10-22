#pragma once
#include <QVariantMap>

namespace PackageValidation {
constexpr int MaximumPackages = 64;
constexpr int MaximumManifestBytes = 64 * 1024;
constexpr int MaximumConfigurationBytes = 64 * 1024;
constexpr int MaximumStoreBytes = 512 * 1024;
bool fail(QString *, const QString &);
QByteArray json(const QVariant &);
bool bounded(const QVariant &, qsizetype maximum = MaximumConfigurationBytes);
bool identifier(const QString &);
bool serviceName(const QString &);
bool schema(const QVariantMap &, QString *error = nullptr);
bool configuration(const QVariantMap &schema, const QVariantMap &values, QString *error = nullptr);
bool manifest(const QString &directory, QVariantMap *out, QString *error = nullptr);
bool files(const QString &directory, QStringList *relativeFiles, QString *error = nullptr);
bool store(const QString &file, QVariantList *scopes, QString *error = nullptr);
bool write(const QString &file, const QByteArray &, QString *error = nullptr);
}
