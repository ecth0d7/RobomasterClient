#include "SeasonConfiguration.h"
#include "ClientBackend.h"
#include "OperatorPreferences.h"
#include "RulesetCatalog.h"
#include "SeasonMechanics.h"
#include "TerminalDataBus.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLockFile>
#include <QSaveFile>

namespace {
constexpr int MaximumBytes = 4096;
bool validEnvironment(const QString &value) {
    return value == QLatin1String("training") || value == QLatin1String("competition");
}
}

SeasonConfiguration::SeasonConfiguration(ClientBackend *backend, OperatorPreferences *preparation,
                                         QString codecId, QString file, QObject *parent)
    : QObject(parent), m_backend(backend), m_preparation(preparation),
      m_codec(std::move(codecId)), m_file(std::move(file)),
      m_profile(RulesetCatalog::defaultProfileId()) {
    load();
    m_bus = new TerminalDataBus(this);
    const auto selected = current();
    m_bus->setRulesContext({{"profile_id", m_profile}, {"field_profile_id", selected.value("field_profile_id")},
                           {"capability_revision", selected.value("capability_revision")}});
    if (backend) {
        connect(backend, &ClientBackend::identityChanged, this, &SeasonConfiguration::stateChanged);
        connect(backend, &ClientBackend::connectionChanged, this, &SeasonConfiguration::stateChanged);
    }
    if (preparation)
        connect(preparation, &OperatorPreferences::stateChanged, this, &SeasonConfiguration::stateChanged);
}
QVariantList SeasonConfiguration::profiles() const { return RulesetCatalog::profiles(); }
QVariantMap SeasonConfiguration::current() const { return RulesetCatalog::profile(m_profile); }
QVariantList SeasonConfiguration::opportunities() const { return RulesetCatalog::opportunities(m_profile); }
QObject *SeasonConfiguration::terminalBus() const { return m_bus.data(); }
bool SeasonConfiguration::seedLocalDemo() {
    if (!editable() || !m_valid || m_environment != QLatin1String("training") ||
        current().value("season").toInt() != 2027 || !m_bus) {
        m_status = QStringLiteral("本地mock演示仅供2027训练／赛外准备；不进入比赛遥测或模型输入");
        emit stateChanged(); return false;
    }
    QString error;
    const bool accepted = m_bus->seedMock(&error);
    m_status = accepted ? QStringLiteral("已生成明确标记的本地mock；没有连接赛事、队友、设备或模型") : error;
    emit stateChanged();
    return accepted;
}
void SeasonConfiguration::clearLocalDemo() { if (m_bus) m_bus->clear(); }
QVariantMap SeasonConfiguration::estimateLogistics(double health) const {
    return SeasonMechanics::logistics(m_profile, health);
}
QVariantMap SeasonConfiguration::estimateTerritoryRate(bool outposts, bool bases) const {
    return SeasonMechanics::territoryRate(m_profile, outposts, bases);
}
QVariantMap SeasonConfiguration::context() const {
    const auto selected = current();
    QVariantMap result;
    for (const auto &key : {"id", "event", "season", "competition_stage", "rules_version",
                            "document_status", "released_on", "rules_document_id",
                            "protocol_document_id", "ui_document_id", "capability_revision",
                            "field_profile_id", "topology"})
        result[key] = selected.value(key);
    result["environment"] = m_environment;
    result["codec_id"] = m_codec;
    result["revision"] = qulonglong(m_revision);
    result["configuration_valid"] = m_valid;
    result["wire_compatible"] = officialConnectionAllowed();
    result["official_adapter_status"] = selected.value("official_transport_ready").toBool()
        ? QStringLiteral("existing_2026_adapter_unaccepted") : QStringLiteral("protocol_pending");
    result["automatic_actions_allowed"] = false;
    return result;
}
QString SeasonConfiguration::lockReason() const {
    if (!m_backend) return QStringLiteral("赛季宿主不可用");
    if (m_changing) return QStringLiteral("正在切换赛季范围");
    if (m_backend->connecting()) return QStringLiteral("先取消正在建立的连接，再修改赛季与用途");
    if (m_backend->clientId() == 0 && !m_backend->connected()) return {};
    if (!m_preparation || !m_preparation->editable())
        return m_preparation ? m_preparation->lockReason() : QStringLiteral("赛外状态尚未确认");
    return {};
}
QString SeasonConfiguration::connectionReason() const {
    if (m_changing) return QStringLiteral("赛季范围正在切换，尚未连接");
    if (!m_valid) return QStringLiteral("赛季配置损坏或未知，请在赛外重新保存；原文件保留");
    const auto selected = current();
    if (selected.isEmpty()) return QStringLiteral("没有可核验的正式规则配置");
    if (!selected.value("official_transport_ready").toBool())
        return QStringLiteral("2027规则已核实；详细通信协议及适配器尚未取得，不能用2026线路连接");
    if (!selected.value("codec_ids").toStringList().contains(m_codec))
        return QStringLiteral("所选规则与本次协议插件不兼容，不能解释或发送比赛数据");
    return {};
}
QString SeasonConfiguration::optionalServiceBlockReason(const QString &role, const QString &pluginId) const {
    if (!m_valid || m_changing || current().isEmpty()) return QStringLiteral("赛季配置无效或正在切换，可选服务未启动");
    const bool competition = m_environment == QLatin1String("competition");
    const bool nextSeason = current().value("season").toInt() == 2027;
    if (role == QLatin1String("aggregation")) {
        if (nextSeason)
            return QStringLiteral("现有队伍schema2尚无2027规则／场地握手；2027有线共享适配待接通");
        if (competition)
            return QStringLiteral("2026比赛配置不启用客户端间共享；现有共享模块仅供明确的本地训练");
    }
    if (role == QLatin1String("bridge") && competition)
        return QStringLiteral("比赛配置停用实验室网络桥接，避免操作间外通信");
    if (role == QLatin1String("decision") && competition)
        return QStringLiteral("比赛配置尚无核验为完全本地的推理适配器；云端／未知位置模型不启动");
    if (role == QLatin1String("decision") && nextSeason)
        return QStringLiteral("2027来源与新机制输入适配未接通，不能把2026快照当2027建议依据");
    if (role == QLatin1String("speech") && competition && pluginId != QLatin1String("speech.espeak"))
        return QStringLiteral("比赛配置仅保留本地espeak播报；网络语音未核验为操作间内服务");
    return {};
}
QString SeasonConfiguration::inferenceBlockReason(const QVariantMap &details) const {
    if (!m_valid || m_changing || current().isEmpty()) return QStringLiteral("规则作用域无效或正在切换");
    if (current().value("season").toInt() == 2027)
        return QStringLiteral("2027模型输入生产端尚未接通，未发送模型请求");
    // This is a conservative project inference from the no-outside-room rule,
    // not an official rule that explicitly names AI vendors or local processes.
    if (m_environment == QLatin1String("competition") &&
        (details.value("inference_location") != QLatin1String("local") ||
         details.value("fully_local_verified").metaType().id() != QMetaType::Bool ||
         !details.value("fully_local_verified").toBool()))
        return QStringLiteral("比赛中禁止向操作间外请求建议；localhost／本地Codex进程不证明本地推理");
    return {};
}
void SeasonConfiguration::load() {
    if (m_file.isEmpty() || !QFileInfo::exists(m_file)) {
        m_status = current().value("season").toInt() == 2026
            ? QStringLiteral("2026 V2.0.0／本地训练；可连接 SharkDataSever")
            : QStringLiteral("2027正式区域赛规则／本地训练；详细通信协议及生产适配待接通");
        return;
    }
    QFile file(m_file);
    if (!file.open(QIODevice::ReadOnly)) {
        m_valid = false;
    } else {
        const auto bytes = file.read(MaximumBytes + 1);
        QJsonParseError parse;
        const auto document = QJsonDocument::fromJson(bytes, &parse);
        const auto object = document.object();
        const auto profile = object.value("profile_id").toString();
        const auto environment = object.value("environment").toString();
        m_valid = bytes.size() <= MaximumBytes && parse.error == QJsonParseError::NoError &&
            document.isObject() && object.size() == 3 && object.value("schema").isDouble() &&
            object.value("schema").toDouble() == 1 &&
            !RulesetCatalog::profile(profile).isEmpty() && validEnvironment(environment);
        if (m_valid) { m_profile = profile; m_environment = environment; }
    }
    m_status = m_valid ? QStringLiteral("已载入赛季与用途；不自动连接或继承新赛季授权")
                       : QStringLiteral("赛季配置不可读取或版本无效；连接停用，原文件保留，可赛外重新保存恢复");
}
bool SeasonConfiguration::save(const QString &profile, const QString &environment, QString *error) const {
    if (m_file.isEmpty() || !QDir().mkpath(QFileInfo(m_file).absolutePath())) {
        *error = QStringLiteral("赛季配置目录不可写"); return false;
    }
    QLockFile lock(m_file + ".lock");
    if (!lock.tryLock(0)) { *error = QStringLiteral("另一实例正在保存赛季配置"); return false; }
    QSaveFile file(m_file);
    const auto bytes = QJsonDocument(QJsonObject{{"schema", 1}, {"profile_id", profile},
                                                {"environment", environment}}).toJson();
    if (!file.open(QIODevice::WriteOnly)) { *error = file.errorString(); return false; }
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    if (file.write(bytes) != bytes.size() || !file.commit()) {
        *error = file.errorString(); return false;
    }
    return true;
}
bool SeasonConfiguration::apply(const QString &profileId, const QString &environment) {
    const auto locked = lockReason();
    if (!locked.isEmpty()) { m_status = locked; emit stateChanged(); return false; }
    if (RulesetCatalog::profile(profileId).isEmpty() || !validEnvironment(environment)) {
        m_status = QStringLiteral("未知赛季或用途，原配置保留"); emit stateChanged(); return false;
    }
    if (m_valid && profileId == m_profile && environment == m_environment) return true;
    QString error;
    if (!save(profileId, environment, &error)) {
        m_status = error; emit stateChanged(); return false;
    }
    m_changing = true;
    QPointer<SeasonConfiguration> alive(this);
    emit aboutToChange();
    if (!alive) return false;
    m_profile = profileId; m_environment = environment; m_valid = true; ++m_revision;
    if (m_bus) {
        const auto selected = current();
        m_bus->setRulesContext({{"profile_id", m_profile}, {"field_profile_id", selected.value("field_profile_id")},
                               {"capability_revision", selected.value("capability_revision")}});
        if (!alive) return false;
        m_bus->clear(); // Environment changes also retire same-profile mock/local observations.
        if (!alive) return false;
    }
    m_changing = false;
    m_status = QStringLiteral("已保存新赛季范围；旧连接／建议／共享已退役，须赛外重新配置并显式连接");
    emit contextChanged();
    if (alive) emit stateChanged();
    return bool(alive);
}
