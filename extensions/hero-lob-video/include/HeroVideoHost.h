#pragma once
#include "ClientBackend.h"
#include "EncodedVideoEndpoint.h"
#include "HeroVideoPackets.h"
#include <QPointer>
#include <QTimer>
#include <functional>

// Own-seat display feature. It cannot publish commands or open another broker.
class HeroVideoHost final : public VideoEndpoint {
    Q_OBJECT
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool enabled READ enabled NOTIFY statisticsChanged)
    Q_PROPERTY(bool active READ active NOTIFY statisticsChanged)
    Q_PROPERTY(bool frameAvailable READ frameAvailable NOTIFY statisticsChanged)
    Q_PROPERTY(QString format READ format NOTIFY statisticsChanged)
    Q_PROPERTY(QString imageProvider READ imageProvider CONSTANT)
    Q_PROPERTY(QVariantMap diagnostics READ diagnostics NOTIFY statisticsChanged)
public:
    HeroVideoHost(EncodedVideoFactory *factory,ClientBackend *backend,const QVariant &configuration,
                  std::function<bool()> rulesAllowed,QObject *parent=nullptr);
    ~HeroVideoHost() override;
    bool available() const {return m_factory!=nullptr;}
    bool enabled() const {return m_enabled;}
    bool active() const {return bool(m_decoder);}
    bool frameAvailable() const {return m_haveFrame;}
    QString format() const {return m_format;}
    QString imageProvider() const {return QStringLiteral("heroVideoProvider");}
    QString status() const override;
    double fps() const override {return m_decoder?m_decoder->fps():0;}
    QVariantMap diagnostics() const;
    Q_INVOKABLE bool configure(const QVariantMap &configuration);
    void stop();
signals:
    void streamReset();
private slots:
    void synchronize();
    void receive(const QByteArray &bytes,const QVariantMap &observation);
    void clearFrame();
private:
    bool qualified() const;
    void retire();
    EncodedVideoFactory *m_factory=nullptr;
    QPointer<ClientBackend> m_backend;
    std::function<bool()> m_rulesAllowed;
    std::unique_ptr<VideoEndpoint> m_decoder;
    HeroLob::PacketStream m_packets{HeroLob::PacketFormat::AnnexBStream};
    QTimer m_timer;
    bool m_enabled=true,m_haveFrame=false,m_transitioning=false;
    QString m_format="annexb",m_error,m_observationSession;
    quint64 m_generation=0,m_received=0,m_rejected=0,m_duplicates=0,m_lastDropped=0;
    qint64 m_lastIngress=0;
    int m_robot=0;
};
