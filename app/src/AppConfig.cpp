#include "AppConfig.h"
#include <QCommandLineParser>
#include <QHostAddress>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSet>
#include <QStandardPaths>
#include <QRegularExpression>
#include <cmath>

namespace {
QList<QCommandLineOption> clientOptions() {
    return {{"profile", "Load a bounded JSON startup profile; explicit CLI values take precedence",
             "file"},
            {"host", "MQTT server address (local SharkDataSever by default)", "host", "127.0.0.1"},
            {"mqtt-port", "MQTT server port", "port", "3333"},
            {"video-bind", "UDP listening address", "address", "0.0.0.0"},
            {"video-port", "UDP listening port", "port", "3334"},
            {"video-codec", "Video codec: hevc, h264 or auto (Annex-B parameter sets)", "codec", "hevc"},
            {"renderer", "Qt Quick renderer: auto (OpenGL check/fallback), software or opengl",
             "mode", "auto"},
            {"plugin-dir", "Directory containing selected native plugins", "directory"},
            {"package-dir", "Local QML extension-package directory; new packages require explicit enable", "directory"},
            {"package-config", "Persistent QML plugin settings and reviewed enable choices", "file"},
            {"ui-dir", "Replace the external QML pack directory", "directory"},
            {"ui-view", "Select a named operator or reference view from the UI pack", "id", "player-2026"},
            {"ui-preferences", "Instance-local bounded UI preferences JSON file", "file"},
            {"mqtt-plugin", "MQTT plugin id", "id", "mqtt.mosquitto"},
            {"protocol-plugin", "Protocol adapter id; 2026 wire interface", "id", "protocol.rm2026.v2"},
            {"video-plugin", "Video plugin id", "id", "video.ffmpeg"},
            {"state-plugin", "Telemetry state plugin id", "id", "state.telemetry"},
            {"input-plugin", "Window input plugin id", "id", "input.qt"},
            {"policy-plugin", "Command policy plugin id", "id", "policy.operator"},
            {"lab-bridge", "Enable laboratory bridge; 2027 match deployment forbids outside-room communication"},
            {"no-lab-bridge", "Disable a profile's laboratory bridge"},
            {"bridge-plugin", "Laboratory bridge plugin id", "id", "bridge.tcp"},
            {"bridge-bind", "Laboratory TCP listening address", "address", "127.0.0.1"},
            {"bridge-port", "Laboratory TCP listening port (0 chooses an available port)", "port",
             "8888"},
            {"bridge-peer", "Laboratory upstream peer tcp://host:port", "url"},
            {"bridge-token-env", "Environment variable containing shared bridge token", "name",
             "ROBOMASTER_BRIDGE_TOKEN"},
            {"decision", "Enable optional model advice service"},
            {"no-decision", "Disable a profile's model advice service"},
            {"decision-plugin", "Model advice plugin id", "id", "decision.http"},
            {"decision-api", "Model wire API: responses or chat", "name", "responses"},
            {"decision-endpoint", "Full model inference endpoint", "url",
             "https://api.openai.com/v1/responses"},
            {"decision-model", "Configured model id or local server alias", "id"},
            {"decision-schema-profile",
             "Output schema: basic or concise (requires string length support)", "name", "basic"},
            {"decision-key-env", "Environment variable containing model API key", "name",
             "OPENAI_API_KEY"},
            {"decision-timeout-ms", "Total model request timeout", "milliseconds", "15000"},
            {"decision-temperature", "Optional provider-supported sampling temperature (0..2)",
             "number"},
            {"speech", "Enable optional local speech synthesis"},
            {"no-speech", "Disable a profile's speech service and playback"},
            {"no-speech-play", "Disable a profile's audio-device playback"},
            {"speech-play",
             "Play synthesized speech through the system audio device (requires --speech)"},
            {"speech-plugin", "Speech service plugin id", "id", "speech.espeak"},
            {"speech-executable", "Path to espeak-ng (otherwise search PATH)", "file"},
            {"speech-player", "Path to aplay (otherwise search PATH)", "file"},
            {"speech-voice", "Speech voice id", "id", "cmn"},
            {"speech-endpoint", "Local Piper HTTP synthesis endpoint", "url",
             "http://127.0.0.1:5002/synthesize"},
            {"speech-model", "Optional Piper server voice id (otherwise server default)", "id"},
            {"auto-login", "Automatically connect to MQTT server on startup"},
            {"robot", "Robot ID for auto-login (e.g. 1-9 for red, 101-109 for blue)", "id", "3"},
            {"list-plugins", "List plugin metadata and exit without opening connections"}};
}
void configureParser(QCommandLineParser &parser) {
    parser.setSingleDashWordOptionMode(QCommandLineParser::ParseAsLongOptions);
    parser.setApplicationDescription("RoboMaster 2026 player / MQTT / UDP client");
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addOptions(clientOptions());
}
bool boundedConfiguration(const QJsonValue &value, int depth = 0) {
    if (depth > 4)
        return false;
    if (value.isString())
        return value.toString().size() <= 1024;
    if (value.isDouble())
        return std::isfinite(value.toDouble());
    if (value.isArray()) {
        const auto array = value.toArray();
        if (array.size() > 64)
            return false;
        for (const auto &entry : array)
            if (!boundedConfiguration(entry, depth + 1))
                return false;
    } else if (value.isObject()) {
        const auto object = value.toObject();
        if (object.size() > 64)
            return false;
        for (auto it = object.begin(); it != object.end(); ++it)
            if (it.key().size() > 64 || !boundedConfiguration(it.value(), depth + 1))
                return false;
    }
    return true;
}
bool loadProfile(const QString &file, QStringList *arguments, QVariantMap *plugins,
                 QString *error) {
    const auto reject = [&](const QString &reason) {
        if (error)
            *error = reason;
        return false;
    };
    QFile input(file);
    if (!input.open(QIODevice::ReadOnly))
        return reject("Cannot open startup profile");
    const auto bytes = input.read(65537);
    if (bytes.size() > 65536)
        return reject("Startup profile exceeds 64 KiB");
    QJsonParseError parseError;
    const auto document = QJsonDocument::fromJson(bytes, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return reject("Invalid startup profile JSON");
    const auto root = document.object();
    if (!root.value("schema").isDouble() || root.value("schema").toDouble() != 1)
        return reject("Unsupported startup profile schema");
    for (auto it = root.begin(); it != root.end(); ++it)
        if (it.key() != "schema" && it.key() != "options" && it.key() != "plugins")
            return reject("Unknown startup profile field");
    if ((root.contains("options") && !root.value("options").isObject()) ||
        (root.contains("plugins") && !root.value("plugins").isObject()))
        return reject("Profile options/plugins must be objects");
    QMap<QString, QCommandLineOption> definitions;
    for (const auto &option : clientOptions())
        definitions.insert(option.names().first(), option);
    const auto options = root.value("options").toObject();
    const auto base = QFileInfo(file).absoluteDir();
    for (auto it = options.begin(); it != options.end(); ++it) {
        if (!definitions.contains(it.key()) || it.key() == "profile" ||
            it.key() == "list-plugins" || it.key().startsWith("no-"))
            return reject("Unknown or non-configuration option in startup profile");
        const auto definition = definitions.constFind(it.key()).value();
        if (definition.valueName().isEmpty()) {
            if (!it.value().isBool())
                return reject("Profile flags must be boolean");
            if (it.value().toBool())
                arguments->append("--" + it.key());
        } else {
            if (!it.value().isString() && !it.value().isDouble())
                return reject("Profile option values must be strings or numbers");
            QString value = it.value().isString() ? it.value().toString()
                                                  : QString::number(it.value().toDouble(), 'g', 17);
            if (value.size() > 2048)
                return reject("Profile option value is too long");
            if ((definition.valueName() == "directory" ||
                 (definition.valueName() == "file" && value.contains('/'))) &&
                !value.isEmpty() && QDir::isRelativePath(value))
                value = base.filePath(value);
            arguments->append("--" + it.key() + "=" + value);
        }
    }
    const QSet<QString> roles{"state", "input", "policy", "video", "bridge", "decision", "speech"};
    const auto configurations = root.value("plugins").toObject();
    for (auto it = configurations.begin(); it != configurations.end(); ++it) {
        if (!roles.contains(it.key()) || !it.value().isObject() ||
            !boundedConfiguration(it.value()))
            return reject("Invalid or unsupported plugin configuration role");
    }
    *plugins = configurations.toVariantMap();
    return true;
}
}

bool AppConfig::metadataOnlyRequested(const QStringList &arguments) {
    QCommandLineParser parser;
    configureParser(parser);
    parser.parse(arguments);
    return parser.isSet("help") || parser.isSet("help-all") || parser.isSet("version") ||
           parser.isSet("list-plugins");
}

std::optional<AppConfig> AppConfig::fromArguments(QCoreApplication &app, QString *error) {
    QCommandLineParser parser;
    configureParser(parser);
    parser.process(app);
    return parse(app.arguments(), error);
}
std::optional<AppConfig> AppConfig::parse(const QStringList &arguments, QString *error) {
    if (error)
        error->clear();
    QCommandLineParser parser;
    configureParser(parser);
    if (!parser.parse(arguments)) {
        if (error)
            *error = parser.errorText();
        return {};
    }
    AppConfig result;
    result.profileFile = parser.value("profile");
    if (!result.profileFile.isEmpty()) {
        QStringList merged{arguments.value(0)};
        if (!loadProfile(result.profileFile, &merged, &result.pluginConfigurations, error))
            return {};
        merged.append(arguments.mid(1));
        if (!parser.parse(merged)) {
            if (error)
                *error = parser.errorText();
            return {};
        }
    }
    result.mqttHost = parser.value("host").trimmed();
    result.videoBind = parser.value("video-bind");
    result.videoCodec = parser.value("video-codec").toLower();
    result.renderer = parser.value("renderer").toLower();
    if (result.renderer != "auto" && result.renderer != "software" &&
        result.renderer != "opengl") {
        if (error)
            *error = "Invalid renderer; choose auto, software or opengl.";
        return {};
    }
    result.pluginDirectory = parser.value("plugin-dir");
    if (result.pluginDirectory.isEmpty()) {
        const QDir binary(QCoreApplication::applicationDirPath());
        result.pluginDirectory = binary.filePath("plugins");
        if (!QDir(result.pluginDirectory).exists())
            result.pluginDirectory = binary.filePath("../lib/robomaster/plugins");
    }
    result.mqttPlugin = parser.value("mqtt-plugin");
    result.packageDirectory = parser.value("package-dir");
    if (result.packageDirectory.isEmpty())
        result.packageDirectory = QDir(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)).filePath("packages");
    else if (QFileInfo(result.packageDirectory).isRelative() && !result.profileFile.isEmpty())
        result.packageDirectory = QFileInfo(result.profileFile).dir().absoluteFilePath(result.packageDirectory);
    result.uiDirectory = parser.value("ui-dir");
    result.uiView = parser.value("ui-view");
    static const QRegularExpression viewIdentifier(QStringLiteral("^[a-z][a-z0-9]*(?:[.-][a-z0-9]+)*$"));
    if (result.uiView.isEmpty() || result.uiView.size() > 64 ||
        !viewIdentifier.match(result.uiView).hasMatch()) {
        if (error)
            *error = "Invalid UI view identifier";
        return {};
    }
    result.uiPreferencesFile = parser.value("ui-preferences");
    if (result.uiPreferencesFile.isEmpty()) {
        result.uiPreferencesFile = result.profileFile.isEmpty()
            ? QDir(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)).filePath("local-ui.json")
            : QFileInfo(result.profileFile).absoluteFilePath() + ".ui.json";
    } else if (QFileInfo(result.uiPreferencesFile).isRelative() && !result.profileFile.isEmpty()) {
        result.uiPreferencesFile = QFileInfo(result.profileFile).dir().absoluteFilePath(result.uiPreferencesFile);
    }
    result.packageConfigurationFile = parser.value("package-config");
    if (result.packageConfigurationFile.isEmpty())
        result.packageConfigurationFile = result.uiPreferencesFile + ".packages.json";
    else if (QFileInfo(result.packageConfigurationFile).isRelative() && !result.profileFile.isEmpty())
        result.packageConfigurationFile = QFileInfo(result.profileFile).dir().absoluteFilePath(result.packageConfigurationFile);
    if (result.uiDirectory.isEmpty()) {
        const QDir binary(QCoreApplication::applicationDirPath());
        result.uiDirectory = binary.filePath("qml");
        if (!QDir(result.uiDirectory).exists())
            result.uiDirectory = binary.filePath("../share/robomaster/qml");
    }
    result.protocolPlugin = parser.value("protocol-plugin");
    result.videoPlugin = parser.value("video-plugin");
    result.statePlugin = parser.value("state-plugin");
    result.inputPlugin = parser.value("input-plugin");
    result.policyPlugin = parser.value("policy-plugin");
    result.bridgePlugin = parser.value("bridge-plugin");
    result.laboratoryBridge = parser.isSet("lab-bridge") && !parser.isSet("no-lab-bridge");
    result.bridgeBind = parser.value("bridge-bind");
    bool bridgePortValid = false;
    result.bridgePort = parser.value("bridge-port").toInt(&bridgePortValid);
    result.bridgePeer = parser.value("bridge-peer");
    result.bridgeTokenEnvironment = parser.value("bridge-token-env");
    result.decisionEnabled = parser.isSet("decision") && !parser.isSet("no-decision");
    result.decisionPlugin = parser.value("decision-plugin");
    result.decisionApi = parser.value("decision-api");
    result.decisionEndpoint = parser.value("decision-endpoint");
    result.decisionModel = parser.value("decision-model");
    result.decisionSchemaProfile = parser.value("decision-schema-profile");
    if (result.decisionSchemaProfile != "basic" && result.decisionSchemaProfile != "concise") {
        if (error)
            *error = "Invalid decision schema profile";
        return {};
    }
    if (parser.isSet("decision-temperature")) {
        bool valid = false;
        const double value = parser.value("decision-temperature").toDouble(&valid);
        if (!valid || !std::isfinite(value) || value < 0 || value > 2) {
            if (error)
                *error = "Invalid optional decision temperature";
            return {};
        }
        result.decisionTemperature = value;
    }
    result.decisionKeyEnvironment = parser.value("decision-key-env");
    result.speechEnabled = parser.isSet("speech") && !parser.isSet("no-speech");
    result.speechPlayback = parser.isSet("speech-play") && !parser.isSet("no-speech-play") &&
                            !parser.isSet("no-speech");
    result.speechPlugin = parser.value("speech-plugin");
    result.speechExecutable = parser.value("speech-executable");
    result.speechPlayer = parser.value("speech-player");
    result.speechVoice = parser.value("speech-voice");
    result.speechEndpoint = parser.value("speech-endpoint");
    result.speechModel = parser.value("speech-model");
    if (result.speechPlayback && !result.speechEnabled) {
        if (error)
            *error = "--speech-play requires --speech";
        return {};
    }
    bool decisionTimeoutValid = false;
    result.decisionTimeout = parser.value("decision-timeout-ms").toInt(&decisionTimeoutValid);
    if (!decisionTimeoutValid || result.decisionTimeout < 50 || result.decisionTimeout > 120000 ||
        (result.decisionApi != "responses" && result.decisionApi != "chat")) {
        if (error)
            *error = "Invalid decision API or timeout";
        return {};
    }
    if (!bridgePortValid || result.bridgePort < 0 || result.bridgePort > 65535 ||
        QHostAddress(result.bridgeBind).isNull()) {
        if (error)
            *error = "Invalid bridge address or port";
        return {};
    }
    result.listPlugins = parser.isSet("list-plugins");
    result.autoLogin = parser.isSet("auto-login");
    bool robotValid = false;
    result.robotId = parser.value("robot").toInt(&robotValid);
    if (!robotValid || result.robotId < 1)
        result.robotId = 3;
    bool mqttValid = false, videoValid = false;
    result.mqttPort = parser.value("mqtt-port").toInt(&mqttValid);
    result.videoPort = parser.value("video-port").toInt(&videoValid);
    if (result.mqttHost.isEmpty() || !mqttValid || result.mqttPort < 1 || result.mqttPort > 65535 ||
        !videoValid || result.videoPort < 1 || result.videoPort > 65535 ||
        QHostAddress(result.videoBind).isNull() ||
        (result.videoCodec != "hevc" && result.videoCodec != "h264" && result.videoCodec != "auto")) {
        if (error)
            *error = "Invalid host, port, UDP address or video codec. Use --help for options.";
        return {};
    }
    return result;
}
std::optional<QVariantMap>
AppConfig::configuration(const QString &role, const QVariantMap &defaults, QString *error) const {
    auto result = pluginConfigurations.value(role).toMap();
    for (auto it = defaults.cbegin(); it != defaults.cend(); ++it) {
        if (result.contains(it.key())) {
            if (error)
                *error = "Plugin extras conflict with a common option; move that setting into "
                         "profile.options";
            return {};
        }
        result.insert(it.key(), it.value());
    }
    return result;
}
