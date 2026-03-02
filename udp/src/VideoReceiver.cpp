#include "VideoReceiver.h"
#include "VideoImageProvider.h"
#include <arpa/inet.h>
#include <QDebug>

VideoReceiver::VideoReceiver(VideoImageProvider *provider, QObject *parent)
    : QObject(parent), m_provider(provider) {
    
    // 修正拼写错误：AV_CODEC_ID_HEVC
    const AVCodec *codec = avcodec_find_decoder(AV_CODEC_ID_HEVC);
    if (!codec) {
        qWarning() << "未找到 HEVC 解码器";
        return;
    }

    m_codecCtx = avcodec_alloc_context3(codec);
    m_codecCtx->flags |= AV_CODEC_FLAG_LOW_DELAY;
    
    if (avcodec_open2(m_codecCtx, codec, nullptr) < 0) {
        qWarning() << "无法打开解码器";
    }

    m_frame = av_frame_alloc();
    m_socket = new QUdpSocket(this);
    m_socket->bind(QHostAddress("127.0.0.1"), 3334);
    connect(m_socket, &QUdpSocket::readyRead, this, &VideoReceiver::readData);
}

// 修复链接错误：添加析构函数的具体实现
VideoReceiver::~VideoReceiver() {
    if (m_codecCtx) avcodec_free_context(&m_codecCtx);
    if (m_frame) av_frame_free(&m_frame);
    if (m_swsCtx) {
        sws_freeContext(m_swsCtx);
        m_swsCtx = nullptr;
    }
    if (m_rgbBuffer) {
        av_free(m_rgbBuffer);
        m_rgbBuffer = nullptr;
    }
}

void VideoReceiver::readData() {
    while (m_socket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(m_socket->pendingDatagramSize());
        m_socket->readDatagram(datagram.data(), datagram.size());
        
        if (datagram.size() < 8) continue;

        uint16_t frameId = ntohs(*(uint16_t*)(datagram.data()));
        uint16_t sliceId = ntohs(*(uint16_t*)(datagram.data() + 2));
        uint32_t totalSize = ntohl(*(uint32_t*)(datagram.data() + 4));

        if (sliceId == 0) {
            m_buffer.clear();
            m_buffer.reserve(totalSize);
            m_currentFrameId = frameId;
            m_isCorrupt = false;
        } else if (frameId != m_currentFrameId) {
            m_isCorrupt = true; // 丢包处理
        }

        if (!m_isCorrupt) {
            m_buffer.append(datagram.mid(8));
            if ((uint32_t)m_buffer.size() >= totalSize) {
                decode(m_buffer);
                m_isCorrupt = true; 
            }
        }
    }
}

void VideoReceiver::decode(const QByteArray &data) {
    AVPacket pkt;
    av_init_packet(&pkt);
    pkt.data = (uint8_t*)data.data();
    pkt.size = data.size();

    if (avcodec_send_packet(m_codecCtx, &pkt) < 0) {
        avcodec_flush_buffers(m_codecCtx);
        return;
    }

    while (avcodec_receive_frame(m_codecCtx, m_frame) >= 0) {
        int w = m_frame->width;
        int h = m_frame->height;

        if (!m_swsCtx) {
            m_swsCtx = sws_getContext(w, h, m_codecCtx->pix_fmt, w, h, 
                                      AV_PIX_FMT_RGB32, SWS_FAST_BILINEAR, 
                                      nullptr, nullptr, nullptr);
            // 使用 av_image_get_buffer_size 计算缓冲区大小
            int numBytes = av_image_get_buffer_size(AV_PIX_FMT_RGB32, w, h, 1);
            m_rgbBuffer = (uint8_t*)av_malloc(numBytes);
        }

        uint8_t *dstData[4] = {m_rgbBuffer, nullptr, nullptr, nullptr};
        int dstLinesize[4] = {w * 4, 0, 0, 0};
        sws_scale(m_swsCtx, m_frame->data, m_frame->linesize, 0, h, dstData, dstLinesize);

        if (m_provider) {
            // 将解码后的 RGB 数据传给渲染器
            m_provider->updateImage(QImage(m_rgbBuffer, w, h, QImage::Format_RGB32).copy());
            emit frameReady();
        }
    }
}