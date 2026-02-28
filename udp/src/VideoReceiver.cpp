#include "VideoReceiver.h"
#include <QDebug>
#include <arpa/inet.h>

VideoReceiver::VideoReceiver(VideoImageProvider *provider, QObject *parent)
    : QObject(parent), m_provider(provider)
{
    // 1. 初始化解码器
    const AVCodec *codec = avcodec_find_decoder(AV_CODEC_ID_HEVC);
    if (!codec) {
        qCritical() << "找不到HEVC解码器！";
        return;
    }
    m_codecCtx = avcodec_alloc_context3(codec);
    avcodec_open2(m_codecCtx, codec, nullptr);
    m_frame = av_frame_alloc();

    // 2. 初始化 UDP 监听
    m_socket = new QUdpSocket(this);
    m_socket->bind(QHostAddress("127.0.0.1"), 8888);
    connect(m_socket, &QUdpSocket::readyRead, this, &VideoReceiver::readData);

    qDebug() << "客户端已启动 (终极优化版)，监听端口 8888...";
}

VideoReceiver::~VideoReceiver()
{
    if(m_codecCtx) avcodec_free_context(&m_codecCtx);
    if(m_frame) av_frame_free(&m_frame);
    if(m_swsCtx) sws_freeContext(m_swsCtx);
    if(m_rgbBuffer) av_free(m_rgbBuffer);
}

void VideoReceiver::readData()
{
    while (m_socket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(m_socket->pendingDatagramSize());
        m_socket->readDatagram(datagram.data(), datagram.size());

        if (m_pendingSize == 0) {
            if (datagram.size() == 4) {
                m_pendingSize = *(uint32_t*)(datagram.data());
                m_pendingSize = ntohl(m_pendingSize);
                m_buffer.clear();
            }
        } else {
            m_buffer.append(datagram);
            if (m_buffer.size() >= m_pendingSize) {
                decode(m_buffer);
                m_pendingSize = 0;
            }
        }
    }
}

void VideoReceiver::decode(const QByteArray &data)
{
    AVPacket *pkt = av_packet_alloc();
    pkt->data = (uint8_t*)data.data();
    pkt->size = data.size();

    if (avcodec_send_packet(m_codecCtx, pkt) >= 0) {
        if (avcodec_receive_frame(m_codecCtx, m_frame) >= 0) {
            int w = m_frame->width;
            int h = m_frame->height;

            if (!m_swsCtx) {
                m_swsCtx = sws_getContext(w, h, m_codecCtx->pix_fmt,
                                          w, h, AV_PIX_FMT_RGB32, // 注意：这里直接转成 RGB32，QML 最喜欢这个格式
                                          SWS_FAST_BILINEAR, nullptr, nullptr, nullptr);
                int rgbSize = av_image_get_buffer_size(AV_PIX_FMT_RGB32, w, h, 1);
                m_rgbBuffer = (uint8_t*)av_malloc(rgbSize);
            }

            uint8_t *dstData[4] = {m_rgbBuffer, nullptr, nullptr, nullptr};
            int dstLinesize[4] = {w * 4, 0, 0, 0}; // RGB32 是 4 字节每像素
            sws_scale(m_swsCtx, m_frame->data, m_frame->linesize, 0, h, dstData, dstLinesize);

            // 终极优化：直接构造 QImage，不做任何文件格式压缩！
            // 这里必须用 copy()，因为 m_rgbBuffer 会被复用
            QImage img(m_rgbBuffer, w, h, w * 4, QImage::Format_RGB32);

            if (m_provider) {
                m_provider->updateImage(img.copy()); // 把图片拷贝一份传给 provider
                emit frameReady(); // 通知 QML 刷新
            }
        }
    }
    av_packet_free(&pkt);
}
