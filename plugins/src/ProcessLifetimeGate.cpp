#include "ProcessLifetimeGate.h"
#include <QCoreApplication>
#include <QMap>
#include <QPointer>
#include <QThread>

namespace {
QMap<QString, QPointer<QObject>> &registry() {
    static QMap<QString, QPointer<QObject>> entries;
    return entries;
}
bool owningThread() {
    const auto *application = QCoreApplication::instance();
    return application && QThread::currentThread() == application->thread();
}
bool validName(const QString &name) { return !name.isEmpty() && name.size() <= 96; }
}
QObject *ProcessLifetimeGate::current(const QString &name) {
    if (!owningThread() || !validName(name)) return nullptr;
    return registry().value(name).data();
}
bool ProcessLifetimeGate::acquire(const QString &name, QObject *lifetime) {
    if (!owningThread() || !validName(name) || !lifetime || lifetime->thread() != QThread::currentThread()) return false;
    auto &entries = registry();
    for (auto it = entries.begin(); it != entries.end();)
        if (!it.value()) it = entries.erase(it); else ++it;
    const auto previous = entries.value(name);
    if (previous && previous != lifetime) return false;
    entries[name] = lifetime;
    return true;
}
