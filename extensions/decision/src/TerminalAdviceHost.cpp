#include "TerminalAdviceHost.h"
#include "AdviceContract.h"
#include "PluginHost.h"
#include "PluginPackageRuntime.h"
#include "PacketObservation.h"
#include "RulesetCatalog.h"
#include "SeasonConfiguration.h"
#include "ServiceEndpoint.h"
#include "TerminalDataBus.h"
#include "TerminalTeamHost.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLockFile>
#include <QPointer>
#include <QRegularExpression>
#include <QSaveFile>
#include <QScopeGuard>
#include <QSet>
#include <QThread>
#include <QTimer>
#include <QUrl>
#include <QUuid>
#include <algorithm>
#include <cmath>
#include <utility>

namespace {
constexpr qint64 Safe = 9007199254740991LL;
constexpr int SettingsLimit = 128 * 1024, InputLimit = 40 * 1024;
const QSet<QString> RawKeys{"schema", "context", "team_id", "robot_key", "source_id", "sensor_id", "source_kind",
    "session_id", "sequence", "item_id", "produced_at_ms", "clock_domain", "ttl_ms", "confidence", "validation",
    "lifecycle", "data_type", "value", "unit", "frame_id", "frame_revision", "transform_id"};
bool fail(QString *error, const QString &message) { if (error) *error = message; return false; }
bool integer(const QVariant &value, qint64 low, qint64 high, qint64 *out = nullptr) {
    const auto type = value.metaType().id();
    if (type != QMetaType::Int && type != QMetaType::UInt && type != QMetaType::LongLong &&
        type != QMetaType::ULongLong && type != QMetaType::Double && type != QMetaType::Float) return false;
    const auto n = value.toDouble();
    if (!std::isfinite(n) || std::floor(n) != n || n < double(low) || n > double(high)) return false;
    if (out) *out = qint64(n);
    return true;
}
bool text(const QVariant &value, int maximum, bool empty = false) {
    if (value.metaType().id() != QMetaType::QString || value.toString().size() > maximum ||
        (!empty && value.toString().trimmed().isEmpty())) return false;
    for (const auto c : value.toString()) if (c.isNull() || c.category() == QChar::Other_Control ||
        c.category() == QChar::Separator_Line || c.category() == QChar::Separator_Paragraph) return false;
    return true;
}
bool strategyText(const QVariant &value, bool required) {
    if (value.metaType().id() != QMetaType::QString || value.toString().size() > 1000 ||
        (required && value.toString().trimmed().isEmpty())) return false;
    for (const auto c : value.toString()) if (c.isNull() ||
        (c.category() == QChar::Other_Control && c != '\n' && c != '\r')) return false;
    return true;
}
bool id(const QVariant &value, int maximum = 96) {
    if (!text(value, maximum)) return false;
    for (const auto c : value.toString()) {
        const auto n = c.unicode();
        if (!((n >= 'a' && n <= 'z') || (n >= 'A' && n <= 'Z') || (n >= '0' && n <= '9') ||
              n == '_' || n == '.' || n == '-' || n == ':' || n == '/')) return false;
    }
    return true;
}
bool exact(const QVariantMap &map, const QSet<QString> &required, const QSet<QString> &optional = {}) {
    for (const auto &key : required) if (!map.contains(key)) return false;
    for (auto it = map.cbegin(); it != map.cend(); ++it)
        if (!required.contains(it.key()) && !optional.contains(it.key())) return false;
    return true;
}
bool flag(const QVariantMap &map, const QString &key) { return map.value(key).metaType().id() == QMetaType::Bool; }
bool yes(const QVariantMap &map, const QString &key) { return flag(map, key) && map.value(key).toBool(); }
QByteArray compact(const QVariant &value) { return QJsonDocument::fromVariant(value).toJson(QJsonDocument::Compact); }
QString digest(const QVariant &value) {
    return QString::fromLatin1(QCryptographicHash::hash(compact(value), QCryptographicHash::Sha256).toHex());
}
bool environmentName(const QVariant &value) {
    if (!text(value, 96)) return false;
    const auto name = value.toString();
    for (qsizetype i = 0; i < name.size(); ++i) {
        const auto n = name[i].unicode();
        if (!((n >= 'a' && n <= 'z') || (n >= 'A' && n <= 'Z') || n == '_' ||
              (i && n >= '0' && n <= '9'))) return false;
    }
    return true;
}
bool semanticRobot(const QVariant &value) {
    if (!text(value, 64)) return false;
    const auto parts = value.toString().split('/');
    if (parts.size() != 3 || (parts[0] != "red" && parts[0] != "blue") || parts[2].isEmpty() ||
        parts[2].size() > 3 || parts[2][0] < '1' || parts[2][0] > '9') return false;
    for (const auto c : parts[2]) if (c < '0' || c > '9') return false;
    const auto slot = parts[2].toInt();
    for (const auto &entry : RulesetCatalog::profile("rmuc2027-regional-v1.0.0").value("roster").toList()) {
        const auto row = entry.toMap();
        if (row.value("role_id") == parts[1]) return slot >= 1 && slot <= row.value("count").toInt();
    }
    return false;
}
QVariantMap rulesContext(const SeasonConfiguration *season) {
    if (!season) return {};
    const auto current = season->current();
    return {{"profile_id", season->profileId()}, {"field_profile_id", current.value("field_profile_id")},
            {"capability_revision", current.value("capability_revision")}};
}
QVariantMap configurationScope(const QVariantMap &ctx, const QString &environment, const QVariantMap &values) {
    auto result = ctx; result["environment"] = environment;
    result["team_id"] = values.value("team_id"); result["robot_key"] = values.value("robot_key");
    return result;
}
QVariantMap raw(const QVariantMap &row) {
    QVariantMap result;
    for (auto it = row.cbegin(); it != row.cend(); ++it) if (RawKeys.contains(it.key())) result[it.key()] = it.value();
    return result;
}
QString fieldKey(const QVariantMap &field, const QVariantMap &values) {
    return digest(QVariantList{field.value("robot_key", values.value("robot_key")), field.value("source_id"), field.value("item_id")});
}
bool localEndpoint(const QUrl &url) {
    return QHostAddress(url.host()).isLoopback() || url.host().compare("localhost", Qt::CaseInsensitive) == 0;
}
bool fingerprint(const QVariant &value) {
    if (!text(value, 64) || value.toString().size() != 64) return false;
    for (const auto c : value.toString()) if ((c < '0' || c > '9') && (c < 'a' || c > 'f')) return false;
    return true;
}
bool packageLocator(const QVariantMap &value) {
    static const QRegularExpression packageId("\\A[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*\\z");
    static const QRegularExpression serviceName("\\A[a-z][a-z0-9_.-]{0,79}@[1-9][0-9]{0,3}\\z");
    return text(value.value("package_id"), 64) && packageId.match(value.value("package_id").toString()).hasMatch() &&
        text(value.value("service_name"), 96) && serviceName.match(value.value("service_name").toString()).hasMatch();
}
bool samePackageIdentity(const QVariantMap &a, const QVariantMap &b) {
    for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})
        if (a.value(QLatin1String(key)) != b.value(QLatin1String(key))) return false;
    return true;
}
bool providerValid(const QString &kind, const QVariantMap &p, QString *error) {
    const auto defaults = TerminalAdviceHost::providerDefaults(kind);
    QSet<QString> fields;
    for (auto it = defaults.cbegin(); it != defaults.cend(); ++it) fields.insert(it.key());
    if (defaults.isEmpty() || !exact(p, fields) || !text(p.value("model"), 128) ||
        !integer(p.value("timeout_ms"), 50, 120000) || !integer(p.value("max_output_tokens"), 256, 8192))
        return fail(error, "模型类型、明确模型ID、超时或输出预算无效");
    if (kind == "package")
        return (packageLocator(p) && fingerprint(p.value("package_fingerprint")) && fingerprint(p.value("configuration_fingerprint"))) ||
            fail(error, "插件模型须保存准确的包／服务标识与原生审核指纹");
    if (kind == "codex") {
        return (text(p.value("executable"), 1024) && text(p.value("auth_home"), 1024, true) &&
            text(p.value("reasoning"), 16) && QStringList{"low", "medium", "high"}.contains(p.value("reasoning").toString())) ||
            fail(error, "Codex仅接受专用认证目录引用、程序引用和固定推理强度；不能传任意参数");
    }
    if (!text(p.value("endpoint"), 2048) || !text(p.value("provider"), 64) || !environmentName(p.value("key_env")) ||
        !flag(p, "thinking") || !text(p.value("api"), 16) || !text(p.value("format"), 16) || !text(p.value("schema_profile"), 16) ||
        !QStringList{"chat", "responses"}.contains(p.value("api").toString()) ||
        !QStringList{"json-object", "json-schema"}.contains(p.value("format").toString()) ||
        !QStringList{"basic", "concise"}.contains(p.value("schema_profile").toString()) ||
        (p.value("thinking").toBool() && (p.value("provider") != "deepseek" || p.value("api") != "chat")))
        return fail(error, "HTTP模型选项或密钥环境变量名无效；不接受密钥值／未知选项");
    const QUrl url(p.value("endpoint").toString(), QUrl::StrictMode);
    return (url.isValid() && !url.isRelative() && !url.host().isEmpty() && url.userInfo().isEmpty() &&
        !url.authority(QUrl::FullyEncoded).contains('@') && !url.hasQuery() && !url.hasFragment() &&
        url.path().startsWith('/') && (url.port(-1) == -1 || (url.port() >= 1 && url.port() <= 65535)) &&
        (url.scheme() == "https" || (url.scheme() == "http" && localEndpoint(url)))) ||
        fail(error, "模型端点须为HTTPS完整路径，本机HTTP仅限loopback；不保存URL凭据");
}
QVariantList strategies() {
    return {QVariantMap{{"id", "balanced"}, {"label", "均衡协同"}, {"description", "根据已提供状态平衡生存、资源与队伍协同；缺失事实明确说明。"}},
        QVariantMap{{"id", "defensive"}, {"label", "生存防守"}, {"description", "优先已观测风险、补给与防守；不补造敌方动向。"}},
        QVariantMap{{"id", "territory"}, {"label", "场地控制"}, {"description", "分析已提供据点状态与队伍能力；区分完全与临时占领，不推测未提供资格。"}},
        QVariantMap{{"id", "heavy-support"}, {"label", "重型协同"}, {"description", "关注已提供重型机器人组装、实际安装与队伍协同；解锁不等于已安装。"}},
        QVariantMap{{"id", "logistics"}, {"label", "后勤资源"}, {"description", "关注已提供补给、基地后勤与资源；不把规则估算当实际遥测。"}},
        QVariantMap{{"id", "custom"}, {"label", "自定义策略"}, {"description", "使用赛前明确保存的策略关注点；仍不能改写数据、来源或机器人命令边界。"}}};
}
QString strategyDescription(const QString &key) {
    for (const auto &entry : strategies()) if (entry.toMap().value("id") == key) return entry.toMap().value("description").toString();
    return {};
}
bool readSettings(const QString &file, QVariantList *profiles, QVariantMap *selected, QString *error) {
    profiles->clear(); selected->clear();
    if (QFileInfo(file).isSymLink()) return fail(error, "模型配置不能为符号链接；原文件保留");
    if (!QFileInfo::exists(file)) return true;
    QFile input(file);
    if (!input.open(QIODevice::ReadOnly)) return fail(error, "模型配置无法读取；未启用模型");
    const auto bytes = input.read(SettingsLimit + 1); QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(bytes, &parse); const auto map = document.toVariant().toMap();
    if (bytes.size() > SettingsLimit || parse.error != QJsonParseError::NoError || !document.isObject() ||
        !exact(map, {"schema", "selected", "profiles"}) || !integer(map.value("schema"), 1, 1) ||
        map.value("selected").metaType().id() != QMetaType::QVariantMap ||
        map.value("profiles").metaType().id() != QMetaType::QVariantList || map.value("profiles").toList().size() > 32)
        return fail(error, "模型配置损坏或版本未知；原文件保留，需赛外明确保存恢复");
    QSet<QString> seen;
    for (const auto &entry : map.value("profiles").toList()) {
        auto record = entry.toMap();
        const auto scope = record.value("scope").toMap();
        auto values = record.value("values").toMap();
        // Schema1 existed before HUD preferences. Only a complete absence of
        // all three fields is a legacy record; partial/corrupt sets still fail
        // normal strict validation. Loading never rewrites the original file.
        if (!values.contains("hud_enabled") && !values.contains("hud_position") && !values.contains("hud_density")) {
            const auto defaults = TerminalAdviceHost::defaults();
            for (const auto &key : {"hud_enabled", "hud_position", "hud_density"})
                values[QLatin1String(key)] = defaults.value(QLatin1String(key));
            record["values"] = values;
        }
        if (entry.metaType().id() != QMetaType::QVariantMap || !exact(record, {"scope", "values"}) ||
            record.value("scope").metaType().id() != QMetaType::QVariantMap ||
            record.value("values").metaType().id() != QMetaType::QVariantMap ||
            !exact(scope, {"profile_id", "field_profile_id", "capability_revision", "environment", "team_id", "robot_key"}) ||
            scope.value("profile_id") != "rmuc2027-regional-v1.0.0" || !id(scope.value("field_profile_id"), 128) ||
            !id(scope.value("capability_revision"), 128) ||
            (scope.value("environment") != "training" && scope.value("environment") != "competition") ||
            scope.value("team_id") != values.value("team_id") || scope.value("robot_key") != values.value("robot_key") ||
            !TerminalAdviceHost::validatePublic(values, error) || seen.contains(digest(scope)))
            return fail(error, "模型范围含无效、重复或旧赛季配置；原文件保留");
        seen.insert(digest(scope)); profiles->append(record);
    }
    *selected = map.value("selected").toMap();
    return (selected->isEmpty() || seen.contains(digest(*selected))) || fail(error, "模型选中范围不存在；未启用服务");
}
std::shared_ptr<ServiceEndpoint> own(ServiceEndpoint *endpoint) {
    const QPointer<ServiceEndpoint> alive(endpoint);
    return std::shared_ptr<ServiceEndpoint>(endpoint, [alive](ServiceEndpoint *) { if (alive) delete alive.data(); });
}
}

