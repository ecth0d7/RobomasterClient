#pragma once
#include <QString>
#include <QCoreApplication>
#include <QStringList>
#include <QVariantMap>
#include <optional>

struct AppConfig {
    QString mqttHost = "127.0.0.1"; // Local draft only, not a 2027 server address.
    int mqttPort = 3333;
    QString videoBind = "0.0.0.0";
    int videoPort = 3334;
    QString videoCodec = "hevc";
    QString renderer = "auto";
    QString pluginDirectory;
    QString packageDirectory;
    QString packageConfigurationFile;
    QString uiDirectory;
    QString uiView = "player-2026";
    QString uiPreferencesFile;
    QString mqttPlugin = "mqtt.mosquitto";
    QString protocolPlugin = "protocol.rm2026.v2";
    QString videoPlugin = "video.ffmpeg";
    QString statePlugin = "state.telemetry";
    QString inputPlugin = "input.qt";
    QString policyPlugin = "policy.operator";
    QString bridgePlugin = "bridge.tcp";
    bool laboratoryBridge = false;
    QString bridgeBind = "127.0.0.1";
    int bridgePort = 8888;
    QString bridgePeer;
    QString bridgeTokenEnvironment = "ROBOMASTER_BRIDGE_TOKEN";
    bool decisionEnabled = false;
    QString decisionPlugin = "decision.http";
    QString decisionApi = "responses";
    QString decisionEndpoint = "https://api.openai.com/v1/responses";
    QString decisionModel;
    QString decisionSchemaProfile = "basic";
    QString decisionKeyEnvironment = "OPENAI_API_KEY";
    int decisionTimeout = 15000;
    std::optional<double> decisionTemperature;
    bool speechEnabled = false, speechPlayback = false;
    QString speechPlugin = "speech.espeak", speechExecutable, speechPlayer, speechVoice = "cmn";
    QString speechEndpoint = "http://127.0.0.1:5002/synthesize", speechModel;
    bool listPlugins = false;
    bool autoLogin = false;
    int robotId = 3;
    QString profileFile;
    QVariantMap pluginConfigurations;
    std::optional<QVariantMap> configuration(const QString &role, const QVariantMap &defaults,
                                             QString *error) const;
    static bool metadataOnlyRequested(const QStringList &arguments);
    static std::optional<AppConfig> parse(const QStringList &arguments, QString *error);
    static std::optional<AppConfig> fromArguments(QCoreApplication &app, QString *error);
};
