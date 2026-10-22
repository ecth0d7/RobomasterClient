#include "TerminalVoiceCoordinator.h"
#include "TerminalAdviceHost.h"
#include "TerminalDataBus.h"
#include "TerminalTeamHost.h"
#include "SeasonConfiguration.h"
#include "ServiceHub.h"
#include "RulesetCatalog.h"
#include "PacketObservation.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QLockFile>
#include <QMap>
#include <QPointer>
#include <QSaveFile>
#include <QSet>
#include <QThread>
#include <QTimer>
#include <QUuid>
#include <algorithm>
#include <cmath>

namespace {
constexpr qint64 Safe = 9007199254740991LL;
constexpr int SettingsLimit = 64 * 1024, MaximumSeen = 4096, MaximumSpeech = 16;
const QString VoiceSource = QStringLiteral("terminal.advice.voice");
const QString VoiceItem = QStringLiteral("announcement");
bool fail(QString *error, const QString &reason) { if (error) *error = reason; return false; }
bool text(const QVariant &value, int maximum, bool empty = false) {
    if (value.metaType().id() != QMetaType::QString || value.toString().size() > maximum ||
        (!empty && value.toString().trimmed().isEmpty())) return false;
    for (const auto c : value.toString())
        if (c.isNull() || c.category() == QChar::Other_Control || c.category() == QChar::Separator_Line || c.category() == QChar::Separator_Paragraph) return false;
    return true;
}
bool id(const QVariant &value, int maximum = 96) {
    if (!text(value, maximum)) return false;
    for (const auto c : value.toString()) {
        const auto n = c.unicode();
        if (!((n >= 'a' && n <= 'z') || (n >= 'A' && n <= 'Z') || (n >= '0' && n <= '9') || n == '_' || n == '-' || n == '.' || n == ':' || n == '/')) return false;
    }
    return true;
}
bool node(const QVariant &value) { return id(value, 64) && !value.toString().contains('/') && !value.toString().contains(':'); }
bool integer(const QVariant &value, qint64 low, qint64 high, qint64 *out = nullptr) {
    const auto type = value.metaType().id();
    if (type != QMetaType::Int && type != QMetaType::UInt && type != QMetaType::LongLong && type != QMetaType::ULongLong && type != QMetaType::Double) return false;
    const auto n = value.toDouble();
    if (!std::isfinite(n) || std::floor(n) != n || n < double(low) || n > double(high)) return false;
    if (out) *out = qint64(n);
    return true;
}
bool yes(const QVariantMap &map, const QString &key) { return map.value(key).metaType().id() == QMetaType::Bool && map.value(key).toBool(); }
bool no(const QVariantMap &map, const QString &key) { return map.value(key).metaType().id() == QMetaType::Bool && !map.value(key).toBool(); }
bool exact(const QVariantMap &map, const QSet<QString> &keys) {
    if (map.size() != keys.size()) return false;
    for (auto it = map.cbegin(); it != map.cend(); ++it) if (!keys.contains(it.key())) return false;
    return true;
}
QByteArray compact(const QVariant &value) { return QJsonDocument::fromVariant(value).toJson(QJsonDocument::Compact); }
QString digest(const QVariant &value) { return QString::fromLatin1(QCryptographicHash::hash(compact(value), QCryptographicHash::Sha256).toHex()); }
int priority(const QString &value) { return value == "info" ? 0 : value == "caution" ? 1 : value == "urgent" ? 2 : -1; }
bool semanticRobot(const QVariant &value) {
    if (!text(value, 64)) return false;
    const auto parts = value.toString().split('/');
    if (parts.size() != 3 || (parts[0] != "red" && parts[0] != "blue") || parts[2].isEmpty() || parts[2].size() > 3 || parts[2][0] < '1' || parts[2][0] > '9') return false;
    for (const auto c : parts[2]) if (c < '0' || c > '9') return false;
    for (const auto &entry : RulesetCatalog::profile("rmuc2027-regional-v1.0.0").value("roster").toList()) {
        const auto role = entry.toMap();
        if (role.value("role_id") == parts[1]) return parts[2].toInt() >= 1 && parts[2].toInt() <= role.value("count").toInt();
    }
    return false;
}
QVariantMap context(const SeasonConfiguration *season) {
    if (!season) return {};
    return {{"profile_id", season->profileId()}, {"field_profile_id", season->current().value("field_profile_id")},
            {"capability_revision", season->current().value("capability_revision")}};
}
QVariantMap scope(const SeasonConfiguration *season, const QVariantMap &values) {
    auto result = context(season);
    result["environment"] = season ? season->environment() : QString{};
    result["team_id"] = values.value("team_id"); result["robot_key"] = values.value("robot_key");
    return result;
}
bool scopeValid(const QVariantMap &saved, const QVariantMap &values) {
    return exact(saved, {"profile_id", "field_profile_id", "capability_revision", "environment", "team_id", "robot_key"}) &&
        saved.value("profile_id") == "rmuc2027-regional-v1.0.0" && id(saved.value("field_profile_id"), 128) &&
        id(saved.value("capability_revision"), 128) && (saved.value("environment") == "training" || saved.value("environment") == "competition") &&
        saved.value("team_id") == values.value("team_id") && saved.value("robot_key") == values.value("robot_key");
}
bool readSettings(const QString &file, QVariantList *profiles, QVariantMap *selected, QString *error) {
    profiles->clear(); selected->clear();
    if (QFileInfo(file).isSymLink()) return fail(error, "语音配置不能为符号链接；原文件保留");
    if (!QFileInfo::exists(file)) return true;
    QFile input(file);
    if (!input.open(QIODevice::ReadOnly)) return fail(error, "语音配置无法读取；没有启用播报");
    const auto bytes = input.read(SettingsLimit + 1); QJsonParseError parse;
    const auto doc = QJsonDocument::fromJson(bytes, &parse); const auto map = doc.toVariant().toMap();
    if (bytes.size() > SettingsLimit || parse.error != QJsonParseError::NoError || !doc.isObject() ||
        !exact(map, {"schema", "selected", "profiles"}) || !integer(map.value("schema"), 1, 1) ||
        map.value("selected").metaType().id() != QMetaType::QVariantMap || map.value("profiles").metaType().id() != QMetaType::QVariantList || map.value("profiles").toList().size() > 32)
        return fail(error, "语音配置损坏或版本未知；原文件保留，未自动重置");
    QSet<QString> seen;
    for (const auto &entry : map.value("profiles").toList()) {
        const auto record = entry.toMap(), saved = record.value("scope").toMap(), values = record.value("values").toMap();
        if (entry.metaType().id() != QMetaType::QVariantMap || !exact(record, {"scope", "values"}) ||
            record.value("scope").metaType().id() != QMetaType::QVariantMap || record.value("values").metaType().id() != QMetaType::QVariantMap ||
            !TerminalVoiceCoordinator::validatePublic(values, error) || !scopeValid(saved, values) || seen.contains(digest(saved)))
            return fail(error, "语音配置含无效、重复或跨版本身份；原文件保留");
        seen.insert(digest(saved)); profiles->append(record);
    }
    *selected = map.value("selected").toMap();
    return selected->isEmpty() || seen.contains(digest(*selected)) || fail(error, "语音选中身份不存在；没有启用播报");
}
bool writeSettings(const QString &file, const QByteArray &bytes, QString *error) {
    if (QFileInfo(file).isSymLink()) return fail(error, "语音配置不能为符号链接；原文件保留");
    QSaveFile output(file);
    if (!output.open(QIODevice::WriteOnly) || !output.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner) ||
        output.write(bytes) != bytes.size() || !output.commit()) return fail(error, "语音配置提交失败；原文件保留");
    return true;
}
struct Candidate {
    QString logical, speechKey, requestId, snapshotId, originNode, originSession, fingerprint;
    QVariantMap speech;
    qint64 deadline = 0;
};
}

