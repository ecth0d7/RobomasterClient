#pragma once
#include <QObject>
#include <QPointer>
#include <QVariantMap>
#include <QVariantList>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>

class ClientBackend;
class PluginRuntime;
class ServiceHub;
class OperatorPreferences;

// Public state contains credential references only. Keys are resolved in the
// host immediately before starting an adapter or an explicit catalog request.
class ProviderConfiguration final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap current READ current NOTIFY currentChanged)
    Q_PROPERTY(QVariantMap state READ state NOTIFY stateChanged)
    Q_PROPERTY(QVariantList models READ models NOTIFY modelsChanged)
    Q_PROPERTY(bool editable READ editable NOTIFY stateChanged)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
public:
    void retireForRulesChange();
    ProviderConfiguration(ClientBackend *, PluginRuntime *, ServiceHub *, OperatorPreferences *,
                          QVariantMap startupValues, QString file, QVariantMap startupRuntime = {},
                          QObject *parent = nullptr);
    ~ProviderConfiguration() override;
    QVariantMap current() const {
        return m_current;
    }
    QVariantMap state() const;
    QVariantList models() const {
        return m_models;
    }
    bool editable() const {
        return lockReason().isEmpty();
    }
    QString lockReason() const;
    QString status() const {
        return m_status;
    }
    Q_INVOKABLE bool save(const QVariantMap &values);
    Q_INVOKABLE bool inspect(const QVariantMap &values);
    Q_INVOKABLE bool refreshModels();
    static QVariantMap defaults();
    static bool validate(const QVariantMap &, QString *error);
signals:
    void currentChanged();
    void stateChanged();
    void modelsChanged();
    void scopeChanged();

private:
    void synchronize();
    void load();
    bool activate(QString *error);
    bool readNodes(QVariantMap *nodes, QString *error) const;
    bool writeNode(const QVariantMap &, QString *error);
    void cancelCatalog();
    QString pluginId() const;
    bool pluginAvailable() const;
    QUrl catalogUrl() const;
    QPointer<ClientBackend> m_backend;
    QPointer<PluginRuntime> m_runtime;
    QPointer<ServiceHub> m_services;
    QPointer<OperatorPreferences> m_phase;
    QVariantMap m_startup, m_current, m_startupRuntime;
    QVariantList m_models;
    QString m_file, m_status, m_applyError;
    int m_robot = -1;
    quint64 m_revision = 0, m_catalogGeneration = 0;
    bool m_changing = false, m_usingStartup = false;
    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_catalog;
    QTimer m_deadline;
    QByteArray m_catalogBytes;
};
