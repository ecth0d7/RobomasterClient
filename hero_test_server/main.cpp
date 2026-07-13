#include <QCoreApplication>
#include <QElapsedTimer>
#include <QHostAddress>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QtEndian>
#include <QDebug>

#include "hero_custom_client.pb.h"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/opt.h>
}

#include <cmath>
#include <cstring>

namespace {

quint16 crc16(const char *data, int size)
{
    quint16 crc = 0xFFFF;
    for (int i = 0; i < size; ++i) {
        crc ^= static_cast<quint8>(data[i]);
        for (int bit = 0; bit < 8; ++bit)
            crc = (crc & 1U) ? static_cast<quint16>((crc >> 1U) ^ 0x8408U)
                             : static_cast<quint16>(crc >> 1U);
    }
    return crc;
}

void putFloat(QByteArray &p, int offset, float value)
{
    quint32 bits;
    std::memcpy(&bits, &value, sizeof(bits));
    qToLittleEndian<quint32>(bits, p.data() + offset);
}

QByteArray remainingLength(int length)
{
    QByteArray out;
    do {
        quint8 digit = static_cast<quint8>(length % 128);
        length /= 128;
        if (length) digit |= 0x80;
        out.append(static_cast<char>(digit));
    } while (length);
    return out;
}

bool decodeRemainingLength(const QByteArray &buffer, int &value, int &bytes)
{
    value = 0;
    bytes = 0;
    int multiplier = 1;
    for (int i = 1; i < buffer.size() && i <= 4; ++i) {
        const quint8 digit = static_cast<quint8>(buffer[i]);
        value += (digit & 0x7F) * multiplier;
        ++bytes;
        if (!(digit & 0x80)) return true;
        multiplier *= 128;
    }
    return false;
}

QByteArray mqttPacket(quint8 header, const QByteArray &body)
{
    QByteArray packet(1, static_cast<char>(header));
    packet += remainingLength(body.size());
    packet += body;
    return packet;
}

} // namespace

class H264TestEncoder {
public:
    H264TestEncoder()
    {
        const AVCodec *codec = avcodec_find_encoder(AV_CODEC_ID_H264);
        if (!codec) return;
        m_context = avcodec_alloc_context3(codec);
        m_context->width = 640;
        m_context->height = 360;
        m_context->time_base = AVRational{1, 5};
        m_context->framerate = AVRational{5, 1};
        m_context->pix_fmt = AV_PIX_FMT_YUV420P;
        m_context->gop_size = 10;
        m_context->max_b_frames = 0;
        m_context->bit_rate = 250000;
        av_opt_set(m_context->priv_data, "preset", "ultrafast", 0);
        av_opt_set(m_context->priv_data, "tune", "zerolatency", 0);
        av_opt_set(m_context->priv_data, "x264-params", "repeat-headers=1:annexb=1", 0);
        if (avcodec_open2(m_context, codec, nullptr) < 0) {
            avcodec_free_context(&m_context);
            return;
        }
        m_frame = av_frame_alloc();
        m_frame->format = m_context->pix_fmt;
        m_frame->width = m_context->width;
        m_frame->height = m_context->height;
        av_frame_get_buffer(m_frame, 32);
    }

    ~H264TestEncoder()
    {
        if (m_frame) av_frame_free(&m_frame);
        if (m_context) avcodec_free_context(&m_context);
    }

    bool available() const { return m_context && m_frame; }