struct TerminalVoiceCoordinator::Private {
    struct Active { Candidate candidate; QString route; };
    struct Seen { QString fingerprint; qint64 deadline = 0; };
    QPointer<SeasonConfiguration> season;
    QPointer<TerminalDataBus> bus;
    QPointer<TerminalTeamHost> team;
    QPointer<TerminalAdviceHost> advice;
    QPointer<ServiceHub> services;
    QString file, session = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QString status = QStringLiteral("自动语音未配置；本机数据及其他功能独立运行");
    QVariantMap values = defaults(), savedScope, publication, lastEvent;
    QMap<QString, Active> active;
    QMap<QString, Seen> seen;
    QSet<QString> ownSeen;
    QTimer timer;
    quint64 generation = 0;
    qint64 sequence = 0, publicationDeadline = 0, submitted = 0, cancelled = 0, published = 0, withdrawn = 0, deduplicated = 0, rejected = 0;
    qint64 lastUtc = 0, lastTick = 0;
    bool configured = false, valid = true, changing = false, destroying = false, scheduled = false, ticking = false, clockInvalid = false;
    bool modelConsent() const {
        return advice && yes(advice->current(), "voice_enabled") && advice->current().value("team_id") == values.value("team_id") && advice->current().value("robot_key") == values.value("robot_key");
    }
    bool scopeCurrent() const {
        return configured && valid && season && season->profileId() == "rmuc2027-regional-v1.0.0" &&
            yes(season->context(), "configuration_valid") && savedScope == scope(season, values) && !clockInvalid;
    }
    bool speechReady() const {
        if (!services) return false;
        const auto capabilities = services->speechDetails();
        return yes(capabilities, "active") && yes(capabilities, "keyed_cancellation") &&
            (!yes(capabilities, "playback") || yes(capabilities, "local_volume_applied"));
    }
    QString publishBlock() const {
        if (!scopeCurrent()) return QStringLiteral("语音配置范围或宿主时钟不可用");
        if (!yes(values, "team_enabled")) return QStringLiteral("队内语音未开启");
        if (!modelConsent()) return QStringLiteral("模型建议语音意向未开启或身份不匹配");
        if (!bus || !team || !team->active()) return QStringLiteral("可选队伍插件未启用；不自动改用其他播报路径");
        const auto current = team->current();
        if (current.value("team_id") != values.value("team_id") || current.value("robot_key") != values.value("robot_key") ||
            !yes(current, "can_send") || !current.value("allowed_uses").toList().contains("voice")) return QStringLiteral("队伍身份、发送许可或voice用途未授权");
        for (const auto &entry : current.value("allowed_fields").toList()) {
            const auto field = entry.toMap();
            if (field.value("source_id") == VoiceSource && field.value("item_id") == VoiceItem && field.value("uses").toList().contains("voice")) return {};
        }
        return QStringLiteral("队伍插件尚未精确授权terminal.advice.voice／announcement的voice用途");
    }
    QString receiveBlock() const {
        if (!scopeCurrent()) return QStringLiteral("语音配置范围或宿主时钟不可用");
        if (!yes(values, "team_enabled")) return QStringLiteral("队内语音未开启");
        if (!modelConsent()) return QStringLiteral("模型建议语音意向未开启或身份不匹配");
        if (!yes(values, "local_enabled")) return QStringLiteral("本机语音输出未授权");
        if (!team || !team->active()) return QStringLiteral("可选队伍插件未启用；队内模式不隐式降为本机播报");
        const auto current = team->current(); const auto local = current.value("node_id");
        if (current.value("team_id") != values.value("team_id") || current.value("robot_key") != values.value("robot_key")) return QStringLiteral("本机队伍共享身份与语音配置不匹配");
        if (!values.value("listener_node_ids").toList().contains(local)) return QStringLiteral("本节点不在明确接收列表内");
        if (values.value("speaker_node_id") != local) return QStringLiteral("本节点仅接收状态；只有指定节点负责队内播放");
        const auto view = team->teamView();
        if (view.value("context").toMap() != context(season) || view.value("team_id") != values.value("team_id") ||
            !yes(view, "channel_connected") || !yes(view, "source_proofs_verified") || !yes(view, "publisher_proof_verified")) return QStringLiteral("队伍完整视图、原来源或发布者证明尚未通过");
        if (!yes(view, "clock_sync_verified")) return QStringLiteral("队伍时钟映射尚未独立核验；队内播报不可用");
        return {};
    }
    bool observeClock(qint64 utc, qint64 now) {
        if (lastUtc && (utc < lastUtc || now < lastTick || std::abs((utc - lastUtc) - (now - lastTick)) > 250)) clockInvalid = true;
        lastUtc = utc; lastTick = now;
        return !clockInvalid;
    }
};

