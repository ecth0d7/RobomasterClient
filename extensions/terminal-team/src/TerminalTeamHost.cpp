#include "TerminalTeamHost.h"
#include "TerminalDataBus.h"
#include "SeasonConfiguration.h"
#include "RulesetCatalog.h"
#include "PluginHost.h"
#include "PluginPackageRuntime.h"
#include "PacketObservation.h"
#include "TerminalTeamContract.h"
#include "TerminalTeamProofVerifier.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLockFile>
#include <QMap>
#include <QPointer>
#include <QRegularExpression>
#include <QScopeGuard>
#include <QThread>
#include <QSaveFile>
#include <QSet>
#include <QTimer>
#include <algorithm>
#include <cmath>

namespace {
constexpr int SettingsBytes = 128 * 1024, LeaseBytes = 32 * 1024;
constexpr qint64 Safe = 9007199254740991LL;
const QString PluginId = QStringLiteral("terminal.team.aggregate.v3");
const QString ProviderRole = QStringLiteral("terminal-team");
const QString ProviderContract = QStringLiteral("terminal.team@3");
const QSet<QString> RawKeys{"schema", "context", "team_id", "robot_key", "source_id", "sensor_id", "source_kind",
    "session_id", "sequence", "item_id", "produced_at_ms", "clock_domain", "ttl_ms", "confidence", "validation",
    "lifecycle", "data_type", "value", "unit", "frame_id", "frame_revision", "transform_id"};

bool fail(QString *error, const QString &message) { if (error) *error = message; return false; }
QByteArray compact(const QVariant &value) { return QJsonDocument::fromVariant(value).toJson(QJsonDocument::Compact); }
QString digest(const QVariant &value) {
    return QString::fromLatin1(QCryptographicHash::hash(compact(value), QCryptographicHash::Sha256).toHex());
}
bool integer(const QVariant &value, qint64 low, qint64 high, qint64 *out = nullptr) {
    const auto type = value.metaType().id();
    if (type != QMetaType::Int && type != QMetaType::UInt && type != QMetaType::LongLong &&
        type != QMetaType::ULongLong && type != QMetaType::Double) return false;
    const double n = value.toDouble();
    if (!std::isfinite(n) || std::floor(n) != n || n < double(low) || n > double(high)) return false;
    if (out) *out = qint64(n);
    return true;
}
bool text(const QVariant &value, int maximum, bool empty = false) {
    if (value.metaType().id() != QMetaType::QString || value.toString().size() > maximum ||
        (!empty && value.toString().isEmpty())) return false;
    for (const auto ch : value.toString())
        if (ch.isNull() || ch.category() == QChar::Other_Control || ch.category() == QChar::Separator_Line ||
            ch.category() == QChar::Separator_Paragraph) return false;
    return true;
}
bool exact(const QVariantMap &map, const QSet<QString> &keys) {
    if (map.size() != keys.size()) return false;
    for (auto it = map.cbegin(); it != map.cend(); ++it) if (!keys.contains(it.key())) return false;
    return true;
}
bool bounded(const QVariant &value, int depth = 0, int *count = nullptr, qsizetype *cost = nullptr) {
    int localCount = 0; qsizetype localCost = 0;
    if (!count) count = &localCount;
    if (!cost) cost = &localCost;
    if (++*count > 65536 || depth > 10 || *cost > 2 * 1024 * 1024) return false;
    if (!value.isValid() || value.isNull()) { *cost += 4; return true; }
    const auto type = value.metaType().id();
    if (type == QMetaType::QVariantMap) {
        const auto map = value.toMap();
        if (map.size() > 512) return false;
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            if (!text(it.key(), 128)) return false;
            *cost += it.key().size() * 2 + 4;
            if (!bounded(it.value(), depth + 1, count, cost)) return false;
        }
    } else if (type == QMetaType::QVariantList) {
        const auto list = value.toList();
        if (list.size() > 512) return false;
        for (const auto &entry : list) if (!bounded(entry, depth + 1, count, cost)) return false;
    } else if (type == QMetaType::QString) {
        if (!text(value, 768 * 1024, true)) return false;
        *cost += value.toString().size() * 2 + 2;
    } else if (type == QMetaType::Bool) *cost += 5;
    else {
        if (!integer(value, -Safe, Safe) &&
            ((type != QMetaType::Double && type != QMetaType::Float) || !std::isfinite(value.toDouble()))) return false;
        *cost += 24;
    }
    return *cost <= 2 * 1024 * 1024;
}
QVariantMap context(const SeasonConfiguration *season) {
    if (!season) return {};
    const auto current = season->current();
    return {{"profile_id", season->profileId()}, {"field_profile_id", current.value("field_profile_id")},
            {"capability_revision", current.value("capability_revision")}};
}
QVariantMap defaults() {
    return {{"team_id", ""}, {"match_id", ""}, {"epoch", ""}, {"node_id", ""}, {"robot_key", ""},
        {"publisher_id", ""}, {"can_send", false}, {"can_aggregate", false},
        {"allowed_fields", QVariantList{}}, {"allowed_uses", QVariantList{}}, {"clocks_synchronized", false},
        {"max_clock_skew_ms", 250}, {"heartbeat_ms", 1000}, {"timeout_ms", 3000}, {"training_mock", false},
        {"team_wide_sharing_confirmed", false}, {"endpoint", ""}, {"ca_file", ""}, {"certificate_file", ""},
        {"signing_key_file_env", "ROBOMASTER_TERMINAL_TEAM_SIGNING_KEY_FILE"}, {"peers", QVariantList{}}};
}
bool environmentName(const QVariant &value) {
    if (!text(value, 96)) return false;
    const auto name = value.toString();
    if (!((name[0] >= 'A' && name[0] <= 'Z') || (name[0] >= 'a' && name[0] <= 'z') || name[0] == '_')) return false;
    for (const auto c : name)
        if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_')) return false;
    return true;
}
bool semanticRobot(const QString &value, const QString &profileId) {
    const auto parts = value.split('/');
    if (parts.size() != 3 || (parts[0] != "red" && parts[0] != "blue") || parts[2].isEmpty() ||
        parts[2][0] < '1' || parts[2][0] > '9') return false;
    for (const auto c : parts[2]) if (c < '0' || c > '9') return false;
    bool ok = false;
    const auto slot = parts[2].toInt(&ok);
    if (!ok) return false;
    for (const auto &entry : RulesetCatalog::profile(profileId).value("roster").toList()) {
        const auto row = entry.toMap();
        if (row.value("role_id") == parts[1]) return slot >= 1 && slot <= row.value("count").toInt();
    }
    return false;
}
QVariantMap scope(const QVariantMap &ctx, const QString &environment, const QVariantMap &values) {
    auto result = ctx;
    result["environment"] = environment;
    result["node_id"] = values.value("node_id");
    result["robot_key"] = values.value("robot_key");
    return result;
}
QVariantMap nativeConfig(const QVariantMap &values, const QVariantMap &ctx, const QString &file,
                         bool resolveKey, QString *error) {
    auto result = values;
    result.remove("signing_key_file_env");
    result["schema"] = 3;
    result["context"] = ctx;
    const auto directory = QFileInfo(file).absoluteDir();
    const auto path = [&directory](const QString &reference) {
        return reference.isEmpty() ? QString{} : QDir::cleanPath(directory.absoluteFilePath(reference));
    };
    for (const auto &key : {"ca_file", "certificate_file"}) result[QLatin1String(key)] = path(values.value(QLatin1String(key)).toString());
    QString keyPath = QStringLiteral("native-signing-key-reference-not-resolved");
    if (resolveKey) {
        const auto bytes = qgetenv(values.value("signing_key_file_env").toString().toLatin1().constData());
        keyPath = QString::fromLocal8Bit(bytes);
        if (!text(keyPath, 4096)) { fail(error, "签名密钥路径环境变量未设置或无效；未启用网络"); return {}; }
    }
    result["signing_key_file"] = path(keyPath);
    QVariantList peers;
    for (const auto &entry : values.value("peers").toList()) {
        auto peer = entry.toMap();
        peer["certificate_file"] = path(peer.value("certificate_file").toString());
        peers.append(peer);
    }
    result["peers"] = peers;
    return result;
}
bool validatePublic(const QVariantMap &values, const QVariantMap &ctx, const QString &environment,
                    const QString &file, QString *error) {
    QSet<QString> keys;
    const auto fields = defaults();
    for (auto it = fields.cbegin(); it != fields.cend(); ++it) keys.insert(it.key());
    if (!exact(values, keys) || !bounded(values) || compact(values).size() > SettingsBytes ||
        ctx.value("profile_id") != "rmuc2027-regional-v1.0.0" ||
        (environment != "training" && environment != "competition") || !environmentName(values.value("signing_key_file_env")))
        return fail(error, "共享配置字段、2027范围或密钥环境变量名无效；不能传入密钥路径或验证标记");
    if (!semanticRobot(values.value("robot_key").toString(), ctx.value("profile_id").toString()))
        return fail(error, "本机身份须为当前2027目录中的语义机器人键，如red/infantry/1；不是线路编号");
    for (const auto &entry : values.value("peers").toList())
        if (!semanticRobot(entry.toMap().value("robot_key").toString(), ctx.value("profile_id").toString()))
            return fail(error, "队友语义机器人不在当前2027阵容内");
    if (environment == "competition") {
        if (values.value("training_mock").toBool()) return fail(error, "比赛范围不允许共享mock样例");
        if (values.value("allowed_uses").toList().contains("externalAi"))
            return fail(error, "比赛共享不授权操作间外模型用途；训练配置单独保存");
        const auto forbidExternal = [](const QVariantList &grants) {
            for (const auto &entry : grants) if (entry.toMap().value("uses").toList().contains("externalAi")) return true;
            return false;
        };
        if (forbidExternal(values.value("allowed_fields").toList())) return fail(error, "比赛字段授权不能含externalAi");
        for (const auto &entry : values.value("peers").toList())
            if (forbidExternal(entry.toMap().value("allowed_fields").toList())) return fail(error, "比赛队友字段授权不能含externalAi");
    }
    const auto native = nativeConfig(values, ctx, file, false, error);
    return !native.isEmpty() && TerminalTeamContract::validateConfiguration(native, error);
}
bool atomicWrite(const QString &file, const QByteArray &bytes, QString *error) {
    if (QFileInfo(file).isSymLink()) return fail(error, "配置或轮次账本不能为符号链接；原文件保留");
    QSaveFile output(file);
    if (!output.open(QIODevice::WriteOnly) || !output.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner) ||
        output.write(bytes) != bytes.size() || !output.commit()) return fail(error, "配置提交失败，原文件保留");
    return true;
}
bool readSettings(const QString &file, QVariantList *profiles, QVariantMap *selected, QString *error) {
    profiles->clear(); selected->clear();
    if (QFileInfo(file).isSymLink()) return fail(error, "共享配置不能为符号链接，原文件保留");
    if (!QFileInfo::exists(file)) return true;
    QFile input(file);
    if (!input.open(QIODevice::ReadOnly)) return fail(error, "共享配置无法读取，未启用网络");
    const auto bytes = input.read(SettingsBytes + 1);
    QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(bytes, &parse);
    const auto map = document.toVariant().toMap();
    if (bytes.size() > SettingsBytes || parse.error != QJsonParseError::NoError || !document.isObject() ||
        !exact(map, {"schema", "selected", "profiles"}) || !integer(map.value("schema"), 1, 1) ||
        map.value("selected").metaType().id() != QMetaType::QVariantMap ||
        map.value("profiles").metaType().id() != QMetaType::QVariantList || map.value("profiles").toList().size() > 32)
        return fail(error, "共享配置损坏或版本未知；原文件保留，不自动重置");
    QSet<QString> seen;
    for (const auto &entry : map.value("profiles").toList()) {
        const auto record = entry.toMap(), savedScope = record.value("scope").toMap();
        if (entry.metaType().id() != QMetaType::QVariantMap || !exact(record, {"scope", "values"}) ||
            !exact(savedScope, {"profile_id", "field_profile_id", "capability_revision", "environment", "node_id", "robot_key"}) ||
            record.value("values").metaType().id() != QMetaType::QVariantMap) return fail(error, "共享范围记录无效；原文件保留");
        const QVariantMap ctx{{"profile_id", savedScope.value("profile_id")}, {"field_profile_id", savedScope.value("field_profile_id")},
                              {"capability_revision", savedScope.value("capability_revision")}};
        const auto values = record.value("values").toMap();
        if (savedScope.value("node_id") != values.value("node_id") || savedScope.value("robot_key") != values.value("robot_key") ||
            !validatePublic(values, ctx, savedScope.value("environment").toString(), file, error) || seen.contains(digest(savedScope)))
            return fail(error, "共享配置含无效、重复或错误版本的身份范围；原文件保留");
        seen.insert(digest(savedScope));
        profiles->append(record);
    }
    *selected = map.value("selected").toMap();
    if (!selected->isEmpty() && !seen.contains(digest(*selected)))
        return fail(error, "共享配置的选中身份不存在，原文件保留");
    return true;
}
bool consumeEpoch(const QString &settingsFile, const QVariantMap &values, QString *error) {
    const auto file = settingsFile + ".epochs.json";
    if (!QDir().mkpath(QFileInfo(file).absolutePath())) return fail(error, "共享轮次账本目录不可写");
    QLockFile lock(file + ".lock");
    if (!lock.tryLock(0)) return fail(error, "共享轮次账本被另一实例占用");
    if (QFileInfo(file).isSymLink()) return fail(error, "共享轮次账本不能为符号链接");
    QVariantList used;
    if (QFileInfo::exists(file)) {
        QFile input(file);
        if (!input.open(QIODevice::ReadOnly)) return fail(error, "共享轮次账本无法读取");
        const auto bytes = input.read(LeaseBytes + 1);
        QJsonParseError parse;
        const auto doc = QJsonDocument::fromJson(bytes, &parse);
        const auto map = doc.toVariant().toMap();
        if (bytes.size() > LeaseBytes || parse.error != QJsonParseError::NoError || !doc.isObject() ||
            !exact(map, {"schema", "used"}) || !integer(map.value("schema"), 1, 1) ||
            map.value("used").metaType().id() != QMetaType::QVariantList || map.value("used").toList().size() > 256)
            return fail(error, "共享轮次账本损坏；原文件保留，不启用网络");
        used = map.value("used").toList(); QSet<QString> seen;
        for (const auto &entry : used) {
            const auto hash = entry.toString();
            if (entry.metaType().id() != QMetaType::QString || hash.size() != 64 || seen.contains(hash))
                return fail(error, "共享轮次账本含无效或重复条目");
            for (const auto c : hash) if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')))
                return fail(error, "共享轮次账本摘要无效");
            seen.insert(hash);
        }
    }
    const auto lease = digest(QVariantList{values.value("team_id"), values.value("match_id"), values.value("epoch"), values.value("node_id")});
    if (used.contains(lease)) return fail(error, "该队伍／比赛／轮次／节点已使用；停用或重启后须约定新的共享轮次");
    if (used.size() >= 256) return fail(error, "共享轮次账本已满，未删除历史；请显式维护或更换独立实例配置");
    used.append(lease);
    const auto bytes = compact(QVariantMap{{"schema", 1}, {"used", used}});
    return bytes.size() <= LeaseBytes ? atomicWrite(file, bytes, error) : fail(error, "共享轮次账本超出容量");
}
QVariantMap raw(const QVariantMap &row) {
    QVariantMap result;
    for (auto it = row.cbegin(); it != row.cend(); ++it) if (RawKeys.contains(it.key())) result[it.key()] = it.value();
    return result;
}
QString itemKey(const QVariantMap &row) {
    return digest(QVariantList{row.value("source_node"), row.value("node_session_id"), row.value("source_id"),
        row.value("session_id"), row.value("item_id")});
}
bool projectionUses(const QVariant &value, const QVariantList &original, QVariantList *result) {
    static const QSet<QString> purposes{"hud", "alerts", "localAi", "externalAi", "voice"};
    if (value.metaType().id() != QMetaType::QVariantList || value.toList().size() > purposes.size()) return false;
    for (const auto &use : value.toList()) {
        if (!text(use, 16) || !purposes.contains(use.toString()) || !original.contains(use) || result->contains(use)) return false;
        result->append(use);
    }
    return true;
}
QVariantList intersectUses(const QVariantList &left, const QVariantList &right) {
    QVariantList result;
    for (const auto &use : left) if (right.contains(use)) result.append(use);
    return result;
}
std::shared_ptr<ServiceEndpoint> own(ServiceEndpoint *endpoint) {
    const QPointer<ServiceEndpoint> alive(endpoint);
    return std::shared_ptr<ServiceEndpoint>(endpoint, [alive](ServiceEndpoint *) { if (alive) delete alive.data(); });
}
QVariantMap defaultProvider() { return {{"provider_kind", "builtin"}, {"provider_options", QVariantMap{}}}; }
bool fingerprint(const QVariant &value, bool empty = false) {
    static const QRegularExpression pattern(QStringLiteral("\\A[0-9a-f]{64}\\z"));
    return value.metaType().id() == QMetaType::QString &&
        ((empty && value.toString().isEmpty()) || pattern.match(value.toString()).hasMatch());
}
bool providerOptions(const QVariantMap &options, bool emptyHashes = false) {
    static const QRegularExpression package(QStringLiteral("\\A[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*\\z"));
    static const QRegularExpression service(QStringLiteral("\\A[a-z][a-z0-9_.-]{0,79}@[1-9][0-9]{0,3}\\z"));
    return exact(options, {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"}) &&
        text(options.value("package_id"), 64) && package.match(options.value("package_id").toString()).hasMatch() &&
        text(options.value("service_name"), 96) && service.match(options.value("service_name").toString()).hasMatch() &&
        fingerprint(options.value("package_fingerprint"), emptyHashes) && fingerprint(options.value("configuration_fingerprint"), emptyHashes);
}
bool validProviderSelection(const QVariantMap &selection, bool emptyHashes = false) {
    if (!exact(selection, {"provider_kind", "provider_options"}) ||
        selection.value("provider_options").metaType().id() != QMetaType::QVariantMap) return false;
    return selection == defaultProvider() || (selection.value("provider_kind") == "package" &&
        providerOptions(selection.value("provider_options").toMap(), emptyHashes));
}
bool sameProvider(const QVariantMap &a, const QVariantMap &b) {
    for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})
        if (a.value(QLatin1String(key)) != b.value(QLatin1String(key))) return false;
    return true;
}
QVariantMap providerLocator(const QVariantMap &identity) {
    QVariantMap options;
    for (const auto &key : {"package_id", "service_name", "package_fingerprint", "configuration_fingerprint"})
        options[QLatin1String(key)] = identity.value(QLatin1String(key));
    return options;
}
bool providerScope(const QVariantMap &saved) {
    static const QRegularExpression node(QStringLiteral("\\A[A-Za-z0-9_.-]{1,64}\\z"));
    if (!exact(saved, {"profile_id", "field_profile_id", "capability_revision", "environment", "node_id", "robot_key"}) ||
        !text(saved.value("profile_id"), 128) || !text(saved.value("node_id"), 64) || !node.match(saved.value("node_id").toString()).hasMatch() ||
        (saved.value("environment") != "training" && saved.value("environment") != "competition")) return false;
    const auto rules = RulesetCatalog::profile(saved.value("profile_id").toString());
    return !rules.isEmpty() && saved.value("field_profile_id") == rules.value("field_profile_id") &&
        saved.value("capability_revision") == rules.value("capability_revision") &&
        semanticRobot(saved.value("robot_key").toString(), saved.value("profile_id").toString());
}
bool readProviders(const QString &file, QVariantList *profiles, QString *error) {
    profiles->clear();
    if (file.isEmpty() || !QFileInfo::exists(file)) return true;
    QFile input(file);
    if (QFileInfo(file).isSymLink() || !input.open(QIODevice::ReadOnly))
        return fail(error, "共享提供者选择不可读取或为符号链接；未启用");
    const auto bytes = input.read(64 * 1024 + 1); QJsonParseError parse;
    const auto doc = QJsonDocument::fromJson(bytes, &parse); const auto root = doc.toVariant().toMap();
    if (bytes.size() > 64 * 1024 || parse.error != QJsonParseError::NoError || !doc.isObject() ||
        !exact(root, {"schema", "profiles"}) || !integer(root.value("schema"), 1, 1) ||
        root.value("profiles").metaType().id() != QMetaType::QVariantList || root.value("profiles").toList().size() > 32)
        return fail(error, "共享提供者选择损坏、版本未知或超过32范围；原文件保留");
    QSet<QString> seen;
    for (const auto &entry : root.value("profiles").toList()) {
        const auto record = entry.toMap(), saved = record.value("scope").toMap();
        if (entry.metaType().id() != QMetaType::QVariantMap || !exact(record, {"scope", "selection"}) ||
            record.value("scope").metaType().id() != QMetaType::QVariantMap || !providerScope(saved) ||
            record.value("selection").metaType().id() != QMetaType::QVariantMap ||
            !validProviderSelection(record.value("selection").toMap()) || seen.contains(digest(saved)))
            return fail(error, "共享提供者选择含无效／重复范围或未知选项；原文件保留");
        seen.insert(digest(saved)); profiles->append(record);
    }
    return true;
}
bool activeLease(const QVariantMap &details) {
    const auto flag = details.value("provider_active");
    return !details.contains("provider_active") || (flag.metaType().id() == QMetaType::Bool && flag.toBool());
}
bool boolIs(const QVariant &value, bool expected) { return value.metaType().id() == QMetaType::Bool && value.toBool() == expected; }
bool startedState(const QVariantMap &details) {
    return activeLease(details) && (boolIs(details.value("active"), true) ||
        (boolIs(details.value("active"), false) && details.value("state") == "starting"));
}
}

