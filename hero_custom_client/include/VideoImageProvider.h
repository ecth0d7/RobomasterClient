#pragma once

#include <QImage>
#include <QMutex>
#include <QQuickImageProvider>

class VideoImageProvider final : public QQuickImageProvider {
public:
    VideoImageProvider();
    QImage requestImage(const QString &, QSize *size, const QSize &requestedSize) override;
    void updateImage(const QImage &image);

private:
    QMutex m_mutex;
    QImage m_image;
};
