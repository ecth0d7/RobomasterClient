#pragma once

#include <QObject>
#include <QElapsedTimer>
#include <QPointer>
#include <QVariantMap>

class ClientBackend;
class TelemetryEndpoint;

// Operator intents stay separate from telemetry and model recommendations. The host
// must also install allowCommand() inside ClientBackend::sendCommand(), so calling
// the backend directly cannot bypass the same final eligibility check.
class OperatorActions final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap uiCapabilities READ uiCapabilities NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap commonControls READ commonControls NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap dartControl READ dartControl NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap runeActivation READ runeActivation NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap runeContext READ runeContext NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap assemblyContext READ assemblyContext NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap performanceControls READ performanceControls NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap unavailableReasons READ unavailableReasons NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap commandFeedback READ commandFeedback NOTIFY commandFeedbackChanged)
public:
    explicit OperatorActions(ClientBackend *backend, const QVariantMap &configuration = {},
                             QObject *parent = nullptr);

    QVariantMap uiCapabilities() const { return m_capabilities; }
    QVariantMap commonControls() const { return m_common; }
    QVariantMap dartControl() const { return m_dart; }
    QVariantMap runeActivation() const { return m_rune; }
    QVariantMap runeContext() const { return m_runeContext; }
    QVariantMap assemblyContext() const { return m_assembly; }
    QVariantMap performanceControls() const { return m_performance; }
    QVariantMap unavailableReasons() const { return m_reasons; }
    QString status() const { return m_status; }
    QVariantMap commandFeedback() const { return m_feedback; }

    bool allowCommand(const QString &topic, const QVariantMap &fields, QString *error) const;
    Q_INVOKABLE bool sendCommand(const QString &topic, const QVariantMap &fields);
    // Human confirmation of a protocol field absent from TechCoreMotionStateSync.
    // This only supplies the next command's context; it never sends a command or
    // rewrites telemetry, and is labeled operator_confirmation in the UI.
    Q_INVOKABLE bool confirmAssemblyDifficulty(int difficulty);
    // Optional loopback Shark metadata; never grants official remote-server
    // permissions or rewrites the operator's own RobotStaticStatus.
    Q_INVOKABLE bool syncLocalSentrySupport(const QVariantMap &context);

    // Host-only, deliberately not invokable/writable from QML or an AI plugin.
    // Unsupported/undocumented parameter mappings require explicit host evidence.
    bool setConfiguration(const QVariantMap &configuration, QString *error = nullptr);
    static bool validatePreferences(const QVariantMap &configuration, QString *error = nullptr);

signals:
    void stateChanged();
    void commandFeedbackChanged();

private:
    void refresh();
    void feedback(const QString &topic, bool accepted, const QString &reason);
    QVariantMap effectiveAssemblyConfiguration() const;
    QPointer<ClientBackend> m_backend;
    QPointer<TelemetryEndpoint> m_telemetry;
    QElapsedTimer m_clock;
    QVariantMap m_configuration;
    qint64 m_configuredAt = 0;
    quint64 m_generation = 0, m_configurationGeneration = 0;
    QVariantMap m_operatorAssembly;
    qint64 m_operatorAssemblyAt = 0;
    quint64 m_operatorAssemblyGeneration = 0;
    bool m_connectionWasReady = false;
    bool m_assemblyEnded = false;
    quint32 m_assemblyExitRound = 0;
    bool m_refreshing = false;
    QVariantMap m_localSentry;
    quint64 m_localSentryGeneration = 0;
    QVariantMap m_capabilities, m_common, m_dart, m_rune, m_runeContext;
    QVariantMap m_assembly, m_performance, m_reasons, m_feedback;
    QString m_status, m_configurationError;
};