struct TerminalTeamHost::Private {
    struct Narrow {
        qint64 sequence = 0, deadline = 0;
        bool invalid = false;
        QVariantList allowedUses;
    };
    PluginHost *host = nullptr;
    QString directory, file, status = QStringLiteral("队内共享未配置；本机数据独立运行"), privateKeyPath;
    QPointer<SeasonConfiguration> season;
    QPointer<TerminalDataBus> bus;
    QPointer<PluginPackageRuntime> packages;
    QVariantMap values = defaults(), savedScope, native, moduleView;
    QVariantList profiles;
    std::shared_ptr<ServiceEndpoint> endpoint;
    ProofVerifierFactory verifierFactory;
    std::shared_ptr<TerminalTeamProofVerifier> verifier;
    QVariantMap provider = defaultProvider(), providerIdentity;
    bool providerSaved = false, providerValid = true, builtinAvailable = false;
    QString providerError;
    std::unique_ptr<TerminalTeamContract::Store> store;
    QTimer timer;
    QMap<QString, Narrow> narrowing;
    QMap<QString, QVariantMap> signedItems;
    QByteArray cut;
    QString lastExport;
    quint64 generation = 0, exports = 0, received = 0, rejected = 0;
    qint64 producedTick = 0, producedUtc = 0, lastUtc = 0, lastTick = 0;
    bool changing = false, destroying = false, configured = false, fileValid = true;
    bool proofsVerified = false, publisherVerified = false, clockInvalid = false;
    QString sanitize(QString message) const {
        if (!privateKeyPath.isEmpty()) message.replace(privateKeyPath, "<signing-key-file>");
        return message.left(512);
    }
};

