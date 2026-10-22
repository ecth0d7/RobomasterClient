#pragma once
#include <QObject>
#include <QPointer>
#include <QVariantMap>

class ClientBackend;
class OperatorPreferences;
class ProviderConfiguration;
class ServiceHub;

// Saved intent is scoped to the selected player endpoint and robot. It never
// grants robot command authority or turns a raw bridge peer into a team view.
class DecisionConfiguration final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap current READ current NOTIFY currentChanged)
    Q_PROPERTY(QVariantMap state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool editable READ editable NOTIFY stateChanged)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
public:
    DecisionConfiguration(ClientBackend *, OperatorPreferences *, ProviderConfiguration *,
                          ServiceHub *, QString file, QString protocol, QObject *parent = nullptr);
    QVariantMap current() const {
        return m_values;
    }
    QVariantMap state() const;
    bool editable() const {
        return lockReason().isEmpty();
    }
    QString lockReason() const;
    QString status() const {
        return m_status;
    }
    quint64 revision() const {
        return m_revision;
    }
    Q_INVOKABLE bool save(const QVariantMap &values);
    static QVariantMap defaults();
    static bool validate(const QVariantMap &, QString *error = nullptr);
signals:
    void currentChanged();
    void scopeChanged();
    void stateChanged();

private:
    QVariantMap scope() const;
    void synchronize();
    bool readProfiles(QVariantList *, QString *) const;
    bool writeProfile(const QVariantMap &, QString *);
    QPointer<ClientBackend> m_backend;
    QPointer<OperatorPreferences> m_phase;
    QPointer<ProviderConfiguration> m_provider;
    QPointer<ServiceHub> m_services;
    QVariantMap m_scope, m_values;
    QString m_file, m_protocol, m_status;
    quint64 m_revision = 0;
    bool m_saving = false;
};
