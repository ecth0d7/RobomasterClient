#include "TerminalSpeechHost.h"
#include "PluginHost.h"
#include "PluginPackageRuntime.h"
#include "PluginRuntime.h"
#include "RulesetCatalog.h"
#include "SeasonConfiguration.h"
#include "ServiceHub.h"
#include "ServiceEndpoint.h"

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
constexpr int SettingsLimit = 64 * 1024;
const QString SpeechRole = QStringLiteral("speech");
const QString SpeechContract = QStringLiteral("terminal.speech@1");
bool fail(QString *error, const QString &reason) { if (error) *error = reason; return false; }
bool exact(const QVariantMap &values, const QSet<QString> &keys) {
    if (values.size() != keys.size()) return false;
    for (const auto &key : keys) if (!values.contains(key)) return false;
    return true;
}
bool text(const QVariant &value, int maximum, bool empty = false) {
    if (value.metaType().id() != QMetaType::QString || value.toString().size() > maximum ||
        (!empty && value.toString().trimmed().isEmpty())) return false;
    for (const auto c : value.toString())
        if (c.isNull() || c.category() == QChar::Other_Control || c.category() == QChar::Separator_Line ||
            c.category() == QChar::Separator_Paragraph) return false;
    return true;
}
bool integer(const QVariant &value, int minimum, int maximum) {
    const auto type = value.metaType().id();
    if (type != QMetaType::Int && type != QMetaType::UInt && type != QMetaType::LongLong &&
        type != QMetaType::ULongLong && type != QMetaType::Double) return false;
    const auto number = value.toDouble();
    return std::isfinite(number) && std::floor(number) == number && number >= minimum && number <= maximum;
}
bool fingerprint(const QVariant &value, bool empty = false) {
    static const QRegularExpression pattern(QStringLiteral("\\A[0-9a-f]{64}\\z"));
    return text(value, 64, empty) && ((empty && value.toString().isEmpty()) || pattern.match(value.toString()).hasMatch());
}
bool locator(const QVariantMap &options) {
    static const QRegularExpression package(QStringLiteral("\\A[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*\\z"));
    static const QRegularExpression service(QStringLiteral("\\A[a-z][a-z0-9_.-]{0,79}@[1-9][0-9]{0,3}\\z"));
    return text(options.value("package_id"), 64) && package.match(options.value("package_id").toString()).hasMatch() &&
        text(options.value("service_name"), 96) && service.match(options.value("service_name").toString()).hasMatch();
}
bool sameIdentity(const QVariantMap &left, const QVariantMap &right) {
    for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})
        if (left.value(QLatin1String(key)) != right.value(QLatin1String(key))) return false;
    return true;
}
QVariantMap findPackage(PluginPackageRuntime *packages, const QVariantMap &options, bool hashes) {
    if (!packages) return {};
    for (const auto &entry : packages->serviceProviders(SpeechRole, SpeechContract)) {
        const auto row = entry.toMap();
        if (row.value("package_id") != options.value("package_id") || row.value("service_name") != options.value("service_name")) continue;
        if (!hashes || sameIdentity(row, options)) return row;
    }
    return {};
}
QString pluginId(const QString &kind) {
    if (kind == "espeak") return QStringLiteral("speech.espeak");
    if (kind == "http") return QStringLiteral("speech.piper-http");
    return {};
}
bool settingsScope(const QVariantMap &scope) {
    if (!exact(scope, {"profile_id", "field_profile_id", "capability_revision", "environment"}) ||
        !text(scope.value("profile_id"), 128) || !text(scope.value("field_profile_id"), 128) ||
        !text(scope.value("capability_revision"), 128) ||
        (scope.value("environment") != "training" && scope.value("environment") != "competition")) return false;
    const auto rules = RulesetCatalog::profile(scope.value("profile_id").toString());
    return !rules.isEmpty() && scope.value("field_profile_id") == rules.value("field_profile_id") &&
        scope.value("capability_revision") == rules.value("capability_revision");
}
bool readSettings(const QString &path, QVariantList *profiles, QString *error) {
    profiles->clear();
    if (path.isEmpty() || !QFileInfo::exists(path)) return true;
    QFile input(path);
    if (QFileInfo(path).isSymLink() || !input.open(QIODevice::ReadOnly))
        return fail(error, QStringLiteral("语音提供者配置不可读取或为符号链接；未自动启用"));
    const auto bytes = input.read(SettingsLimit + 1);
    QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(bytes, &parse);
    const auto root = document.toVariant().toMap();
    if (bytes.size() > SettingsLimit || parse.error != QJsonParseError::NoError || !document.isObject() ||
        !exact(root, {"schema", "profiles"}) || !integer(root.value("schema"), 1, 1) ||
        root.value("profiles").metaType().id() != QMetaType::QVariantList || root.value("profiles").toList().size() > 32)
        return fail(error, QStringLiteral("语音提供者配置损坏或版本未知；原文件保留，未启用"));
    QSet<QByteArray> seen;
    for (const auto &entry : root.value("profiles").toList()) {
        const auto record = entry.toMap(), scope = record.value("scope").toMap(), values = record.value("values").toMap();
        if (entry.metaType().id() != QMetaType::QVariantMap || !exact(record, {"scope", "values"}) ||
            record.value("scope").metaType().id() != QMetaType::QVariantMap || !settingsScope(scope) ||
            record.value("values").metaType().id() != QMetaType::QVariantMap || !TerminalSpeechHost::validatePublic(values, error))
            return fail(error, QStringLiteral("语音配置含无效规则范围或提供者选项；原文件保留"));
        const auto options = values.value("provider_options").toMap();
        if (values.value("provider_kind") == "package" &&
            (!fingerprint(options.value("package_fingerprint")) || !fingerprint(options.value("configuration_fingerprint"))))
            return fail(error, QStringLiteral("已保存的语音插件缺少原生内容／配置指纹；未启用"));
        const auto key = QJsonDocument::fromVariant(scope).toJson(QJsonDocument::Compact);
        if (seen.contains(key)) return fail(error, QStringLiteral("语音配置规则范围重复；原文件保留"));
        seen.insert(key); profiles->append(record);
    }
    return true;
}
}

