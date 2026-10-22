#include "HttpSpeech.h"
#include <QHostAddress>
#include <QJsonDocument>
#include <QFile>
#include <QNetworkRequest>

bool HttpSpeech::configureSynthesizer(const QVariantMap &configuration, QString *error) {
    m_endpoint = QUrl(configuration.value("endpoint").toString());
    m_voice = configuration.value("model").toString().trimmed();
    const bool loopback =
        QHostAddress(m_endpoint.host()).isLoopback() || m_endpoint.host() == "localhost";
    if (!m_endpoint.isValid() || !loopback || m_endpoint.scheme() != "http" ||
        !m_endpoint.userInfo().isEmpty() || !m_endpoint.fragment().isEmpty() ||
        !m_endpoint.query().isEmpty() || m_voice.size() > 128) {
        if (error)
            *error = "Piper speech requires a local HTTP endpoint and bounded optional voice id";
        return false;
    }
    return true;
}
QVariantMap HttpSpeech::synthesizerDetails() const {
    return {{"engine", "piper-http"},
            {"voice", m_voice.isEmpty() ? QString("服务默认音色") : m_voice},
            {"endpoint", m_endpoint.toString()}};
}
void HttpSpeech::cancelSynthesizer() {
    auto reply = m_reply;
    m_reply = nullptr;
    if (reply) {
        reply->abort();
        reply->deleteLater();
    }
    m_audio.clear();
}
void HttpSpeech::launchSynthesizer(const QString &text, const QString &wave, quint64 generation) {
    QVariantMap body{{"text", text}};
    if (!m_voice.isEmpty())
        body["voice"] = m_voice;
    QNetworkRequest request(m_endpoint);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Accept", "audio/wav");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::ManualRedirectPolicy);
    m_audio.clear();
    m_reply =
        m_network.post(request, QJsonDocument::fromVariant(body).toJson(QJsonDocument::Compact));
    m_reply->setReadBufferSize(MaximumAudio + 1);
    connect(m_reply, &QNetworkReply::readyRead, this, [this, generation] {
        if (!current(generation) || !m_reply)
            return;
        const auto bytes = m_reply->readAll();
        if (m_audio.size() + bytes.size() > MaximumAudio) {
            synthesisCompleted(generation, "语音音频超过 8 MiB");
            return;
        }
        m_audio += bytes;
    });
    connect(m_reply, &QNetworkReply::finished, this, [this, generation, wave] {
        if (!current(generation) || !m_reply)
            return;
        const int status = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status < 200 || status >= 300) {
            synthesisCompleted(generation, status ? QString("语音服务 HTTP %1").arg(status)
                                                  : QString("语音服务连接失败"));
            return;
        }
        if (m_reply->error() != QNetworkReply::NoError) {
            synthesisCompleted(generation, "语音音频接收失败");
            return;
        }
        QFile output(wave);
        if (!output.open(QIODevice::WriteOnly) || output.write(m_audio) != m_audio.size()) {
            synthesisCompleted(generation, "无法保存语音音频");
            return;
        }
        output.close();
        m_reply->deleteLater();
        m_reply = nullptr;
        m_audio.clear();
        synthesisCompleted(generation);
    });
}
