#include "HeroClient.h"
#include "H264Decoder.h"
#include "HeroProtocol.h"
#include "hero_custom_client.pb.h"

#include <QMetaObject>
#include <QtEndian>

HeroClient::HeroClient(H264Decoder *decoder, QObject *parent)
    : QObject(parent), m_decoder(decoder),
      m_settings("HNU", "HeroCustomClient")
{
    mosquitto_lib_init();
    m_heartbeat.setInterval(1000);
    connect(&m_heartbeat, &QTimer::timeout, this, [this] { sendCommand(0x03); });
    m_telemetryWatchdog.setInterval(1000);
    m_telemetryWatchdog.setSingleShot(true);
    connect(&m_telemetryWatchdog, &QTimer::timeout, this, [this] {
        if (m_telemetryOnline) {
            m_telemetryOnline = false;
            emit telemetryOnlineChanged();
        }
    });
    connect(m_decoder, &H264Decoder::frameReady, this, &HeroClient::frameReady);
}

HeroClient::~HeroClient()
{
    disconnectFromServer();
    if (m_mosquitto) mosquitto_destroy(m_mosquitto);
    mosquitto_lib_cleanup();
}

bool HeroClient::connectToServer(const QString &clientId, const QString &host, int port)
{
    disconnectFromServer();
    if (m_mosquitto) {
        mosquitto_destroy(m_mosquitto);
        m_mosquitto = nullptr;
    }
    const QByteArray id = clientId.toUtf8();
    m_commandSequence = static_cast<quint16>(m_settings.value("sequence/" + clientId, 0).toUInt());
    m_mosquitto = mosquitto_new(id.constData(), true, this);
    if (!m_mosquitto) {
        setStatus("初始化失败");
        return false;
    }
    mosquitto_connect_callback_set(m_mosquitto, onConnect);
    mosquitto_disconnect_callback_set(m_mosquitto, onDisconnect);
    mosquitto_message_callback_set(m_mosquitto, onMessage);
    mosquitto_user_data_set(m_mosquitto, this);

    setStatus("连接中");
    int rc = mosquitto_connect_async(m_mosquitto, host.toUtf8().constData(), port, 60);
    if (rc == MOSQ_ERR_SUCCESS) rc = mosquitto_loop_start(m_mosquitto);
    if (rc != MOSQ_ERR_SUCCESS) {
        setStatus(QString("连接启动失败: %1").arg(mosquitto_strerror(rc)));
        return false;
    }
    m_loopStarted = true;
    m_settings.setValue("active_client_id", clientId);
    return true;
}

void HeroClient::disconnectFromServer()
{
    m_heartbeat.stop();
    m_telemetryWatchdog.stop();
    if (m_mosquitto && m_loopStarted) {
        mosquitto_disconnect(m_mosquitto);
        mosquitto_loop_stop(m_mosquitto, true);
        m_loopStarted = false;
    }
    if (m_connected.exchange(false)) emit connectedChanged();
    if (m_telemetryOnline) {
        m_telemetryOnline = false;
        emit telemetryOnlineChanged();
    }
}

void HeroClient::trimStep(int steps)
{
    if (steps < -4 || steps > 4 || steps == 0) {
        emit commandRejected("trim_step 必须在 [-4,+4] 且不能为 0");
        return;
    }
    sendCommand(0x01, static_cast<qint8>(steps));
}

void HeroClient::trimReset() { sendCommand(0x02); }

quint16 HeroClient::nextSequence()
{
    // u16 自然回绕符合协议；先持久化再发布，发布失败也不复用旧序号。
    ++m_commandSequence;
    const QString clientId = m_settings.value("active_client_id").toString();
    m_settings.setValue("sequence/" + clientId, m_commandSequence);
    m_settings.sync();
    return m_commandSequence;
}

void HeroClient::sendCommand(quint8 command, qint8 parameter)
{
    if (!m_connected || !m_mosquitto) {
        if (command != 0x03) emit commandRejected("MQTT 未连接");
        return;
    }
    const quint16 sequence = nextSequence();
    const QByteArray raw = HeroProtocol::makeCommand(sequence, command, parameter);

    // MQTT payload 是 protobuf 外壳，data 内才是固定 30B 的 0x0311 raw payload。
    robomaster::hero_client::CustomControl envelope;
    envelope.set_data(raw.constData(), raw.size());
    std::string bytes;
    envelope.SerializeToString(&bytes);
    const int rc = mosquitto_publish(m_mosquitto, nullptr, "CustomControl",
                                     static_cast<int>(bytes.size()), bytes.data(), 1, false);
    if (rc == MOSQ_ERR_SUCCESS)
        emit commandSent(sequence, command, parameter);
    else
        emit commandRejected(QString("发布失败: %1").arg(mosquitto_strerror(rc)));
}

