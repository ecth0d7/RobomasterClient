#pragma once
#include "ServiceEndpoint.h"
#include <QPointer>
#include <QStringList>

class CodexDecisionRun;

// Optional process provider. Starting/configuring never launches inference.
// Only the already-authorized ServiceHub decision-request enters a fresh run.
class CodexDecision final : public ServiceEndpoint {
    Q_OBJECT
public:
    explicit CodexDecision(QObject *parent = nullptr);
    ~CodexDecision() override;
    bool start(const QVariantMap &configuration, QString *error) override;
    void stop() override;
    bool submit(const QVariantMap &message, QString *error) override;
    QString status() const override { return m_status; }
    QVariantMap details() const override;

private:
    void cancel();
    void failed(const QString &reason);
    bool drainOutput(quint64 generation);
    bool drainError(quint64 generation);
    void finish(quint64 generation, int exitCode, bool normalExit);
    bool resolveReferences(QString *error);
    QStringList arguments(const CodexDecisionRun &run) const;
    QString m_program, m_authHome, m_model, m_reasoning, m_requestId;
    QString m_status = QStringLiteral("未启用");
    int m_timeout = 15000, m_tokenHint = 1200;
    quint64 m_generation = 0;
    bool m_active = false;
    QPointer<CodexDecisionRun> m_run;
    QPointer<QObject> m_retiring;
};