QVariantMap TerminalVoiceCoordinator::defaults() {
    return {{"team_id", ""}, {"robot_key", ""}, {"local_enabled", false}, {"team_enabled", false},
            {"speaker_node_id", ""}, {"listener_node_ids", QVariantList{}}, {"minimum_priority", "caution"}};
}
bool TerminalVoiceCoordinator::validatePublic(const QVariantMap &values, QString *error) {
    if (error) error->clear();
    if (!exact(values, {"team_id", "robot_key", "local_enabled", "team_enabled", "speaker_node_id", "listener_node_ids", "minimum_priority"}) ||
        !id(values.value("team_id"), 64) || !semanticRobot(values.value("robot_key")) ||
        values.value("local_enabled").metaType().id() != QMetaType::Bool || values.value("team_enabled").metaType().id() != QMetaType::Bool ||
        !text(values.value("speaker_node_id"), 64, true) || (!values.value("speaker_node_id").toString().isEmpty() && !node(values.value("speaker_node_id"))) ||
        values.value("listener_node_ids").metaType().id() != QMetaType::QVariantList || values.value("listener_node_ids").toList().size() > 16 ||
        !text(values.value("minimum_priority"), 16) || priority(values.value("minimum_priority").toString()) < 0)
        return fail(error, "语音配置须为明确的2027语义身份、输出意向、优先级和节点列表；不能传入音频或验证标记");
    QSet<QString> nodes;
    for (const auto &entry : values.value("listener_node_ids").toList()) {
        if (!node(entry) || nodes.contains(entry.toString())) return fail(error, "语音接收节点须逐项明确、互不重复且不含通配符");
        nodes.insert(entry.toString());
    }
    if (yes(values, "team_enabled") && (!node(values.value("speaker_node_id")) || !nodes.contains(values.value("speaker_node_id").toString())))
        return fail(error, "队内语音须指定唯一播放节点，并把该节点列入明确接收列表");
    return true;
}