    QList<QByteArray> nextPackets()
    {
        QList<QByteArray> packets;
        if (!available() || av_frame_make_writable(m_frame) < 0) return packets;
        const int phase = m_pts % 180;
        for (int y = 0; y < m_context->height; ++y)
            for (int x = 0; x < m_context->width; ++x)
                m_frame->data[0][y * m_frame->linesize[0] + x] = static_cast<uint8_t>((x + phase * 3) % 220 + 16);
        for (int y = 0; y < m_context->height / 2; ++y) {
            for (int x = 0; x < m_context->width / 2; ++x) {
                m_frame->data[1][y * m_frame->linesize[1] + x] = static_cast<uint8_t>(80 + (phase % 80));
                m_frame->data[2][y * m_frame->linesize[2] + x] = static_cast<uint8_t>(190 - (phase % 80));
            }
        }
        m_frame->pts = m_pts++;
        if (avcodec_send_frame(m_context, m_frame) < 0) return packets;
        AVPacket *packet = av_packet_alloc();
        while (avcodec_receive_packet(m_context, packet) == 0) {
            packets.append(QByteArray(reinterpret_cast<const char *>(packet->data), packet->size));
            av_packet_unref(packet);
        }
        av_packet_free(&packet);
        return packets;
    }

private:
    AVCodecContext *m_context = nullptr;
    AVFrame *m_frame = nullptr;
    int m_pts = 0;
};

class TestServer final : public QObject {
    Q_OBJECT
public:
    explicit TestServer(QObject *parent = nullptr) : QObject(parent)
    {
        connect(&m_server, &QTcpServer::newConnection, this, &TestServer::acceptClient);
        connect(&m_telemetryTimer, &QTimer::timeout, this, &TestServer::publishTelemetry);
        connect(&m_videoTimer, &QTimer::timeout, this, &TestServer::publishVideo);
        connect(&m_safetyTimer, &QTimer::timeout, this, &TestServer::checkHeartbeat);
        m_telemetryTimer.setInterval(100);
        m_videoTimer.setInterval(200);
        m_safetyTimer.setInterval(100);
    }

    bool listen(quint16 port)
    {
        if (!m_server.listen(QHostAddress::AnyIPv4, port)) return false;
        qInfo() << "英雄协议测试服务器监听" << m_server.serverAddress().toString() << port;
        qInfo() << "模拟状态: DEPLOY, RK45 SUCCESS, fire_allowed=true";
        qInfo() << "连接客户端后自动发布 HNU-TLM 10Hz 与 HNU-VID 5fps";
        if (!m_encoder.available())
            qWarning() << "当前 FFmpeg 没有 H.264 编码器；遥测仍可测试，视频不会发布";
        m_telemetryTimer.start();
        m_videoTimer.start();
        m_safetyTimer.start();
        return true;
    }

private slots:
    void acceptClient()
    {
        if (m_socket) m_socket->disconnectFromHost();
        m_socket = m_server.nextPendingConnection();
        m_subscribed = false;
        m_rx.clear();
        connect(m_socket, &QTcpSocket::readyRead, this, &TestServer::readClient);
        connect(m_socket, &QTcpSocket::disconnected, this, [this] {
            qInfo() << "MQTT 客户端断开";
            m_socket->deleteLater();
            m_socket = nullptr;
            m_subscribed = false;
        });
        qInfo() << "收到 TCP 客户端连接:" << m_socket->peerAddress().toString();
    }

    void readClient()
    {
        m_rx += m_socket->readAll();
        while (m_rx.size() >= 2) {
            int remaining = 0, lengthBytes = 0;
            if (!decodeRemainingLength(m_rx, remaining, lengthBytes)) return;
            const int headerBytes = 1 + lengthBytes;
            if (m_rx.size() < headerBytes + remaining) return;
            const quint8 header = static_cast<quint8>(m_rx[0]);
            const QByteArray body = m_rx.mid(headerBytes, remaining);
            m_rx.remove(0, headerBytes + remaining);
            handleMqtt(header, body);
        }
    }

private:
    void handleMqtt(quint8 header, const QByteArray &body)
    {
        switch (header >> 4) {
        case 1: // CONNECT
            m_socket->write(QByteArray::fromHex("20020000"));
            qInfo() << "MQTT CONNECT -> CONNACK success";
            break;
        case 8: { // SUBSCRIBE
            if (body.size() < 5) return;
            const quint16 packetId = qFromBigEndian<quint16>(body.constData());
            const quint16 topicLength = qFromBigEndian<quint16>(body.constData() + 2);
            if (body.size() < 4 + topicLength + 1) return;
            const QByteArray topic = body.mid(4, topicLength);
            QByteArray response;
            response.resize(3);
            qToBigEndian<quint16>(packetId, response.data());
            response[2] = 1;
            m_socket->write(mqttPacket(0x90, response));
            if (topic == "CustomByteBlock") {
                m_subscribed = true;
                qInfo() << "已订阅 CustomByteBlock";
            }
            break;
        }
        case 3: { // PUBLISH
            if (body.size() < 2) return;
            const quint16 topicLength = qFromBigEndian<quint16>(body.constData());
            if (body.size() < 2 + topicLength) return;
            int offset = 2 + topicLength;
            const QByteArray topic = body.mid(2, topicLength);
            quint16 packetId = 0;
            const int qos = (header >> 1) & 0x03;
            if (qos > 0) {
                if (body.size() < offset + 2) return;
                packetId = qFromBigEndian<quint16>(body.constData() + offset);
                offset += 2;
            }
            if (topic == "CustomControl") handleCommand(body.mid(offset));
            if (qos == 1) {
                QByteArray ack(2, '\0');
                qToBigEndian<quint16>(packetId, ack.data());
                m_socket->write(mqttPacket(0x40, ack));
            }
            break;
        }
        case 12: m_socket->write(QByteArray::fromHex("d000")); break; // PINGREQ
        case 14: m_socket->disconnectFromHost(); break;
        default: break;
        }
    }

