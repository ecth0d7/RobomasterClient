#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSGRendererInterface>

#include "H264Decoder.h"
#include "HeroClient.h"
#include "VideoImageProvider.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName("HNU");
    QCoreApplication::setApplicationName("HeroCustomClient");

    // 必须在创建首个 QQuickWindow 前固定渲染后端。该客户端的视频已经由
    // FFmpeg 解码为 QImage；使用 Software 场景图可绕开 X11 分数缩放下
    // OpenGL 全屏交换链在按键动画重绘时出现的左上角小画面/黑屏问题。
    QQuickWindow::setGraphicsApi(QSGRendererInterface::Software);

    QQmlApplicationEngine engine;
    auto *provider = new VideoImageProvider;
    engine.addImageProvider("heroVideo", provider);
    H264Decoder decoder(provider);
    HeroClient client(&decoder);
    engine.rootContext()->setContextProperty("heroClient", &client);
    engine.load(QUrl("qrc:/HeroMain.qml"));
    if (engine.rootObjects().isEmpty()) return -1;
    return app.exec();
}
