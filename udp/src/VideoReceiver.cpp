#include "VideoReceiver.h"
#include "VideoImageProvider.h"
#include "DatagramAssembler.h"
#include "DecodedFramePool.h"
#include "AnnexBCodecProbe.h"
#include <QHostAddress>
#include <QLoggingCategory>
#include <QMutex>
#include <QMutexLocker>
#include <QPointer>
#include <QQueue>
#include <QTimer>
#include <QUdpSocket>
#include <QtEndian>
#include <chrono>
#include <cmath>
#include <cstring>
#include <memory>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/error.h>
#include <libavutil/buffer.h>
#include <libavutil/pixdesc.h>
#include <libswscale/swscale.h>
}

Q_LOGGING_CATEGORY(videoLog, "robomaster.video")

namespace {
constexpr int ParseBlockBytes = 64 * 1024;
constexpr int ParameterSetBytes = 256 * 1024;
constexpr int SourceIdleMs = 3000;
constexpr int UiImageLifetimeMs = 1500;
constexpr int ReceiveBufferBytes = 256 * 1024;

qint64 monotonicMs() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

QString ffmpegError(int result) {
    char text[AV_ERROR_MAX_STRING_SIZE]{};
    av_strerror(result, text, sizeof(text));
    return QString::fromUtf8(text);
}

QString codecMismatchStatus(const QVariantMap &statistics) {
    return QStringLiteral("码流为%1；请选择对应编码或自动识别").arg(
        statistics.value("detected_codec").toString() == "h264" ? "H.264" : "HEVC/H.265");
}

bool portValue(const QVariant &value, bool allowWildcard, quint16 *port) {
    bool integral = false, numeric = false;
    const qlonglong number = value.toLongLong(&integral);
    const double real = value.toDouble(&numeric);
    if (!integral || !numeric || !std::isfinite(real) || real != double(number) ||
        number < (allowWildcard ? 0 : 1) || number > 65535)
        return false;
    *port = quint16(number);
    return true;
}

bool sameAddress(const QHostAddress &a, const QHostAddress &b) {
    return a.isEqual(b, QHostAddress::ConvertV4MappedToIPv4);
}

bool wildcardAddress(const QHostAddress &address) {
    return address == QHostAddress::Any || address == QHostAddress::AnyIPv4 ||
           address == QHostAddress::AnyIPv6;
}

struct NalInformation {
    bool valid = false;
    bool picture = false;
    bool keyframe = false;
    bool rasl = false;
    bool trailing = false;
    QList<QByteArray> parameterSets;
};

int startCode(const uint8_t *bytes, int size, int from, int *prefix) {
    for (int i = from; i + 2 < size; ++i) {
        if (bytes[i] || bytes[i + 1])
            continue;
        if (bytes[i + 2] == 1) {
            *prefix = 3;
            return i;
        }
        if (i + 3 < size && bytes[i + 2] == 0 && bytes[i + 3] == 1) {
            *prefix = 4;
            return i;
        }
    }
    return -1;
}

// Read Annex-B NAL headers only. FFmpeg's parser, not the UDP chunk header,
// establishes which complete NAL units belong to the same access unit.
NalInformation inspectAccessUnit(const uint8_t *bytes, int size, bool hevc) {
    NalInformation result;
    int prefix = 0;
    int position = startCode(bytes, size, 0, &prefix);
    while (position >= 0) {
        const int header = position + prefix;
        int nextPrefix = 0;
        const int next = startCode(bytes, size, header, &nextPrefix);
        const int end = next < 0 ? size : next;
        if (end - header < (hevc ? 2 : 1) || (bytes[header] & 0x80) ||
            (hevc && !(bytes[header + 1] & 7)))
            return {};
        result.valid = true;
        const int type = hevc ? ((bytes[header] >> 1) & 63) : (bytes[header] & 31);
        const bool parameter = hevc ? type >= 32 && type <= 34 : type == 7 || type == 8;
        if (parameter && end - header <= 64 * 1024 && result.parameterSets.size() < 32) {
            QByteArray nal("\0\0\0\1", 4);
            nal.append(reinterpret_cast<const char *>(bytes + header), end - header);
            result.parameterSets.append(std::move(nal));
        }
        if (hevc) {
            result.picture |= type <= 31;
            // BLA/IDR/CRA are random-access pictures; an ordinary I slice is not.
            result.keyframe |= type >= 16 && type <= 21;
            result.rasl |= type == 8 || type == 9;
            result.trailing |= type <= 5;
        } else {
            result.picture |= type >= 1 && type <= 5;
            result.keyframe |= type == 5;
        }
        position = next;
        prefix = nextPrefix;
    }
    return result;
}
} // namespace

class VideoWorker : public QObject {
    Q_OBJECT
public:
    explicit VideoWorker(QVariantMap configuration) : m_configuration(std::move(configuration)),
        m_encodedMode(m_configuration.value("input_mode").toString()==QLatin1String("encoded")) {}
    ~VideoWorker() override {
        av_parser_close(m_parser);
        av_packet_free(&m_packet);
        av_buffer_unref(&m_packetStorage);
        avcodec_free_context(&m_context);
        av_frame_free(&m_frame);
        av_frame_free(&m_displayFrame);
        sws_freeContext(m_scaler);
    }

    // The sole cross-thread operation: a one-slot mailbox holds the newest image.
    // Queued Qt events contain no image, so a stalled UI cannot retain old frames.
    QImage takeLatestImage(qint64 *queueAge, quint64 *epoch, quint64 *recovery) {
        QMutexLocker lock(&m_imageMutex);
        QImage image;
        image.swap(m_latestImage);
        *epoch = m_imageEpoch;
        *recovery = m_imageRecovery;
        *queueAge = image.isNull() ? -1 : qMax<qint64>(0, monotonicMs() - m_imageAt);
        m_imageNotificationPending = false;
        return image;
    }
    QPair<quint64,quint64> takeInvalidation() {
        QMutexLocker lock(&m_imageMutex);
        m_invalidationPending=false;
        return {m_invalidationEpoch,m_invalidationRecovery};
    }

    QVariantMap takeDiagnostics() {
        QMutexLocker lock(&m_imageMutex);
        m_diagnosticsNotificationPending = false;
        return m_latestDiagnostics;
    }

    // A bounded byte mailbox, not one unbounded queued closure per MQTT packet.
    bool enqueueEncoded(const QByteArray &bytes, quint64 epoch) {
        bool schedule=false, accepted=true;
        {
            QMutexLocker lock(&m_encodedMutex);
            if(!m_encodedMode || !m_acceptEncoded || bytes.size()>64*1024)return false;
            if(epoch!=m_latestQueuedEpoch) {
                m_encodedQueue.clear();m_encodedBytes=0;m_latestQueuedEpoch=epoch;
            }
            if(m_encodedQueue.size()>=256 || m_encodedBytes+bytes.size()>256*1024) {
                m_encodedQueue.clear();m_encodedBytes=0;++m_encodedDrops;accepted=false;
            }
            m_encodedQueue.enqueue({accepted?bytes:QByteArray{},epoch,monotonicMs()});
            m_encodedBytes+=accepted?bytes.size():0;
            m_maxEncodedBytes=qMax(m_maxEncodedBytes,m_encodedBytes);
            m_maxEncodedChunks=qMax(m_maxEncodedChunks,m_encodedQueue.size());
            if(!m_encodedDrainPending){m_encodedDrainPending=true;schedule=true;}
        }
        if(schedule)QMetaObject::invokeMethod(this,[this]{drainEncoded();},Qt::QueuedConnection);
        return accepted;
    }

