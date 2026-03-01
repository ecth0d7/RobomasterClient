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