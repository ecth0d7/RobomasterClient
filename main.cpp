#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include <QDir>
#include <QTimer>
#include <memory>
#include <vector>
#include <functional>

// MQTT相关头文件
#include "MqttClient.h"          
#include "MqttRecvHandlers.h"    
#include "MqttSendHandlers.h"    

// UDP视频流相关头文件
#include "VideoReceiver.h"
#include "VideoImageProvider.h"
// 全局输入过滤器头文件
#include "GlobalInputFilter.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    QGuiApplication a(argc, argv);
    a.setApplicationName("RoboMasterMqttVideoClient");
    a.setApplicationVersion("V2.0.0");

    // ===================== 1. 初始化全局输入过滤器 =====================
    GlobalInputFilter *globalInputFilter = new GlobalInputFilter();

    // ===================== 2. 初始化QML引擎 =====================
    QQmlApplicationEngine engine;
    
    // 暴露全局输入过滤器
    engine.rootContext()->setContextProperty("globalInputFilter", globalInputFilter);

    // ===================== 3. 初始化UDP视频流模块 =====================
    VideoImageProvider *provider = new VideoImageProvider();
    VideoReceiver receiver(provider);
    engine.addImageProvider(QLatin1String("videoProvider"), provider);
    engine.rootContext()->setContextProperty("videoReceiver", &receiver);

    // ===================== 4. 配置MQTT客户端 (不立即连接) =====================
    // 默认构造，ID和地址稍后通过 UI 设置
    MqttClient mqttClient("robomaster_server2client_001", "192.168.12.1", 3333);
    
    // 将 mqttClient 暴露给 QML，以便在登录界面设置 clientId 和调用 connect
    engine.rootContext()->setContextProperty("mqttClient", &mqttClient);

    // ===================== 5. 创建并注册所有MQTT处理器 =====================
    std::vector<std::shared_ptr<IMqttHandler>> allHandlers;

    // -------------------- 5.1 接收处理器 (25个) --------------------
    auto gameStatusHandler = std::make_shared<GameStatusRecvHandler>();
    engine.rootContext()->setContextProperty("gameStatusHandler", gameStatusHandler.get());
    allHandlers.emplace_back(gameStatusHandler);

    auto globalUnitHandler = std::make_shared<GlobalUnitStatusRecvHandler>();
    engine.rootContext()->setContextProperty("globalUnitHandler", globalUnitHandler.get());
    allHandlers.emplace_back(globalUnitHandler);

    auto globalLogisticsHandler = std::make_shared<GlobalLogisticsRecvHandler>();
    engine.rootContext()->setContextProperty("globalLogisticsHandler", globalLogisticsHandler.get());
    allHandlers.emplace_back(globalLogisticsHandler);

    auto globalSpecialMechanismHandler = std::make_shared<GlobalSpecialMechanismRecvHandler>();
    engine.rootContext()->setContextProperty("globalSpecialMechanismHandler", globalSpecialMechanismHandler.get());
    allHandlers.emplace_back(globalSpecialMechanismHandler);

    auto eventHandler = std::make_shared<EventRecvHandler>();
    engine.rootContext()->setContextProperty("eventHandler", eventHandler.get());
    allHandlers.emplace_back(eventHandler);

    auto robotInjuryStatHandler = std::make_shared<RobotInjuryStatRecvHandler>();
    engine.rootContext()->setContextProperty("robotInjuryStatHandler", robotInjuryStatHandler.get());
    allHandlers.emplace_back(robotInjuryStatHandler);

    auto robotRespawnStatusHandler = std::make_shared<RobotRespawnRecvHandler>();
    engine.rootContext()->setContextProperty("robotRespawnStatusHandler", robotRespawnStatusHandler.get());
    allHandlers.emplace_back(robotRespawnStatusHandler);

    auto robotStaticStatusHandler = std::make_shared<RobotStaticStatusRecvHandler>();
    engine.rootContext()->setContextProperty("robotStaticStatusHandler", robotStaticStatusHandler.get());
    allHandlers.emplace_back(robotStaticStatusHandler);

    auto robotDynamicStatusHandler = std::make_shared<RobotDynamicStatusRecvHandler>();
    engine.rootContext()->setContextProperty("robotDynamicStatusHandler", robotDynamicStatusHandler.get());
    allHandlers.emplace_back(robotDynamicStatusHandler);

    auto robotModuleStatusHandler = std::make_shared<RobotModuleStatusRecvHandler>();
    engine.rootContext()->setContextProperty("robotModuleStatusHandler", robotModuleStatusHandler.get());
    allHandlers.emplace_back(robotModuleStatusHandler);

    auto robotPositionHandler = std::make_shared<RobotPositionRecvHandler>();
    engine.rootContext()->setContextProperty("robotPositionHandler", robotPositionHandler.get());
    allHandlers.emplace_back(robotPositionHandler);

    auto buffHandler = std::make_shared<BuffRecvHandler>();
    engine.rootContext()->setContextProperty("buffHandler", buffHandler.get());
    allHandlers.emplace_back(buffHandler);

    auto penaltyInfoHandler = std::make_shared<PenaltyInfoRecvHandler>();
    engine.rootContext()->setContextProperty("penaltyInfoHandler", penaltyInfoHandler.get());
    allHandlers.emplace_back(penaltyInfoHandler);

    auto robotPathPlanHandler = std::make_shared<RobotPathPlanRecvHandler>();
    engine.rootContext()->setContextProperty("robotPathPlanHandler", robotPathPlanHandler.get());
    allHandlers.emplace_back(robotPathPlanHandler);

    auto mapClickInfoHandler = std::make_shared<MapClickInfoRecvHandler>();
    engine.rootContext()->setContextProperty("mapClickInfoRecvHandler", mapClickInfoHandler.get());
    allHandlers.emplace_back(mapClickInfoHandler);

    auto radarInfoHandler = std::make_shared<RadarInfoRecvHandler>();
    engine.rootContext()->setContextProperty("radarInfoHandler", radarInfoHandler.get());
    allHandlers.emplace_back(radarInfoHandler);

    auto customByteBlockHandler = std::make_shared<CustomByteBlockRecvHandler>();
    engine.rootContext()->setContextProperty("customByteBlockHandler", customByteBlockHandler.get());
    allHandlers.emplace_back(customByteBlockHandler);

    auto techCoreMotionHandler = std::make_shared<TechCoreMotionRecvHandler>();
    engine.rootContext()->setContextProperty("techCoreMotionHandler", techCoreMotionHandler.get());
    allHandlers.emplace_back(techCoreMotionHandler);

    auto robotPerformanceSyncHandler = std::make_shared<RobotPerformanceSyncRecvHandler>();
    engine.rootContext()->setContextProperty("robotPerformanceSyncHandler", robotPerformanceSyncHandler.get());
    allHandlers.emplace_back(robotPerformanceSyncHandler);

    auto deployModeStatusHandler = std::make_shared<DeployModeStatusRecvHandler>();
    engine.rootContext()->setContextProperty("deployModeStatusHandler", deployModeStatusHandler.get());
    allHandlers.emplace_back(deployModeStatusHandler);

    auto runeStatusHandler = std::make_shared<RuneStatusRecvHandler>();
    engine.rootContext()->setContextProperty("runeStatusHandler", runeStatusHandler.get());
    allHandlers.emplace_back(runeStatusHandler);

    auto sentryStatusHandler = std::make_shared<SentryStatusRecvHandler>();
    engine.rootContext()->setContextProperty("sentryStatusHandler", sentryStatusHandler.get());
    allHandlers.emplace_back(sentryStatusHandler);

    auto dartTargetStatusHandler = std::make_shared<DartTargetStatusRecvHandler>();
    engine.rootContext()->setContextProperty("dartTargetStatusHandler", dartTargetStatusHandler.get());
    allHandlers.emplace_back(dartTargetStatusHandler);

    auto sentryCtrlResultHandler = std::make_shared<SentryCtrlResultRecvHandler>();
    engine.rootContext()->setContextProperty("sentryCtrlResultHandler", sentryCtrlResultHandler.get());
    allHandlers.emplace_back(sentryCtrlResultHandler);

    auto airSupportStatusHandler = std::make_shared<AirSupportStatusRecvHandler>();
    engine.rootContext()->setContextProperty("airSupportStatusHandler", airSupportStatusHandler.get());
    allHandlers.emplace_back(airSupportStatusHandler);

    // -------------------- 5.2 发送处理器 (11个) --------------------
    auto keyboardMouseHandler = std::make_shared<KeyboardMouseSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("keyboardMouseHandler", keyboardMouseHandler.get());
    allHandlers.emplace_back(keyboardMouseHandler);

    auto customControlHandler = std::make_shared<CustomControlSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("customControlHandler", customControlHandler.get());
    allHandlers.emplace_back(customControlHandler);

    auto mapClickCmdHandler = std::make_shared<MapClickCmdSendHandler>(&mqttClient);
    // 保留旧 QML 上下文名，底层 topic 已更新为 MapClickCmd。
    engine.rootContext()->setContextProperty("mapClickInfoHandler", mapClickCmdHandler.get());
    allHandlers.emplace_back(mapClickCmdHandler);

    auto assemblyCommandHandler = std::make_shared<AssemblyCommandSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("assemblyCommandHandler", assemblyCommandHandler.get());
    allHandlers.emplace_back(assemblyCommandHandler);

    auto robotPerformanceHandler = std::make_shared<RobotPerformanceSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("robotPerformanceHandler", robotPerformanceHandler.get());
    allHandlers.emplace_back(robotPerformanceHandler);

    auto commonCommandHandler = std::make_shared<CommonCommandSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("commonCommandHandler", commonCommandHandler.get());
    allHandlers.emplace_back(commonCommandHandler);

    auto heroDeployModeHandler = std::make_shared<HeroDeployModeSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("heroDeployModeHandler", heroDeployModeHandler.get());
    allHandlers.emplace_back(heroDeployModeHandler);

    auto runeActivateHandler = std::make_shared<RuneActivateSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("runeActivateHandler", runeActivateHandler.get());
    allHandlers.emplace_back(runeActivateHandler);

    auto dartCommandHandler = std::make_shared<DartCommandSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("dartCommandHandler", dartCommandHandler.get());
    allHandlers.emplace_back(dartCommandHandler);

    auto sentryCtrlHandler = std::make_shared<SentryCtrlSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("sentryCtrlHandler", sentryCtrlHandler.get());
    allHandlers.emplace_back(sentryCtrlHandler);

    auto airSupportHandler = std::make_shared<AirSupportSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("airSupportHandler", airSupportHandler.get());
    allHandlers.emplace_back(airSupportHandler);

    // 执行批量注册
    mqttClient.registerHandlers(allHandlers);

    // ===================== 6. 加载 QML =====================
    const QUrl url(u"qrc:/qml/components/Main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &a, [&](QObject *obj, const QUrl &objUrl) {
        if (objUrl == url && obj) {
            QQuickWindow *window = qobject_cast<QQuickWindow*>(obj);
            if (window) {
                globalInputFilter->setParent(window);
                window->installEventFilter(globalInputFilter);
            }
        }
    }, Qt::QueuedConnection);

    engine.load(url);

    if (engine.rootObjects().isEmpty()) return -1;

    return a.exec();
}
