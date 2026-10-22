#pragma once
#include <QObject>
#include <QPointer>
#include <QVariantMap>
#include <QVariantList>

class ClientBackend;
class OperatorActions;

// Local operator setup, scoped to robot AND player endpoint AND protocol.
// Preferences grant no server-side authority and never publish robot commands.
class OperatorPreferences final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap values READ values NOTIFY valuesChanged)
    Q_PROPERTY(bool editable READ editable NOTIFY stateChanged)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    Q_PROPERTY(int clientId READ clientId NOTIFY scopeChanged)
    Q_PROPERTY(QString targetLabel READ targetLabel NOTIFY scopeChanged)
public:
    OperatorPreferences(ClientBackend *backend, OperatorActions *actions,
                        QVariantMap startupValues, QString protocolId, QString file,
                        QObject *parent = nullptr);
    QVariantMap values() const { return m_values; }
    bool editable() const { return lockReason().isEmpty(); }
    QString lockReason() const;
    QString status() const { return m_status; }
    int clientId() const { return m_scope.value("robot_id").toInt(); }
    QString targetLabel() const;
    Q_INVOKABLE bool apply(const QVariantMap &values);
    Q_INVOKABLE bool reload();
signals:
    void stateChanged();
    void valuesChanged();
    void scopeChanged();
private:
    QVariantMap currentScope() const;
    void synchronize();
    bool loadScope(bool notifyScope);
    bool readProfiles(QVariantList *profiles, QString *error) const;
    bool writeProfile(const QVariantMap &scope, const QVariantMap &values, QString *error);
    QPointer<ClientBackend> m_backend;
    QPointer<OperatorActions> m_actions;
    QVariantMap m_startupValues, m_scope, m_values;
    QString m_protocol, m_file, m_startupHost, m_status;
    int m_startupPort = 0, m_startupRobot = 0;
    quint64 m_revision = 0;
    bool m_saving = false;
};
