#pragma once

#include <QObject>
#include <QSettings>
#include <QTimer>
#include <QVariantMap>
#include <atomic>
#include <mosquitto.h>

class H264Decoder;

class HeroClient final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool telemetryOnline READ telemetryOnline NOTIFY telemetryOnlineChanged)
    Q_PROPERTY(bool heartbeatEnabled READ heartbeatEnabled NOTIFY heartbeatEnabledChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)

public:
    explicit HeroClient(H264Decoder *decoder, QObject *parent = nullptr);
    ~HeroClient() override;

    bool connected() const { return m_connected; }
    bool telemetryOnline() const { return m_telemetryOnline; }
    bool heartbeatEnabled() const { return m_heartbeatEnabled; }
    QString statusText() const { return m_statusText; }

    Q_INVOKABLE bool connectToServer(const QString &clientId, const QString &host = "192.168.12.1", int port = 3333);
    Q_INVOKABLE void disconnectFromServer();
    Q_INVOKABLE void trimStep(int steps);
    Q_INVOKABLE void trimReset();
    Q_INVOKABLE void setHeartbeatEnabled(bool enabled);

signals:
    void connectedChanged();
    void telemetryOnlineChanged();
    void heartbeatEnabledChanged();
    void statusTextChanged();
    void telemetryUpdated(const QVariantMap &telemetry);
    void frameReady();
    void commandSent(int sequence, int command, int parameter);
    void commandRejected(const QString &reason);

private:
    static void onConnect(mosquitto *, void *, int rc);
    static void onDisconnect(mosquitto *, void *, int rc);
    static void onMessage(mosquitto *, void *, const mosquitto_message *message);
    void handlePayload(const QByteArray &payload);
    void handleVideo(const QByteArray &payload);
    void sendCommand(quint8 command, qint8 parameter = 0);
    quint16 nextSequence();
    void setStatus(const QString &text);

    H264Decoder *m_decoder;
    mosquitto *m_mosquitto = nullptr;
    std::atomic_bool m_connected{false};
    bool m_loopStarted = false;
    bool m_telemetryOnline = false;
    bool m_heartbeatEnabled = true;
    QString m_statusText = "未连接";
    QTimer m_heartbeat;
    QTimer m_telemetryWatchdog;
    QSettings m_settings;
    quint16 m_commandSequence = 0;
    quint16 m_videoSequence = 0;
    quint16 m_frameId = 0;
    quint16 m_nextSlice = 0;
    quint32 m_frameTotal = 0;
    QByteArray m_frameBuffer;
};
