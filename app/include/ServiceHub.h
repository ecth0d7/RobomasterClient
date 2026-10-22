#pragma once
#include "ClientBackend.h"
#include "ServiceEndpoint.h"
#include "TeamViewCache.h"
#include <QTimer>
#include <QElapsedTimer>
#include <QPointer>
class DecisionConfiguration;
class DataSourceHost;
class SeasonConfiguration;

class ServiceHub : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString bridgeStatus READ bridgeStatus NOTIFY serviceStatusChanged)
    Q_PROPERTY(QVariantMap bridgeDetails READ bridgeDetails NOTIFY serviceStatusChanged)
    Q_PROPERTY(QVariantMap peers READ peers NOTIFY peersChanged)
    Q_PROPERTY(QString decisionStatus READ decisionStatus NOTIFY serviceStatusChanged)
    Q_PROPERTY(QVariantMap decisionDetails READ decisionDetails NOTIFY serviceStatusChanged)
    Q_PROPERTY(bool decisionAvailable READ decisionAvailable NOTIFY serviceStatusChanged)
    Q_PROPERTY(QVariantMap advice READ advice NOTIFY adviceChanged)
    Q_PROPERTY(QVariantMap decisionInput READ decisionInput NOTIFY decisionInputChanged)
    Q_PROPERTY(bool decisionInputFresh READ decisionInputFresh NOTIFY decisionInputValidityChanged)
    Q_PROPERTY(QString speechStatus READ speechStatus NOTIFY serviceStatusChanged)
    Q_PROPERTY(QVariantMap speechDetails READ speechDetails NOTIFY serviceStatusChanged)
    Q_PROPERTY(QString localAudioStatus READ localAudioStatus NOTIFY serviceStatusChanged)
    Q_PROPERTY(QObject *pluginRuntime READ pluginRuntime CONSTANT)
    Q_PROPERTY(QObject *operatorActions READ operatorActions CONSTANT)
    Q_PROPERTY(QObject *operatorPreferences READ operatorPreferences CONSTANT)
    Q_PROPERTY(QObject *providerConfiguration READ providerConfiguration CONSTANT)
    Q_PROPERTY(QVariantList decisionModels READ decisionModels NOTIFY serviceStatusChanged)
    Q_PROPERTY(QObject *decisionConfiguration READ decisionConfiguration CONSTANT)
    Q_PROPERTY(QObject *teamConfiguration READ teamConfiguration CONSTANT)
    Q_PROPERTY(QObject *sourceConfiguration READ sourceConfiguration CONSTANT)
    Q_PROPERTY(QObject *seasonConfiguration READ seasonConfiguration CONSTANT)
    Q_PROPERTY(QVariantList terminalGateways READ terminalGateways CONSTANT)
    Q_PROPERTY(QObject *terminalTeam READ terminalTeam CONSTANT)
    Q_PROPERTY(QObject *terminalScene READ terminalScene CONSTANT)
    Q_PROPERTY(QObject *terminalAdvice READ terminalAdvice CONSTANT)
    Q_PROPERTY(QObject *packageRuntime READ packageRuntime CONSTANT)
    Q_PROPERTY(QObject *terminalVoice READ terminalVoice CONSTANT)
    Q_PROPERTY(QObject *terminalSpeech READ terminalSpeech CONSTANT)
    Q_PROPERTY(QObject *terminalBridge READ terminalBridge CONSTANT)
    Q_PROPERTY(QVariantMap localDataView READ localDataView NOTIFY sourceDataChanged)
    Q_PROPERTY(QString aggregationStatus READ aggregationStatus NOTIFY serviceStatusChanged)
    Q_PROPERTY(QVariantMap aggregationDetails READ aggregationDetails NOTIFY serviceStatusChanged)
    Q_PROPERTY(QVariantMap aggregationView READ aggregationView NOTIFY aggregationChanged)
    Q_PROPERTY(QVariantMap teamIdentity READ teamIdentity NOTIFY teamIdentityChanged)
    Q_PROPERTY(QVariantMap teamSharingConfiguration READ teamIdentity NOTIFY teamIdentityChanged)
    Q_PROPERTY(QVariantMap decisionCapabilities READ decisionCapabilities NOTIFY
                   decisionPolicyStatusChanged)
    Q_PROPERTY(QVariantMap decisionTrace READ decisionTrace NOTIFY decisionPolicyStatusChanged)