    void start() {
        m_clock.start();
        QString error;
        if (!configure(&error)) {
            fail(error);
            return;
        }
        m_frame = av_frame_alloc();
        m_displayFrame = av_frame_alloc();
        m_packet = av_packet_alloc();
        if (!m_frame || !m_displayFrame || !m_packet) {
            fail("无法分配视频帧或数据包");
            return;
        }
        if (m_codec != "auto" && !openDecoder(m_codecId)) return;
        if(!m_encodedMode) {
        m_socket = new QUdpSocket(this);
        QAbstractSocket::BindMode mode = QUdpSocket::DefaultForPlatform;
        if (!m_multicast.isNull())
            mode = QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint;
        if (!m_socket->bind(m_bindAddress, m_port, mode)) {
            fail("UDP 绑定失败：" + m_socket->errorString());
            return;
        }
        // 接收队列也需有界；这是请求值，系统可能限幅或计入额外开销。
        m_socket->setSocketOption(QAbstractSocket::ReceiveBufferSizeSocketOption, ReceiveBufferBytes);
        if (!m_multicast.isNull() && !m_socket->joinMulticastGroup(m_multicast)) {
            const QString errorText = m_socket->errorString();
            m_socket->close();
            fail("UDP 组播加入失败：" + errorText);
            return;
        }
        m_bound = true;
        m_boundPort = m_socket->localPort();
        const QVariant receiveBuffer = m_socket->socketOption(QAbstractSocket::ReceiveBufferSizeSocketOption);
        if (receiveBuffer.isValid() && receiveBuffer.toLongLong() > 0)
            m_receiveBufferActual = receiveBuffer;
        connect(m_socket, &QUdpSocket::readyRead, this, &VideoWorker::scheduleDrain);
        }
        if (!m_encodedMode) {
            m_reassemblyDeadline = new QTimer(this);
            m_reassemblyDeadline->setSingleShot(true);
            m_reassemblyDeadline->setTimerType(Qt::PreciseTimer);
            connect(m_reassemblyDeadline, &QTimer::timeout, this, &VideoWorker::scheduleDrain);
        }
        auto *statistics = new QTimer(this);
        statistics->setInterval(1000);
        connect(statistics, &QTimer::timeout, this, [this] {
            publishDiagnostics();
        });
        statistics->start();
        publishDiagnostics();
    }

signals:
    void imageAvailable();
    void failed(const QString &error);
    void diagnosticsAvailable();
    void outputInvalidated();

private:
    bool configure(QString *error) {
        const auto input=m_configuration.value("input_mode","udp").toString();
        if(input!=QLatin1String("udp") && input!=QLatin1String("encoded")) {
            *error="未知视频输入模式";return false;
        }
        m_address = m_configuration.value("bind", "0.0.0.0").toString().trimmed();
        m_codec = m_configuration.value("codec", "hevc").toString().trimmed().toLower();
        const QString source = m_configuration.value("source_address").toString().trimmed();
        const QString group = m_configuration.value("multicast_group").toString().trimmed();
        if (!m_bindAddress.setAddress(m_address) || m_bindAddress.isMulticast())
            *error = "视频绑定地址必须是本机 IP 或通配 IP";
        else if (!portValue(m_configuration.value("port", 3334), false, &m_port))
            *error = "视频端口必须在 1–65535 之间";
        else if (m_codec != "h264" && m_codec != "hevc" && m_codec != "auto")
            *error = "视频编码仅支持 h264、hevc 或 auto";
        else if (!portValue(m_configuration.value("source_port", 0), true, &m_sourcePort))
            *error = "视频来源端口必须在 0–65535 之间（0 为自动）";
        else if (!source.isEmpty() &&
                 (!m_sourceAddress.setAddress(source) || wildcardAddress(m_sourceAddress) ||
                  m_sourceAddress.isMulticast()))
            *error = "视频来源地址必须是单播 IP；留空时自动锁定一个来源";
        else if (!group.isEmpty() &&
                 (!m_multicast.setAddress(group) || !m_multicast.isMulticast()))
            *error = "组播组必须是合法的组播 IP；单播时留空";
        else if (!m_multicast.isNull() && m_multicast.protocol() != m_bindAddress.protocol())
            *error = "组播组与绑定地址的 IPv4/IPv6 类型必须一致";
        if (!error->isEmpty())
            return false;
        m_codecId = m_codec == "auto" ? AV_CODEC_ID_NONE : m_codec == "h264" ? AV_CODEC_ID_H264 : AV_CODEC_ID_HEVC;
        return true;
    }

    bool openDecoder(AVCodecID id) {
        const AVCodec *codec = avcodec_find_decoder(id);
        if (!codec) { fail("找不到视频解码器"); return false; }
        auto *context = avcodec_alloc_context3(codec);
        auto *parser = av_parser_init(id);
        if (!context || !parser) {
            avcodec_free_context(&context); av_parser_close(parser);
            fail("无法分配视频解析器或解码器"); return false;
        }
        context->flags |= AV_CODEC_FLAG_LOW_DELAY;
        context->thread_count = 2;
        context->thread_type = FF_THREAD_SLICE;
        context->err_recognition = AV_EF_BITSTREAM | AV_EF_BUFFER | AV_EF_EXPLODE;
        context->max_pixels = 4096LL * 2160;
        const int opened = avcodec_open2(context, codec, nullptr);
        if (opened < 0) {
            avcodec_free_context(&context); av_parser_close(parser);
            fail("无法打开解码器：" + ffmpegError(opened)); return false;
        }
        const bool replacing = m_context != nullptr;
        if (replacing) {
            recover("confirmed_codec_change", false, true);
            ++m_codecChanges;
        }
        av_parser_close(m_parser); avcodec_free_context(&m_context);
        m_context = context; m_parser = parser; m_codecId = id;
        m_parserBuffered = 0; m_parserStartedAt = -1; m_streamOffset = 0;
        m_waitingKeyframe = true;
        m_parserReady = m_encodedMode && m_codec != "auto";
        m_parserPrefix.clear();
        m_parserNeedsSync = true;
        m_resyncTail.clear();
        m_colorWidth = m_colorHeight = 0;
        m_colorFormat = m_colorSpace = m_colorRange = -1;
        publishDiagnostics();
        return true;
    }

