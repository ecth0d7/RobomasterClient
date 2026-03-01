#ifndef VIDEORECEIVER_H
#define VIDEORECEIVER_H

#include <QObject>
#include <QUdpSocket>
#include <QImage>
#include "VideoImageProvider.h"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>
}

class VideoReceiver : public QObject {
    Q_OBJECT
public:
    explicit VideoReceiver(VideoImageProvider *provider, QObject *parent = nullptr);
    ~VideoReceiver();

signals:
    void frameReady();

private slots:
    void readData();

private:
    void decode(const QByteArray &data);

    QUdpSocket *m_socket;
    VideoImageProvider *m_provider;
    AVCodecContext *m_codecCtx = nullptr;
    AVFrame *m_frame = nullptr;
    SwsContext *m_swsCtx = nullptr;
    uint8_t *m_rgbBuffer = nullptr;

    // 组包逻辑变量
    QByteArray m_buffer;
    uint16_t m_lastFrameId = 0xFFFF;
    uint16_t m_expectedSliceId = 0;
    bool m_isCurrentFrameCorrupt = true;
};

#endif