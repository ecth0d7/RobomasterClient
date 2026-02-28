#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include <QDir>
#include <QTimer>
#include <memory>
#include <vector>

// MQTT相关头文件（包含所有发送+接收处理器）
#include "MqttClient.h"          
#include "MqttRecvHandlers.h"    
#include "MqttSendHandlers.h"    

// UDP视频流相关头文件
#include "VideoReceiver.h"
#include "VideoImageProvider.h"
//全局输入过滤器头文件
#include "GlobalInputFilter.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    // QML必须使用QGuiApplication（同时支撑MQTT和UDP/FFmpeg）
    QGuiApplication a(argc, argv);
    a.setApplicationName("RoboMasterMqttVideoClient");
    a.setApplicationVersion("V2.0.0");
    // ===================== 初始化全局输入过滤器 =====================
   GlobalInputFilter *globalInputFilter = new GlobalInputFilter();
    // 设置长按阈值（可选，默认500ms）
   

    // ===================== 1. 初始化QML引擎（全局唯一） =====================
    QQmlApplicationEngine engine;
        // 新增：将全局输入过滤器暴露到QML上下文
    engine.rootContext()->setContextProperty("globalInputFilter", globalInputFilter);

    // 打印调试信息（整合版）
    qInfo() << "==================== 调试信息 ====================";
    qInfo() << "项目根目录：" << QDir::currentPath();

    // ===================== 2. 初始化UDP视频流模块（完全保留） =====================
      // 1. 创建 ImageProvider
    VideoImageProvider *provider = new VideoImageProvider();

    // 2. 创建 VideoReceiver，并把 provider 传进去
    VideoReceiver receiver(provider);
    // 3. 向 QML 注册 ImageProvider，名字叫 "videoProvider"
    engine.addImageProvider(QLatin1String("videoProvider"), provider);

    // 4. 把 VideoReceiver 注册为上下文属性，方便 QML 直接访问
    engine.rootContext()->setContextProperty("videoReceiver", &receiver);
    // ===================== 3. 配置MQTT客户端 =====================
    MqttClient mqttClient("robomaster_server2client_001", "127.0.0.1", 3333);
    if (!mqttClient.init()) {
        qCritical() << "【MQTT模块】MQTT客户端初始化失败！但视频模块仍会运行";
    } else {
        qInfo() << "【MQTT模块】MQTT客户端初始化成功";
    }

    // ===================== 4. 创建所有MQTT处理器（接收+发送）并暴露给QML =====================
    std::vector<std::shared_ptr<IMqttHandler>> allHandlers;

    // -------------------- 4.1 接收处理器（RecvHandlers）：24个完整列表 --------------------
    // 1. 比赛全局状态处理器
    auto gameStatusHandler = std::make_shared<GameStatusRecvHandler>();
    engine.rootContext()->setContextProperty("gameStatusHandler", gameStatusHandler.get());
    allHandlers.emplace_back(gameStatusHandler);

    // 2. 基地/前哨站/机器人全局状态处理器
    auto globalUnitHandler = std::make_shared<GlobalUnitStatusRecvHandler>();
    engine.rootContext()->setContextProperty("globalUnitHandler", globalUnitHandler.get());
    allHandlers.emplace_back(globalUnitHandler);

    // 3. 全局后勤信息处理器
    auto globalLogisticsHandler = std::make_shared<GlobalLogisticsRecvHandler>();
    engine.rootContext()->setContextProperty("globalLogisticsHandler", globalLogisticsHandler.get());
    allHandlers.emplace_back(globalLogisticsHandler);

    // 4. 全局特殊机制处理器
    auto globalSpecialMechanismHandler = std::make_shared<GlobalSpecialMechanismRecvHandler>();
    engine.rootContext()->setContextProperty("globalSpecialMechanismHandler", globalSpecialMechanismHandler.get());
    allHandlers.emplace_back(globalSpecialMechanismHandler);

    // 5. 全局事件通知处理器
    auto eventHandler = std::make_shared<EventRecvHandler>();
    engine.rootContext()->setContextProperty("eventHandler", eventHandler.get());
    allHandlers.emplace_back(eventHandler);

    // 6. 机器人受伤统计处理器
    auto robotInjuryStatHandler = std::make_shared<RobotInjuryStatRecvHandler>();
    engine.rootContext()->setContextProperty("robotInjuryStatHandler", robotInjuryStatHandler.get());
    allHandlers.emplace_back(robotInjuryStatHandler);

    // 7. 机器人复活状态处理器
    auto robotRespawnStatusHandler = std::make_shared<RobotRespawnRecvHandler>();
    engine.rootContext()->setContextProperty("robotRespawnStatusHandler", robotRespawnStatusHandler.get());
    allHandlers.emplace_back(robotRespawnStatusHandler);

    // 8. 机器人固定属性配置处理器
    auto robotStaticStatusHandler = std::make_shared<RobotStaticStatusRecvHandler>();
    engine.rootContext()->setContextProperty("robotStaticStatusHandler", robotStaticStatusHandler.get());
    allHandlers.emplace_back(robotStaticStatusHandler);

    // 9. 机器人实时动态数据处理器
    auto robotDynamicStatusHandler = std::make_shared<RobotDynamicStatusRecvHandler>();
    engine.rootContext()->setContextProperty("robotDynamicStatusHandler", robotDynamicStatusHandler.get());
    allHandlers.emplace_back(robotDynamicStatusHandler);

    // 10. 机器人模块状态处理器
    auto robotModuleStatusHandler = std::make_shared<RobotModuleStatusRecvHandler>();
    engine.rootContext()->setContextProperty("robotModuleStatusHandler", robotModuleStatusHandler.get());
    allHandlers.emplace_back(robotModuleStatusHandler);

    // 11. 机器人位置与朝向处理器
    auto robotPositionHandler = std::make_shared<RobotPositionRecvHandler>();
    engine.rootContext()->setContextProperty("robotPositionHandler", robotPositionHandler.get());
    allHandlers.emplace_back(robotPositionHandler);

    // 12. Buff效果信息处理器
    auto buffHandler = std::make_shared<BuffRecvHandler>();
    engine.rootContext()->setContextProperty("buffHandler", buffHandler.get());
    allHandlers.emplace_back(buffHandler);

    // 13. 判罚信息处理器
    auto penaltyInfoHandler = std::make_shared<PenaltyInfoRecvHandler>();
    engine.rootContext()->setContextProperty("penaltyInfoHandler", penaltyInfoHandler.get());
    allHandlers.emplace_back(penaltyInfoHandler);

    // 14. 哨兵轨迹规划处理器
    auto robotPathPlanHandler = std::make_shared<RobotPathPlanRecvHandler>();
    engine.rootContext()->setContextProperty("robotPathPlanHandler", robotPathPlanHandler.get());
    allHandlers.emplace_back(robotPathPlanHandler);

    // 15. 雷达位置信息处理器
    auto radarInfoHandler = std::make_shared<RadarInfoRecvHandler>();
    engine.rootContext()->setContextProperty("radarInfoHandler", radarInfoHandler.get());
    allHandlers.emplace_back(radarInfoHandler);

    // 16. 自定义数据流处理器
    auto customByteBlockHandler = std::make_shared<CustomByteBlockRecvHandler>();
    engine.rootContext()->setContextProperty("customByteBlockHandler", customByteBlockHandler.get());
    allHandlers.emplace_back(customByteBlockHandler);

    // 17. 科技核心运动状态处理器
    auto techCoreMotionHandler = std::make_shared<TechCoreMotionRecvHandler>();
    engine.rootContext()->setContextProperty("techCoreMotionHandler", techCoreMotionHandler.get());
    allHandlers.emplace_back(techCoreMotionHandler);

    // 18. 机器人性能体系状态处理器
    auto robotPerformanceSyncHandler = std::make_shared<RobotPerformanceSyncRecvHandler>();
    engine.rootContext()->setContextProperty("robotPerformanceSyncHandler", robotPerformanceSyncHandler.get());
    allHandlers.emplace_back(robotPerformanceSyncHandler);

    // 19. 英雄部署模式状态处理器
    auto deployModeStatusHandler = std::make_shared<DeployModeStatusRecvHandler>();
    engine.rootContext()->setContextProperty("deployModeStatusHandler", deployModeStatusHandler.get());
    allHandlers.emplace_back(deployModeStatusHandler);

    // 20. 能量机关状态处理器
    auto runeStatusHandler = std::make_shared<RuneStatusRecvHandler>();
    engine.rootContext()->setContextProperty("runeStatusHandler", runeStatusHandler.get());
    allHandlers.emplace_back(runeStatusHandler);

    // 21. 哨兵状态处理器
    auto sentryStatusHandler = std::make_shared<SentryStatusRecvHandler>();
    engine.rootContext()->setContextProperty("sentryStatusHandler", sentryStatusHandler.get());
    allHandlers.emplace_back(sentryStatusHandler);

    // 22. 飞镖目标选择状态处理器
    auto dartTargetStatusHandler = std::make_shared<DartTargetStatusRecvHandler>();
    engine.rootContext()->setContextProperty("dartTargetStatusHandler", dartTargetStatusHandler.get());
    allHandlers.emplace_back(dartTargetStatusHandler);

    // 23. 哨兵控制结果处理器
    auto sentryCtrlResultHandler = std::make_shared<SentryCtrlResultRecvHandler>();
    engine.rootContext()->setContextProperty("sentryCtrlResultHandler", sentryCtrlResultHandler.get());
    allHandlers.emplace_back(sentryCtrlResultHandler);

    // 24. 空中支援状态处理器
    auto airSupportStatusHandler = std::make_shared<AirSupportStatusRecvHandler>();
    engine.rootContext()->setContextProperty("airSupportStatusHandler", airSupportStatusHandler.get());
    allHandlers.emplace_back(airSupportStatusHandler);

    // -------------------- 4.2 发送处理器（SendHandlers）：完整11个（匹配实际代码） --------------------
    // 1. 键鼠遥控发送处理器
    auto keyboardMouseHandler = std::make_shared<KeyboardMouseSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("keyboardMouseHandler", keyboardMouseHandler.get());
    allHandlers.emplace_back(keyboardMouseHandler);

    // 2. 自定义控制数据发送处理器
    auto customControlHandler = std::make_shared<CustomControlSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("customControlHandler", customControlHandler.get());
    allHandlers.emplace_back(customControlHandler);

    // 3. 云台手地图点击标记发送处理器
    auto mapClickInfoHandler = std::make_shared<MapClickInfoSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("mapClickInfoHandler", mapClickInfoHandler.get());
    allHandlers.emplace_back(mapClickInfoHandler);

    // 4. 工程装配指令发送处理器
    auto assemblyCommandHandler = std::make_shared<AssemblyCommandSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("assemblyCommandHandler", assemblyCommandHandler.get());
    allHandlers.emplace_back(assemblyCommandHandler);

    // 5. 步兵/英雄性能体系选择指令发送处理器
    auto robotPerformanceHandler = std::make_shared<RobotPerformanceSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("robotPerformanceHandler", robotPerformanceHandler.get());
    allHandlers.emplace_back(robotPerformanceHandler);

    // 6. 机器人通用指令发送处理器
    auto commonCommandHandler = std::make_shared<CommonCommandSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("commonCommandHandler", commonCommandHandler.get());
    allHandlers.emplace_back(commonCommandHandler);

    // 7. 英雄部署模式指令发送处理器
    auto heroDeployModeHandler = std::make_shared<HeroDeployModeSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("heroDeployModeHandler", heroDeployModeHandler.get());
    allHandlers.emplace_back(heroDeployModeHandler);

    // 8. 能量机关激活指令发送处理器（补全注册，代码中已定义完整）
    auto runeActivateHandler = std::make_shared<RuneActivateSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("runeActivateHandler", runeActivateHandler.get());
    allHandlers.emplace_back(runeActivateHandler);

    // 9. 飞镖控制指令发送处理器（补全注册，代码中已定义完整）
    auto dartCommandHandler = std::make_shared<DartCommandSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("dartCommandHandler", dartCommandHandler.get());
    allHandlers.emplace_back(dartCommandHandler);

    // 10. 哨兵控制指令请求发送处理器（补全注册，代码中已定义完整）
    auto sentryCtrlHandler = std::make_shared<SentryCtrlSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("sentryCtrlHandler", sentryCtrlHandler.get());
    allHandlers.emplace_back(sentryCtrlHandler);

    // 11. 空中支援指令发送处理器（补全注册，代码中已定义完整）
    auto airSupportHandler = std::make_shared<AirSupportSendHandler>(&mqttClient);
    engine.rootContext()->setContextProperty("airSupportHandler", airSupportHandler.get());
    allHandlers.emplace_back(airSupportHandler);

    // ===================== 5. 注册所有处理器（发送+接收）并连接服务器 =====================
    // 批量注册：所有处理器（发送+接收）都会被存入m_handlers，接收处理器会自动订阅主题
    mqttClient.registerHandlers(allHandlers);
    qInfo() << "【MQTT模块】已注册处理器总数：" << allHandlers.size() 
            << "（接收处理器：24个 | 发送处理器：11个）";
    
    // ===================== 6. MQTT连接与重连机制 =====================
    // 创建重连定时器
    QTimer reconnectTimer;
    reconnectTimer.setInterval(1000); // 1秒
    reconnectTimer.setSingleShot(false); // 循环触发
    
    // 标记是否已连接成功
    bool connected = false;
    
    // 尝试连接的函数
    std::function<void()> tryConnect = [&]() {
        if (connected) return;
        
        qInfo() << "【MQTT模块】尝试连接服务器...";
        if (mqttClient.connectToServer()) {
            connected = true;
            reconnectTimer.stop();
            qInfo() << "=====================================";
            qInfo() << "MQTT连接成功，开始接收服务器数据...";
            qInfo() << "=====================================";
        } else {
            qWarning() << "【MQTT模块】连接失败，将在1秒后重试...";
            // 确保定时器在运行
            if (!reconnectTimer.isActive()) {
                reconnectTimer.start();
            }
        }
    };
    
    // 连接定时器的超时信号
    QObject::connect(&reconnectTimer, &QTimer::timeout, tryConnect);
    
    // 首次连接尝试
    tryConnect();
    
    // 监听断开连接事件，触发重连
    QObject::connect(&mqttClient, &MqttClient::disconnected, [&]() {
        qWarning() << "=====================================";
        qWarning() << "MQTT连接已断开！将在1秒后重连...";
        qWarning() << "=====================================";
        connected = false;
        if (!reconnectTimer.isActive()) {
            reconnectTimer.start();
        }
    });
    
    // 监听错误事件，触发重连
    QObject::connect(&mqttClient, &MqttClient::errorOccurred, [&](const std::string& errorMsg) {
        // 如果是已连接状态下的错误，可能需要重连
        if (connected) {
            qCritical() << "=====================================";
            qCritical() << "MQTT错误发生：" << QString::fromStdString(errorMsg);
            qCritical() << "=====================================";
            // 注意：这里不立即设置connected=false，因为disconnected信号会处理
            // 但如果客户端没有发出disconnected信号，我们可能需要主动处理
        } else {
            qDebug() << "【MQTT模块】连接过程中的错误：" << QString::fromStdString(errorMsg);
        }
    });
    
    // 监听连接成功信号，确保状态同步
    QObject::connect(&mqttClient, &MqttClient::connected, [&]() {
        if (!connected) {
            qInfo() << "=====================================";
            qInfo() << "MQTT连接成功（通过后续信号确认）...";
            qInfo() << "=====================================";
            connected = true;
            reconnectTimer.stop();
        }
    });

    // ===================== 7. 加载QML界面（完全保留） =====================
    // 注意：根据实际项目路径调整QML文件路径，以下为示例路径
    const QUrl url(u"qrc:/qml/components/Main.qml"_qs);
     QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &a, [&](QObject *obj, const QUrl &objUrl) {
        if (objUrl == url) {
            if (obj) {
                QQuickWindow *window = qobject_cast<QQuickWindow*>(obj);
                if (window) {
                    qDebug() << "找到QML主窗口，开始设置事件过滤器";
                    
                    // 设置过滤器父对象为窗口
                    globalInputFilter->setParent(window);
                    
                    // 安装事件过滤器到窗口
                    window->installEventFilter(globalInputFilter);
                    
                    qDebug() << "事件过滤器已安装到主窗口";
                }
            }
        }
    }, Qt::QueuedConnection);
    engine.load(url);

    // 检查QML加载状态
    if (engine.rootObjects().isEmpty()) {
        qCritical() << "QML加载失败！尝试的路径：" << url.toString();
        qCritical() << "请检查QML文件是否存在，路径是否正确！";
        // 可选：若QML加载失败，仍保持程序运行（仅MQTT+视频功能可用）
        // return -1; 
    } else {
        qInfo() << "QML加载成功！界面已显示（包含MQTT+视频功能）";
    }

    // QML对象创建失败处理（不退出程序）
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &a, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) {
            qCritical() << "QML对象创建失败！路径：" << objUrl.toString();
        }
    }, Qt::QueuedConnection);

    return a.exec();
}