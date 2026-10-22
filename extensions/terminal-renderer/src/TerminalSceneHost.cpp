#include "TerminalSceneHost.h"
#include "TerminalDataBus.h"
#include "SeasonConfiguration.h"
#include "PluginHost.h"
#include "PacketObservation.h"
#include "TerminalRendererContract.h"
#include "PluginPackageRuntime.h"
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonObject>
#include <QJsonDocument>
#include <QLockFile>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QUuid>
#include <cmath>

namespace {
const QString RendererRole = QStringLiteral("terminal-renderer");
const QString RendererContract = QStringLiteral("terminal.renderer@1");
QVariantMap builtinProvider() {
    return {{"kind", "builtin"}, {"plugin_id", "renderer.terminal.2d.v1"}, {"package_id", ""},
        {"service_name", ""}, {"package_fingerprint", ""}, {"configuration_fingerprint", ""}};
}
bool exactKeys(const QVariantMap &value, const QSet<QString> &keys) {
    if (value.size() != keys.size()) return false;
    for (const auto &key : keys) if (!value.contains(key)) return false;
    return true;
}
bool token(const QVariant &value, int maximum = 128, bool empty = false) {
    static const QRegularExpression characters(QStringLiteral("\\A[A-Za-z0-9_.:/@-]*\\z"));
    return value.metaType().id() == QMetaType::QString && value.toString().size() <= maximum &&
        (empty || !value.toString().isEmpty()) && characters.match(value.toString()).hasMatch();
}
bool providerIdentity(const QVariantMap &value) {
    const auto baseline = builtinProvider();
    if (!exactKeys(value, {"kind", "plugin_id", "package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})) return false;
    for (auto it = value.cbegin(); it != value.cend(); ++it)
        if (it.value().metaType().id() != QMetaType::QString) return false;
    if (value.value("kind") == "builtin") return value == baseline;
    static const QRegularExpression fingerprint(QStringLiteral("\\A[0-9a-f]{64}\\z"));
    return value.value("kind") == "package" && value.value("plugin_id") == "" &&
        token(value.value("package_id"), 96) && token(value.value("service_name"), 128) &&
        value.value("package_fingerprint").metaType().id() == QMetaType::QString &&
        value.value("configuration_fingerprint").metaType().id() == QMetaType::QString &&
        fingerprint.match(value.value("package_fingerprint").toString()).hasMatch() &&
        fingerprint.match(value.value("configuration_fingerprint").toString()).hasMatch();
}
bool validTeam(const QVariant &value, bool empty = false) {
    static const QRegularExpression characters(QStringLiteral("\\A[A-Za-z0-9_.-]{1,96}\\z"));
    return value.metaType().id() == QMetaType::QString &&
        ((empty && value.toString().isEmpty()) || characters.match(value.toString()).hasMatch());
}
bool settingsRecords(const QVariantList &records) {
    if (records.size() > 32) return false;
    QSet<QByteArray> scopes;
    for (const auto &entry : records) {
        const auto record = entry.toMap(), scope = record.value("scope").toMap();
        if (entry.metaType().id() != QMetaType::QVariantMap || !exactKeys(record, {"scope", "team_id", "provider"}) ||
            record.value("scope").metaType().id() != QMetaType::QVariantMap ||
            !exactKeys(scope, {"profile_id", "field_profile_id", "capability_revision", "environment"}) ||
            scope.value("profile_id") != "rmuc2027-regional-v1.0.0" ||
            !token(scope.value("field_profile_id")) || !token(scope.value("capability_revision")) ||
            (scope.value("environment") != "training" && scope.value("environment") != "competition") ||
            !validTeam(record.value("team_id"), true) || record.value("provider").metaType().id() != QMetaType::QVariantMap ||
            !providerIdentity(record.value("provider").toMap())) return false;
        const auto key = QJsonDocument::fromVariant(scope).toJson(QJsonDocument::Compact);
        if (scopes.contains(key)) return false;
        scopes.insert(key);
    }
    return true;
}
std::shared_ptr<ServiceEndpoint> own(ServiceEndpoint *endpoint) {
    const QPointer<ServiceEndpoint> alive(endpoint);
    return std::shared_ptr<ServiceEndpoint>(endpoint, [alive](ServiceEndpoint *) { if (alive) delete alive.data(); });
}
QString identity(const QVariantMap &row) {
    return row.value("team_id").toString() + QChar(0x1f) + row.value("source_id").toString();
}
QVariantMap initialFrame() {
    // Dimensions are confirmed; origin/axes remain unverified, so this frame
    // cannot project real targets until a calibration adapter registers it.
    return {{"frame_id", "rmuc2027.regional.field.v1"}, {"frame_revision", "unverified"},
        {"width_m", 28.0}, {"height_m", 15.0}, {"unit", "m"}, {"origin", "lower_left"},
        {"x_axis", "right"}, {"y_axis", "up"}, {"calibration_status", "unverified"},
        {"project_manual_calibration_acknowledged", false}};
}
QVariantMap origin(const QVariantMap &row) {
    QVariantMap result;
    for (const auto &key : {"team_id", "robot_key", "source_id", "sensor_id", "source_kind", "session_id", "sequence", "item_id"})
        result[QLatin1String(key)] = row.value(QLatin1String(key));
    return result;
}
bool finite(const QVariant &value) {
    return value.metaType().id() == QMetaType::Double || value.metaType().id() == QMetaType::Int ||
           value.metaType().id() == QMetaType::LongLong || value.metaType().id() == QMetaType::UInt;
}
}
TerminalSceneHost::TerminalSceneHost(PluginHost *plugins, QString directory, SeasonConfiguration *season,
                                   TerminalDataBus *bus, QObject *parent)
    : TerminalSceneHost(plugins, std::move(directory), season, bus, QString{}, parent) {}
TerminalSceneHost::TerminalSceneHost(PluginHost *plugins, QString directory, SeasonConfiguration *season,
                                   TerminalDataBus *bus, QString settingsFile, QObject *parent)
    : QObject(parent), m_plugins(plugins), m_directory(std::move(directory)), m_season(season), m_bus(bus),
      m_frame(initialFrame()), m_settingsFile(std::move(settingsFile)), m_selectedProvider(builtinProvider()) {
    m_status = QStringLiteral("场景渲染器保持停用；传感器／场地变换未接通，未知坐标只作文字");
    refreshBuiltinAvailability();
    m_timer.setInterval(100);
    connect(&m_timer, &QTimer::timeout, this, &TerminalSceneHost::submit);
    if (season) {
        connect(season, &SeasonConfiguration::aboutToChange, this, [this] {
            stop(); m_frame = initialFrame(); m_transforms.clear(); m_teamId.clear();
            m_selectedProvider = builtinProvider(); emit changed();
        });
        connect(season, &SeasonConfiguration::contextChanged, this, [this] { restoreConfiguration(); emit changed(); });
        connect(season, &SeasonConfiguration::stateChanged, this, &TerminalSceneHost::changed);
        connect(season, &QObject::destroyed, this, &TerminalSceneHost::stop);
    }
    if (bus) connect(bus, &QObject::destroyed, this, &TerminalSceneHost::stop);
    restoreConfiguration();
}
TerminalSceneHost::~TerminalSceneHost() {
    if (m_season) disconnect(m_season, nullptr, this, nullptr);
    if (m_packages) disconnect(m_packages, nullptr, this, nullptr);
    retire();
}
QVariantMap TerminalSceneHost::context() const {
    return m_season ? QVariantMap{{"profile_id", m_season->profileId()},
        {"field_profile_id", m_season->current().value("field_profile_id")},
        {"capability_revision", m_season->current().value("capability_revision")}} : QVariantMap{};
}
bool TerminalSceneHost::editable() const {
    return !m_changing && m_season && m_bus && m_season->editable() &&
        m_season->context().value("configuration_valid") == QVariant(true) &&
        m_season->profileId() == "rmuc2027-regional-v1.0.0";
}
bool TerminalSceneHost::fail(const QString &reason) { m_status = reason.left(512); emit changed(); return false; }
QVariantMap TerminalSceneHost::configurationScope() const {
    auto scope = context();
    scope["environment"] = m_season ? m_season->environment() : QString{};
    return scope;
}
void TerminalSceneHost::restoreConfiguration() {
    m_savedProfiles.clear(); m_configurationValid = true; m_configurationError.clear();
    m_teamId.clear(); m_selectedProvider = builtinProvider();
    if (m_settingsFile.isEmpty() || !QFileInfo::exists(m_settingsFile)) return;
    QFile file(m_settingsFile);
    if (QFileInfo(m_settingsFile).isSymLink() || !file.open(QIODevice::ReadOnly)) {
        m_configurationValid = false; m_configurationError = QStringLiteral("渲染配置不可读取或为符号链接；原文件保留，未启用渲染器"); return;
    }
    const auto bytes = file.read(64 * 1024 + 1);
    QJsonParseError error;
    const auto document = QJsonDocument::fromJson(bytes, &error);
    const auto map = document.toVariant().toMap();
    const auto records = map.value("profiles").toList();
    if (bytes.size() > 64 * 1024 || error.error != QJsonParseError::NoError || !document.isObject() ||
        !exactKeys(map, {"schema", "profiles"}) ||
        (map.value("schema").metaType().id() != QMetaType::Int &&
         map.value("schema").metaType().id() != QMetaType::LongLong &&
         map.value("schema").metaType().id() != QMetaType::Double) || map.value("schema").toDouble() != 1 ||
        map.value("profiles").metaType().id() != QMetaType::QVariantList || !settingsRecords(records)) {
        m_configurationValid = false; m_configurationError = QStringLiteral("渲染配置损坏或版本未知；原文件保留，请赛外重新明确保存选择"); return;
    }
    m_savedProfiles = records;
    for (const auto &entry : records) if (entry.toMap().value("scope").toMap() == configurationScope()) {
        m_teamId = entry.toMap().value("team_id").toString();
        m_selectedProvider = entry.toMap().value("provider").toMap();
        break;
    }
}
bool TerminalSceneHost::saveChoice(const QString &team, const QVariantMap &provider) {
    auto records = m_savedProfiles;
    const QVariantMap record{{"scope", configurationScope()}, {"team_id", team}, {"provider", provider}};
    bool replaced = false;
    for (auto &entry : records) if (entry.toMap().value("scope").toMap() == configurationScope()) {
        entry = record; replaced = true; break;
    }
    if (!replaced) records.append(record);
    if (!settingsRecords(records)) return fail(QStringLiteral("渲染选择或范围无效／超过32项；未修改当前选择"));
    if (!m_settingsFile.isEmpty()) {
        if (QFileInfo(m_settingsFile).isSymLink() || !QDir().mkpath(QFileInfo(m_settingsFile).absolutePath()))
            return fail(QStringLiteral("渲染配置目录不可写或目标为符号链接；未修改当前选择"));
        QLockFile lock(m_settingsFile + ".lock");
        if (!lock.tryLock(0)) return fail(QStringLiteral("另一个进程正在保存渲染配置；未修改当前选择"));
        QSaveFile file(m_settingsFile);
        const auto bytes = QJsonDocument::fromVariant(QVariantMap{{"schema", 1}, {"profiles", records}}).toJson(QJsonDocument::Compact);
        if (!file.open(QIODevice::WriteOnly) || file.write(bytes) != bytes.size() || !file.commit())
            return fail(QStringLiteral("渲染配置保存失败；原选择保留"));
    }
    m_savedProfiles = records; m_configurationValid = true; m_configurationError.clear();
    return true;
}
QVariantList TerminalSceneHost::providerCatalog() const {
    QVariantMap builtin{{"kind", "builtin"}, {"plugin_id", "renderer.terminal.2d.v1"}, {"available", m_builtinAvailable},
        {"label", m_builtinAvailable ? "内置二维投影" : "内置二维投影 · 未安装或标识重复"}};
    QVariantList rows{builtin};
    if (m_packages) for (const auto &entry : m_packages->serviceProviders(RendererRole, RendererContract)) {
        auto row = entry.toMap();
        row["kind"] = "package";
        row["label"] = row.value("title").toString() + " · " + row.value("package_id").toString() + " / " + row.value("service_name").toString();
        rows.append(row);
    }
    return rows;
}
QVariantMap TerminalSceneHost::selectedCatalogProvider() const {
    for (const auto &entry : providerCatalog()) {
        const auto row = entry.toMap();
        if (row.value("kind") != m_selectedProvider.value("kind")) continue;
        if (row.value("kind") == "builtin") return m_builtinAvailable ? row : QVariantMap{};
        bool matches = true;
        for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})
            if (row.value(QLatin1String(key)) != m_selectedProvider.value(QLatin1String(key))) matches = false;
        if (matches) return row;
    }
    return {};
}
void TerminalSceneHost::refreshBuiltinAvailability() {
    int matches = 0;
    if (m_plugins) for (const auto &entry : PluginHost::discover(m_directory)) {
        const auto metadata = entry.toMap();
        if (metadata.value("id") == "renderer.terminal.2d.v1" && metadata.value("role") == RendererRole &&
            metadata.value("contract") == QLatin1String(ExtensionPlugin_iid)) ++matches;
    }
    m_builtinAvailable = matches == 1;
}
void TerminalSceneHost::refreshProviders() {
    refreshBuiltinAvailability();
    emit changed();
}
void TerminalSceneHost::setPackageRuntime(PluginPackageRuntime *runtime) {
    if (m_packages == runtime) return;
    if (m_selectedProvider.value("kind") == "package") stop();
    if (m_packages) disconnect(m_packages, nullptr, this, nullptr);
    m_packages = runtime;
    if (runtime) {
        connect(runtime, &PluginPackageRuntime::changed, this, &TerminalSceneHost::refreshProviders);
        connect(runtime, &QObject::destroyed, this, [this] {
            if (m_selectedProvider.value("kind") == "package") stop();
            emit changed();
        });
    }
    emit changed();
}
bool TerminalSceneHost::selectProvider(const QVariantMap &locator) {
    if (!editable()) return fail(QStringLiteral("渲染提供者只能在赛外选择和保存"));
    refreshBuiltinAvailability();
    auto selected = builtinProvider();
    if (locator.value("kind") == "package" && exactKeys(locator, {"kind", "package_id", "service_name"})) {
        QVariantMap candidate;
        for (const auto &entry : providerCatalog()) {
            const auto row = entry.toMap();
            if (row.value("kind") == "package" && row.value("package_id") == locator.value("package_id") &&
                row.value("service_name") == locator.value("service_name")) candidate = row;
        }
        if (candidate.isEmpty()) return fail(QStringLiteral("所选渲染工厂尚未启用或依赖未就绪；未加载任意路径"));
        selected["kind"] = "package"; selected["plugin_id"] = "";
        for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})
            selected[QLatin1String(key)] = candidate.value(QLatin1String(key));
    } else if (locator != QVariantMap{{"kind", "builtin"}}) return fail(QStringLiteral("渲染选择仅接受内置项或准确的插件／导出服务标识"));
    if (!saveChoice(m_teamId, selected)) return false;
    QPointer<TerminalSceneHost> alive(this);
    retire();
    if (!alive) return false;
    m_selectedProvider = selected;
    m_status = QStringLiteral("渲染提供者选择已保存；尚未启用，数据与标定仍由宿主核验");
    emit changed(); return true;
}
bool TerminalSceneHost::selectTeam(const QString &teamId) {
    if (!editable()) return fail(QStringLiteral("渲染器队伍范围只能在赛外配置"));
    if (!validTeam(teamId)) return fail(QStringLiteral("填写明确的项目队伍标识"));
    if (!saveChoice(teamId, m_selectedProvider)) return false;
    if (teamId == m_teamId) {
        m_status = QStringLiteral("渲染队伍范围已保存；当前启用状态保持");
        emit changed(); return true;
    }
    QPointer<TerminalSceneHost> alive(this);
    retire();
    if (!alive) return false;
    m_teamId = teamId; m_status = QStringLiteral("渲染队伍范围已选；尚未启用"); emit changed(); return true;
}
void TerminalSceneHost::retire() {
    ++m_generation; m_timer.stop(); m_projection.clear(); m_lastScene.clear(); m_projector.reset();
    auto old = std::move(m_endpoint);
    m_activation.clear(); m_revision = 0; m_changing = false; m_providerIdentity.clear();
    if (old) { disconnect(old.get(), nullptr, this, nullptr); old->stop(); }
}
void TerminalSceneHost::stop() {
    QPointer<TerminalSceneHost> alive(this); retire();
    if (!alive) return;
    m_status = QStringLiteral("仅渲染器已停；单机数据、队伍共享与收发链路继续运行"); emit changed();
}
bool TerminalSceneHost::setEnabled(bool enable) {
    if (!enable) { stop(); return true; }
    if (!editable() || m_teamId.isEmpty()) return fail(QStringLiteral("先在赛外选择明确的渲染队伍范围"));
    if (!m_configurationValid) return fail(m_configurationError);
    if (m_endpoint) return true;
    refreshBuiltinAvailability();
    const auto choice = selectedCatalogProvider();
    if (choice.isEmpty()) return fail(QStringLiteral("保存的渲染工厂尚未就绪或内容／配置已变化；请检查并重新明确选择，不自动替换"));
    QString error;
    const auto generation = ++m_generation;
    m_changing = true;
    QPointer<TerminalSceneHost> alive(this);
    ServiceEndpoint *created = nullptr;
    QVariantMap provider;
    if (choice.value("kind") == "package") {
        if (m_packages) created = m_packages->createProviderService(choice.value("package_id").toString(),
            choice.value("service_name").toString(), RendererRole, RendererContract, &error, &provider);
    } else {
        auto *factory = m_plugins ? m_plugins->loadExtension(m_directory, "renderer.terminal.2d.v1", RendererRole, &error) : nullptr;
        if (alive && generation == m_generation && factory) created = factory->createService();
        provider = choice;
    }
    auto endpoint = own(created);
    if (!alive || generation != m_generation) return false;
    if (!endpoint) { m_changing = false; return fail(error.isEmpty() ? QStringLiteral("所选渲染插件未就绪；其他功能继续") : error); }
    if (choice.value("kind") == "package") {
        for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})
            if (provider.value(QLatin1String(key)) != choice.value(QLatin1String(key))) {
                endpoint->stop();
                if (!alive || generation != m_generation) return false;
                m_changing = false;
                return fail(QStringLiteral("创建期间渲染提供者身份已改变；请重新查看和选择"));
            }
    }
    const QVariantMap config{{"schema", 1}, {"context", context()}};
    auto projector = std::make_unique<TerminalRendererContract::Projector>();
    if (!projector->configure(config, &error)) { m_changing = false; return fail(error); }
    m_endpoint = endpoint; m_projector = std::move(projector); m_providerIdentity = provider;
    connect(endpoint.get(), &ServiceEndpoint::messageReceived, this, [this, generation](const QVariantMap &message) { receive(generation, message); });
    connect(endpoint.get(), &ServiceEndpoint::errorOccurred, this, [this, generation](const QString &error) { if (generation == m_generation) fail(error); });
    if (choice.value("kind") == "package") {
        connect(endpoint.get(), &ServiceEndpoint::statusChanged, this, [this, generation] {
            if (generation != m_generation || !m_endpoint) return;
            if (m_endpoint->details().value("provider_active") != QVariant(true)) {
                QPointer<TerminalSceneHost> alive(this);
                retire();
                if (alive) fail(QStringLiteral("社区渲染提供者已退役；场景已清除，恢复后需明确重新启用"));
            } else emit changed();
        });
    }
    const bool started = endpoint->start(config, &error);
    if (!alive || generation != m_generation) return false;
    m_changing = false;
    if (!started) { retire(); if (!alive) return false; return fail(error); }
    m_activation = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_timer.start(); m_status = QStringLiteral("所选渲染器已启用；未验证的帧／坐标／mock仅列文字");
    emit changed(); return true;
}
bool TerminalSceneHost::setCalibration(const QVariantMap &frame, const QVariantList &transforms, QString *error) {
    if (!editable() || transforms.size() > 128) {
        if (error)
            *error = QStringLiteral("标定只能由原生适配器在赛外注册，最多128项");
        return false;
    }
    const auto tick = PacketObservation::steadyMilliseconds(), utc = QDateTime::currentMSecsSinceEpoch();
    QVariantMap candidate{{"schema", 1}, {"kind", "renderer-scene"}, {"context", context()}, {"team_id", m_teamId},
        {"scene_id", "calibration-check"}, {"revision", 1}, {"produced_at_ms", utc}, {"produced_tick_ms", tick},
        {"frame", frame}, {"items", QVariantList{}}};
    TerminalRendererContract::Scene parsed;
    if (!TerminalRendererContract::parseScene(candidate, &parsed, error)) return false;
    QVariantMap checked;
    const QSet<QString> required{"team_id", "source_id", "frame_id", "frame_revision", "transform_id"};
    for (const auto &entry : transforms) {
        const auto value = entry.toMap();
        if (entry.metaType().id() != QMetaType::QVariantMap || value.size() != required.size()) {
            if (error)
                *error = "Invalid native transform registration";
            return false;
        }
        for (const auto &key : required) if (value.value(key).metaType().id() != QMetaType::QString || value.value(key).toString().isEmpty() || value.value(key).toString().size() > 96) {
            if (error)
                *error = "Invalid native transform identity";
            return false;
        }
        if (value.value("team_id") != m_teamId || value.value("frame_id") != frame.value("frame_id") || value.value("frame_revision") != frame.value("frame_revision") || checked.contains(identity(value))) {
            if (error)
                *error = "Native transform scope mismatch or duplicate";
            return false;
        }
        checked[identity(value)] = value;
    }
    m_frame = frame; m_transforms = checked;
    // Every calibration change retires its old projected coordinates.
    stop(); return true;
}
void TerminalSceneHost::submit() {
    if (!m_endpoint || !m_projector || !m_bus || !m_season || m_changing) return;
    const auto tick = PacketObservation::steadyMilliseconds(), utc = QDateTime::currentMSecsSinceEpoch();
    QVariantList items;
    for (const auto &entry : m_bus->view().value("items").toList()) {
        const auto row = entry.toMap();
        if (row.value("team_id") != m_teamId || row.value("lifecycle") != "active" ||
            !QStringList{"fresh", "time_unverified"}.contains(row.value("state").toString())) continue;
        const auto receivedAge = row.value("received_age_ms").toLongLong();
        const auto value = row.value("value").toMap();
        QVariant spatial;
        if (finite(value.value("x")) && finite(value.value("y")) && std::isfinite(value.value("x").toDouble()) && std::isfinite(value.value("y").toDouble())) {
            const auto evidence = m_transforms.value(identity(row)).toMap();
            const bool verified = !evidence.isEmpty() && evidence.value("frame_id") == row.value("frame_id") &&
                evidence.value("frame_revision") == row.value("frame_revision") && evidence.value("transform_id") == row.value("transform_id");
            spatial = QVariantMap{{"frame_id", row.value("frame_id")}, {"frame_revision", row.value("frame_revision")},
                {"transform_id", row.value("transform_id")}, {"unit", row.value("unit")}, {"x", value.value("x")}, {"y", value.value("y")},
                {"heading_deg", value.value("heading_deg")}, {"transform_verified", verified}};
            // Incomplete spatial metadata is text-only, not a malformed scene.
            if (row.value("frame_id").toString().isEmpty() || row.value("frame_revision").toString().isEmpty() || row.value("transform_id").toString().isEmpty() || row.value("unit") != "m") spatial = QVariant{};
        }
        const auto label = value.value("summary").toString();
        items.append(QVariantMap{{"origin", origin(row)}, {"produced_at_ms", row.value("produced_at_ms")},
            {"received_at_ms", row.value("received_at_ms")}, {"received_tick_ms", qMax<qint64>(0, tick - receivedAge)},
            {"remaining_ms", row.value("remaining_ms")}, {"state", row.value("source_kind") == "mock" ? "mock" : row.value("state")},
            {"confidence", row.value("confidence")}, {"label", (label.isEmpty() ? row.value("item_id").toString() : label).left(128)}, {"spatial", spatial}});
    }
    QVariantMap scene{{"schema", 1}, {"kind", "renderer-scene"}, {"context", context()}, {"team_id", m_teamId},
        {"scene_id", m_activation}, {"revision", qulonglong(++m_revision)}, {"produced_at_ms", utc}, {"produced_tick_ms", tick},
        {"frame", m_frame}, {"items", items}};
    QString error;
    const auto independent = m_projector->project(scene, utc, tick, &error);
    if (independent.isEmpty()) { m_projection.clear(); fail(error); return; }
    m_lastScene = scene;
    const auto endpoint = m_endpoint; const auto generation = m_generation;
    QPointer<TerminalSceneHost> alive(this);
    if (!endpoint->submit(scene, &error)) {
        if (alive && generation == m_generation) { m_projection.clear(); fail(error); } return;
    }
    if (!alive || generation != m_generation) return;
    emit changed();
}
void TerminalSceneHost::receive(quint64 generation, const QVariantMap &message) {
    if (generation != m_generation || !m_endpoint || !m_projector || m_lastScene.isEmpty()) return;
    if (message.value("schema") != 1 || message.value("kind") != "renderer-projection" || message.value("context").toMap() != context() ||
        message.value("scene_id") != m_activation || message.value("revision") != m_lastScene.value("revision") ||
        QJsonDocument::fromVariant(message).toJson(QJsonDocument::Compact).size() > 256 * 1024) return;
    // Use an independent canonical projection for the Qt view. A replacement
    // renderer's packet cannot promote unverified sensor coordinates to markers.
    QString error;
    if (!TerminalRendererContract::validateProjection(m_lastScene, message,
            QDateTime::currentMSecsSinceEpoch(), PacketObservation::steadyMilliseconds(), &error)) {
        m_projection.clear(); fail(error); return;
    }
    m_projection = m_projector->view(QDateTime::currentMSecsSinceEpoch(), PacketObservation::steadyMilliseconds(), &error);
    if (m_projection.isEmpty()) fail(error); else emit changed();
}
QVariantMap TerminalSceneHost::projection() const {
    if (!m_projector || m_projection.isEmpty()) return {};
    QString error;
    return m_projector->view(QDateTime::currentMSecsSinceEpoch(), PacketObservation::steadyMilliseconds(), &error);
}
QVariantMap TerminalSceneHost::details() const {
    const auto choice = selectedCatalogProvider();
    const auto selectedId = m_selectedProvider.value("kind") == "builtin" ? QStringLiteral("renderer.terminal.2d.v1") :
        m_selectedProvider.value("package_id").toString() + "/" + m_selectedProvider.value("service_name").toString();
    return {{"active", active()}, {"plugin_id", active() ? selectedId : QString{}}, {"selected_plugin_id", selectedId}, {"context", context()},
        {"provider_identity", m_providerIdentity}, {"provider_available", !choice.isEmpty()},
        {"configuration_valid", m_configurationValid}, {"configuration_error", m_configurationError},
        {"settings_file", m_settingsFile}, {"selection_restored_without_enabling", !m_savedProfiles.isEmpty() && !active()},
        {"team_id", m_teamId}, {"calibration_status", m_frame.value("calibration_status")},
        {"registered_transforms", m_transforms.size()}, {"ue_dependency", false},
        {"sensor_adapter_connected", !m_transforms.isEmpty()}, {"automatic_actions_allowed", false}};
}