    void fail(const QString &error) {
        m_failure = error;
        m_failed = true;
        m_bound = false;
        {
            QMutexLocker lock(&m_encodedMutex);
            m_acceptEncoded=false;m_encodedQueue.clear();m_encodedBytes=0;
        }
        if (m_socket)
            m_socket->close();
        emit failed(error);
        publishDiagnostics();
    }

    void scheduleDrain() {
        if (m_failed || m_drainQueued || QThread::currentThread()->isInterruptionRequested())
            return;
        m_drainQueued = true;
        QMetaObject::invokeMethod(this, [this] {
            m_drainQueued = false;
            if (!m_failed && !QThread::currentThread()->isInterruptionRequested())
                drainDatagrams();
        }, Qt::QueuedConnection);
    }

    bool acceptsSource(const QHostAddress &address, quint16 port, bool validHeader, bool first,
                       quint16 chunkId, qint64 now) {
        if ((!m_sourceAddress.isNull() && !sameAddress(address, m_sourceAddress)) ||
            (m_sourcePort && port != m_sourcePort))
            return false;
        const bool same = m_pinned && sameAddress(address, m_pinnedAddress) && port == m_pinnedPort;
        if (m_pinned && !same && now - m_lastSourceAt < SourceIdleMs)
            return false;
        if (!m_pinned || !same) {
            if (!validHeader || !first)
                return false;
            if (m_pinned) {
                ++m_sourceChanges;
                m_assembler.reset();
                recover("source_changed_after_idle", true, true);
            }
            m_haveLastChunk = false;
            m_pinned = true;
            m_pinnedAddress = address;
            m_pinnedPort = port;
        } else if (validHeader && first && m_haveLastChunk && chunkId <= 1 &&
                   now - m_lastSourceAt >= 500 &&
                   (quint16(chunkId - m_lastChunk) == 0 ||
                    quint16(chunkId - m_lastChunk) >= 0x8000)) {
            // A counter restart from this *same pinned endpoint* is distinct from
            // changing senders. The local video producer restarts at 1 between clips.
            ++m_sequenceRestarts;
            m_assembler.reset();
            m_haveLastChunk = false;
            recover("same_source_chunk_counter_restarted", true, true);
        }
        if (validHeader)
            m_lastSourceAt = now;
        return true;
    }

    void drainEncoded() {
        if(m_failed || QThread::currentThread()->isInterruptionRequested())return;
        QElapsedTimer quantum;quantum.start();
        while(!m_failed && quantum.elapsed()<4 && !QThread::currentThread()->isInterruptionRequested()) {
            if(!m_input.isEmpty()) {
                if(monotonicMs()-m_inputAt>1500) {
                    m_input.clear();m_inputOffset=0;recover("encoded_input_expired",true,true);
                } else parseInput(quantum);
                if(!m_input.isEmpty())break;
            }
            EncodedChunk next;
            {
                QMutexLocker lock(&m_encodedMutex);
                if(m_encodedQueue.isEmpty())break;
                next=m_encodedQueue.dequeue();m_encodedBytes-=next.bytes.size();
            }
            if(next.epoch!=m_currentEncodedEpoch) {
                m_currentEncodedEpoch=next.epoch;
                recover("encoded_stream_discontinuity",true,true);
            }
            if(monotonicMs()-next.received>1500) {
                recover("encoded_input_expired",true,true);continue;
            }
            ++m_encodedChunks;m_bytes+=quint64(next.bytes.size());
            m_input=std::move(next.bytes);m_inputOffset=0;m_inputAt=next.received;m_inputProbed=false;
        }
        if(!m_failed && !m_waitingKeyframe && m_displayFrame && m_displayFrame->data[0])convertFrame();
        if(m_displayFrame)av_frame_unref(m_displayFrame);
        bool again;
        {
            QMutexLocker lock(&m_encodedMutex);
            again=!m_input.isEmpty() || !m_encodedQueue.isEmpty();
            if(!again)m_encodedDrainPending=false;
        }
        if(again && !m_failed)QMetaObject::invokeMethod(this,[this]{drainEncoded();},Qt::QueuedConnection);
    }

    void acceptChunk(QByteArray chunk, const QElapsedTimer &quantum) {
        m_lastChunk = m_assembler.lastDeliveredChunk();
        m_haveLastChunk = true;
        ++m_compressed;
        m_input = std::move(chunk);
        m_inputOffset = 0;
        m_inputProbed = false;
        m_inputAt = monotonicMs();
        parseInput(quantum);
    }

    void drainDatagrams() {
        QElapsedTimer quantum;
        quantum.start();
        int processed = 0;
        ++m_drainBatches;
        parseInput(quantum);
        while (!m_failed && m_input.isEmpty() && processed < 64 && quantum.elapsed() < 4 &&
               !QThread::currentThread()->isInterruptionRequested()) {
            auto before = m_assembler.discontinuityCount();
            auto ready = m_assembler.takeReady(m_clock.elapsed());
            if (m_assembler.discontinuityCount() != before)
                recover("fragment_reorder_deadline", true);
            if (m_failed) break;
            if (ready) {
                acceptChunk(std::move(*ready), quantum);
                continue;
            }
            if (!m_socket->hasPendingDatagrams()) break;
            ++processed;
            const auto pending = m_socket->pendingDatagramSize();
            QHostAddress sender;
            quint16 senderPort = 0;
            const qint64 count = m_socket->readDatagram(m_datagramStorage.data(), m_datagramStorage.size(),
                                                       &sender, &senderPort);
            if (count < 0) continue;
            ++m_datagrams;
            m_bytes += quint64(qMax<qint64>(0, pending));
            const QByteArray packet = QByteArray::fromRawData(m_datagramStorage.data(), int(count));
            const bool validLength = pending > 8 && pending <= DatagramAssembler::MaxDatagramBytes && count == pending;
            const auto *header = reinterpret_cast<const uchar *>(m_datagramStorage.data());
            // 新来源仍须从分片0开始；短时间内不能让另一发送端混入当前参考帧链。
            const quint32 total = validLength ? qFromBigEndian<quint32>(header + 4) : 0;
            const bool validHeader = validLength && total && total <= DatagramAssembler::MaxFrameBytes &&
                                     quint32(count - 8) <= total;
            const bool first = validLength && qFromBigEndian<quint16>(header + 2) == 0;
            const quint16 chunkId = validLength ? qFromBigEndian<quint16>(header) : 0;
            const qint64 now = m_clock.elapsed();
            if (!acceptsSource(sender, senderPort, validHeader, first, chunkId, now)) {
                ++m_filtered;
                continue;
            }
            before = m_assembler.discontinuityCount();
            if (!validHeader) ++m_invalid;
            auto chunk = m_assembler.push(validHeader ? packet : QByteArray{}, now);
            if (m_assembler.discontinuityCount() != before)
                recover("transport_gap_or_invalid_fragment", true);
            if (m_failed) break;
            if (chunk) acceptChunk(std::move(*chunk), quantum);
        }
        if (!m_failed && !m_waitingKeyframe && m_displayFrame && m_displayFrame->data[0])
            convertFrame();
        av_frame_unref(m_displayFrame);
        m_maxBatchDatagrams = qMax(m_maxBatchDatagrams, processed);
        const auto deadline = m_assembler.nextDeadlineMs();
        if (deadline >= 0)
            m_reassemblyDeadline->start(int(qMax<qint64>(1, deadline - m_clock.elapsed())));
        else
            m_reassemblyDeadline->stop();
        if (!m_failed && (!m_input.isEmpty() || m_socket->hasPendingDatagrams())) {
            ++m_drainYields;
            scheduleDrain();
        }
    }

