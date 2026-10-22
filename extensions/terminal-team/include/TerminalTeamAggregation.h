#pragma once
#include "ServiceEndpoint.h"
#include "TerminalTeamProofVerifier.h"
#include <memory>

class TerminalTeamAggregation final : public ServiceEndpoint, public TerminalTeamProofVerifier {
    Q_OBJECT
    Q_INTERFACES(TerminalTeamProofVerifier)
public:
    explicit TerminalTeamAggregation(QObject *parent = nullptr);
    ~TerminalTeamAggregation() override;
    bool start(const QVariantMap &, QString *error) override;
    void stop() override;
    bool submit(const QVariantMap &, QString *error) override;
    QString status() const override;
    QVariantMap details() const override;
    bool verifySourceProof(const QVariantMap &, QVariantMap *, QString *error = nullptr) override;
    bool verifyTeamViewProof(const QVariantMap &, QVariantMap *, QString *error = nullptr) override;
private:
    struct Private;
    std::unique_ptr<Private> d;
};
