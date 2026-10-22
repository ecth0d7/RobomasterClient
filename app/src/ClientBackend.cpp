#include "ClientBackend.h"
#include "RobotIdentity.h"
#include "PacketObservation.h"
#include <QLoggingCategory>
#include <QTimer>
#include <QMetaProperty>
#include <QPointer>
#include <QDateTime>
#include <QHostAddress>
#include <QRegularExpression>
#include <stdexcept>
#include <cmath>

Q_LOGGING_CATEGORY(protocolLog, "robomaster.protocol")
namespace {
std::optional<QByteArray> customBytePayload(const QVariant &value) {
    // rm2026 exposes protobuf bytes as hexadecimal for the protocol inspector.
    // Optional codecs may expose QByteArray directly. Never decode arbitrary
    // text with QByteArray::fromHex's permissive character skipping.
    if(value.metaType().id()==QMetaType::QByteArray) {
        const auto bytes=value.toByteArray();
        if(bytes.size()<=300)return bytes;
    } else if(value.metaType().id()==QMetaType::QString) {
        const auto text=value.toString();
        static const QRegularExpression hex(QStringLiteral("\\A[0-9a-fA-F]*\\z"));
        if(text.size()<=600 && text.size()%2==0 && hex.match(text).hasMatch())
            return QByteArray::fromHex(text.toLatin1());
    }
    return std::nullopt;
}
}
ClientBackend::ClientBackend(const QString &host, int port, std::unique_ptr<MqttEndpoint> transport,
                             std::unique_ptr<ProtocolEndpoint> protocol,
                             std::unique_ptr<TelemetryEndpoint> telemetry,
                             std::unique_ptr<CommandPolicyEndpoint> policy, QObject *parent)
    : QObject(parent), m_transport(std::move(transport)), m_protocol(std::move(protocol)),
      m_telemetry(std::move(telemetry)), m_policy(std::move(policy)), m_host(host), m_port(port) {
    if (!m_transport || !m_protocol || !m_telemetry || !m_policy)
        throw std::invalid_argument("Missing client endpoint");
    m_clock.start();
    // 具体实现的可选诊断不写进稳定的 MQTT SDK。
    // 宿主以有限频率转发变化通知，不再复制一份传输层统计。
    const int diagnosticProperty = m_transport->metaObject()->indexOfProperty("diagnostics");
    if (diagnosticProperty >= 0) {
        const auto property = m_transport->metaObject()->property(diagnosticProperty);
        if (property.hasNotifySignal())
            connect(
                m_transport.get(), property.notifySignal(), this,
                metaObject()->method(metaObject()->indexOfSlot("markReceiveDiagnosticsDirty()")));
    }
    m_diagnosticsTimer.setInterval(250);
    connect(&m_diagnosticsTimer, &QTimer::timeout, this, [this] {
        if (!m_receiveDiagnosticsDirty)
            return;
        m_receiveDiagnosticsDirty = false;
        emit receiveDiagnosticsChanged();
    });
    m_diagnosticsTimer.start();
    const int observedSignal=m_transport->metaObject()->indexOfSignal("packetObserved(QString,QByteArray,QVariantMap)");
    if(observedSignal>=0) {
        connect(m_transport.get(),m_transport->metaObject()->method(observedSignal),this,
                metaObject()->method(metaObject()->indexOfSlot("observePacket(QString,QByteArray,QVariantMap)")));
    }
    connect(m_transport.get(), &MqttEndpoint::packetReceived, this,
            [this, timedTransport = observedSignal >= 0](const QString &topic, const QByteArray &bytes) {
                const auto observation=m_observedPacket && m_observedPacket->topic==topic && m_observedPacket->bytes==bytes
                    ?m_observedPacket->stamp:QVariantMap{};
                m_observedPacket.reset();
                if (!m_connected || !sessionAllowed())
                    return;
                QPointer<ClientBackend> lifetime(this);
                const auto session = m_session;
                QString error, messageType;
                QVariantMap fields;
                const bool decoded =
                    m_protocol->decode(topic, bytes, &messageType, &fields, &error);
                // 可替换解码器可能同步通知其他接收者，触发宿主销毁、
                // 身份变更或断线。返回后先检查存活与会话。
                if (!lifetime || session != m_session || !m_connected)
                    return;
                if (decoded) {
                    // Keep callback time through GUI queuing and decoding. An
                    // invalid timed ingress must not fall back to apply(),
                    // which would give old bytes a new local arrival time.
                    // Empty optional protobuf messages remain valid no-ops.
                    auto *consumer = qobject_cast<TelemetryObservationConsumer *>(m_telemetry.get());
                    if (consumer && timedTransport && !fields.isEmpty()) {
                        QString ingressError;
                        if (!consumer->applyObserved(messageType, fields, observation, &ingressError)) {
                            if (!lifetime || session != m_session)
                                return;
                            m_ingressErrors = qMin<quint64>(m_ingressErrors + 1, PacketObservation::SafeInteger);
                            m_lastIngressError = ingressError.left(160);
                            m_receiveDiagnosticsDirty = true;
                            return;
                        }
                    } else {
                        // Legacy third-party endpoints keep their stable ABI.
                        m_telemetry->apply(messageType, fields);
                    }
                    if(lifetime && session==m_session && m_connected && messageType==QLatin1String("CustomByteBlock")) {
                        if(const auto payload=customBytePayload(fields.value("data")))
                            emit customBytesReceived(*payload,observation);
                    }
                } else {
                    ++m_decodeErrors;
                    m_lastDecodeError = error.left(160);
                    m_receiveDiagnosticsDirty = true;
                    const auto now = m_clock.elapsed();
                    if (now - m_lastDecodeLog >= 1000) {
                        m_lastDecodeLog = now;
                        qCWarning(protocolLog)
                            << m_lastDecodeError
                            << "decode errors in this session:" << m_decodeErrors;
                    }
                }
            });
    connect(m_transport.get(), &MqttEndpoint::connected, this, [this] {
        m_observedPacket.reset();
        m_connected = true;
        m_connecting = false;
        m_status = QStringLiteral("已连接 %1:%2").arg(m_host).arg(m_port);
        emit connectionChanged();
    });
    connect(m_transport.get(), &MqttEndpoint::disconnected, this, [this] {
        m_observedPacket.reset();
        m_connected = false;
        m_connecting = true;
        m_status = QStringLiteral("%1:%2 已断开，等待重连").arg(m_host).arg(m_port);
        emit connectionChanged();
    });
    connect(m_transport.get(), &MqttEndpoint::errorOccurred, this, [this](const QString &error) {
        m_status = error;
        emit connectionChanged();
    });
}
void ClientBackend::observePacket(const QString &topic,const QByteArray &bytes,const QVariantMap &observation) {
    m_observedPacket.reset();
    PacketObservation::Stamp stamp;
    if(!m_connected || !PacketObservation::parse(observation,&stamp)
        || stamp.basis!=QLatin1String("mqtt_callback")
        || stamp.session!=m_transport->property("packetObservationSession").toString())return;
    m_observedPacket=ObservedPacket{topic,bytes,observation};
}
ClientBackend::~ClientBackend() {
    blockSignals(true);
    m_diagnosticsTimer.stop();
    // 端点关闭时也可能同步通知；成员和具体端点开始销毁前，
    // 先断开它们到宿主的回调。
    m_transport->disconnect(this);
    m_telemetry->disconnect(this);
    m_transport->close();
}
QVariantMap ClientBackend::receiveDiagnostics() const {
    auto diagnostics = m_transport->property("diagnostics").toMap();
    diagnostics.insert("transport_statistics_available", !diagnostics.isEmpty());
    diagnostics.insert("decode_errors", m_decodeErrors);
    diagnostics.insert("last_decode_error", m_lastDecodeError);
    diagnostics.insert("ingress_rejections", m_ingressErrors);
    diagnostics.insert("last_ingress_rejection", m_lastIngressError);
    return diagnostics;
}
bool ClientBackend::loginAt(int robotId, const QString &requestedHost, int port) {
    const auto blocked = sessionBlockReason();
    if (!blocked.isEmpty()) {
        m_status = blocked;
        emit connectionChanged();
        return false;
    }
    const QString host = requestedHost.trimmed();
    QHostAddress address;
    static const QRegularExpression hostname(
        QStringLiteral("^(?=.{1,253}$)(?=.*[A-Za-z])[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$"));
    if (!RobotIdentity::valid(robotId) || port < 1 || port > 65535
        || (!address.setAddress(host) && !hostname.match(host).hasMatch())) {
        m_status = QStringLiteral("连接目标无效：填写IP或主机名以及1–65535端口");
        emit connectionChanged();
        return false;
    }
    const bool changed = host != m_host || port != m_port;
    const auto revision = ++m_targetRevision;
    const auto session = m_session;
    ++m_targetChanges;
    m_host = host;
    m_port = port;
    QPointer<ClientBackend> alive(this);
    if (changed) emit connectionOptionsChanged();
    if (!alive) return false;
    // Endpoint-bound preferences may react synchronously. A newer login wins;
    // no command may use new preferences with the still-open old transport.
    if (revision != m_targetRevision || session != m_session) {
        --m_targetChanges;
        return false;
    }
    const bool started = login(robotId);
    if (alive) --m_targetChanges;
    return alive && started;
}
bool ClientBackend::canChangeTarget() const {
    // 本地调试允许赛中更换连接与身份；赛季兼容、输入合法性和会话退役仍由登录流程校验。
    return true;
}
void ClientBackend::disconnectFromPlayer() {
    m_observedPacket.reset();
    ++m_session;
    m_connected = false;
    m_connecting = false;
    m_status = QStringLiteral("已断开 %1:%2").arg(m_host).arg(m_port);
    m_lastSent.clear();
    QPointer<ClientBackend> alive(this);
    m_transport->close();
    if (!alive) return;
    m_telemetry->reset();
    if (alive) emit connectionChanged();
}
bool ClientBackend::login(int robotId) {
    const auto blocked = sessionBlockReason();
    if (!blocked.isEmpty()) {
        m_status = blocked;
        emit connectionChanged();
        return false;
    }
    if (!RobotIdentity::valid(robotId))
        return false;

    QPointer<ClientBackend> lifetime(this);
    const auto session = ++m_session;
    // 关闭连接使上一会话中已排队的回调失效。
    m_transport->close();
    if (!lifetime || session != m_session)
        return false;
    m_decodeErrors = 0;
    m_lastDecodeError.clear();
    m_ingressErrors = 0;
    m_lastIngressError.clear();
    m_lastDecodeLog = -1000;
    m_receiveDiagnosticsDirty = true;
    m_clientId = robotId;
    m_lastSent.clear();
    m_telemetry->setClientId(robotId);
    if (!lifetime || session != m_session)
        return false;
    m_commandHistory.clear();
    m_commandSequence = 0;
    emit commandStatusChanged();
    if (!lifetime || session != m_session)
        return false;
    m_connected = false;
    m_connecting = true;
    m_status = QStringLiteral("正在连接 %1:%2").arg(m_host).arg(m_port);
    emit identityChanged();
    if (!lifetime || session != m_session)
        return false;
    emit connectionChanged();
    if (!lifetime || session != m_session)
        return false;
    const bool started = m_transport->open(RobotIdentity::mqttId(robotId), m_host, m_port,
                                           m_protocol->receiveTopics());
    if (!lifetime || session != m_session)
        return false;
    if (!started) {
        m_connecting = false;
        m_status = QStringLiteral("连接失败 %1:%2").arg(m_host).arg(m_port);
        emit connectionChanged();
    }
    if (!lifetime || session != m_session)
        return false;
    // connect_async 成功只表示连接流程已启动，不代表 broker 已可达。
    QTimer::singleShot(8000, this, [this, session] {
        if (session == m_session && !m_connected) {
            m_status = QStringLiteral("%1:%2 未响应，正在重试；可在身份页取消或更换地址").arg(m_host).arg(m_port);
            emit connectionChanged();
        }
    });
    return started;
}
bool ClientBackend::sendCommand(const QString &topic, const QVariantMap &fields) {
    if (topic == "KeyboardMouseControl")
        return false;
    return transmit("operator", topic, fields, true);
}
bool ClientBackend::sendInputFields(const QVariantMap &fields) {
    return transmit("input", "KeyboardMouseControl", fields, true);
}
bool ClientBackend::sendInput(const QVariantMap &fields) {
    return transmit("input", "KeyboardMouseControl", fields, false);
}
void ClientBackend::rejectOperatorCommand(const QString &topic, const QString &reason) {
    recordCommandResult(topic, false, reason);
}
void ClientBackend::recordCommandResult(const QString &topic, bool accepted, const QString &reason) {
    if (m_commandHistory.size() >= 24)
        m_commandHistory.removeLast();
    m_commandHistory.prepend(QVariantMap{
        {"topic", topic.left(128)},
        {"accepted", accepted},
        {"reason", reason.left(160)},
        {"delivery_stage", accepted ? "local_submission" : "rejected"},
        {"execution_confirmed", false},
        {"at_ms", m_clock.elapsed()},
        {"recorded_at", QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
        {"client_id", m_clientId},
        {"sequence", qulonglong(++m_commandSequence)}});
    emit commandStatusChanged();
}
bool ClientBackend::transmit(const QString &origin, const QString &topic, const QVariantMap &fields,
                             bool report) {
    QPointer<ClientBackend> lifetime(this);
    const auto session = m_session;
    const auto robotId = m_clientId;
    QString error, wireTopic;
    QByteArray payload;
    bool allowed = false;
    const auto blocked = sessionBlockReason();
    if (!blocked.isEmpty()) error = blocked;
    else if (m_targetChanges) error = QStringLiteral("连接目标正在切换，指令未发送");
    else allowed = m_policy->allow(origin, topic, fields, robotId, &error);
    if (!lifetime || session != m_session)
        return false;
    // Keep the policy plugin and final current-telemetry guard on every operator
    // path, including direct backend calls. Continuous input has its own origin.
    const auto guard = m_operatorGuard;
    if (allowed && origin == QLatin1String("operator") && guard)
        allowed = guard(topic, fields, &error);
    if (!lifetime || session != m_session)
        return false;
    const bool encoded = allowed && m_protocol->encode(topic, fields, &wireTopic, &payload, &error);
    if (!lifetime || session != m_session)
        return false;
    bool accepted = false;
    if (encoded) {
        // 低频操作由事件触发，不能定时重发旧动作。
        const qint64 minimumMs = qMax(1, m_protocol->minimumIntervalMs(topic, robotId));
        if (!lifetime || session != m_session)
            return false;
        const auto now = m_clock.elapsed();
        if (!m_connected)
            error = "未连接，指令未发送";
        else if (m_lastSent.contains(topic) && now - m_lastSent.value(topic) < minimumMs)
            error = "操作过快，请稍后重试";
        else {
            const bool published = m_transport->publish(wireTopic, payload);
            if (!lifetime || session != m_session)
                return false;
            if (!m_connected)
                error = "发送期间连接已断开";
            else if (published) {
                m_lastSent[topic] = now;
                accepted = true;
            } else
                error = "发送失败";
        }
    }
    if (report) {
        if (!accepted && error.isEmpty())
            error = "指令未通过策略或协议校验";
        // 同一份有界日志同时提供最近反馈和操作历史。
        // 连续遥控输入不写入操作日志。
        recordCommandResult(topic, accepted, error);
    }
    return accepted;
}
