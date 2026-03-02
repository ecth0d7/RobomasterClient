#ifndef VIDEORECEIVER_H
#define VIDEORECEIVER_H

#include <QObject>
#include <QUdpSocket>
#include <QImage>

// FFmpeg 必须在 extern "C" 中包含，否则会出现链接错误
extern "C" {
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <libavutil/avutil.h>
#include <libavutil/imgutils.h> // 使用 imgutils.h 替代 image.h 以获得更好的兼容性
}

class VideoImageProvider;

class VideoReceiver : public QObject {
    Q_OBJECT
public:
    explicit VideoReceiver(VideoImageProvider *provider, QObject *parent = nullptr);
    // 析构函数声明
    ~VideoReceiver();

signals:
    void frameReady();

private slots:
    void readData();

private:
    void decode(const QByteArray &data);

    QUdpSocket *m_socket = nullptr;
    VideoImageProvider *m_provider = nullptr;

    // FFmpeg 结构体指针
    AVCodecContext *m_codecCtx = nullptr;
    AVFrame *m_frame = nullptr;
    struct SwsContext *m_swsCtx = nullptr;
    uint8_t *m_rgbBuffer = nullptr;

    // 数据缓存与状态
    QByteArray m_buffer;
    uint16_t m_currentFrameId = 0;
    bool m_isCorrupt = false;
};

#endif // VIDEORECEIVER_H