#include "TerminalGateway.h"
#include "TerminalGatewayContract.h"
#include "TerminalDataBus.h"
#include "SeasonConfiguration.h"
#include "PluginHost.h"
#include "PluginPackageRuntime.h"
#include "RulesetCatalog.h"
#include "PacketObservation.h"
#include <QCryptographicHash>
#include <QDateTime>
#include <QElapsedTimer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSet>
#include <QLockFile>
#include <QRegularExpression>
#include <QSaveFile>
#include <QScopeGuard>
#include <QUuid>
#include <QThread>
#include <algorithm>
#include <cmath>

namespace {
constexpr int SettingsLimit = 128 * 1024;
const QString LinkRole = QStringLiteral("terminal-link");
const QString LinkContract = QStringLiteral("terminal.link@1");
bool fail(QString *error, const QString &reason) { if (error) *error = reason; return false; }
bool exact(const QVariantMap &map, const QSet<QString> &keys) {
    if (map.size() != keys.size()) return false;
    for (const auto &key : keys) if (!map.contains(key)) return false;
    return true;
}
bool integer(const QVariant &value, int low, int high) {
    const auto type = value.metaType().id();
    if (type != QMetaType::Int && type != QMetaType::UInt && type != QMetaType::LongLong &&
        type != QMetaType::ULongLong && type != QMetaType::Double) return false;
    const auto n = value.toDouble();
    return std::isfinite(n) && std::floor(n) == n && n >= low && n <= high;
}
bool hash(const QVariant &value, bool empty = false) {
    static const QRegularExpression expression(QStringLiteral("\\A[0-9a-f]{64}\\z"));
    return value.metaType().id() == QMetaType::QString &&
        ((empty && value.toString().isEmpty()) || expression.match(value.toString()).hasMatch());
}
bool packageOptions(const QVariantMap &options, bool emptyHashes = false) {
    static const QRegularExpression package(QStringLiteral("\\A[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*\\z"));
    static const QRegularExpression service(QStringLiteral("\\A[a-z][a-z0-9_.-]{0,79}@[1-9][0-9]{0,3}\\z"));
    return exact(options, {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"}) &&
        options.value("package_id").metaType().id() == QMetaType::QString && options.value("package_id").toString().size() <= 64 &&
        package.match(options.value("package_id").toString()).hasMatch() &&
        options.value("service_name").metaType().id() == QMetaType::QString && service.match(options.value("service_name").toString()).hasMatch() &&
        hash(options.value("package_fingerprint"), emptyHashes) && hash(options.value("configuration_fingerprint"), emptyHashes);
}
bool samePackage(const QVariantMap &a, const QVariantMap &b) {
    for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})
        if (a.value(QLatin1String(key)) != b.value(QLatin1String(key))) return false;
    return true;
}
QVariantMap packageLocator(const QVariantMap &identity) {
    QVariantMap result;
    for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})
        result[QLatin1String(key)] = identity.value(QLatin1String(key));
    return result;
}
QVariantMap publicOptions(QVariantMap values) { values.remove("schema"); values.remove("context"); return values; }
QVariantMap settingsScope(const SeasonConfiguration *season) {
    auto result = season ? TerminalGatewayContract::context(season->context()) : QVariantMap{};
    if (!result.isEmpty()) result["environment"] = season->environment();
    return result;
}
bool validScope(const QVariantMap &scope) {
    if (!exact(scope, {"profile_id", "field_profile_id", "capability_revision", "environment"}) ||
        !TerminalGatewayContract::token(scope.value("profile_id"), 128) ||
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
        return fail(error, QStringLiteral("终端链路配置不可读取或为符号链接；原文件保留，未自动连接"));
    const auto bytes = input.read(SettingsLimit + 1); QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(bytes, &parse); const auto root = document.toVariant().toMap();
    if (bytes.size() > SettingsLimit || parse.error != QJsonParseError::NoError || !document.isObject() ||
        !exact(root, {"schema", "profiles"}) || !integer(root.value("schema"), 1, 1) ||
        root.value("profiles").metaType().id() != QMetaType::QVariantList || root.value("profiles").toList().size() > 32)
        return fail(error, QStringLiteral("终端链路配置版本未知、损坏或超过32范围；未启用"));
    QSet<QByteArray> seen;
    for (const auto &entry : root.value("profiles").toList()) {
        const auto record = entry.toMap(), scope = record.value("scope").toMap(), options = record.value("options").toMap();
        if (entry.metaType().id() != QMetaType::QVariantMap || !exact(record, {"scope", "plugin_id", "options"}) ||
            record.value("scope").metaType().id() != QMetaType::QVariantMap || !validScope(scope) ||
            record.value("plugin_id").metaType().id() != QMetaType::QString || record.value("options").metaType().id() != QMetaType::QVariantMap)
            return fail(error, QStringLiteral("终端链路配置含未知字段或无效规则范围；原文件保留"));
        const auto id = record.value("plugin_id").toString();
        QVariantMap normalized;
        if (id == "package" ? !packageOptions(options) :
            (!TerminalGatewayContract::configuration(id, options, TerminalGatewayContract::context(scope), &normalized, error) ||
             publicOptions(normalized) != options))
            return fail(error, QStringLiteral("终端链路配置选项或原生指纹无效；原文件保留"));
        const auto key = QJsonDocument::fromVariant(scope).toJson(QJsonDocument::Compact);
        if (seen.contains(key)) return fail(error, QStringLiteral("终端链路配置范围重复；未启用"));
        seen.insert(key); profiles->append(record);
    }
    return true;
}
QVariantMap builtinOptions(const QString &id) {
    if (id == TerminalGatewayContract::loopbackId()) return {};
    if (id == "terminal.link.mqtt.v1") return {{"host", ""}, {"port", 0}, {"client_id", ""}, {"receive_topics", QVariantList{}}, {"send_topics", QVariantList{}}};
    if (id == "terminal.link.udp.v1") return {{"bind_address", "127.0.0.1"}, {"bind_port", 0}, {"peer_address", ""}, {"peer_port", 0}};
    return {{"options", QVariantMap{}}};
}
bool activeLease(const QVariantMap &details) {
    const auto lease = details.value("provider_active");
    return !details.contains("provider_active") || (lease.metaType().id() == QMetaType::Bool && lease.toBool());
}
bool flag(const QVariant &value, bool expected) { return value.metaType().id() == QMetaType::Bool && value.toBool() == expected; }
QString uuid() { return QUuid::createUuid().toString(QUuid::WithoutBraces); }
QString identity(const QVariantList &parts) {
    // Namespace identity only. A digest is not sender authentication.
    return QString::fromLatin1(QCryptographicHash::hash(
        QJsonDocument(QJsonArray::fromVariantList(parts)).toJson(QJsonDocument::Compact),
        QCryptographicHash::Sha256).toHex());
}
std::shared_ptr<ServiceEndpoint> owned(ServiceEndpoint *raw) {
    const QPointer<ServiceEndpoint> lifetime(raw);
    return std::shared_ptr<ServiceEndpoint>(raw, [lifetime](ServiceEndpoint *) { if (lifetime) delete lifetime.data(); });
}
bool quota(double &tokens, qint64 &last, qint64 now, double rate, double burst) {
    tokens = std::min(burst, tokens + double(qMax<qint64>(0, now - last)) * rate / 1000.0);
    last = now;
    if (tokens < 1.0) return false;
    tokens -= 1.0; return true;
}
}
struct TerminalGateway::Private {
    PluginHost *host = nullptr;
    QString directory, pluginId, status = QStringLiteral("未配置终端链路；官方协议字段映射尚未接入");
    QString file, configurationError;
    QPointer<SeasonConfiguration> season;
    QPointer<TerminalDataBus> bus;
    QPointer<PluginPackageRuntime> packages;
    QVariantMap configuration, scope;
    QVariantMap providerIdentity;
    std::shared_ptr<ServiceEndpoint> endpoint;
    std::shared_ptr<ProtocolEndpoint> binding;
    QString bindingId, activation, receiveSession, mockSession;
    QVariantList journal, catalog;
    QSet<QString> pending;
    quint64 generation = 0;
    qint64 receiveSequence = 0, mockSequence = 0, tx = 0, rx = 0, normalized = 0, rejected = 0, dropped = 0;
    qint64 txBytes = 0, rxBytes = 0, txAt = 0, rxAt = 0;
    QElapsedTimer clock;
    double txTokens = 8, rxTokens = 64;
    bool changing = false, destroying = false, configurationSaved = false, configurationValid = true;
};
TerminalGateway::TerminalGateway(PluginHost *host, QString directory, SeasonConfiguration *season,
                                TerminalDataBus *bus, QObject *parent)
    : TerminalGateway(host, std::move(directory), season, bus, QString{}, parent) {}