TerminalVoiceCoordinator::TerminalVoiceCoordinator(SeasonConfiguration *season, TerminalDataBus *bus, TerminalTeamHost *team,
    TerminalAdviceHost *advice, ServiceHub *services, QString settingsFile, QObject *parent)
    : QObject(parent), d(std::make_unique<Private>()) {
    d->season = season; d->bus = bus; d->team = team; d->advice = advice; d->services = services; d->file = std::move(settingsFile);
    d->timer.setParent(this); d->timer.setInterval(250);
    connect(&d->timer, &QTimer::timeout, this, &TerminalVoiceCoordinator::tick);
    if (season) {
        connect(season, &SeasonConfiguration::aboutToChange, this, [this] { retire(); });
        connect(season, &SeasonConfiguration::contextChanged, this, [this] { load(); emit changed(); });
        connect(season, &SeasonConfiguration::stateChanged, this, &TerminalVoiceCoordinator::scheduleTick);
    }
    if (advice) {
        connect(advice, &TerminalAdviceHost::voiceRequested, this, [this](const QVariantMap &value) {
            const auto request = value.value("request_id").toString(); const auto generation = d->generation;
            QMetaObject::invokeMethod(this, [this, generation, request] { if (generation == d->generation) handleOwn(request); }, Qt::QueuedConnection);
        });
        connect(advice, &TerminalAdviceHost::voiceCancelled, this, [this](const QString &) { scheduleTick(); });
        connect(advice, &TerminalAdviceHost::changed, this, &TerminalVoiceCoordinator::scheduleTick);
        connect(advice, &QObject::destroyed, this, &TerminalVoiceCoordinator::scheduleTick);
    }
    if (team) {
        connect(team, &TerminalTeamHost::changed, this, &TerminalVoiceCoordinator::scheduleTick);
        connect(team, &QObject::destroyed, this, &TerminalVoiceCoordinator::scheduleTick);
    }
    if (bus) connect(bus, &TerminalDataBus::changed, this, &TerminalVoiceCoordinator::scheduleTick);
    if (services) connect(services, &ServiceHub::serviceStatusChanged, this, &TerminalVoiceCoordinator::scheduleTick);
    load();
}
TerminalVoiceCoordinator::~TerminalVoiceCoordinator() { d->destroying = true; retire(); }
QVariantMap TerminalVoiceCoordinator::current() const { return d->values; }
QString TerminalVoiceCoordinator::status() const { return d->status; }
bool TerminalVoiceCoordinator::editable() const { return lockReason().isEmpty(); }
QString TerminalVoiceCoordinator::lockReason() const {
    if (d->destroying || !d->season || d->file.isEmpty()) return QStringLiteral("语音配置宿主或保存路径不可用");
    if (d->changing) return QStringLiteral("正在保存语音配置");
    if (d->season->profileId() != "rmuc2027-regional-v1.0.0" || !yes(d->season->context(), "configuration_valid")) return QStringLiteral("须选择有效的2027正式规则范围");
    return d->season->lockReason();
}
bool TerminalVoiceCoordinator::reject(const QString &reason) { d->status = reason.left(512); emit changed(); return false; }
void TerminalVoiceCoordinator::load() {
    d->values = defaults(); d->savedScope.clear(); d->configured = false; d->valid = true;
    d->seen.clear(); d->ownSeen.clear(); d->clockInvalid = false; d->lastUtc = d->lastTick = 0;
    QVariantList profiles; QVariantMap selected; QString error;
    if (d->file.isEmpty() || !readSettings(d->file, &profiles, &selected, &error)) {
        d->valid = false; d->status = error.isEmpty() ? QStringLiteral("未提供语音配置路径；没有启用播报") : error; return;
    }
    for (const auto &entry : profiles) {
        const auto row = entry.toMap(), values = row.value("values").toMap(), saved = row.value("scope").toMap();
        if (saved == selected && saved == scope(d->season, values)) {
            d->values = values; d->savedScope = saved; d->configured = true;
            d->status = QStringLiteral("已读取语音偏好；仅处理之后通过接纳的新建议，不重播旧结果");
            return;
        }
    }
    d->status = QStringLiteral("当前身份尚未保存语音偏好；没有启用播报");
}
bool TerminalVoiceCoordinator::save(const QVariantMap &values) {
    if (QThread::currentThread() != thread()) return false;
    auto reason = lockReason();
    if (!reason.isEmpty() || !validatePublic(values, &reason)) return reject(reason);
    if (!QDir().mkpath(QFileInfo(d->file).absolutePath())) return reject(QStringLiteral("语音配置目录不可写"));
    QLockFile lock(d->file + ".lock"); if (!lock.tryLock(0)) return reject(QStringLiteral("语音配置由另一实例占用，原文件保留"));
    QVariantList profiles; QVariantMap selected;
    if (!readSettings(d->file, &profiles, &selected, &reason)) return reject(reason);
    const auto saved = scope(d->season, values); bool replaced = false;
    for (auto &entry : profiles) if (entry.toMap().value("scope").toMap() == saved) {
        entry = QVariantMap{{"scope", saved}, {"values", values}}; replaced = true; break;
    }
    if (!replaced) {
        if (profiles.size() >= 32) return reject(QStringLiteral("语音身份范围已达32项，未覆盖其他机器人配置"));
        profiles.append(QVariantMap{{"scope", saved}, {"values", values}});
    }
    const auto bytes = compact(QVariantMap{{"schema", 1}, {"selected", saved}, {"profiles", profiles}});
    if (bytes.size() > SettingsLimit || !writeSettings(d->file, bytes, &reason)) return reject(reason.isEmpty() ? QStringLiteral("语音配置超过64KiB，原文件保留") : reason);
    QPointer<TerminalVoiceCoordinator> alive(this); d->changing = true;
    const auto generation = d->generation + 1; retire();
    if (!alive || generation != d->generation) return false;
    if (d->savedScope != saved) { d->seen.clear(); d->ownSeen.clear(); }
    d->values = values; d->savedScope = saved; d->configured = d->valid = true; d->changing = false;
    // Explicitly saving retires old sound before establishing a new clock
    // baseline; a periodic notification never clears clock quarantine.
    d->clockInvalid = false; d->lastUtc = d->lastTick = 0;
    d->status = QStringLiteral("语音偏好已保存；旧播报及共享事件已取消，等待之后的新鲜建议");
    emit changed(); return true;
}
void TerminalVoiceCoordinator::scheduleTick() {
    if (d->destroying || d->scheduled) return;
    d->scheduled = true;
    QMetaObject::invokeMethod(this, [this] { d->scheduled = false; tick(); }, Qt::QueuedConnection);
}
void TerminalVoiceCoordinator::withdraw() {
    auto publication = std::move(d->publication); d->publication.clear(); d->publicationDeadline = 0;
    if (publication.isEmpty() || !d->bus || d->sequence >= Safe) return;
    bool present = false;
    for (const auto &entry : d->bus->view().value("items").toList()) {
        const auto row = entry.toMap();
        present = present || (row.value("context") == publication.value("context") && row.value("team_id") == publication.value("team_id") &&
            row.value("robot_key") == publication.value("robot_key") && row.value("source_id") == VoiceSource && row.value("session_id") == publication.value("session_id") &&
            row.value("item_id") == VoiceItem && row.value("sequence") == publication.value("sequence"));
    }
    // Explicit Bus clear/scope change must not reinsert a retired event.
    if (!present) return;
    publication["sequence"] = ++d->sequence; publication["lifecycle"] = "withdrawn";
    publication["produced_at_ms"] = QDateTime::currentMSecsSinceEpoch(); publication["ttl_ms"] = 100;
    QString error;
    QPointer<TerminalVoiceCoordinator> alive(this); const auto generation = d->generation;
    const bool accepted = d->bus->acceptLocal(publication, &error);
    if (alive && generation == d->generation && accepted) ++d->withdrawn;
}
void TerminalVoiceCoordinator::retire() {
    const auto generation = ++d->generation; d->timer.stop(); d->ticking = false;
    const auto active = std::move(d->active); d->active.clear();
    QPointer<TerminalVoiceCoordinator> alive(this);
    const QPointer<ServiceHub> services = d->services;
    for (auto it = active.cbegin(); it != active.cend(); ++it) {
        if (services) services->cancelTerminalSpeech(it.key());
        if (!alive || generation != d->generation) return;
        ++d->cancelled;
    }
    withdraw();
}

