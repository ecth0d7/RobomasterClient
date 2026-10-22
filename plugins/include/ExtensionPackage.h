#pragma once

#include <QObject>
#include <QVariantMap>
#include <QtPlugin>

// Header-only ABI for an optional native part of a QML extension package.
// All calls run on the application's owning thread. Workers must queue their
// results back to their session; host/context pointers must not escape it.
class ExtensionPackageHost {
public:
    virtual ~ExtensionPackageHost() = default;
    virtual QString packageId() const = 0;
    virtual QString packageDirectory() const = 0;
    virtual QVariantMap configuration() const = 0;
    virtual bool active() const = 0;
    virtual QObject *service(const QString &name) const = 0;
    virtual bool registerService(const QString &name, QObject *object) = 0;
    virtual bool publish(const QString &channel, const QVariantMap &payload) = 0;
    virtual bool ownObject(QObject *object) = 0;
};

// The returned QObject implements this interface and is parented to `owner`.
// create() constructs a quiescent session; start() registers declared exports.
// stop() must cancel work, disconnect callbacks and join owned workers before
// returning, including after a failed start. It must be idempotent and noexcept.
class ExtensionPackageSession {
public:
    virtual ~ExtensionPackageSession() = default;
    virtual bool start(QString *error) = 0;
    virtual void stop() noexcept = 0;
};

class ExtensionPackagePlugin {
public:
    virtual ~ExtensionPackagePlugin() = default;
    virtual QString id() const = 0;
    virtual int apiMajor() const = 0;
    virtual QObject *create(ExtensionPackageHost *host, QObject *owner) = 0;
};

#define ExtensionPackagePlugin_iid "org.robomaster.client.ExtensionPackagePlugin/1.0"
#define ExtensionPackageSession_iid "org.robomaster.client.ExtensionPackageSession/1.0"
Q_DECLARE_INTERFACE(ExtensionPackagePlugin, ExtensionPackagePlugin_iid)
Q_DECLARE_INTERFACE(ExtensionPackageSession, ExtensionPackageSession_iid)
