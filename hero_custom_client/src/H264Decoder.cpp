#include "H264Decoder.h"
#include "VideoImageProvider.h"

#include <QImage>
#include <QDebug>

H264Decoder::H264Decoder(VideoImageProvider *provider, QObject *parent)
    : QObject(parent), m_provider(provider)
{
    const AVCodec *codec = avcodec_find_decoder(AV_CODEC_ID_H264);
    if (!codec) return;
    m_context = avcodec_alloc_context3(codec);
    m_context->flags |= AV_CODEC_FLAG_LOW_DELAY;
    if (avcodec_open2(m_context, codec, nullptr) < 0) {
        avcodec_free_context(&m_context);
        return;
    }
    m_frame = av_frame_alloc();
}

H264Decoder::~H264Decoder()
{
    if (m_sws) sws_freeContext(m_sws);
    if (m_frame) av_frame_free(&m_frame);
    if (m_context) avcodec_free_context(&m_context);
}

void H264Decoder::reset()
{
    if (m_context) avcodec_flush_buffers(m_context);
}

void H264Decoder::decode(const QByteArray &data)
{
    if (!m_context || data.isEmpty()) return;
    AVPacket *packet = av_packet_alloc();
    if (!packet) return;
    packet->data = reinterpret_cast<uint8_t *>(const_cast<char *>(data.constData()));
    packet->size = data.size();
    if (avcodec_send_packet(m_context, packet) < 0) {
        av_packet_free(&packet);
        reset();
        return;
    }
    av_packet_free(&packet);

    while (avcodec_receive_frame(m_context, m_frame) == 0) {
        if (m_frame->width != m_width || m_frame->height != m_height || !m_sws) {
            m_width = m_frame->width;
            m_height = m_frame->height;
            m_sws = sws_getCachedContext(m_sws, m_width, m_height,
                                         static_cast<AVPixelFormat>(m_frame->format),
                                         m_width, m_height, AV_PIX_FMT_BGRA,
                                         SWS_FAST_BILINEAR, nullptr, nullptr, nullptr);
        }
        QImage image(m_width, m_height, QImage::Format_ARGB32);
        uint8_t *dst[] = { image.bits(), nullptr, nullptr, nullptr };
        int lines[] = { static_cast<int>(image.bytesPerLine()), 0, 0, 0 };
        sws_scale(m_sws, m_frame->data, m_frame->linesize, 0, m_height, dst, lines);
        m_provider->updateImage(image);
        emit frameReady();
    }
}
