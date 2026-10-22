#pragma once

#include <QObject>
#include <QVariantMap>
#include <memory>
#include <functional>

class PluginHost;
class PluginPackageRuntime;
class SeasonConfiguration;
class TerminalDataBus;
class TerminalTeamProofVerifier;

// Optional schema3 team plane. Its retirement never clears the independent
// local data bus, terminal gateways or an official connection.
class TerminalTeamHost final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap current READ current NOTIFY changed)
    Q_PROPERTY(QVariantMap providerSelection READ providerSelection NOTIFY changed)
    Q_PROPERTY(QVariantList providerCatalog READ providerCatalog NOTIFY changed)
    Q_PROPERTY(bool editable READ editable NOTIFY changed)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QVariantMap details READ details NOTIFY changed)
    Q_PROPERTY(QVariantMap teamView READ teamView NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
public:
    TerminalTeamHost(PluginHost *host, QString directory, SeasonConfiguration *season,
                     TerminalDataBus *bus, QString file, QObject *parent = nullptr);
    ~TerminalTeamHost() override;
    QVariantMap current() const;
    QVariantMap providerSelection() const;
    QVariantList providerCatalog() const;
    bool editable() const;
    QString lockReason() const;
    QString status() const;
    QVariantMap details() const;
    QVariantMap teamView() const;
    bool active() const;
    using ProofVerifierFactory = std::function<std::unique_ptr<TerminalTeamProofVerifier>(const QVariantMap &, QString *)>;
    // Native composition only: a package cannot nominate its own proof checker
    // or turn an advertised verifier flag into a host trust decision.
    void setProofVerifierFactory(ProofVerifierFactory factory);
    void setPackageRuntime(PluginPackageRuntime *runtime);
    Q_INVOKABLE bool save(const QVariantMap &values);
    Q_INVOKABLE bool saveProvider(const QVariantMap &selection);
    Q_INVOKABLE void refreshProviders();
    Q_INVOKABLE bool setEnabled(bool enabled);
    Q_INVOKABLE void stop();
signals:
    // Only a successful saved team/robot identity change rebuilds package scope.
    // Provider catalog/status notifications must not feed back into setScope().
    void identityChanged();
    void changed();
private:
    void load();
    void loadProvider();
    QVariantMap selectedProvider(bool requireFingerprints = true) const;
    void synchronizeProviders();
    void retire();
    void tick();
    void receive(quint64 generation, const QVariantMap &view);
    bool reject(const QString &reason);
    struct Private;
    std::unique_ptr<Private> d;
};
