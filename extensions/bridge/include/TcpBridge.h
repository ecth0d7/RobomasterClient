#pragma once
#include "ServiceEndpoint.h"
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QElapsedTimer>
#include <QHash>
#include <QPointer>

// 实验室遥测中继，不发布机器人控制消息。
class TcpBridge final : public ServiceEndpoint {
    Q_OBJECT
public:
    explicit TcpBridge(QObject *parent = nullptr);
    ~TcpBridge() override;
    // Pure preflight for the actual schema1 laboratory transport. Applies the
    // same strict known-field types/defaults as start(), without binding,
    // resolving a hostname, reading token environment variables or connecting.
    // Legacy extra configuration keys remain ignored by this transport.
    static bool validateConfiguration(const QVariantMap &configuration, QString *error = nullptr);
    bool start(const QVariantMap &configuration, QString *error) override;
    void stop() override;
    bool submit(const QVariantMap &message, QString *error) override;
    QString status() const override;
    QVariantMap details() const override;

private:
    struct Connection {
        QByteArray input;
        bool ready = false;
        qint64 lastRead = 0;
        bool drainScheduled = false;
        bool closing = false;
        bool rejected = false;
    };
    void addSocket(QTcpSocket *socket, bool outbound);
    void consume(QTcpSocket *socket);
    void scheduleConsume(QTcpSocket *socket);
    void releaseSocket(QTcpSocket *socket);
    void closeSocket(QTcpSocket *socket, bool outbound);
    void finishSocket(QTcpSocket *socket);
    void rejectSocket(QTcpSocket *socket);
    void handle(QTcpSocket *socket, const QVariantMap &message);
    void sendHello(QTcpSocket *socket);
    bool write(QTcpSocket *socket, const QByteArray &line);
    void broadcast(const QByteArray &line, QTcpSocket *excluded = nullptr);
    bool validate(const QVariantMap &message, QString *error) const;
    bool remember(const QVariantMap &message);
    void reconnect();
    QTcpServer m_server;
    QHash<QTcpSocket *, Connection> m_connections;
    QPointer<QTcpSocket> m_outbound;
    QHash<QString, quint64> m_lastSequence;
    QStringList m_sources;
    QVariantMap m_lastSnapshot;
    QTimer m_heartbeat;
    QElapsedTimer m_clock;
    QString m_source, m_token, m_peerHost, m_error;
    quint16 m_peerPort = 0;
    bool m_active = false;
    qint64 m_nextReconnect = 0;
    int m_reconnectDelay = 250;
    quint64 m_dropped = 0;
    quint64 m_generation = 0;
    quint64 m_drainBatches = 0, m_drainYields = 0;
    int m_maxBatchMessages = 0;
    static constexpr qsizetype MaximumLine = 65536;
    static constexpr int MaximumConnections = 8;
};
