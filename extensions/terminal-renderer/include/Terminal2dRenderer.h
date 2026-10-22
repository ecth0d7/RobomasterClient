#pragma once

#include "ServiceEndpoint.h"
#include <memory>

class Terminal2dRenderer final : public ServiceEndpoint {
    Q_OBJECT
public:
    explicit Terminal2dRenderer(QObject *parent = nullptr);
    ~Terminal2dRenderer() override;
    bool start(const QVariantMap &, QString *error) override;
    void stop() override;
    bool submit(const QVariantMap &, QString *error) override;
    QString status() const override;
    QVariantMap details() const override;
private:
    void schedule();
    void drain(quint64 generation);
    void refresh();
    struct Private;
    std::unique_ptr<Private> d;
};