void TerminalVoiceCoordinator::handleOwn(const QString &requestId) {
    if (d->destroying || d->changing || !d->scopeCurrent() || !d->advice || !d->modelConsent()) return;
    const auto latest = d->advice->advice();
    const auto now = PacketObservation::steadyMilliseconds(), utc = QDateTime::currentMSecsSinceEpoch();
    qint64 expiry = 0, remaining = 0;
    if (!d->observeClock(utc, now) || !yes(latest, "fresh") || latest.value("request_id") != requestId || !id(latest.value("request_id")) ||
        !id(latest.value("snapshot_id")) || latest.value("source") != "terminal-advice-host" || latest.value("context").toMap() != context(d->season) ||
        !text(latest.value("summary"), 180) || priority(latest.value("priority").toString()) < 0 ||
        !integer(latest.value("expires_at_tick_ms"), now + 500, Safe, &expiry) || !integer(latest.value("remaining_ms"), 500, 10000, &remaining)) {
        ++d->rejected; d->status = QStringLiteral("建议语音已过期或未通过宿主来源／时间接纳"); emit changed(); return;
    }
    const auto ownKey = digest(QVariantList{requestId, latest.value("snapshot_id")});
    if (d->ownSeen.contains(ownKey)) { ++d->deduplicated; emit changed(); return; }
    if (d->ownSeen.size() >= MaximumSeen) { ++d->rejected; reject(QStringLiteral("当前身份语音去重记录已满；未重播或清除历史")); return; }
    d->ownSeen.insert(ownKey);
    if (priority(latest.value("priority").toString()) < priority(d->values.value("minimum_priority").toString())) {
        d->status = QStringLiteral("建议低于已保存的最低播报优先级；没有提交语音"); emit changed(); return;
    }
    const auto deadline = std::min(expiry, now + remaining);
    QPointer<TerminalVoiceCoordinator> alive(this); const auto generation = d->generation;
    if (yes(d->values, "team_enabled")) {
        const auto blocked = d->publishBlock();
        if (!blocked.isEmpty()) { ++d->rejected; reject(blocked); return; }
        withdraw(); if (!alive || generation != d->generation) return;
        if (d->sequence >= Safe) { reject(QStringLiteral("语音来源序号已耗尽；未重用旧序号")); return; }
        QVariantMap observation{{"schema", 3}, {"context", context(d->season)}, {"team_id", d->values.value("team_id")},
            {"robot_key", d->values.value("robot_key")}, {"source_id", VoiceSource}, {"sensor_id", "model-advice-host"},
            {"source_kind", "derived"}, {"session_id", d->session}, {"sequence", ++d->sequence}, {"item_id", VoiceItem},
            {"produced_at_ms", utc}, {"clock_domain", "host_utc"}, {"ttl_ms", deadline - now}, {"confidence", QVariant{}},
            {"validation", "derived"}, {"lifecycle", "active"}, {"data_type", "object"},
            {"value", QVariantMap{{"text", latest.value("summary")}, {"priority", latest.value("priority")},
                {"request_id", requestId}, {"snapshot_id", latest.value("snapshot_id")}}}};
        d->publication = observation; d->publicationDeadline = deadline;
        QString error; const bool accepted = d->bus->acceptLocal(observation, &error);
        if (!alive || generation != d->generation) return;
        if (!accepted) { d->publication.clear(); d->publicationDeadline = 0; ++d->rejected; reject(error); return; }
        ++d->published;
        d->status = QStringLiteral("已写入授权的推导播报事件，交由队伍插件汇总；本节点不另走本机播报路径");
        d->lastEvent = {{"route", "team_publish"}, {"request_id", requestId}, {"snapshot_id", latest.value("snapshot_id")},
            {"origin_session", d->session}, {"priority", latest.value("priority")}, {"deadline_tick_ms", deadline}};
        d->timer.start(); emit changed(); return;
    }
    if (!yes(d->values, "local_enabled")) { d->status = QStringLiteral("本机语音未授权；建议仍可显示于HUD"); emit changed(); return; }
    if (!d->services || d->active.size() >= MaximumSpeech) { ++d->rejected; reject(QStringLiteral("语音服务不可用或协调队列已满")); return; }
    Candidate candidate; candidate.logical = ownKey; candidate.speechKey = requestId; candidate.requestId = requestId;
    candidate.snapshotId = latest.value("snapshot_id").toString(); candidate.originSession = d->session; candidate.deadline = deadline;
    auto speech = latest; speech["source"] = "terminal-voice-coordinator"; speech["remaining_ms"] = deadline - now; speech["expires_at_tick_ms"] = deadline;
    candidate.speech = speech; d->active[requestId] = {candidate, "local"};
    const bool accepted = d->services->submitTerminalSpeech(speech);
    if (!alive || generation != d->generation) return;
    if (!accepted) { d->active.remove(requestId); ++d->rejected; reject(QStringLiteral("语音服务未接纳；未声称已播放")); return; }
    ++d->submitted; d->lastEvent = {{"route", "local"}, {"request_id", requestId}, {"snapshot_id", candidate.snapshotId},
        {"priority", latest.value("priority")}, {"deadline_tick_ms", deadline}};
    d->status = QStringLiteral("本机有效建议已提交语音服务；实际合成／播放由服务状态报告");
    d->timer.start(); emit changed();
}

