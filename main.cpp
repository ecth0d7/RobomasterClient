#include <QGuiApplication>
#include <QSettings>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include "AppConfig.h"
#include "GraphicsBootstrap.h"
#include "ClientBackend.h"
#include "ServiceHub.h"
#include "LocalUiSettings.h"
#include "VideoImageProvider.h"
#include "PluginHost.h"
#include "PluginRuntime.h"
#include "VideoController.h"
#ifdef CLIENT_HAS_BATTLEFIELD
#include "BattlefieldHost.h"
#endif
#ifdef CLIENT_HAS_HERO_LOB_VIDEO
#include "HeroVideoHost.h"
#endif
#include "OperatorActions.h"
#include "OperatorPreferences.h"
#include "ProviderConfiguration.h"
#include "DecisionConfiguration.h"
#include "TeamConfiguration.h"
#include "SeasonConfiguration.h"
#include "UnavailableProtocol.h"
#include "TerminalGateway.h"
#include "TerminalDataBus.h"
#include "TerminalPluginSourceHost.h"
#include "TerminalTeamHost.h"
#ifdef CLIENT_HAS_TERMINAL_TEAM_VERIFIER
#include "TerminalTeamVerifier.h"
#endif
#include "TerminalSceneHost.h"
#include "TerminalAdviceHost.h"
#include "PluginPackageRuntime.h"
#include "TerminalVoiceCoordinator.h"
#include "TerminalSpeechHost.h"
#include "TerminalBridgeHost.h"
#include <QHostAddress>
#include "UiPack.h"
#include <QDir>
#include "UiViewController.h"
#include <QJsonDocument>

