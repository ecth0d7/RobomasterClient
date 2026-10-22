#include "TcpBridge.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>
#include <QUuid>
#include <QCoreApplication>
#include <cmath>
#include <utility>

namespace {
QByteArray encode(const QVariantMap &message) {
    return QJsonDocument::fromVariant(message).toJson(QJsonDocument::Compact) + '\n';
}
bool fail(QString *error, const QString &message) {
    if (error)
        *error = message;
    return false;
}
bool integer(const QVariant &value, double minimum, double maximum) {
    switch (value.metaType().id()) {
    case QMetaType::Int:
    case QMetaType::UInt:
    case QMetaType::LongLong:
    case QMetaType::ULongLong:
    case QMetaType::Double:
        break;
    default:
        return false;
    }
    const double number = value.toDouble();
    return std::isfinite(number) && number >= minimum && number <= maximum &&
           std::floor(number) == number;
}
struct Configuration {
    QHostAddress address;
    quint16 port = 0;
    bool listen = true;
    QString token, peerHost;
    quint16 peerPort = 0;
};
// Keep preflight and activation on one parser. These defaults are the original
// laboratory bridge defaults; there is no inferred official/team protocol.
bool parseConfiguration(const QVariantMap &configuration, Configuration *result, QString *error) {
    if (error) error->clear();
    const auto laboratory = configuration.value("laboratory");
    if (laboratory.metaType().id() != QMetaType::Bool || !laboratory.toBool())
        return fail(error, "TCP bridge requires laboratory mode (RoboMaster S63)");
    const auto bind = configuration.value("bind", QStringLiteral("127.0.0.1"));
    const auto port = configuration.value("listen_port", 0);
    const auto listen = configuration.value("listen", true);
    const auto peer = configuration.value("peer", QString{});
    const auto token = configuration.value("token", QString{});
    if (bind.metaType().id() != QMetaType::QString || bind.toString().size() > 256 ||
        !integer(port, 0, 65535) || listen.metaType().id() != QMetaType::Bool ||
        peer.metaType().id() != QMetaType::QString || peer.toString().size() > 2048 ||
        token.metaType().id() != QMetaType::QString)
        return fail(error, "Invalid bridge address/port/listen/peer/token field types or bounds");
    Configuration parsed;
    parsed.address = QHostAddress(bind.toString()); // Literal IP only; no DNS.
    parsed.port = quint16(port.toUInt());
    parsed.listen = listen.toBool();
    parsed.token = token.toString();
    if (parsed.address.isNull())
        return fail(error, "Invalid bridge listening address or port");
    const QString peerText = peer.toString();
    const QUrl peerUrl(peerText, QUrl::StrictMode);
    if (!peerText.isEmpty() &&
        (!peerUrl.isValid() || peerUrl.scheme() != "tcp" || peerUrl.host().isEmpty() ||
         peerUrl.port() < 1 || peerUrl.port() > 65535 || !peerUrl.userInfo().isEmpty() ||
         !peerUrl.query().isEmpty() || !peerUrl.fragment().isEmpty() || !peerUrl.path().isEmpty()))
        return fail(error, "Bridge peer must be tcp://host:port");
    if (!parsed.listen && peerText.isEmpty())
        return fail(error, "Bridge needs a listener or a peer");
    if (parsed.token.size() > 256)
        return fail(error, "Bridge token is too long");
    if (parsed.listen && !parsed.address.isLoopback() && parsed.token.isEmpty())
        return fail(error, "Non-loopback laboratory listener needs a shared token");
    parsed.peerHost = peerText.isEmpty() ? QString{} : peerUrl.host();
    parsed.peerPort = peerText.isEmpty() ? 0 : quint16(peerUrl.port());
    if (result) *result = std::move(parsed);
    return true;
}
}
TcpBridge::TcpBridge(QObject *parent) : ServiceEndpoint(parent) {
    m_clock.start();
    m_heartbeat.setInterval(1000);
    connect(
        &m_server, &QTcpServer::newConnection, this,
        [this] {
            QPointer<TcpBridge> lifetime(this);
            const auto generation = m_generation;
            while (m_server.hasPendingConnections()) {
                auto *socket = m_server.nextPendingConnection();
                if (m_connections.size() >= MaximumConnections) {
                    socket->abort();
                    socket->deleteLater();
                    ++m_dropped;
                } else
                    addSocket(socket, false);
                if (!lifetime || generation != m_generation)
                    return;
            }
        },
        Qt::QueuedConnection);
    connect(
        &m_heartbeat, &QTimer::timeout, this,
        [this] {
            if (!m_active)
                return; // stop 后仍可能收到已排队的超时回调。
            QPointer<TcpBridge> lifetime(this);
            const auto generation = m_generation;
            const auto sockets = m_connections.keys();
            const auto now = m_clock.elapsed();
            for (auto *socket : sockets) {
                if (!m_connections.contains(socket))
                    continue;
                const auto entry = m_connections.value(socket);
                if (entry.closing || entry.rejected)
                    continue;
                if (now - entry.lastRead > (entry.ready ? 15000 : 3000))
                    rejectSocket(socket);
                else if (entry.ready)
                    write(socket, encode({{"schema", 1}, {"kind", "ping"}}));
                if (!lifetime || generation != m_generation)
                    return;
            }
            reconnect();
            if (!lifetime || generation != m_generation)
                return;
            emit statusChanged(); // 队列与计数诊断合并为每秒一次通知。
        },
        Qt::QueuedConnection);
}
TcpBridge::~TcpBridge() {
    blockSignals(true);
    stop();
}
bool TcpBridge::validateConfiguration(const QVariantMap &configuration, QString *error) {
    return parseConfiguration(configuration, nullptr, error);
}
bool TcpBridge::start(const QVariantMap &configuration, QString *error) {
    QPointer<TcpBridge> lifetime(this);
    const auto generation = m_generation + 1;
    stop();
    // 通知回调可能同步替换端点或会话。
    if (!lifetime || generation != m_generation)
        return false;
    Configuration parsed;
    if (!parseConfiguration(configuration, &parsed, error))
        return false;
    if (parsed.listen && !m_server.listen(parsed.address, parsed.port))
        return fail(error, m_server.errorString());
    m_token = std::move(parsed.token);
    m_source = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_peerHost = std::move(parsed.peerHost);
    m_peerPort = parsed.peerPort;
    m_active = true;
    m_error.clear();
    m_nextReconnect = 0;
    m_reconnectDelay = 250;
    m_heartbeat.start();
    reconnect();
    if (!lifetime || generation != m_generation)
        return false;
    emit statusChanged();
    return lifetime && generation == m_generation;
}
void TcpBridge::stop() {
    ++m_generation;
    m_active = false;
    m_heartbeat.stop();
    m_server.close();
    const auto sockets = m_connections.keys();
    m_connections.clear();
    m_outbound = nullptr;
    for (auto *socket : sockets) {
        releaseSocket(socket);
        socket->abort();
    }
    m_lastSnapshot.clear();
    m_lastSequence.clear();
    m_sources.clear();
    m_dropped = 0;
    m_drainBatches = m_drainYields = 0;
    m_maxBatchMessages = 0;
    m_peerHost.clear();
    m_peerPort = 0;
    m_token.clear();
    m_error.clear();
    emit statusChanged();
}
QString TcpBridge::status() const {
    if (!m_active)
        return "未启用";
    if (!m_error.isEmpty())
        return m_error;
    return QString("实验室桥接 · %1 个连接").arg(m_connections.size());
}
QVariantMap TcpBridge::details() const {
    qint64 inputBytes = 0, outputBytes = 0;
    int pendingReads = 0;
    for (auto it = m_connections.cbegin(); it != m_connections.cend(); ++it) {
        inputBytes += it.value().input.size() + it.key()->bytesAvailable();
        outputBytes += it.key()->bytesToWrite();
        if (it.value().drainScheduled)
            ++pendingReads;
    }
    return {{"active", m_active},
            {"listen_port", m_server.serverPort()},
            {"connections", m_connections.size()},
            {"dropped", qulonglong(m_dropped)},
            {"pending_input_bytes", inputBytes},
            {"pending_output_bytes", outputBytes},
            {"pending_reads", pendingReads},
            {"drain_batches", m_drainBatches},
            {"drain_yields", m_drainYields},
            {"maximum_batch_messages", m_maxBatchMessages}};
}
void TcpBridge::reconnect() {
    if (!m_active || m_peerHost.isEmpty() || m_outbound ||
        m_connections.size() >= MaximumConnections || m_clock.elapsed() < m_nextReconnect)
        return;
    auto *socket = new QTcpSocket(this);
    QPointer<TcpBridge> lifetime(this);
    QPointer<QTcpSocket> guarded(socket);
    const auto generation = m_generation;
    m_outbound = socket;
    addSocket(socket, true);
    if (!lifetime || !guarded || generation != m_generation || !m_connections.contains(socket))
        return;
    socket->connectToHost(m_peerHost, m_peerPort);
}
void TcpBridge::addSocket(QTcpSocket *socket, bool outbound) {
    socket->setParent(this);
    socket->setReadBufferSize(MaximumLine + 1);
    socket->setSocketOption(QAbstractSocket::LowDelayOption, 1);
    m_connections.insert(socket, {{}, false, m_clock.elapsed()});
    const auto socketGeneration = m_generation;
    const QPointer<QTcpSocket> guardedSocket(socket);
    connect(socket, &QTcpSocket::readyRead, this, [this, socket] { scheduleConsume(socket); });
    connect(
        socket, &QTcpSocket::connected, this,
        [this, socket, guardedSocket, socketGeneration] {
            if (!guardedSocket || socketGeneration != m_generation ||
                !m_connections.contains(socket) ||
                socket->state() != QAbstractSocket::ConnectedState)
                return;
            QPointer<TcpBridge> lifetime(this);
            const auto generation = m_generation;
            m_error.clear();
            m_reconnectDelay = 250;
            sendHello(socket);
            if (!lifetime || generation != m_generation || !m_connections.contains(socket))
                return;
            emit statusChanged();
        },
        Qt::QueuedConnection);
    connect(
        socket, &QTcpSocket::errorOccurred, this,
        [this, outbound, socketGeneration](QAbstractSocket::SocketError) {
            if (socketGeneration != m_generation)
                return;
            // Qt 可能先报告 UnconnectedState，再报告错误，期间外连指针已被移除。
            // 回调保留原连接角色，以便正确显示重连错误。
            if (outbound)
                m_error = "实验室桥接连接中断，等待重连";
            emit statusChanged();
        },
        Qt::QueuedConnection);
    connect(
        socket, &QTcpSocket::disconnected, this,
        [this, socket, outbound, guardedSocket, socketGeneration] {
            if (!guardedSocket || socketGeneration != m_generation ||
                !m_connections.contains(socket))
                return;
            closeSocket(socket, outbound);
        },
        Qt::QueuedConnection);
    // 连接失败可能只发出错误和状态变化，没有 disconnected 信号。
    connect(
        socket, &QTcpSocket::stateChanged, this,
        [this, socket, outbound, guardedSocket,
         socketGeneration](QAbstractSocket::SocketState state) {
            if (!guardedSocket || socketGeneration != m_generation)
                return;
            if (outbound && state == QAbstractSocket::UnconnectedState &&
                m_connections.contains(socket)) {
                closeSocket(socket, true);
            }
        },
        Qt::QueuedConnection);
    QPointer<TcpBridge> lifetime(this);
    const auto generation = m_generation;
    if (!outbound)
        sendHello(socket);
    if (!lifetime || generation != m_generation || !m_connections.contains(socket))
        return;
    emit statusChanged();
}
void TcpBridge::releaseSocket(QTcpSocket *socket) {
    socket->disconnect(this);
    // 断连通知中销毁端点时，abort 或 disconnectFromHost 可能仍在访问 Qt 内部状态。
    // 仅调用 deleteLater 不够：端点析构会先删除 QObject 子对象。
    // 将退役 socket 交给应用持有，再延迟删除；事件循环已退出时也会被应用回收。
    socket->setParent(QCoreApplication::instance());
    socket->deleteLater();
}
void TcpBridge::closeSocket(QTcpSocket *socket, bool outbound) {
    if (!m_connections.contains(socket))
        return;
    auto &entry = m_connections[socket];
    if (!entry.closing) {
        entry.closing = true;
        if (outbound && m_outbound == socket) {
            m_outbound = nullptr;
            m_nextReconnect = m_clock.elapsed() + m_reconnectDelay;
            m_reconnectDelay = qMin(8000, m_reconnectDelay * 2);
        }
    }
    // 正常 FIN 到达时，分批解析缓冲中仍可能有完整消息。
    // 保留 socket 和缓冲，沿用有限批次排空后再结束连接。
    if (!entry.rejected && (!entry.input.isEmpty() || socket->bytesAvailable()))
        scheduleConsume(socket);
    else
        finishSocket(socket);
}
void TcpBridge::finishSocket(QTcpSocket *socket) {
    if (!m_connections.remove(socket))
        return;
    releaseSocket(socket);
    emit statusChanged();
}
void TcpBridge::rejectSocket(QTcpSocket *socket) {
    if (!m_connections.contains(socket))
        return;
    m_connections[socket].rejected = true;
    m_connections[socket].input.clear();
    ++m_dropped;
    QPointer<TcpBridge> lifetime(this);
    const auto generation = m_generation;
    socket->abort();
    if (!lifetime || generation != m_generation || !m_connections.contains(socket))
        return;
    // 已到 EOF 的 socket 调用 abort 不会再次发出断连信号。
    if (socket->state() == QAbstractSocket::UnconnectedState)
        closeSocket(socket, socket == m_outbound);
}
void TcpBridge::sendHello(QTcpSocket *socket) {
    write(socket,
          encode({{"schema", 1}, {"kind", "hello"}, {"source", m_source}, {"token", m_token}}));
}
bool TcpBridge::write(QTcpSocket *socket, const QByteArray &line) {
    if (socket->state() != QAbstractSocket::ConnectedState)
        return false;
    // Qt 发送队列默认没有长度上限；超限时断开慢消费者，
    // 避免旧快照无限积压。
    if (socket->bytesToWrite() + line.size() > 4 * MaximumLine) {
        rejectSocket(socket);
        return false;
    }
    QPointer<TcpBridge> lifetime(this);
    QPointer<QTcpSocket> guarded(socket);
    const auto generation = m_generation;
    const auto written = socket->write(line);
    if (!lifetime || !guarded || generation != m_generation)
        return false;
    if (written != line.size()) {
        rejectSocket(socket);
        return false;
    }
    return true;
}
void TcpBridge::broadcast(const QByteArray &line, QTcpSocket *excluded) {
    const auto sockets = m_connections.keys();
    QPointer<TcpBridge> alive(this);
    const auto generation = m_generation;
    for (auto *socket : sockets) {
        if (socket != excluded && m_connections.value(socket).ready)
            write(socket, line);
        if (!alive || generation != m_generation)
            return;
    }
}
void TcpBridge::scheduleConsume(QTcpSocket *socket) {
    if (!m_connections.contains(socket) || m_connections.value(socket).rejected ||
        m_connections.value(socket).drainScheduled)
        return;
    m_connections[socket].drainScheduled = true;
    QPointer<QTcpSocket> guarded(socket);
    const auto generation = m_generation;
    QTimer::singleShot(0, this, [this, guarded, generation] {
        if (!guarded || generation != m_generation || !m_connections.contains(guarded))
            return;
        m_connections[guarded].drainScheduled = false;
        consume(guarded);
    });
}
void TcpBridge::consume(QTcpSocket *socket) {
    if (!m_connections.contains(socket) || m_connections.value(socket).rejected)
        return;
    QPointer<TcpBridge> alive(this);
    const auto generation = m_generation;
    QElapsedTimer quantum;
    quantum.start();
    ++m_drainBatches;
    int count = 0;
    while (m_connections.contains(socket) && count < 32 && quantum.elapsed() < 4) {
        auto &buffer = m_connections[socket].input;
        auto newline = buffer.indexOf('\n');
        if (newline < 0 && socket->bytesAvailable()) {
            buffer += socket->read(MaximumLine - buffer.size());
            m_connections[socket].lastRead = m_clock.elapsed();
            newline = buffer.indexOf('\n');
        }
        if (newline < 0) {
            if (buffer.size() >= MaximumLine) {
                rejectSocket(socket);
                return;
            }
            break;
        }
        const auto line = buffer.left(newline);
        buffer.remove(0, newline + 1);
        ++count;
        QJsonParseError error;
        const auto json = QJsonDocument::fromJson(line, &error);
        if (error.error != QJsonParseError::NoError || !json.isObject()) {
            rejectSocket(socket);
            return;
        }
        handle(socket, json.object().toVariantMap());
        if (!alive || generation != m_generation)
            return;
        if (!m_connections.contains(socket) || m_connections.value(socket).rejected)
            return;
    }
    m_maxBatchMessages = qMax(m_maxBatchMessages, count);
    if (m_connections.contains(socket) &&
        (m_connections.value(socket).input.contains('\n') || socket->bytesAvailable())) {
        ++m_drainYields;
        scheduleConsume(socket);
    } else if (m_connections.contains(socket) && m_connections.value(socket).closing) {
        if (!m_connections.value(socket).input.isEmpty())
            ++m_dropped; // 末尾不足一行的报文计为丢弃。
        finishSocket(socket);
    }
}
void TcpBridge::handle(QTcpSocket *socket, const QVariantMap &message) {
    if (!m_connections.contains(socket))
        return;
    const QString kind = message.value("kind").toString();
    if (!integer(message.value("schema"), 1, 1)) {
        rejectSocket(socket);
        return;
    }
    if (kind == "hello") {
        if (m_connections.value(socket).ready || message.value("source").toString().isEmpty() ||
            message.value("source").metaType().id() != QMetaType::QString ||
            (message.contains("token") &&
             message.value("token").metaType().id() != QMetaType::QString) ||
            message.value("source").toString().size() > 96 ||
            message.value("token").toString() != m_token) {
            rejectSocket(socket);
            return;
        }
        m_connections[socket].ready = true;
        QPointer<TcpBridge> lifetime(this);
        const auto generation = m_generation;
        if (!m_lastSnapshot.isEmpty())
            write(socket, encode(m_lastSnapshot));
        if (!lifetime || generation != m_generation || !m_connections.contains(socket))
            return;
        emit statusChanged();
        return;
    }
    if (!m_connections.value(socket).ready) {
        rejectSocket(socket);
        return;
    }
    if (kind == "ping")
        return;
    QString error;
    if (!validate(message, &error)) {
        rejectSocket(socket);
        return;
    }
    const auto serialized = encode(message);
    if (serialized.size() > MaximumLine) {
        rejectSocket(socket);
        return;
    }
    if (!remember(message))
        return;
    QPointer<TcpBridge> alive(this);
    emit messageReceived(message);
    // 接收者可能在回调中停止、重启或销毁端点。
    // 不能把旧会话的数据转发到新桥接会话。
    if (!alive || !m_connections.contains(socket) || !m_connections.value(socket).ready)
        return;
    broadcast(serialized, socket);
}
bool TcpBridge::validate(const QVariantMap &message, QString *error) const {
    const auto kind = message.value("kind").toString();
    const auto source = message.value("source").toString();
    if (!integer(message.value("schema"), 1, 1) || (kind != "snapshot" && kind != "event") ||
        source.isEmpty() || source.size() > 96 ||
        message.value("source").metaType().id() != QMetaType::QString ||
        !integer(message.value("seq"), 1, 9007199254740991.0) ||
        !integer(message.value("sent_at_ms"), 1, 9007199254740991.0) ||
        !integer(message.value("robot_id"), 0, 65535) ||
        message.value("payload").metaType().id() != QMetaType::QVariantMap)
        return fail(error, "Invalid bridge envelope; only snapshot/event schema 1 is accepted");
    return true;
}
bool TcpBridge::remember(const QVariantMap &message) {
    const auto source = message.value("source").toString();
    const auto sequence = message.value("seq").toULongLong();
    if (m_lastSequence.contains(source) && sequence <= m_lastSequence.value(source)) {
        ++m_dropped;
        return false;
    }
    if (!m_lastSequence.contains(source)) {
        if (m_sources.size() >= 64)
            m_lastSequence.remove(m_sources.takeFirst());
        m_sources.append(source);
    }
    m_lastSequence[source] = sequence;
    return true;
}
bool TcpBridge::submit(const QVariantMap &message, QString *error) {
    if (error)
        error->clear();
    if (!m_active)
        return fail(error, "Bridge is not active");
    if (!validate(message, error))
        return false;
    const auto serialized = encode(message);
    if (serialized.size() > MaximumLine)
        return fail(error, "Bridge envelope exceeds 64 KiB");
    if (!remember(message))
        return fail(error, "Duplicate or out-of-order bridge sequence");
    if (message.value("kind") == "snapshot")
        m_lastSnapshot = message;
    QPointer<TcpBridge> lifetime(this);
    const auto generation = m_generation;
    broadcast(serialized);
    return lifetime && generation == m_generation;
}
