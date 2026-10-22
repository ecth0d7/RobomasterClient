#include "DecisionConfiguration.h"
#include "ClientBackend.h"
#include "OperatorPreferences.h"
#include "ProviderConfiguration.h"
#include "ServiceHub.h"
#include "RobotIdentity.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLockFile>
#include <QSaveFile>
#include <QSet>

namespace {
bool fail(QString *error, const QString &message) {
    if (error)
        *error = message;
    return false;
}
bool line(const QVariant &value, int maximum) {
    if (value.metaType().id() != QMetaType::QString || value.toString().size() > maximum)
        return false;
    for (const auto ch : value.toString())
        if (ch.category() == QChar::Other_Control)
            return false;
    return true;
}
bool scopeValid(const QVariantMap &scope) {
    const auto id = scope.value("robot_id");
    return scope.size() == 4 && id.isValid() && !id.isNull() &&
           id.metaType().id() != QMetaType::Bool && id.metaType().id() != QMetaType::QString &&
           id.toDouble() == id.toInt() && (id.toInt() == 0 || RobotIdentity::valid(id.toInt())) &&
           line(scope.value("host"), 253) && !scope.value("host").toString().isEmpty() &&
           scope.value("port").metaType().id() != QMetaType::Bool &&
           scope.value("port").metaType().id() != QMetaType::QString &&
           scope.value("port").toDouble() == scope.value("port").toInt() &&
           scope.value("port").toInt() > 0 && scope.value("port").toInt() <= 65535 &&
           line(scope.value("protocol_id"), 128) &&
           !scope.value("protocol_id").toString().isEmpty();
}
bool choices(const QVariant &value, const QStringList &allowed) {
    if (value.metaType().id() != QMetaType::QVariantList &&
        value.metaType().id() != QMetaType::QStringList)
        return false;
    QSet<QString> seen;
    for (const auto &item : value.toList()) {
        if (!line(item, 96) || !allowed.contains(item.toString()) || seen.contains(item.toString()))
            return false;
        seen.insert(item.toString());
    }
    return true;
}
}
QVariantMap DecisionConfiguration::defaults() {
    return {{"modelId", ""},
            {"teamStrategy", "balanced"},
            {"roleStrategy", "assist"},
            {"autoAdvice", false},
            {"trigger", "event"},
            {"voiceEnabled", false},
            {"voicePriority", "caution"},
            {"voiceAudience", "self"},
            {"voiceSpeaker", "local"},
            {"shareEnabled", false},
            {"shareFields", QVariantList{}},
            {"inputMode", "local"},
            {"teamFallback", "wait"},
            {"aggregationEnabled", false},
            {"advicePosition", "race"},
            {"adviceDensity", "compact"},
            {"localAiFields", QVariantList{}},
            {"externalAiFields", QVariantList{}},
            {"playerSourceConfirmed", false}};
}
bool DecisionConfiguration::validate(const QVariantMap &value, QString *error) {
    const auto fields = defaults();
    if (value.size() != fields.size())
        return fail(error, "策略配置字段不完整或含未知字段");
    for (auto it = fields.cbegin(); it != fields.cend(); ++it) {
        const auto item = value.value(it.key());
        if (it.value().metaType().id() == QMetaType::Bool) {
            if (item.metaType().id() != QMetaType::Bool)
                return fail(error, "策略开关须为明确布尔值");
        } else if (it.value().metaType().id() == QMetaType::QString &&
                   !line(item, it.key() == "modelId" ? 128 : 32))
            return fail(error, "策略文本含非法字符或过长");
    }
    const QMap<QString, QStringList> enums{{"teamStrategy", {"balanced", "resource", "objective"}},
                                           {"roleStrategy", {"assist", "task", "pressure"}},
                                           {"trigger", {"event", "periodic"}},
                                           {"voicePriority", {"info", "caution", "urgent"}},
                                           {"voiceAudience", {"self", "team"}},
                                           {"voiceSpeaker", {"local", "leader", "designated"}},
                                           {"inputMode", {"local", "team"}},
                                           {"teamFallback", {"wait", "local"}},
                                           {"advicePosition", {"race", "right"}},
                                           {"adviceDensity", {"compact", "standard"}}};
    for (auto it = enums.cbegin(); it != enums.cend(); ++it)
        if (!it.value().contains(value.value(it.key()).toString()))
            return fail(error, "策略枚举不受支持");
    const QStringList categories{"health", "resources", "position", "objective"};
    if (!choices(value.value("localAiFields"), categories) ||
        !choices(value.value("externalAiFields"), categories) ||
        !choices(value.value("shareFields"),
                 {"health", "resources", "position", "objective", "advice", "sensorEvents",
                  "visionDiscoveries", "derived"}))
        return fail(error, "数据用途白名单含未知项或重复项");
    if (value.value("autoAdvice").toBool() && value.value("modelId").toString().trimmed().isEmpty())
        return fail(error, "自动建议须明确选择模型ID");
    if (value.value("shareEnabled").toBool() && value.value("shareFields").toList().isEmpty())
        return fail(error, "共享意向须明确勾选必要字段");
    return true;
}
DecisionConfiguration::DecisionConfiguration(ClientBackend *backend, OperatorPreferences *phase,
                                             ProviderConfiguration *provider, ServiceHub *services,
                                             QString file, QString protocol, QObject *parent)
    : QObject(parent), m_backend(backend), m_phase(phase), m_provider(provider),
      m_services(services), m_file(std::move(file)), m_protocol(std::move(protocol)) {
    if (backend) {
        connect(backend, &ClientBackend::identityChanged, this,
                &DecisionConfiguration::synchronize);
        connect(backend, &ClientBackend::connectionOptionsChanged, this,
                &DecisionConfiguration::synchronize);
    }
    if (phase)
        connect(phase, &OperatorPreferences::stateChanged, this,
                &DecisionConfiguration::stateChanged);
    if (services)
        connect(services, &ServiceHub::decisionPolicyStatusChanged, this,
                &DecisionConfiguration::stateChanged);
    synchronize();
}
QVariantMap DecisionConfiguration::scope() const {
    return {{"robot_id", m_backend ? m_backend->clientId() : 0},
            {"host", m_backend ? m_backend->host().trimmed().toLower() : QString{}},
            {"port", m_backend ? m_backend->port() : 0},
            {"protocol_id", m_protocol}};
}
QString DecisionConfiguration::lockReason() const {
    if (!m_backend || !m_phase || !m_provider || !m_services)
        return "策略宿主不可用";
    if (m_saving)
        return "正在保存模型策略";
    if (m_backend->clientId() == 0 && !m_backend->connected() && !m_backend->connecting())
        return {};
    return m_phase->lockReason();
}
QVariantMap DecisionConfiguration::state() const {
    return {{"status", m_status},
            {"automatic_status",
             m_services ? m_services->automaticDecisionStatus() : QStringLiteral("宿主不可用")},
            {"configuration_revision", qulonglong(m_revision)},
            {"scope", m_scope},
            {"team_strategy_synchronized", false},
            {"team_voice_available", false}};
}
bool DecisionConfiguration::readProfiles(QVariantList *profiles, QString *error) const {
    profiles->clear();
    if (!QFileInfo::exists(m_file))
        return true;
    QFile file(m_file);
    if (!file.open(QIODevice::ReadOnly))
        return fail(error, "策略文件无法读取");
    const auto bytes = file.read(65537);
    QJsonParseError parse;
    const auto doc = QJsonDocument::fromJson(bytes, &parse);
    const auto root = doc.object();
    if (bytes.size() > 65536 || parse.error != QJsonParseError::NoError || !doc.isObject() ||
        root.size() != 2 || !root.value("schema").isDouble() ||
        root.value("schema").toDouble() != 1 || !root.value("profiles").isArray() ||
        root.value("profiles").toArray().size() > 32)
        return fail(error, "策略文件格式／版本无效，原文件保留");
    for (const auto &entry : root.value("profiles").toArray()) {
        const auto profile = entry.toObject().toVariantMap();
        const auto storedScope = profile.value("scope").toMap();
        if (profile.size() != 2 || !scopeValid(storedScope) ||
            profile.value("values").metaType().id() != QMetaType::QVariantMap ||
            !validate(profile.value("values").toMap(), error) ||
            (storedScope.value("robot_id").toInt() == 0 &&
             profile.value("values").toMap().value("playerSourceConfirmed").toBool()))
            return fail(error, "策略文件含非法范围或字段，原文件保留");
        for (const auto &previous : *profiles)
            if (previous.toMap().value("scope").toMap() == storedScope)
                return fail(error, "策略文件存在重复范围");
        profiles->append(profile);
    }
    return true;
}
bool DecisionConfiguration::writeProfile(const QVariantMap &values, QString *error) {
    if (!scopeValid(m_scope) || !QDir().mkpath(QFileInfo(m_file).absolutePath()))
        return fail(error, "策略范围或目录无效");
    QLockFile lock(m_file + ".lock");
    if (!lock.tryLock(0))
        return fail(error, "另一实例正在保存策略，请稍后再试");
    QVariantList profiles;
    if (!readProfiles(&profiles, error))
        return false;
    const QVariantMap next{{"scope", m_scope}, {"values", values}};
    bool replaced = false;
    for (auto &item : profiles)
        if (item.toMap().value("scope").toMap() == m_scope) {
            item = next;
            replaced = true;
            break;
        }
    if (!replaced)
        profiles.append(next);
    const auto bytes =
        QJsonDocument(
            QJsonObject{{"schema", 1}, {"profiles", QJsonArray::fromVariantList(profiles)}})
            .toJson();
    if (profiles.size() > 32 || bytes.size() > 65536)
        return fail(error, "策略保存空间已满，未覆盖文件");
    QSaveFile file(m_file);
    if (!file.open(QIODevice::WriteOnly))
        return fail(error, "策略文件不可写");
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    return (file.write(bytes) == bytes.size() && file.commit()) ||
           fail(error, "策略保存失败，旧文件保留");
}
void DecisionConfiguration::synchronize() {
    const auto selected = scope();
    if (selected == m_scope)
        return;
    m_scope = selected;
    const auto revision = ++m_revision;
    QVariantList profiles;
    QString error;
    const bool loaded = readProfiles(&profiles, &error);
    m_values = defaults();
    auto fallback = selected;
    fallback["robot_id"] = 0;
    if (loaded) {
        for (const auto &entry : profiles)
            if (entry.toMap().value("scope").toMap() == fallback)
                m_values = entry.toMap().value("values").toMap();
        for (const auto &entry : profiles)
            if (entry.toMap().value("scope").toMap() == selected)
                m_values = entry.toMap().value("values").toMap();
    }
    m_status = loaded ? QStringLiteral("已载入本机器人／选手端范围的策略；未请求模型") : error;
    QPointer<DecisionConfiguration> alive(this);
    emit currentChanged();
    if (!alive || revision != m_revision)
        return;
    emit scopeChanged();
    if (alive && revision == m_revision)
        emit stateChanged();
}
bool DecisionConfiguration::save(const QVariantMap &values) {
    QPointer<DecisionConfiguration> alive(this);
    QString error = lockReason();
    if (!error.isEmpty() || !validate(values, &error) ||
        (m_scope.value("robot_id").toInt() == 0 &&
         values.value("playerSourceConfirmed").toBool())) {
        m_status = error.isEmpty() ? QStringLiteral("选择机器人后才能手动确认该选手端来源") : error;
        emit stateChanged();
        return false;
    }
    const auto model = values.value("modelId").toString();
    const auto activeModel = m_services->decisionDetails().value("model").toString();
    const auto selectedPlugin = m_provider->state().value("provider_id").toString();
    const bool builtin = selectedPlugin == "decision.http" || selectedPlugin == "decision.codex";
    if (!model.isEmpty() && !builtin && model != activeModel) {
        m_status = "当前第三方插件只接受其报告的模型ID；更换提供者请在连接配置页明确选择";
        emit stateChanged();
        return false;
    }
    if (!writeProfile(values, &error)) {
        m_status = error;
        emit stateChanged();
        return false;
    }
    m_values = values;
    const auto revision = ++m_revision;
    m_saving = true;
    emit currentChanged();
    if (!alive)
        return false;
    if (revision != m_revision) {
        m_saving = false;
        return false;
    }
    bool applied = true;
    if (!model.isEmpty() && builtin && m_provider &&
        m_provider->current().value("model") != model) {
        auto provider = m_provider->current();
        provider["model"] = model;
        applied = m_provider->save(provider);
    }
    if (!alive)
        return false;
    m_saving = false;
    if (revision != m_revision)
        return false;
    m_status =
        applied
            ? QStringLiteral("策略已保存；明确模型选择已同步，未自动启用提供者；运行资格另行判断")
            : QStringLiteral("策略已保存，但提供者模型未切换：") +
                  (m_provider ? m_provider->status() : QStringLiteral("宿主不可用"));
    emit stateChanged();
    return true;
}
