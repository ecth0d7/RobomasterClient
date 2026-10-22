#pragma once
#include <QObject>
#include <QPointer>
#include <QVariantMap>
#include <memory>

class PluginHost;
class PluginPackageRuntime;
class ProtocolEndpoint;
class SeasonConfiguration;
class ServiceEndpoint;
class TerminalDataBus;

// An independently owned optional plane. The PluginHost must outlive it.
class TerminalGateway final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap configuration READ configuration NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QVariantMap details READ details NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool editable READ editable NOTIFY changed)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY changed)
    Q_PROPERTY(QVariantList modules READ modules NOTIFY changed)
    Q_PROPERTY(QVariantList receivedPackets READ receivedPackets NOTIFY changed)
    Q_PROPERTY(QObject *terminalBus READ terminalBus CONSTANT)
public:
    TerminalGateway(PluginHost *host, QString directory, SeasonConfiguration *season,
                    TerminalDataBus *bus, QObject *parent = nullptr);
    TerminalGateway(PluginHost *host, QString directory, SeasonConfiguration *season,
                    TerminalDataBus *bus, QString settingsFile, QObject *parent = nullptr);
    ~TerminalGateway() override;
    QVariantMap configuration() const;
    QString status() const;
    QVariantMap details() const;
    bool active() const;
    bool editable() const { return guardReason().isEmpty(); }
    QString lockReason() const { return guardReason(); }
    QVariantList modules() const;
    QVariantList receivedPackets() const;
    QObject *terminalBus() const;
    void setPackageRuntime(PluginPackageRuntime *runtime);
    Q_INVOKABLE bool configure(const QString &pluginId, const QVariantMap &publicConfiguration);
    Q_INVOKABLE bool setEnabled(bool enabled);
    Q_INVOKABLE bool sendMock();
    // Explicit manual training send. This facade accepts bounded hex only and
    // keeps the lower-level QByteArray / observation APIs native-only.
    Q_INVOKABLE bool sendTrainingHex(const QString &channel, const QString &hex, bool confirmed);
    Q_INVOKABLE void refreshModules();
    Q_INVOKABLE void stop();
    bool sendBytes(const QString &channel, const QByteArray &payload, const QString &requestId,
                   QString *error = nullptr);
    bool sendObservation(const QVariantMap &observation, const QString &requestId, QString *error = nullptr);
    bool setProtocolBinding(std::unique_ptr<ProtocolEndpoint> binding, const QString &bindingId,
                            QString *error = nullptr);
signals:
    void changed();
private:
    QString guardReason() const;
    bool reject(const QString &reason, QString *error = nullptr);
    void receive(quint64 generation, const QVariantMap &message);
    void retire(bool clearJournal);
    void loadConfiguration();
    bool saveConfiguration(const QString &pluginId, const QVariantMap &options);
    QVariantMap selectedPackage(bool requireFingerprints = true) const;
    void synchronizeProviders();
    struct Private;
    std::unique_ptr<Private> d;
};