    void handleCommand(const QByteArray &serialized)
    {
        robomaster::hero_client::CustomControl envelope;
        if (!envelope.ParseFromArray(serialized.constData(), serialized.size())) return;
        const QByteArray p(envelope.data().data(), static_cast<int>(envelope.data().size()));
        if (p.size() != 30 || qFromLittleEndian<quint16>(p.constData()) != 0xA55A
            || crc16(p.constData(), 12) != qFromLittleEndian<quint16>(p.constData() + 12)) {
            qWarning() << "拒绝非法 CustomControl: 长度/魔数/CRC 错误";
            return;
        }
        const quint16 sequence = qFromLittleEndian<quint16>(p.constData() + 2);
        const quint8 command = static_cast<quint8>(p[4]);
        const qint8 parameter = static_cast<qint8>(p[5]);
        if (m_haveCommandSequence && static_cast<qint16>(sequence - m_lastCommandSequence) <= 0) {
            qWarning() << "拒绝重复或倒退 seq:" << sequence << "last=" << m_lastCommandSequence;
            return;
        }
        const bool validStep = command == 0x01 && parameter >= -4 && parameter <= 4 && parameter != 0;
        const bool validReset = command == 0x02 && parameter == 0;
        const bool validHeartbeat = command == 0x03 && parameter == 0;
        if (!validStep && !validReset && !validHeartbeat) {
            qWarning() << "拒绝未知或参数非法的 HNU-CMD: cmd=" << command
                       << "param=" << parameter;
            return;
        }

        m_lastCommandSequence = sequence;
        m_haveCommandSequence = true;

        // 视觉侧安全计时器：任何合法 HNU-CMD（包括被 0.2s 限频拒绝的
        // trim_step）都会刷新 heartbeat。超过 2s 没有合法命令时由接收端
        // 清零 m_trim，随后发布的 HNU-TLM 会自然回传 pitch_trim_deg=0。
        m_lastHeartbeat.restart();
        m_haveHeartbeat = true;
        m_heartbeatTimedOut = false;

        if (validStep) {
            if (m_haveStep && m_lastStep.elapsed() < 200) {
                qWarning() << "trim_step 被 0.2s 限频拒绝, seq=" << sequence;
                return;
            }
            m_lastStep.restart();
            m_haveStep = true;
            m_trim = qBound(-1.0f, m_trim + parameter * 0.05f, 1.0f);
            qInfo() << "trim_step seq=" << sequence << "steps=" << parameter << "trim=" << m_trim;
        } else if (validReset) {
            m_trim = 0;
            qInfo() << "trim_reset seq=" << sequence;
        } else if (validHeartbeat) {
            qInfo() << "heartbeat seq=" << sequence;
        }
    }