public:
    explicit ServiceHub(ClientBackend *backend, QObject *parent = nullptr);
    ~ServiceHub() override;
    bool startBridge(std::unique_ptr<ServiceEndpoint> bridge, const QVariantMap &configuration,
                     QString *error, QObject *owner = nullptr,
                     bool exportSnapshots = true, bool exportEvents = true);
    bool ownsBridge(const QObject *owner) const;
    bool releaseBridge(const QObject *owner);
    bool startDecision(std::unique_ptr<ServiceEndpoint> decision, const QVariantMap &configuration,
                       QString *error);
    bool startSpeech(std::unique_ptr<ServiceEndpoint> speech, const QVariantMap &configuration,
                     QString *error, const QString &verifiedPluginId = {}, QObject *owner = nullptr);
    // Native ownership is separate from queue cancellation. A retired host may
    // never stop a service subsequently installed by another native/legacy host.
    bool ownsSpeech(const QObject *owner) const;
    bool releaseSpeech(const QObject *owner);
    bool startAggregation(std::unique_ptr<ServiceEndpoint> aggregation,
                          const QVariantMap &configuration, QString *error);
    void setTeamConfiguration(QObject *configuration);
    QObject *teamConfiguration() const { return m_teamConfiguration.data(); }
    QString aggregationStatus() const;
    QVariantMap aggregationDetails() const;
    QVariantMap aggregationView() const;
    QVariantMap teamIdentity() const;
    QObject *sourceConfiguration() const;
    QVariantMap localDataView() const;
    void setSeasonConfiguration(SeasonConfiguration *configuration);
    QObject *seasonConfiguration() const;
    QString optionalServiceBlockReason(const QString &role, const QString &pluginId) const;
    void addTerminalGateway(const QString &id, const QString &title, QObject *gateway);
    QVariantList terminalGateways() const;
    void setTerminalTeam(QObject *runtime) { m_terminalTeam = runtime; }
    QObject *terminalTeam() const { return m_terminalTeam.data(); }
    void setTerminalScene(QObject *runtime) { m_terminalScene = runtime; }
    QObject *terminalScene() const { return m_terminalScene.data(); }
    void setTerminalAdvice(QObject *runtime) { m_terminalAdvice = runtime; }
    QObject *terminalAdvice() const { return m_terminalAdvice.data(); }
    void setPackageRuntime(QObject *runtime) { m_packageRuntime = runtime; }
    QObject *packageRuntime() const { return m_packageRuntime.data(); }
    void setTerminalVoice(QObject *runtime) { m_terminalVoice = runtime; }
    QObject *terminalVoice() const { return m_terminalVoice.data(); }
    void setTerminalSpeech(QObject *runtime) { m_terminalSpeech = runtime; }
    QObject *terminalSpeech() const { return m_terminalSpeech.data(); }
    void setTerminalBridge(QObject *runtime) { m_terminalBridge = runtime; }
    QObject *terminalBridge() const { return m_terminalBridge.data(); }
    // Native-only speech admission; there is no QML raw speech/TTL authority.
    bool submitTerminalSpeech(const QVariantMap &advice);
    void cancelTerminalSpeech(const QString &requestId);
    // 仅报告启动时未建立的可选端点；不替换已运行服务，也不开放给QML调用。
    void reportOptionalStartupFailure(const QString &role, const QString &error);
    // Host-only lifecycle control; QML uses the scope- and lifecycle-guarded PluginRuntime facade.
    void disableOptionalService(const QString &role);
    void setPluginRuntime(QObject *runtime) {
        m_pluginRuntime = runtime;
    }
    QObject *pluginRuntime() const {
        return m_pluginRuntime.data();
    }
    void setOperatorActions(QObject *actions) {
        m_operatorActions = actions;
    }
    QObject *operatorActions() const {
        return m_operatorActions.data();
    }
    void setOperatorPreferences(QObject *preferences);
    QObject *operatorPreferences() const {
        return m_operatorPreferences.data();
    }
    void setProviderConfiguration(QObject *provider) {
        m_providerConfiguration = provider;
    }
    QObject *providerConfiguration() const {
        return m_providerConfiguration.data();
    }
    QVariantList decisionModels() const {
        auto models = m_providerConfiguration ? m_providerConfiguration->property("models").toList()
                                              : QVariantList{};
        const auto plugin =
            m_providerConfiguration
                ? m_providerConfiguration->property("state").toMap().value("provider_id").toString()
                : QString{};
        const bool builtin = plugin == "decision.http" || plugin == "decision.codex";
        if (!builtin)
            models.clear();
        const auto id =
            builtin && m_providerConfiguration
                ? m_providerConfiguration->property("current").toMap().value("model").toString()
                : QString{};
        bool found = false;
        for (const auto &model : models)
            if (model.toMap().value("id") == id)
                found = true;
        if (!id.isEmpty() && !found)
            models.prepend(QVariantMap{{"id", id},
                                       {"title", id + QStringLiteral(" · 已配置ID，账号未核验")},
                                       {"available", true},
                                       {"source", "configured_id"}});
        const auto active = decisionDetails();
        const auto current = active.value("model").toString();
        found = false;
        for (const auto &model : models)
            if (model.toMap().value("id") == current)
                found = true;
        if (active.value("active").toBool() && !current.isEmpty() && !found)
            models.prepend(QVariantMap{{"id", current},
                                       {"title", current + QStringLiteral(" · 活动插件报告ID")},
                                       {"available", true},
                                       {"source", "active_adapter"}});
        return models;
    }
    void setDecisionConfiguration(DecisionConfiguration *);
    QObject *decisionConfiguration() const;
    QVariantMap decisionCapabilities() const;
    QVariantMap decisionTrace() const;
    QString automaticDecisionStatus() const {
        return m_automaticStatus;
    }
    void setDecisionMinimumInterval(int ms) {
        if (ms >= 500 && ms <= 30000)
            m_decisionMinimumInterval = ms;
    }
    void setLocalAudioPreferences(int voice, int alert);
    QString localAudioStatus() const;
    Q_INVOKABLE bool testAlertTone();
    QString bridgeStatus() const;
    QVariantMap bridgeDetails() const;
    QVariantMap peers() const {
        return m_peers;
    }
    QVariantMap snapshot() const;
    QString decisionStatus() const {
        if (!m_decisionError.isEmpty()) {
            return m_decisionError;
        }
        return m_decision ? m_decision->status() : QStringLiteral("未启用");
    }
    QVariantMap decisionDetails() const {
        return m_decision ? m_decision->details()
                          : optionalFailureDetails(m_decisionError, m_decisionStartupFailed);
    }
    bool decisionAvailable() const;
    QVariantMap advice() const {
        return m_advice;
    }
    QVariantMap decisionInput() const {
        return m_decisionInput;
    }
    bool decisionInputFresh() const;
    Q_INVOKABLE bool requestDecision(const QString &question = {});
    Q_INVOKABLE void cancelDecision();
    QString speechStatus() const {
        if (!m_speechError.isEmpty())
            return m_speechError;
        return m_speech ? m_speech->status() : QStringLiteral("未启用");
    }
    QVariantMap speechDetails() const {
        QPointer<const ServiceHub> alive(this);
        QPointer<ServiceEndpoint> endpoint(m_speech.get());
        const auto generation = m_speechEndpointGeneration;
        auto result = endpoint ? endpoint->details()
                               : optionalFailureDetails(m_speechError, m_speechStartupFailed);
        if (!alive || generation != m_speechEndpointGeneration || (endpoint && m_speech.get() != endpoint.data()))
            return {};
        result.insert("local_volume_applied", m_localAudioApplied);
        return result;
    }
    Q_INVOKABLE bool narrate(const QString &text, const QString &priority, const QString &key);
    Q_INVOKABLE bool speakAdvice();
    Q_INVOKABLE bool speakInputFacts();
    Q_INVOKABLE bool testSpeech();
    Q_INVOKABLE void stopSpeech();
