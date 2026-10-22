#pragma once

#include <QObject>
#include <QVariantMap>
#include <memory>

// Native-only normalized local observations. No sockets, official wire schema,
// AI invocation, robot commands, or writable QML injection entrypoints.
class TerminalDataBus final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap view READ view NOTIFY changed)
    Q_PROPERTY(QVariantMap diagnostics READ diagnostics NOTIFY changed)
public:
    explicit TerminalDataBus(QObject *parent = nullptr);
    ~TerminalDataBus() override;
    QVariantMap view() const;
    QVariantMap diagnostics() const;

    void setRulesContext(const QVariantMap &context);
    bool acceptLocal(const QVariantMap &observation, QString *error = nullptr);
    bool seedMock(QString *error = nullptr);
    void clear();
    static bool validateObservation(const QVariantMap &observation, const QVariantMap &context,
                                    bool allowMock, QString *error = nullptr);
signals:
    void changed();
private:
    friend class TerminalGateway;
    friend class TerminalPluginSourceHost;
    // Host-owned adapter provenance cannot arrive inside a producer payload.
    bool acceptTransportObservation(const QVariantMap &observation, const QVariantMap &provenance,
                                    bool allowMock, QString *error);
    void retireTransport(const QString &activationId);
    bool registerPluginSource(const QVariantMap &binding, QString *error);
    bool acceptPluginObservation(const QVariantMap &observation, const QVariantMap &provenance,
                                 bool allowMock, QString *error);
    void retirePluginSource(const QString &activationId);
    bool reject(const QString &reason, QString *error);
    void updateAges();
    void scheduleExpiry();
    struct Private;
    std::unique_ptr<Private> d;
};
