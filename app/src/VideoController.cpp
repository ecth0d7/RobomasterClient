#include "VideoController.h"
#include <QHostAddress>
#include <QSet>
#include <cmath>

namespace {
const QStringList publicKeys{"bind","port","codec","source_address","source_port","multicast_group"};
bool integer(const QVariant &value, int minimum, int maximum) {
    if (value.metaType().id()==QMetaType::Bool || value.metaType().id()==QMetaType::QString) return false;
    bool ok=false;const double number=value.toDouble(&ok);
    return ok && std::isfinite(number) && number>=minimum && number<=maximum && std::floor(number)==number;
}
QAbstractSocket::NetworkLayerProtocol addressProtocol(const QHostAddress &address) {
    // The receiver compares IPv4-mapped IPv6 addresses as IPv4 as well.
    bool ipv4=false;
    address.toIPv4Address(&ipv4);
    return ipv4 ? QAbstractSocket::IPv4Protocol : address.protocol();
}
}
VideoController::VideoController(ClientPlugin *factory, ClientBackend *backend,
                                 QVariantMap configuration, QObject *parent, bool startImmediately)
    : VideoEndpoint(parent), m_factory(factory), m_backend(backend), m_configuration(std::move(configuration)) {
    if (!m_configuration.contains("source_address")) m_configuration["source_address"]=QString{};
    if (!m_configuration.contains("source_port")) m_configuration["source_port"]=0;
    if (!m_configuration.contains("multicast_group")) m_configuration["multicast_group"]=QString{};
    connect(backend,&ClientBackend::connectionOptionsChanged,this,&VideoController::configurationChanged);
    connect(backend,&ClientBackend::connectionChanged,this,&VideoController::configurationChanged);
    if (startImmediately) replace(m_configuration,true);
    else m_configurationStatus = QStringLiteral("2027图传包头／接口待核实，未启动UDP监听；配置仅是本地草稿");
}
VideoController::~VideoController() {
    blockSignals(true);
    ++m_generation;
    if(m_endpoint)m_endpoint->disconnect(this);
    m_endpoint.reset();
}
bool VideoController::canConfigure() const {
    return !m_transitioning && (!m_backend || (m_backend->sessionAllowed() && m_backend->canChangeTarget()));
}
QVariantMap VideoController::settings() const {
    QVariantMap result;
    for(const auto &key:publicKeys)result[key]=m_configuration.value(key);
    return result;
}
QVariantMap VideoController::capabilities() const {
    auto result=m_capabilities;
    result["reconfigure"]=true;
    return result;
}
QVariantMap VideoController::diagnostics() const {
    auto result=m_endpoint ? m_endpoint->property("diagnostics").toMap() : QVariantMap{};
    result["stream_generation"]=qulonglong(m_generation);
    result["configured_bind"]=m_configuration.value("bind");
    result["configured_port"]=m_configuration.value("port");
    result["configured_source"]=m_configuration.value("source_address");
    result["configured_source_port"]=m_configuration.value("source_port");
    result["configured_multicast_group"]=m_configuration.value("multicast_group");
    result["configuration_status"]=m_configurationStatus;
    return result;
}
QString VideoController::status() const {
    return m_endpoint ? m_endpoint->status() : m_configurationStatus.isEmpty() ? QStringLiteral("UDP已停止") : m_configurationStatus;
}
double VideoController::fps() const {return m_endpoint ? m_endpoint->fps() : 0;}
bool VideoController::validate(const QVariantMap &configuration, QString *error) {
    const auto fail=[error](const QString &reason){if(error)*error=reason;return false;};
    QHostAddress bind,source,group;
    if(!bind.setAddress(configuration.value("bind").toString()) || bind.isMulticast())return fail("UDP监听地址须为本机单播IP字面量或0.0.0.0／::");
    if(!integer(configuration.value("port"),1,65535))return fail("UDP监听端口须为1–65535");
    if(!QStringList{"hevc","h264","auto"}.contains(configuration.value("codec").toString()))return fail("请选择HEVC、H.264或自动识别");
    const bool hasSource=!configuration.value("source_address").toString().isEmpty();
    if(hasSource && (!source.setAddress(configuration.value("source_address").toString())
        || source.isMulticast() || source==QHostAddress(QHostAddress::Any)
        || source==QHostAddress(QHostAddress::AnyIPv4) || source==QHostAddress(QHostAddress::AnyIPv6)))
        return fail("发送源过滤须为单播IP字面量，留空为自动锁定来源");
    if(hasSource && bind!=QHostAddress(QHostAddress::Any) && addressProtocol(bind)!=addressProtocol(source))
        return fail("发送源与监听地址的IP版本不一致");
    if(!integer(configuration.value("source_port"),0,65535))return fail("发送源端口须为0–65535，0表示不限");
    if(!configuration.value("multicast_group").toString().isEmpty()) {
        if(!group.setAddress(configuration.value("multicast_group").toString()) || !group.isMulticast())return fail("订阅组必须是有效组播地址，单播接收时留空");
        if(bind.protocol()!=group.protocol() && bind!=QHostAddress(QHostAddress::Any))return fail("监听地址与组播组的IP版本不一致");
    }
    if(!source.isNull() && !group.isNull() && addressProtocol(source)!=group.protocol())return fail("发送源与组播组的IP版本不一致");
    return true;
}
bool VideoController::configure(const QVariantMap &options) {
    if(!canConfigure()) {m_configurationStatus="图传会话不可用或正在重建，请稍后重试";emit configurationChanged();return false;}
    auto next=m_configuration;
    for(auto field=options.cbegin();field!=options.cend();++field) {
        if(!publicKeys.contains(field.key())) {m_configurationStatus="未支持的图传配置项："+field.key();emit configurationChanged();return false;}
        next[field.key()]=field.value();
    }
    QString error;
    if(!validate(next,&error)) {m_configurationStatus=error;emit configurationChanged();return false;}
    const auto caps=capabilities();
    if(m_endpoint && ((!caps.value("source_filter").toBool()
        && (!next.value("source_address").toString().isEmpty() || next.value("source_port").toInt()!=0)
        ) || (!caps.value("multicast").toBool() && !next.value("multicast_group").toString().isEmpty()))) {
        m_configurationStatus="当前图传插件未声明来源过滤或组播能力";emit configurationChanged();return false;
    }
    return replace(next,false);
}
bool VideoController::restart() {
    if(!canConfigure()){m_configurationStatus="图传会话不可用或正在重建，请稍后重试";emit configurationChanged();return false;}
    return replace(m_configuration,true);
}
void VideoController::stop() {
    if(m_transitioning)return;
    m_transitioning=true;
    ++m_generation;
    if(m_endpoint)m_endpoint->disconnect(this);
    m_endpoint.reset();
    m_configurationStatus="UDP已停止；可修改配置后重新接收";
    m_transitioning=false;
    QPointer<VideoController> alive(this);
    emit streamReset();
    if(!alive)return;
    emit configurationChanged();
    if(alive)emit statisticsChanged();
}
bool VideoController::replace(const QVariantMap &configuration, bool force) {
    if(m_transitioning)return false;
    if(!force && m_endpoint && configuration==m_configuration) {
        m_configurationStatus=QStringLiteral("图传配置有效，继续使用当前图传");
        emit configurationChanged();
        return true;
    }
    QString error;
    if(!m_factory || !validate(configuration,&error)) {
        m_configurationStatus=error.isEmpty() ? QStringLiteral("图传插件工厂不可用") : error;
        emit configurationChanged();return false;
    }
    m_transitioning=true;
    const auto generation=++m_generation;
    if(m_endpoint)m_endpoint->disconnect(this);
    m_endpoint.reset(); // Joins the old bounded worker before releasing its port.
    m_configuration=configuration;
    m_configurationStatus="图传配置已提交，等待插件绑定与有效码流";
    QPointer<VideoController> alive(this);
    emit streamReset();
    if(!alive)return false;
    std::unique_ptr<VideoEndpoint> candidate(m_factory->createVideo(m_configuration));
    if(!alive)return false;
    m_endpoint=std::move(candidate);
    m_transitioning=false;
    if(!m_endpoint) {m_configurationStatus="插件未创建图传端点，可修改配置重试";emit configurationChanged();return false;}
    m_capabilities=m_endpoint->property("configurationCapabilities").toMap();
    // 解码器在丢块或换编码后撤回旧画面；外观、视觉插件和图像提供器共用此边界。
    // 旧插件可以不提供该可选信号，保持SDK兼容。
    if (m_endpoint->metaObject()->indexOfSignal("streamReset()") >= 0)
        connect(m_endpoint.get(), SIGNAL(streamReset()), this, SIGNAL(streamReset()));
    connect(m_endpoint.get(),&VideoEndpoint::frameDecoded,this,[this,generation](const QImage &image){
        if(generation==m_generation && !image.isNull())emit frameDecoded(image);
    });
    connect(m_endpoint.get(),&VideoEndpoint::frameReady,this,[this,generation]{
        if(generation==m_generation)emit frameReady();
    });
    connect(m_endpoint.get(),&VideoEndpoint::statisticsChanged,this,[this,generation]{
        if(generation!=m_generation)return;
        QPointer<VideoController> alive(this);
        emit statisticsChanged();
        if(alive)emit configurationChanged();
    });
    emit configurationChanged();
    if(alive)emit statisticsChanged();
    return bool(alive);
}