QVariantMap TerminalAdviceHost::providerDefaults(const QString &kind) {
    if (kind == "http") return {{"endpoint", "https://api.deepseek.com/chat/completions"}, {"api", "chat"}, {"model", ""},
        {"provider", "deepseek"}, {"format", "json-object"}, {"schema_profile", "concise"}, {"timeout_ms", 15000},
        {"max_output_tokens", 1200}, {"key_env", "DEEPSEEK_API_KEY"}, {"thinking", false}};
    if (kind == "codex") return {{"model", ""}, {"timeout_ms", 15000}, {"max_output_tokens", 1200},
        {"executable", "codex"}, {"auth_home", ""}, {"reasoning", "high"}};
    if (kind == "package") return {{"package_id", ""}, {"service_name", ""}, {"package_fingerprint", ""},
        {"configuration_fingerprint", ""}, {"model", ""}, {"timeout_ms", 15000}, {"max_output_tokens", 1200}};
    return {};
}
QVariantMap TerminalAdviceHost::defaults() {
    return {{"team_id", ""}, {"robot_key", ""}, {"provider_kind", "http"}, {"provider_options", providerDefaults("http")},
        {"strategy_id", "balanced"}, {"strategy_text", ""}, {"input_mode", "local"}, {"selected_fields", QVariantList{}},
        {"auto_advice", false}, {"trigger", "event"}, {"minimum_interval_ms", 1000}, {"voice_enabled", false},
        {"hud_enabled", true}, {"hud_position", "field-above"}, {"hud_density", "compact"}};
}
bool TerminalAdviceHost::validatePublic(const QVariantMap &values, QString *error) {
    if (error) error->clear();
    QSet<QString> fields; const auto base = defaults();
    for (auto it = base.cbegin(); it != base.cend(); ++it) fields.insert(it.key());
    if (!exact(values, fields) || !id(values.value("team_id"), 64) || !semanticRobot(values.value("robot_key")) ||
        !text(values.value("provider_kind"), 16) || values.value("provider_options").metaType().id() != QMetaType::QVariantMap ||
        !providerValid(values.value("provider_kind").toString(), values.value("provider_options").toMap(), error) ||
        !text(values.value("strategy_id"), 32) || strategyDescription(values.value("strategy_id").toString()).isEmpty() ||
        !strategyText(values.value("strategy_text"), values.value("strategy_id") == "custom") ||
        !text(values.value("input_mode"), 16) || !text(values.value("trigger"), 16) ||
        !QStringList{"local", "team"}.contains(values.value("input_mode").toString()) ||
        !QStringList{"event", "interval"}.contains(values.value("trigger").toString()) ||
        !flag(values, "auto_advice") || !flag(values, "voice_enabled") || !integer(values.value("minimum_interval_ms"), 500, 30000) ||
        !flag(values, "hud_enabled") || !text(values.value("hud_position"), 32) || !text(values.value("hud_density"), 16) ||
        !QStringList{"field-above", "right"}.contains(values.value("hud_position").toString()) ||
        !QStringList{"compact", "standard"}.contains(values.value("hud_density").toString()) ||
        values.value("selected_fields").metaType().id() != QMetaType::QVariantList || values.value("selected_fields").toList().size() > 32)
        return fail(error, "模型、策略、语义身份、授权字段或请求模式配置无效");
    QSet<QString> seen;
    for (const auto &entry : values.value("selected_fields").toList()) {
        const auto field = entry.toMap();
        if (entry.metaType().id() != QMetaType::QVariantMap || !exact(field, {"source_id", "item_id", "uses"}, {"robot_key"}) ||
            !id(field.value("source_id")) || !id(field.value("item_id")) ||
            (field.contains("robot_key") && (!semanticRobot(field.value("robot_key")) ||
             field.value("robot_key").toString().section('/', 0, 0) != values.value("robot_key").toString().section('/', 0, 0))) ||
            field.value("uses").metaType().id() != QMetaType::QVariantList || field.value("uses").toList().isEmpty() ||
            field.value("uses").toList().size() > 2 || seen.contains(fieldKey(field, values)))
            return fail(error, "输入字段须唯一、同队且逐项明确localAi／externalAi用途；无默认授权");
        QSet<QString> purposes;
        for (const auto &use : field.value("uses").toList()) {
            if (!text(use, 16) || (use != "localAi" && use != "externalAi") || purposes.contains(use.toString()))
                return fail(error, "输入字段用途重复或不受支持");
            purposes.insert(use.toString());
        }
        if (values.value("input_mode") == "local" && field.value("robot_key", values.value("robot_key")) != values.value("robot_key"))
            return fail(error, "本机模式不能选择队友机器人字段");
        seen.insert(fieldKey(field, values));
    }
    return true;
}

