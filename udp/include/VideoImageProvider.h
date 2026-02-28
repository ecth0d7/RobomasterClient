#ifndef VIDEOIMAGEPROVIDER_H
#define VIDEOIMAGEPROVIDER_H

#include <QQuickImageProvider>
#include <QImage>
#include <QMutex>

class VideoImageProvider : public QQuickImageProvider
{
public:
    VideoImageProvider();

    // 核心函数：QML 请求图片时调用
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

    // 供 VideoReceiver 调用：更新最新的一帧
    void updateImage(const QImage &img);

private:
    QImage m_currentImage;
    QMutex m_mutex; // 线程锁，防止读写冲突
};

#endif // VIDEOIMAGEPROVIDER_H