    void parseInput(const QElapsedTimer &quantum) {
        if ((m_codec == "auto" || !m_encodedMode) && !m_input.isEmpty() && !m_inputProbed) {
            m_inputProbed = true;
            const auto active = !m_parserReady ? AnnexBCodecProbe::Codec::Unknown :
                m_codecId == AV_CODEC_ID_H264 ? AnnexBCodecProbe::Codec::H264 :
                m_codecId == AV_CODEC_ID_HEVC ? AnnexBCodecProbe::Codec::Hevc : AnnexBCodecProbe::Codec::Unknown;
            auto detected = m_codecProbe.observe(m_input, active);
            if (detected) {
                const auto codec = detected->codec == AnnexBCodecProbe::Codec::H264 ? AV_CODEC_ID_H264 : AV_CODEC_ID_HEVC;
                m_detectedCodec = codec == AV_CODEC_ID_H264 ? "h264" : "hevc";
                if (m_codec != "auto" && codec != m_codecId) {
                    if (!m_codecMismatch) {
                        m_codecMismatch = true;
                        recover("configured_codec_mismatch", true, true);
                        publishDiagnostics();
                    }
                    m_input.clear(); m_inputOffset = 0;
                    return;
                }
                if ((m_codecId != codec || !m_context) && !openDecoder(codec)) return;
                const bool resolvedMismatch = m_codecMismatch;
                m_codecMismatch = false;
                m_parserReady = true;
                if (resolvedMismatch) publishDiagnostics();
                m_input = std::move(detected->bootstrap); m_inputOffset = 0;
            }
            // 从GOP中间加入时先等参数集，避免把无法解释的切片送进解析器。
            if (!m_parser || !m_parserReady) { m_input.clear(); m_inputOffset = 0; return; }
        }
        if (m_parserNeedsSync && !m_input.isEmpty() && m_inputOffset == 0) {
            m_input.prepend(m_resyncTail);
            m_resyncTail.clear();
            int prefix = 0;
            const int position = startCode(reinterpret_cast<const uint8_t *>(m_input.constData()),
                                           int(m_input.size()), 0, &prefix);
            if (position < 0) {
                m_resyncTail = m_input.right(3);
                m_input.clear();
                return;
            }
            // 传输块未必从NAL边界开始。丢块后的尾部不能接在缓存PPS之后。
            m_input.remove(0, position);
            m_parserNeedsSync = false;
        }
        if (!m_parserPrefix.isEmpty() && !m_input.isEmpty() && m_inputOffset == 0) {
            m_input.prepend(m_parserPrefix);
            m_parserPrefix.clear();
        }
        while (!m_failed && m_inputOffset < m_input.size() && quantum.elapsed() < 4 &&
               !QThread::currentThread()->isInterruptionRequested()) {
            const int available = int(DatagramAssembler::MaxFrameBytes) - m_parserBuffered;
            if (available <= 0) {
                ++m_parserOversized;
                recover("access_unit_exceeds_4MiB", true);
                m_input.clear();
                m_inputOffset = 0;
                break;
            }
            const int length = qMin(qMin(ParseBlockBytes, available),
                                    int(m_input.size() - m_inputOffset));
            // Each parser input has its own zero padding, including across event-loop
            // quanta. Do not set PARSER_FLAG_COMPLETE_FRAMES for arbitrary raw chunks.
            m_parseBlock.resize(length + AV_INPUT_BUFFER_PADDING_SIZE);
            memcpy(m_parseBlock.data(), m_input.constData() + m_inputOffset, size_t(length));
            memset(m_parseBlock.data() + length, 0, AV_INPUT_BUFFER_PADDING_SIZE);
            int offset = 0;
            while (offset < length && quantum.elapsed() < 4) {
                uint8_t *unit = nullptr;
                int unitSize = 0;
                if (m_parserBuffered == 0)
                    m_parserStartedAt = monotonicMs();
                ++m_parserCalls;
                const int used = av_parser_parse2(
                    m_parser, m_context, &unit, &unitSize,
                    reinterpret_cast<const uint8_t *>(m_parseBlock.constData()) + offset, length - offset,
                    AV_NOPTS_VALUE, AV_NOPTS_VALUE, m_streamOffset);
                if (used < 0 || used > length - offset || unitSize < 0 ||
                    unitSize > int(DatagramAssembler::MaxFrameBytes) || (unitSize && !unit) ||
                    (!used && !unitSize)) {
                    ++m_parserErrors;
                    recover("access_unit_parser_error", true);
                    m_input.clear();
                    m_inputOffset = 0;
                    return;
                }
                offset += used;
                m_inputOffset += used;
                m_streamOffset += used;
                m_parserBuffered += used;
                if (unitSize) {
                    ++m_accessUnits;
                    m_lastParserAge = qMax<qint64>(0, monotonicMs() - m_parserStartedAt);
                    m_maxParserAge = qMax(m_maxParserAge, m_lastParserAge);
                    m_parserBuffered = qMax(0, m_parserBuffered - unitSize);
                    processAccessUnit(unit, unitSize);
                    if (m_parserBuffered)
                        m_parserStartedAt = monotonicMs();
                }
                if (m_failed)
                    return;
            }
        }
        if (m_inputOffset >= m_input.size()) {
            m_input.clear();
            m_inputOffset = 0;
        }
    }

    void rememberParameterSets(const QList<QByteArray> &sets) {
        if (!sets.isEmpty())
            m_parametersPending = true;
        for (const auto &set : sets) {
            m_parameterSets.removeAll(set);
            m_parameterSets.append(set);
        }
        int total = 0;
        for (const auto &set : m_parameterSets)
            total += int(set.size());
        while (total > ParameterSetBytes || m_parameterSets.size() > 32)
            total -= int(m_parameterSets.takeFirst().size());
        m_parameterBytes = total;
    }