void TerminalVoiceCoordinator::tick() {
    if (d->destroying || d->changing || d->ticking) return;
    d->ticking = true;
    const auto now = PacketObservation::steadyMilliseconds(), utc = QDateTime::currentMSecsSinceEpoch();
    d->observeClock(utc, now);
    QPointer<TerminalVoiceCoordinator> alive(this); const auto generation = d->generation;
    const auto own = d->advice ? d->advice->advice() : QVariantMap{};
    const bool localValid = d->scopeCurrent() && d->modelConsent() && yes(d->values, "local_enabled") && !yes(d->values, "team_enabled") && yes(own, "fresh");
    const auto teamBlocked = d->receiveBlock();
    QMap<QString, Candidate> candidates;
    if (teamBlocked.isEmpty() && d->team) {
        const auto view = d->team->teamView(), config = d->team->current();
        QMap<QString, QString> identities{{config.value("node_id").toString(), config.value("robot_key").toString()}};
        for (const auto &entry : config.value("peers").toList()) identities[entry.toMap().value("node_id").toString()] = entry.toMap().value("robot_key").toString();
        for (const auto &entry : view.value("items").toList()) {
            const auto row = entry.toMap();
            if (row.value("source_id") != VoiceSource || row.value("item_id") != VoiceItem) continue;
            const auto value = row.value("value").toMap(); qint64 remaining = 0, produced = 0, ttl = 0;
            if (row.value("state") != "fresh" || row.value("lifecycle") != "active" || row.value("source_kind") != "derived" || row.value("validation") != "derived" ||
                row.value("data_type") != "object" || row.value("value").metaType().id() != QMetaType::QVariantMap ||
                row.value("context").toMap() != context(d->season) || row.value("team_id") != d->values.value("team_id") ||
                !no(row, "mock") || !no(row, "authoritative") || !yes(row, "host_source_proof_verified") || !yes(row, "peer_authenticated") || !yes(row, "clock_sync_verified") ||
                row.value("clock_domain") != "host_utc" || !row.value("allowed_uses").toList().contains("voice") ||
                !id(row.value("source_node"), 64) || identities.value(row.value("source_node").toString()) != row.value("robot_key").toString() ||
                !id(row.value("session_id")) || !id(row.value("node_session_id")) || !integer(row.value("sequence"), 1, Safe) ||
                !id(row.value("source_proof_ref"), 128) || !exact(value, {"text", "priority", "request_id", "snapshot_id"}) ||
                !text(value.value("text"), 180) || !id(value.value("request_id")) || !id(value.value("snapshot_id")) ||
                priority(value.value("priority").toString()) < priority(d->values.value("minimum_priority").toString()) ||
                !integer(row.value("remaining_ms"), 500, 10000, &remaining) || !integer(row.value("ttl_ms"), 100, 10000, &ttl) ||
                !integer(row.value("produced_at_ms"), 1, utc, &produced) || utc - produced >= ttl || remaining > ttl - (utc - produced)) continue;
            Candidate candidate; candidate.requestId = value.value("request_id").toString(); candidate.snapshotId = value.value("snapshot_id").toString();
            candidate.originNode = row.value("source_node").toString(); candidate.originSession = row.value("session_id").toString();
            candidate.logical = digest(QVariantList{candidate.originNode, row.value("node_session_id"), candidate.originSession, candidate.requestId, candidate.snapshotId});
            candidate.speechKey = "team-voice." + candidate.logical;
            candidate.deadline = now + remaining;
            candidate.fingerprint = digest(QVariantMap{{"origin", candidate.originNode}, {"session", candidate.originSession}, {"sequence", row.value("sequence")},
                {"produced_at_ms", produced}, {"ttl_ms", ttl}, {"value", value}, {"robot_key", row.value("robot_key")}});
            candidate.speech = {{"request_id", candidate.speechKey}, {"fresh", true}, {"summary", value.value("text")}, {"priority", value.value("priority")},
                {"remaining_ms", remaining}, {"expires_at_tick_ms", candidate.deadline}, {"voice_scope", "local_only"}, {"source", "terminal-voice-coordinator"}};
            if (!candidates.contains(candidate.logical)) candidates[candidate.logical] = candidate;
        }
    }
    QStringList cancelKeys;
    for (auto it = d->active.cbegin(); it != d->active.cend(); ++it) {
        const auto &active = it.value();
        const bool valid = active.route == "local" ? localValid && own.value("request_id") == active.candidate.requestId && own.value("snapshot_id") == active.candidate.snapshotId
            : teamBlocked.isEmpty() && candidates.contains(active.candidate.logical) && candidates.value(active.candidate.logical).fingerprint == active.candidate.fingerprint;
        if (!valid || active.candidate.deadline <= now) cancelKeys.append(it.key());
    }
    for (const auto &key : cancelKeys) {
        d->active.remove(key);
        if (d->services) d->services->cancelTerminalSpeech(key);
        if (!alive || generation != d->generation) return;
        ++d->cancelled;
    }
    for (auto it = d->active.begin(); it != d->active.end(); ++it)
        if (it->route == "team_designated" && candidates.contains(it->candidate.logical))
            it->candidate.deadline = std::min(it->candidate.deadline, candidates.value(it->candidate.logical).deadline);
    if (!d->publication.isEmpty()) {
        bool present = false;
        if (d->bus) for (const auto &entry : d->bus->view().value("items").toList()) {
            const auto row = entry.toMap();
            present = present || (row.value("source_id") == VoiceSource && row.value("session_id") == d->publication.value("session_id") &&
                row.value("sequence") == d->publication.value("sequence") && row.value("state") == "fresh");
        }
        if (!d->publishBlock().isEmpty() || !yes(own, "fresh") || own.value("request_id") != d->publication.value("value").toMap().value("request_id") || d->publicationDeadline <= now || !present) {
            withdraw(); if (!alive || generation != d->generation) return;
        }
    }
    for (auto it = candidates.cbegin(); it != candidates.cend(); ++it) {
        auto candidate = it.value();
        if (d->seen.contains(candidate.logical)) continue;
        if (d->seen.size() >= MaximumSeen || d->active.size() >= MaximumSpeech || !d->services) continue;
        // A repeated cut can only retain or shorten the first observed deadline.
        // It never renews a previously submitted announcement or retries a failed
        // audio submission as though it were a new origin event.
        d->seen[candidate.logical] = {candidate.fingerprint, candidate.deadline};
        d->active[candidate.speechKey] = {candidate, "team_designated"};
        const bool accepted = d->services->submitTerminalSpeech(candidate.speech);
        if (!alive || generation != d->generation) return;
        if (accepted) {
            ++d->submitted;
            d->lastEvent = {{"route", "team_designated"}, {"origin_node", candidate.originNode}, {"origin_session", candidate.originSession},
                {"request_id", candidate.requestId}, {"snapshot_id", candidate.snapshotId}, {"deadline_tick_ms", candidate.deadline}};
            d->status = QStringLiteral("指定播放节点已提交核验后的队内事件；其他节点不重复播放");
        } else { d->active.remove(candidate.speechKey); ++d->rejected; d->status = QStringLiteral("语音服务未接纳队内事件；未声称已播放"); }
    }
    if (yes(d->values, "team_enabled") && !teamBlocked.isEmpty() && d->active.isEmpty() && d->publication.isEmpty()) d->status = teamBlocked;
    if (d->clockInvalid) d->status = QStringLiteral("宿主时钟异常；已停止并取消播报，不续命旧事件");
    if (d->active.isEmpty() && d->publication.isEmpty()) d->timer.stop(); else if (!d->timer.isActive()) d->timer.start();
    d->ticking = false; emit changed();
}

