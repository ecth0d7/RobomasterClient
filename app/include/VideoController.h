#pragma once
#include "ClientPlugin.h"
#include "ClientBackend.h"
#include <QPointer>
#include <memory>

// Stable QML-facing facade. Rebinding retires an entire plugin endpoint so old
// socket, decoder, and queued frame callbacks cannot leak into the new stream.
class VideoController final : public VideoEndpoint {
    Q_OBJECT
    Q_PROPERTY(QVariantMap settings READ settings NOTIFY configurationChanged)
    Q_PROPERTY(QVariantMap capabilities READ capabilities NOTIFY configurationChanged)
    Q_PROPERTY(QVariantMap diagnostics READ diagnostics NOTIFY statisticsChanged)
    Q_PROPERTY(bool running READ running NOTIFY configurationChanged)
    Q_PROPERTY(bool canConfigure READ canConfigure NOTIFY configurationChanged)
    Q_PROPERTY(QString configurationStatus READ configurationStatus NOTIFY configurationChanged)
public:
    VideoController(ClientPlugin *factory, ClientBackend *backend, QVariantMap configuration,
                    QObject *parent = nullptr, bool startImmediately = true);
    ~VideoController() override;
    QString status() const override;
    double fps() const override;
    QVariantMap settings() const;
    QVariantMap capabilities() const;
    QVariantMap diagnostics() const;
    bool running() const { return bool(m_endpoint); }
    bool canConfigure() const;
    QString configurationStatus() const { return m_configurationStatus; }
    Q_INVOKABLE bool configure(const QVariantMap &options);
    Q_INVOKABLE bool restart();
    Q_INVOKABLE void stop();
signals:
    void configurationChanged();
    void streamReset();
private:
    bool replace(const QVariantMap &configuration, bool force);
    static bool validate(const QVariantMap &configuration, QString *error);
    ClientPlugin *m_factory;
    QPointer<ClientBackend> m_backend;
    QVariantMap m_configuration;
    QVariantMap m_capabilities;
    std::unique_ptr<VideoEndpoint> m_endpoint;
    QString m_configurationStatus;
    quint64 m_generation = 0;
    bool m_transitioning = false;
};
