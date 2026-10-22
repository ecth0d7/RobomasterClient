#pragma once
#include <QObject>
#include <QString>

// Shared SDK state, rather than a header/static-provider singleton: separately
// linked native packages observe the same gate in client_plugin_sdk. These
// functions run on the application's owning GUI thread; acquired objects must
// stay on that thread. A name identifies one process resource, not a grant.
namespace ProcessLifetimeGate {
QObject *current(const QString &name);
// No manual release: cancellation/provider replacement must not clear the gate
// before its run/reaper and private resources have actually been destroyed.
// Reacquiring the same lifetime is idempotent; a different live owner fails.
bool acquire(const QString &name, QObject *lifetime);
}
