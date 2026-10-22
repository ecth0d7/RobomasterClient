#pragma once

#include <QString>
#include <QVariantMap>

class ExtensionPackagePlugin;

namespace NativePackageLoader {
// Native code remains mapped for the process, even after its sessions retire.
// A changed binary at a previously used path must never resolve to Qt's cached
// old factory while the manager reports that the new artifact is running.
bool restartRequired(const QString &library, const QString &fingerprint);
ExtensionPackagePlugin *load(const QVariantMap &manifest, QString *error);
}