    void processAccessUnit(const uint8_t *unit, int size) {
        const auto information = inspectAccessUnit(unit, size, m_codecId == AV_CODEC_ID_HEVC);
        if (!information.valid) {
            ++m_parserErrors;
            recover("invalid_annex_b_access_unit", false);
            return;
        }
        rememberParameterSets(information.parameterSets);
        if (!information.picture) {
            ++m_parameterOnly;
            return;
        }
        if (m_waitingKeyframe && !information.keyframe) {
            ++m_recoveryDropped;
            return;
        }
        if (m_discardRasl && information.rasl) {
            ++m_leadingDropped;
            return;
        }
        if (information.trailing)
            m_discardRasl = false;
        const bool resuming = m_waitingKeyframe;
        // Cache complete parameter NALs and replay them before IRAP/IDR recovery.
        // Old versions precede newer versions, so the decoder resolves their IDs.
        // Standalone parameter-set access units may precede a non-key picture.
        // Deliver their cached NALs with the next real picture rather than asking
        // avcodec_send_packet to decode a packet containing no picture at all.
        const bool prependParameters = resuming || m_parametersPending;
        const int prefixBytes = prependParameters ? m_parameterBytes : 0;
        if (size > int(DatagramAssembler::MaxFrameBytes) - prefixBytes) {
            ++m_parserOversized;
            recover("access_unit_and_parameter_sets_exceed_4MiB", false);
            return;
        }
        const int payloadBytes = prefixBytes + size;
        const int required = payloadBytes + AV_INPUT_BUFFER_PADDING_SIZE;
        if (!m_packetStorage || size_t(m_packetStorage->size) < size_t(required) ||
            !av_buffer_is_writable(m_packetStorage)) {
            av_buffer_unref(&m_packetStorage);
            const int rounded = qMin(int(DatagramAssembler::MaxFrameBytes) + AV_INPUT_BUFFER_PADDING_SIZE,
                                     (required + 65535) & ~65535);
            m_packetStorage = av_buffer_alloc(size_t(rounded));
            if (m_packetStorage) ++m_packetAllocations;
        } else {
            ++m_packetReuses;
        }
        av_packet_unref(m_packet);
        if (m_packetStorage) m_packet->buf = av_buffer_ref(m_packetStorage);
        if (!m_packetStorage || !m_packet->buf) {
            ++m_allocFailed;
            recover("packet_allocation_failed", false);
            return;
        }
        m_packet->data = m_packetStorage->data;
        m_packet->size = payloadBytes;
        // 解码器可能继续持有AVBuffer引用。仅独占时复用，并为本次真实长度补零。
        memset(m_packet->data + payloadBytes, 0, AV_INPUT_BUFFER_PADDING_SIZE);
        int offset = 0;
        if (prependParameters) {
            for (const auto &set : m_parameterSets) {
                memcpy(m_packet->data + offset, set.constData(), size_t(set.size()));
                offset += int(set.size());
            }
        }
        if (resuming) {
            m_waitingKeyframe = false;
            m_discardRasl = m_codecId == AV_CODEC_ID_HEVC;
        }
        memcpy(m_packet->data + offset, unit, size_t(size));
        m_packet->flags = information.keyframe ? AV_PKT_FLAG_KEY : 0;
        bool received = true;
        int result = avcodec_send_packet(m_context, m_packet);
        if (result == AVERROR(EAGAIN)) {
            received = receiveFrames();
            if (received)
                result = avcodec_send_packet(m_context, m_packet);
        }
        av_packet_unref(m_packet);
        if (!received)
            return;
        if (result < 0) {
            ++m_errors;
            m_lastDecoderError = ffmpegError(result);
            recover("decoder_rejected_access_unit", false);
            return;
        }
        m_parametersPending = false;
        if (receiveFrames() && resuming)
            ++m_recovered;
    }

    bool receiveFrames() {
        int result = 0;
        while ((result = avcodec_receive_frame(m_context, m_frame)) >= 0) {
            if ((m_frame->flags & AV_FRAME_FLAG_CORRUPT) || m_frame->decode_error_flags) {
                ++m_corrupt;
                av_frame_unref(m_frame);
                recover("corrupt_or_missing_reference_frame", false);
                return false;
            }
            ++m_decoded;
            // Decode every reference picture; only rendering/conversion is coalesced.
            if (m_displayFrame->data[0])
                ++m_skipped;
            av_frame_unref(m_displayFrame);
            av_frame_move_ref(m_displayFrame, m_frame);
        }
        if (result != AVERROR(EAGAIN) && result != AVERROR_EOF) {
            ++m_errors;
            m_lastDecoderError = ffmpegError(result);
            recover("decoder_receive_error", false);
            return false;
        }
        return true;
    }

    void recover(const QString &reason, bool resetParser, bool clearParameters = false) {
        ++m_recoveries;
        m_lastRecoveryReason = reason;
        // Flush at a real gap/corruption, never as a 'latest compressed packet' policy.
        if (m_context && (!m_waitingKeyframe || resetParser || clearParameters))
            avcodec_flush_buffers(m_context);
        m_waitingKeyframe = true;
        m_discardRasl = false;
        if (m_displayFrame)
            av_frame_unref(m_displayFrame);
        {
            QMutexLocker lock(&m_imageMutex);
            m_latestImage = {};
        }
        m_codecProbe.reset();
        if (clearParameters) {
            m_parameterSets.clear();
            m_parameterBytes = 0;
            m_parametersPending = false;
        }
        if (resetParser && m_codecId != AV_CODEC_ID_NONE) {
            av_parser_close(m_parser);
            m_parser = av_parser_init(m_codecId);
            m_parserBuffered = 0;
            m_parserStartedAt = -1;
            m_parserPrefix.clear();
            m_resyncTail.clear();
            m_parserNeedsSync = true;
            for (const auto &parameters : m_parameterSets) m_parserPrefix.append(parameters);
            m_parserReady = m_encodedMode || !m_parserPrefix.isEmpty();
            if (!m_parser) {
                ++m_allocFailed;
                fail("无法重新分配视频解析器");
            }
        }
        {
            bool notify;
            {
                QMutexLocker lock(&m_imageMutex);
                m_invalidationEpoch=m_currentEncodedEpoch;
                m_invalidationRecovery=++m_recoveryRevision;
                notify=!m_invalidationPending;m_invalidationPending=true;
            }
            if(notify)emit outputInvalidated();
        }
    }

