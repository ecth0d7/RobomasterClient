#pragma once
#include <QObject>
#include <QPointer>
#include <QVariantMap>
#include <QVariantList>
#include <QMap>
#include <functional>

class PluginHost;
class ServiceHub;
class ClientBackend;

// Native plugin factories are discovered by metadata. Only explicitly configured
// optional services may start; core endpoints retain their startup-only lifetime.
class PluginRuntime final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList modules READ modules NOTIFY changed)
    Q_PROPERTY(bool editable READ editable NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
public:
    PluginRuntime(PluginHost *host, ServiceHub *services, ClientBackend *backend, QString directory,
                  QVariantMap coreSelection, QObject *parent = nullptr);
    void configureOptional(const QString &role, const QString &id, const QVariantMap &configuration,
                           bool enabled, const QString &configurationError = {});
    void startConfigured();
    // Host-only provider configuration. Secrets stay in memory, outside QML.
    bool replaceOptional(const QString &role, const QString &id, const QVariantMap &configuration,
                         bool enabled, QString *error);
    void retireOptional(const QString &role);
    QString selectedPlugin(const QString &role) const {
        return m_profiles.value(role).id;
    }
    void setPreparationGuard(std::function<bool()> guard) {
        m_preparationGuard = std::move(guard);
    }
    // Host-only activation leases (e.g. a fresh team epoch). The plugin manager
    // cannot bypass the owner's scope/identity policy by toggling a cached ID.
    void setOptionalActivationGuard(const QString &role,
        std::function<bool(const QVariantMap &, QString *)> guard) {
        m_activationGuards[role] = std::move(guard);
    }
    QVariantList modules() const;
    bool editable() const;
    QString status() const {
        return m_status;
    }
    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool setEnabled(const QString &role, bool enabled);
    Q_INVOKABLE bool selectPlugin(const QString &role, const QString &id);
    Q_INVOKABLE bool configureSpeech(const QString &id, const QVariantMap &configuration);
signals:
    void changed();

private:
    struct Profile {
        QString id;
        QVariantMap configuration;
        bool requested = false;
        bool enabled = false;
        QString configurationError;
        QString failure;
    };
    bool apply(const QString &role, bool enabled);
    bool beginEdit();
    PluginHost *m_host;
    QPointer<ServiceHub> m_services;
    QPointer<ClientBackend> m_backend;
    QString m_directory;
    QVariantMap m_coreSelection;
    QVariantList m_catalog;
    QMap<QString, Profile> m_profiles;
    QMap<QString, quint64> m_revisions;
    QString m_status;
    bool m_changing = false;
    std::function<bool()> m_preparationGuard;
    QMap<QString, std::function<bool(const QVariantMap &, QString *)>> m_activationGuards;
};
