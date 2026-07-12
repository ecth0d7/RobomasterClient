#include "VideoImageProvider.h"
#include <QMutexLocker>

VideoImageProvider::VideoImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

QImage VideoImageProvider::requestImage(const QString &, QSize *size, const QSize &requestedSize)
{
    QMutexLocker lock(&m_mutex);
    if (size) *size = m_image.size();
    return requestedSize.isValid() ? m_image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation)
                                   : m_image;
}

void VideoImageProvider::updateImage(const QImage &image)
{
    QMutexLocker lock(&m_mutex);
    m_image = image;
}
