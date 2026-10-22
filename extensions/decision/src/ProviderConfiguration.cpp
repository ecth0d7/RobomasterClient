#include "ProviderConfiguration.h"
#include "ClientBackend.h"
#include "PluginRuntime.h"
#include "ServiceHub.h"
#include "OperatorPreferences.h"
#include "RobotIdentity.h"
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QLockFile>
#include <QSaveFile>
#include <QRegularExpression>
#include <QNetworkRequest>
#include <QSet>
#include <QStandardPaths>
#include <utility>

namespace {
bool fail(QString *error, const QString &reason) {
    if (error)
        *error = reason;
    return false;
}
bool text(const QVariant &value, int maximum) {
    if (value.metaType().id() != QMetaType::QString || value.toString().size() > maximum)
        return false;
    for (const auto ch : value.toString())
        if (ch.category() == QChar::Other_Control)
            return false;
    return true;
}
bool digits(const QVariant &value, int low, int high) {
    static const QRegularExpression decimal(QStringLiteral("\\A[0-9]{1,6}\\z"));
    if (!text(value, 6) || !decimal.match(value.toString()).hasMatch())
        return false;
    const int number = value.toString().toInt();
    return number >= low && number <= high;
}
bool localUrl(const QUrl &url) {
    return QHostAddress(url.host()).isLoopback() || url.host() == "localhost";
}
bool endpointValid(const QVariantMap &values) {
    const QUrl url(values.value("endpoint").toString());
    return url.isValid() && !url.isRelative() && !url.host().isEmpty() &&
           url.userInfo().isEmpty() && !url.hasQuery() && !url.hasFragment() &&
           url.path().startsWith('/') &&
           (url.port(-1) == -1 || (url.port() > 0 && url.port() <= 65535)) &&
           (url.scheme() == "https" || (url.scheme() == "http" && localUrl(url))) &&
           (values.value("kind") == "local-http" ? localUrl(url) : url.scheme() == "https");
}
QString credentialState(const QVariantMap &values) {
    if (values.value("kind") == "codex") {
        const auto configured = values.value("authHome").toString();
        const auto path = configured.isEmpty()
            ? QDir(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)).filePath("codex-credentials")
            : configured;
        return QStringLiteral("专用认证引用：%1；账号未核验，不读取或复制凭据").arg(path);
    }
    const auto name = values.value("keyEnv").toString();
    if (name.isEmpty())
        return QStringLiteral("未配置密钥引用；账号未核验");
    return qEnvironmentVariableIsEmpty(name.toUtf8().constData())
               ? name + QStringLiteral(" 未设置；账号未核验")
               : name + QStringLiteral(" 已设置；账号未核验");
}
}
QVariantMap ProviderConfiguration::defaults() {
    return {{"kind", "deepseek"},
            {"enabled", false},
            {"endpoint", "https://api.deepseek.com/chat/completions"},
            {"model", "deepseek-flash"},
            {"keyEnv", "DEEPSEEK_API_KEY"},
            {"api", "chat"},
            {"format", "json-object"},
            {"executable", "codex"},
            {"authHome", ""},
            {"reasoning", "high"},
            {"timeoutMs", "15000"},
            {"minimumIntervalMs", "1000"},
            {"maxOutputTokens", "1200"},
            {"thinking", false}};
}
bool ProviderConfiguration::validate(const QVariantMap &values, QString *error) {
    const auto fields = defaults();
    if (values.size() != fields.size())
        return fail(error, "模型配置字段不完整或含未知字段");
    for (auto it = fields.cbegin(); it != fields.cend(); ++it) {
        if (it.value().metaType().id() == QMetaType::Bool) {
            if (values.value(it.key()).metaType().id() != QMetaType::Bool)
                return fail(error, "模型开关须为明确布尔值");
        } else if (!text(values.value(it.key()), 512))
            return fail(error, "模型配置含过长或非法文本");
    }
    if (!QStringList{"deepseek", "local-http", "remote-http", "codex"}.contains(
            values.value("kind").toString()) ||
        !QStringList{"chat", "responses"}.contains(values.value("api").toString()) ||
        !QStringList{"json-schema", "json-object"}.contains(values.value("format").toString()) ||
        !QStringList{"low", "medium", "high"}.contains(values.value("reasoning").toString()))
        return fail(error, "提供者／API／格式／推理配置不受支持");
    static const QRegularExpression environment(
        QStringLiteral("\\A[A-Za-z_][A-Za-z0-9_]{0,95}\\z"));
    const auto env = values.value("keyEnv").toString();
    if (!env.isEmpty() && !environment.match(env).hasMatch())
        return fail(error, "只填写密钥环境变量名，不填写密钥值");
    if (!digits(values.value("timeoutMs"), 50, 120000) ||
        !digits(values.value("minimumIntervalMs"), 500, 30000) ||
        !digits(values.value("maxOutputTokens"), 256, 8192))
        return fail(error, "模型时限、节流或输出预算不合法");
    if (values.value("kind") == "deepseek" &&
        (values.value("api") != "chat" || values.value("format") != "json-object"))
        return fail(error, "当前DeepSeek预设使用Chat与JSON Object");
    const QUrl storedEndpoint(values.value("endpoint").toString());
    if (!storedEndpoint.userInfo().isEmpty() || storedEndpoint.hasQuery() ||
        storedEndpoint.hasFragment())
        return fail(error, "端点不可保存账号、查询凭据或片段，即使提供者未启用");
    if (values.value("thinking").toBool() && values.value("kind") != "deepseek")
        return fail(error, "当前思考开关仅支持DeepSeek Chat预设");
    if (!values.value("enabled").toBool())
        return true;
    if (values.value("model").toString().trimmed().isEmpty() || !text(values.value("model"), 128))
        return fail(error, "启用前填写明确模型ID");
    if (values.value("kind") == "codex") {
        if (values.value("executable").toString().trimmed().isEmpty())
            return fail(error, "填写Codex程序路径");
    } else if (!endpointValid(values))
        return fail(error, "模型端点须为完整安全HTTP(S)路径；本机模式限loopback");
    if ((values.value("kind") == "deepseek" || values.value("kind") == "remote-http") &&
        env.isEmpty())
        return fail(error, "外部模型需要密钥环境变量引用");
    return true;
}
ProviderConfiguration::ProviderConfiguration(ClientBackend *backend, PluginRuntime *runtime,
                                             ServiceHub *services, OperatorPreferences *phase,
                                             QVariantMap startupValues, QString file,
                                             QVariantMap startupRuntime, QObject *parent)
    : QObject(parent), m_backend(backend), m_runtime(runtime), m_services(services), m_phase(phase),
      m_startup(std::move(startupValues)), m_startupRuntime(std::move(startupRuntime)),
      m_file(std::move(file)) {
    if (m_startup.isEmpty())
        m_startup = defaults();
    m_deadline.setSingleShot(true);
    connect(&m_deadline, &QTimer::timeout, this, [this] {
        cancelCatalog();
        m_status = "模型清单请求超时；未验证账号可用模型";
        emit stateChanged();
    });
    if (backend)
        connect(backend, &ClientBackend::identityChanged, this,
                &ProviderConfiguration::synchronize);
    if (phase)
        connect(phase, &OperatorPreferences::stateChanged, this, [this] {
            if (m_catalog && !editable()) {
                cancelCatalog();
                m_status = "比赛／阶段未确认，已取消模型清单请求";
            }
            emit stateChanged();
        });
    if (services)
        connect(services, &ServiceHub::serviceStatusChanged, this,
                &ProviderConfiguration::stateChanged);
    if (runtime)
        connect(runtime, &PluginRuntime::changed, this, &ProviderConfiguration::stateChanged);
    synchronize();
}
ProviderConfiguration::~ProviderConfiguration() {
    blockSignals(true);
    cancelCatalog();
}
QString ProviderConfiguration::lockReason() const {
    if (!m_backend || !m_runtime || !m_phase)
        return "模型配置宿主不可用";
    if (m_changing)
        return "正在保存或切换模型配置";
    if (m_backend->clientId() == 0 && !m_backend->connected() && !m_backend->connecting())
        return {};
    return m_phase->lockReason();
}
QString ProviderConfiguration::pluginId() const {
    return m_current.value("kind") == "codex" ? "decision.codex" : "decision.http";
}
bool ProviderConfiguration::pluginAvailable() const {
    if (!m_runtime)
        return false;
    int matches = 0;
    for (const auto &value : m_runtime->modules()) {
        const auto row = value.toMap();
        if (row.value("id") == pluginId() && row.value("role") == "decision" &&
            !row.value("missing").toBool() && !row.value("duplicate").toBool() &&
            row.value("contract") == QLatin1String(ExtensionPlugin_iid))
            ++matches;
    }
    return matches == 1;
}
QUrl ProviderConfiguration::catalogUrl() const {
    if (m_current.value("kind") == "codex" || !endpointValid(m_current))
        return {};
    QUrl url(m_current.value("endpoint").toString());
    auto path = url.path();
    if (path.endsWith("/chat/completions"))
        path.chop(QString("/chat/completions").size());
    else if (path.endsWith("/responses"))
        path.chop(QString("/responses").size());
    else
        return {};
    url.setPath(path + "/models");
    return url;
}
QVariantMap ProviderConfiguration::state() const {
    const auto details = m_services ? m_services->decisionDetails() : QVariantMap{};
    const bool active = details.value("active").toBool();
    return {{"status", m_catalog                 ? QStringLiteral("正在读取模型清单")
                       : !m_applyError.isEmpty() ? m_applyError
                       : active                  ? m_services->decisionStatus()
                                                 : m_status},
            {"health", !m_applyError.isEmpty()                       ? "error"
                       : m_catalog || details.value("busy").toBool() ? "busy"
                       : active                                      ? "configured"
                                                                     : "disabled"},
            {"provider_id", m_runtime ? m_runtime->selectedPlugin("decision") : QString{}},
            {"model", active ? details.value("model") : QVariant{}},
            {"configured_model", m_current.value("model")},
            {"endpoint", active ? details.value("endpoint") : QVariant{}},
            {"api", details.value("api")},
            {"format", details.value("format")},
            {"inference_location", details.value("inference_location", "unknown")},
            {"process_location", details.value("process_location")},
            {"auth_home", details.value("auth_home")},
            {"cli_contract_verified", details.value("cli_contract_verified")},
            {"authentication_verified", details.value("authentication_verified")},
            {"isolation_verified", details.value("isolation_verified")},
            {"output_token_limit_supported", details.value("output_token_limit_supported")},
            {"maximum_final_bytes", details.value("maximum_final_bytes")},
            {"configuration_revision", qulonglong(m_revision)},
            {"credentials", credentialState(m_current)},
            {"catalog_busy", bool(m_catalog)},
            {"catalog_count", m_models.size()},
            {"capabilities",
             QVariantMap{{"inspect", true},
                         {"activate", pluginAvailable()},
                         {"listModels", catalogUrl().isValid() && !catalogUrl().isEmpty()}}}};
}
bool ProviderConfiguration::readNodes(QVariantMap *nodes, QString *error) const {
    nodes->clear();
    if (!QFileInfo::exists(m_file))
        return true;
    QFile input(m_file);
    if (!input.open(QIODevice::ReadOnly))
        return fail(error, "模型配置文件无法读取");
    const auto bytes = input.read(65537);
    QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(bytes, &parse);
    const auto root = document.object();
    if (bytes.size() > 65536 || parse.error != QJsonParseError::NoError || !document.isObject() ||
        root.size() != 2 || !root.value("schema").isDouble() ||
        root.value("schema").toDouble() != 1 || !root.value("nodes").isObject() ||
        root.value("nodes").toObject().size() > 17)
        return fail(error, "模型配置格式／版本无效，原文件保留");
    const auto stored = root.value("nodes").toObject();
    for (auto it = stored.begin(); it != stored.end(); ++it) {
        bool ok = false;
        const int id = it.key().toInt(&ok);
        if (!ok || QString::number(id) != it.key() || (id != 0 && !RobotIdentity::valid(id)) ||
            !it.value().isObject() || !validate(it.value().toObject().toVariantMap(), error))
            return fail(error, "模型配置含非法身份或字段，未恢复");
    }
    *nodes = stored.toVariantMap();
    return true;
}
bool ProviderConfiguration::writeNode(const QVariantMap &values, QString *error) {
    if (!QDir().mkpath(QFileInfo(m_file).absolutePath()))
        return fail(error, "模型配置目录不可写");
    QLockFile lock(m_file + ".lock");
    if (!lock.tryLock(0))
        return fail(error, "模型配置正由另一实例保存，请稍后再试");
    QVariantMap nodes;
    if (!readNodes(&nodes, error))
        return false;
    nodes[QString::number(m_robot)] = values;
    const auto bytes =
        QJsonDocument(QJsonObject{{"schema", 1}, {"nodes", QJsonObject::fromVariantMap(nodes)}})
            .toJson();
    if (nodes.size() > 17 || bytes.size() > 65536)
        return fail(error, "模型配置容量已满，未覆盖文件");
    QSaveFile output(m_file);
    if (!output.open(QIODevice::WriteOnly))
        return fail(error, "模型配置文件不可写");
    output.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    if (output.write(bytes) != bytes.size() || !output.commit())
        return fail(error, "模型配置未保存，旧文件保留");
    return true;
}
void ProviderConfiguration::synchronize() {
    const int robot = m_backend ? m_backend->clientId() : 0;
    if (robot == m_robot)
        return;
    m_robot = robot;
    QPointer<ProviderConfiguration> alive(this);
    load();
    if (alive)
        emit scopeChanged();
}
void ProviderConfiguration::load() {
    cancelCatalog();
    m_models.clear();
    const auto revision = ++m_revision;
    QPointer<ProviderConfiguration> alive(this);
    if (m_runtime)
        m_runtime->retireOptional("decision");
    if (!alive || revision != m_revision)
        return;
    QVariantMap nodes;
    QString error;
    const bool read = readNodes(&nodes, &error);
    m_usingStartup = read && !nodes.contains(QString::number(m_robot)) && !nodes.contains("0");
    m_current = read ? nodes.value(QString::number(m_robot), nodes.value("0", m_startup)).toMap()
                     : defaults();
    if (!validate(m_current, &error)) {
        m_current = defaults();
        m_applyError = error;
    } else
        m_applyError = read ? QString{} : error;
    if (m_applyError.isEmpty()) {
        const bool applied = activate(&error);
        if (!alive || revision != m_revision)
            return;
        if (!applied)
            m_applyError = error;
    }
    if (!alive || revision != m_revision)
        return;
    m_status = m_applyError.isEmpty() ? QStringLiteral("已恢复提供者配置；未请求推理或模型清单")
                                      : m_applyError;
    emit currentChanged();
    if (!alive || revision != m_revision)
        return;
    emit modelsChanged();
    if (alive && revision == m_revision)
        emit stateChanged();
}
bool ProviderConfiguration::activate(QString *error) {
    if (!m_runtime || !m_services)
        return fail(error, "模型服务宿主不可用");
    // A GUI save explicitly selects a supported preset. Merely starting or
    // selecting an identity must preserve third-party plugins and advanced
    // CLI/profile options that this panel does not edit.
    if (m_usingStartup && !m_startupRuntime.isEmpty()) {
        const auto configurationError = m_startupRuntime.value("error").toString();
        if (!configurationError.isEmpty())
            return fail(error, configurationError);
        return m_runtime->replaceOptional("decision", m_startupRuntime.value("id").toString(),
                                          m_startupRuntime.value("configuration").toMap(),
                                          m_startupRuntime.value("enabled").toBool(), error);
    }
    if (!m_current.value("enabled").toBool())
        return m_runtime->replaceOptional("decision", pluginId(), {}, false, error);
    QVariantMap configuration{
        {"model", m_current.value("model")},
        {"timeout_ms", m_current.value("timeoutMs").toString().toInt()},
        {"max_output_tokens", m_current.value("maxOutputTokens").toString().toInt()}};
    if (m_current.value("kind") == "codex") {
        configuration.insert("executable", m_current.value("executable"));
        configuration.insert("auth_home", m_current.value("authHome"));
        configuration.insert("reasoning", m_current.value("reasoning"));
    } else {
        const auto name = m_current.value("keyEnv").toString();
        configuration.insert("key",
                             name.isEmpty() ? QByteArray{} : qgetenv(name.toUtf8().constData()));
        configuration.insert("endpoint", m_current.value("endpoint"));
        configuration.insert("api", m_current.value("api"));
        configuration.insert("format", m_current.value("format"));
        configuration.insert("provider",
                             m_current.value("kind") == "deepseek" ? "deepseek" : "generic");
        if (m_current.value("kind") == "deepseek")
            configuration.insert("thinking", m_current.value("thinking"));
    }
    m_services->setDecisionMinimumInterval(m_current.value("minimumIntervalMs").toString().toInt());
    return m_runtime->replaceOptional("decision", pluginId(), configuration, true, error);
}
bool ProviderConfiguration::save(const QVariantMap &values) {
    QPointer<ProviderConfiguration> alive(this);
    const int robot = m_robot;
    const auto revision = m_revision;
    QString error = lockReason();
    if (!error.isEmpty() || !validate(values, &error)) {
        m_status = error;
        emit stateChanged();
        return false;
    }
    if (!alive || robot != m_robot || revision != m_revision)
        return false;
    if (!writeNode(values, &error)) {
        m_status = error;
        emit stateChanged();
        return false;
    }
    cancelCatalog();
    m_models.clear();
    m_current = values;
    m_usingStartup = false;
    const auto savedRevision = ++m_revision;
    m_changing = true;
    m_applyError.clear();
    const bool applied = activate(&error);
    if (!alive)
        return false;
    m_changing = false;
    if (savedRevision != m_revision)
        return false;
    if (!applied)
        m_applyError = error;
    m_status = applied ? QStringLiteral("已保存并应用提供者配置；未请求推理")
                       : QStringLiteral("已保存，提供者尚不可用：") + error;
    emit currentChanged();
    if (!alive)
        return false;
    emit modelsChanged();
    if (alive)
        emit stateChanged();
    return bool(alive); // Saved intent is distinct from adapter/account availability.
}
bool ProviderConfiguration::inspect(const QVariantMap &values) {
    QString error = lockReason();
    if (!error.isEmpty() || !validate(values, &error)) {
        m_status = error;
        emit stateChanged();
        return false;
    }
    m_status = QStringLiteral("配置格式有效；%1；未连接账号、未保存、未请求推理")
                   .arg(credentialState(values));
    emit stateChanged();
    return true;
}
void ProviderConfiguration::cancelCatalog() {
    ++m_catalogGeneration;
    m_deadline.stop();
    auto reply = m_catalog;
    m_catalog = nullptr;
    m_catalogBytes.clear();
    if (reply) {
        reply->disconnect(this);
        reply->abort();
        reply->deleteLater();
    }
}
void ProviderConfiguration::retireForRulesChange() {
    cancelCatalog();
    m_models.clear();
    m_status = QStringLiteral("赛季／用途已切换；旧目录请求已取消，提供者不会自动重新启用");
    emit modelsChanged();
    emit stateChanged();
}
bool ProviderConfiguration::refreshModels() {
    if (m_backend && m_backend->rulesContext().value("environment") == QLatin1String("competition")) {
        m_status = QStringLiteral("比赛配置不请求外部模型目录；请在训练／赛外准备并核验完全本地部署");
        emit stateChanged();
        return false;
    }
    const auto reason = lockReason();
    const auto url = catalogUrl();
    if (!reason.isEmpty() || url.isEmpty() || !url.isValid()) {
        m_status = reason.isEmpty() ? QStringLiteral("当前端点未提供已知模型清单路径") : reason;
        emit stateChanged();
        return false;
    }
    const auto env = m_current.value("keyEnv").toString();
    const auto key = env.isEmpty() ? QByteArray{} : qgetenv(env.toUtf8().constData());
    if ((!localUrl(url) && key.isEmpty()) || key.size() > 4096 || key.contains('\n') ||
        key.contains('\r')) {
        m_status = "密钥环境变量缺失或格式无效；未发送模型清单请求";
        emit stateChanged();
        return false;
    }
    cancelCatalog();
    m_models.clear();
    const auto generation = m_catalogGeneration;
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::ManualRedirectPolicy);
    if (!key.isEmpty())
        request.setRawHeader("Authorization", "Bearer " + key);
    request.setRawHeader("Accept", "application/json");
    m_catalog = m_network.get(request);
    auto *reply = m_catalog.data();
    reply->setReadBufferSize(262145);
    connect(reply, &QIODevice::readyRead, this, [this, reply, generation] {
        if (generation != m_catalogGeneration || reply != m_catalog)
            return;
        m_catalogBytes += reply->read(262145 - m_catalogBytes.size());
        if (m_catalogBytes.size() > 262144) {
            cancelCatalog();
            m_status = "模型清单过大，已停止读取";
            emit stateChanged();
        }
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation] {
        if (generation != m_catalogGeneration || reply != m_catalog)
            return;
        m_deadline.stop();
        m_catalogBytes += reply->read(262145 - m_catalogBytes.size());
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QJsonParseError parse;
        const auto document = QJsonDocument::fromJson(m_catalogBytes, &parse);
        const bool ok = reply->error() == QNetworkReply::NoError && status >= 200 && status < 300 &&
                        m_catalogBytes.size() <= 262144 &&
                        parse.error == QJsonParseError::NoError && document.isObject() &&
                        document.object().value("data").isArray();
        m_catalog = nullptr;
        reply->deleteLater();
        m_catalogBytes.clear();
        if (ok) {
            QSet<QString> seen;
            const auto checked = QDateTime::currentMSecsSinceEpoch();
            for (const auto &item : document.object().value("data").toArray()) {
                const auto id = item.toObject().value("id").toString();
                if (id.trimmed().isEmpty() || !text(id, 128) || seen.contains(id))
                    continue;
                seen.insert(id);
                m_models.append(QVariantMap{{"id", id},
                                            {"title", id},
                                            {"available", true},
                                            {"source", "provider_catalog"},
                                            {"checked_at_ms", checked}});
                if (m_models.size() >= 64)
                    break;
            }
            m_status = QStringLiteral("端点列出%1个模型；不代表推理调用或建议质量已验证")
                           .arg(m_models.size());
        } else
            m_status =
                QStringLiteral("模型清单请求失败（HTTP %1）；没有可验证模型清单").arg(status);
        QPointer<ProviderConfiguration> alive(this);
        emit modelsChanged();
        if (alive)
            emit stateChanged();
    });
    m_deadline.start(qMin(15000, m_current.value("timeoutMs").toString().toInt()));
    m_status = "正在读取模型清单；未请求推理";
    QPointer<ProviderConfiguration> alive(this);
    emit modelsChanged();
    if (alive)
        emit stateChanged();
    return bool(alive);
}