struct TerminalAdviceHost::Private {
    PluginHost *plugins = nullptr; QString directory, file;
    QPointer<SeasonConfiguration> season; QPointer<TerminalDataBus> bus; QPointer<TerminalTeamHost> team;
    QPointer<PluginPackageRuntime> packages;
    QMap<QString, int> builtinProviderCounts;
    EndpointFactory factory; std::shared_ptr<ServiceEndpoint> endpoint;
    QVariantMap values = defaults(), captured, trace, result, providerIdentity;
    QString status = QStringLiteral("2027建议未启用；没有有效建议时HUD隐藏"), requestId, evidenceHash, eventHash;
    QElapsedTimer clock; QTimer timer;
    quint64 generation = 0, revision = 0;
    qint64 captureTick = 0, captureUtc = 0, inputDeadline = 0, adviceDeadline = 0, completedTick = 0, lastRequest = -30000, lastProjection = 0;
    bool valid = true, enabled = false, changing = false, dispatching = false;
};
TerminalAdviceHost::TerminalAdviceHost(PluginHost *plugins, QString directory, SeasonConfiguration *season,
    TerminalDataBus *bus, TerminalTeamHost *team, QString file, QObject *parent, EndpointFactory factory)
    : QObject(parent), d(std::make_unique<Private>()) {
    d->plugins = plugins; d->directory = std::move(directory); d->season = season; d->bus = bus; d->team = team;
    d->file = std::move(file); d->factory = std::move(factory); d->clock.start();
    d->timer.setParent(this); d->timer.setInterval(100);
    connect(&d->timer, &QTimer::timeout, this, &TerminalAdviceHost::tick);
    if (season) {
        connect(season, &SeasonConfiguration::aboutToChange, this, [this] { retire(QStringLiteral("规则／用途切换，已撤销旧模型请求与语音"), true); });
        connect(season, &SeasonConfiguration::contextChanged, this, [this] { load(); emit changed(); });
        connect(season, &SeasonConfiguration::stateChanged, this, [this] {
            if (d->enabled && (!yes(d->season->context(), "configuration_valid") || d->season->environment() != "training"))
                retire(QStringLiteral("当前范围没有经过核验的完全本地推理适配器，已停用模型"), true);
            else emit changed();
        });
        connect(season, &QObject::destroyed, this, [this] { retire(QStringLiteral("赛季宿主已离线"), true); });
    }
    if (bus) {
        connect(bus, &TerminalDataBus::changed, this, &TerminalAdviceHost::tick);
        connect(bus, &QObject::destroyed, this, [this] { retire(QStringLiteral("本机数据源已离线"), true); });
    }
    if (team) connect(team, &TerminalTeamHost::changed, this, &TerminalAdviceHost::tick);
    load(); refreshProviders();
}
TerminalAdviceHost::~TerminalAdviceHost() { blockSignals(true); stop(); }
QVariantMap TerminalAdviceHost::current() const { return d->values; }
QVariantList TerminalAdviceHost::strategyCatalog() const { return strategies(); }
QVariantList TerminalAdviceHost::providerCatalog() const {
    QVariantList result{QVariantMap{{"kind", "http"}, {"label", "HTTP模型模板（未验证可用性）"}, {"default_options", providerDefaults("http")}},
        QVariantMap{{"kind", "codex"}, {"label", "Codex专用进程模板（推理位置未知）"}, {"default_options", providerDefaults("codex")}}};
    const auto providers = d->packages ? d->packages->serviceProviders("decision", "terminal.decision@1") : QVariantList{};
    for (const auto &entry : providers) {
        auto row = entry.toMap(), options = providerDefaults("package");
        for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})
            options[QLatin1String(key)] = row.value(QLatin1String(key));
        row["kind"] = "package"; row["available"] = true;
        row["label"] = row.value("title").toString() + " · " + row.value("package_id").toString() + " / " + row.value("service_name").toString();
        row["default_options"] = options; result.append(row);
    }
    const auto saved = d->values.value("provider_options").toMap();
    if (d->values.value("provider_kind") == "package" && packageProvider(saved, true).isEmpty()) {
        QVariantMap row{{"kind", "package"}, {"available", false}, {"default_options", saved},
            {"label", "已保存 · " + saved.value("package_id").toString() + " / " + saved.value("service_name").toString() + "（不可用／内容已变化）"}};
        for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})
            row[QLatin1String(key)] = saved.value(QLatin1String(key));
        result.append(row);
    }
    return result;
}
QVariantMap TerminalAdviceHost::packageProvider(const QVariantMap &options, bool requireFingerprints) const {
    if (!d->packages) return {};
    for (const auto &entry : d->packages->serviceProviders("decision", "terminal.decision@1")) {
        const auto row = entry.toMap();
        if (row.value("package_id") == options.value("package_id") && row.value("service_name") == options.value("service_name") &&
            (!requireFingerprints || samePackageIdentity(row, options))) return row;
    }
    return {};
}
void TerminalAdviceHost::setPackageRuntime(PluginPackageRuntime *runtime) {
    if (QThread::currentThread() != thread() || d->packages == runtime) return;
    QPointer<TerminalAdviceHost> alive(this);
    if (d->values.value("provider_kind") == "package") retire(QStringLiteral("模型插件宿主已更换，旧请求与建议已撤销"), true);
    if (!alive) return;
    if (d->packages) disconnect(d->packages, nullptr, this, nullptr);
    d->packages = runtime;
    if (runtime) {
        connect(runtime, &PluginPackageRuntime::changed, this, &TerminalAdviceHost::refreshProviders);
        connect(runtime, &QObject::destroyed, this, [this] {
            if (d->values.value("provider_kind") == "package") retire(QStringLiteral("模型插件宿主已离线，旧建议已撤销"), true);
            else emit changed();
        });
    }
    refreshProviders();
}
void TerminalAdviceHost::refreshProviders() {
    if (QThread::currentThread() != thread()) return;
    d->builtinProviderCounts.clear();
    if (d->plugins) for (const auto &entry : PluginHost::discover(d->directory)) {
        const auto row = entry.toMap(); const auto id = row.value("id").toString();
        if ((id == "decision.http" || id == "decision.codex") && row.value("role") == "decision" &&
            row.value("contract") == QLatin1String(ExtensionPlugin_iid)) ++d->builtinProviderCounts[id];
    }
    synchronizeProviders();
}
void TerminalAdviceHost::synchronizeProviders() {
    if (d->values.value("provider_kind") == "package" && (d->enabled || d->endpoint) &&
        packageProvider(d->values.value("provider_options").toMap(), true).isEmpty()) {
        retire(QStringLiteral("模型插件已停用或审核配置改变；请赛外重新选择，未自动切换模型"), true);
        return;
    }
    emit changed();
}
bool TerminalAdviceHost::editable() const { return lockReason().isEmpty(); }
QString TerminalAdviceHost::lockReason() const {
    if (d->changing) return QStringLiteral("正在提交模型与策略配置");
    if (!d->season) return QStringLiteral("赛季宿主不可用");
    return d->season->lockReason();
}
QString TerminalAdviceHost::status() const { return d->status; }
bool TerminalAdviceHost::active() const {
    if (!d->enabled || !d->endpoint) return false;
    const auto provider = d->endpoint->details();
    return yes(provider, "active") && (d->values.value("provider_kind") != "package" ||
        (yes(provider, "provider_active") && !packageProvider(d->values.value("provider_options").toMap(), true).isEmpty()));
}
QVariantMap TerminalAdviceHost::details() const {
    const auto reported = d->endpoint ? d->endpoint->details() : QVariantMap{};
    auto provider = reported;
    provider["fully_local_verified"] = false; provider["competition_adapter_certified"] = false;
    provider["official_adapter_bound"] = false; provider["automatic_actions_allowed"] = false;
    provider["inference_location"] = "unknown";
    bool available = false;
    if (d->values.value("provider_kind") == "package") available = !packageProvider(d->values.value("provider_options").toMap(), true).isEmpty();
    else if (d->factory) available = true;
    else if (d->plugins) {
        const auto selected = d->values.value("provider_kind") == "codex" ? QStringLiteral("decision.codex") : QStringLiteral("decision.http");
        available = d->builtinProviderCounts.value(selected) == 1;
    }
    QString inputReason; const auto input = capture(&inputReason);
    return {{"active", active()}, {"busy", !d->requestId.isEmpty()}, {"configuration_valid", d->valid},
        {"configuration_revision", qulonglong(d->revision)}, {"provider_kind", d->values.value("provider_kind")},
        {"model", d->values.value("provider_options").toMap().value("model")}, {"provider", provider},
        {"provider_reported", reported}, {"provider_available", available}, {"provider_identity", d->providerIdentity},
        {"input_mode", d->values.value("input_mode")}, {"strategy_id", d->values.value("strategy_id")},
        {"input_ready", !input.isEmpty()}, {"input_block_reason", inputReason}, {"auto_advice", d->values.value("auto_advice")},
        {"voice_enabled", d->values.value("voice_enabled")}, {"competition_adapter_certified", false},
        {"automatic_actions_allowed", false}, {"official_adapter_bound", false}, {"fully_local_verified", false}};
}
QVariantMap TerminalAdviceHost::inputTrace() const {
    auto result = d->trace;
    if (!result.isEmpty()) {
        result["snapshot_age_ms"] = qMax<qint64>(0, d->clock.elapsed() - d->captureTick);
        result["remaining_ms"] = qMax<qint64>(0, d->inputDeadline - d->clock.elapsed());
        result["input_revision_current"] = evidenceCurrent();
    }
    return result;
}
QVariantMap TerminalAdviceHost::advice() const {
    if (d->result.isEmpty() || d->clock.elapsed() >= d->adviceDeadline || !evidenceCurrent()) return {};
    auto result = d->result;
    result["remaining_ms"] = qMax<qint64>(0, std::min(d->adviceDeadline, d->inputDeadline) - d->clock.elapsed());
    result["received_age_ms"] = qMax<qint64>(0, d->clock.elapsed() - d->completedTick);
    return result;
}
bool TerminalAdviceHost::reject(const QString &reason) { d->status = reason.left(500); emit changed(); return false; }
void TerminalAdviceHost::load() {
    d->values = defaults(); d->valid = true;
    if (!d->season || !yes(d->season->context(), "configuration_valid")) {
        d->valid = false; d->status = QStringLiteral("规则范围无效，未启用模型"); return;
    }
    QVariantList profiles; QVariantMap selected; QString error;
    if (!readSettings(d->file, &profiles, &selected, &error)) { d->valid = false; d->status = error; return; }
    const auto ctx = rulesContext(d->season);
    if (!selected.isEmpty()) {
        for (const auto &entry : profiles) {
            const auto row = entry.toMap(), scope = row.value("scope").toMap();
            if (scope == selected && scope.value("profile_id") == ctx.value("profile_id") &&
                scope.value("field_profile_id") == ctx.value("field_profile_id") &&
                scope.value("capability_revision") == ctx.value("capability_revision") &&
                scope.value("environment") == d->season->environment()) d->values = row.value("values").toMap();
        }
    }
    d->status = QStringLiteral("模型策略已载入／等待赛前配置；不会自动启用或发送请求");
}
bool TerminalAdviceHost::save(const QVariantMap &input) {
    if (QThread::currentThread() != thread()) return false;
    const auto locked = lockReason(); if (!locked.isEmpty()) return reject(locked);
    auto values = input;
    if (values.value("provider_kind") == "package") {
        auto options = values.value("provider_options").toMap();
        QSet<QString> keys;
        const auto shape = providerDefaults("package");
        for (auto it = shape.cbegin(); it != shape.cend(); ++it) keys.insert(it.key());
        if (values.value("provider_options").metaType().id() != QMetaType::QVariantMap || !exact(options, keys) || !packageLocator(options))
            return reject(QStringLiteral("插件模型配置只接受明确包／服务标识和有界公共模型参数"));
        const auto provider = packageProvider(options, false);
        if (!provider.isEmpty()) {
            // Saving is an explicit review; the host, not QML, chooses the
            // current active factory's artifact/configuration fingerprints.
            options["package_fingerprint"] = provider.value("package_fingerprint");
            options["configuration_fingerprint"] = provider.value("configuration_fingerprint");
        } else if (d->values.value("provider_kind") != "package" ||
                   !samePackageIdentity(options, d->values.value("provider_options").toMap())) {
            return reject(QStringLiteral("新选模型插件尚未运行；原已保存的缺失模型可保留，但不能改成另一个未就绪来源"));
        }
        values["provider_options"] = options;
    }
    QString error;
    if (!validatePublic(values, &error) || !yes(d->season->context(), "configuration_valid"))
        return reject(error.isEmpty() ? QStringLiteral("规则范围无效") : error);
    if (d->file.isEmpty() || !QDir().mkpath(QFileInfo(d->file).absolutePath()) || QFileInfo(d->file).isSymLink())
        return reject(QStringLiteral("模型配置目录不可写或文件为符号链接；原配置保留"));
    QLockFile lock(d->file + ".lock");
    if (!lock.tryLock(0)) return reject(QStringLiteral("另一实例正在保存模型配置；原配置保留"));
    QVariantList profiles; QVariantMap selected;
    // Explicit save is the sole recovery operation for an unreadable/unknown
    // file. Mere loading, enabling or changing a scope never rewrites it.
    if (!readSettings(d->file, &profiles, &selected, &error)) profiles.clear();
    const auto scope = configurationScope(rulesContext(d->season), d->season->environment(), values);
    bool replaced = false;
    for (auto &entry : profiles) if (entry.toMap().value("scope").toMap() == scope) {
        entry = QVariantMap{{"scope", scope}, {"values", values}}; replaced = true; break;
    }
    if (!replaced) {
        if (profiles.size() >= 32) return reject(QStringLiteral("模型身份范围已满；未删除其他机器人的配置"));
        profiles.append(QVariantMap{{"scope", scope}, {"values", values}});
    }
    const auto bytes = compact(QVariantMap{{"schema", 1}, {"selected", scope}, {"profiles", profiles}});
    if (bytes.size() > SettingsLimit) return reject(QStringLiteral("完整模型配置超出128KiB；未截断范围"));
    QSaveFile output(d->file);
    if (!output.open(QIODevice::WriteOnly) || !output.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner) ||
        output.write(bytes) != bytes.size() || !output.commit()) return reject(QStringLiteral("模型配置原子提交失败；原配置保留"));
    d->changing = true; QPointer<TerminalAdviceHost> alive(this);
    retire(QStringLiteral("模型／策略已保存；旧请求已撤销，请明确启用"), true);
    if (!alive) return false;
    d->values = values; d->valid = true; ++d->revision; d->changing = false; d->eventHash.clear();
    emit changed(); return true;
}
bool TerminalAdviceHost::setEnabled(bool enabled) {
    if (QThread::currentThread() != thread()) return false;
    if (!enabled) { stop(); return true; }
    const auto locked = lockReason(); if (!locked.isEmpty()) return reject(locked);
    QString error;
    if (!d->valid || !validatePublic(d->values, &error)) return reject(QStringLiteral("先在赛外保存有效模型与策略配置"));
    if (!d->season || !yes(d->season->context(), "configuration_valid") || d->season->profileId() != "rmuc2027-regional-v1.0.0")
        return reject(QStringLiteral("仅接纳当前正式2027规则范围"));
    if (d->season->environment() != "training")
        return reject(QStringLiteral("比赛范围尚无经过认证的完全本地推理适配器；loopback／CLI不证明本地推理"));
    if (d->enabled && d->endpoint) return true;
    auto options = d->values.value("provider_options").toMap();
    const auto kind = d->values.value("provider_kind").toString();
    const auto expectedIdentity = kind == "package" ? packageProvider(options, true) : QVariantMap{};
    if (kind == "package" && expectedIdentity.isEmpty())
        return reject(QStringLiteral("已保存的模型插件缺失或内容／配置已改变；请赛外明确重新选择并保存，没有回退到其他模型"));
    if (kind == "http") {
        const auto env = options.take("key_env").toString(); const auto key = qgetenv(env.toLatin1().constData());
        if (key.size() > 4096 || key.contains('\r') || key.contains('\n') || key.contains('\0') ||
            (!localEndpoint(QUrl(options.value("endpoint").toString())) && key.trimmed().isEmpty()))
            return reject(QStringLiteral("API密钥环境变量未设置或无效；未启动请求"));
        options["key"] = key;
        // The existing adapter only accepts its provider-specific thinking
        // field for DeepSeek Chat. A false generic switch is omitted entirely.
        if (options.value("provider") != "deepseek" || options.value("api") != "chat") options.remove("thinking");
    }
    // A factory/start callback may synchronously stop this host, retire its
    // package or change the rules. Establish the transition before calling it.
    QPointer<TerminalAdviceHost> alive(this);
    const auto generation = ++d->generation;
    d->changing = true;
    const auto transition = qScopeGuard([this, alive] {
        if (alive && d->changing) { d->changing = false; emit changed(); }
    });
    const auto current = [this, alive, generation] { return alive && generation == d->generation; };
    const auto activationFailed = [this, current](const QString &reason) {
        if (!current()) return false;
        retire(reason.isEmpty() ? QStringLiteral("模型插件启用失败，未保留旧请求") : reason, true);
        return false;
    };
    ServiceEndpoint *created = nullptr;
    QVariantMap identity;
    if (kind == "package") {
        created = d->packages->createProviderService(options.value("package_id").toString(), options.value("service_name").toString(),
            "decision", "terminal.decision@1", &error, &identity);
        // Package-specific URLs, credentials and executable choices stay in
        // its reviewed manifest configuration, outside this common contract.
        options = {{"model", options.value("model")}, {"timeout_ms", options.value("timeout_ms")},
            {"max_output_tokens", options.value("max_output_tokens")}};
    } else {
        const auto pluginId = kind == "codex" ? QStringLiteral("decision.codex") : QStringLiteral("decision.http");
        if (d->factory) created = d->factory(pluginId, &error);
        else if (d->plugins) {
            auto *plugin = d->plugins->loadExtension(d->directory, pluginId, "decision", &error);
            if (!current()) return false;
            if (plugin && plugin->id() == pluginId && plugin->role() == "decision") created = plugin->createService();
        }
    }
    if (!created) return activationFailed(error.isEmpty() ? QStringLiteral("可选模型插件不存在；本机与其他插件继续运行") : error);
    if (created->thread() != QThread::currentThread()) {
        created->deleteLater(); return activationFailed(QStringLiteral("模型服务不在宿主线程，未启用"));
    }
    auto endpoint = own(created);
    if (!current()) { endpoint->stop(); return false; }
    if (kind == "package" && identity != expectedIdentity) {
        endpoint->stop(); return activationFailed(QStringLiteral("模型工厂在创建期间改变，未启用未审核来源"));
    }
    d->endpoint = endpoint; d->providerIdentity = identity;
    connect(created, &ServiceEndpoint::messageReceived, this, [this, generation](const QVariantMap &message) { receive(generation, message); });
    connect(created, &ServiceEndpoint::statusChanged, this, [this, generation] {
        if (generation != d->generation) return;
        const auto endpoint = d->endpoint;
        if (!endpoint) return;
        QPointer<TerminalAdviceHost> alive(this);
        const auto status = endpoint->details();
        if (!alive || generation != d->generation) return;
        const bool revoked = d->values.value("provider_kind") == "package" && !yes(status, "provider_active");
        if (revoked || (!d->changing && !yes(status, "active"))) retire(QStringLiteral("模型服务失联／停用，已撤销请求、建议与播报"), true);
        else emit changed();
    });
    connect(created, &ServiceEndpoint::errorOccurred, this, [this, generation](const QString &) {
        if (generation == d->generation) retire(QStringLiteral("模型服务发生错误；旧建议已撤销"), d->changing);
    });
    const bool started = endpoint->start(options, &error);
    if (!current()) { endpoint->stop(); return false; }
    const auto startedDetails = endpoint->details();
    if (!current()) { endpoint->stop(); return false; }
    if (!started || !yes(startedDetails, "active") || (kind == "package" &&
        (!yes(startedDetails, "provider_active") || packageProvider(d->values.value("provider_options").toMap(), true) != expectedIdentity)))
        return activationFailed(error.isEmpty() ? QStringLiteral("模型未进入有效运行状态，未保留请求") : error);
    d->enabled = true; d->changing = false;
    d->status = QStringLiteral("训练模型已配置；只使用明确授权的新鲜本机数据／经核验完整队伍截面");
    d->timer.start(); emit changed(); return alive && generation == d->generation;
}

