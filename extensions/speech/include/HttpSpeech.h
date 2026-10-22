#pragma once
#include "QueuedSpeech.h"
#include <QNetworkAccessManager>
#include <QNetworkReply>

// 通过常驻本地 Piper 服务异步合成，并与进程合成器
// 共用队列和播放生命周期。
class HttpSpeech final : public QueuedSpeech {
    Q_OBJECT
public:
    using QueuedSpeech::QueuedSpeech;
    ~HttpSpeech() override {
        blockSignals(true);
        stop();
    }

protected:
    bool configureSynthesizer(const QVariantMap &configuration, QString *error) override;
    QVariantMap synthesizerDetails() const override;
    void launchSynthesizer(const QString &text, const QString &wave, quint64 generation) override;
    void cancelSynthesizer() override;

private:
    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_reply;
    QUrl m_endpoint;
    QString m_voice;
    QByteArray m_audio;
    static constexpr qsizetype MaximumAudio = 8 * 1024 * 1024;
};
