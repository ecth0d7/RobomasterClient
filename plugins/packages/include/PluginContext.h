#pragma once

#include <QObject>
#include <QJSValue>
#include <QVariantMap>
#include <memory>
#include "ExtensionPackage.h"
#include "TerminalObservationSource.h"

class PluginPackageRuntime;
class QQmlContext;
class QQmlEngine;

class PluginContext final : public QObject, public ExtensionPackageHost, public TerminalObservationSourceFactory {
    Q_OBJECT
    Q_INTERFACES(TerminalObservationSourceFactory)
    Q_PROPERTY(QString packageId READ packageId CONSTANT)
    Q_PROPERTY(QString packageDirectory READ packageDirectory CONSTANT)
    Q_PROPERTY(QVariantMap configuration READ configuration CONSTANT)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(qulonglong servicesRevision READ servicesRevision NOTIFY servicesChanged)
public:
    ~PluginContext() override;
    QString packageId() const override;
    QString packageDirectory() const override;
    QVariantMap configuration() const override;
    bool active() const override;
    qulonglong servicesRevision() const;
    Q_INVOKABLE QObject *service(const QString &name) const override;
    Q_INVOKABLE bool registerService(const QString &name, QObject *object) override;
    Q_INVOKABLE bool publish(const QString &channel, const QVariantMap &payload) override;
    Q_INVOKABLE QString subscribe(const QString &channel, const QJSValue &callback);
    Q_INVOKABLE bool unsubscribe(const QString &token);
    Q_INVOKABLE QString createTimer(int milliseconds, bool repeat, const QJSValue &callback);
    Q_INVOKABLE bool cancelTimer(const QString &token);
    Q_INVOKABLE bool ownObject(QObject *object) override;
    // Native optional interface only: never expose observation writes to QML.
    QObject *openObservationSource(const QVariantMap &descriptor, QString *error = nullptr) override;
signals:
    void activeChanged();
    void servicesChanged();
    void errorOccurred(const QString &message);
    void messageReceived(const QString &channel, const QVariantMap &message);
private:
    friend class PluginPackageRuntime;
    PluginContext(PluginPackageRuntime *, QQmlEngine *, QString id, QVariantMap manifest, QVariantMap configuration);
    void dispose();
    bool startNative(ExtensionPackagePlugin *, QString *error);
    void deliver(const QString &, const QVariantMap &);
    void notifyServices();
    bool declares(const QString &group, const QString &direction, const QString &name) const;
    bool owns(QObject *) const;
    void remember(QObject *);
    QQmlContext *qmlContext() const;
    struct Private;
    std::unique_ptr<Private> d;
};
