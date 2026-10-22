#pragma once
#include <QUrl>
#include <QString>
#include <QVariantList>
namespace UiPack {
QUrl entry(const QString &directory, QString *error, const QString &viewId = {});
QVariantList viewCatalog(const QString &directory, QString *error);
}