signals:
    void serviceStatusChanged();
    void peersChanged();
    void peerEventReceived(const QString &source, const QVariantMap &payload);
    void adviceChanged();
    void decisionInputChanged();
    void decisionInputValidityChanged();
    void decisionPolicyStatusChanged();
    void aggregationChanged();
    void teamIdentityChanged();
    void sourceDataChanged();

private:
    bool applyLocalAudio();
    static QVariantMap optionalFailureDetails(const QString &error, bool startupFailed) {
        if (error.isEmpty())
            return {};
        return {{"active", false},
                {"busy", false},
                {"health", "unavailable"},
                {"startup_failed", startupFailed},
                {"error", error}};
    }
    void refreshInputValidity();
    void cancelInputSpeech();
    void cancelAdviceSpeech();
    bool decisionEvidenceFresh() const;
    QVariantMap prepareDecisionInput(QString *reason) const;
    bool submitDecision(const QString &question, bool automatic);
    void cancelDecisionRequest();
    void invalidateDecisionPolicy();
    void scheduleDecision();
    void setAutomaticStatus(const QString &);
    QVariantMap message(const QString &kind, const QVariantMap &payload);
    void publishSnapshot();
    bool bridgeBoundaryAllowed() const;
    QString sanitizeBridge(const QString &value) const;
    void receive(const QVariantMap &message);
    void receiveDecision(const QVariantMap &message);
    void receiveAggregation(const QVariantMap &message);
    void publishSourceSnapshot();
    bool submitSpeech(const QString &text, const QString &priority, const QString &key, int ttl);
    QPointer<ClientBackend> m_backend;
    QPointer<TelemetryEndpoint> m_state;
    QPointer<QObject> m_pluginRuntime;
    QPointer<QObject> m_operatorActions;
    QPointer<QObject> m_operatorPreferences;
    QPointer<QObject> m_providerConfiguration;
    QPointer<QObject> m_teamConfiguration;
    QPointer<DecisionConfiguration> m_decisionConfiguration;
    QPointer<SeasonConfiguration> m_seasonConfiguration;
    struct GatewayEntry { QString id, title; QPointer<QObject> gateway; };
    QList<GatewayEntry> m_terminalGateways;
    QPointer<QObject> m_terminalTeam;
    QPointer<QObject> m_terminalScene;
    QPointer<QObject> m_terminalAdvice;
    QPointer<QObject> m_packageRuntime;
    QPointer<QObject> m_terminalVoice;
    QPointer<QObject> m_terminalSpeech;
    QPointer<QObject> m_terminalBridge;
    QPointer<QObject> m_bridgeOwner;
    QMetaObject::Connection m_bridgeOwnerConnection;
    QPointer<QObject> m_speechOwner;
    QMetaObject::Connection m_speechOwnerConnection;
    int m_decisionMinimumInterval = 1000;
    qint64 m_lastDecisionRequest = -30000;
    std::unique_ptr<ServiceEndpoint> m_bridge;
    std::unique_ptr<ServiceEndpoint> m_decision;
    std::unique_ptr<ServiceEndpoint> m_speech;
    std::unique_ptr<ServiceEndpoint> m_aggregation;
    std::unique_ptr<DataSourceHost> m_dataSources;
    TeamViewCache m_teamView;
    QTimer m_timer;
    QElapsedTimer m_clock;
    QString m_source;
    quint64 m_sequence = 0;
    quint64 m_bridgeGeneration = 0, m_decisionGeneration = 0, m_speechGeneration = 0;
    quint64 m_speechEndpointGeneration = 0;
    quint64 m_aggregationGeneration = 0;
    int m_aggregationRobot = 0;
    qint64 m_lastAggregationNotification = 0;
    qint64 m_lastSourceSubmission = -1000;
    quint64 m_sourceSubmissionCount = 0;
    bool m_aggregationCanSend = false, m_sourceWasConnected = false;
    QString m_sourceSubmissionError, m_lastSourceSnapshotId;
    qint64 m_lastPublished = -1000;
    bool m_dirty = true;
    bool m_peersDirty = false;
    bool m_bridgeExportSnapshots = false, m_bridgeExportEvents = false;
    quint64 m_bridgeReceived = 0, m_bridgeRejected = 0;
    qint64 m_bridgeLastReceivedUtc = 0, m_bridgeLastReceivedTick = -1;
    bool m_bridgeDiagnosticsDirty = false;
    QMap<QString, quint64> m_bridgeSequences;
    QString m_bridgeToken;
    QString m_bridgeError;
    QString m_speechError;
    QString m_aggregationError;
    bool m_aggregationStartupFailed = false;
    bool m_bridgeStartupFailed = false, m_decisionStartupFailed = false,
         m_speechStartupFailed = false;
    int m_voiceVolume = 80, m_alertVolume = 50;
    bool m_localAudioApplied = false;
    quint64 m_audioRevision = 0;
    QString m_decisionError, m_decisionRequestId;
    QVariantMap m_advice;
    QVariantMap m_decisionInput;
    qint64 m_decisionStarted = 0, m_adviceExpires = 0;
    qint64 m_inputExpires = 0, m_adviceReceived = 0;
    quint64 m_requestPolicyRevision = 0;
    QVariantMap m_decisionTrace, m_lastAutomaticEvidence;
    QString m_automaticStatus = QStringLiteral("自动建议未启用");
    bool m_autoSuspended = false;
    bool m_inputWasFresh = false, m_inputSpeechOutstanding = false;
    QString m_adviceSpeechKey;
    QVariantMap m_peers;
    QMap<QString, qint64> m_peerSeen;
    QStringList m_peerOrder;
};
