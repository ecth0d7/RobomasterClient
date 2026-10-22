#pragma once
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <memory>

class PluginHost;
class SeasonConfiguration;
class TerminalDataBus;
class ServiceEndpoint;
class PluginPackageRuntime;
namespace TerminalRendererContract { class Projector; }

// Sensor-independent renderer boundary. QML may enable a renderer, but cannot
// assert that a sensor transform or the official field calibration is verified.
class TerminalSceneHost final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap projection READ projection NOTIFY changed)
    Q_PROPERTY(QVariantMap details READ details NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool editable READ editable NOTIFY changed)
    Q_PROPERTY(QString teamId READ teamId NOTIFY changed)
    Q_PROPERTY(QVariantList providerCatalog READ providerCatalog NOTIFY changed)
    Q_PROPERTY(QVariantMap current READ current NOTIFY changed)
public:
    TerminalSceneHost(PluginHost *, QString directory, SeasonConfiguration *, TerminalDataBus *, QObject *parent = nullptr);
    TerminalSceneHost(PluginHost *, QString directory, SeasonConfiguration *, TerminalDataBus *, QString settingsFile, QObject *parent = nullptr);
    ~TerminalSceneHost() override;
    QVariantMap projection() const;
    QVariantMap details() const;
    QString status() const { return m_status; }
    bool active() const { return bool(m_endpoint) && !m_changing; }
    bool editable() const;
    QString teamId() const { return m_teamId; }
    QVariantList providerCatalog() const;
    QVariantMap current() const { return m_selectedProvider; }
    // Native composition only. A package export supplies a factory, never an
    // authoritative coordinate projection or the provider's existing endpoint.
    void setPackageRuntime(PluginPackageRuntime *);
    Q_INVOKABLE bool selectProvider(const QVariantMap &locator);
    Q_INVOKABLE void refreshProviders();
    Q_INVOKABLE bool selectTeam(const QString &teamId);
    Q_INVOKABLE bool setEnabled(bool);
    Q_INVOKABLE void stop();
    // A real acquisition/calibration adapter supplies this native evidence.
    // No QVariant from a received packet can register its own trusted transform.
    bool setCalibration(const QVariantMap &frame, const QVariantList &sourceTransforms, QString *error = nullptr);
signals:
    void changed();
private:
    QVariantMap context() const;
    void submit();
    void receive(quint64 generation, const QVariantMap &message);
    void retire();
    bool fail(const QString &);
    QVariantMap configurationScope() const;
    QVariantMap selectedCatalogProvider() const;
    void restoreConfiguration();
    bool saveChoice(const QString &team, const QVariantMap &provider);
    void refreshBuiltinAvailability();
    PluginHost *m_plugins;
    QString m_directory, m_status, m_teamId;
    QPointer<SeasonConfiguration> m_season;
    QPointer<TerminalDataBus> m_bus;
    QPointer<PluginPackageRuntime> m_packages;
    std::shared_ptr<ServiceEndpoint> m_endpoint;
    std::unique_ptr<TerminalRendererContract::Projector> m_projector;
    QVariantMap m_frame, m_transforms, m_projection, m_lastScene;
    QTimer m_timer;
    quint64 m_generation = 0, m_revision = 0;
    QString m_activation;
    QString m_settingsFile, m_configurationError;
    QVariantMap m_selectedProvider, m_providerIdentity;
    QVariantList m_savedProfiles;
    bool m_configurationValid = true;
    bool m_builtinAvailable = false;
    bool m_changing = false;
};
