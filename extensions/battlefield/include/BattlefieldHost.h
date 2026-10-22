#pragma once
#include <QObject>
#include <QByteArray>
#include <QImage>
#include <QPointer>
#include <QTimer>
#include <QVariantMap>
#include <memory>

class PluginHost;
class ServiceEndpoint;
class ClientBackend;
class VideoController;
class VideoEndpoint;

// Optional read-only acquisition: no reference to a robot command/publish API.
class BattlefieldHost final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap view READ view NOTIFY changed)
    Q_PROPERTY(QVariantMap diagnostics READ diagnostics NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool visionEnabled READ visionEnabled NOTIFY changed)
    Q_PROPERTY(bool projectileEnabled READ projectileEnabled NOTIFY changed)
    Q_PROPERTY(QString configurationFile READ configurationFile NOTIFY changed)
public:
    BattlefieldHost(PluginHost *, QString pluginDirectory, ClientBackend *, VideoController *, QObject *parent = nullptr);
    ~BattlefieldHost() override;
    QVariantMap view() const { return m_view; }
    QVariantMap diagnostics() const;
    QString status() const { return m_status; }
    bool active() const;
    bool visionEnabled() const { return active() && m_visionEnabled; }
    bool projectileEnabled() const { return active() && m_projectileEnabled; }
    Q_INVOKABLE QVariantMap projectionConfiguration(const QString &file) const;
    Q_INVOKABLE bool saveProjectionConfiguration(const QString &file, const QVariantMap &values, const QString &modelFile);
    Q_INVOKABLE QVariantMap identityConfiguration(const QString &file) const;
    Q_INVOKABLE bool saveIdentityConfiguration(const QString &file, const QVariantMap &values, const QString &modelFile);
    Q_INVOKABLE QVariantMap filterConfiguration(const QString &file) const;
    Q_INVOKABLE bool saveFilterConfiguration(const QString &file, const QVariantMap &values);
    Q_INVOKABLE bool startModules(const QString &file, bool vision, bool projectile, bool share, const QString &modelFile);
    void attachHeroVideo(VideoEndpoint *);
    QString configurationFile() const { return m_configurationFile; }
    Q_INVOKABLE bool start(const QString &configurationFile);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void disable();
    Q_INVOKABLE bool setJournalEnabled(bool enabled);
    Q_INVOKABLE bool addTacticalMark(const QString &text, const QString &intent, const QVariantList &position, bool share);
    Q_INVOKABLE bool analyze(const QString &question = {});
    Q_INVOKABLE bool announce(const QString &targetId, const QString &peerNode = {});
    Q_INVOKABLE void speakAdvice();
    Q_INVOKABLE void mute(bool muted);
    Q_INVOKABLE void cancelVoice();
signals:
    void changed();
private:
    bool saveVisionSection(const QString &file, const QString &section, const QVariantMap &values, const QString &modelFile);
    bool submit(const QVariantMap &);
    void capture(const QImage &);
    void captureHero(const QImage &);
private slots:
    void resetHero();
private:
    void snapshot();
    QVariantMap observerAt(qint64 now) const;
    PluginHost *m_plugins;
    QString m_directory, m_status = QStringLiteral("态势插件未启用"), m_configurationFile;
    QPointer<ClientBackend> m_backend;
    QPointer<VideoController> m_video;
    QPointer<VideoEndpoint> m_heroVideo;
    std::unique_ptr<ServiceEndpoint> m_endpoint;
    QVariantMap m_view;
    QTimer m_timer;
    qint64 m_lastFrame = 0, m_lastHeroFrame = 0;
    bool m_projectileEnabled = false;
    bool m_visionEnabled = false;
    quint64 m_generation = 0;
    bool m_overrideModules=false, m_requestedVision=false, m_requestedProjectile=false, m_requestedShare=false;
    QString m_requestedModel;
    QByteArray m_configurationBaseline;
};
