#pragma once
#include <QString>

namespace GraphicsBootstrap {
// 在 QGuiApplication 创建后、任何 QQuickWindow 创建前调用。
// 返回失败时由入口正常退出，不让 RHI 初始化走到 qFatal/abort。
bool configure(const QString &mode, QString *error);
}
