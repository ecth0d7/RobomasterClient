#include "VideoImageProvider.h"

VideoImageProvider::VideoImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {
}

QImage VideoImageProvider::requestImage(const QString &id, QSize *size,
                                        const QSize &requestedSize) {
    Q_UNUSED(id);
    QImage image;
    {
        QMutexLocker locker(&m_mutex);
        image = m_currentImage; // 共享只读像素，拷贝开销不随图像尺寸增长。
    }
    if (size)
        *size = image.size();
    // 缩放在锁外执行，避免整幅图像处理期间阻塞生产者。
    if (!requestedSize.isEmpty() && !image.isNull())
        return image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::FastTransformation);
    return image;
}

void VideoImageProvider::updateImage(const QImage &img) {
    QMutexLocker locker(&m_mutex);
    m_currentImage = img;
}
