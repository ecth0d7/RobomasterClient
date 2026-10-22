#pragma once
#include "ServiceEndpoint.h"
#include <QPointer>

// Host-owned facade. The provider owns neither this facade nor the transferred
// inner endpoint. Revocation runs before the package session's stop().
class LeaseServiceEndpoint final : public ServiceEndpoint {
public:
    LeaseServiceEndpoint(ServiceEndpoint *, QVariantMap identity);
    ~LeaseServiceEndpoint() override;
    bool start(const QVariantMap &, QString *) override;
    void stop() override;
    bool submit(const QVariantMap &, QString *) override;
    QString status() const override;
    QVariantMap details() const override;
    void revoke(const QString &reason);
    ServiceEndpoint *transferredEndpoint() const { return m_inner.data(); }
private:
    bool reject(QString *) const;
    void disposeInner();
    QPointer<ServiceEndpoint> m_inner;
    QVariantMap m_identity;
    QString m_retiredReason;
    bool m_providerActive = true, m_stopping = false, m_destroying = false;
};
