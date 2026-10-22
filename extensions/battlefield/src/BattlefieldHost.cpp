#include "BattlefieldHost.h"
#include "ClientBackend.h"
#include "VideoController.h"
#include "PluginHost.h"
#include "ExtensionPlugin.h"
#include "ServiceEndpoint.h"
#include <QBuffer>
#include <QDateTime>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaMethod>
#include <QSettings>
#include <QSaveFile>
#include <QStandardPaths>
#include <QDir>
#include <QFileInfo>
#include <QSet>
#include <cmath>

namespace {
QVariantList ageTracks(const QVariantList &rows, qint64 age) {
    QVariantList result;
    for (const auto &value : rows) {
        auto row=value.toMap();
        const auto remaining=row.value("remaining_ms").toLongLong()-age;
        if (remaining<=0) continue;
        row["remaining_ms"]=remaining;result.append(row);
    }
    return result;
}
}

BattlefieldHost::BattlefieldHost(PluginHost *plugins, QString directory, ClientBackend *backend,
                               VideoController *video, QObject *parent)
    : QObject(parent), m_plugins(plugins), m_directory(std::move(directory)), m_backend(backend), m_video(video) {
    m_configurationFile=QSettings().value("battlefield/configurationFile").toString();
    m_timer.setInterval(250);
    connect(&m_timer, &QTimer::timeout, this, &BattlefieldHost::snapshot);
    connect(video, &VideoEndpoint::frameDecoded, this, &BattlefieldHost::capture);
    connect(video, &VideoController::streamReset, this, [this] {
        submit({{"kind", "stream_reset"}});
        m_view.remove("boxes");
        emit changed();
    });
    connect(backend, &ClientBackend::identityChanged, this, &BattlefieldHost::stop);
    connect(backend, &ClientBackend::rulesContextChanged, this, &BattlefieldHost::stop);
    connect(backend, &ClientBackend::connectionChanged, this, &BattlefieldHost::snapshot);
}
BattlefieldHost::~BattlefieldHost() { blockSignals(true); stop(); }
QVariantMap BattlefieldHost::diagnostics() const {
    auto result=m_endpoint?m_endpoint->details():QVariantMap{};
    result["snapshot_timer_active"]=m_timer.isActive();
    result["configuration_active"]=m_endpoint!=nullptr;
    return result;
}
bool BattlefieldHost::active() const { return m_endpoint && m_endpoint->details().value("active").toBool(); }
QVariantMap BattlefieldHost::projectionConfiguration(const QString &file) const {
    QFile input(file);
    if (!QFileInfo(file).isAbsolute() || !input.open(QIODevice::ReadOnly) || input.size()>128*1024) return {};
    const auto json = QJsonDocument::fromJson(input.readAll());
    return json.object().value("vision").toObject().value("projection").toObject().toVariantMap();
}
QVariantMap BattlefieldHost::identityConfiguration(const QString &file) const {
    QFile input(file);
    if (!QFileInfo(file).isAbsolute() || !input.open(QIODevice::ReadOnly) || input.size()>128*1024) return {};
    const auto json=QJsonDocument::fromJson(input.readAll());
    return json.object().value("vision").toObject().value("identity").toObject().toVariantMap();
}
bool BattlefieldHost::saveProjectionConfiguration(const QString &file, const QVariantMap &values, const QString &modelFile) {
    return saveVisionSection(file,"projection",values,modelFile);
}
bool BattlefieldHost::saveIdentityConfiguration(const QString &file, const QVariantMap &values, const QString &modelFile) {
    return saveVisionSection(file,"identity",values,modelFile);
}
QVariantMap BattlefieldHost::filterConfiguration(const QString &file) const {
    QFile input(file);
    if(!QFileInfo(file).isAbsolute() || !input.open(QIODevice::ReadOnly) || input.size()>128*1024)return {};
    return QJsonDocument::fromJson(input.readAll()).object().value("vision").toObject().value("filter").toObject().toVariantMap();
}
bool BattlefieldHost::saveFilterConfiguration(const QString &file,const QVariantMap &values) {
    return saveVisionSection(file,"filter",values,{});
}
bool BattlefieldHost::saveVisionSection(const QString &file, const QString &section, const QVariantMap &values, const QString &modelFile) {
    auto fail = [this](const QString &reason) { m_status=reason;emit changed();return false; };
    if (!m_backend) return false;
    const QSet<QString> projectionKeys{"enabled","acknowledged","image_model_confirmed","method","frame_id","calibration_id",
        "normalized_intrinsics","camera_height_m","pitch_down_deg","camera_yaw_offset_deg","roll_clockwise_deg",
        "rigid_camera_confirmed","pose_heading_clockwise","forward_offset_m","right_offset_m","pose_uncertainty_m",
        "yaw_uncertainty_deg","pitch_uncertainty_deg","height_uncertainty_m","pixel_uncertainty_normalized",
        "max_target_speed_mps","max_observer_speed_mps","max_observer_yaw_rate_degps","max_camera_yaw_rate_degps","max_range_m","max_uncertainty_m","pose_max_age_ms","distortion",
        "pose_node_id","pose_source_id","pose_target_id","gimbal_node_id","gimbal_source_id","gimbal_target_id"};
    const QSet<QString> identityKeys{"enabled","model_file","confidence","minimum_hits"};
    const QSet<QString> filterKeys{"mode"};
    const auto &allowed=section=="projection"?projectionKeys:section=="filter"?filterKeys:identityKeys;
    if(section=="filter" && (values.value("mode").metaType().id()!=QMetaType::QString ||
        !QStringList{"enemy_and_unknown","all"}.contains(values.value("mode").toString())))
        return fail("请选择敌方与阵营未知，或全部目标");
    if(section=="identity") {
        if(values.value("enabled").metaType().id()!=QMetaType::Bool ||
            values.value("model_file").metaType().id()!=QMetaType::QString)
            return fail("身份辅助需要布尔启用状态和模型路径");
        auto numeric=[](const QVariant &value,double minimum,double maximum,bool whole) {
            const auto type=value.metaType().id();
            if(type!=QMetaType::Int && type!=QMetaType::LongLong && type!=QMetaType::Double && type!=QMetaType::UInt && type!=QMetaType::ULongLong)return false;
            const auto number=value.toDouble();
            return std::isfinite(number) && number>=minimum && number<=maximum && (!whole || std::floor(number)==number);
        };
        if(!numeric(values.value("confidence"),.5,1,false) || !numeric(values.value("minimum_hits"),3,10,true))
            return fail("身份阈值须为0.5至1，连续确认帧数须为3至10的整数");
        const QFileInfo identityModel(values.value("model_file").toString());
        if(values.value("enabled").toBool() && (!identityModel.isAbsolute() || !identityModel.isFile()))
            return fail("身份辅助ONNX路径不可用，未保存配置");
    }
    for(auto it=values.cbegin();it!=values.cend();++it)if(!allowed.contains(it.key()))return fail("视觉配置含未知字段");
    if (QJsonDocument::fromVariant(values).toJson().size()>8192) return fail("视觉配置过大");
    QFile input(file);
    if (!QFileInfo(file).isAbsolute() || !input.open(QIODevice::ReadOnly) || input.size()>128*1024) return fail("请先选择可读取的完整视觉配置JSON");
    QJsonParseError error;
    auto json=QJsonDocument::fromJson(input.readAll(),&error);
    if (error.error!=QJsonParseError::NoError || !json.isObject()) return fail("视觉配置不是JSON对象");
    auto config=json.object().toVariantMap();
    if (config.value("schema")!="rm.situation.config/1") return fail("视觉配置版本不受支持");
    if (section=="projection" && values.value("enabled").toBool() && values.value("frame_id")!=config.value("frame_id"))
        return fail("相机坐标系须与完整态势配置一致，请先统一队内配置；不会替您改名");
    auto vision=config.value("vision").toMap();vision[section]=values;
    if (!modelFile.isEmpty()) {
        const QFileInfo model(modelFile);
        if (!model.isAbsolute() || !model.isFile()) return fail("ONNX模型路径不可用，未保存配置");
        vision["model_file"]=model.absoluteFilePath();
    }
    config["vision"]=vision;
    const auto directory=QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    if (directory.isEmpty() || !QDir().mkpath(directory)) return fail("无法创建本机配置目录");
    const auto destination=directory+"/vision-projection.json";
    if (QFileInfo(destination).isSymLink())return fail("配置目标为符号链接，未覆盖");
    QSaveFile output(destination);
    const auto bytes=QJsonDocument::fromVariant(config).toJson(QJsonDocument::Indented);
    if (bytes.size()>128*1024)return fail("保存后的配置超过128 KiB，未写入");
    if (!output.open(QIODevice::WriteOnly) || !output.setPermissions(QFileDevice::ReadOwner|QFileDevice::WriteOwner) ||
        output.write(bytes)!=bytes.size() || !output.commit()) return fail("视觉配置未保存，旧文件保留");
    m_configurationFile=destination;QSettings().setValue("battlefield/configurationFile",destination);
    m_status="已保存本机视觉配置；点击应用视觉配置后生效，未修改原文件";emit changed();return true;
}
bool BattlefieldHost::startModules(const QString &file,bool vision,bool projectile,bool share,const QString &modelFile) {
    if(active()) {
        QFile source(file);
        if(source.open(QIODevice::ReadOnly) && source.size()<=128*1024) {
            const auto document=QJsonDocument::fromJson(source.readAll());
            auto currentBase=QJsonDocument::fromJson(m_configurationBaseline).object();
            auto nextBase=document.object();
            for(const auto &key:{"vision","projectile","share_vision"}){currentBase.remove(key);nextBase.remove(key);}
            if(document.isObject() && currentBase==nextBase) {
                const auto visionConfiguration=document.object().value("vision").toObject();
                const auto configuredModel=visionConfiguration.value("model_file").toString();
                if(!submit({{"kind","configure_modules"},{"vision",vision},{"projectile",projectile},
                    {"share",share},{"model_file",modelFile.isEmpty()?configuredModel:modelFile},
                    {"vision_configuration",visionConfiguration.toVariantMap()},
                    {"projectile_configuration",document.object().value("projectile").toObject().toVariantMap()}}))return false;
                m_visionEnabled=vision;m_projectileEnabled=projectile;
                m_configurationFile=file;m_configurationBaseline=document.toJson(QJsonDocument::Compact);
                QSettings().setValue("battlefield/configurationFile",file);
                if(!vision)m_view.remove("boxes");
                if(!projectile)m_view.remove("projectile");
                m_status="已提交独立插件启停；队内会话及其它任务保留";
                emit changed();return true;
            }
        }
    }
    m_overrideModules=true;m_requestedVision=vision;m_requestedProjectile=projectile;
    m_requestedShare=share;m_requestedModel=modelFile;
    const bool accepted=start(file);
    m_overrideModules=false;return accepted;
}
bool BattlefieldHost::start(const QString &file) {
    stop();
    QFile input(file);
    if (!input.open(QIODevice::ReadOnly) || input.size() > 128*1024) {
        m_status = QStringLiteral("无法读取态势配置，或文件超过128 KiB"); emit changed(); return false;
    }
    QJsonParseError parse;
    const auto json = QJsonDocument::fromJson(input.readAll(), &parse);
    if (parse.error != QJsonParseError::NoError || !json.isObject()) {
        m_status = QStringLiteral("态势配置不是有效JSON对象"); emit changed(); return false;
    }
    auto config = json.object().toVariantMap();
    if(m_overrideModules) {
        auto vision=config.value("vision").toMap();vision["enabled"]=m_requestedVision;
        if(!m_requestedModel.isEmpty())vision["model_file"]=m_requestedModel;
        config["vision"]=vision;config["share_vision"]=m_requestedShare;
        auto projectile=config.value("projectile").toMap();projectile["enabled"]=m_requestedProjectile;
        projectile["share"]=m_requestedShare;config["projectile"]=projectile;
    }
    QString error;
    auto *factory = m_plugins->loadExtension(m_directory, "situation.process.v1", "battlefield", &error);
    if (!factory) { m_status = QStringLiteral("可选态势插件不可用：")+error; emit changed(); return false; }
    std::unique_ptr<ServiceEndpoint> endpoint(factory->createService());
    if (!endpoint) { m_status = QStringLiteral("态势工厂未提供端点"); emit changed(); return false; }
    const auto generation = ++m_generation;
    connect(endpoint.get(), &ServiceEndpoint::messageReceived, this, [this, generation](const QVariantMap &message) {
        if (generation != m_generation) return;
        const auto schema = message.value("schema").toString();
        if (schema == "rm.situation.view/1") {
            const auto age = QDateTime::currentMSecsSinceEpoch()-message.value("stamp_ms").toLongLong();
            if (age < -250 || age > 1500) { m_view.clear(); emit changed(); return; }
            auto aged=message;
            const auto now=QDateTime::currentMSecsSinceEpoch();
            if (aged.value("advice").toMap().value("expires_ms").toLongLong()<=now) aged["advice"]=QVariantMap{};
            aged["tracks"]=ageTracks(aged.value("tracks").toList(),qMax<qint64>(0,age));
            QVariantList boxes;
            for (const auto &entry : aged.value("boxes").toList()) {
                auto box=entry.toMap();
                const auto frameAge=now-box.value("stamp_ms").toLongLong();
                if (frameAge<0 || frameAge>1500) continue;
                box["age_ms"]=frameAge;box["occluded"]=frameAge>500;
                box["confidence"]=box.value("confidence").toDouble()*std::exp(-qMax<qint64>(0,age)/1500.0);
                boxes.append(box);
            }
            aged["boxes"]=boxes;
            auto projectile=aged.value("projectile").toMap();
            QVariantList trajectories;
            for (const auto &entry : projectile.value("tracks").toList()) {
                auto track=entry.toMap();const auto trackAge=now-track.value("stamp_ms").toLongLong();
                if(trackAge<0 || trackAge>450)continue;
                track["age_ms"]=trackAge;trajectories.append(track);
            }
            projectile["tracks"]=trajectories;aged["projectile"]=projectile;
            QVariantList peers;
            for (const auto &entry : aged.value("peer_views").toList()) {
                auto peer=entry.toMap();
                const auto remaining=peer.value("remaining_ms").toLongLong()-qMax<qint64>(0,age);
                if (remaining<=0) continue;
                peer["remaining_ms"]=remaining;peer["tracks"]=ageTracks(peer.value("tracks").toList(),qMax<qint64>(0,age));peers.append(peer);
            }
            aged["peer_views"]=peers;
            m_view = aged; m_status = QStringLiteral("态势运行中 · 只读采集与队内共享");
        }
        else if (schema == "rm.situation.error/1") { m_status = QStringLiteral("态势进程启动或运行失败：")+message.value("error").toString(); }
        emit changed();
    });
    connect(endpoint.get(), &ServiceEndpoint::errorOccurred, this, [this, generation](const QString &error) {
        if (generation != m_generation) return;
        m_view.clear(); m_status = error; m_timer.stop(); emit changed();
    });
    if (!endpoint->start(config, &error)) { m_status = error; emit changed(); return false; }
    m_projectileEnabled = config.value("projectile").toMap().value("enabled").toBool();
    m_visionEnabled = config.value("vision").toMap().value("enabled").toBool();
    m_endpoint = std::move(endpoint);
    m_configurationFile = file;
    m_configurationBaseline=json.toJson(QJsonDocument::Compact);
    QSettings().setValue("battlefield/configurationFile",file);
    m_lastFrame = 0;m_lastHeroFrame = 0;
    m_status = QStringLiteral("正在启动态势插件");
    m_timer.start();
    snapshot();
    emit changed();
    return true;
}
void BattlefieldHost::disable() {
    QSettings().remove("battlefield/configurationFile");stop();
}
void BattlefieldHost::stop() {
    ++m_generation;
    m_timer.stop();
    auto old = std::move(m_endpoint);
    if (old) old->stop();
    m_view.clear();
    m_status = QStringLiteral("态势插件已停用");
    emit changed();
}
bool BattlefieldHost::submit(const QVariantMap &value) {
    if (!m_endpoint) return false;
    QString error;
    const bool accepted = m_endpoint->submit(value, &error);
    if (!accepted && !error.isEmpty()) { m_status = error; emit changed(); }
    return accepted;
}
QVariantMap BattlefieldHost::observerAt(qint64 now) const {
    if (!m_backend || !m_backend->connected() || !m_backend->telemetry()) return {};
    const auto *state = m_backend->telemetry();
    const auto position = state->group("robotPosition");
    const auto observations = state->group("fieldObservations").value("robotPosition").toMap();
    qint64 age = 0, remaining = 5000;
    for (const auto &field : {"x", "y", "yaw"}) {
        const auto meta = observations.value(field).toMap();
        bool numeric = false;
        const auto value = position.value(field).toDouble(&numeric);
        if (!numeric || !std::isfinite(value) || !meta.value("ingress_clock_verified").toBool() ||
            meta.value("remaining_ms").toLongLong() <= 0) return {};
        age = qMax(age, meta.value("received_age_ms").toLongLong());
        remaining = qMin(remaining, meta.value("remaining_ms").toLongLong());
    }
    const auto id = position.value("robot_id", m_backend->clientId()).toInt();
    const auto role = id % 100;
    if (role < 1 || role > 7 || (m_backend->clientId() % 100 <= 7 && id != m_backend->clientId())) return {};
    // This is local receive time. The official packet supplies no acquisition
    // timestamp and yaw describes the speed sensor, not the camera gimbal.
    return {{"position", QVariantList{position.value("x"), position.value("y")}},
            {"yaw_deg", position.value("yaw")}, {"robot_id", id}, {"frame_id", "field.2026"},
            {"stamp_ms", now-age}, {"expires_ms", now+remaining}, {"clock_basis", "local_receive"}};
}
void BattlefieldHost::capture(const QImage &image) {
    const auto now = QDateTime::currentMSecsSinceEpoch();
    if (!m_endpoint || !m_visionEnabled || image.isNull() || now-m_lastFrame < 200) return;
    const auto diagnostics = m_video ? m_video->diagnostics() : QVariantMap{};
    const auto age = diagnostics.value("last_frame_age_ms", 0).toLongLong();
    if (age < 0 || age > 1500) return;
    m_lastFrame = now;
    auto sampled = image.scaled(960, 640, Qt::KeepAspectRatio, Qt::FastTransformation);
    QByteArray jpeg;
    QBuffer buffer(&jpeg);
    buffer.open(QIODevice::WriteOnly);
    if (!sampled.save(&buffer, "JPEG", 75) || jpeg.size() > 512*1024) return;
    submit({{"kind", "frame"}, {"stamp_ms", now-age}, {"jpeg", QString::fromLatin1(jpeg.toBase64())},
            {"client_id",m_backend?m_backend->clientId():0},
            {"observer", observerAt(now)}});
}
void BattlefieldHost::attachHeroVideo(VideoEndpoint *video) {
    if(m_heroVideo)m_heroVideo->disconnect(this);
    m_heroVideo=video;
    if(!video)return;
    connect(video,&VideoEndpoint::frameDecoded,this,&BattlefieldHost::captureHero);
    const int signal=video->metaObject()->indexOfSignal("streamReset()");
    const int slot=metaObject()->indexOfSlot("resetHero()");
    if(signal>=0 && slot>=0)connect(video,video->metaObject()->method(signal),this,metaObject()->method(slot));
}
void BattlefieldHost::resetHero() {
    m_lastHeroFrame=0;submit({{"kind","hero_stream_reset"}});
    m_view["projectile"]=QVariantMap{{"tracks",QVariantList{}}};emit changed();
}
void BattlefieldHost::captureHero(const QImage &image) {
    const auto now=QDateTime::currentMSecsSinceEpoch();
    if(!m_endpoint || !m_projectileEnabled || image.isNull() || now-m_lastHeroFrame<25 || !m_heroVideo)return;
    const auto age=m_heroVideo->property("diagnostics").toMap().value("last_frame_age_ms",0).toLongLong();
    if(age<0 || age>600)return;
    m_lastHeroFrame=now;auto sampled=image.scaled(640,480,Qt::KeepAspectRatio,Qt::FastTransformation);
    QByteArray jpeg;QBuffer buffer(&jpeg);buffer.open(QIODevice::WriteOnly);
    if(!sampled.save(&buffer,"JPEG",92) || jpeg.size()>512*1024)return;
    submit({{"kind","hero_frame"},{"stamp_ms",now-age},{"jpeg",QString::fromLatin1(jpeg.toBase64())}});
}
void BattlefieldHost::snapshot() {
    if (!m_endpoint || !m_backend) return;
    if (!m_view.value("advice").toMap().isEmpty() && m_view.value("advice").toMap().value("expires_ms").toLongLong()<=QDateTime::currentMSecsSinceEpoch()) {
        m_view["advice"]=QVariantMap{};emit changed();
    }
    if (!m_view.isEmpty() && QDateTime::currentMSecsSinceEpoch()-m_view.value("stamp_ms").toLongLong() > 1500) {
        m_view.clear(); emit changed();
    }
    QVariantMap groups, observations;
    auto *state = m_backend->telemetry();
    if (m_backend->connected() && state) {
        const auto times = state->group("fieldObservations");
        for (const auto &group : {"radar", "robotStatic", "robotDynamic", "gameStatus"}) {
            groups.insert(group, state->group(group));
            observations.insert(group, times.value(group));
        }
    }
    submit({{"kind", "official"}, {"captured_ms", QDateTime::currentMSecsSinceEpoch()}, {"connected", m_backend->connected()}, {"robot_id", m_backend->clientId()},
            {"groups", groups}, {"observations", observations}});
}
bool BattlefieldHost::setJournalEnabled(bool enabled) {
    return submit({{"kind","journal_control"},{"enabled",enabled}});
}
bool BattlefieldHost::addTacticalMark(const QString &text, const QString &intent, const QVariantList &position, bool share) {
    if(!active() || text.trimmed().isEmpty() || text.size()>64 || !QStringList{"observe","defend","rally"}.contains(intent))return false;
    QVariantMap message{{"kind","journal_mark"},{"text",text},{"intent",intent},{"share",share}};
    if(!position.isEmpty()) {
        if(position.size()!=2)return false;
        message["position"]=position;
    }
    return submit(message);
}
bool BattlefieldHost::analyze(const QString &question) { return submit({{"kind", "analyze"}, {"question", question.left(300)}}); }
bool BattlefieldHost::announce(const QString &target, const QString &peer) { return submit({{"kind", "announce"}, {"target_id", target}, {"peer_node", peer}}); }
void BattlefieldHost::speakAdvice() { submit({{"kind", "speak_advice"}}); }
void BattlefieldHost::mute(bool muted) { submit({{"kind", "mute"}, {"value", muted}}); }
void BattlefieldHost::cancelVoice() { submit({{"kind", "cancel_voice"}}); }