void HeroClient::onConnect(mosquitto *mosq, void *context, int rc)
{
    auto *self = static_cast<HeroClient *>(context);
    // QTimer 和 QML 属性只能在 QObject 所属的 Qt 主线程更新。
    QMetaObject::invokeMethod(self, [self, mosq, rc] {
        if (rc == 0) {
            self->m_connected = true;
            mosquitto_subscribe(mosq, nullptr, "CustomByteBlock", 1);
            self->setStatus("已连接");
            emit self->connectedChanged();
            self->m_heartbeat.start();
            self->sendCommand(0x03);
        } else {
            self->m_connected = false;
            self->setStatus(QString("连接失败(%1)").arg(rc));
        }
    }, Qt::QueuedConnection);
}

void HeroClient::onDisconnect(mosquitto *, void *context, int rc)
{
    auto *self = static_cast<HeroClient *>(context);
    QMetaObject::invokeMethod(self, [self, rc] {
        const bool changed = self->m_connected.exchange(false);
        self->m_heartbeat.stop();
        self->setStatus(rc == 0 ? "已断开" : "连接中断");
        if (changed) emit self->connectedChanged();
    }, Qt::QueuedConnection);
}

void HeroClient::onMessage(mosquitto *, void *context, const mosquitto_message *message)
{
    if (!message || !message->payload || QString::fromUtf8(message->topic) != "CustomByteBlock") return;
    auto *self = static_cast<HeroClient *>(context);
    // 在网络线程复制 payload，随后交给主线程解析，避免消息回调返回后悬空。
    const QByteArray bytes(static_cast<const char *>(message->payload), message->payloadlen);
    QMetaObject::invokeMethod(self, [self, bytes] {
        robomaster::hero_client::CustomByteBlock envelope;
        if (!envelope.ParseFromArray(bytes.constData(), bytes.size())) return;
        self->handlePayload(QByteArray(envelope.data().data(), static_cast<int>(envelope.data().size())));
    }, Qt::QueuedConnection);
}

void HeroClient::handlePayload(const QByteArray &payload)
{
    // HNU-TLM 与 HNU-VID 共用 magic，通过 type 字段分流。
    if (payload.size() < 2 || static_cast<quint8>(payload[0]) != 0x5A) return;
    if (static_cast<quint8>(payload[1]) == 0x01) {
        QVariantMap telemetry;
        if (!HeroProtocol::parseTelemetry(payload, telemetry)) return;
        if (!m_telemetryOnline) {
            m_telemetryOnline = true;
            emit telemetryOnlineChanged();
        }
        m_telemetryWatchdog.start();
        emit telemetryUpdated(telemetry);
    } else if (static_cast<quint8>(payload[1]) == 0x02) {
        handleVideo(payload);
    }
}

void HeroClient::handleVideo(const QByteArray &p)
{
    if (p.size() < HeroProtocol::VideoHeaderSize) return;

    const int sliceBytes = p.size() - HeroProtocol::VideoHeaderSize;
    if (sliceBytes <= 0 || sliceBytes > HeroProtocol::VideoSliceSize) return;

    const quint16 seq = qFromLittleEndian<quint16>(p.constData() + 2);
    const quint16 frameId = qFromLittleEndian<quint16>(p.constData() + 4);
    const quint16 sliceId = qFromLittleEndian<quint16>(p.constData() + 6);
    const quint32 total = qFromLittleEndian<quint32>(p.constData() + 8);
    if (total == 0 || total > 4U * 1024U * 1024U) return;

    if (sliceId == 0) {
        // slice 0 开启新帧；未完成的旧帧直接丢弃。
        m_frameId = frameId;
        m_nextSlice = 0;
        m_frameTotal = total;
        m_frameBuffer.clear();
        m_frameBuffer.reserve(static_cast<int>(total));
    }
    if (frameId != m_frameId || sliceId != m_nextSlice
        || (m_nextSlice > 0 && static_cast<quint16>(m_videoSequence + 1) != seq)) {
        // frame/slice/seq 任一不连续时，本帧不再可信，等待后续新帧恢复。
        m_frameBuffer.clear();
        m_frameTotal = 0;
        m_nextSlice = 0;
        m_decoder->reset();
        return;
    }

    if (static_cast<quint64>(m_frameBuffer.size()) + static_cast<quint64>(sliceBytes)
        > m_frameTotal) {
        m_frameBuffer.clear();
        m_frameTotal = 0;
        m_nextSlice = 0;
        m_decoder->reset();
        return;
    }

    m_videoSequence = seq;
    ++m_nextSlice;
    m_frameBuffer.append(p.constData() + HeroProtocol::VideoHeaderSize, sliceBytes);
    if (static_cast<quint32>(m_frameBuffer.size()) == m_frameTotal) {
        m_decoder->decode(m_frameBuffer);
        m_frameBuffer.clear();
        m_frameTotal = 0;
        m_nextSlice = 0;
    }
}

void HeroClient::setStatus(const QString &text)
{
    if (m_statusText == text) return;
    m_statusText = text;
    emit statusTextChanged();
}
