#pragma once
#include "ClientPlugin.h"
#include "ExtensionPlugin.h"
#include <QElapsedTimer>
#include <QMap>
#include <QTimer>
#include <memory>
#include <functional>
#include <optional>

class ClientBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(TelemetryEndpoint *telemetry READ telemetry CONSTANT)
    Q_PROPERTY(int clientId READ clientId NOTIFY identityChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectionChanged)
    Q_PROPERTY(bool connecting READ connecting NOTIFY connectionChanged)
    Q_PROPERTY(QString status READ status NOTIFY connectionChanged)
    Q_PROPERTY(QString host READ host NOTIFY connectionOptionsChanged)
    Q_PROPERTY(int port READ port NOTIFY connectionOptionsChanged)
    Q_PROPERTY(bool canChangeTarget READ canChangeTarget NOTIFY connectionOptionsChanged)
    Q_PROPERTY(QVariantMap rulesContext READ rulesContext NOTIFY rulesContextChanged)
    Q_PROPERTY(bool sessionAllowed READ sessionAllowed NOTIFY rulesContextChanged)
    Q_PROPERTY(QString sessionBlockReason READ sessionBlockReason NOTIFY rulesContextChanged)
    Q_PROPERTY(QString commandStatus READ commandStatus NOTIFY commandStatusChanged)
    Q_PROPERTY(QVariantMap commandFeedback READ commandFeedback NOTIFY commandStatusChanged)
    Q_PROPERTY(QVariantList commandHistory READ commandHistory NOTIFY commandStatusChanged)
    Q_PROPERTY(
        QVariantMap receiveDiagnostics READ receiveDiagnostics NOTIFY receiveDiagnosticsChanged)
public:
    explicit ClientBackend(const QString &host, int port, QObject *parent = nullptr);
    ClientBackend(const QString &host, int port, std::unique_ptr<MqttEndpoint> transport,
                  std::unique_ptr<ProtocolEndpoint> protocol, QObject *parent = nullptr);
    ClientBackend(const QString &host, int port, std::unique_ptr<MqttEndpoint> transport,
                  std::unique_ptr<ProtocolEndpoint> protocol,
                  std::unique_ptr<TelemetryEndpoint> telemetry,
                  std::unique_ptr<CommandPolicyEndpoint> policy, QObject *parent = nullptr);
    ~ClientBackend() override;
    TelemetryEndpoint *telemetry() {
        return m_telemetry.get();
    }
    int clientId() const {
        return m_clientId;
    }
    bool connected() const {
        return m_connected;
    }
    bool connecting() const {
        return m_connecting;
    }
    QString status() const {
        return m_status;
    }
    QString host() const { return m_host; }
    int port() const { return m_port; }
    bool canChangeTarget() const;
    QVariantMap rulesContext() const { return m_rulesContext; }
    QString sessionBlockReason() const { return m_sessionGuard ? m_sessionGuard() : QString{}; }
    bool sessionAllowed() const { return sessionBlockReason().isEmpty(); }
    // Host-only: a UI selection never mutates a protocol plugin or grants it
    // compatibility with a new season. Also covers continuous input publishing.
    void setSessionGuard(std::function<QString()> guard) { m_sessionGuard = std::move(guard); }
    void setRulesContext(const QVariantMap &context) {
        if (context == m_rulesContext) return;
        m_rulesContext = context;
        emit rulesContextChanged();
    }
    QString commandStatus() const {
        const auto feedback = commandFeedback();
        if (feedback.isEmpty())
            return {};
        return feedback.value("accepted").toBool()
                   ? "指令已提交：" + feedback.value("topic").toString()
                   : feedback.value("reason").toString();
    }
    QVariantMap commandFeedback() const {
        return m_commandHistory.isEmpty() ? QVariantMap{} : m_commandHistory.first().toMap();
    }
    QVariantList commandHistory() const {
        return m_commandHistory;
    }
    QVariantMap receiveDiagnostics() const;
    Q_INVOKABLE bool login(int robotId);
    Q_INVOKABLE bool loginAt(int robotId, const QString &host, int port);
    Q_INVOKABLE void disconnectFromPlayer();
    Q_INVOKABLE bool sendCommand(const QString &topic, const QVariantMap &fields);
    bool sendInput(const QVariantMap &fields);
    Q_INVOKABLE bool sendInputFields(const QVariantMap &fields);
    // Host-side refusals belong to the same journal as codec/transport failures.
    // Not invokable from QML; this records a refusal and never publishes.
    void rejectOperatorCommand(const QString &topic, const QString &reason);
    // Installed by the host, never writable through QML or model services.
    using OperatorGuard = std::function<bool(const QString &, const QVariantMap &, QString *)>;
    void setOperatorGuard(OperatorGuard guard) { m_operatorGuard = std::move(guard); }
signals:
    // Actual packets, including equal consecutive byte blocks. Display-only
    // stream consumers must not use merged QVariant property change signals.
    void customBytesReceived(const QByteArray &bytes, const QVariantMap &observation);
    void identityChanged();
    void connectionChanged();
    void connectionOptionsChanged();
    void rulesContextChanged();
    void commandStatusChanged();
    void receiveDiagnosticsChanged();
private slots:
    void observePacket(const QString &topic, const QByteArray &bytes,
                       const QVariantMap &observation);
    void markReceiveDiagnosticsDirty() {
        m_receiveDiagnosticsDirty = true;
    }

private:
    bool transmit(const QString &origin, const QString &topic, const QVariantMap &fields,
                  bool report);
    void recordCommandResult(const QString &topic, bool accepted, const QString &reason);
    std::unique_ptr<MqttEndpoint> m_transport;
    std::unique_ptr<ProtocolEndpoint> m_protocol;
    std::unique_ptr<TelemetryEndpoint> m_telemetry;
    std::unique_ptr<CommandPolicyEndpoint> m_policy;
    QString m_host, m_status = "未连接";
    QVariantList m_commandHistory;
    quint64 m_commandSequence = 0;
    int m_port, m_clientId = 0;
    bool m_connected = false, m_connecting = false;
    QElapsedTimer m_clock;
    QTimer m_diagnosticsTimer;
    quint64 m_decodeErrors = 0;
    QString m_lastDecodeError;
    quint64 m_ingressErrors = 0;
    QString m_lastIngressError;
    qint64 m_lastDecodeLog = -1000;
    bool m_receiveDiagnosticsDirty = false;
    QMap<QString, qint64> m_lastSent;
    quint64 m_session = 0;
    quint64 m_targetRevision = 0;
    int m_targetChanges = 0;
    OperatorGuard m_operatorGuard;
    std::function<QString()> m_sessionGuard;
    QVariantMap m_rulesContext;
    struct ObservedPacket {QString topic;QByteArray bytes;QVariantMap stamp;};
    std::optional<ObservedPacket> m_observedPacket;
};