TerminalTeamHost::TerminalTeamHost(PluginHost *host, QString directory, SeasonConfiguration *season,
                                  TerminalDataBus *bus, QString file, QObject *parent)
    : QObject(parent), d(std::make_unique<Private>()) {
    d->host = host; d->directory = std::move(directory); d->season = season; d->bus = bus; d->file = std::move(file);
    d->timer.setInterval(100);
    connect(&d->timer, &QTimer::timeout, this, &TerminalTeamHost::tick);
    if (season) {
        connect(season, &SeasonConfiguration::aboutToChange, this, [this] {
            QPointer<TerminalTeamHost> alive(this);
            // Clear the old authorization before any retiring plugin code can
            // reenter this object during stop().
            d->values = defaults(); d->savedScope.clear(); d->configured = false;
            d->changing = true;
            const auto generation = d->generation + 1;
            retire();
            if (!alive || generation != d->generation) return;
            d->changing = false;
            d->status = QStringLiteral("规则／用途范围已退役；共享已停，须在新范围重新保存并显式启用");
            emit changed();
        });
        connect(season, &SeasonConfiguration::stateChanged, this, &TerminalTeamHost::changed);
        connect(season, &SeasonConfiguration::contextChanged, this, [this] { loadProvider(); emit changed(); });
        connect(season, &QObject::destroyed, this, [this] { stop(); });
    }
    if (bus) connect(bus, &QObject::destroyed, this, [this] { stop(); });
    load();
    loadProvider(); refreshProviders();
}
TerminalTeamHost::~TerminalTeamHost() {
    d->destroying = true;
    if (d->season) disconnect(d->season, nullptr, this, nullptr);
    if (d->packages) disconnect(d->packages, nullptr, this, nullptr);
    retire();
}
QVariantMap TerminalTeamHost::current() const { return d->values; }
QVariantMap TerminalTeamHost::providerSelection() const { return d->provider; }
bool TerminalTeamHost::editable() const { return lockReason().isEmpty(); }
QString TerminalTeamHost::lockReason() const {
    if (d->destroying || !d->season || !d->bus) return QStringLiteral("队伍宿主不可用");
    if (d->changing) return QStringLiteral("正在保存或切换队伍范围");
    if (!d->fileValid || d->file.isEmpty()) return QStringLiteral("共享配置损坏或未配置路径；原文件保留，请先恢复有效文件");
    if (d->season->profileId() != "rmuc2027-regional-v1.0.0" || d->season->current().isEmpty())
        return QStringLiteral("队内共享仅适用于当前2027正式规则范围");
    if (d->season->context().value("configuration_valid") != QVariant(true)) return QStringLiteral("当前规则配置无效");
    return d->season->editable() ? QString{} : d->season->lockReason();
}
QString TerminalTeamHost::status() const { return d->status; }
bool TerminalTeamHost::active() const { return bool(d->endpoint) && !d->changing; }
bool TerminalTeamHost::reject(const QString &reason) {
    d->status = d->sanitize(reason);
    emit changed();
    return false;
}
void TerminalTeamHost::load() {
    if (d->file.isEmpty()) { d->fileValid = false; d->status = QStringLiteral("未设置队伍配置路径，未启用网络"); return; }
    QVariantMap selected; QString error;
    if (!readSettings(d->file, &d->profiles, &selected, &error)) {
        d->fileValid = false; d->status = error; return;
    }
    const auto ctx = context(d->season);
    for (const auto &entry : d->profiles) {
        const auto record = entry.toMap(), saved = record.value("scope").toMap();
        if (saved == selected && saved.value("profile_id") == ctx.value("profile_id") &&
            saved.value("field_profile_id") == ctx.value("field_profile_id") &&
            saved.value("capability_revision") == ctx.value("capability_revision") &&
            saved.value("environment") == (d->season ? d->season->environment() : QString{})) {
            d->values = record.value("values").toMap(); d->savedScope = saved; d->configured = true;
            d->status = QStringLiteral("已读取当前范围的共享配置；保持停用，不自动连接");
            break;
        }
    }
}
bool TerminalTeamHost::save(const QVariantMap &values) {
    if (QThread::currentThread() != thread()) return false;
    auto reason = lockReason();
    if (!reason.isEmpty()) return reject(reason);
    const auto ctx = context(d->season);
    const auto environment = d->season->environment();
    if (!validatePublic(values, ctx, environment, d->file, &reason)) return reject(reason);
    if (!QDir().mkpath(QFileInfo(d->file).absolutePath())) return reject(QStringLiteral("共享配置目录不可写"));
    QLockFile lock(d->file + ".lock");
    if (!lock.tryLock(0)) return reject(QStringLiteral("共享配置由另一实例占用，请稍后重试"));
    QVariantList profiles; QVariantMap selected;
    if (!readSettings(d->file, &profiles, &selected, &reason)) { d->fileValid = false; return reject(reason); }
    const auto saved = scope(ctx, environment, values);
    bool replaced = false;
    for (auto &entry : profiles) if (entry.toMap().value("scope").toMap() == saved) {
        entry = QVariantMap{{"scope", saved}, {"values", values}}; replaced = true; break;
    }
    if (!replaced) {
        if (profiles.size() >= 32) return reject(QStringLiteral("共享身份范围已达32项；不自动覆盖其他节点"));
        profiles.append(QVariantMap{{"scope", saved}, {"values", values}});
    }
    const auto bytes = compact(QVariantMap{{"schema", 1}, {"selected", saved}, {"profiles", profiles}});
    if (bytes.size() > SettingsBytes || !atomicWrite(d->file, bytes, &reason))
        return reject(reason.isEmpty() ? QStringLiteral("共享配置超过128KiB；原文件保留") : reason);
    const bool identityDiffers = d->values.value("team_id") != values.value("team_id") ||
        d->values.value("robot_key") != values.value("robot_key");
    QPointer<TerminalTeamHost> alive(this);
    const auto generation = d->generation + 1;
    d->changing = true;
    retire();
    if (!alive || generation != d->generation) return false;
    d->values = values; d->savedScope = saved; d->profiles = profiles; d->configured = true; d->changing = false;
    loadProvider();
    d->status = QStringLiteral("共享配置已保存；网络已停，需显式启用；没有自动连接");
    if (identityDiffers) {
        // Scope retirement is synchronous. General provider/status changes also
        // occur during package retirement and must never trigger this signal.
        emit identityChanged();
        if (!alive || generation != d->generation) return false;
    }
    emit changed();
    return true;
}
void TerminalTeamHost::loadProvider() {
    d->provider = defaultProvider(); d->providerSaved = false; d->providerValid = true; d->providerError.clear();
    QVariantList profiles;
    if (!readProviders(d->file.isEmpty() ? QString{} : d->file + ".provider.json", &profiles, &d->providerError)) {
        d->providerValid = false; d->status = d->providerError; return;
    }
    if (!d->configured || !d->season) return;
    const auto currentScope = scope(context(d->season), d->season->environment(), d->values);
    for (const auto &entry : profiles) if (entry.toMap().value("scope").toMap() == currentScope) {
        d->provider = entry.toMap().value("selection").toMap(); d->providerSaved = true; break;
    }
}
QVariantList TerminalTeamHost::providerCatalog() const {
    QVariantList rows{QVariantMap{{"provider_kind", "builtin"}, {"plugin_id", PluginId},
        {"label", d->builtinAvailable ? QStringLiteral("原生schema3完整队伍汇总") : QStringLiteral("原生schema3汇总 · 未安装或标识重复")},
        {"available", d->builtinAvailable}, {"default_options", QVariantMap{}}}};
    if (d->packages) for (const auto &entry : d->packages->serviceProviders(ProviderRole, ProviderContract)) {
        auto row = entry.toMap(); row["provider_kind"] = "package"; row["available"] = true;
        row["default_options"] = providerLocator(row);
        row["label"] = row.value("title").toString() + " · " + row.value("package_id").toString() + " / " + row.value("service_name").toString();
        rows.append(row);
    }
    if (d->provider.value("provider_kind") == "package" && selectedProvider().isEmpty()) {
        const auto options = d->provider.value("provider_options").toMap(); auto row = options;
        row["provider_kind"] = "package"; row["available"] = false; row["retained"] = true; row["default_options"] = options;
        row["label"] = options.value("package_id").toString() + " / " + options.value("service_name").toString() + QStringLiteral(" · 已保存，缺失或内容已变化");
        rows.append(row);
    }
    return rows;
}
QVariantMap TerminalTeamHost::selectedProvider(bool requireFingerprints) const {
    if (d->provider.value("provider_kind") == "builtin")
        return d->builtinAvailable ? QVariantMap{{"provider_kind", "builtin"}, {"plugin_id", PluginId}} : QVariantMap{};
    if (!d->packages || d->provider.value("provider_kind") != "package") return {};
    const auto options = d->provider.value("provider_options").toMap();
    for (const auto &entry : d->packages->serviceProviders(ProviderRole, ProviderContract)) {
        const auto row = entry.toMap();
        if (row.value("package_id") == options.value("package_id") && row.value("service_name") == options.value("service_name") &&
            (!requireFingerprints || sameProvider(row, options))) return row;
    }
    return {};
}
void TerminalTeamHost::refreshProviders() {
    if (QThread::currentThread() != thread()) return;
    int matches = 0;
    if (d->host) for (const auto &entry : PluginHost::discover(d->directory)) {
        const auto row = entry.toMap();
        if (row.value("id") == PluginId && row.value("role") == ProviderRole && row.value("contract") == QLatin1String(ExtensionPlugin_iid)) ++matches;
    }
    d->builtinAvailable = matches == 1;
    synchronizeProviders();
}
void TerminalTeamHost::synchronizeProviders() {
    if (d->destroying) return;
    if (d->endpoint && d->provider.value("provider_kind") == "package" && selectedProvider().isEmpty()) {
        QPointer<TerminalTeamHost> alive(this); const auto generation = d->generation + 1;
        d->changing = true; retire();
        if (!alive || generation != d->generation) return;
        d->changing = false; d->status = QStringLiteral("队伍提供者已退役，独立验证器与投影已清除；无自动回退，本机数据继续运行");
    }
    emit changed();
}
void TerminalTeamHost::setPackageRuntime(PluginPackageRuntime *runtime) {
    if (QThread::currentThread() != thread() || d->packages == runtime) return;
    QPointer<TerminalTeamHost> alive(this);
    const bool package = d->provider.value("provider_kind") == "package";
    const auto generation = d->generation + (package ? 1 : 0);
    if (package) { d->changing = true; retire(); }
    if (!alive || generation != d->generation) return;
    if (d->packages) disconnect(d->packages, nullptr, this, nullptr);
    d->packages = runtime; d->changing = false;
    if (runtime) {
        connect(runtime, &PluginPackageRuntime::changed, this, &TerminalTeamHost::synchronizeProviders);
        connect(runtime, &QObject::destroyed, this, [this] {
            if (d->provider.value("provider_kind") == "package") {
                QPointer<TerminalTeamHost> alive(this); const auto generation = d->generation + 1;
                d->changing = true; retire();
                if (!alive || generation != d->generation) return;
                d->changing = false; d->status = QStringLiteral("队伍插件注册表已销毁；独立验证器和投影已退役，没有自动替换");
            }
            emit changed();
        });
    }
    emit changed();
}
void TerminalTeamHost::setProofVerifierFactory(ProofVerifierFactory factory) {
    if (QThread::currentThread() != thread()) return;
    QPointer<TerminalTeamHost> alive(this); const auto generation = d->generation + 1;
    d->changing = true; retire();
    if (!alive || generation != d->generation) return;
    d->verifierFactory = std::move(factory); d->changing = false;
    d->status = d->verifierFactory ? QStringLiteral("原生独立证明后端已装配；未配置证书或启用共享") :
        QStringLiteral("独立证明后端不可用；共享保持停用，本机数据与其他客户端功能继续");
    emit changed();
}
bool TerminalTeamHost::saveProvider(const QVariantMap &input) {
    if (QThread::currentThread() != thread()) return false;
    const auto locked = lockReason(); if (!locked.isEmpty()) return reject(locked);
    if (!d->configured || d->savedScope != scope(context(d->season), d->season->environment(), d->values))
        return reject(QStringLiteral("先保存当前节点／语义机器人的完整队伍参数，再保存提供者选择"));
    if (!validProviderSelection(input, true)) return reject(QStringLiteral("队伍提供者只接受内置空选项，或精确包／服务及两个原生指纹"));
    auto selection = input;
    if (selection.value("provider_kind") == "package") {
        auto options = selection.value("provider_options").toMap(); QVariantMap registered;
        if (d->packages) for (const auto &entry : d->packages->serviceProviders(ProviderRole, ProviderContract)) {
            const auto row = entry.toMap();
            if (row.value("package_id") == options.value("package_id") && row.value("service_name") == options.value("service_name")) { registered = row; break; }
        }
        if (!registered.isEmpty()) {
            for (const auto &key : {"package_fingerprint", "configuration_fingerprint"}) {
                const auto name = QLatin1String(key);
                if (!options.value(name).toString().isEmpty() && options.value(name) != registered.value(name))
                    return reject(QStringLiteral("队伍插件内容／配置已变化；先查看刷新后的来源再明确选择保存"));
                options[name] = registered.value(name);
            }
        } else if (d->provider.value("provider_kind") != "package" || !d->providerSaved ||
            !sameProvider(options, d->provider.value("provider_options").toMap()))
            return reject(QStringLiteral("新选队伍插件未运行；只能保留原已保存的缺失来源，没有自动替换"));
        selection["provider_options"] = options;
    }
    const auto file = d->file + ".provider.json";
    if (!QDir().mkpath(QFileInfo(file).absolutePath()) || QFileInfo(file).isSymLink()) return reject(QStringLiteral("队伍提供者配置目录不可写或为符号链接"));
    QLockFile lock(file + ".lock"); if (!lock.tryLock(0)) return reject(QStringLiteral("另一实例正在保存队伍提供者选择"));
    QVariantList profiles; QString error;
    if (!readProviders(file, &profiles, &error)) { d->providerValid = false; d->providerError = error; return reject(error); }
    bool replaced = false;
    const QVariantMap record{{"scope", d->savedScope}, {"selection", selection}};
    for (auto &entry : profiles) if (entry.toMap().value("scope").toMap() == d->savedScope) { entry = record; replaced = true; break; }
    if (!replaced) {
        if (profiles.size() >= 32) return reject(QStringLiteral("队伍提供者节点范围已满32项；未删除其他来源"));
        profiles.append(record);
    }
    const auto bytes = compact(QVariantMap{{"schema", 1}, {"profiles", profiles}});
    if (bytes.size() > 64 * 1024 || !atomicWrite(file, bytes, &error)) return reject(error.isEmpty() ? QStringLiteral("队伍提供者选择超过64KiB") : error);
    QPointer<TerminalTeamHost> alive(this); const auto generation = d->generation + 1;
    d->changing = true; retire();
    if (!alive || generation != d->generation) return false;
    d->provider = selection; d->providerSaved = true; d->providerValid = true; d->providerError.clear(); d->changing = false;
    d->status = QStringLiteral("队伍提供者已保存；旧投影和网络已退役，启用仍需未使用的新轮次及独立证明后端");
    emit changed(); return true;
}
void TerminalTeamHost::retire() {
    ++d->generation;
    d->timer.stop();
    auto endpoint = std::move(d->endpoint);
    d->verifier.reset(); d->providerIdentity.clear();
    d->store.reset(); d->moduleView.clear(); d->native.clear(); d->cut.clear(); d->narrowing.clear(); d->signedItems.clear();
    d->lastExport.clear(); d->proofsVerified = d->publisherVerified = d->clockInvalid = false;
    d->producedTick = d->producedUtc = d->lastUtc = d->lastTick = 0;
    d->exports = d->received = d->rejected = 0;
    // Clear credentials before invoking a retiring plugin; its callbacks no
    // longer own this generation. Local bus and gateway data remain untouched.
    d->privateKeyPath.clear();
    if (endpoint) { disconnect(endpoint.get(), nullptr, this, nullptr); endpoint->stop(); }
}
void TerminalTeamHost::stop() {
    if (QThread::currentThread() != thread()) {
        QMetaObject::invokeMethod(this, &TerminalTeamHost::stop, Qt::QueuedConnection); return;
    }
    QPointer<TerminalTeamHost> alive(this);
    const auto generation = d->generation + 1;
    d->changing = true;
    retire();
    if (!alive || generation != d->generation) return;
    d->changing = false;
    d->status = QStringLiteral("队内网络与投影已停；本机数据总线、其他链路继续独立运行");
    emit changed();
}
bool TerminalTeamHost::setEnabled(bool enabled) {
    if (QThread::currentThread() != thread()) return false;
    if (!enabled) { stop(); return true; }
    const auto reason = lockReason();
    if (!reason.isEmpty()) return reject(reason);
    const auto ctx = context(d->season);
    if (!d->configured || d->savedScope != scope(ctx, d->season->environment(), d->values))
        return reject(QStringLiteral("先在当前规则／用途／语义机器人范围保存完整配置"));
    if (!d->providerValid || !d->providerSaved || !validProviderSelection(d->provider))
        return reject(d->providerError.isEmpty() ? QStringLiteral("先明确保存当前节点的队伍提供者选择") : d->providerError);
    if (!d->verifierFactory) return reject(QStringLiteral("原生独立证明后端不可用；共享未启用，本机数据和其他客户端功能继续运行"));
    if (d->endpoint) return true;
    const auto selected = selectedProvider();
    if (selected.isEmpty()) return reject(QStringLiteral("已保存的队伍提供者缺失、重复或内容／配置已变化；未自动回退"));
    QString error;
    if (!validatePublic(d->values, ctx, d->season->environment(), d->file, &error)) return reject(error);
    const auto config = nativeConfig(d->values, ctx, d->file, true, &error);
    if (config.isEmpty()) return reject(error);
    QPointer<TerminalTeamHost> alive(this);
    const auto generation = ++d->generation;
    d->changing = true;
    const auto transition = qScopeGuard([this, alive, generation] {
        if (alive && generation == d->generation && d->changing) {
            d->changing = false; if (!d->endpoint) d->privateKeyPath.clear(); emit changed();
        }
    });
    const auto current = [this, alive, generation] { return alive && generation == d->generation; };
    d->privateKeyPath = config.value("signing_key_file").toString();
    // This backend comes only from native composition. Neither a community
    // factory nor its Q_INTERFACES/self-reported flags can choose the verifier.
    const auto verifierFactory = d->verifierFactory;
    std::unique_ptr<TerminalTeamProofVerifier> createdVerifier;
    try { createdVerifier = verifierFactory(config, &error); }
    catch (...) { error = QStringLiteral("原生证明后端配置发生异常；未启用队伍提供者"); }
    if (!current()) return false;
    if (!createdVerifier) return reject(error.isEmpty() ? QStringLiteral("原生证明后端未接纳当前证书／范围；未启用网络") : error);
    std::shared_ptr<TerminalTeamProofVerifier> verifier(std::move(createdVerifier));
    auto store = std::make_unique<TerminalTeamContract::Store>();
    if (!store->configure(config, &error)) return reject(error);
    // Claim durable scope before the first factory/start action. A failed start
    // consumes this epoch too; process restart must never reuse its nonce scope.
    if (!consumeEpoch(d->file, d->values, &error)) return reject(error);
    const bool package = d->provider.value("provider_kind") == "package";
    ServiceEndpoint *created = nullptr; QVariantMap provider;
    if (package) {
        const auto options = d->provider.value("provider_options").toMap();
        if (d->packages) created = d->packages->createProviderService(options.value("package_id").toString(),
            options.value("service_name").toString(), ProviderRole, ProviderContract, &error, &provider);
    } else {
        auto *factory = d->host ? d->host->loadExtension(d->directory, PluginId, ProviderRole, &error) : nullptr;
        if (current() && factory) {
            try { created = factory->createService(); }
            catch (...) { error = QStringLiteral("队伍工厂创建发生原生异常；此共享轮次已消耗"); }
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
    if (!candidate) return reject(error.isEmpty() ? QStringLiteral("可选队伍工厂未创建端点；此共享轮次已消耗") : error);
    if (candidate->parent() || candidate->thread() != thread())
        return reject(QStringLiteral("队伍工厂须转交新的、无父对象且位于界面线程的静止端点"));
    const auto quiet = candidate->details();
    if (!current() || !candidate) return false;
    if (!boolIs(quiet.value("active"), false) || !activeLease(quiet) ||
        (quiet.contains("busy") && !boolIs(quiet.value("busy"), false)) ||
        (quiet.contains("connected") && !boolIs(quiet.value("connected"), false)) || quiet.value("state") == "starting")
        return reject(QStringLiteral("队伍工厂返回已活动／失效端点；此共享轮次已消耗"));
    if (package && (provider != selectedProvider() || !sameProvider(provider, d->provider.value("provider_options").toMap())))
        return reject(QStringLiteral("创建期间队伍提供者身份已变化；此共享轮次已消耗"));
    auto endpoint = own(candidate.data()); dispose.dismiss();
    d->endpoint = endpoint; d->store = std::move(store); d->native = config; d->verifier = std::move(verifier); d->providerIdentity = provider;
    const auto startupMessage = std::make_shared<bool>(false);
    connect(endpoint.get(), &ServiceEndpoint::messageReceived, this,
        [this, generation, startupMessage](const QVariantMap &message) {
            if (generation != d->generation) return;
            if (d->changing) { *startupMessage = true; return; }
            receive(generation, message);
        });
    connect(endpoint.get(), &ServiceEndpoint::statusChanged, this, [this, generation] {
        if (generation != d->generation) return;
        const auto endpoint = d->endpoint;
        const QPointer<ServiceEndpoint> guard(endpoint.get());
        QPointer<TerminalTeamHost> alive(this);
        const auto observed = endpoint ? endpoint->details() : QVariantMap{};
        if (!alive || !guard || generation != d->generation) return;
        if (!activeLease(observed) || (!d->changing && !startedState(observed))) {
            const auto retirement = d->generation + 1; d->changing = true; retire();
            if (!alive || retirement != d->generation) return;
            d->changing = false; reject(QStringLiteral("队伍租约或端点已退役；独立证明状态与投影已清除，没有自动替换")); return;
        }
        const auto error = observed.value("error");
        if (error.metaType().id() == QMetaType::QString && !error.toString().isEmpty())
            d->status = d->sanitize(error.toString());
        emit changed();
    });
    connect(endpoint.get(), &ServiceEndpoint::errorOccurred, this, [this, generation](const QString &message) {
        if (generation != d->generation) return;
        d->status = d->sanitize(message); emit changed();
    });
    connect(endpoint.get(), &QObject::destroyed, this, [this, generation] {
        if (generation != d->generation) return;
        // QObject destruction has already cleared the guarded deleter. Do not
        // call virtual stop() on the object whose destructor is running.
        d->endpoint.reset();
        QPointer<TerminalTeamHost> alive(this); const auto retirement = d->generation + 1;
        retire();
        if (!alive || retirement != d->generation) return;
        d->changing = false;
        d->status = QStringLiteral("可选队伍端点已销毁；本机数据与其他链路继续运行");
        emit changed();
    });
    const bool started = endpoint->start(config, &error);
    if (!current() || !candidate) return false;
    const auto observed = endpoint->details();
    if (!current() || !candidate) return false;
    if (!started || !startedState(observed) || *startupMessage || (package && provider != selectedProvider())) {
        const auto sanitized = d->sanitize(error);
        const auto retiringGeneration = d->generation + 1;
        d->changing = true;
        retire();
        if (!alive || retiringGeneration != d->generation) return false;
        d->changing = false;
        return reject(sanitized.isEmpty() ? QStringLiteral("可选队伍插件启动失败，本机功能继续") : sanitized);
    }
    d->changing = false;
    d->timer.start();
    d->status = QStringLiteral("队伍插件已启动；TLS、原始证明及各字段时效按实际状态显示，AI输入仍未接通");
    emit changed();
    return current();
}

QVariantMap TerminalTeamHost::details() const {
    QVariantMap result{{"active", active()}, {"configured", d->configured},
        {"plugin_id", d->provider.value("provider_kind") == "package" ? QStringLiteral("package") : PluginId},
        {"provider_selection", d->provider}, {"provider_selection_saved", d->providerSaved}, {"provider_selection_valid", d->providerValid},
        {"provider_selection_error", d->providerError}, {"provider_available", !selectedProvider().isEmpty()},
        {"provider_identity", d->providerIdentity}, {"provider_settings_file", d->file + ".provider.json"},
        {"provider_selection_file", d->file + ".provider.json"}, {"automatic_fallback", false},
        {"verification_backend_available", bool(d->verifierFactory)}, {"host_verifier_configured", bool(d->verifier)},
        {"proof_verification_boundary", "native_factory_independent_of_provider"}, {"provider_flags_certify_proofs", false},
        {"schema", 3}, {"context", context(d->season)}, {"environment", d->season ? d->season->environment() : QString{}},
        {"source_proofs_verified", d->proofsVerified}, {"publisher_proof_verified", d->publisherVerified},
        {"ai_input_ready", false}, {"official_issuer_bound", false}, {"measurement_verified", false},
        {"clock_sync_verified", false}, {"exports", qulonglong(d->exports)}, {"received_views", qulonglong(d->received)},
        {"rejected_views", qulonglong(d->rejected)}, {"local_bus_independent", true}, {"auto_connect", false},
        {"native_view_limit", 1024 * 1024}, {"source_body_limit", 64 * 1024},
        {"team_view_body_limit", 256 * 1024}, {"maximum_cut_members", 16}, {"maximum_cut_items", 512}};
    const auto endpoint = d->endpoint;
    const auto generation = d->generation;
    QPointer<const TerminalTeamHost> alive(this);
    const auto service = endpoint ? endpoint->details() : QVariantMap{};
    if (!alive || generation != d->generation) return {};
    for (const auto &key : {"state", "connected", "tls_connected", "pending_messages", "pending_bytes", "received", "published", "dropped"}) {
        const auto value = service.value(QLatin1String(key));
        if (value.metaType().id() == QMetaType::Bool || integer(value, 0, Safe)) result[QLatin1String(key)] = value;
        else if (text(value, 128, true)) result[QLatin1String(key)] = d->sanitize(value.toString());
    }
    if (service.value("error").metaType().id() == QMetaType::QString)
        result["last_error"] = d->sanitize(service.value("error").toString());
    if (!result.contains("connected")) result["connected"] = false;
    return result;
}

QVariantMap TerminalTeamHost::teamView() const {
    if (!d->store || !d->endpoint || !d->verifier) return {{"schema", 3}, {"kind", "terminal-team-view"}, {"context", context(d->season)},
        {"items", QVariantList{}}, {"members", QVariantList{}}, {"channel_connected", false},
        {"source_proofs_verified", false}, {"publisher_proof_verified", false}, {"ai_input_ready", false}};
    const auto endpoint = d->endpoint;
    const auto generation = d->generation;
    QPointer<const TerminalTeamHost> alive(this);
    const auto service = endpoint->details();
    if (!alive || generation != d->generation) return {};
    const auto utc = QDateTime::currentMSecsSinceEpoch(), tickNow = PacketObservation::steadyMilliseconds();
    const bool connected = boolIs(service.value("connected"), true) && boolIs(service.value("active"), true) && activeLease(service) && !d->clockInvalid;
    auto view = d->store->view(utc, tickNow, connected);
    QVariantList rows;
    for (const auto &entry : view.value("items").toList()) {
        auto row = entry.toMap();
        const auto narrow = d->narrowing.value(itemKey(row));
        const auto remaining = qMax<qint64>(0, std::min(row.value("remaining_ms").toLongLong(), narrow.deadline - tickNow));
        if (narrow.invalid || remaining == 0 || !d->publisherVerified || !d->proofsVerified) {
            const bool activeState = row.value("state") == "fresh" || row.value("state") == "mock" || row.value("state") == "time_unverified";
            if (activeState) row["state"] = narrow.invalid ? "quarantined" :
                !d->publisherVerified || !d->proofsVerified ? "proof_unverified" : "expired";
            row["remaining_ms"] = 0; row["allowed_uses"] = QVariantList{}; row["value"] = QVariant{};
        } else {
            row["remaining_ms"] = remaining;
            row["allowed_uses"] = intersectUses(row.value("allowed_uses").toList(), narrow.allowedUses);
        }
        // Signatures authenticate a configured sender, never the measurement,
        // producer clock, map transform or an unconnected AI consumer.
        row["host_source_proof_verified"] = d->proofsVerified;
        // Independent proof verification supplies this host receipt clock;
        // it must not be presented as the source sensor's network ingress.
        row["receipt_basis"] = "host_proof_verification";
        row["authoritative"] = false; row["renderable"] = false;
        row["measurement_verified"] = false; row["ai_input_ready"] = false;
        rows.append(row);
    }
    view["items"] = rows;
    view.remove("proofs"); // QML receives proof references, not repeated signed payload blobs.
    view.remove("publisher_proof"); // The publisher envelope embeds the same original source proofs.
    view["source_proofs_verified"] = d->proofsVerified;
    view["publisher_proof_verified"] = d->publisherVerified;
    view["projection_produced_at_ms"] = d->producedUtc;
    view["projection_age_ms"] = d->producedTick ? qMax<qint64>(0, tickNow - d->producedTick) : 0;
    view["ai_input_ready"] = false;
    return view;
}

void TerminalTeamHost::tick() {
    if (!d->endpoint || !d->store || !d->verifier || !d->season || !d->bus || d->changing) return;
    if (d->savedScope != scope(context(d->season), d->season->environment(), d->values)) { stop(); return; }
    const auto utc = QDateTime::currentMSecsSinceEpoch(), now = PacketObservation::steadyMilliseconds();
    if (d->lastUtc && (utc < d->lastUtc || now < d->lastTick || std::abs((utc - d->lastUtc) - (now - d->lastTick)) > 250))
        d->clockInvalid = true;
    d->lastUtc = utc; d->lastTick = now;
    if (d->clockInvalid) { d->status = QStringLiteral("宿主时钟异常；队伍投影已降级，不续命旧字段"); emit changed(); return; }
    const auto endpoint = d->endpoint;
    const auto generation = d->generation;
    QPointer<TerminalTeamHost> alive(this);
    const auto service = endpoint->details();
    if (!alive || generation != d->generation) return;
    if (boolIs(d->values.value("can_send"), true) && boolIs(service.value("active"), true) &&
        boolIs(service.value("connected"), true) && activeLease(service)) {
        QMap<QString, QVariantMap> ordered;
        for (const auto &entry : d->bus->view().value("items").toList()) {
            const auto row = entry.toMap();
            if (row.value("state") != "fresh" || row.value("lifecycle") != "active" ||
                row.value("team_id") != d->values.value("team_id") || row.value("robot_key") != d->values.value("robot_key")) continue;
            const bool mock = row.value("source_kind") == "mock";
            if (mock && (d->season->environment() != "training" || d->values.value("training_mock") != QVariant(true))) continue;
            bool allowed = false;
            for (const auto &grant : d->values.value("allowed_fields").toList()) {
                const auto field = grant.toMap();
                if (field.value("source_id") != row.value("source_id") || field.value("item_id") != row.value("item_id")) continue;
                for (const auto &use : field.value("uses").toList())
                    allowed = allowed || d->values.value("allowed_uses").toList().contains(use);
            }
            if (!allowed) continue;
            const auto observation = raw(row);
            QString error;
            if (!TerminalDataBus::validateObservation(observation, context(d->season), mock, &error)) continue;
            ordered[digest(QVariantList{row.value("source_id"), row.value("session_id"), row.value("item_id")})] = observation;
        }
        QVariantList items;
        for (const auto &entry : ordered) items.append(entry);
        if (items.size() > 64 || compact(items).size() > 60 * 1024) {
            d->status = QStringLiteral("授权完整快照超出64项／60KiB，未截断或发送"); emit changed(); return;
        }
        const auto identity = digest(items);
        if (identity != d->lastExport) {
            const QVariantMap request{{"schema", 3}, {"kind", "local-snapshot"},
                {"snapshot_id", "snapshot-" + identity}, {"items", items}};
            QString error;
            if (!TerminalTeamContract::validateLocalSnapshotRequest(request, &error)) {
                d->status = d->sanitize(error); emit changed(); return;
            }
            const bool accepted = endpoint->submit(request, &error);
            if (!alive || generation != d->generation) return;
            if (accepted) { d->lastExport = identity; ++d->exports; }
            else d->status = d->sanitize(error.isEmpty() ? QStringLiteral("插件未接纳完整本机快照") : error);
        }
    }
    emit changed();
}

void TerminalTeamHost::receive(quint64 generation, const QVariantMap &message) {
    if (generation != d->generation || !d->endpoint || !d->store || !d->verifier || d->changing) return;
    const auto rejectView = [this](const QString &reason) {
        ++d->rejected; d->proofsVerified = d->publisherVerified = false;
        d->status = d->sanitize(reason); emit changed();
    };
    const auto endpoint = d->endpoint;
    const auto verifier = d->verifier; // Keep native verifier alive across reentrant retirement during a proof call.
    QPointer<TerminalTeamHost> alive(this);
    const auto service = endpoint->details();
    if (!alive || generation != d->generation) return;
    if (!boolIs(service.value("active"), true) || !activeLease(service)) {
        rejectView("队伍提供者尚未活动或租约已退役；没有接纳共享投影"); return;
    }
    qint64 producedUtc = 0, producedTick = 0;
    auto utc = QDateTime::currentMSecsSinceEpoch();
    auto now = PacketObservation::steadyMilliseconds();
    if (!bounded(message) || compact(message).size() > 1024 * 1024 ||
        !integer(message.value("schema"), 3, 3) || message.value("kind") != "terminal-team-view" ||
        message.value("context").toMap() != context(d->season) || message.value("team_id") != d->values.value("team_id") ||
        message.value("match_id") != d->values.value("match_id") || message.value("epoch") != d->values.value("epoch") ||
        message.value("publisher_id") != d->values.value("publisher_id") ||
        message.value("proofs").metaType().id() != QMetaType::QVariantList || message.value("proofs").toList().size() > 16 ||
        message.value("items").metaType().id() != QMetaType::QVariantList || message.value("items").toList().size() > 512 ||
        !integer(message.value("produced_at_ms"), 1, utc, &producedUtc) ||
        !integer(message.value("produced_tick_ms"), 0, now, &producedTick) || now - producedTick > 60000 ||
        std::abs((utc - producedUtc) - (now - producedTick)) > 250 ||
        producedTick < d->producedTick || producedUtc < d->producedUtc) {
        rejectView("队伍投影形状、范围或原始产生时刻无效，未接纳"); return;
    }
    if (!verifier || message.value("publisher_proof").metaType().id() != QMetaType::QVariantMap) {
        rejectView("缺少可独立复核的发布者／原始来源证明接口"); return;
    }
    const auto cut = compact(QVariantMap{{"publisher", message.value("publisher_proof")}, {"sources", message.value("proofs")}});
    auto candidate = std::make_unique<TerminalTeamContract::Store>(*d->store);
    auto signedItems = d->signedItems;
    QString error;
    if (cut != d->cut) {
        signedItems.clear();
        QVariantMap publisher;
        if (!verifier->verifyTeamViewProof(message.value("publisher_proof").toMap(), &publisher, &error)) {
            if (alive && generation == d->generation) rejectView(error);
            return;
        }
        if (!alive || generation != d->generation) return;
        if (publisher.value("view_id") != message.value("view_id") || publisher.value("view_revision") != message.value("revision") ||
            publisher.value("session_id") != message.value("publisher_session_id") || publisher.value("proofs") != message.value("proofs")) {
            rejectView("投影cut与签名发布者cut不一致"); return;
        }
        QVariantList sources;
        for (const auto &proof : message.value("proofs").toList()) {
            QVariantMap body;
            if (proof.metaType().id() != QMetaType::QVariantMap || !verifier->verifySourceProof(proof.toMap(), &body, &error)) {
                if (alive && generation == d->generation) rejectView(error);
                return;
            }
            if (!alive || generation != d->generation) return;
            sources.append(body);
            for (const auto &wrapped : body.value("items").toList()) {
                const auto observation = wrapped.toMap().value("observation").toMap();
                auto identity = observation;
                identity["source_node"] = body.value("source_node");
                identity["node_session_id"] = body.value("session_id");
                signedItems[itemKey(identity)] = observation;
            }
        }
        // Verification runs on the crypto worker. Its native arrival evidence
        // can be later than this GUI callback's entry time, so sample admission
        // after every original proof has been checked. The projection's earlier
        // produced_tick still charges all this verification/queue delay to TTL.
        utc = QDateTime::currentMSecsSinceEpoch();
        now = PacketObservation::steadyMilliseconds();
        if (!candidate->commit(publisher, sources, utc, now, &error)) { rejectView(error); return; }
    }
    const auto expected = candidate->view(utc, now, true);
    QMap<QString, QVariantMap> expectedRows;
    for (const auto &entry : expected.value("items").toList()) expectedRows[itemKey(entry.toMap())] = entry.toMap();
    if (expectedRows.size() != message.value("items").toList().size()) {
        rejectView("投影未包含签名cut的完整成员，未截断接纳"); return;
    }
    auto narrowing = d->narrowing;
    QSet<QString> seen;
    static const QSet<QString> permittedStates{"fresh", "mock", "time_unverified", "offline", "expired", "conflict",
        "superseded", "withdrawn", "clock_invalid"};
    for (const auto &entry : message.value("items").toList()) {
        const auto row = entry.toMap();
        const auto key = itemKey(row);
        const auto original = expectedRows.value(key);
        qint64 sequence = 0, remaining = 0;
        QVariantList allowedUses;
        if (entry.metaType().id() != QMetaType::QVariantMap || original.isEmpty() || seen.contains(key) ||
            !integer(row.value("sequence"), 1, Safe, &sequence) || row.value("sequence") != original.value("sequence") ||
            !integer(row.value("remaining_ms"), 0, 60000, &remaining) || !permittedStates.contains(row.value("state").toString()) ||
            row.value("source_proof_ref") != original.value("source_proof_ref") || row.value("snapshot_id") != original.value("snapshot_id") ||
            row.value("relay_deadline_ms") != original.value("relay_deadline_ms") ||
            row.value("source_allowed_uses") != original.value("source_allowed_uses") ||
            !projectionUses(row.value("allowed_uses"), original.value("source_allowed_uses").toList(), &allowedUses)) {
            rejectView("来源投影标识、原证明引用或寿命与独立签名结果不符"); return;
        }
        auto projectedRaw = raw(row), originalRaw = signedItems.value(key);
        // Both stores may hide values after an independent deadline expires.
        // An inactive projection may only redact a value, never replace it.
        const bool rowActive = row.value("state") == "fresh" || row.value("state") == "mock" || row.value("state") == "time_unverified";
        if (!rowActive && (!projectedRaw.value("value").isValid() || projectedRaw.value("value").isNull())) originalRaw["value"] = QVariant{};
        if (compact(projectedRaw) != compact(originalRaw)) { rejectView("投影值或来源元数据不同于原始签名快照"); return; }
        seen.insert(key);
        if (!narrowing.contains(key) && narrowing.size() >= 2048) { rejectView("宿主来源版本历史已满，未删除旧记录"); return; }
        auto previous = narrowing.value(key);
        if (sequence < previous.sequence) { rejectView("宿主观察序号倒退"); return; }
        const auto deadline = now + qMax<qint64>(0, remaining - (now - producedTick));
        const bool invalid = !rowActive;
        if (sequence == previous.sequence && previous.sequence) {
            previous.deadline = std::min(previous.deadline, deadline);
            previous.invalid = previous.invalid || invalid;
            previous.allowedUses = intersectUses(previous.allowedUses, allowedUses);
        } else previous = {sequence, deadline, invalid, allowedUses};
        narrowing[key] = previous;
    }
    d->store = std::move(candidate); d->narrowing = std::move(narrowing); d->signedItems = std::move(signedItems); d->moduleView = message;
    d->cut = cut; d->producedTick = producedTick; d->producedUtc = producedUtc;
    d->publisherVerified = true; d->proofsVerified = !message.value("proofs").toList().isEmpty();
    ++d->received;
    d->status = QStringLiteral("已独立核验发布者及原始来源证明；测量／时钟／坐标未因此认证，AI输入仍未接通");
    emit changed();
}
