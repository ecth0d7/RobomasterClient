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

// Preparation-only provider selection. Utterance admission and ownership stay
// in ServiceHub; this object deliberately exposes no raw speak/submit ingress.
class TerminalSpeechHost final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap current READ current NOTIFY changed)
    Q_PROPERTY(QVariantList providerCatalog READ providerCatalog NOTIFY changed)
    Q_PROPERTY(bool editable READ editable NOTIFY changed)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QVariantMap details READ details NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
public:
    TerminalSpeechHost(PluginHost *, QString directory, SeasonConfiguration *, ServiceHub *,
                       QString settingsFile, QObject *parent = nullptr);
    ~TerminalSpeechHost() override;
    static QVariantMap defaults();
    static QVariantMap providerDefaults(const QString &kind);
    static bool validatePublic(const QVariantMap &, QString *error = nullptr);
    QVariantMap current() const { return m_current; }
    QVariantList providerCatalog() const;
    bool editable() const;
    QString lockReason() const;
    QString status() const { return m_status; }
    QVariantMap details() const;
    bool active() const;
    void setPackageRuntime(PluginPackageRuntime *);
    void setLegacyRuntime(PluginRuntime *runtime);
    Q_INVOKABLE bool save(const QVariantMap &values);
    Q_INVOKABLE void refreshProviders();
    Q_INVOKABLE bool setEnabled(bool enabled);
    Q_INVOKABLE bool testOutput();
    Q_INVOKABLE void stop();
signals:
    void changed();
private:
    QVariantMap scope() const;
    QVariantMap selectedProvider(bool requireFingerprints = true) const;
    void load();
    bool persist(const QVariantMap &values);
    void retire();
    void synchronize();
    bool reject(const QString &reason);
    PluginHost *m_plugins;
    QString m_directory, m_file, m_status, m_configurationError;
    QPointer<SeasonConfiguration> m_season;
    QPointer<ServiceHub> m_services;
    QPointer<PluginPackageRuntime> m_packages;
    QPointer<PluginRuntime> m_legacy;
    QVariantMap m_current, m_providerIdentity;
    QVariantList m_builtinCatalog;
    quint64 m_generation = 0;
    bool m_configurationValid = true, m_configurationSaved = false, m_changing = false, m_owned = false;
};
