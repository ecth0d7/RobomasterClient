#pragma once
#include "ServiceEndpoint.h"
#include <QProcess>
#include <QPointer>
#include <QTemporaryDir>
#include <QElapsedTimer>
#include <QTimer>
#include <QFile>
#include <QSaveFile>
#include <memory>

// 共用调度与播放生命周期；具体后端只配置、生成 WAV 并取消合成。
// 机器人和界面状态不进入此模块。
class QueuedSpeech : public ServiceEndpoint {
    Q_OBJECT
public:
    explicit QueuedSpeech(QObject *parent = nullptr);
    ~QueuedSpeech() override;
    bool start(const QVariantMap &configuration, QString *error) override;
    void stop() override;
    bool submit(const QVariantMap &message, QString *error) override;
    QString status() const override {
        return m_status;
    }
    QVariantMap details() const override;

protected:
    virtual bool configureSynthesizer(const QVariantMap &, QString *) = 0;
    virtual QVariantMap synthesizerDetails() const = 0;
    virtual void launchSynthesizer(const QString &text, const QString &wave,
                                   quint64 generation) = 0;
    virtual void cancelSynthesizer() {
    }
    void launchSynthesisProcess(const QString &program, const QStringList &arguments,
                                const QByteArray &input, quint64 generation);
    void synthesisCompleted(quint64 generation, const QString &error = {});
    bool current(quint64 generation) const {
        return m_active && m_busy && generation == m_generation;
    }

private:
    struct Utterance {
        QString id, text, key;
        int priority;
        qint64 expires;
        bool tone = false;
    };
    void advance();
    void launch(bool playback);
    void launchProcess(bool playback, const QString &program, const QStringList &arguments,
                       const QByteArray &input, quint64 generation);
    void finish(bool success, const QString &error = {});
    void cancelActive();
    void cancelProcess();
    void preparePlayback(quint64 generation);
    void gainStep();
    QString m_player, m_status = "未启用", m_wave;
    QString m_playWave;
    std::unique_ptr<QFile> m_gainInput;
    std::unique_ptr<QSaveFile> m_gainOutput;
    QTimer m_gainTimer;
    qint64 m_gainPosition = 0, m_pcmOffset = 0, m_pcmBytes = 0;
    quint64 m_gainGeneration = 0;
    int m_voiceVolume = 100, m_alertVolume = 100, m_currentVolume = 100;
    bool m_muted = false, m_partialPlayback = false, m_playing = false, m_didPlay = false;
    bool m_cancelledForMute = false;
    QVariantMap m_audioDetails;
    QTemporaryDir m_directory;
    QPointer<QProcess> m_process;
    QList<QPointer<QProcess>> m_retiring;
    QTimer m_deadline;
    QElapsedTimer m_clock;
    QList<Utterance> m_queue;
    QMap<QString, qint64> m_recent;
    Utterance m_current;
    quint64 m_generation = 0, m_dropped = 0;
    int m_timeout = 15000;
    bool m_active = false, m_play = false, m_busy = false;
};
