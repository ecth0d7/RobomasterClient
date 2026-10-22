#pragma once
#include "ServiceEndpoint.h"
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QPointer>
#include <QTimer>
#include <QElapsedTimer>

class HttpDecision final : public ServiceEndpoint {
    Q_OBJECT
public:
    explicit HttpDecision(QObject *parent = nullptr);
    ~HttpDecision() override;
    bool start(const QVariantMap &configuration, QString *error) override;
    void stop() override;
    bool submit(const QVariantMap &message, QString *error) override;
    QString status() const override {
        return m_status;
    }
    QVariantMap details() const override;

private:
    void cancel();
    void finish(quint64 generation);
    void failed(const QString &reason);
    QByteArray requestBody(const QVariantMap &snapshot, const QString &question) const;
    bool parseAdvice(const QByteArray &response, QVariantMap *advice, QString *error) const;
    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_reply;
    QTimer m_deadline;
    QElapsedTimer m_elapsed;
    QUrl m_endpoint;
    QString m_api, m_model, m_requestId, m_schemaProfile, m_format, m_provider;
    QByteArray m_key, m_response;
    QString m_status = QStringLiteral("未启用");
    int m_timeout = 15000;
    int m_maxOutputTokens = 1200;
    quint64 m_generation = 0;
    bool m_active = false;
    bool m_hasTemperature = false;
    bool m_hasThinking = false, m_thinking = false, m_loopback = false;
    double m_temperature = 0;
    static constexpr qsizetype MaximumResponse = 262144;
};