    void convertFrame() {
        const int width = m_displayFrame->width, height = m_displayFrame->height;
        if (width <= 0 || height <= 0 || width > 8192 || height > 8192 ||
            qint64(width) * height > 4096LL * 2160) {
            ++m_pixelRejected;
            return;
        }
        m_scaler = sws_getCachedContext(m_scaler, width, height, AVPixelFormat(m_displayFrame->format),
                                      width, height, AV_PIX_FMT_BGRA, SWS_FAST_BILINEAR, nullptr,
                                      nullptr, nullptr);
        if (!m_scaler) {
            ++m_allocFailed;
            return;
        }
        const bool fullRange = m_displayFrame->color_range == AVCOL_RANGE_JPEG ||
            m_displayFrame->format == AV_PIX_FMT_YUVJ420P || m_displayFrame->format == AV_PIX_FMT_YUVJ422P ||
            m_displayFrame->format == AV_PIX_FMT_YUVJ444P || m_displayFrame->format == AV_PIX_FMT_YUVJ440P;
        const int colorSpace = m_displayFrame->colorspace;
        if (width != m_colorWidth || height != m_colorHeight || m_displayFrame->format != m_colorFormat ||
            colorSpace != m_colorSpace || int(fullRange) != m_colorRange) {
            int coefficients = SWS_CS_DEFAULT;
            switch (colorSpace) {
            case AVCOL_SPC_BT709: coefficients = SWS_CS_ITU709; break;
            case AVCOL_SPC_FCC: coefficients = SWS_CS_FCC; break;
            case AVCOL_SPC_BT470BG:
            case AVCOL_SPC_SMPTE170M: coefficients = SWS_CS_ITU601; break;
            case AVCOL_SPC_SMPTE240M: coefficients = SWS_CS_SMPTE240M; break;
            case AVCOL_SPC_BT2020_NCL:
            case AVCOL_SPC_BT2020_CL: coefficients = SWS_CS_BT2020; break;
            default: break;
            }
            const auto *table = sws_getCoefficients(coefficients);
            if (sws_setColorspaceDetails(m_scaler, table, fullRange, table, 1, 0, 1 << 16, 1 << 16) < 0) {
                ++m_conversionErrors;
                return;
            }
            m_colorWidth = width; m_colorHeight = height; m_colorFormat = m_displayFrame->format;
            m_colorSpace = colorSpace; m_colorRange = fullRange;
        }
        QElapsedTimer conversion;
        conversion.start();
        // 保留FFmpeg的64字节行对齐。空闲帧可复用，仍被渲染器引用的像素绝不覆盖。
        const auto pool = m_outputPool;
        const auto recycle = [pool](AVFrame *frame) { pool->release(frame); };
        std::unique_ptr<AVFrame, decltype(recycle)> output(pool->acquire(width, height), recycle);
        if (!output) {
            ++m_allocFailed;
            return;
        }
        if (sws_scale(m_scaler, m_displayFrame->data, m_displayFrame->linesize, 0, height, output->data,
                      output->linesize) != height) {
            ++m_conversionErrors;
            return;
        }
        struct ImageLease {
            std::shared_ptr<DecodedFramePool> pool;
            AVFrame *frame;
            ImageLease(std::shared_ptr<DecodedFramePool> owner, AVFrame *storage)
                : pool(std::move(owner)), frame(storage) {}
            ImageLease(const ImageLease &) = delete;
            ~ImageLease() { pool->release(frame); }
        };
        auto lease = std::make_unique<ImageLease>(pool, output.release());
        QImage image(static_cast<const uchar *>(lease->frame->data[0]), width, height, lease->frame->linesize[0],
            QImage::Format_ARGB32, [](void *opaque) { delete static_cast<ImageLease *>(opaque); }, lease.get());
        if (image.isNull()) {
            ++m_allocFailed;
            return;
        }
        lease.release();
        m_lastConversionNs = conversion.nsecsElapsed();
        m_totalConversionNs += m_lastConversionNs;
        m_maxConversionNs = qMax(m_maxConversionNs, m_lastConversionNs);
        bool notify = false;
        {
            QMutexLocker lock(&m_imageMutex);
            if (!m_latestImage.isNull())
                ++m_coalesced;
            m_latestImage = std::move(image);
            m_imageEpoch=m_currentEncodedEpoch;
            m_imageRecovery=m_recoveryRevision;
            m_imageAt = monotonicMs();
            notify = !m_imageNotificationPending;
            m_imageNotificationPending = true;
        }
        ++m_converted;
        if (notify)
            emit imageAvailable();
    }

    void publishDiagnostics() {
        qsizetype encodedBytes=0,maxEncodedBytes=0,maxEncodedChunks=0;quint64 encodedDrops=0;
        {
            QMutexLocker lock(&m_encodedMutex);
            encodedBytes=m_encodedBytes;encodedDrops=m_encodedDrops;
            maxEncodedBytes=m_maxEncodedBytes;maxEncodedChunks=m_maxEncodedChunks;
        }
        int pendingImage = 0;
        qint64 imageAge = -1;
        {
            QMutexLocker lock(&m_imageMutex);
            pendingImage = !m_latestImage.isNull();
            if (pendingImage)
                imageAge = qMax<qint64>(0, monotonicMs() - m_imageAt);
        }
        QVariantMap statistics{
            {"input_mode",m_encodedMode?"encoded":"udp"},
            {"encoded_chunks",m_encodedChunks},{"pending_encoded_bytes",encodedBytes},
            {"encoded_queue_drops",encodedDrops},
            {"maximum_encoded_queue_bytes",maxEncodedBytes},{"maximum_encoded_queue_chunks",maxEncodedChunks},
            {"bound", m_bound}, {"bind_address", m_address}, {"port", m_boundPort},
            {"socket_receive_buffer_requested_bytes", m_encodedMode ? QVariant{} : QVariant(ReceiveBufferBytes)},
            {"socket_receive_buffer_actual_bytes", m_bound ? m_receiveBufferActual : QVariant{}},
            {"codec", m_codec}, {"source_address", m_sourceAddress.toString()},
            {"source_port", m_sourcePort}, {"multicast_group", m_multicast.toString()},
            {"source_pinned", m_pinned},
            {"pinned_source_address", m_pinned ? m_pinnedAddress.toString() : QString{}},
            {"pinned_source_port", m_pinned ? QVariant(m_pinnedPort) : QVariant{}},
            {"source_idle_ms", m_pinned ? QVariant(m_clock.elapsed() - m_lastSourceAt) : QVariant{}},
            {"source_repin_idle_ms", SourceIdleMs}, {"filtered_datagrams", m_filtered},
            {"source_changes", m_sourceChanges},
            {"same_source_sequence_restarts", m_sequenceRestarts},
            {"last_transport_chunk_id", m_haveLastChunk ? QVariant(m_lastChunk) : QVariant{}},
            {"datagrams", m_datagrams}, {"bytes", m_bytes}, {"invalid_datagrams", m_invalid},
            {"compressed_frames", m_compressed}, {"transport_chunks", m_compressed},
            {"configured_codec", m_codec},
            {"active_codec", m_codecId == AV_CODEC_ID_NONE ? "pending" : m_codecId == AV_CODEC_ID_H264 ? "h264" : "hevc"},
            {"codec_changes", m_codecChanges}, {"codec_probe_retained_bytes", m_codecProbe.retainedBytes()},
            {"awaiting_parameter_sets", !m_parserReady}, {"codec_mismatch", m_codecMismatch},
            {"detected_codec", m_detectedCodec},
            {"transport_discontinuities", m_assembler.discontinuityCount()},
            {"reordered_fragments", m_assembler.reorderedFragments()},
            {"duplicate_fragments", m_assembler.duplicateFragments()},
            {"reorder_wait_ms", DatagramAssembler::ReorderWaitMs},
            {"parser_calls", m_parserCalls}, {"access_units", m_accessUnits},
            {"packet_buffer_allocations", m_packetAllocations}, {"packet_buffer_reuses", m_packetReuses},
            {"packet_buffer_bytes", m_packetStorage ? qulonglong(m_packetStorage->size) : qulonglong(0)},
            {"parser_buffered_bytes", m_parserBuffered}, {"parser_errors", m_parserErrors},
            {"oversized_access_units", m_parserOversized}, {"parameter_set_bytes", m_parameterBytes},
            {"non_picture_access_units", m_parameterOnly}, {"waiting_keyframe", m_waitingKeyframe},
            {"recovery_events", m_recoveries}, {"keyframe_recoveries", m_recovered},
            {"recovery_dropped_access_units", m_recoveryDropped},
            {"leading_rasl_dropped", m_leadingDropped}, {"last_recovery_reason", m_lastRecoveryReason},
            {"decoded_frames", m_decoded}, {"corrupt_frames", m_corrupt},
            {"converted_frames", m_converted}, {"ui_skipped_frames", m_skipped + m_coalesced},
            {"coalesced_ui_frames", m_coalesced}, {"decoder_errors", m_errors},
            {"last_decoder_error", m_lastDecoderError}, {"pixel_rejections", m_pixelRejected},
            {"conversion_errors", m_conversionErrors}, {"allocation_failures", m_allocFailed},
            {"drain_batches", m_drainBatches}, {"drain_yields", m_drainYields},
            {"maximum_batch_datagrams", m_maxBatchDatagrams},
            {"pending_input_bytes", m_input.size() - m_inputOffset},
            {"pending_input_age_ms", m_input.isEmpty() ? QVariant{} : QVariant(monotonicMs() - m_inputAt)},
            {"last_parser_assembly_age_ms", m_lastParserAge < 0 ? QVariant{} : QVariant(m_lastParserAge)},
            {"maximum_parser_assembly_age_ms", m_maxParserAge},
            {"pending_images", pendingImage}, {"pending_image_age_ms", imageAge < 0 ? QVariant{} : QVariant(imageAge)},
            {"frame_threading", false}, {"decoder_has_b_frames", m_context ? m_context->has_b_frames : 0},
            {"decoder_state", m_failed ? "failed" : m_waitingKeyframe ? "waiting_keyframe" : "decoding"},
            {"error", m_failure}};
        const auto poolStatistics = m_outputPool->diagnostics();
        for (auto it = poolStatistics.cbegin(); it != poolStatistics.cend(); ++it)
            statistics.insert(it.key(), it.value());
        statistics.insert("conversion_us_last", m_lastConversionNs / 1000.0);
        statistics.insert("conversion_us_average", m_converted ? m_totalConversionNs / (1000.0 * m_converted) : 0.0);
        statistics.insert("conversion_us_maximum", m_maxConversionNs / 1000.0);
        statistics.insert("decoded_width", m_colorWidth);
        statistics.insert("decoded_height", m_colorHeight);
        statistics.insert("source_pixel_format", m_colorFormat >= 0 ? QString::fromLatin1(av_get_pix_fmt_name(AVPixelFormat(m_colorFormat))) : QString{});
        statistics.insert("source_color_space", m_colorSpace);
        statistics.insert("source_full_range", m_colorRange == 1);
        bool notify = false;
        {
            QMutexLocker lock(&m_imageMutex);
            m_latestDiagnostics = std::move(statistics);
            notify = !m_diagnosticsNotificationPending;
            m_diagnosticsNotificationPending = true;
        }
        if (notify)
            emit diagnosticsAvailable();
    }

