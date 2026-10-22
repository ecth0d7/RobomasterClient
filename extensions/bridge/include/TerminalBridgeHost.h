#pragma once
#include <QObject>
#include <QPointer>
#include <QVariantList>
#include <QVariantMap>

class PluginHost;
class PluginPackageRuntime;
class PluginRuntime;
class SeasonConfiguration;
class ServiceHub;

// Laboratory composition only. The native hub owns the endpoint and export
// permissions; this facade exposes neither token values nor raw submissions.
class TerminalBridgeHost final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap current READ current NOTIFY changed)
    Q_PROPERTY(QVariantList providerCatalog READ providerCatalog NOTIFY changed)
    Q_PROPERTY(bool editable READ editable NOTIFY changed)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QVariantMap details READ details NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
public:
    TerminalBridgeHost(PluginHost *, QString directory, SeasonConfiguration *, ServiceHub *, QString settingsFile, QObject *parent = nullptr);
    ~TerminalBridgeHost() override;
    static QVariantMap defaults();
    static bool validatePublic(const QVariantMap &, QString *error = nullptr);
    QVariantMap current() const { return m_current; }
    QVariantList providerCatalog() const;
    bool editable() const;
    QString lockReason() const;
    QString status() const { return m_status; }
    QVariantMap details() const;
    bool active() const;
    void setPackageRuntime(PluginPackageRuntime *);
    void setLegacyRuntime(PluginRuntime *);
    Q_INVOKABLE bool save(const QVariantMap &);
    Q_INVOKABLE void refreshProviders();
    Q_INVOKABLE bool setEnabled(bool);
    Q_INVOKABLE void stop();
signals:
    void changed();
private:
    QVariantMap scope() const;
    QVariantMap selectedProvider() const;
    void load();
    bool persist(const QVariantMap &);
    void retire();
    void synchronize();
    bool reject(const QString &);
    PluginHost *m_plugins;
    QString m_directory, m_file, m_status, m_configurationError;
    QPointer<SeasonConfiguration> m_season;
    QPointer<ServiceHub> m_services;
    QPointer<PluginPackageRuntime> m_packages;
    QPointer<PluginRuntime> m_legacy;
    QVariantMap m_current, m_providerIdentity;
    quint64 m_generation = 0;
    bool m_builtinAvailable = false, m_configurationValid = true, m_configurationSaved = false, m_changing = false, m_owned = false;
};