QVariantMap TerminalSpeechHost::providerDefaults(const QString &kind) {
    if (kind == "espeak") return {{"executable", ""}, {"voice", "cmn"}, {"speed", 175},
        {"player", ""}, {"playback", false}, {"timeout_ms", 15000}};
    if (kind == "http") return {{"endpoint", ""}, {"model", ""}, {"player", ""},
        {"playback", false}, {"timeout_ms", 15000}};
    if (kind == "package") return {{"package_id", ""}, {"service_name", ""},
        {"package_fingerprint", ""}, {"configuration_fingerprint", ""}};
    return {};
}
QVariantMap TerminalSpeechHost::defaults() {
    return {{"provider_kind", "espeak"}, {"provider_options", providerDefaults("espeak")}};
}
bool TerminalSpeechHost::validatePublic(const QVariantMap &values, QString *error) {
    if (error) error->clear();
    if (!exact(values, {"provider_kind", "provider_options"}) || !text(values.value("provider_kind"), 16) ||
        values.value("provider_options").metaType().id() != QMetaType::QVariantMap)
        return fail(error, QStringLiteral("语音只接受明确的提供者类型及其公共选项"));
    const auto kind = values.value("provider_kind").toString();
    const auto options = values.value("provider_options").toMap();
    const auto shape = providerDefaults(kind);
    QSet<QString> keys; for (auto it = shape.cbegin(); it != shape.cend(); ++it) keys.insert(it.key());
    if (shape.isEmpty() || !exact(options, keys)) return fail(error, QStringLiteral("语音选项含未知或缺失字段；不接受额外命令／凭据"));
    if (kind == "package")
        return (locator(options) && fingerprint(options.value("package_fingerprint"), true) &&
            fingerprint(options.value("configuration_fingerprint"), true)) ||
            fail(error, QStringLiteral("插件语音须明确包／服务标识及原生内容／配置指纹"));
    if (!text(options.value("player"), 1024, true) || options.value("playback").metaType().id() != QMetaType::Bool ||
        !integer(options.value("timeout_ms"), 50, 60000))
        return fail(error, QStringLiteral("播放器引用、实际布尔播放开关或50–60000ms超时无效"));
    if (kind == "espeak") {
        static const QRegularExpression voice(QStringLiteral("\\A[A-Za-z0-9_+.-]{1,48}\\z"));
        return (text(options.value("executable"), 1024, true) && text(options.value("voice"), 48) &&
            voice.match(options.value("voice").toString()).hasMatch() && integer(options.value("speed"), 80, 350)) ||
            fail(error, QStringLiteral("espeak程序引用、音色标识或80–350语速无效"));
    }
    if (!text(options.value("endpoint"), 2048, true) || !text(options.value("model"), 128, true))
        return fail(error, QStringLiteral("本机HTTP语音端点或可选音色标识无效"));
    if (options.value("endpoint").toString().isEmpty()) return true; // Explicit inactive draft, never an invented URL.
    const QUrl url(options.value("endpoint").toString(), QUrl::StrictMode);
    return (url.isValid() && !url.isRelative() && url.scheme() == "http" &&
        (QHostAddress(url.host()).isLoopback() || url.host() == "localhost") &&
        url.userInfo().isEmpty() && !url.authority(QUrl::FullyEncoded).contains('@') && !url.hasQuery() && !url.hasFragment() &&
        (url.port(-1) == -1 || (url.port() >= 1 && url.port() <= 65535))) ||
        fail(error, QStringLiteral("Piper仅接受明确的loopback HTTP端点；不保存URL凭据、查询或片段"));
}

