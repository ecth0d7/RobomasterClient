#pragma once

#include "ServiceEndpoint.h"
#include <memory>

// Optional team transport/aggregation only. This endpoint owns no official
// connection, telemetry store, robot action or model provider. Host integration
// must recheck purpose permissions and the committed view before AI submission.
class TeamAggregation final : public ServiceEndpoint {
    Q_OBJECT
public:
    explicit TeamAggregation(QObject *parent = nullptr);
    ~TeamAggregation() override;
    bool start(const QVariantMap &configuration, QString *error) override;
    void stop() override;
    bool submit(const QVariantMap &message, QString *error) override;
    QString status() const override;
    QVariantMap details() const override;

private:
    struct Private;
    std::unique_ptr<Private> d;
};
