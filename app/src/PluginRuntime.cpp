#include "PluginRuntime.h"
#include "PluginHost.h"
#include "ServiceHub.h"
#include "ClientBackend.h"
#include <cmath>

PluginRuntime::PluginRuntime(PluginHost *host, ServiceHub *services, ClientBackend *backend,
                             QString directory, QVariantMap coreSelection, QObject *parent)
    : QObject(parent), m_host(host), m_services(services), m_backend(backend),
      m_directory(std::move(directory)), m_coreSelection(std::move(coreSelection)) {
    connect(services, &ServiceHub::serviceStatusChanged, this, &PluginRuntime::changed);
    connect(backend, &ClientBackend::identityChanged, this, &PluginRuntime::changed);
    connect(backend, &ClientBackend::connectionChanged, this, &PluginRuntime::changed);
    services->setPluginRuntime(this);
    refresh(); // Metadata only: no endpoint creation or connection.
}
void PluginRuntime::configureOptional(const QString &role, const QString &id,
                                      const QVariantMap &configuration, bool enabled,
                                      const QString &configurationError) {
    if (role != QLatin1String("decision") && role != QLatin1String("speech") &&
        role != QLatin1String("bridge") && role != QLatin1String("aggregation"))
        return;
    ++m_revisions[role];
    m_profiles[role] = {id, configuration, enabled, false, configurationError, {}};
}
void PluginRuntime::startConfigured() {
    for (const auto &role :
         {QStringLiteral("speech"), QStringLiteral("decision"), QStringLiteral("bridge"), QStringLiteral("aggregation")}) {
        if (!m_profiles.value(role).requested)
            continue;
        QPointer<PluginRuntime> alive(this);
        apply(role, true);
        if (!alive)
            return;
    }
}
bool PluginRuntime::editable() const {
    if (!m_backend || m_changing)
        return false;
    if (m_backend->clientId() == 0 && !m_backend->connected() && !m_backend->connecting())
        return true;
    if (m_preparationGuard)
        return m_preparationGuard();
    return true;
}
void PluginRuntime::refresh() {
    m_catalog = PluginHost::discover(m_directory);
    emit changed();
}
bool PluginRuntime::beginEdit() {
    if (editable())
        return true;
    m_status = QStringLiteral("配置宿主不可用、身份未确认或正在切换插件，请稍后重试");
    emit changed();
    return false;
}
void PluginRuntime::retireOptional(const QString &role) {
    if (!m_profiles.contains(role))
        return;
    ++m_revisions[role];
    m_profiles[role].enabled = false;
    m_profiles[role].requested = false;
    QPointer<PluginRuntime> alive(this);
    if (m_services)
        m_services->disableOptionalService(role);
    if (alive)
        emit changed();
}
bool PluginRuntime::replaceOptional(const QString &role, const QString &id,
                                    const QVariantMap &configuration, bool enabled,
                                    QString *error) {
    if (error)
        error->clear();
    if (!m_profiles.contains(role) || !beginEdit()) {
        if (error)
            *error = m_status;
        return false;
    }
    m_changing = true;
    QPointer<PluginRuntime> alive(this);
    const auto retirement = m_revisions.value(role) + 1;
    retireOptional(role);
    if (!alive)
        return false;
    if (m_revisions.value(role) != retirement) {
        m_changing = false;
        if (error)
            *error = QStringLiteral("服务范围在切换期间变化，旧配置未启动");
        emit changed();
        return false;
    }
    m_profiles[role] = {id, configuration, enabled, false, {}, {}};
    const bool accepted = enabled ? apply(role, true) : true;
    if (!alive)
        return false;
    m_changing = false;
    if (!enabled)
        m_status = QStringLiteral("已保存 %1 配置，当前未启用").arg(id);
    if (!accepted && error) {
        *error = m_profiles.value(role).failure;
        if (error->isEmpty())
            *error = QStringLiteral("服务范围在切换期间变化，旧配置未启动");
    }
    emit changed();
    return accepted;
}
bool PluginRuntime::configureSpeech(const QString &id,const QVariantMap &configuration) {
    const QStringList strings{"executable","player","voice","endpoint","model"};
    if(id!="speech.espeak" && id!="speech.piper-http")return false;
    for(auto it=configuration.cbegin();it!=configuration.cend();++it) {
        const bool valid=it.key()=="playback" ? it->metaType().id()==QMetaType::Bool
            : strings.contains(it.key()) && it->metaType().id()==QMetaType::QString && it->toString().size()<=1024
                && !it->toString().contains(QChar::Null) && !it->toString().contains('\n');
        if(!valid){m_status=QStringLiteral("语音配置字段或类型无效；本入口不接受凭据或附加命令参数");emit changed();return false;}
    }
    QString error;
    const bool accepted=replaceOptional("speech",id,configuration,true,&error);
    if(!accepted){m_status=error;emit changed();}
    return accepted;
}
bool PluginRuntime::setEnabled(const QString &role, bool enabled) {
    if (!beginEdit() || !m_profiles.contains(role))
        return false;
    m_changing = true;
    QPointer<PluginRuntime> alive(this);
    const bool accepted = apply(role, enabled);
    if (alive) {
        m_changing = false;
        emit changed();
    }
    return accepted;
}
bool PluginRuntime::selectPlugin(const QString &role, const QString &id) {
    if (!beginEdit() || !m_profiles.contains(role))
        return false;
    auto &profile = m_profiles[role];
    if (profile.enabled) {
        m_status = QStringLiteral("请先停用当前服务，再更换插件");
        emit changed();
        return false;
    }
    int matches = 0;
    for (const auto &entry : m_catalog) {
        const auto metadata = entry.toMap();
        if (metadata.value("id") == id && metadata.value("role") == role &&
            metadata.value("contract") == QLatin1String(ExtensionPlugin_iid))
            ++matches;
    }
    if (matches != 1) {
        m_status = QStringLiteral("未找到唯一且契约匹配的插件");
        emit changed();
        return false;
    }
    profile.id = id;
    profile.failure.clear();
    m_status = QStringLiteral("已选择 %1；显式启用后启动，沿用当前启动配置").arg(id);
    emit changed();
    return true;
}
bool PluginRuntime::apply(const QString &role, bool enabled) {
    if (!m_services || !m_profiles.contains(role))
        return false;
    // Service signals may synchronously retire a robot scope. Keep a value
    // snapshot and check the role revision before committing any old result.
    const auto profile = m_profiles.value(role);
    if (profile.enabled == enabled && (enabled || profile.failure.isEmpty()))
        return true;
    const auto revision = ++m_revisions[role];
    QPointer<PluginRuntime> alive(this);
    m_services->disableOptionalService(role);
    if (!alive || !m_services || revision != m_revisions.value(role))
        return false;
    m_profiles[role].enabled = false;
    m_profiles[role].failure.clear();
    if (enabled) {
        QString error = profile.configurationError;
        if (error.isEmpty())
            error = m_services->optionalServiceBlockReason(role, profile.id);
        ExtensionPlugin *factory =
            error.isEmpty() ? m_host->loadExtension(m_directory, profile.id, role, &error)
                            : nullptr;
        if (!alive || !m_services || revision != m_revisions.value(role))
            return false;
        const auto activationGuard = m_activationGuards.value(role);
        if (factory && error.isEmpty() && activationGuard
            && !activationGuard(profile.configuration, &error))
            factory = nullptr;
        if (!alive || !m_services || revision != m_revisions.value(role))
            return false;
        if (factory && error.isEmpty()) {
            std::unique_ptr<ServiceEndpoint> endpoint(factory->createService());
            if (!alive || !m_services || revision != m_revisions.value(role))
                return false;
            bool started = false;
            if (role == QLatin1String("speech"))
                started =
                    m_services->startSpeech(std::move(endpoint), profile.configuration, &error, profile.id);
            else if (role == QLatin1String("decision"))
                started =
                    m_services->startDecision(std::move(endpoint), profile.configuration, &error);
            else if (role == QLatin1String("bridge"))
                started =
                    m_services->startBridge(std::move(endpoint), profile.configuration, &error);
            else if (role == QLatin1String("aggregation"))
                started = m_services->startAggregation(std::move(endpoint), profile.configuration, &error);
            if (!alive || !m_services || revision != m_revisions.value(role))
                return false;
            m_profiles[role].enabled = started;
        }
        if (!m_profiles.value(role).enabled) {
            m_profiles[role].failure =
                error.isEmpty() ? QStringLiteral("插件未能创建可用服务") : error;
            m_services->reportOptionalStartupFailure(role, m_profiles.value(role).failure);
            if (!alive || revision != m_revisions.value(role))
                return false;
        }
    }
    const auto result = m_profiles.value(role);
    m_status =
        enabled ? result.enabled
                      ? QStringLiteral("已启用 %1；实际连接状态由服务报告").arg(result.id)
                      : QStringLiteral("%1 启动失败：%2；其他客户端功能继续")
                            .arg(result.id, result.failure)
                : QStringLiteral("已停用 %1，相关任务已取消；核心客户端继续运行").arg(profile.id);
    const bool accepted = !enabled || result.enabled;
    emit changed();
    return accepted;
}
QVariantList PluginRuntime::modules() const {
    QVariantList result = m_catalog;
    // A selected but uninstalled optional plugin must remain visible as missing.
    for (auto it = m_profiles.cbegin(); it != m_profiles.cend(); ++it) {
        bool found = false;
        for (const auto &entry : result)
            if (entry.toMap().value("id") == it->id && entry.toMap().value("role") == it.key()) {
                found = true;
                break;
            }
        if (!found)
            result.append(QVariantMap{{"id", it->id},
                                      {"role", it.key()},
                                      {"name", QStringLiteral("未安装或元数据不兼容")},
                                      {"missing", true}});
    }
    QMap<QString, int> counts;
    for (const auto &entry : result) {
        const auto row = entry.toMap();
        ++counts[row.value("role").toString() + ":" + row.value("id").toString()];
    }
    for (auto &entry : result) {
        auto row = entry.toMap();
        const auto role = row.value("role").toString(), id = row.value("id").toString();
        const bool managed = m_profiles.contains(role), core = m_coreSelection.contains(role);
        const bool selected =
            managed ? m_profiles.value(role).id == id : m_coreSelection.value(role) == id;
        row["optional"] = !core;
        row["managed"] = managed;
        row["selected"] = selected;
        row["duplicate"] = counts.value(role + ":" + id) > 1;
        row["enabled"] = managed ? selected && m_profiles.value(role).enabled : selected;
        row["restart_required"] = core;
        row["error"] = managed && selected ? m_profiles.value(role).failure : QString{};
        row["configuration_error"] =
            managed && selected ? m_profiles.value(role).configurationError : QString{};
        row["status"] = !managed && !core ? QStringLiteral("可选扩展角色尚未接入宿主；不可启用")
                        : core ? selected ? QStringLiteral("核心端点 · 随主程序运行，替换需重启")
                                          : QStringLiteral("未选择 · 核心替换需修改启动配置")
                        : !selected ? QStringLiteral("可选插件 · 未选择")
                        : !m_profiles.value(role).failure.isEmpty() ? m_profiles.value(role).failure
                        : !m_profiles.value(role).enabled           ? QStringLiteral("未启用")
                        : !m_services                       ? QStringLiteral("服务宿主已释放")
                        : role == QLatin1String("speech")   ? m_services->speechStatus()
                        : role == QLatin1String("decision") ? m_services->decisionStatus()
                        : role == QLatin1String("aggregation") ? m_services->aggregationStatus()
                                                            : m_services->bridgeStatus();
        entry = row;
    }
    return result;
}