TerminalSpeechHost::TerminalSpeechHost(PluginHost *plugins, QString directory, SeasonConfiguration *season,
    ServiceHub *services, QString settingsFile, QObject *parent)
    : QObject(parent), m_plugins(plugins), m_directory(std::move(directory)), m_file(std::move(settingsFile)),
      m_season(season), m_services(services), m_current(defaults()) {
    if (season) {
        connect(season, &SeasonConfiguration::aboutToChange, this, &TerminalSpeechHost::stop);
        connect(season, &SeasonConfiguration::contextChanged, this, [this] { load(); emit changed(); });
        connect(season, &SeasonConfiguration::stateChanged, this, &TerminalSpeechHost::changed);
        connect(season, &QObject::destroyed, this, &TerminalSpeechHost::stop);
    }
    if (services) {
        connect(services, &ServiceHub::serviceStatusChanged, this, &TerminalSpeechHost::synchronize);
        connect(services, &QObject::destroyed, this, [this] {
            ++m_generation; m_owned = false; m_providerIdentity.clear(); m_changing = false;
            m_status = QStringLiteral("语音队列宿主已销毁；未自动切换提供者"); emit changed();
        });
    }
    load(); refreshProviders();
}
TerminalSpeechHost::~TerminalSpeechHost() {
    blockSignals(true);
    if (m_season) disconnect(m_season, nullptr, this, nullptr);
    if (m_packages) disconnect(m_packages, nullptr, this, nullptr);
    if (m_services) disconnect(m_services, nullptr, this, nullptr);
    retire();
}
QVariantMap TerminalSpeechHost::scope() const {
    if (!m_season) return {};
    const auto rules = m_season->current();
    return {{"profile_id", m_season->profileId()}, {"field_profile_id", rules.value("field_profile_id")},
        {"capability_revision", rules.value("capability_revision")}, {"environment", m_season->environment()}};
}
QString TerminalSpeechHost::lockReason() const {
    if (m_changing) return QStringLiteral("语音提供者正在切换");
    if (!m_season || !m_services) return QStringLiteral("规则或语音队列宿主未就绪");
    if (!m_season->editable()) return m_season->lockReason();
    if (m_season->context().value("configuration_valid") != QVariant(true) || !settingsScope(scope()))
        return QStringLiteral("正式规则范围尚未确认；未启动语音");
    return {};
}
bool TerminalSpeechHost::editable() const { return lockReason().isEmpty(); }
bool TerminalSpeechHost::active() const { return !m_changing && m_owned && m_services && m_services->ownsSpeech(this); }
bool TerminalSpeechHost::reject(const QString &reason) { m_status = reason.left(512); emit changed(); return false; }
void TerminalSpeechHost::load() {
    m_current = defaults(); m_configurationValid = true; m_configurationSaved = false; m_configurationError.clear();
    QVariantList profiles;
    if (!readSettings(m_file, &profiles, &m_configurationError)) {
        m_configurationValid = false; m_status = m_configurationError; return;
    }
    for (const auto &entry : profiles) if (entry.toMap().value("scope").toMap() == scope()) {
        m_current = entry.toMap().value("values").toMap(); m_configurationSaved = true; break;
    }
    m_status = QStringLiteral("语音提供者选择已载入；未自动启用、合成或播放");
}
bool TerminalSpeechHost::persist(const QVariantMap &values) {
    if (m_file.isEmpty() || QFileInfo(m_file).isSymLink() || !QDir().mkpath(QFileInfo(m_file).absolutePath()))
        return reject(QStringLiteral("语音配置目录不可写或目标为符号链接；原配置保留"));
    QLockFile lock(m_file + ".lock");
    if (!lock.tryLock(0)) return reject(QStringLiteral("另一实例正在保存语音提供者配置"));
    QVariantList profiles; QString error;
    // Only explicit save can recover a malformed file. Normal reads, scope
    // changes and enabling never rewrite it or auto-start a default provider.
    if (!readSettings(m_file, &profiles, &error)) profiles.clear();
    bool replaced = false;
    const QVariantMap record{{"scope", scope()}, {"values", values}};
    for (auto &entry : profiles) if (entry.toMap().value("scope").toMap() == scope()) { entry = record; replaced = true; break; }
    if (!replaced) {
        if (profiles.size() >= 32) return reject(QStringLiteral("语音规则范围超过32项；未删除其他配置"));
        profiles.append(record);
    }
    const auto bytes = QJsonDocument::fromVariant(QVariantMap{{"schema", 1}, {"profiles", profiles}}).toJson(QJsonDocument::Compact);
    if (bytes.size() > SettingsLimit) return reject(QStringLiteral("语音配置超过64KiB；未截断保存"));
    QSaveFile output(m_file);
    if (!output.open(QIODevice::WriteOnly) || !output.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner) ||
        output.write(bytes) != bytes.size() || !output.commit()) return reject(QStringLiteral("语音配置原子保存失败；原配置保留"));
    return true;
}
QVariantList TerminalSpeechHost::providerCatalog() const {
    auto rows = m_builtinCatalog;
    if (m_packages) for (const auto &entry : m_packages->serviceProviders(SpeechRole, SpeechContract)) {
        auto row = entry.toMap();
        QVariantMap options; for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})
            options[QLatin1String(key)] = row.value(QLatin1String(key));
        row["provider_kind"] = "package"; row["available"] = true; row["default_options"] = options;
        row["label"] = row.value("title").toString() + " · " + row.value("package_id").toString() + " / " + row.value("service_name").toString();
        rows.append(row);
    }
    if (m_current.value("provider_kind") == "package") {
        const auto options = m_current.value("provider_options").toMap();
        bool found = false;
        for (const auto &entry : rows) if (entry.toMap().value("provider_kind") == "package" && sameIdentity(entry.toMap(), options)) found = true;
        if (!found) {
            auto row = options; row["provider_kind"] = "package"; row["available"] = false; row["retained"] = true;
            row["default_options"] = options; row["label"] = options.value("package_id").toString() + " / " +
                options.value("service_name").toString() + QStringLiteral(" · 已保存，当前缺失或内容已变化");
            rows.append(row);
        }
    }
    return rows;
}
QVariantMap TerminalSpeechHost::selectedProvider(bool hashes) const {
    const auto kind = m_current.value("provider_kind").toString();
    if (kind == "package") return findPackage(m_packages, m_current.value("provider_options").toMap(), hashes);
    for (const auto &entry : m_builtinCatalog) {
        const auto row = entry.toMap();
        if (row.value("provider_kind") == kind && row.value("available") == QVariant(true)) return row;
    }
    return {};
}
void TerminalSpeechHost::refreshProviders() {
    if (QThread::currentThread() != thread()) return;
    m_builtinCatalog.clear();
    const auto metadata = m_plugins ? PluginHost::discover(m_directory) : QVariantList{};
    for (const auto &kind : {QStringLiteral("espeak"), QStringLiteral("http")}) {
        const auto id = pluginId(kind); int count = 0;
        for (const auto &entry : metadata) {
            const auto row = entry.toMap();
            if (row.value("id") == id && row.value("role") == SpeechRole && row.value("contract") == QLatin1String(ExtensionPlugin_iid)) ++count;
        }
        m_builtinCatalog.append(QVariantMap{{"provider_kind", kind}, {"plugin_id", id}, {"available", count == 1},
            {"label", kind == "espeak" ? QStringLiteral("本机espeak") : QStringLiteral("本机Piper HTTP")},
            {"default_options", providerDefaults(kind)}});
    }
    synchronize();
}
void TerminalSpeechHost::setPackageRuntime(PluginPackageRuntime *runtime) {
    if (m_packages == runtime) return;
    QPointer<TerminalSpeechHost> alive(this);
    if (m_current.value("provider_kind") == "package") retire();
    if (!alive) return;
    if (m_packages) disconnect(m_packages, nullptr, this, nullptr);
    m_packages = runtime;
    if (runtime) {
        connect(runtime, &PluginPackageRuntime::changed, this, &TerminalSpeechHost::synchronize);
        connect(runtime, &QObject::destroyed, this, [this] {
            if (m_current.value("provider_kind") == "package") {
                QPointer<TerminalSpeechHost> alive(this); retire();
                if (!alive) return;
                m_status = QStringLiteral("插件注册表已销毁；语音租约已撤销，没有自动替换");
            }
            emit changed();
        });
    }
    emit changed();
}
void TerminalSpeechHost::setLegacyRuntime(PluginRuntime *runtime) { m_legacy = runtime; }
void TerminalSpeechHost::retire() {
    ++m_generation; m_owned = false; m_providerIdentity.clear();
    // Exact native ownership prevents an old host/lease from stopping a later
    // legacy PluginRuntime selection or another native owner's replacement.
    if (m_services) m_services->releaseSpeech(this);
}
void TerminalSpeechHost::stop() {
    if (QThread::currentThread() != thread()) return;
    QPointer<TerminalSpeechHost> alive(this); m_changing = true; retire();
    if (!alive) return;
    m_changing = false; m_status = QStringLiteral("本提供者已停用并清空队列；不影响后续其他宿主的语音服务"); emit changed();
}
void TerminalSpeechHost::synchronize() {
    if (m_changing) return;
    if (m_owned && (!m_services || !m_services->ownsSpeech(this) ||
        (m_current.value("provider_kind") == "package" && selectedProvider().isEmpty()))) {
        QPointer<TerminalSpeechHost> alive(this); m_changing = true; retire();
        if (!alive) return;
        m_changing = false; m_status = QStringLiteral("语音所有权／插件租约已退役；旧队列已取消，恢复后须明确启用");
    }
    emit changed();
}
bool TerminalSpeechHost::save(const QVariantMap &input) {
    if (QThread::currentThread() != thread()) return false;
    const auto locked = lockReason(); if (!locked.isEmpty()) return reject(locked);
    auto values = input; QString error;
    if (!validatePublic(values, &error)) return reject(error);
    if (values.value("provider_kind") == "package") {
        auto options = values.value("provider_options").toMap();
        const auto registered = findPackage(m_packages, options, false);
        if (!registered.isEmpty()) {
            // Fingerprints always come from the native registry. Nonempty stale
            // hashes require selecting the refreshed row before saving again.
            for (const auto &key : {"package_fingerprint", "configuration_fingerprint"}) {
                const auto name = QLatin1String(key);
                if (!options.value(name).toString().isEmpty() && options.value(name) != registered.value(name))
                    return reject(QStringLiteral("插件内容／配置已变化；请查看刷新后的来源再明确选择保存"));
                options[name] = registered.value(name);
            }
        } else if (m_current.value("provider_kind") != "package" ||
            !sameIdentity(options, m_current.value("provider_options").toMap())) {
            return reject(QStringLiteral("新选语音插件尚未运行；可保留原已保存的缺失来源，但不能启用或替换成未知来源"));
        }
        values["provider_options"] = options;
    }
    if (!persist(values)) return false;
    QPointer<TerminalSpeechHost> alive(this); m_changing = true; retire();
    if (!alive) return false;
    m_current = values; m_configurationValid = true; m_configurationSaved = true; m_configurationError.clear(); m_changing = false;
    m_status = QStringLiteral("语音提供者已保存；旧队列已取消，须明确启用，不会试播或自动恢复"); emit changed(); return true;
}
bool TerminalSpeechHost::setEnabled(bool enabled) {
    if (QThread::currentThread() != thread()) return false;
    if (!enabled) { stop(); return true; }
    const auto locked = lockReason(); if (!locked.isEmpty()) return reject(locked);
    QString error;
    if (!m_configurationSaved || !m_configurationValid || !validatePublic(m_current, &error))
        return reject(error.isEmpty() ? QStringLiteral("先在赛外明确保存有效的语音提供者配置") : error);
    if (active()) return true;
    QPointer<TerminalSpeechHost> alive(this);
    refreshProviders();
    if (!alive) return false;
    const auto choice = selectedProvider();
    if (choice.isEmpty()) return reject(QStringLiteral("已保存的语音来源缺失、重复或内容／配置已变化；没有自动回退"));
    const auto kind = m_current.value("provider_kind").toString();
    const auto options = m_current.value("provider_options").toMap();
    const auto verified = kind == "package" ? QStringLiteral("package:") + choice.value("package_id").toString() + "/" + choice.value("service_name").toString() : pluginId(kind);
    const auto blocked = m_season->optionalServiceBlockReason(SpeechRole, verified);
    if (!blocked.isEmpty()) return reject(blocked);
    if (kind == "http" && options.value("endpoint").toString().isEmpty())
        return reject(QStringLiteral("先保存实际本机Piper HTTP端点；没有默认端口或隐藏服务"));
    const auto generation = ++m_generation;
    m_changing = true;
    const auto finishTransition = qScopeGuard([this, alive, generation] {
        if (alive && generation == m_generation) { m_changing = false; emit changed(); }
    });
    const auto current = [this, alive, generation] { return alive && generation == m_generation && m_services && m_season; };
    // Explicit takeover retires the legacy controller's intent as well as its
    // endpoint. Construction, loading and catalog refresh remain passive.
    if (m_legacy) m_legacy->retireOptional(SpeechRole);
    if (!current()) return false;
    if (kind == "package" && selectedProvider() != choice)
        return reject(QStringLiteral("停用旧语音服务时所选插件身份已改变；请重新明确启用"));
    ServiceEndpoint *created = nullptr; QVariantMap identity;
    if (kind == "package") {
        if (m_packages) created = m_packages->createProviderService(choice.value("package_id").toString(),
            choice.value("service_name").toString(), SpeechRole, SpeechContract, &error, &identity);
    } else {
        auto *factory = m_plugins ? m_plugins->loadExtension(m_directory, verified, SpeechRole, &error) : nullptr;
        if (current() && factory) created = factory->createService();
        identity = choice;
    }
    QPointer<ServiceEndpoint> endpoint(created);
    auto dispose = qScopeGuard([endpoint] {
        if (!endpoint || endpoint->parent()) return;
        if (endpoint->thread() != QThread::currentThread()) { endpoint->deleteLater(); return; }
        endpoint->stop(); if (endpoint) delete endpoint.data();
    });
    if (!current()) return false;
    if (!endpoint) return reject(error.isEmpty() ? QStringLiteral("语音工厂未创建端点；其他功能继续") : error);
    if (endpoint->thread() != thread() || endpoint->parent())
        return reject(QStringLiteral("语音工厂必须转交新的、无父对象且位于界面线程的静止端点"));
    if (kind == "package" && (!sameIdentity(identity, choice) || identity != selectedProvider()))
        return reject(QStringLiteral("创建期间语音插件租约身份已改变；旧来源未启动"));
    // Package-specific executables/endpoints stay inside its separately reviewed
    // manifest configuration; the shared engine never smuggles UI options in.
    dispose.dismiss();
    const bool started = m_services->startSpeech(std::unique_ptr<ServiceEndpoint>(endpoint.data()),
        kind == "package" ? QVariantMap{} : options, &error, verified, this);
    if (!current()) return false;
    if (!started || !m_services->ownsSpeech(this) ||
        (kind == "package" && (selectedProvider() != identity || !sameIdentity(identity, options)))) {
        m_services->releaseSpeech(this);
        if (!current()) return false;
        return reject(error.isEmpty() ? QStringLiteral("语音启动未保持当前所有权／租约；没有自动替换") : error);
    }
    m_owned = true; m_providerIdentity = identity;
    m_status = QStringLiteral("所选语音提供者已启用；启用不试播，建议仍经原有时效／语音权限与去重边界");
    return true;
}
bool TerminalSpeechHost::testOutput() {
    if (QThread::currentThread() != thread()) return false;
    const auto locked = lockReason(); if (!locked.isEmpty()) return reject(locked);
    if (!active() || !m_services || !m_services->ownsSpeech(this))
        return reject(QStringLiteral("先明确启用本提供者；旧宿主不能向后来的语音服务提交试音"));
    QPointer<TerminalSpeechHost> alive(this); const auto generation = m_generation;
    const bool accepted = m_services->testSpeech(); // Fixed existing phrase; never arbitrary QML text/TTL.
    if (!alive || generation != m_generation || !m_services || !m_services->ownsSpeech(this)) return false;
    m_status = accepted ? QStringLiteral("试音／示例合成请求已被队列接纳；不代表音频已生成或播放完成") :
        QStringLiteral("试音请求未被接纳；请检查实际提供者、设备或音量状态，未自动切换来源");
    emit changed(); return accepted;
}
QVariantMap TerminalSpeechHost::details() const {
    QPointer<const TerminalSpeechHost> alive(this);
    const bool owner = m_services && m_services->ownsSpeech(this);
    auto reported = owner ? m_services->speechDetails() : QVariantMap{};
    if (!alive) return {};
    const bool currentOwner = m_services && m_services->ownsSpeech(this);
    if (!currentOwner) reported.clear();
    const bool available = !selectedProvider().isEmpty();
    return {{"active", active()}, {"provider_kind", m_current.value("provider_kind")},
        {"provider_identity", m_providerIdentity}, {"configuration_valid", m_configurationValid}, {"configuration_saved", m_configurationSaved},
        {"configuration_error", m_configurationError}, {"selection_available", available}, {"provider_available", available},
        {"owner_current", currentOwner}, {"speech", reported}, {"provider_reported", reported},
        {"context", scope()}, {"environment", m_season ? m_season->environment() : QString{}}, {"settings_file", m_file},
        {"enabled_persisted", false}, {"automatic_fallback", false}, {"provider_claims_certify_locality", false}, {"status", m_status}};
}
