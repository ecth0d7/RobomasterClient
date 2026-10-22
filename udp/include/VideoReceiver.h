#pragma once
#include <QObject>
#include <QThread>
#include <QElapsedTimer>
#include <QImage>
#include "ClientPlugin.h"
#include "EncodedVideoEndpoint.h"

class VideoImageProvider;
class VideoWorker;
class VideoReceiver : public VideoEndpoint, public EncodedVideoInput {
    Q_OBJECT
    Q_INTERFACES(EncodedVideoInput)
    Q_PROPERTY(QVariantMap diagnostics READ diagnostics NOTIFY statisticsChanged)
    Q_PROPERTY(QVariantMap configurationCapabilities READ configurationCapabilities CONSTANT)
public:
    VideoReceiver(VideoImageProvider *provider, const QVariantMap &configuration,
                  QObject *parent = nullptr);
    VideoReceiver(VideoImageProvider *provider, const QString &bindAddress, quint16 port,
                  const QString &codec, QObject *parent = nullptr);
    ~VideoReceiver() override;
    QString status() const override {
        return m_status;
    }
    double fps() const override {
        return m_fps;
    }
    QVariantMap diagnostics() const;
    QVariantMap configurationCapabilities() const;
    bool submitEncoded(const QByteArray &bytes, bool discontinuity) override;
signals:
    void streamReset();

private:
    QThread m_thread;
    VideoWorker *m_worker;
    VideoImageProvider *m_provider;
    QString m_status = "等待码流";
    QVariantMap m_diagnostics;
    double m_fps = 0;
    int m_frames = 0;
    qint64 m_lastFrame = -1;
    QSize m_presentedSize;
    qint64 m_lastQueueAge = -1, m_maxQueueAge = 0;
    QElapsedTimer m_clock, m_fpsClock;
    bool m_encodedMode = false;
    quint64 m_encodedEpoch = 0;
    quint64 m_lastImageRecovery = 0;
    quint64 m_expiredUiFrames = 0;
};