TerminalGateway::TerminalGateway(PluginHost *host, QString directory, SeasonConfiguration *season,
                                TerminalDataBus *bus, QString file, QObject *parent)
    : QObject(parent), d(std::make_unique<Private>()) {
    d->host = host; d->directory = std::move(directory); d->season = season; d->bus = bus;
    d->file = std::move(file);
    d->catalog = PluginHost::discover(d->directory);
    d->clock.start();
    if (season) {
        connect(season, &SeasonConfiguration::aboutToChange, this, [this] {
            QPointer<TerminalGateway> alive(this);
            retire(true);
            if (!alive) return;
            d->configuration.clear(); d->scope.clear(); d->pluginId.clear(); d->configurationSaved = false;
            d->status = QStringLiteral("规则范围已退役；链路已停，需重新配置并显式启用");
            emit changed();
        });
        connect(season, &QObject::destroyed, this, [this] { stop(); });
        connect(season, &SeasonConfiguration::stateChanged, this, &TerminalGateway::changed);
        connect(season, &SeasonConfiguration::contextChanged, this, [this] { loadConfiguration(); emit changed(); });
    }
    if (bus) connect(bus, &QObject::destroyed, this, &TerminalGateway::stop);
    loadConfiguration();
}
TerminalGateway::~TerminalGateway() {
    d->destroying = true;
    if (d->season) disconnect(d->season, nullptr, this, nullptr);
    if (d->packages) disconnect(d->packages, nullptr, this, nullptr);
    retire(false);
}
QVariantMap TerminalGateway::configuration() const {
    return {{"plugin_id", d->pluginId}, {"options", d->pluginId == "package" ? d->configuration : publicOptions(d->configuration)},
            {"binding_id", d->bindingId}, {"binding_classification", "project_local_unverified"},
            {"configuration_saved", d->configurationSaved}};
}
QString TerminalGateway::status() const { return d->status; }
bool TerminalGateway::active() const { return bool(d->endpoint) && !d->changing; }
QObject *TerminalGateway::terminalBus() const { return d->bus; }
QVariantList TerminalGateway::receivedPackets() const { return d->journal; }
QVariantList TerminalGateway::modules() const {
    QVariantList result;
    QMap<QString, int> counts;
    for (const auto &entry : d->catalog) {
        const auto metadata = entry.toMap();
        if (metadata.value("role") == LinkRole && metadata.value("contract") == QLatin1String(ExtensionPlugin_iid)) ++counts[metadata.value("id").toString()];
    }
    QSet<QString> seen;
    for (const auto &entry : d->catalog) {
        const auto metadata = entry.toMap();
        const auto id = metadata.value("id").toString();
        if (metadata.value("role") != LinkRole || metadata.value("contract") != QLatin1String(ExtensionPlugin_iid) ||
            !counts.contains(id) || seen.contains(id) || id == "package") continue;
        seen.insert(id);
        result.append(QVariantMap{{"id", id}, {"role", LinkRole}, {"provider_kind", "builtin"},
            {"options", id == d->pluginId ? publicOptions(d->configuration) : builtinOptions(id)},
            {"available", counts.value(id) == 1}, {"title", metadata.value("name", id)},
            {"version", metadata.value("version")}, {"description", metadata.value("description").toString().left(512)},
            {"selected", id == d->pluginId}});
    }
    if (d->packages) for (const auto &entry : d->packages->serviceProviders(LinkRole, LinkContract)) {
        const auto provider = entry.toMap();
        result.append(QVariantMap{{"id", "package"}, {"role", LinkRole}, {"provider_kind", "package"},
            {"options", packageLocator(provider)}, {"title", provider.value("title").toString() + " · " +
                provider.value("package_id").toString() + " / " + provider.value("service_name").toString()},
            {"available", true}, {"selected", d->pluginId == "package" && samePackage(provider, d->configuration)}});
    }
    if (d->configurationSaved && ((d->pluginId == "package" && selectedPackage().isEmpty()) ||
        (d->pluginId != "package" && !seen.contains(d->pluginId))))
        result.append(QVariantMap{{"id", d->pluginId}, {"role", LinkRole}, {"provider_kind", d->pluginId == "package" ? "package" : "builtin"},
            {"options", d->pluginId == "package" ? d->configuration : publicOptions(d->configuration)},
            {"title", (d->pluginId == "package" ? d->configuration.value("package_id").toString() + " / " +
                d->configuration.value("service_name").toString() : d->pluginId) + QStringLiteral(" · 已保存，当前缺失或内容已变化")},
            {"available", false}, {"retained", true}, {"selected", true}});
    return result;
}
void TerminalGateway::refreshModules() {
    if (QThread::currentThread() != thread()) return;
    d->catalog = PluginHost::discover(d->directory);
    synchronizeProviders();
}
QVariantMap TerminalGateway::details() const {
    const auto endpoint = d->endpoint;
    const auto generation = d->generation;
    QPointer<const TerminalGateway> alive(this);
    const auto service = endpoint ? endpoint->details() : QVariantMap{};
    if (!alive || generation != d->generation) return {};
    bool available = false;
    if (d->pluginId == "package") available = !selectedPackage().isEmpty();
    else for (const auto &entry : modules()) if (entry.toMap().value("id") == d->pluginId && entry.toMap().value("available") == QVariant(true)) available = true;
    QVariantMap result{{"active", bool(endpoint) && !d->changing}, {"connected", service.value("connected").metaType().id() == QMetaType::Bool && service.value("connected").toBool()},
        {"plugin_id", d->pluginId}, {"binding_id", d->bindingId}, {"context", d->scope},
        {"provider_identity", d->providerIdentity}, {"provider_available", available}, {"configuration_saved", d->configurationSaved},
        {"configuration_valid", d->configurationValid}, {"configuration_error", d->configurationError}, {"settings_file", d->file},
        {"environment", d->season ? d->season->environment() : QString{}}, {"enabled_persisted", false}, {"automatic_fallback", false},
        {"activation_id", d->activation}, {"sent_packets", d->tx}, {"received_packets", d->rx},
        {"sent_bytes", d->txBytes}, {"received_bytes", d->rxBytes}, {"normalized_packets", d->normalized},
        {"normalization_rejected", d->rejected}, {"quota_dropped", d->dropped},
        {"pending_submissions", d->pending.size()}, {"authoritative", false}, {"execution_confirmed", false},
        {"official_protocol_bound", false}, {"peer_authenticated", false}, {"ai_input_ready", false},
        {"classification", "unclassified_raw_transport"}, {"journal_limit", 16}};
    if (service.value("kind").metaType().id() == QMetaType::QString)
        result["transport_kind"] = service.value("kind").toString().left(32);
    for (const auto &key : {"transport_kind", "bind_port", "queued_messages", "queued_bytes", "health"})
        if (service.contains(key) && (service.value(key).metaType().id() == QMetaType::QString ||
            service.value(key).metaType().id() == QMetaType::Int || service.value(key).metaType().id() == QMetaType::LongLong))
            result[key] = service.value(key).metaType().id() == QMetaType::QString ? service.value(key).toString().left(128) : service.value(key);
    for (const auto &key : {"state", "peer", "last_error", "pending_messages", "pending_bytes",
                           "last_dispatch_queue_age_ms", "maximum_dispatch_queue_age_ms", "queue_limit_scope"}) {
        const auto value = service.value(key);
        if (value.metaType().id() == QMetaType::QString) result[key] = value.toString().left(512);
        else if (value.metaType().id() == QMetaType::Int || value.metaType().id() == QMetaType::LongLong)
            result[key] = value;
    }
    return result;
}
QString TerminalGateway::guardReason() const {
    if (d->destroying || !d->season || !d->bus) return QStringLiteral("终端链路宿主不可用");
    if (d->changing) return QStringLiteral("正在切换终端链路");
    if (d->season->context().value("configuration_valid") != QVariant(true)) return QStringLiteral("正式规则范围无效；链路未启动");
    if (d->season->profileId() != "rmuc2027-regional-v1.0.0") return QStringLiteral("终端链路仅在当前2027正式规则范围配置");
    if (d->season->environment() != "training") return QStringLiteral("未分类原始链路仅供本地训练；比赛需明确官方映射与身份配置");
    if (!d->season->editable()) return d->season->lockReason();
    return {};
}
bool TerminalGateway::reject(const QString &reason, QString *error) {
    if (error) *error = reason;
    d->status = reason;
    emit changed();
    return false;
}
void TerminalGateway::loadConfiguration() {
    d->pluginId.clear(); d->configuration.clear(); d->scope.clear(); d->configurationSaved = false;
    d->configurationValid = true; d->configurationError.clear();
    QVariantList profiles;
    if (!readSettings(d->file, &profiles, &d->configurationError)) {
        d->configurationValid = false; d->status = d->configurationError; return;
    }
    for (const auto &entry : profiles) {
        const auto record = entry.toMap();
        if (record.value("scope").toMap() != settingsScope(d->season)) continue;
        d->pluginId = record.value("plugin_id").toString();
        d->scope = TerminalGatewayContract::context(record.value("scope").toMap());
        if (d->pluginId == "package") d->configuration = record.value("options").toMap();
        else TerminalGatewayContract::configuration(d->pluginId, record.value("options").toMap(), d->scope, &d->configuration);
        d->configurationSaved = true; break;
    }
    d->status = d->configurationSaved ? QStringLiteral("已载入当前规则范围的终端链路选择；没有自动启用或连接") :
        QStringLiteral("当前规则范围尚未保存终端链路；先配置，再明确启用");
}
bool TerminalGateway::saveConfiguration(const QString &pluginId, const QVariantMap &options) {
    if (d->file.isEmpty()) return true; // Backward-compatible native in-memory composition.
    if (QFileInfo(d->file).isSymLink() || !QDir().mkpath(QFileInfo(d->file).absolutePath()))
        return reject(QStringLiteral("终端链路配置目录不可写或目标为符号链接；原配置保留"));
    QLockFile lock(d->file + ".lock");
    if (!lock.tryLock(0)) return reject(QStringLiteral("另一实例正在保存此终端链路配置"));
    QVariantList profiles; QString error;
    // Explicit configure/save is the only recovery operation for a malformed
    // file. Startup, enable and scope changes never rewrite it.
    if (!readSettings(d->file, &profiles, &error)) profiles.clear();
    const auto scope = settingsScope(d->season);
    const QVariantMap record{{"scope", scope}, {"plugin_id", pluginId}, {"options", options}};
    bool replaced = false;
    for (auto &entry : profiles) if (entry.toMap().value("scope").toMap() == scope) { entry = record; replaced = true; break; }
    if (!replaced) {
        if (profiles.size() >= 32) return reject(QStringLiteral("终端链路规则范围超过32项；未删除其他配置"));
        profiles.append(record);
    }
    const auto bytes = QJsonDocument::fromVariant(QVariantMap{{"schema", 1}, {"profiles", profiles}}).toJson(QJsonDocument::Compact);
    if (bytes.size() > SettingsLimit) return reject(QStringLiteral("终端链路配置超过128KiB；未截断保存"));
    QSaveFile output(d->file);
    if (!output.open(QIODevice::WriteOnly) || !output.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner) ||
        output.write(bytes) != bytes.size() || !output.commit()) return reject(QStringLiteral("终端链路配置原子提交失败；原配置保留"));
    return true;
}
QVariantMap TerminalGateway::selectedPackage(bool fingerprints) const {
    if (!d->packages || d->pluginId != "package") return {};
    for (const auto &entry : d->packages->serviceProviders(LinkRole, LinkContract)) {
        const auto row = entry.toMap();
        if (row.value("package_id") == d->configuration.value("package_id") && row.value("service_name") == d->configuration.value("service_name") &&
            (!fingerprints || samePackage(row, d->configuration))) return row;
    }
    return {};
}
void TerminalGateway::synchronizeProviders() {
    if (d->destroying) return;
    if (d->pluginId == "package" && d->endpoint && selectedPackage().isEmpty()) {
        QPointer<TerminalGateway> alive(this); const auto generation = d->generation + 1;
        retire(true);
        if (!alive || generation != d->generation) return;
        d->status = QStringLiteral("插件终端链路已退役；对应总线来源已撤回，没有自动回退或恢复");
    }
    emit changed();
}
void TerminalGateway::setPackageRuntime(PluginPackageRuntime *runtime) {
    if (QThread::currentThread() != thread() || d->packages == runtime) return;
    QPointer<TerminalGateway> alive(this); const auto generation = d->generation + (d->pluginId == "package" ? 1 : 0);
    if (d->pluginId == "package") retire(true);
    if (!alive || generation != d->generation) return;
    if (d->packages) disconnect(d->packages, nullptr, this, nullptr);
    d->packages = runtime;
    if (runtime) {
        connect(runtime, &PluginPackageRuntime::changed, this, &TerminalGateway::synchronizeProviders);
        connect(runtime, &QObject::destroyed, this, [this] {
            if (d->pluginId == "package") {
                QPointer<TerminalGateway> alive(this); const auto generation = d->generation + 1;
                retire(true);
                if (!alive || generation != d->generation) return;
                d->status = QStringLiteral("插件注册表已销毁；链路与对应总线来源已退役");
            }
            emit changed();
        });
    }
    emit changed();
}
void TerminalGateway::retire(bool clearJournal) {
    ++d->generation;
    auto endpoint = std::move(d->endpoint);
    const auto activation = d->activation;
    d->activation.clear(); d->receiveSession.clear(); d->receiveSequence = 0; d->pending.clear(); d->providerIdentity.clear();
    d->mockSession.clear(); d->mockSequence = 0; d->changing = false;
    if (clearJournal) {
        d->journal.clear();
        d->tx = d->rx = d->txBytes = d->rxBytes = d->normalized = d->rejected = d->dropped = 0;
    }
    QPointer<TerminalGateway> alive(this);
    const QPointer<TerminalDataBus> bus = d->bus;
    const QPointer<ServiceEndpoint> endpointGuard(endpoint.get());
    if (endpointGuard) disconnect(endpointGuard, nullptr, this, nullptr);
    if (bus && !activation.isEmpty()) bus->retireTransport(activation);
    // Retract matching observations before stopping the endpoint/package. A
    // stop callback must never see a still-active source from this activation.
    if (endpointGuard) endpointGuard->stop();
    if (!alive) return;
}
void TerminalGateway::stop() {
    if (QThread::currentThread() != thread()) {
        QMetaObject::invokeMethod(this, &TerminalGateway::stop, Qt::QueuedConnection);
        return;
    }
    QPointer<TerminalGateway> alive(this);
    const auto retirement = d->generation + 1;
    retire(true);
    if (!alive || retirement != d->generation) return;
    d->status = QStringLiteral("本链路已停；本机来源及其他独立链路继续运行");
    emit changed();
}
bool TerminalGateway::configure(const QString &pluginId, const QVariantMap &publicConfiguration) {
    if (QThread::currentThread() != thread()) return false;
    const auto reason = guardReason();
    if (!reason.isEmpty()) return reject(reason);
    const auto scope = TerminalGatewayContract::context(d->season->context());
    QVariantMap normalized;
    QString error;
    if (pluginId == "package") {
        if (!packageOptions(publicConfiguration, true)) return reject(QStringLiteral("插件链路配置仅接受明确包／服务及两个原生内容／配置指纹"));
        normalized = publicConfiguration;
        QVariantMap selected;
        if (d->packages) for (const auto &entry : d->packages->serviceProviders(LinkRole, LinkContract)) {
            const auto row = entry.toMap();
            if (row.value("package_id") == normalized.value("package_id") && row.value("service_name") == normalized.value("service_name")) { selected = row; break; }
        }
        if (!selected.isEmpty()) {
            for (const auto &key : {"package_fingerprint", "configuration_fingerprint"}) {
                const auto name = QLatin1String(key);
                if (!normalized.value(name).toString().isEmpty() && normalized.value(name) != selected.value(name))
                    return reject(QStringLiteral("插件链路内容／配置已变化；先查看刷新后的来源，再明确选择保存"));
                normalized[name] = selected.value(name);
            }
        } else if (d->pluginId != "package" || !d->configurationSaved || !samePackage(normalized, d->configuration))
            return reject(QStringLiteral("新选插件链路未运行；可保留原已保存的缺失来源，但不能替换成未知来源"));
    } else if (!TerminalGatewayContract::configuration(pluginId, publicConfiguration, scope, &normalized, &error)) return reject(error);
    if (!saveConfiguration(pluginId, pluginId == "package" ? normalized : publicOptions(normalized))) return false;
    QPointer<TerminalGateway> alive(this);
    const auto retirement = d->generation + 1;
    retire(true);
    if (!alive || retirement != d->generation) return false;
    d->pluginId = pluginId; d->configuration = normalized; d->scope = scope;
    d->configurationSaved = true; d->configurationValid = true; d->configurationError.clear();
    d->catalog = PluginHost::discover(d->directory);
    d->status = QStringLiteral("已配置 %1；尚未启用，没有自动连接").arg(pluginId);
    emit changed();
    return true;
}
bool TerminalGateway::setEnabled(bool enabled) {
    if (QThread::currentThread() != thread()) return false;
    if (!enabled) { stop(); return true; }
    const auto reason = guardReason();
    if (!reason.isEmpty()) return reject(reason);
    if (!d->configurationValid || !d->configurationSaved || d->pluginId.isEmpty() || d->configuration.isEmpty() ||
        d->scope != TerminalGatewayContract::context(d->season->context()))
        return reject(QStringLiteral("先配置与当前规则一致的终端链路"));
    if (d->endpoint) return true;
    QVariantMap selected;
    if (d->pluginId == "package") selected = selectedPackage();
    else for (const auto &entry : modules()) {
        const auto row = entry.toMap();
        if (row.value("id") == d->pluginId && row.value("available") == QVariant(true)) selected = row;
    }
    if (selected.isEmpty()) return reject(QStringLiteral("已保存的链路提供者缺失、重复或内容／配置已改变；未自动回退"));
    d->changing = true;
    const auto generation = ++d->generation;
    const auto config = d->configuration;
    const auto plugin = d->pluginId;
    QPointer<TerminalGateway> alive(this);
    const auto transition = qScopeGuard([this, alive, generation] {
        if (alive && generation == d->generation && d->changing) { d->changing = false; emit changed(); }
    });
    const auto current = [this, alive, generation] { return alive && generation == d->generation; };
    QString error;
    ServiceEndpoint *created = nullptr; QVariantMap provider;
    if (plugin == "package") {
        if (d->packages) created = d->packages->createProviderService(config.value("package_id").toString(),
            config.value("service_name").toString(), LinkRole, LinkContract, &error, &provider);
    } else {
        auto *factory = d->host ? d->host->loadExtension(d->directory, plugin, LinkRole, &error) : nullptr;
        if (current() && factory) {
            try { created = factory->createService(); }
            catch (...) { error = QStringLiteral("终端链路工厂创建发生原生异常；其他客户端功能继续"); }
        }
        provider = selected;
    }
    QPointer<ServiceEndpoint> candidate(created);
    auto dispose = qScopeGuard([candidate] {
        if (!candidate || candidate->parent()) return;
        if (candidate->thread() != QThread::currentThread()) { candidate->deleteLater(); return; }
        candidate->stop(); if (candidate) delete candidate.data();
    });
    if (!current()) return false;
    if (!candidate) return reject(error.isEmpty() ? QStringLiteral("可选终端插件不可用；其他功能继续") : error);
    if (candidate->parent() || candidate->thread() != thread())
        return reject(QStringLiteral("终端链路工厂须转交新的、无父对象且位于界面线程的静止端点"));
    const auto quiet = candidate->details();
    if (!current() || !candidate) return false;
    if (!flag(quiet.value("active"), false) || !activeLease(quiet) ||
        (quiet.contains("busy") && !flag(quiet.value("busy"), false)))
        return reject(QStringLiteral("终端链路工厂返回了已活动／失效端点；未启动"));
    if (plugin == "package" && (provider != selectedPackage() || !samePackage(provider, config)))
        return reject(QStringLiteral("创建期间终端链路提供者身份已变化；未保留旧租约"));
    auto endpoint = owned(candidate.data()); dispose.dismiss();
    d->activation = uuid(); d->mockSession = uuid(); d->mockSequence = 0; d->endpoint = endpoint;
    d->providerIdentity = provider;
    d->txTokens = 8; d->rxTokens = 64; d->txAt = d->rxAt = d->clock.elapsed();
    d->tx = d->rx = d->txBytes = d->rxBytes = d->normalized = d->rejected = d->dropped = 0;
    const auto startupMessage = std::make_shared<bool>(false);
    connect(endpoint.get(), &ServiceEndpoint::messageReceived, this, [this, generation, startupMessage](const QVariantMap &message) {
        if (generation != d->generation) return;
        if (d->changing) { *startupMessage = true; return; }
        receive(generation, message);
    });
    connect(endpoint.get(), &QObject::destroyed, this, [this, generation] {
        if (generation != d->generation) return;
        // Its guarded shared deleter knows this QObject has already died.
        d->endpoint.reset();
        QPointer<TerminalGateway> alive(this); const auto retirement = d->generation + 1;
        retire(true);
        if (!alive || retirement != d->generation) return;
        reject(QStringLiteral("终端链路端点已销毁；对应总线来源已撤回，没有自动替换"));
    });
    connect(endpoint.get(), &ServiceEndpoint::statusChanged, this, [this, generation] {
        if (generation != d->generation || !d->endpoint) return;
        const auto endpoint = d->endpoint; const QPointer<ServiceEndpoint> guard(endpoint.get());
        QPointer<TerminalGateway> alive(this);
        const auto details = endpoint->details();
        if (!alive || !guard || generation != d->generation) return;
        if (!activeLease(details) || (!d->changing && !flag(details.value("active"), true))) {
            const auto retirement = d->generation + 1; retire(true);
            if (!alive || retirement != d->generation) return;
            reject(QStringLiteral("终端链路租约或端点已失效；对应总线来源已撤回，须明确重新启用"));
        } else emit changed();
    });
    connect(endpoint.get(), &ServiceEndpoint::errorOccurred, this, [this, generation](const QString &message) {
        if (generation != d->generation) return;
        d->status = message.left(512); emit changed();
    });
    const bool started = endpoint->start(plugin == "package" ? QVariantMap{{"schema", 1}, {"context", d->scope}} : config, &error);
    if (!current() || !candidate) return false;
    const auto running = endpoint->details();
    if (!current() || !candidate) return false;
    if (!started || !flag(running.value("active"), true) || !activeLease(running) || *startupMessage ||
        (plugin == "package" && provider != selectedPackage())) {
        const auto retirement = d->generation + 1;
        retire(true);
        if (!alive || retirement != d->generation) return false;
        return reject(error.isEmpty() ? QStringLiteral("终端链路未静止启用或租约已变化；本机功能继续") : error);
    }
    d->changing = false;
    d->status = QStringLiteral("链路已启动；连接状态及实际收发按插件报告，未分类数据不等于官方遥测");
    emit changed();
    return current();
}
bool TerminalGateway::setProtocolBinding(std::unique_ptr<ProtocolEndpoint> binding,
                                        const QString &bindingId, QString *error) {
    if (QThread::currentThread() != thread()) { if (error) *error = "Protocol binding must be replaced on its owner thread"; return false; }
    const auto reason = guardReason();
    if (!reason.isEmpty()) return reject(reason, error);
    if (binding && !TerminalGatewayContract::token(bindingId)) return reject(QStringLiteral("协议绑定ID无效"), error);
    QPointer<TerminalGateway> alive(this);
    const auto retirement = d->generation + 1;
    retire(true);
    if (!alive || retirement != d->generation) return false;
    d->binding = std::shared_ptr<ProtocolEndpoint>(std::move(binding));
    d->bindingId = d->binding ? bindingId : QString{};
    d->status = QStringLiteral("已更换本项目数据映射；链路保持停用，未授予官方权威");
    emit changed();
    return true;
}
bool TerminalGateway::sendBytes(const QString &channel, const QByteArray &payload,
                                const QString &requestId, QString *error) {
    if (error) error->clear();
    if (QThread::currentThread() != thread()) { if (error) *error = "Raw submission must run on its owner thread"; return false; }
    const auto guard = guardReason();
    if (!guard.isEmpty()) return reject(guard, error);
    if (!d->season || d->season->environment() != "training" || d->scope != TerminalGatewayContract::context(d->season->context()))
        return reject(QStringLiteral("当前环境不允许未分类原始发送"), error);
    if (!d->endpoint || d->changing || payload.size() > TerminalGatewayContract::MaximumPayloadBytes ||
        !TerminalGatewayContract::token(requestId) || channel.isEmpty() || channel.size() > 256 || channel.contains(QChar::Null))
        return reject(QStringLiteral("链路未就绪或原始发送字段／64KiB界限不合格"), error);
    if (d->pending.contains(requestId) || d->pending.size() >= 32 ||
        !quota(d->txTokens, d->txAt, d->clock.elapsed(), 20, 8))
        return reject(QStringLiteral("发送请求重复、队列已满或超过速率配额"), error);
    d->pending.insert(requestId);
    const auto endpoint = d->endpoint;
    const auto generation = d->generation;
    QPointer<TerminalGateway> alive(this);
    QString reason;
    const bool accepted = endpoint->submit(TerminalGatewayContract::wireSend(channel, payload, requestId), &reason);
    if (!alive || generation != d->generation) { if (error) *error = "Gateway scope changed during submission"; return false; }
    d->pending.remove(requestId);
    if (!accepted) return reject(reason.isEmpty() ? QStringLiteral("插件拒绝原始发送") : reason, error);
    ++d->tx; d->txBytes += payload.size();
    d->status = QStringLiteral("已提交原始字节；本地接纳不证明网络送达或机器人执行");
    emit changed();
    return true;
}
bool TerminalGateway::sendObservation(const QVariantMap &observation, const QString &requestId, QString *error) {
    if (QThread::currentThread() != thread()) { if (error) *error = "Observation submission must run on its owner thread"; return false; }
    const auto reason = guardReason(); if (!reason.isEmpty()) return reject(reason, error);
    const bool allowMock = d->pluginId == TerminalGatewayContract::loopbackId();
    QByteArray payload;
    if (!TerminalGatewayContract::encodeObservation(observation, d->scope, allowMock, &payload, error)) return false;
    QString channel = d->pluginId == TerminalGatewayContract::loopbackId() ? "local" :
        d->pluginId == "terminal.link.udp.v1" ? "peer" : d->configuration.value("send_topics").toList().value(0).toString();
    const auto binding = d->binding;
    const auto generation = d->generation;
    QPointer<TerminalGateway> alive(this);
    if (d->pluginId == "package" && !binding)
        return reject(QStringLiteral("插件链路发送观察须有原生协议绑定明确指定通道；不猜测已审核允许的通道"), error);
    if (binding) {
        QString boundChannel;
        const bool encoded = binding->encode("terminal-observation", observation, &boundChannel, &payload, error);
        if (!alive || generation != d->generation) return false;
        if (!encoded) return false;
        if (d->pluginId == "package" && boundChannel.isEmpty())
            return reject(QStringLiteral("插件链路协议绑定未指定明确发送通道；未发送"), error);
        if (!boundChannel.isEmpty()) channel = boundChannel;
    }
    if (!alive || generation != d->generation) return false;
    return sendBytes(channel, payload, requestId, error);
}
bool TerminalGateway::sendTrainingHex(const QString &channel, const QString &hex, bool confirmed) {
    if (QThread::currentThread() != thread()) return false;
    const auto reason = guardReason();
    if (!reason.isEmpty()) return reject(reason);
    if (!confirmed) return reject(QStringLiteral("先明确确认向配置的训练对端提交原始字节"));
    if (hex.isEmpty() || hex.size() > TerminalGatewayContract::MaximumPayloadBytes * 3)
        return reject(QStringLiteral("十六进制内容为空或超过64KiB界限"));
    QByteArray compactHex;
    compactHex.reserve(std::min<qsizetype>(hex.size(), TerminalGatewayContract::MaximumPayloadBytes * 2));
    for (const auto character : hex) {
        if (character == QLatin1Char(' ') || character == QLatin1Char('\n') || character == QLatin1Char('\r') || character == QLatin1Char('\t')) continue;
        const auto value = character.unicode();
        if (!((value >= '0' && value <= '9') || (value >= 'a' && value <= 'f') || (value >= 'A' && value <= 'F')))
            return reject(QStringLiteral("原始发送仅接受成对十六进制字节，可用空格或换行分隔"));
        compactHex.append(char(value));
        if (compactHex.size() > TerminalGatewayContract::MaximumPayloadBytes * 2)
            return reject(QStringLiteral("原始发送超过64KiB界限"));
    }
    if (compactHex.isEmpty() || compactHex.size() % 2)
        return reject(QStringLiteral("十六进制字节必须完整成对"));
    QString error;
    return sendBytes(channel, QByteArray::fromHex(compactHex), uuid(), &error);
}
bool TerminalGateway::sendMock() {
    if (QThread::currentThread() != thread()) return false;
    const auto reason = guardReason();
    if (!reason.isEmpty()) return reject(reason);
    if (d->pluginId != TerminalGatewayContract::loopbackId() || !d->endpoint)
        return reject(QStringLiteral("明确启用本机回环插件后，才能执行模拟字节收发"));
    const auto session = d->mockSession;
    const auto sample = [&](const QString &item, const QString &type, const QVariant &value) {
        return QVariantMap{{"schema", 3}, {"context", d->scope}, {"team_id", "local-loopback-demo"},
            {"robot_key", "red/heavy/1"}, {"source_id", "mock.terminal.loopback"}, {"sensor_id", item},
            {"source_kind", "mock"}, {"session_id", session}, {"sequence", ++d->mockSequence}, {"item_id", item},
            {"produced_at_ms", QDateTime::currentMSecsSinceEpoch()}, {"clock_domain", "host_utc"}, {"ttl_ms", 30000},
            {"confidence", QVariant{}}, {"validation", "mock"}, {"lifecycle", "active"}, {"data_type", type}, {"value", value}};
    };
    const QVariantList samples{sample("heavy-lock-sensor", "boolean", false),
        sample("vision-unverified-event", "event", QVariantMap{{"summary", "回环模拟视觉发现；未经标定，仅文字"}, {"x", 17.2}, {"y", 6.4}}),
        sample("derived-logistics-reference", "object", QVariantMap{{"summary", "回环模拟：手动假设基地5000HP，非比赛值"}, {"lambda", 0.75}})};
    QPointer<TerminalGateway> alive(this);
    const auto generation = d->generation;
    for (const auto &value : samples) {
        auto observation = value.toMap();
        if (observation.value("data_type") == "event") {
            observation["frame_id"] = "rm2027.field"; observation["frame_revision"] = "mock-unverified";
            observation["transform_id"] = "unverified"; observation["unit"] = "m";
        }
        QString error;
        if (!sendObservation(observation, uuid(), &error)) return false;
        if (!alive || generation != d->generation) return false;
    }
    return true;
}
void TerminalGateway::receive(quint64 generation, const QVariantMap &message) {
    if (generation != d->generation || !d->endpoint) return;
    if (message.value("kind") == "wire-submit-result") {
        if (message.value("schema") != 1 || message.value("accepted").metaType().id() != QMetaType::Bool ||
            message.value("delivery") != "local_submission" || message.value("execution_confirmed") != QVariant(false)) return;
        const auto id = message.value("request_id").toString();
        if (d->pending.contains(id)) {
            d->pending.remove(id);
            d->status = message.value("accepted").toBool() ? QStringLiteral("插件确认本地提交；非远端执行确认") : QStringLiteral("插件拒绝本地提交");
            emit changed();
        }
        return;
    }
    QVariantMap packet;
    QString error;
    if (!TerminalGatewayContract::wireReceived(message, d->scope, &packet, &error)) { ++d->dropped; reject(error); return; }
    if (!quota(d->rxTokens, d->rxAt, d->clock.elapsed(), 100, 64)) { ++d->dropped; reject(QStringLiteral("接收配额已满，已显式丢弃原始包")); return; }
    const auto sequence = packet.value("sequence").toLongLong();
    const auto session = packet.value("session_id").toString();
    qint64 queueAge = 0;
    const PacketObservation::Stamp stamp{"host_dispatch", session, sequence,
        packet.value("received_at_ms").toLongLong(), packet.value("received_tick_ms").toLongLong()};
    if (!PacketObservation::validateAt(stamp, QDateTime::currentMSecsSinceEpoch(),
                                     PacketObservation::steadyMilliseconds(), &queueAge, &error)) {
        ++d->dropped; reject(error); return;
    }
    if ((!d->receiveSession.isEmpty() && session != d->receiveSession) || sequence <= d->receiveSequence) {
        ++d->dropped; reject(QStringLiteral("旧链路会话／重复包已丢弃")); return;
    }
    d->receiveSession = session; d->receiveSequence = sequence;
    const auto bytes = packet.value("payload").toByteArray();
    ++d->rx; d->rxBytes += bytes.size();
    const auto packetId = uuid();
    QVariantMap record{{"packet_id", packetId}, {"received_at_ms", packet.value("received_at_ms")},
        {"channel", packet.value("channel")}, {"peer", packet.value("peer")}, {"transport_kind", packet.value("transport_kind")},
        {"bytes", bytes.size()}, {"preview_hex", QString::fromLatin1(bytes.left(1024).toHex())},
        {"preview_truncated", bytes.size() > 1024}, {"authoritative", false}, {"normalized", false}};
    QVariantMap observation;
    const bool mockLoop = d->pluginId == TerminalGatewayContract::loopbackId() && packet.value("transport_kind") == "loopback";
    const auto binding = d->binding;
    QPointer<TerminalGateway> alive(this);
    bool decoded = false;
    if (binding) {
        QString type; QVariantMap fields;
        decoded = binding->decode(packet.value("channel").toString(), bytes, &type, &fields, &error) &&
                  type == "terminal-observation" && fields.value("observation").metaType().id() == QMetaType::QVariantMap;
        if (decoded) observation = fields.value("observation").toMap();
    } else decoded = TerminalGatewayContract::decodeObservation(bytes, d->scope, mockLoop, &observation, &error);
    if (!alive || generation != d->generation) return;
    if (decoded && d->bus) {
        const auto original = observation;
        const bool mock = mockLoop && observation.value("source_kind") == "mock";
        if (!mock) {
            observation["clock_domain"] = "remote_unverified";
            observation["validation"] = observation.value("source_kind") == "derived" ? "derived" : "unverified";
        }
        QByteArray checked;
        if (!TerminalGatewayContract::encodeObservation(observation, d->scope, mock, &checked, &error))
            decoded = false;
        if (!decoded) {
            ++d->rejected;
            record["normalization_status"] = error.left(512);
            d->journal.append(record);
            while (d->journal.size() > 16) d->journal.removeFirst();
            d->status = QStringLiteral("已收到原始字节；本包映射拒绝，未改变官方遥测");
            emit changed();
            return;
        }
        observation["source_id"] = (mock ? "mock.gateway." : "gateway.") + identity({d->activation, packet.value("channel"), packet.value("peer"),
            original.value("team_id"), original.value("robot_key"), original.value("source_id")});
        observation["session_id"] = "gateway." + identity({d->activation, original.value("session_id")});
        QVariantMap provenance{{"activation_id", d->activation}, {"packet_id", packetId}, {"plugin_id", d->pluginId},
            {"binding_id", d->bindingId}, {"channel", packet.value("channel")}, {"peer", packet.value("peer")},
            {"peer_authenticated", false}, {"original_team_id", original.value("team_id")},
            {"original_robot_key", original.value("robot_key")}, {"original_source_id", original.value("source_id")},
            {"original_session_id", original.value("session_id")}, {"original_clock_domain", original.value("clock_domain")},
            {"queue_age_ms", queueAge},
            {"packet_received_at_ms", packet.value("received_at_ms")}, {"packet_received_tick_ms", packet.value("received_tick_ms")}};
        // Runtime identity is transport provenance only. It never upgrades an
        // original sensor claim to official telemetry or authenticated data.
        if (d->pluginId == "package") provenance["provider_identity"] = d->providerIdentity;
        decoded = d->bus->acceptTransportObservation(observation, provenance, mock, &error);
        if (!alive || generation != d->generation) return;
    } else decoded = false;
    if (decoded) ++d->normalized; else ++d->rejected;
    record["normalized"] = decoded;
    record["normalization_status"] = decoded ? QStringLiteral("项目本地观察已接纳；非官方权威") : error.isEmpty() ? QStringLiteral("原始包已收到；没有匹配的数据映射") : error.left(512);
    d->journal.append(record);
    while (d->journal.size() > 16) d->journal.removeFirst();
    d->status = decoded ? QStringLiteral("已实际收到字节并归一化；来源／mock与时效仍明确标记") : QStringLiteral("已实际收到原始字节；本包未生成有效观察");
    emit changed();
}
