#pragma once
#include "QueuedSpeech.h"

class EspeakSpeech final : public QueuedSpeech {
    Q_OBJECT
public:
    using QueuedSpeech::QueuedSpeech;
    ~EspeakSpeech() override {
        blockSignals(true);
        stop();
    }

protected:
    bool configureSynthesizer(const QVariantMap &configuration, QString *error) override;
    QVariantMap synthesizerDetails() const override;
    void launchSynthesizer(const QString &text, const QString &wave, quint64 generation) override;

private:
    QString m_executable, m_voice;
    int m_speed = 175;
};
