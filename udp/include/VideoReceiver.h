#ifndef VIDEORECEIVER_H
#define VIDEORECEIVER_H

#include <QObject>
#include <QUdpSocket>
#include <QImage>
#include "VideoImageProvider.h"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

class VideoReceiver : public QObject
{
    Q_OBJECT
public:
    explicit VideoReceiver(VideoImageProvider *provider, QObject *parent = nullptr);
    ~VideoReceiver();

signals:
    void frameReady(); // 只发信号，不发数据，数据已经在 provider 里了

private slots:
    void readData();

private:
    void decode(const QByteArray &data);

    QUdpSocket *m_socket = nullptr;
    VideoImageProvider *m_provider = nullptr; // 保存 provider 的指针

    // FFmpeg 成员
    AVCodecContext *m_codecCtx = nullptr;
    AVFrame *m_frame = nullptr;
    SwsContext *m_swsCtx = nullptr;
    uint8_t *m_rgbBuffer = nullptr;

    // 数据缓冲
    QByteArray m_buffer;
    int m_pendingSize = 0;
};

#endif // VIDEORECEIVER_H
