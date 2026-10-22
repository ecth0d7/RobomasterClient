#pragma once
#include "OfficialSourceSnapshot.h"
#include "SourceRegistry.h"
#include "ServiceEndpoint.h"
#include "TeamSourceExport.h"
#include <QPointer>
#include <QTimer>
#include <memory>

class ClientBackend;
class DecisionConfiguration;
class TelemetryEndpoint;

// Native owner of independent sources. QML sees diagnostics only; a draft ID or
// a model result cannot create an adapter, grant trust, or write core telemetry.
class DataSourceHost final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString health READ health NOTIFY changed)
    Q_PROPERTY(QString teamExportStatus READ teamExportStatus NOTIFY changed)
    Q_PROPERTY(bool editable READ editable NOTIFY changed)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY changed)
    Q_PROPERTY(QVariantList adapters READ adapters NOTIFY changed)
    Q_PROPERTY(QVariantList sources READ sources NOTIFY changed)
    Q_PROPERTY(QVariantMap capabilities READ capabilities CONSTANT)
    Q_PROPERTY(QVariantMap localView READ localView NOTIFY changed)
public:
    explicit DataSourceHost(ClientBackend *, QObject *parent = nullptr);
    ~DataSourceHost() override;
    void setDecisionConfiguration(DecisionConfiguration *);
    void setPhaseGuard(QObject *);
    void setRulesContext(const QVariantMap &context);
    // Copy only public disclosure/category settings, never TLS/private-key refs.
    void setSharingConfiguration(const QVariantMap &nativeTeamConfiguration);
    bool startSource(std::unique_ptr<ServiceEndpoint>, const QVariantMap &descriptor,
                     const QVariantMap &configuration, QString *error = nullptr);
    void retireSource(const QString &sourceId);
    QVariantMap teamSnapshot(QString *error = nullptr);
    void resetTeamExport(); // New aggregation node session only.
    QVariantMap localView() const;
    QVariantList sources() const;
    QVariantList adapters() const { return {}; } // No real device adapter installed yet.
    QVariantMap capabilities() const;
    QString status() const { return m_status; }
    QString health() const { return m_health; }
    QString teamExportStatus() const { return m_teamExportStatus; }
    bool editable() const;
    QString lockReason() const;
signals:
    void changed();
private:
    struct Source;
    void refresh();
    void retireOfficial();
    void synchronizeRobot();
    void stopSources();
    void setStatus(const QString &, const QString &);
    QPointer<ClientBackend> m_backend;
    QPointer<TelemetryEndpoint> m_state;
    QPointer<DecisionConfiguration> m_decision;
    QPointer<QObject> m_phase;
    SourceRegistry m_registry;
    OfficialSourceSnapshot m_official;
    TeamSourceExport::VersionLedger m_exportVersions;
    QMap<QString, std::shared_ptr<Source>> m_sources;
    QMap<QString, quint64> m_sourceRevisions;
    QVariantMap m_share, m_officialDescriptor, m_rulesContext;
    QTimer m_timer;
    QString m_status, m_health = QStringLiteral("waiting");
    QString m_teamExportStatus = QStringLiteral("队伍导出未启用；本机视图独立");
    QString m_officialSession, m_exportId;
    quint64 m_officialGeneration = 0;
    quint64 m_authorizationRevision = 0;
    int m_robot = 0;
};
