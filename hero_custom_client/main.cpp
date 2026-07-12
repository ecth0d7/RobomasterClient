#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTimer>

#include "H264Decoder.h"
#include "HeroClient.h"
#include "VideoImageProvider.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName("HNU");
    QCoreApplication::setApplicationName("HeroCustomClient");

    QQmlApplicationEngine engine;
    auto *provider = new VideoImageProvider;
    engine.addImageProvider("heroVideo", provider);
    H264Decoder decoder(provider);
    HeroClient client(&decoder);
    engine.rootContext()->setContextProperty("heroClient", &client);
    engine.load(QUrl("qrc:/HeroMain.qml"));
    if (engine.rootObjects().isEmpty()) return -1;
    // 供无界面的协议联调使用；正常启动时不设置此环境变量。
    if (qEnvironmentVariableIsSet("HERO_TEST_AUTOCONNECT")) {
        const QString host = qEnvironmentVariable("HERO_TEST_HOST", "127.0.0.1");
        QTimer::singleShot(0, &client, [&client, host] {
            client.connectToServer("hero_protocol_test", host, 3333);
        });
        QTimer::singleShot(1000, &client, [&client] { client.trimStep(2); });
        QTimer::singleShot(2000, &client, [&client] { client.trimReset(); });
        QTimer::singleShot(3000, &client, [&client] { client.trimStep(1); });
        // 保持 MQTT 与遥测订阅，只停止 heartbeat，验证 2 秒超时回环清零。
        QTimer::singleShot(3200, &client, [&client] { client.setHeartbeatEnabled(false); });
    }
    return app.exec();
}
