#include "TerminalBridgeHost.h"
#include "PluginHost.h"
#include "PluginPackageRuntime.h"
#include "PluginRuntime.h"
#include "RulesetCatalog.h"
#include "SeasonConfiguration.h"
#include "ServiceHub.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHostAddress>
#include <QJsonDocument>
#include <QLockFile>
#include <QRegularExpression>
#include <QSaveFile>
#include <QScopeGuard>
#include <QSet>
#include <QThread>
#include <QUrl>
#include <cmath>
#include <utility>

namespace {
const QString Role = QStringLiteral("bridge"), Contract = QStringLiteral("laboratory.bridge@1"), BuiltinId = QStringLiteral("bridge.tcp");
bool fail(QString *error, const QString &reason) { if (error) *error = reason; return false; }
bool exact(const QVariantMap &map, const QSet<QString> &keys) {
    if (map.size() != keys.size()) return false;
    for (const auto &key : keys) if (!map.contains(key)) return false;
    return true;
}
bool text(const QVariant &value, int maximum, bool empty = false) {
    if (value.metaType().id() != QMetaType::QString || value.toString().size() > maximum ||
        (!empty && value.toString().trimmed().isEmpty())) return false;
    for (const auto c : value.toString()) if (c.isNull() || c.category() == QChar::Other_Control ||
        c.category() == QChar::Separator_Line || c.category() == QChar::Separator_Paragraph) return false;
    return true;
}
bool integer(const QVariant &value, int low, int high) {
    const auto type = value.metaType().id();
    if (type != QMetaType::Int && type != QMetaType::UInt && type != QMetaType::LongLong &&
        type != QMetaType::ULongLong && type != QMetaType::Double) return false;
    const auto n = value.toDouble(); return std::isfinite(n) && std::floor(n) == n && n >= low && n <= high;
}
bool fingerprint(const QVariant &value, bool empty = false) {
    static const QRegularExpression pattern(QStringLiteral("\\A[0-9a-f]{64}\\z"));
    return text(value, 64, empty) && ((empty && value.toString().isEmpty()) || pattern.match(value.toString()).hasMatch());
}
bool locator(const QVariantMap &options, bool emptyHashes = false) {
    static const QRegularExpression package(QStringLiteral("\\A[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*\\z"));
    static const QRegularExpression service(QStringLiteral("\\A[a-z][a-z0-9_.-]{0,79}@[1-9][0-9]{0,3}\\z"));
    return exact(options, {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"}) &&
        text(options.value("package_id"), 64) && package.match(options.value("package_id").toString()).hasMatch() &&
        text(options.value("service_name"), 96) && service.match(options.value("service_name").toString()).hasMatch() &&
        fingerprint(options.value("package_fingerprint"), emptyHashes) && fingerprint(options.value("configuration_fingerprint"), emptyHashes);
}
bool sameProvider(const QVariantMap &a, const QVariantMap &b) {
    for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})
        if (a.value(QLatin1String(key)) != b.value(QLatin1String(key))) return false;
    return true;
}
QVariantMap registered(PluginPackageRuntime *packages, const QVariantMap &options, bool hashes) {
    if (packages) for (const auto &entry : packages->serviceProviders(Role, Contract)) {
        const auto row = entry.toMap();
        if (row.value("package_id") == options.value("package_id") && row.value("service_name") == options.value("service_name") &&
            (!hashes || sameProvider(row, options))) return row;
    }
    return {};
}
bool validScope(const QVariantMap &scope) {
    if (!exact(scope, {"profile_id", "field_profile_id", "capability_revision", "environment"}) || !text(scope.value("profile_id"), 128) ||
        (scope.value("environment") != "training" && scope.value("environment") != "competition")) return false;
    const auto rules = RulesetCatalog::profile(scope.value("profile_id").toString());
    return !rules.isEmpty() && scope.value("field_profile_id") == rules.value("field_profile_id") && scope.value("capability_revision") == rules.value("capability_revision");
}
bool readSettings(const QString &path, QVariantList *profiles, QString *error) {
    profiles->clear(); if (path.isEmpty() || !QFileInfo::exists(path)) return true;
    QFile input(path);
    if (QFileInfo(path).isSymLink() || !input.open(QIODevice::ReadOnly)) return fail(error, "实验室桥配置不可读取或为符号链接；未自动连接");
    const auto bytes = input.read(64 * 1024 + 1); QJsonParseError parse;
    const auto doc = QJsonDocument::fromJson(bytes, &parse); const auto root = doc.toVariant().toMap();
    if (bytes.size() > 64 * 1024 || parse.error != QJsonParseError::NoError || !doc.isObject() ||
        !exact(root, {"schema", "profiles"}) || !integer(root.value("schema"), 1, 1) ||
        root.value("profiles").metaType().id() != QMetaType::QVariantList || root.value("profiles").toList().size() > 32)
        return fail(error, "实验室桥配置损坏或版本未知；原文件保留，未启用");
    QSet<QByteArray> seen;
    for (const auto &entry : root.value("profiles").toList()) {
        const auto record = entry.toMap(), scope = record.value("scope").toMap(), values = record.value("values").toMap();
        if (entry.metaType().id() != QMetaType::QVariantMap || !exact(record, {"scope", "values"}) ||
            record.value("scope").metaType().id() != QMetaType::QVariantMap || !validScope(scope) ||
            record.value("values").metaType().id() != QMetaType::QVariantMap || !TerminalBridgeHost::validatePublic(values, error))
            return fail(error, "实验室桥配置含无效规则、未知字段或提供者选项；原文件保留");
        if (values.value("provider_kind") == "package" && !locator(values.value("provider_options").toMap()))
            return fail(error, "已保存的桥接插件缺少原生内容／配置指纹；未启用");
        const auto key = QJsonDocument::fromVariant(scope).toJson(QJsonDocument::Compact);
        if (seen.contains(key)) return fail(error, "实验室桥配置规则范围重复；原文件保留");
        seen.insert(key); profiles->append(record);
    }
    return true;
}
QString redact(QString value, const QString &token) { if (!token.isEmpty()) value.replace(token, "<bridge-token>"); return value.left(512); }
}
QVariantMap TerminalBridgeHost::defaults() {
    return {{"provider_kind", "tcp"}, {"provider_options", QVariantMap{}}, {"bind", "127.0.0.1"}, {"listen", true}, {"listen_port", 0},
        {"peer", ""}, {"token_env", "ROBOMASTER_BRIDGE_TOKEN"}, {"export_snapshots", false}, {"export_events", false}};
}
bool TerminalBridgeHost::validatePublic(const QVariantMap &values, QString *error) {
    if (error) error->clear();
    if (!exact(values, {"provider_kind", "provider_options", "bind", "listen", "listen_port", "peer", "token_env", "export_snapshots", "export_events"}) ||
        !text(values.value("provider_kind"), 16) || values.value("provider_options").metaType().id() != QMetaType::QVariantMap)
        return fail(error, "实验室桥只接受明确提供者、公共地址和导出开关；不接受token值／附加命令");
    const auto options = values.value("provider_options").toMap();
    if (!((values.value("provider_kind") == "tcp" && options.isEmpty()) || (values.value("provider_kind") == "package" && locator(options, true))))
        return fail(error, "TCP提供者选项须为空；插件仅接受准确包／服务和两个原生指纹");
    for (const auto &key : {"listen", "export_snapshots", "export_events"})
        if (values.value(QLatin1String(key)).metaType().id() != QMetaType::Bool) return fail(error, "监听和导出开关必须为实际布尔值");
    QHostAddress address;
    static const QRegularExpression environment(QStringLiteral("\\A[A-Za-z_][A-Za-z0-9_]{0,95}\\z"));
    if (!text(values.value("bind"), 256) || !address.setAddress(values.value("bind").toString()) || address.isNull() ||
        !integer(values.value("listen_port"), 0, 65535) || !text(values.value("peer"), 2048, true) ||
        !text(values.value("token_env"), 96) || !environment.match(values.value("token_env").toString()).hasMatch())
        return fail(error, "填写数字监听地址、0–65535整数端口及token环境变量名；不填写凭据值");
    const auto peer = values.value("peer").toString(); const QUrl url(peer, QUrl::StrictMode);
    if (!peer.isEmpty() && (!url.isValid() || url.isRelative() || url.scheme() != "tcp" || url.host().isEmpty() ||
        url.port() < 1 || url.port() > 65535 || !url.userInfo().isEmpty() || url.authority(QUrl::FullyEncoded).contains('@') ||
        !url.path().isEmpty() || url.hasQuery() || url.hasFragment()))
        return fail(error, "对端仅接受tcp://主机:端口，不包含路径、用户信息、查询或片段");
    return (values.value("listen").toBool() || !peer.isEmpty()) || fail(error, "至少明确启用监听或填写实际对端；没有默认远端");
}
TerminalBridgeHost::TerminalBridgeHost(PluginHost *plugins, QString directory, SeasonConfiguration *season, ServiceHub *services, QString file, QObject *parent)
    : QObject(parent), m_plugins(plugins), m_directory(std::move(directory)), m_file(std::move(file)), m_season(season), m_services(services), m_current(defaults()) {
    if (season) {
        connect(season, &SeasonConfiguration::aboutToChange, this, &TerminalBridgeHost::stop);
        connect(season, &SeasonConfiguration::contextChanged, this, [this] { load(); emit changed(); });
        connect(season, &SeasonConfiguration::stateChanged, this, &TerminalBridgeHost::changed);
        connect(season, &QObject::destroyed, this, &TerminalBridgeHost::stop);
    }
    if (services) {
        connect(services, &ServiceHub::serviceStatusChanged, this, &TerminalBridgeHost::synchronize);
        connect(services, &QObject::destroyed, this, [this] {
            ++m_generation; m_owned = false; m_providerIdentity.clear(); m_changing = false;
            m_status = QStringLiteral("桥接宿主已销毁；没有自动替换"); emit changed();
        });
    }
    load(); refreshProviders();
}
TerminalBridgeHost::~TerminalBridgeHost() {
    blockSignals(true);
    if (m_season) disconnect(m_season, nullptr, this, nullptr);
    if (m_services) disconnect(m_services, nullptr, this, nullptr);
    if (m_packages) disconnect(m_packages, nullptr, this, nullptr);
    retire();
}
QVariantMap TerminalBridgeHost::scope() const {
    if (!m_season) return {};
    const auto rules = m_season->current(); return {{"profile_id", m_season->profileId()}, {"field_profile_id", rules.value("field_profile_id")},
        {"capability_revision", rules.value("capability_revision")}, {"environment", m_season->environment()}};
}
QString TerminalBridgeHost::lockReason() const {
    if (m_changing) return QStringLiteral("实验室桥正在切换");
    if (!m_season || !m_services) return QStringLiteral("规则或桥接宿主未就绪");
    if (m_season->environment() != "training") return QStringLiteral("实验室原始桥只供训练；比赛范围不启用");
    if (!m_season->editable()) return m_season->lockReason();
    if (m_season->context().value("configuration_valid") != QVariant(true) || !validScope(scope())) return QStringLiteral("正式规则范围无效；桥接未启用");
    return {};
}
bool TerminalBridgeHost::editable() const { return lockReason().isEmpty(); }
bool TerminalBridgeHost::active() const { return !m_changing && m_owned && m_services && m_services->ownsBridge(this); }
bool TerminalBridgeHost::reject(const QString &reason) { m_status = reason.left(512); emit changed(); return false; }
void TerminalBridgeHost::load() {
    m_current = defaults(); m_configurationValid = true; m_configurationSaved = false; m_configurationError.clear(); QVariantList profiles;
    if (!readSettings(m_file, &profiles, &m_configurationError)) { m_configurationValid = false; m_status = m_configurationError; return; }
    for (const auto &entry : profiles) if (entry.toMap().value("scope").toMap() == scope()) {
        m_current = entry.toMap().value("values").toMap(); m_configurationSaved = true; break;
    }
    m_status = QStringLiteral("桥接选择与导出意向已载入；未自动监听、连接或导出");
}
bool TerminalBridgeHost::persist(const QVariantMap &values) {
    if (m_file.isEmpty() || QFileInfo(m_file).isSymLink() || !QDir().mkpath(QFileInfo(m_file).absolutePath()))
        return reject(QStringLiteral("桥接配置目录不可写或目标为符号链接；原文件保留"));
    QLockFile lock(m_file + ".lock"); if (!lock.tryLock(0)) return reject(QStringLiteral("另一实例正在保存桥接配置"));
    QVariantList profiles; QString error;
    // Explicit Save is the sole malformed-file recovery operation.
    if (!readSettings(m_file, &profiles, &error)) profiles.clear();
    bool replaced = false; const QVariantMap record{{"scope", scope()}, {"values", values}};
    for (auto &entry : profiles) if (entry.toMap().value("scope").toMap() == scope()) { entry = record; replaced = true; break; }
    if (!replaced) { if (profiles.size() >= 32) return reject(QStringLiteral("桥接规则范围已满32项；未删除其他配置")); profiles.append(record); }
    const auto bytes = QJsonDocument::fromVariant(QVariantMap{{"schema", 1}, {"profiles", profiles}}).toJson(QJsonDocument::Compact);
    QSaveFile output(m_file);
    if (bytes.size() > 64 * 1024 || !output.open(QIODevice::WriteOnly) || !output.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner) ||
        output.write(bytes) != bytes.size() || !output.commit()) return reject(QStringLiteral("桥接配置超过64KiB或原子保存失败；原文件保留"));
    return true;
}
QVariantList TerminalBridgeHost::providerCatalog() const {
    QVariantList rows{QVariantMap{{"provider_kind", "tcp"}, {"plugin_id", BuiltinId}, {"label", QStringLiteral("实验室TCP字节桥")},
        {"available", m_builtinAvailable}, {"default_options", QVariantMap{}}}};
    if (m_packages) for (const auto &entry : m_packages->serviceProviders(Role, Contract)) {
        auto row = entry.toMap(); QVariantMap options;
        for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"}) options[QLatin1String(key)] = row.value(QLatin1String(key));
        row["provider_kind"] = "package"; row["available"] = true; row["default_options"] = options;
        row["label"] = row.value("title").toString() + " · " + row.value("package_id").toString() + " / " + row.value("service_name").toString(); rows.append(row);
    }
    if (m_current.value("provider_kind") == "package" && selectedProvider().isEmpty()) {
        auto row = m_current.value("provider_options").toMap(); row["provider_kind"] = "package"; row["available"] = false; row["retained"] = true;
        row["default_options"] = m_current.value("provider_options"); row["label"] = row.value("package_id").toString() + " / " +
            row.value("service_name").toString() + QStringLiteral(" · 已保存，缺失或内容已变化"); rows.append(row);
    }
    return rows;
}
QVariantMap TerminalBridgeHost::selectedProvider() const {
    if (m_current.value("provider_kind") == "tcp") return m_builtinAvailable ? QVariantMap{{"provider_kind", "tcp"}, {"plugin_id", BuiltinId}} : QVariantMap{};
    return registered(m_packages, m_current.value("provider_options").toMap(), true);
}
void TerminalBridgeHost::refreshProviders() {
    if (QThread::currentThread() != thread()) return;
    int matches = 0;
    if (m_plugins) for (const auto &entry : PluginHost::discover(m_directory)) {
        const auto row = entry.toMap(); if (row.value("id") == BuiltinId && row.value("role") == Role && row.value("contract") == QLatin1String(ExtensionPlugin_iid)) ++matches;
    }
    m_builtinAvailable = matches == 1; synchronize();
}
void TerminalBridgeHost::setPackageRuntime(PluginPackageRuntime *runtime) {
    if (QThread::currentThread() != thread() || m_packages == runtime) return;
    QPointer<TerminalBridgeHost> alive(this); const bool package = m_current.value("provider_kind") == "package";
    const auto generation = m_generation + (package ? 1 : 0); if (package) retire();
    if (!alive || generation != m_generation) return;
    if (m_packages) disconnect(m_packages, nullptr, this, nullptr);
    m_packages = runtime;
    if (runtime) {
        connect(runtime, &PluginPackageRuntime::changed, this, &TerminalBridgeHost::synchronize);
        connect(runtime, &QObject::destroyed, this, [this] {
            if (m_current.value("provider_kind") == "package") {
                QPointer<TerminalBridgeHost> alive(this); retire(); if (!alive) return;
                m_status = QStringLiteral("桥接插件注册表已退役；旧连接及远端投影已清除，没有自动替换");
            }
            emit changed();
        });
    }
    emit changed();
}
void TerminalBridgeHost::setLegacyRuntime(PluginRuntime *runtime) { m_legacy = runtime; }
void TerminalBridgeHost::retire() { ++m_generation; m_owned = false; m_providerIdentity.clear(); if (m_services) m_services->releaseBridge(this); }
void TerminalBridgeHost::stop() {
    if (QThread::currentThread() != thread()) return;
    QPointer<TerminalBridgeHost> alive(this); m_changing = true; retire(); if (!alive) return;
    m_changing = false; m_status = QStringLiteral("本桥接已停并撤销旧远端投影；本机与其他功能继续，不影响后来替换的服务"); emit changed();
}
void TerminalBridgeHost::synchronize() {
    if (m_changing) return;
    if (m_owned && (!m_services || !m_services->ownsBridge(this) || (m_current.value("provider_kind") == "package" && selectedProvider().isEmpty()))) {
        QPointer<TerminalBridgeHost> alive(this); m_changing = true; retire(); if (!alive) return;
        m_changing = false; m_status = QStringLiteral("桥接所有权／插件租约已退役；旧远端投影已清除，没有自动替换");
    }
    emit changed();
}
bool TerminalBridgeHost::save(const QVariantMap &input) {
    if (QThread::currentThread() != thread()) return false;
    const auto locked = lockReason(); if (!locked.isEmpty()) return reject(locked);
    QString error; if (!validatePublic(input, &error)) return reject(error); auto values = input;
    if (values.value("provider_kind") == "package") {
        auto options = values.value("provider_options").toMap(); const auto ready = registered(m_packages, options, false);
        if (!ready.isEmpty()) {
            for (const auto &key : {"package_fingerprint", "configuration_fingerprint"}) {
                const auto name = QLatin1String(key); if (!options.value(name).toString().isEmpty() && options.value(name) != ready.value(name))
                    return reject(QStringLiteral("桥接插件内容／配置已变化；先查看刷新后的来源再明确选择保存"));
                options[name] = ready.value(name);
            }
        } else if (m_current.value("provider_kind") != "package" || !m_configurationSaved || !sameProvider(options, m_current.value("provider_options").toMap()))
            return reject(QStringLiteral("新选桥接插件未运行；可保留原已保存的缺失来源，但不能替换成未知来源"));
        values["provider_options"] = options;
    }
    if (!persist(values)) return false;
    QPointer<TerminalBridgeHost> alive(this); m_changing = true; retire(); if (!alive) return false;
    m_current = values; m_configurationValid = m_configurationSaved = true; m_configurationError.clear(); m_changing = false;
    m_status = QStringLiteral("实验室桥配置已保存；未自动监听、连接或导出，须明确启用"); emit changed(); return true;
}
bool TerminalBridgeHost::setEnabled(bool enable) {
    if (QThread::currentThread() != thread()) return false;
    if (!enable) { stop(); return true; }
    const auto locked = lockReason(); if (!locked.isEmpty()) return reject(locked);
    QString error; if (!m_configurationSaved || !m_configurationValid || !validatePublic(m_current, &error))
        return reject(error.isEmpty() ? QStringLiteral("先明确保存当前规则范围的桥接配置") : error);
    if (active()) return true;
    QPointer<TerminalBridgeHost> alive(this); refreshProviders(); if (!alive) return false;
    const auto choice = selectedProvider(); if (choice.isEmpty()) return reject(QStringLiteral("已保存的桥接来源缺失、重复或内容／配置已变化；没有自动回退"));
    const auto bytes = qgetenv(m_current.value("token_env").toString().toLatin1().constData());
    const auto token = QString::fromUtf8(bytes);
    if (bytes.size() > 1024 || token.toUtf8() != bytes || !text(token, 256, true)) return reject(QStringLiteral("token环境变量包含无效文本或超过256字符；未启用"));
    if (m_current.value("listen").toBool() && !QHostAddress(m_current.value("bind").toString()).isLoopback() && token.isEmpty())
        return reject(QStringLiteral("非回环实验室监听需要已设置的共享token环境变量；未启用"));
    const QVariantMap native{{"laboratory", true}, {"bind", m_current.value("bind")}, {"listen", m_current.value("listen")},
        {"listen_port", m_current.value("listen_port")}, {"peer", m_current.value("peer")}, {"token", token}};
    const auto generation = ++m_generation; m_changing = true;
    const auto transition = qScopeGuard([this, alive, generation] { if (alive && generation == m_generation) { m_changing = false; emit changed(); } });
    const auto current = [this, alive, generation] { return alive && generation == m_generation && m_services && m_season; };
    if (m_legacy) m_legacy->retireOptional(Role);
    if (!current()) return false;
    const bool package = m_current.value("provider_kind") == "package";
    if (package && selectedProvider() != choice) return reject(QStringLiteral("旧桥退役期间所选插件身份已变化；请重新明确启用"));
    ServiceEndpoint *created = nullptr; QVariantMap identity;
    if (package) {
        if (m_packages) created = m_packages->createProviderService(choice.value("package_id").toString(), choice.value("service_name").toString(), Role, Contract, &error, &identity);
    } else {
        auto *factory = m_plugins ? m_plugins->loadExtension(m_directory, BuiltinId, Role, &error) : nullptr;
        if (current() && factory) { try { created = factory->createService(); } catch (...) { error = QStringLiteral("桥接工厂创建发生原生异常"); } }
        identity = choice;
    }
    QPointer<ServiceEndpoint> endpoint(created);
    auto dispose = qScopeGuard([endpoint] {
        if (!endpoint || endpoint->parent()) return;
        if (endpoint->thread() != QThread::currentThread()) { endpoint->deleteLater(); return; }
        endpoint->stop(); if (endpoint) delete endpoint.data();
    });
    if (!current()) return false;
    if (!endpoint) return reject(redact(error.isEmpty() ? QStringLiteral("桥接工厂未创建端点；其他功能继续") : error, token));
    if (endpoint->parent() || endpoint->thread() != thread()) return reject(QStringLiteral("桥接工厂须转交新的、无父对象且位于界面线程的静止端点"));
    if (package && (identity != selectedProvider() || !sameProvider(identity, m_current.value("provider_options").toMap())))
        return reject(QStringLiteral("创建期间桥接提供者租约已变化；未保留旧来源"));
    dispose.dismiss();
    const bool started = m_services->startBridge(std::unique_ptr<ServiceEndpoint>(endpoint.data()), native, &error, this,
        m_current.value("export_snapshots").toBool(), m_current.value("export_events").toBool());
    if (!current()) return false;
    if (!started || !m_services->ownsBridge(this) || (package && selectedProvider() != identity)) {
        m_services->releaseBridge(this); if (!current()) return false;
        return reject(redact(error.isEmpty() ? QStringLiteral("桥接未保持当前所有权／租约；没有自动替换") : error, token));
    }
    m_owned = true; m_providerIdentity = identity;
    m_status = QStringLiteral("实验室桥已启用；只按明确导出开关发送，接收数据不等于官方权威或已验证队伍共享"); return true;
}
QVariantMap TerminalBridgeHost::details() const {
    QPointer<const TerminalBridgeHost> alive(this); const bool owner = m_services && m_services->ownsBridge(this);
    auto bridge = owner ? m_services->bridgeDetails() : QVariantMap{}; if (!alive) return {};
    const bool currentOwner = m_services && m_services->ownsBridge(this); if (!currentOwner) bridge.clear();
    return {{"active", active()}, {"provider_kind", m_current.value("provider_kind")}, {"provider_identity", m_providerIdentity},
        {"configuration_valid", m_configurationValid}, {"configuration_saved", m_configurationSaved}, {"configuration_error", m_configurationError},
        {"provider_available", !selectedProvider().isEmpty()}, {"owner_current", currentOwner}, {"bridge", bridge}, {"provider_reported", bridge},
        {"context", scope()}, {"environment", m_season ? m_season->environment() : QString{}}, {"settings_file", m_file},
        {"export_snapshots", m_current.value("export_snapshots")}, {"export_events", m_current.value("export_events")},
        {"token_value_exposed", false}, {"enabled_persisted", false}, {"automatic_fallback", false}, {"peer_authenticated", false},
        {"authoritative", false}, {"ai_input_ready", false}, {"status", m_status}};
}