int main(int argc, char *argv[]) {
    QStringList arguments;
    for (int i = 0; i < argc; ++i)
        arguments.append(QString::fromLocal8Bit(argv[i]));
    const bool metadataOnly = AppConfig::metadataOnlyRequested(arguments);
    // 只读元数据和帮助命令无需桌面，也可通过 SSH 运行。
    std::unique_ptr<QCoreApplication> app;
    if (metadataOnly)
        app = std::make_unique<QCoreApplication>(argc, argv);
    else
        app = std::make_unique<QGuiApplication>(argc, argv);
    app->setApplicationName("RoboMasterClient");
    app->setOrganizationName("RoboMasterClient");
    app->setApplicationVersion("2.0.0");
    QString error;
    const auto config = AppConfig::fromArguments(*app, &error);
    if (!config) {
        qCritical().noquote() << error;
        return 2;
    }
    // 加载器必须晚于所有端点销毁，包含后台线程的退出过程。
    PluginHost plugins;
    if (config->listPlugins) {
        qInfo().noquote()
            << QJsonDocument::fromVariant(PluginHost::discover(config->pluginDirectory)).toJson();
        return 0;
    }
    if (!GraphicsBootstrap::configure(config->renderer, &error)) {
        qCritical().noquote() << error;
        return 2;
    }
    UiViewController uiViews(config->uiDirectory);
    QString selectedKind;
    for (const auto &value : uiViews.views()) {
        const auto view = value.toMap();
        if (view.value("id").toString() == config->uiView) {
            selectedKind = view.value("kind").toString();
            break;
        }
    }
    if (selectedKind.isEmpty()) {
        qCritical().noquote() << (uiViews.status().isEmpty()
            ? QStringLiteral("Unknown UI view: ") + config->uiView : uiViews.status());
        return 2;
    }
    if (selectedKind == QLatin1String("reference")) {
        // Retained drawing references have no operational session. This branch
        // precedes endpoint factories, model/audio services and plugin activation.
        if (!uiViews.openReference(config->uiView)) {
            qCritical().noquote() << uiViews.status();
            return 1;
        }
        return app->exec();
    }
    const auto stateConfiguration = config->configuration("state", {}, &error);
    const auto inputConfiguration = config->configuration("input", {}, &error);
    const auto policyConfiguration = config->configuration("policy", {}, &error);
    const auto videoConfiguration = config->configuration(
        "video",
        {{"bind", config->videoBind}, {"port", config->videoPort}, {"codec", config->videoCodec}},
        &error);
    if (!stateConfiguration || !inputConfiguration || !policyConfiguration || !videoConfiguration) {
        qCritical().noquote() << error;
        return 2;
    }
    const bool interfacePending = config->protocolPlugin == QLatin1String("protocol.rm2027.pending");
    auto *mqttFactory = interfacePending ? nullptr
        : plugins.load(config->pluginDirectory, config->mqttPlugin, "mqtt", &error);
    if (!mqttFactory && !interfacePending) {
        qCritical().noquote() << error;
        return 2;
    }
    auto *protocolFactory = config->protocolPlugin == QLatin1String("protocol.rm2027.pending")
        ? nullptr : plugins.load(config->pluginDirectory, config->protocolPlugin, "protocol", &error);
    if (!protocolFactory && config->protocolPlugin != QLatin1String("protocol.rm2027.pending")) {
        qCritical().noquote() << error;
        return 2;
    }
    auto *videoFactory = interfacePending ? nullptr
        : plugins.load(config->pluginDirectory, config->videoPlugin, "video", &error);
    if (!videoFactory && !interfacePending) {
        qCritical().noquote() << error;
        return 2;
    }
    auto *stateFactory =
        plugins.loadExtension(config->pluginDirectory, config->statePlugin, "state", &error);
    if (!stateFactory) {
        qCritical().noquote() << error;
        return 2;
    }
    auto *inputFactory =
        plugins.loadExtension(config->pluginDirectory, config->inputPlugin, "input", &error);
    if (!inputFactory) {
        qCritical().noquote() << error;
        return 2;
    }
    auto *policyFactory =
        plugins.loadExtension(config->pluginDirectory, config->policyPlugin, "policy", &error);
    if (!policyFactory) {
        qCritical().noquote() << error;
        return 2;
    }
    std::unique_ptr<MqttEndpoint> transport(mqttFactory ? mqttFactory->createMqtt()
                                                      : new ClosedTerminalTransport);
    std::unique_ptr<ProtocolEndpoint> codec(protocolFactory ? protocolFactory->createProtocol()
                                                           : new UnavailableProtocol);
    std::unique_ptr<TelemetryEndpoint> state(stateFactory->createTelemetry(*stateConfiguration));
    std::unique_ptr<InputEndpoint> input(inputFactory->createInput(*inputConfiguration));
    std::unique_ptr<CommandPolicyEndpoint> policy(
        policyFactory->createCommandPolicy(*policyConfiguration));
    if (!transport || !codec || !state || !input || !policy) {
        qCritical() << "Selected plugin returned an empty endpoint";
        return 2;
    }
    ClientBackend backend(config->mqttHost, config->mqttPort, std::move(transport),
                          std::move(codec), std::move(state), std::move(policy));
    ServiceHub services(&backend);
    OperatorActions actions(&backend, policyConfiguration->value("operator_actions").toMap());
    services.setOperatorActions(&actions);
    backend.setOperatorGuard([guard = QPointer<OperatorActions>(&actions)](
        const QString &topic, const QVariantMap &fields, QString *error) {
        if (guard) return guard->allowCommand(topic, fields, error);
        if (error) *error = QStringLiteral("操作宿主已关闭，未发送指令");
        return false;
    });
    OperatorPreferences operatorPreferences(&backend, &actions,
        policyConfiguration->value("operator_actions").toMap(), config->protocolPlugin,
        config->uiPreferencesFile + ".operator.json");
    services.setOperatorPreferences(&operatorPreferences);
    SeasonConfiguration seasonConfiguration(&backend, &operatorPreferences, config->protocolPlugin,
                                            config->uiPreferencesFile + ".season.json");
    services.setSeasonConfiguration(&seasonConfiguration);
    backend.setSessionGuard([guard = QPointer<SeasonConfiguration>(&seasonConfiguration)] {
        return guard ? guard->connectionReason() : QStringLiteral("赛季宿主已关闭");
    });
    backend.setRulesContext(seasonConfiguration.context());
    QObject::connect(&seasonConfiguration, &SeasonConfiguration::contextChanged, &backend,
                     [&] { backend.setRulesContext(seasonConfiguration.context()); });
    auto *terminalBus = qobject_cast<TerminalDataBus *>(seasonConfiguration.terminalBus());
    TerminalPluginSourceHost nativeSources(&seasonConfiguration, terminalBus);
    TerminalGateway localTerminal(&plugins, config->pluginDirectory, &seasonConfiguration, terminalBus,
                                  config->uiPreferencesFile + ".terminal-link-local.json");
    TerminalGateway peerTerminal(&plugins, config->pluginDirectory, &seasonConfiguration, terminalBus,
                                 config->uiPreferencesFile + ".terminal-link-peer.json");
    TerminalGateway serverTerminal(&plugins, config->pluginDirectory, &seasonConfiguration, terminalBus,
                                   config->uiPreferencesFile + ".terminal-link-server.json");
    services.addTerminalGateway("local", QStringLiteral("本机设备／本地演示"), &localTerminal);
    services.addTerminalGateway("peer", QStringLiteral("终端互联原始通道"), &peerTerminal);
    services.addTerminalGateway("server", QStringLiteral("赛事接口字节边界"), &serverTerminal);
    TerminalTeamHost terminalTeam(&plugins, config->pluginDirectory, &seasonConfiguration,
        terminalBus, config->uiPreferencesFile + ".terminal-team.json");
#ifdef CLIENT_HAS_TERMINAL_TEAM_VERIFIER
    terminalTeam.setProofVerifierFactory([](const QVariantMap &native, QString *error)
        -> std::unique_ptr<TerminalTeamProofVerifier> {
        auto verifier = std::make_unique<TerminalTeamVerifier>();
        if (!verifier->configure(native, error)) return {};
        return verifier;
    });
#endif
    services.setTerminalTeam(&terminalTeam);
    TerminalSceneHost terminalScene(&plugins, config->pluginDirectory, &seasonConfiguration, terminalBus,
        config->uiPreferencesFile + ".terminal-scene.json");
    services.setTerminalScene(&terminalScene);
    TerminalAdviceHost terminalAdvice(&plugins, config->pluginDirectory, &seasonConfiguration,
        terminalBus, &terminalTeam, config->uiPreferencesFile + ".terminal-advice.json");
    services.setTerminalAdvice(&terminalAdvice);
    TerminalVoiceCoordinator terminalVoice(&seasonConfiguration, terminalBus, &terminalTeam,
        &terminalAdvice, &services, config->uiPreferencesFile + ".terminal-voice.json");
    services.setTerminalVoice(&terminalVoice);
    // Optional project-local codec. Missing it falls back to the native bounded
    // local-JSON contract and never prevents the single-terminal workspace.
    QString localBindingError;
    if (auto *localBinding = plugins.load(config->pluginDirectory, "protocol.terminal.local.v1",
                                          "protocol", &localBindingError)) {
        for (auto *gateway : {&localTerminal, &peerTerminal, &serverTerminal})
            gateway->setProtocolBinding(std::unique_ptr<ProtocolEndpoint>(localBinding->createProtocol()),
                                        "protocol.terminal.local.v1", &localBindingError);
    }
    LocalUiSettings localUi(input.get(), &services, config->uiPreferencesFile);
    QObject::connect(&backend, &ClientBackend::identityChanged, &localUi,
                     [&] { localUi.selectRobot(backend.clientId()); });
    PluginRuntime pluginRuntime(&plugins, &services, &backend, config->pluginDirectory,
        {{"mqtt",config->mqttPlugin},{"protocol",config->protocolPlugin},{"video",config->videoPlugin},
         {"state",config->statePlugin},{"input",config->inputPlugin},{"policy",config->policyPlugin}});
    pluginRuntime.setPreparationGuard([guard=QPointer<OperatorPreferences>(&operatorPreferences)]{
        return guard && guard->editable();
    });
    TerminalSpeechHost terminalSpeech(&plugins, config->pluginDirectory, &seasonConfiguration,
        &services, config->uiPreferencesFile + ".terminal-speech.json");
    terminalSpeech.setLegacyRuntime(&pluginRuntime);
    services.setTerminalSpeech(&terminalSpeech);
    TerminalBridgeHost terminalBridge(&plugins, config->pluginDirectory, &seasonConfiguration,
        &services, config->uiPreferencesFile + ".terminal-bridge.json");
    terminalBridge.setLegacyRuntime(&pluginRuntime);
    services.setTerminalBridge(&terminalBridge);
    // Configuration stays in the host; the plugin catalog never exposes API keys,
    // bridge tokens or arbitrary executable configuration to QML.
    error.clear();
    const auto speechConfiguration = config->configuration("speech",
        {{"executable",config->speechExecutable},{"player",config->speechPlayer},
         {"voice",config->speechVoice},{"playback",config->speechPlayback},
         {"endpoint",config->speechEndpoint},{"model",config->speechModel}}, &error);
    pluginRuntime.configureOptional("speech",config->speechPlugin,
        speechConfiguration.value_or(QVariantMap{}),config->speechEnabled,error);
    error.clear();
    QVariantMap decisionDefaults{{"api",config->decisionApi},{"endpoint",config->decisionEndpoint},
        {"model",config->decisionModel},{"timeout_ms",config->decisionTimeout},
        {"schema_profile",config->decisionSchemaProfile},
        {"key",qEnvironmentVariable(config->decisionKeyEnvironment.toUtf8().constData())}};
    if (config->decisionPlugin == "decision.codex") {
        // Codex is not an HTTP endpoint. Never inject inherited API keys or
        // unsupported HTTP/schema options into its strict process config.
        decisionDefaults = {{"model", config->decisionModel.isEmpty() ? "gpt-6.1-sol" : config->decisionModel},
                            {"timeout_ms", config->decisionTimeout}};
    } else if(config->decisionTemperature)decisionDefaults["temperature"]=*config->decisionTemperature;
    const auto decisionConfiguration=config->configuration("decision",decisionDefaults,&error);
    const QString decisionConfigurationError=error;
    pluginRuntime.configureOptional("decision",config->decisionPlugin,
        decisionConfiguration.value_or(QVariantMap{}),config->decisionEnabled,error);
    error.clear();
    const auto bridgeConfiguration=config->configuration("bridge",
        {{"laboratory",true},{"bind",config->bridgeBind},{"listen_port",config->bridgePort},
         {"peer",config->bridgePeer},
         {"token",qEnvironmentVariable(config->bridgeTokenEnvironment.toUtf8().constData())}},&error);
    pluginRuntime.configureOptional("bridge",config->bridgePlugin,
        bridgeConfiguration.value_or(QVariantMap{}),config->laboratoryBridge,error);
    auto providerSeed=ProviderConfiguration::defaults();
    const auto decisionValues=decisionConfiguration.value_or(QVariantMap{});
    if(config->decisionEnabled || !decisionValues.value("model").toString().isEmpty()) {
        const QUrl endpoint(decisionValues.value("endpoint").toString());
        const bool local=QHostAddress(endpoint.host()).isLoopback() || endpoint.host()=="localhost";
        const bool deepseek=endpoint.host()=="api.deepseek.com";
        providerSeed["kind"]=deepseek?"deepseek":local?"local-http":"remote-http";
        providerSeed["enabled"]=config->decisionEnabled;
        providerSeed["endpoint"]=endpoint.toString();providerSeed["model"]=decisionValues.value("model");
        providerSeed["keyEnv"]=config->decisionKeyEnvironment;providerSeed["api"]=decisionValues.value("api",config->decisionApi);
        providerSeed["format"]=decisionValues.value("format",deepseek?"json-object":"json-schema");
        providerSeed["timeoutMs"]=QString::number(decisionValues.value("timeout_ms",config->decisionTimeout).toInt());
        providerSeed["maxOutputTokens"]=QString::number(decisionValues.value("max_output_tokens",1200).toInt());
        providerSeed["thinking"]=deepseek && decisionValues.value("thinking").toBool();
        if(config->decisionPlugin=="decision.codex") {
            providerSeed["kind"]="codex";providerSeed["executable"]=decisionValues.value("executable","codex");
            providerSeed["keyEnv"]="";
            providerSeed["authHome"]=decisionValues.value("auth_home","");
            providerSeed["reasoning"]=decisionValues.value("reasoning","high");
        }
    }
    ProviderConfiguration providerConfiguration(&backend,&pluginRuntime,&services,&operatorPreferences,
        providerSeed,config->uiPreferencesFile+".provider.json",
        {{"id",config->decisionPlugin},{"configuration",decisionValues},
         {"enabled",config->decisionEnabled},{"error",decisionConfigurationError}});
    services.setProviderConfiguration(&providerConfiguration);
    QObject::connect(&providerConfiguration,&ProviderConfiguration::modelsChanged,&services,&ServiceHub::serviceStatusChanged);
    QObject::connect(&providerConfiguration,&ProviderConfiguration::currentChanged,&services,&ServiceHub::serviceStatusChanged);
    DecisionConfiguration decisionPolicy(&backend,&operatorPreferences,&providerConfiguration,&services,
        config->uiPreferencesFile+".decision.json",config->protocolPlugin);
    services.setDecisionConfiguration(&decisionPolicy);
    pluginRuntime.configureOptional("aggregation", "team.aggregate.v2", {}, false,
        QStringLiteral("请先在赛外保存完整队伍配置，并明确分配新的共享epoch"));
    TeamConfiguration teamConfiguration(&backend, &pluginRuntime, &services, &operatorPreferences,
        config->uiPreferencesFile + ".team.json", config->protocolPlugin);
    services.setTeamConfiguration(&teamConfiguration);
    QObject::connect(&seasonConfiguration, &SeasonConfiguration::aboutToChange, &services, [&] {
        // A season/environment switch never migrates live credentials, requests
        // or command permissions. It does not connect to a new event server.
        backend.disconnectFromPlayer();
        providerConfiguration.retireForRulesChange();
        for (const auto &role : {"decision", "aggregation", "bridge", "speech"})
            pluginRuntime.retireOptional(role);
    });
    pluginRuntime.startConfigured();
    QObject::connect(&backend, &ClientBackend::connectionChanged, input.get(),
                     [&] { input->setConnected(backend.connected()); });
    QObject::connect(input.get(), &InputEndpoint::inputReady, &backend,
                     [&](quint64 id, const QVariantMap &fields) {
                         input->completeSend(id, backend.sendInput(fields));
                     });
    auto *provider = new VideoImageProvider;
    QQmlApplicationEngine engine;
    engine.addImageProvider("videoProvider", provider);
    const auto uiEntry = UiPack::entry(config->uiDirectory, &error, config->uiView);
    if (uiEntry.isEmpty()) {
        qCritical().noquote() << error;
        return 2;
    }
    // Package engines inherit this import root, never the application context.
    // Public controls reuse the selected UI pack's actual widgets and assets.
    engine.addImportPath(QDir(config->uiDirectory).absoluteFilePath("imports"));
    // 视频端点先停止，随后由引擎释放图像提供器。
    auto video=std::make_unique<VideoController>(videoFactory,&backend,*videoConfiguration,
                                                nullptr, seasonConfiguration.officialConnectionAllowed());
#ifdef CLIENT_HAS_BATTLEFIELD
    BattlefieldHost battlefield(&plugins, config->pluginDirectory, &backend, video.get());
    auto battlefieldConfig=qEnvironmentVariable("ROBOMASTER_SITUATION_CONFIG");
#endif
    QObject::connect(&seasonConfiguration, &SeasonConfiguration::aboutToChange, video.get(),
                     &VideoController::stop);
    QObject::connect(video.get(), &VideoEndpoint::frameDecoded, &engine,
                     [provider](const QImage &frame) { provider->updateImage(frame); });
    QObject::connect(video.get(),&VideoController::streamReset,&engine,
                     [provider]{provider->updateImage(QImage{});});
#ifdef CLIENT_HAS_HERO_LOB_VIDEO
    auto *encodedFactory=videoFactory?qobject_cast<EncodedVideoFactory*>(dynamic_cast<QObject*>(videoFactory)):nullptr;
    auto heroVideo=std::make_unique<HeroVideoHost>(encodedFactory,&backend,
        videoConfiguration->value("hero_video"),[&]{
            return seasonConfiguration.officialConnectionAllowed()
                && seasonConfiguration.current().value("season").toInt()==2026;
        });
#ifdef CLIENT_HAS_BATTLEFIELD
    battlefield.attachHeroVideo(heroVideo.get());
#endif
    auto *heroProvider=new VideoImageProvider;
    engine.addImageProvider("heroVideoProvider",heroProvider);
    QObject::connect(heroVideo.get(),&VideoEndpoint::frameDecoded,&engine,
        [heroProvider](const QImage &image){heroProvider->updateImage(image);});
    QObject::connect(heroVideo.get(),&HeroVideoHost::streamReset,&engine,
        [heroProvider]{heroProvider->updateImage({});});
    QObject::connect(&seasonConfiguration,&SeasonConfiguration::aboutToChange,heroVideo.get(),&HeroVideoHost::stop);
#endif
    // Native foundations survive optional package retirement. Community code
    // discovers versioned services; adding a package never changes this graph.
    PluginPackageRuntime packages(&engine, config->packageDirectory,
                                  config->packageConfigurationFile);
    services.setPackageRuntime(&packages);
    localTerminal.setPackageRuntime(&packages);
    peerTerminal.setPackageRuntime(&packages);
    serverTerminal.setPackageRuntime(&packages);
    terminalTeam.setPackageRuntime(&packages);
    packages.registerService("terminal.data@3", terminalBus);
    packages.registerService("terminal.sources@3", &nativeSources);
    packages.setObservationSourceFactory([guard = QPointer<TerminalPluginSourceHost>(&nativeSources)](
        QObject *owner, const QVariantMap &package, const QVariantMap &scope,
        const QVariantMap &descriptor, QString *sourceError) -> QObject * {
        if (guard) return guard->createSource(owner, package, scope, descriptor, sourceError);
        if (sourceError) *sourceError = QStringLiteral("Native observation source admission is unavailable");
        return nullptr;
    });
    packages.registerService("terminal.rules@1", &seasonConfiguration);
    packages.registerService("terminal.team@3", &terminalTeam);
    terminalAdvice.setPackageRuntime(&packages);
    packages.registerService("terminal.advice@1", &terminalAdvice);
    terminalScene.setPackageRuntime(&packages);
    packages.registerService("terminal.scene@1", &terminalScene);
    packages.registerService("terminal.voice@1", &terminalVoice);
    terminalSpeech.setPackageRuntime(&packages);
    packages.registerService("terminal.speech@1", &terminalSpeech);
    terminalBridge.setPackageRuntime(&packages);
    packages.registerService("laboratory.bridge@1", &terminalBridge);
    packages.registerService("core.mqtt@1", &backend);
    packages.registerService("core.input@1", input.get());
    packages.registerService("core.video@1", video.get());
    packages.registerService("core.audio@1", &services);
    packages.registerService("core.ui@1", &uiViews);
    packages.registerService("terminal.raw.local@1", &localTerminal);
    packages.registerService("terminal.raw.peer@1", &peerTerminal);
    packages.registerService("terminal.raw.server@1", &serverTerminal);
    const auto synchronizePackages = [&] {
        const auto rules = seasonConfiguration.current();
        const auto team = terminalTeam.current();
        packages.setScope({{"profile_id", seasonConfiguration.profileId()},
            {"field_profile_id", rules.value("field_profile_id").toString()},
            {"capability_revision", rules.value("capability_revision").toString()},
            {"environment", seasonConfiguration.environment()},
            {"team_id", team.value("team_id").toString().isEmpty() ? "unselected" : team.value("team_id").toString()},
            {"robot_key", team.value("robot_key").toString().isEmpty() ? "unselected" : team.value("robot_key").toString()},
            {"endpoint_host", backend.host().isEmpty() ? "unselected" : backend.host()},
            {"endpoint_port", QString::number(backend.port())}});
        packages.setConfigurationLocked(!seasonConfiguration.editable(), seasonConfiguration.lockReason());
    };
    QObject::connect(&seasonConfiguration, &SeasonConfiguration::aboutToChange, &packages,
        [&] { packages.retireAll(QStringLiteral("规则／用途正在切换，旧插件作用域已退役")); });
    QObject::connect(&seasonConfiguration, &SeasonConfiguration::contextChanged, &packages, synchronizePackages);
    QObject::connect(&seasonConfiguration, &SeasonConfiguration::stateChanged, &packages, synchronizePackages);
    // Provider/catalog status also changes during package retirement. Feeding
    // that broad notification back into setScope() recurses before its commit;
    // only a saved team/robot identity changes this part of the package scope.
    QObject::connect(&terminalTeam, &TerminalTeamHost::identityChanged, &packages, synchronizePackages);
    QObject::connect(&backend, &ClientBackend::connectionOptionsChanged, &packages, synchronizePackages);
    synchronizePackages();
    engine.rootContext()->setContextProperty("clientBackend", &backend);
    engine.rootContext()->setContextProperty("inputController", input.get());
    engine.rootContext()->setContextProperty("videoReceiver", video.get());
#ifdef CLIENT_HAS_BATTLEFIELD
    engine.rootContext()->setContextProperty("battlefieldHost", &battlefield);
#else
    engine.rootContext()->setContextProperty("battlefieldHost", static_cast<QObject *>(nullptr));
#endif
#ifdef CLIENT_HAS_HERO_LOB_VIDEO
    engine.rootContext()->setContextProperty("heroVideoReceiver",heroVideo.get());
#else
    engine.rootContext()->setContextProperty("heroVideoReceiver",static_cast<QObject*>(nullptr));
#endif
    engine.rootContext()->setContextProperty("extensionServices", &services);
    engine.rootContext()->setContextProperty("localUiSettings", &localUi);
    engine.rootContext()->setContextProperty("uiViewController", &uiViews);
    engine.load(uiEntry);
    if (engine.rootObjects().isEmpty())
        return 1;
    if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first()))
        input->attach(window);
    // Start ingress only after QML construction. Otherwise cold compilation
    // can fill the bounded MQTT inbox and expire the initial event snapshots.
    if (config->autoLogin)
        backend.loginAt(config->robotId, config->mqttHost, config->mqttPort);
#ifdef CLIENT_HAS_BATTLEFIELD
    // First assign the explicit startup seat; later identity changes still retire the old session.
    if (!battlefieldConfig.isEmpty()) battlefield.start(battlefieldConfig);
#endif
    return app->exec();
}
