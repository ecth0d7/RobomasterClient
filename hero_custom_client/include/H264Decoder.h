#pragma once

#include <QObject>
#include <QByteArray>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
}

class VideoImageProvider;

class H264Decoder final : public QObject {
    Q_OBJECT
public:
    explicit H264Decoder(VideoImageProvider *provider, QObject *parent = nullptr);
    ~H264Decoder() override;
    void decode(const QByteArray &annexBFrame);
    void reset();

signals:
    void frameReady();

private:
    VideoImageProvider *m_provider;
    AVCodecContext *m_context = nullptr;
    AVFrame *m_frame = nullptr;
    SwsContext *m_sws = nullptr;
    int m_width = 0;
    int m_height = 0;
};
