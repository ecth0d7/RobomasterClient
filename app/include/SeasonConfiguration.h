#pragma once

#include <QObject>
#include <QPointer>
#include <QVariantList>
#include <QVariantMap>

class ClientBackend;
class OperatorPreferences;
class TerminalDataBus;

// Rules are independent from the wire codec. Selecting a rule book must never
// turn a 2026 packet or permission into a 2027 packet or permission.
class SeasonConfiguration final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList profiles READ profiles CONSTANT)
    Q_PROPERTY(QVariantMap current READ current NOTIFY contextChanged)
    Q_PROPERTY(QVariantMap context READ context NOTIFY contextChanged)
    Q_PROPERTY(QVariantList opportunities READ opportunities NOTIFY contextChanged)
    Q_PROPERTY(QString profileId READ profileId NOTIFY contextChanged)
    Q_PROPERTY(QString environment READ environment NOTIFY contextChanged)
    Q_PROPERTY(bool editable READ editable NOTIFY stateChanged)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    Q_PROPERTY(bool officialConnectionAllowed READ officialConnectionAllowed NOTIFY stateChanged)
    Q_PROPERTY(QString connectionReason READ connectionReason NOTIFY stateChanged)
    Q_PROPERTY(QObject *terminalBus READ terminalBus CONSTANT)
public:
    SeasonConfiguration(ClientBackend *backend, OperatorPreferences *preparation,
                        QString codecId, QString file, QObject *parent = nullptr);
    QVariantList profiles() const;
    QVariantMap current() const;
    QVariantMap context() const;
    QVariantList opportunities() const;
    QString profileId() const { return m_profile; }
    QString environment() const { return m_environment; }
    bool editable() const { return lockReason().isEmpty(); }
    QString lockReason() const;
    QString status() const { return m_status; }
    bool officialConnectionAllowed() const { return connectionReason().isEmpty(); }
    QString connectionReason() const;
    QObject *terminalBus() const;
    // These are host policy decisions, not writable QML capability flags.
    QString optionalServiceBlockReason(const QString &role, const QString &pluginId) const;
    QString inferenceBlockReason(const QVariantMap &providerDetails) const;
    Q_INVOKABLE bool apply(const QString &profileId, const QString &environment);
    Q_INVOKABLE QVariantMap estimateLogistics(double currentBaseHealth) const;
    Q_INVOKABLE QVariantMap estimateTerritoryRate(bool bothOutposts, bool bothBases) const;
    Q_INVOKABLE bool seedLocalDemo();
    Q_INVOKABLE void clearLocalDemo();
signals:
    // The host retires old requests, credentials and source scopes before the
    // new context can be consumed. This signal never means "connect now".
    void aboutToChange();
    void contextChanged();
    void stateChanged();
private:
    void load();
    bool save(const QString &profile, const QString &environment, QString *error) const;
    QPointer<ClientBackend> m_backend;
    QPointer<OperatorPreferences> m_preparation;
    QPointer<TerminalDataBus> m_bus;
    QString m_codec, m_file, m_profile, m_environment = "training", m_status;
    bool m_valid = true, m_changing = false;
    quint64 m_revision = 1;
};
