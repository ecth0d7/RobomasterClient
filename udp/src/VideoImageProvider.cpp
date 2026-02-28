#include "VideoImageProvider.h"

VideoImageProvider::VideoImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage VideoImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    Q_UNUSED(id);
    QMutexLocker locker(&m_mutex);

    if (size) {
        *size = m_currentImage.size();
    }

    // 如果请求了特定大小，就缩放（但我们这里直接返回原图，QML自己处理缩放更快）
    if (!requestedSize.isEmpty() && !m_currentImage.isNull()) {
        return m_currentImage.scaled(requestedSize, Qt::KeepAspectRatio, Qt::FastTransformation);
    }

    return m_currentImage;
}

void VideoImageProvider::updateImage(const QImage &img)
{
    QMutexLocker locker(&m_mutex);
    m_currentImage = img;
}