    QVariantMap m_configuration;
    struct EncodedChunk {QByteArray bytes;quint64 epoch=0;qint64 received=0;};
    QMutex m_encodedMutex;
    QQueue<EncodedChunk> m_encodedQueue;
    qsizetype m_encodedBytes=0;
    qsizetype m_maxEncodedBytes=0,m_maxEncodedChunks=0;
    quint64 m_encodedDrops=0,m_encodedChunks=0,m_currentEncodedEpoch=0,m_imageEpoch=0;
    quint64 m_latestQueuedEpoch=0;
    quint64 m_recoveryRevision=0,m_imageRecovery=0,m_invalidationEpoch=0,m_invalidationRecovery=0;
    bool m_invalidationPending=false;
    const bool m_encodedMode;
    bool m_encodedDrainPending=false,m_acceptEncoded=true;
    QMutex m_imageMutex;
    QImage m_latestImage;
    QVariantMap m_latestDiagnostics;
    QVariant m_receiveBufferActual;
    qint64 m_imageAt = -1;
    bool m_imageNotificationPending = false;
    bool m_diagnosticsNotificationPending = false;
    bool m_bound = false, m_failed = false, m_drainQueued = false;
    bool m_pinned = false, m_waitingKeyframe = true, m_discardRasl = false;
    bool m_haveLastChunk = false, m_parametersPending = false;
    quint16 m_lastChunk = 0;
    quint16 m_port = 0, m_boundPort = 0, m_sourcePort = 0, m_pinnedPort = 0;
    QHostAddress m_bindAddress, m_sourceAddress, m_multicast, m_pinnedAddress;
    QString m_address, m_codec, m_failure, m_lastRecoveryReason, m_lastDecoderError;
    AVCodecID m_codecId = AV_CODEC_ID_HEVC;
    qint64 m_lastSourceAt = -1, m_streamOffset = 0, m_parserStartedAt = -1, m_inputAt = -1;
    qint64 m_lastParserAge = -1, m_maxParserAge = 0;
    quint64 m_datagrams = 0, m_bytes = 0, m_invalid = 0, m_filtered = 0, m_compressed = 0;
    quint64 m_sourceChanges = 0, m_sequenceRestarts = 0, m_parserCalls = 0,
            m_accessUnits = 0;
    quint64 m_parserErrors = 0, m_parserOversized = 0, m_parameterOnly = 0;
    quint64 m_recoveries = 0, m_recovered = 0, m_recoveryDropped = 0, m_leadingDropped = 0;
    quint64 m_decoded = 0, m_corrupt = 0, m_converted = 0, m_skipped = 0, m_coalesced = 0;
    quint64 m_errors = 0, m_pixelRejected = 0, m_allocFailed = 0, m_conversionErrors = 0;
    quint64 m_drainBatches = 0, m_drainYields = 0;
    int m_maxBatchDatagrams = 0, m_parserBuffered = 0, m_parameterBytes = 0;
    qsizetype m_inputOffset = 0;
    QByteArray m_input, m_parseBlock, m_parserPrefix, m_resyncTail;
    bool m_parserNeedsSync = true;
    bool m_parserReady = false, m_codecMismatch = false;
    QString m_detectedCodec;
    AnnexBCodecProbe m_codecProbe;
    bool m_inputProbed = false;
    quint64 m_codecChanges = 0;
    std::shared_ptr<DecodedFramePool> m_outputPool = std::make_shared<DecodedFramePool>();
    int m_colorWidth = 0, m_colorHeight = 0, m_colorFormat = -1, m_colorSpace = -1, m_colorRange = -1;
    qint64 m_lastConversionNs = 0, m_maxConversionNs = 0;
    quint64 m_totalConversionNs = 0;
    QList<QByteArray> m_parameterSets;
    QUdpSocket *m_socket = nullptr;
    QTimer *m_reassemblyDeadline = nullptr;
    std::array<char, DatagramAssembler::MaxDatagramBytes> m_datagramStorage;
    QElapsedTimer m_clock;
    DatagramAssembler m_assembler;
    AVCodecContext *m_context = nullptr;
    AVCodecParserContext *m_parser = nullptr;
    AVFrame *m_frame = nullptr, *m_displayFrame = nullptr;
    AVPacket *m_packet = nullptr;
    AVBufferRef *m_packetStorage = nullptr;
    quint64 m_packetAllocations = 0, m_packetReuses = 0;
    SwsContext *m_scaler = nullptr;
};

