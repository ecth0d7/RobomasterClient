#include "LeaseServiceEndpoint.h"
#include <utility>

LeaseServiceEndpoint::LeaseServiceEndpoint(ServiceEndpoint *inner, QVariantMap identity)
    : m_inner(inner), m_identity(std::move(identity)) {
    connect(inner, &ServiceEndpoint::statusChanged, this, [this] {
        if (m_providerActive) emit statusChanged();
    });
    connect(inner, &ServiceEndpoint::messageReceived, this, [this](const QVariantMap &message) {
        if (m_providerActive) emit messageReceived(message);
    });
    connect(inner, &ServiceEndpoint::errorOccurred, this, [this](const QString &error) {
        if (m_providerActive) emit errorOccurred(error);
    });
    connect(inner, &QObject::destroyed, this, [this] {
        m_inner = nullptr;
        if (m_providerActive) revoke(QStringLiteral("插件端点已销毁；需要明确重新启用"));
    });
}
LeaseServiceEndpoint::~LeaseServiceEndpoint() {
    m_destroying = true; m_providerActive = false; disposeInner();
}
bool LeaseServiceEndpoint::reject(QString *error) const {
    if (error) *error = m_retiredReason.isEmpty() ? QStringLiteral("插件提供者已退役；旧租约不能重新启用") : m_retiredReason;
    return false;
}
bool LeaseServiceEndpoint::start(const QVariantMap &values, QString *error) {
    if (!m_providerActive || !m_inner) return reject(error);
    QPointer<LeaseServiceEndpoint> alive(this); auto inner = m_inner;
    const bool result = inner->start(values, error);
    return alive && m_providerActive && inner && m_inner == inner && result;
}
void LeaseServiceEndpoint::stop() {
    if (!m_inner || m_stopping) return;
    m_stopping = true;
    QPointer<LeaseServiceEndpoint> alive(this); auto inner = m_inner;
    inner->stop();
    if (alive) m_stopping = false;
}
bool LeaseServiceEndpoint::submit(const QVariantMap &message, QString *error) {
    if (!m_providerActive || !m_inner) return reject(error);
    QPointer<LeaseServiceEndpoint> alive(this); auto inner = m_inner;
    const bool result = inner->submit(message, error);
    return alive && m_providerActive && inner && m_inner == inner && result;
}
QString LeaseServiceEndpoint::status() const {
    return m_providerActive && m_inner ? m_inner->status() : m_retiredReason;
}
QVariantMap LeaseServiceEndpoint::details() const {
    // Read provider values before stamping host-owned identity/availability.
    QPointer<const LeaseServiceEndpoint> alive(this);
    auto result = m_providerActive && m_inner ? m_inner->details() : QVariantMap{};
    if (!alive) return {};
    result["provider_active"] = m_providerActive && bool(m_inner);
    result["provider_identity"] = m_identity;
    if (!m_providerActive || !m_inner) result["active"] = false;
    return result;
}
void LeaseServiceEndpoint::disposeInner() {
    auto inner = m_inner; m_inner = nullptr;
    if (!inner) return;
    disconnect(inner, nullptr, this, nullptr);
    if (m_stopping) {
        // A caller can destroy the facade from a synchronous stop callback.
        // That stop is already in progress; defer destruction until it unwinds.
        inner->deleteLater();
        return;
    }
    inner->stop();
    if (inner) delete inner.data();
}
void LeaseServiceEndpoint::revoke(const QString &reason) {
    if (!m_providerActive) return;
    m_providerActive = false;
    m_retiredReason = reason.left(512);
    QPointer<LeaseServiceEndpoint> alive(this);
    disposeInner();
    if (alive && !m_destroying) emit statusChanged();
}