QVariantMap TerminalAdviceHost::capture(QString *error) const {
    if (!d->valid || !d->season || !yes(d->season->context(), "configuration_valid") ||
        d->season->profileId() != "rmuc2027-regional-v1.0.0" || d->season->environment() != "training") {
        fail(error, "当前规则／用途未允许此模型输入"); return {};
    }
    const auto ctx = rulesContext(d->season), values = d->values;
    const auto selected = values.value("selected_fields").toList();
    if (selected.isEmpty()) { fail(error, "未逐项选择并授权模型输入字段"); return {}; }
    const bool team = values.value("input_mode") == "team";
    QVariantMap view;
    if (team) {
        if (!d->team || !d->team->active()) { fail(error, "队伍插件不可用；队伍模式不会静默改用本机数据"); return {}; }
        view = d->team->teamView();
        if (!yes(view, "source_proofs_verified") || !yes(view, "publisher_proof_verified") ||
            !yes(view, "clock_sync_verified") || !yes(view, "channel_connected") || view.value("context").toMap() != ctx ||
            view.value("team_id") != values.value("team_id") || !id(view.value("view_id"), 128)) {
            fail(error, "队伍截面须独立核验发布者、原始来源和时钟映射；当前未达到AI接纳条件"); return {};
        }
    } else {
        if (!d->bus) { fail(error, "本机数据总线不可用"); return {}; }
        view = d->bus->view();
        if (view.value("kind") != "terminal-data-view" || view.value("context").toMap() != ctx) {
            fail(error, "本机数据范围不匹配"); return {};
        }
    }
    // Built-in and package providers may infer outside the room even when a
    // transport uses loopback or a local CLI. No self-report grants locality.
    const QString purpose = QStringLiteral("externalAi");
    QVariantList items, identities, inputRecords; qint64 lifetime = 60000;
    QSet<QString> matched;
    for (const auto &requested : selected) {
        const auto grant = requested.toMap(); const auto key = fieldKey(grant, values);
        if (!grant.value("uses").toList().contains(purpose)) { fail(error, "此模型推理位置未经核验，所选每项均需明确externalAi授权"); return {}; }
        QVariantMap found; int matches = 0;
        for (const auto &entry : view.value("items").toList()) {
            const auto row = entry.toMap();
            if (row.value("team_id") == values.value("team_id") &&
                row.value("robot_key") == grant.value("robot_key", values.value("robot_key")) &&
                row.value("source_id") == grant.value("source_id") && row.value("item_id") == grant.value("item_id") &&
                row.value("state") == "fresh") { found = row; ++matches; }
        }
        qint64 remaining = 0, ttl = 0, age = 0;
        const auto kind = found.value("source_kind").toString();
        QString reason;
        if (matches != 1 || !integer(found.value("schema"), 3, 3) || found.value("context").toMap() != ctx ||
            found.value("lifecycle") != "active" || found.value("clock_domain") != "host_utc" ||
            !integer(found.value("remaining_ms"), 1, 60000, &remaining) || !integer(found.value("ttl_ms"), 100, 60000, &ttl) || remaining > ttl ||
            found.value("mock").metaType().id() != QMetaType::Bool || found.value("mock").toBool() ||
            found.value("source_id").toString().startsWith("mock.") ||
            (kind != "local_sensor" && kind != "local_vision" && kind != "derived") ||
            !TerminalDataBus::validateObservation(raw(found), ctx, false, &reason)) {
            fail(error, QStringLiteral("所选字段缺失、重复、过期、未核验时钟或为mock：%1/%2").arg(grant.value("source_id").toString(), grant.value("item_id").toString())); return {};
        }
        if (team) {
            if (!yes(found, "host_source_proof_verified") || !yes(found, "clock_sync_verified") || !found.value("allowed_uses").toList().contains(purpose) ||
                !id(found.value("source_proof_ref"), 128)) { fail(error, "队友字段未通过宿主来源、时钟及用途接纳"); return {}; }
        } else if (!yes(found, "clock_checked") || !integer(found.value("age_ms"), 0, 60000, &age) || age > ttl || remaining > ttl - age) {
            fail(error, "本机字段主机时钟寿命检查未通过；不能把接收时间充当新测量"); return {};
        }
        QVariantMap identity{{"robot_key", found.value("robot_key")}, {"source_id", found.value("source_id")},
            {"session_id", found.value("session_id")}, {"sequence", found.value("sequence")}, {"item_id", found.value("item_id")},
            {"observation_hash", digest(raw(found))}};
        if (team) { identity["source_node"] = found.value("source_node"); identity["source_proof_ref"] = found.value("source_proof_ref"); }
        auto record = identity;
        for (const auto &key : {"sensor_id", "source_kind", "produced_at_ms", "received_at_ms", "clock_domain", "ttl_ms", "confidence", "validation"})
            record[QLatin1String(key)] = found.value(QLatin1String(key));
        record["remaining_ms_at_capture"] = remaining;
        record["received_age_ms_at_capture"] = found.value("received_age_ms");
        record["time_basis"] = team ? QStringLiteral("host_verified_team_mapping") : QStringLiteral("native_bus_host_utc_observed");
        record["measurement_verified"] = false; inputRecords.append(record);
        auto item = raw(found); item["freshness"] = "fresh"; item["remaining_ms_at_capture"] = remaining;
        item["measurement_verified"] = false; item["authoritative"] = false;
        item["time_basis"] = team ? QStringLiteral("host_verified_team_mapping") : QStringLiteral("native_bus_host_utc_observed");
        if (team) { item["source_node"] = found.value("source_node"); item["source_proof_ref"] = found.value("source_proof_ref"); }
        else if (found.contains("source_provenance")) item["source_provenance"] = found.value("source_provenance");
        else if (found.contains("transport_provenance")) item["transport_provenance"] = found.value("transport_provenance");
        items.append(item); identities.append(identity); lifetime = std::min(lifetime, remaining); matched.insert(key);
    }
    if (matched.size() != selected.size() || lifetime < 500) { fail(error, "完整输入寿命不足500ms，未请求模型"); return {}; }
    QVariantMap result{{"schema", 3}, {"kind", "terminal-advice-input"}, {"context", ctx},
        {"environment", d->season->environment()}, {"team_id", values.value("team_id")}, {"robot_key", values.value("robot_key")},
        {"input_mode", values.value("input_mode")}, {"items", items}, {"input_identities", identities}, {"input_records", inputRecords},
        {"valid_for_ms", lifetime}, {"automatic_actions_allowed", false}, {"mock", false},
        {"strategy", QVariantMap{{"id", values.value("strategy_id")}, {"description", strategyDescription(values.value("strategy_id").toString())},
                                  {"operator_preference", values.value("strategy_text")}}}};
    if (team) { result["view_id"] = view.value("view_id"); result["view_revision"] = view.value("revision"); result["publisher_id"] = view.value("publisher_id"); }
    if (compact(result).size() > InputLimit) { fail(error, "完整授权输入超过40KiB；未部分截断或发送"); return {}; }
    result["evidence_hash"] = digest(QVariantMap{{"context", ctx}, {"identities", identities}, {"strategy", result.value("strategy")},
        {"input_mode", result.value("input_mode")}, {"view_id", result.value("view_id")}});
    return result;
}
bool TerminalAdviceHost::evidenceCurrent() const {
    if (!active() || d->captured.isEmpty() ||
        d->clock.elapsed() >= d->inputDeadline || QDateTime::currentMSecsSinceEpoch() < d->captureUtc ||
        std::abs((QDateTime::currentMSecsSinceEpoch() - d->captureUtc) - (d->clock.elapsed() - d->captureTick)) > 250) return false;
    const auto latest = capture(nullptr);
    return !latest.isEmpty() && latest.value("evidence_hash") == d->evidenceHash;
}
bool TerminalAdviceHost::request(const QString &question) { return dispatch(question, false); }
bool TerminalAdviceHost::dispatch(const QString &question, bool automatic) {
    if (QThread::currentThread() != thread()) return false;
    if (!automatic && !editable()) return reject(QStringLiteral("比赛中模型与策略只读；手动关注点须在赛外保存"));
    if (!text(question, 500, true)) return reject(QStringLiteral("模型关注点须为不超过500字符的单行文本"));
    if (d->dispatching || !active() || !d->requestId.isEmpty() || yes(d->endpoint->details(), "busy"))
        return reject(QStringLiteral("模型未启用或已有在途请求"));
    const auto now = d->clock.elapsed();
    if (now - d->lastRequest < d->values.value("minimum_interval_ms").toLongLong()) return reject(QStringLiteral("模型请求已按赛前设置节流"));
    QString error; const auto captured = capture(&error);
    if (captured.isEmpty()) return reject(error);
    const auto retiredVoice = d->result.value("request_id").toString();
    d->captureTick = now; d->captureUtc = QDateTime::currentMSecsSinceEpoch();
    d->inputDeadline = now + captured.value("valid_for_ms").toLongLong();
    d->captured = captured; d->evidenceHash = captured.value("evidence_hash").toString(); d->eventHash = d->evidenceHash;
    d->requestId = QUuid::createUuid().toString(QUuid::WithoutBraces); d->lastRequest = now;
    const auto requestId = d->requestId; const auto generation = d->generation; auto endpoint = d->endpoint;
    d->result.clear(); d->adviceDeadline = 0;
    auto payload = captured; payload["request_id"] = requestId; payload["snapshot_id"] = requestId + ".input";
    payload["captured_at_ms"] = d->captureUtc;
    d->trace = {{"request_id", requestId}, {"snapshot_id", payload.value("snapshot_id")}, {"evidence_hash", d->evidenceHash},
        {"input_identities", captured.value("input_identities")}, {"input_records", captured.value("input_records")}, {"input_mode", captured.value("input_mode")},
        {"context", captured.value("context")}, {"team_id", captured.value("team_id")}, {"robot_key", captured.value("robot_key")},
        {"strategy_id", d->values.value("strategy_id")}, {"provider_kind", d->values.value("provider_kind")},
        {"provider_identity", d->providerIdentity},
        {"model", d->values.value("provider_options").toMap().value("model")}, {"captured_at_ms", d->captureUtc},
        {"configuration_revision", qulonglong(d->revision)}, {"measurement_verified", false}, {"official_adapter_bound", false}};
    d->dispatching = true; d->status = QStringLiteral("正在分析新鲜授权输入；不触发机器人动作");
    QPointer<TerminalAdviceHost> alive(this);
    if (!retiredVoice.isEmpty()) { emit voiceCancelled(retiredVoice); if (!alive || generation != d->generation) return false; }
    emit changed();
    if (!alive || generation != d->generation || requestId != d->requestId) return false;
    const bool accepted = endpoint->submit({{"schema", 1}, {"kind", "decision-request"}, {"request_id", requestId},
        {"payload", payload}, {"question", question}}, &error);
    if (!alive || generation != d->generation) return false;
    d->dispatching = false;
    if (!accepted && d->requestId == requestId) { d->requestId.clear(); d->captured.clear(); return reject(error.isEmpty() ? QStringLiteral("模型插件未接纳请求") : error); }
    return accepted;
}
void TerminalAdviceHost::receive(quint64 generation, const QVariantMap &message) {
    if (generation != d->generation || d->requestId.isEmpty() || message.value("request_id") != d->requestId ||
        !integer(message.value("schema"), 1, 1)) return;
    const auto kind = message.value("kind").toString();
    if (kind != "advice" && kind != "decision-error") return;
    const auto requestId = std::exchange(d->requestId, QString{});
    if (kind == "decision-error") { d->result.clear(); reject(QStringLiteral("模型请求失败／超时，未生成有效建议")); return; }
    if (!evidenceCurrent() || message.value("payload").metaType().id() != QMetaType::QVariantMap) {
        d->result.clear(); reject(QStringLiteral("输入已过期、撤回或被更新；已丢弃迟到建议")); return;
    }
    const auto payload = message.value("payload").toMap(); QString error;
    if (!exact(payload, {"summary", "rationale", "priority", "focus", "expires_in_ms"}) ||
        !text(payload.value("summary"), 180) || !text(payload.value("rationale"), 500, true) ||
        !text(payload.value("priority"), 16) || !text(payload.value("focus"), 16) ||
        !integer(payload.value("expires_in_ms"), 500, 10000) ||
        !AdviceContract::validate(QJsonObject::fromVariantMap(payload), &error)) {
        d->result.clear(); reject(QStringLiteral("模型输出未通过建议结构／文字契约；已丢弃")); return;
    }
    const auto now = d->clock.elapsed();
    d->completedTick = now; d->adviceDeadline = std::min(d->inputDeadline, now + payload.value("expires_in_ms").toLongLong());
    if (d->adviceDeadline <= now) { reject(QStringLiteral("建议到达时输入已失效")); return; }
    d->result = payload; d->result["request_id"] = requestId; d->result["fresh"] = true;
    d->result["source"] = "terminal-advice-host"; d->result["input_mode"] = d->values.value("input_mode");
    d->result["input_trace"] = d->trace; d->result["received_at_ms"] = QDateTime::currentMSecsSinceEpoch();
    d->result["received_tick_ms"] = PacketObservation::steadyMilliseconds();
    d->result["expires_at_tick_ms"] = d->result.value("received_tick_ms").toLongLong() + d->adviceDeadline - now;
    d->result["context"] = d->trace.value("context"); d->result["snapshot_id"] = d->trace.value("snapshot_id");
    d->result["source_mode"] = d->values.value("input_mode"); d->result["voice_scope"] = "local_only";
    d->result["measurement_verified"] = false; d->result["automatic_actions_allowed"] = false;
    d->status = QStringLiteral("建议有效；依据、来源与剩余寿命可追溯，操作仍由用户确认");
    QPointer<TerminalAdviceHost> alive(this); emit changed();
    if (alive && generation == d->generation && yes(d->values, "voice_enabled")) {
        const auto valid = advice();
        if (!valid.isEmpty() && valid.value("request_id") == requestId) emit voiceRequested(valid);
    }
}
void TerminalAdviceHost::retire(const QString &reason, bool disable) {
    const auto oldId = d->trace.value("request_id").toString();
    d->requestId.clear(); d->captured.clear(); d->result.clear(); d->inputDeadline = d->adviceDeadline = 0; d->dispatching = false;
    auto endpoint = d->endpoint;
    if (disable) { ++d->generation; d->enabled = false; d->timer.stop(); d->endpoint.reset(); d->providerIdentity.clear(); }
    d->status = reason;
    QPointer<TerminalAdviceHost> alive(this);
    if (endpoint) {
        if (disable) { endpoint->disconnect(this); endpoint->stop(); }
        else { QString error; endpoint->submit({{"schema", 1}, {"kind", "cancel"}}, &error); }
    }
    if (!alive) return;
    if (!oldId.isEmpty()) { emit voiceCancelled(oldId); if (!alive) return; }
    emit changed();
}
void TerminalAdviceHost::cancel() { if (QThread::currentThread() == thread()) retire(QStringLiteral("已取消当前建议／播报；旧响应不会恢复"), false); }
void TerminalAdviceHost::stop() { if (QThread::currentThread() == thread()) retire(QStringLiteral("模型已停用；本机数据、共享与操作功能独立运行"), true); }
void TerminalAdviceHost::tick() {
    if (!d->enabled || d->changing || d->dispatching) return;
    QPointer<TerminalAdviceHost> alive(this);
    if ((!d->requestId.isEmpty() || !d->result.isEmpty()) &&
        (!evidenceCurrent() || (!d->result.isEmpty() && d->clock.elapsed() >= d->adviceDeadline))) {
        retire(QStringLiteral("建议／输入已过期、被替换或来源离线；HUD已隐藏"), false);
        if (!alive || !d->enabled) return;
    }
    if (!d->trace.isEmpty() && d->clock.elapsed() - d->lastProjection >= 250) {
        // QML bindings need a bounded clock notification even when canonical
        // identities have not changed; this never renews a request or TTL.
        d->lastProjection = d->clock.elapsed(); emit changed();
        if (!alive || !d->enabled) return;
    }
    if (!yes(d->values, "auto_advice") || !active() || !d->requestId.isEmpty() || yes(d->endpoint->details(), "busy") ||
        d->clock.elapsed() - d->lastRequest < d->values.value("minimum_interval_ms").toLongLong()) return;
    QString error; const auto latest = capture(&error);
    if (latest.isEmpty()) { if (d->status != error) reject(error); return; }
    if (d->values.value("trigger") == "event" && latest.value("evidence_hash") == d->eventHash) return;
    dispatch({}, true);
}