    void publishEnvelope(const QByteArray &raw)
    {
        if (!m_socket || !m_subscribed) return;
        robomaster::hero_client::CustomByteBlock envelope;
        envelope.set_data(raw.constData(), raw.size());
        std::string serialized;
        envelope.SerializeToString(&serialized);
        QByteArray body(2, '\0');
        qToBigEndian<quint16>(static_cast<quint16>(qstrlen("CustomByteBlock")), body.data());
        body += "CustomByteBlock";
        body.append(serialized.data(), static_cast<int>(serialized.size()));
        m_socket->write(mqttPacket(0x30, body));
    }

    void publishTelemetry()
    {
        QByteArray p(46, '\0');
        p[0] = 0x5A; p[1] = 0x01;
        qToLittleEndian<quint16>(++m_tlmSequence, p.data() + 2);
        p[4] = 1;
        p[5] = 0x14; // DEPLOY + force_deploy
        quint16 flags = 0;
        flags |= (1U << 0) | (1U << 1) | (1U << 3) | (1U << 4) | (1U << 5) | (1U << 6);
        if (std::fabs(m_trim) > 0.001f) flags |= (1U << 7);
        if (std::fabs(m_trim) > 0.999f) flags |= (1U << 11);
        qToLittleEndian<quint16>(flags, p.data() + 6);
        const float t = m_tlmSequence * 0.03f;
        putFloat(p, 8, 18.0f + std::sin(t) * 1.5f);
        putFloat(p, 12, 1.2f + std::cos(t) * 0.2f);
        putFloat(p, 16, 15.7f);
        putFloat(p, 20, 16.0f);
        putFloat(p, 24, 0.41f);
        putFloat(p, 28, m_trim);
        putFloat(p, 32, -3.8f + m_trim);
        putFloat(p, 36, std::sin(t) * 0.15f);
        putFloat(p, 40, std::cos(t) * 0.10f);
        qToLittleEndian<quint16>(crc16(p.constData(), 44), p.data() + 44);
        publishEnvelope(p);
    }

    void publishVideo()
    {
        if (!m_subscribed) return;
        for (const QByteArray &frame : m_encoder.nextPackets()) {
            const quint16 frameId = ++m_frameId;
            quint16 slice = 0;
            for (int offset = 0; offset < frame.size(); offset += 284, ++slice) {
                const QByteArray chunk = frame.mid(offset, 284);
                QByteArray p(12, '\0');
                p[0] = 0x5A; p[1] = 0x02;
                qToLittleEndian<quint16>(++m_videoSequence, p.data() + 2);
                qToLittleEndian<quint16>(frameId, p.data() + 4);
                qToLittleEndian<quint16>(slice, p.data() + 6);
                qToLittleEndian<quint32>(static_cast<quint32>(frame.size()), p.data() + 8);
                p += chunk;
                publishEnvelope(p);
            }
        }
    }

    void checkHeartbeat()
    {
        if (!m_haveHeartbeat || m_heartbeatTimedOut || m_lastHeartbeat.elapsed() < 2000) return;

        const float previousTrim = m_trim;
        m_trim = 0.0f;
        m_heartbeatTimedOut = true;
        qWarning() << "超过 2s 未收到合法 HNU-CMD，模拟视觉已自动清零 trim; previous="
                   << previousTrim;
    }

    QTcpServer m_server;
    QTcpSocket *m_socket = nullptr;
    QByteArray m_rx;
    bool m_subscribed = false;
    QTimer m_telemetryTimer, m_videoTimer, m_safetyTimer;
    QElapsedTimer m_lastHeartbeat;
    QElapsedTimer m_lastStep;
    bool m_haveHeartbeat = false;
    bool m_heartbeatTimedOut = false;
    bool m_haveStep = false;
    bool m_haveCommandSequence = false;
    quint16 m_lastCommandSequence = 0;
    float m_trim = 0;
    quint16 m_tlmSequence = 0, m_videoSequence = 0, m_frameId = 0;
    H264TestEncoder m_encoder;
};

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    TestServer server;
    if (!server.listen(3333)) {
        qCritical() << "无法监听 0.0.0.0:3333，端口可能被占用";
        return 1;
    }
    return app.exec();
}

#include "main.moc"
