#include "GraphicsBootstrap.h"
#include <QGuiApplication>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QDebug>
#if QT_CONFIG(opengl)
#include <QOpenGLContext>
#include <QOffscreenSurface>
#include <QSurfaceFormat>
#endif

namespace {
bool usableOpenGL() {
#if QT_CONFIG(opengl)
    // 同时检查上下文及实际绑定；仅检查平台名字或库存在不能证明 GL 可用。
    QOpenGLContext context;
    context.setFormat(QSurfaceFormat::defaultFormat());
    if (!context.create())
        return false;
    QOffscreenSurface surface;
    surface.setFormat(context.format());
    surface.create();
    if (!surface.isValid() || !context.makeCurrent(&surface))
        return false;
    context.doneCurrent();
    return true;
#else
    return false;
#endif
}
void useSoftware(const QString &reason) {
    QQuickWindow::setSceneGraphBackend(QStringLiteral("software"));
    QQuickWindow::setGraphicsApi(QSGRendererInterface::Software);
    qInfo().noquote() << "[graphics] Qt Quick software renderer:" << reason;
}
}

bool GraphicsBootstrap::configure(const QString &mode, QString *error) {
    if (error)
        error->clear();
    const auto reject = [error](const QString &message) {
        if (error)
            *error = message;
        return false;
    };
    if (mode == QLatin1String("software")) {
        useSoftware(QStringLiteral("explicit --renderer software"));
        return true;
    }
    const auto backend = qEnvironmentVariable("QT_QUICK_BACKEND");
    const auto rhi = qEnvironmentVariable("QSG_RHI_BACKEND");
    if (mode == QLatin1String("opengl")) {
        if ((!backend.isEmpty() && backend != QLatin1String("rhi")) ||
            (!rhi.isEmpty() && rhi != QLatin1String("opengl")))
            return reject(QStringLiteral("--renderer opengl conflicts with the selected Qt "
                                         "backend environment; use --renderer software or "
                                         "remove the conflicting override."));
        if (!usableOpenGL())
            return reject(QStringLiteral("OpenGL context is unavailable. Use --renderer auto "
                                         "or --renderer software to open the client."));
        QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
        qInfo() << "[graphics] OpenGL renderer selected; context check succeeded";
        return true;
    }
    if (mode != QLatin1String("auto"))
        return reject(QStringLiteral("Invalid renderer; choose auto, software or opengl."));
    // 尊重显式软件/自定义适配器。非 OpenGL 平台默认仍用 D3D/Metal 等，
    // 不用一次 GL 检查错误地把所有电脑都降为 CPU 绘制。
    if (!backend.isEmpty()) {
        qInfo().noquote() << "[graphics] Using explicit QT_QUICK_BACKEND:" << backend;
        return true;
    }
    if (QQuickWindow::graphicsApi() != QSGRendererInterface::OpenGL) {
        qInfo() << "[graphics] Using the platform's selected graphics API";
        return true;
    }
    if (usableOpenGL()) {
        qInfo() << "[graphics] OpenGL context check succeeded";
        return true;
    }
    if (!rhi.isEmpty())
        return reject(QStringLiteral("The forced OpenGL backend cannot create a context. "
                                     "Use --renderer software or remove QSG_RHI_BACKEND."));
    // 在第一扇窗口之前退化；创建窗口后再切换已经无法避免 RHI 的 fatal。
    useSoftware(QStringLiteral("OpenGL context unavailable; automatic startup fallback"));
    return true;
}
