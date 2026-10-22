#pragma once

#include <QObject>
#include <QPointer>
#include <QVariantMap>

class ClientBackend;
class PluginRuntime;
class ServiceHub;
class OperatorPreferences;

// Saved team membership is exact-scope intent, never an automatic connection.
// Credential contents and the resolved signing-key path are kept outside QML.
class TeamConfiguration final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap current READ current NOTIFY currentChanged)
    Q_PROPERTY(QVariantMap state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool editable READ editable NOTIFY stateChanged)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
public:
    TeamConfiguration(ClientBackend *, PluginRuntime *, ServiceHub *, OperatorPreferences *,
                      QString file, QString protocol, QObject *parent = nullptr);
    QVariantMap current() const { return m_values; }
    QVariantMap state() const;
    bool editable() const { return lockReason().isEmpty(); }
    QString lockReason() const;
    QString status() const { return m_status; }
    quint64 revision() const { return m_revision; }
    Q_INVOKABLE bool save(const QVariantMap &values);
    // Native-only activation gate, also used by PluginRuntime's enable action.
    // A durable lease is consumed before any plugin factory can start a node.
    bool authorizeActivation(const QVariantMap &runtimeConfig, QString *error);
    static QVariantMap defaults();
    static bool validate(const QVariantMap &, int robotId, QString *error = nullptr);
signals:
    void currentChanged();
    void stateChanged();
    void scopeChanged();
private:
    QVariantMap scope() const;
    void synchronize();
    bool readProfiles(QVariantList *, QString *) const;
    bool writeProfile(const QVariantMap &, QString *);
    bool nativeConfiguration(const QVariantMap &, QVariantMap *, QString *) const;
    bool consumeEpoch(const QVariantMap &, QString *);
    QPointer<ClientBackend> m_backend;
    QPointer<PluginRuntime> m_runtime;
    QPointer<ServiceHub> m_services;
    QPointer<OperatorPreferences> m_phase;
    QVariantMap m_scope, m_values;
    QString m_file, m_protocol, m_status, m_activationError;
    quint64 m_revision = 0;
    bool m_saving = false, m_activationReady = false;
};
