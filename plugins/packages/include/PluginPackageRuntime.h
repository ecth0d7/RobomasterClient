#pragma once

#include <QObject>
#include <QVariantMap>
#include <memory>
#include <functional>

class QQmlEngine;
class PluginContext;
class ServiceEndpoint;

// Local, explicit QML package composition. Native foundations are registered
// separately and are never entries that package enable/remove can target.
class PluginPackageRuntime final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList packages READ packages NOTIFY changed)
    Q_PROPERTY(QVariantList availablePanels READ availablePanels NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(bool editable READ editable NOTIFY changed)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY changed)
    Q_PROPERTY(QVariantMap scope READ scope NOTIFY changed)
    Q_PROPERTY(QString configFile READ configFile CONSTANT)
public:
    PluginPackageRuntime(QQmlEngine *engine, QString packagesDirectory, QString configurationFile,
                         QObject *parent = nullptr);
    ~PluginPackageRuntime() override;
    QVariantList packages() const;
    QVariantList availablePanels() const;
    QString status() const;
    bool editable() const;
    QString lockReason() const;
    QVariantMap scope() const;
    QString configFile() const;
    // These are native composition/policy APIs, deliberately not QML invokables.
    bool registerService(const QString &name, QObject *object);
    bool unregisterService(const QString &name);
    QVariantList serviceProviders(const QString &role, const QString &contract) const;
    ServiceEndpoint *createProviderService(const QString &packageId, const QString &serviceName,
        const QString &role, const QString &contract, QString *error, QVariantMap *identity = nullptr);
    bool setScope(const QVariantMap &scope);
    void retireAll(const QString &reason = {});
    void setConfigurationLocked(bool locked, const QString &reason = {});
    using ObservationSourceFactory = std::function<QObject *(QObject *, const QVariantMap &,
        const QVariantMap &, const QVariantMap &, QString *)>;
    // Compose before any packages activate. The callback receives host-stamped
    // package metadata/configuration and native scope, never producer identity.
    bool setObservationSourceFactory(ObservationSourceFactory factory);
    bool publishFoundation(const QString &channel, const QVariantMap &payload);
    Q_INVOKABLE bool rescan();
    Q_INVOKABLE bool installDirectory(const QString &directory);
    Q_INVOKABLE bool uninstall(const QString &id);
    Q_INVOKABLE bool saveConfiguration(const QString &id, const QVariantMap &values);
    Q_INVOKABLE bool setEnabled(const QString &id, bool enabled);
    Q_INVOKABLE QObject *createPanel(const QString &id, const QString &panelId, QObject *owner = nullptr);
    // A Loader retires its item with deleteLater(). Release the exact owner's
    // panel lease first so a close/reopen never waits on DeferredDelete order.
    Q_INVOKABLE bool releasePanel(const QString &id, const QString &panelId, QObject *owner);
    Q_INVOKABLE QObject *contextFor(const QString &id) const;
signals:
    void changed();
private:
    friend class PluginContext;
    QObject *resolve(PluginContext *, const QString &) const;
    QObject *createObservationSource(PluginContext *, const QVariantMap &, QString *);
    bool provide(PluginContext *, const QString &, QObject *);
    bool publish(PluginContext *, const QString &, const QVariantMap &);
    void release(PluginContext *);
    void revokeProvider(quint64 token, const QString &reason);
    void retirePackage(const QString &id);
    void invalidateDependencies();
    void schedule();
    void reconcile();
    void drainMessages();
    bool reject(const QString &);
    struct Private;
    std::unique_ptr<Private> d;
};
