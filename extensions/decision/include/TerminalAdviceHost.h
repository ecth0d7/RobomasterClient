#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <functional>
#include <memory>

class PluginHost;
class PluginPackageRuntime;
class SeasonConfiguration;
class ServiceEndpoint;
class TerminalDataBus;
class TerminalTeamHost;

// 2027-only native advice boundary. QML can configure consent and request an
// analysis, but cannot submit observations, assert provenance or run commands.
class TerminalAdviceHost final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap current READ current NOTIFY changed)
    Q_PROPERTY(QVariantList strategyCatalog READ strategyCatalog CONSTANT)
    Q_PROPERTY(QVariantList providerCatalog READ providerCatalog NOTIFY changed)
    Q_PROPERTY(bool editable READ editable NOTIFY changed)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QVariantMap details READ details NOTIFY changed)
    Q_PROPERTY(QVariantMap advice READ advice NOTIFY changed)
    Q_PROPERTY(QVariantMap inputTrace READ inputTrace NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
public:
    // Native dependency injection permits source-level memory endpoint tests;
    // this factory is never exposed to QML or read from configuration files.
    using EndpointFactory = std::function<ServiceEndpoint *(const QString &, QString *)>;
    TerminalAdviceHost(PluginHost *, QString directory, SeasonConfiguration *,
                       TerminalDataBus *, TerminalTeamHost *, QString settingsFile,
                       QObject *parent = nullptr, EndpointFactory factory = {});
    ~TerminalAdviceHost() override;
    // Public values contain no enabled-at-boot flag, secret, provenance flag,
    // arbitrary CLI arguments or writable inference-location assertion.
    // provider_options has the exact providerDefaults(kind) shape. Grants are
    // per semantic robot/source/item; localAi does not authorize cloud/unknown
    // providers. Strategy text is an operator preference, never telemetry.
    // hud_enabled / hud_position / hud_density are presentation preferences in
    // this same preparation-only scope; they never authorize a model request.
    static QVariantMap defaults();
    static QVariantMap providerDefaults(const QString &kind);
    static bool validatePublic(const QVariantMap &, QString *error = nullptr);
    QVariantMap current() const;
    QVariantList strategyCatalog() const;
    QVariantList providerCatalog() const;
    bool editable() const;
    QString lockReason() const;
    QString status() const;
    QVariantMap details() const;
    QVariantMap advice() const;
    QVariantMap inputTrace() const;
    bool active() const;
    void setPackageRuntime(PluginPackageRuntime *);
    Q_INVOKABLE void refreshProviders();
    Q_INVOKABLE bool save(const QVariantMap &values);
    Q_INVOKABLE bool setEnabled(bool enabled);
    Q_INVOKABLE bool request(const QString &question = {});
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void stop();
signals:
    void changed();
    // Only admitted, still-fresh advice can reach this optional speech hook.
    // Its consumer must recheck lifetime and its own voice/recipient policy.
    void voiceRequested(const QVariantMap &validatedAdvice);
    void voiceCancelled(const QString &requestId);
private:
    void load();
    void tick();
    void receive(quint64 generation, const QVariantMap &message);
    bool dispatch(const QString &question, bool automatic);
    QVariantMap capture(QString *error) const;
    bool evidenceCurrent() const;
    void retire(const QString &reason, bool disable);
    bool reject(const QString &reason);
    QVariantMap packageProvider(const QVariantMap &options, bool requireFingerprints) const;
    void synchronizeProviders();
    struct Private;
    std::unique_ptr<Private> d;
};