VideoReceiver::VideoReceiver(VideoImageProvider *provider, const QString &address, quint16 port,
                             const QString &codec, QObject *parent)
    : VideoReceiver(provider, {{"bind", address}, {"port", port}, {"codec", codec}}, parent) {}

VideoReceiver::VideoReceiver(VideoImageProvider *provider, const QVariantMap &configuration,
                             QObject *parent)
    : VideoEndpoint(parent), m_worker(new VideoWorker(configuration)), m_provider(provider) {
    m_encodedMode=configuration.value("input_mode").toString()==QLatin1String("encoded");
    m_clock.start();
    m_fpsClock.start();
    m_worker->moveToThread(&m_thread);
    connect(&m_thread, &QThread::started, m_worker, &VideoWorker::start);
    connect(&m_thread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(m_worker, &VideoWorker::imageAvailable, this, [this] {
        qint64 age = -1;
        quint64 epoch=0,recovery=0;
        const QImage image = m_worker->takeLatestImage(&age,&epoch,&recovery);
        if (image.isNull() || (m_encodedMode && epoch!=m_encodedEpoch))
            return;
        m_lastQueueAge = age;
        m_maxQueueAge = qMax(m_maxQueueAge, age);
        // A stalled GUI must not turn the last buffered image of a stopped
        // stream into a fresh deployment frame when its event loop resumes.
        if (age > UiImageLifetimeMs) {
            ++m_expiredUiFrames;
            return;
        }
        m_lastImageRecovery=recovery;
        if (!m_presentedSize.isEmpty() && m_presentedSize != image.size()) {
            // 同一编码也可更新SPS并切换分辨率；旧视觉框必须先退出旧像素坐标系。
            m_lastFrame = -1;
            if (m_provider) m_provider->updateImage({});
            QPointer<VideoReceiver> alive(this);
            emit streamReset();
            if (!alive) return;
        }
        m_presentedSize = image.size();
        if (m_provider)
            m_provider->updateImage(image);
        const bool changed = m_status != "正常";
        m_lastFrame = m_clock.elapsed() - age;
        ++m_frames;
        m_status = "正常";
        // A consumer can synchronously destroy/replace this receiver on notification.
        QPointer<VideoReceiver> alive(this);
        emit frameDecoded(image);
        if (!alive)
            return;
        if (changed)
            emit statisticsChanged();
        if (!alive)
            return;
        emit frameReady();
    }, Qt::QueuedConnection);
    connect(m_worker, &VideoWorker::failed, this, [this](const QString &error) {
        m_status = error;
        qCWarning(videoLog) << error;
        emit statisticsChanged();
    }, Qt::QueuedConnection);
    connect(m_worker, &VideoWorker::diagnosticsAvailable, this, [this] {
        const QVariantMap statistics = m_worker->takeDiagnostics();
        m_diagnostics = statistics;
        if (statistics.value("codec_mismatch").toBool()) {
            m_status = codecMismatchStatus(statistics);
        } else if ((m_encodedMode || statistics.value("bound").toBool()) && statistics.value("waiting_keyframe").toBool()) {
            m_status = statistics.value("awaiting_parameter_sets").toBool() ? "等待H.264/HEVC参数集" :
                statistics.value("transport_chunks").toULongLong() ? "等待关键帧" : "等待码流";
        }
        emit statisticsChanged();
    }, Qt::QueuedConnection);
    connect(m_worker,&VideoWorker::outputInvalidated,this,[this]{
        const auto invalidation=m_worker->takeInvalidation();
        if((m_encodedMode && invalidation.first!=m_encodedEpoch) || invalidation.second<=m_lastImageRecovery)return;
        m_lastFrame=-1;
        m_status=m_diagnostics.value("codec_mismatch").toBool() ? codecMismatchStatus(m_diagnostics) : QStringLiteral("等待关键帧");
        m_presentedSize={};
        if(m_provider)m_provider->updateImage({});
        QPointer<VideoReceiver> alive(this);emit streamReset();
        if(alive)emit statisticsChanged();
    },Qt::QueuedConnection);
    auto *timer = new QTimer(this);
    timer->setInterval(1000);
    connect(timer, &QTimer::timeout, this, [this] {
        m_fps = 1000.0 * m_frames / qMax<qint64>(1, m_fpsClock.restart());
        m_frames = 0;
        if (m_lastFrame >= 0 && m_clock.elapsed() - m_lastFrame > 2000 &&
            m_diagnostics.value("decoder_state").toString() != "failed")
            m_status = m_diagnostics.value("waiting_keyframe").toBool() ? "等待关键帧（画面未更新）" : "画面未更新";
        emit statisticsChanged();
    });
    timer->start();
    m_thread.start();
}

VideoReceiver::~VideoReceiver() {
    m_thread.requestInterruption();
    m_thread.quit();
    m_thread.wait();
}

bool VideoReceiver::submitEncoded(const QByteArray &bytes,bool discontinuity) {
    if(!m_encodedMode || QThread::currentThread()!=thread())return false;
    const auto invalidate=[this]{
        ++m_encodedEpoch;m_lastFrame=-1;m_frames=0;m_fps=0;m_status="等待关键帧";m_presentedSize={};
        if(m_provider)m_provider->updateImage({});
        emit streamReset();
    };
    QPointer<VideoReceiver> alive(this);
    if(discontinuity){invalidate();if(!alive)return false;}
    if(bytes.size()<=64*1024 && m_worker->enqueueEncoded(bytes,m_encodedEpoch))return true;
    invalidate();if(alive)m_worker->enqueueEncoded({},m_encodedEpoch);
    return false;
}

QVariantMap VideoReceiver::configurationCapabilities() const {
    return {{"bind", true}, {"port", true}, {"codec", true}, {"source_filter", true},
            {"multicast", true}, {"automatic_codec", true},
            {"codecs", QStringList{"hevc", "h264", "auto"}}, {"bounded_fragment_reordering", true}};
}

QVariantMap VideoReceiver::diagnostics() const {
    auto result = m_diagnostics;
    // These are local monotonic queue/display ages, not capture/network latency.
    result.insert("last_frame_age_ms", m_lastFrame < 0 ? QVariant{} : QVariant(m_clock.elapsed() - m_lastFrame));
    result.insert("last_ui_queue_age_ms", m_lastQueueAge < 0 ? QVariant{} : QVariant(m_lastQueueAge));
    result.insert("maximum_ui_queue_age_ms", m_maxQueueAge);
    result.insert("expired_ui_frames", m_expiredUiFrames);
    return result;
}
#include "VideoReceiver.moc"