QVariantMap TerminalVoiceCoordinator::details() const {
    const auto now = PacketObservation::steadyMilliseconds(); QVariantList active;
    for (auto it = d->active.cbegin(); it != d->active.cend(); ++it) {
        const auto &value = it.value();
        active.append(QVariantMap{{"speech_key", it.key()}, {"route", value.route}, {"origin_node", value.candidate.originNode},
            {"origin_session", value.candidate.originSession}, {"request_id", value.candidate.requestId}, {"snapshot_id", value.candidate.snapshotId},
            {"remaining_ms", qMax<qint64>(0, value.candidate.deadline - now)}});
    }
    auto last = d->lastEvent;
    if (last.contains("deadline_tick_ms")) last["remaining_ms"] = qMax<qint64>(0, last.value("deadline_tick_ms").toLongLong() - now);
    const auto publishBlock = d->publishBlock(), receiveBlock = d->receiveBlock();
    return {{"context", context(d->season)}, {"environment", d->season ? d->season->environment() : QString{}},
        {"configuration_valid", d->valid && d->configured}, {"route", yes(d->values, "team_enabled") ? "team_designated" : yes(d->values, "local_enabled") ? "local" : "disabled"},
        {"local_node_id", d->team ? d->team->current().value("node_id") : QVariant{}}, {"model_voice_enabled", d->modelConsent()},
        {"local_route_ready", d->scopeCurrent() && d->modelConsent() && yes(d->values, "local_enabled") && !yes(d->values, "team_enabled") && d->speechReady()},
        {"team_publish_ready", publishBlock.isEmpty()}, {"team_receive_ready", receiveBlock.isEmpty()},
        {"team_block_reason", receiveBlock}, {"publish_block_reason", publishBlock}, {"source_id", VoiceSource}, {"item_id", VoiceItem},
        {"active_announcements", active}, {"last_event", last}, {"submitted", d->submitted}, {"cancelled", d->cancelled},
        {"published", d->published}, {"withdrawn", d->withdrawn}, {"deduplicated", d->deduplicated}, {"rejected", d->rejected},
        {"dedup_entries", d->seen.size() + d->ownSeen.size()}, {"dedup_limit_per_route", MaximumSeen}, {"clock_invalid", d->clockInvalid},
        {"speech_details", d->services ? d->services->speechDetails() : QVariantMap{}}, {"speech_status", d->services ? d->services->speechStatus() : QStringLiteral("语音服务宿主未接入")},
        {"authoritative", false}, {"automatic_actions_allowed", false}, {"local_bus_independent", true}, {"implicit_fallback", false}};
}
