#include "HeroVideoHost.h"
#include "PacketObservation.h"
#include <QDateTime>
#include <QMetaMethod>
#include <QThread>

HeroVideoHost::HeroVideoHost(EncodedVideoFactory *factory,ClientBackend *backend,
    const QVariant &configuration,std::function<bool()> rulesAllowed,QObject *parent)
    :VideoEndpoint(parent),m_factory(factory),m_backend(backend),m_rulesAllowed(std::move(rulesAllowed)) {
    connect(backend,&ClientBackend::customBytesReceived,this,&HeroVideoHost::receive);
    connect(backend,&ClientBackend::connectionChanged,this,&HeroVideoHost::synchronize);
    connect(backend,&ClientBackend::identityChanged,this,&HeroVideoHost::synchronize);
    connect(backend,&ClientBackend::rulesContextChanged,this,&HeroVideoHost::synchronize);
    auto *state=backend->telemetry();
    connect(state,&TelemetryEndpoint::deployModeChanged,this,&HeroVideoHost::synchronize);
    connect(state,&TelemetryEndpoint::freshnessChanged,this,&HeroVideoHost::synchronize);
    connect(state,&TelemetryEndpoint::robotStaticChanged,this,&HeroVideoHost::synchronize);
    connect(state,&TelemetryEndpoint::gameStatusChanged,this,&HeroVideoHost::synchronize);
    m_timer.setInterval(250);
    connect(&m_timer,&QTimer::timeout,this,&HeroVideoHost::synchronize);m_timer.start();
    if(configuration.isValid() && configuration.metaType().id()!=QMetaType::QVariantMap) {
        m_enabled=false;m_error=QStringLiteral("吊射视频配置需要对象");
    } else if(!configure(configuration.toMap()))m_enabled=false;
}
HeroVideoHost::~HeroVideoHost() {
    blockSignals(true);m_timer.stop();++m_generation;
    if(m_decoder)m_decoder->disconnect(this);
    m_decoder.reset();
}
bool HeroVideoHost::qualified() const {
    if(!m_enabled || !m_factory || !m_backend || !m_backend->connected()
        || !m_backend->sessionAllowed() || !m_rulesAllowed || !m_rulesAllowed()
        || (m_backend->clientId()!=1 && m_backend->clientId()!=101))return false;
    auto *state=m_backend->telemetry();const auto fresh=state->group("fieldFreshness");
    const auto isFresh=[&](const QString &group,const QString &key){
        return fresh.value(group).toMap().value(key)==QLatin1String("fresh");
    };
    const auto own=state->robotStatic();
    const auto subject=own.value("robot_id");
    const auto subjectType=subject.metaType().id();
    // Other static flags can remain fresh after a partial packet changes its
    // subject. Only current, integer own-seat identity may select this display.
    const bool ownSubject=isFresh("robotStatic","robot_id")
        && (subjectType==QMetaType::UInt || subjectType==QMetaType::Int
            || subjectType==QMetaType::ULongLong || subjectType==QMetaType::LongLong)
        && subject.toULongLong()==quint64(m_backend->clientId());
    return ownSubject && isFresh("deployMode","status") && state->deployMode().value("status")==1
        && isFresh("gameStatus","current_stage") && state->gameStatus().value("current_stage")==4
        && isFresh("robotStatic","alive_state") && own.value("alive_state")==1
        && isFresh("robotStatic","connection_state") && own.value("connection_state")==1
        && isFresh("robotStatic","field_state") && own.value("field_state")==0;
}
QString HeroVideoHost::status() const {
    if(!m_error.isEmpty())return m_error;
    if(!available())return QStringLiteral("当前图传插件不支持吊射字节流");
    if(!m_enabled)return QStringLiteral("吊射视频已关闭");
    if(!m_decoder)return QStringLiteral("等待英雄部署");
    return m_decoder->status();
}
QVariantMap HeroVideoHost::diagnostics() const {
    auto d=m_decoder?m_decoder->property("diagnostics").toMap():QVariantMap{};
    d["active"]=active();d["frame_available"]=m_haveFrame;d["format"]=m_format;
    d["robot_id"]=m_robot;d["generation"]=m_generation;d["received_packets"]=m_received;
    d["rejected_packets"]=m_rejected;d["duplicate_packets"]=m_duplicates;
    d["input_transport"]="CustomByteBlock";return d;
}
bool HeroVideoHost::configure(const QVariantMap &configuration) {
    bool enabled=m_enabled;QString format=m_format;
    for(auto it=configuration.cbegin();it!=configuration.cend();++it) {
        if(it.key()==QLatin1String("enabled") && it->metaType().id()==QMetaType::Bool)enabled=it->toBool();
        else if(it.key()==QLatin1String("format") && it->metaType().id()==QMetaType::QString
            && QStringList{"annexb","compact"}.contains(it->toString()))format=it->toString();
        else {m_error=QStringLiteral("吊射视频仅接受enabled布尔值及annexb/compact格式");emit statisticsChanged();return false;}
    }
    if(m_transitioning || (enabled && m_backend && m_backend->connected() && !m_backend->canChangeTarget()
        && (enabled!=m_enabled || format!=m_format))) {
        m_error=QStringLiteral("请在准备阶段修改吊射视频格式");emit statisticsChanged();return false;
    }
    const bool changed=enabled!=m_enabled || format!=m_format;
    m_enabled=enabled;m_format=format;m_error.clear();
    QPointer<HeroVideoHost> alive(this);
    if(changed)retire();
    if(alive)synchronize();
    // A valid unchanged configuration can still clear an earlier error while
    // inactive, where no decoder statistics would notify the UI afterwards.
    if(alive)emit statisticsChanged();
    return bool(alive);
}
void HeroVideoHost::clearFrame() {
    m_haveFrame=false;
    QPointer<HeroVideoHost> alive(this);emit streamReset();
    if(alive)emit statisticsChanged();
}
void HeroVideoHost::retire() {
    ++m_generation;m_robot=0;m_packets.reset();m_observationSession.clear();m_lastIngress=0;m_lastDropped=0;
    auto retired=std::move(m_decoder);
    if(retired)retired->disconnect(this);
    retired.reset();
    clearFrame();
}
void HeroVideoHost::stop() {retire();}
void HeroVideoHost::synchronize() {
    if(m_transitioning)return;
    if(!qualified()) {if(m_decoder)retire();return;}
    if(m_decoder && m_robot!=m_backend->clientId()) {
        QPointer<HeroVideoHost> alive(this);retire();if(!alive)return;
    }
    if(!m_decoder) {
        m_transitioning=true;
        QPointer<HeroVideoHost> alive(this);
        std::unique_ptr<VideoEndpoint> candidate(m_factory->createEncodedVideo({{"codec","h264"}}));
        if(!alive)return;
        if(!candidate || candidate->parent() || candidate->thread()!=thread()
            || !qobject_cast<EncodedVideoInput*>(candidate.get())
            || candidate->metaObject()->indexOfSignal("streamReset()")<0) {
            m_error=QStringLiteral("吊射解码端点不满足字节流契约");m_transitioning=false;
            m_enabled=false;emit statisticsChanged();return;
        }
        m_decoder=std::move(candidate);m_robot=m_backend->clientId();m_transitioning=false;
        m_packets.setFormat(m_format==QLatin1String("compact")?HeroLob::PacketFormat::CompactH264:HeroLob::PacketFormat::AnnexBStream);
        const auto generation=++m_generation;
        connect(m_decoder.get(),&VideoEndpoint::frameDecoded,this,[this,generation](const QImage &image){
            if(generation!=m_generation || !qualified())return;
            const bool changed=!m_haveFrame;m_haveFrame=true;QPointer<HeroVideoHost> alive(this);
            emit frameDecoded(image);if(alive && changed)emit statisticsChanged();
        });
        connect(m_decoder.get(),&VideoEndpoint::frameReady,this,[this,generation]{if(generation==m_generation && m_haveFrame)emit frameReady();});
        connect(m_decoder.get(),&VideoEndpoint::statisticsChanged,this,&HeroVideoHost::statisticsChanged);
        const int signal=m_decoder->metaObject()->indexOfSignal("streamReset()");
        connect(m_decoder.get(),m_decoder->metaObject()->method(signal),this,
            metaObject()->method(metaObject()->indexOfSlot("clearFrame()")));
        emit statisticsChanged();
        if(!alive)return;
    }
    if(m_decoder && m_haveFrame) {
        const auto age=m_decoder->property("diagnostics").toMap().value("last_frame_age_ms");
        if(!age.isValid() || age.toLongLong()>1500) {
            // Retire parser/reference state as well as the displayed frame.
            // A later encoder restart must not finish an old partial access
            // unit and publish it as a newly received deployment image.
            m_packets.reset();
            qobject_cast<EncodedVideoInput*>(m_decoder.get())->submitEncoded({},true);
        }
    }
}
void HeroVideoHost::receive(const QByteArray &bytes,const QVariantMap &observation) {
    QPointer<HeroVideoHost> alive(this);synchronize();
    if(!alive || !m_decoder || !qualified())return;
    ++m_received;
    PacketObservation::Stamp stamp;qint64 age=0;
    if(!PacketObservation::parse(observation,&stamp) || stamp.basis!=QLatin1String("mqtt_callback")
        || !PacketObservation::validateAt(stamp,QDateTime::currentMSecsSinceEpoch(),PacketObservation::steadyMilliseconds(),&age)
        || age>1500 || (!m_observationSession.isEmpty() && stamp.session!=m_observationSession)
        || stamp.sequence<=m_lastIngress) {
        ++m_rejected;m_packets.reset();
        auto *input=qobject_cast<EncodedVideoInput*>(m_decoder.get());input->submitEncoded({},true);return;
    }
    m_observationSession=stamp.session;m_lastIngress=stamp.sequence;
    const auto dropped=m_backend->receiveDiagnostics().value("dropped").toULongLong();
    if(dropped>m_lastDropped)
        m_packets.reset();
    m_lastDropped=dropped;
    const auto result=m_packets.receive(bytes);
    if(result.status==HeroLob::PacketStatus::Duplicate){++m_duplicates;return;}
    if(result.status==HeroLob::PacketStatus::Invalid)++m_rejected;
    auto *input=qobject_cast<EncodedVideoInput*>(m_decoder.get());
    const auto generation=m_generation;
    if(!input->submitEncoded(result.bytes,result.discontinuity) && alive && generation==m_generation) {
        ++m_rejected;m_packets.reset();
    }
}
