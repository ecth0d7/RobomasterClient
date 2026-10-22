#include "TeamConfiguration.h"
#include "ClientBackend.h"
#include "OperatorPreferences.h"
#include "PluginRuntime.h"
#include "RobotIdentity.h"
#include "ServiceHub.h"
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLockFile>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QUrl>
#include <cmath>

namespace {
constexpr qsizetype MaximumBytes = 128 * 1024;
constexpr qsizetype JournalBytes = 32 * 1024;
const QStringList Categories{"health", "resources", "position", "objective", "advice",
                             "sensorEvents", "visionDiscoveries", "derived"};
const QStringList Uses{"hud", "alerts", "localAi", "externalAi", "voice"};
bool fail(QString *error, const QString &message) {
    if (error) *error = message;
    return false;
}
bool line(const QVariant &value, qsizetype maximum = 512) {
    if (value.metaType().id() != QMetaType::QString || value.toString().size() > maximum)
        return false;
    for (const auto ch : value.toString())
        if (ch.category() == QChar::Other_Control || ch.category() == QChar::Separator_Line ||
            ch.category() == QChar::Separator_Paragraph)
            return false;
    return true;
}
bool identifier(const QVariant &value, bool emptyAllowed) {
    static const QRegularExpression expression(QStringLiteral("\\A[A-Za-z0-9_.-]{1,64}\\z"));
    return line(value, 64) && ((emptyAllowed && value.toString().isEmpty()) ||
                              expression.match(value.toString()).hasMatch());
}
bool number(const QVariant &value, int minimum, int maximum) {
    const auto type = value.metaType().id();
    if (type != QMetaType::Int && type != QMetaType::UInt && type != QMetaType::LongLong &&
        type != QMetaType::ULongLong && type != QMetaType::Double)
        return false;
    const auto numeric = value.toDouble();
    return std::isfinite(numeric) && std::floor(numeric) == numeric &&
           numeric >= minimum && numeric <= maximum;
}
bool digits(const QVariant &value, int minimum, int maximum) {
    static const QRegularExpression expression(QStringLiteral("\\A(?:0|[1-9][0-9]{0,5})\\z"));
    if (!line(value, 6) || !expression.match(value.toString()).hasMatch()) return false;
    bool ok = false;
    const auto integer = value.toString().toInt(&ok);
    return ok && integer >= minimum && integer <= maximum;
}
bool fingerprint(const QVariant &value, bool emptyAllowed = false) {
    static const QRegularExpression expression(QStringLiteral("\\A[0-9A-Fa-f]{64}\\z"));
    return line(value, 64) && ((emptyAllowed && value.toString().isEmpty()) ||
                              expression.match(value.toString()).hasMatch());
}
bool scopeValid(const QVariantMap &scope) {
    const auto id = scope.value("robot_id");
    return scope.size() == 4 && number(id, 0, 109) &&
           (id.toInt() == 0 || RobotIdentity::valid(id.toInt())) &&
           line(scope.value("host"), 253) && !scope.value("host").toString().isEmpty() &&
           number(scope.value("port"), 1, 65535) && line(scope.value("protocol_id"), 128) &&
           !scope.value("protocol_id").toString().isEmpty();
}
bool writeAtomic(const QString &path, const QByteArray &bytes, QString *error) {
    if (QFileInfo(path).isSymLink()) return fail(error, "配置文件不可为符号链接，原文件保留");
    QSaveFile output(path);
    if (!output.open(QIODevice::WriteOnly) ||
        !output.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner) ||
        output.write(bytes) != bytes.size() || !output.commit())
        return fail(error, "队伍配置未保存，旧文件保留");
    return true;
}
QVariantMap emptyPermissions() {
    QVariantMap result;
    for (const auto &category : Categories) result[category] = QVariantMap{};
    return result;
}
}

QVariantMap TeamConfiguration::defaults() {
    return {{"networkEnabled", false}, {"teamId", ""}, {"nodeId", ""},
            {"displayName", ""}, {"endpoint", "mqtts://127.0.0.1:8883"}, {"caFile", ""},
            {"certificateFile", ""}, {"signingKeyFileEnv", "ROBOMASTER_NODE_SIGNING_KEY_FILE"},
            {"heartbeatMs", "1000"}, {"timeoutMs", "3000"}, {"publisherId", ""},
            {"voiceNodeId", ""}, {"selfListen", false}, {"voiceOutputGroup", ""},
            {"voiceOutputNodeId", ""}, {"peers", QVariantList{}},
            {"permissions", emptyPermissions()}, {"matchId", ""}, {"epoch", ""},
            {"configurationRevision", ""}, {"clocksSynchronized", false},
            {"maxClockSkewMs", "250"}, {"teamWideSharingConfirmed", false},
            {"canSend", false}, {"canAggregate", false}};
}

bool TeamConfiguration::validate(const QVariantMap &values, int robotId, QString *error) {
    if (error) error->clear();
    const auto fields = defaults();
    if (values.size() != fields.size()) return fail(error, "队伍配置字段不完整或含未知字段");
    for (auto it = fields.cbegin(); it != fields.cend(); ++it) {
        if (!values.contains(it.key())) return fail(error, "队伍配置缺少必要字段");
        const auto value = values.value(it.key());
        if (it.value().metaType().id() == QMetaType::Bool &&
            value.metaType().id() != QMetaType::Bool)
            return fail(error, "队伍开关须为明确布尔值");
        if (it.value().metaType().id() == QMetaType::QString && !line(value))
            return fail(error, "队伍文本过长、类型错误或含换行／控制字符");
    }
    if (robotId != 0 && !RobotIdentity::valid(robotId))
        return fail(error, "队伍配置的本机机器人身份不合法");
    const bool enabled = values.value("networkEnabled").toBool();
    for (const auto &key : {"teamId", "nodeId", "matchId", "epoch", "configurationRevision",
                            "publisherId", "voiceNodeId", "voiceOutputGroup", "voiceOutputNodeId"})
        if (!identifier(values.value(key), true))
            return fail(error, "队伍／节点／比赛／轮次标识限64位ASCII字母、数字、点、横线和下划线");
    static const QRegularExpression environment(QStringLiteral("\\A[A-Za-z_][A-Za-z0-9_]{0,95}\\z"));
    const auto keyEnv = values.value("signingKeyFileEnv").toString();
    if ((!keyEnv.isEmpty() && !environment.match(keyEnv).hasMatch()) || (enabled && keyEnv.isEmpty()))
        return fail(error, "签名密钥只填写文件路径环境变量名，不填写路径值或密钥内容");
    if (!digits(values.value("heartbeatMs"), 500, 5000) ||
        !digits(values.value("timeoutMs"), 1500, 30000) ||
        values.value("timeoutMs").toString().toInt() < 3 * values.value("heartbeatMs").toString().toInt() ||
        !digits(values.value("maxClockSkewMs"), 0, 1000))
        return fail(error, "心跳须500–5000ms，超时至少三次心跳且不超过30000ms，时差0–1000ms");
    const QUrl endpoint(values.value("endpoint").toString(), QUrl::StrictMode);
    if (!values.value("endpoint").toString().startsWith("mqtts://") || !endpoint.isValid() ||
        endpoint.scheme() != "mqtts" || endpoint.host().isEmpty() ||
        endpoint.port(-1) < 1 || endpoint.port(-1) > 65535 || !endpoint.userInfo().isEmpty() ||
        endpoint.hasQuery() || endpoint.hasFragment() ||
        !endpoint.path().isEmpty())
        return fail(error, "队内端点须为mqtts://主机:端口，不含账号、路径或查询参数；与官方选手端连接分离");
    if (values.value("permissions").metaType().id() != QMetaType::QVariantMap)
        return fail(error, "共享用途须为逐类别白名单");
    const auto permissions = values.value("permissions").toMap();
    for (auto category = permissions.cbegin(); category != permissions.cend(); ++category) {
        if (!Categories.contains(category.key()) || category.value().metaType().id() != QMetaType::QVariantMap)
            return fail(error, "共享白名单含未知类别或错误结构");
        const auto uses = category.value().toMap();
        for (auto use = uses.cbegin(); use != uses.cend(); ++use)
            if (!Uses.contains(use.key()) || use.value().metaType().id() != QMetaType::Bool ||
                !use.value().toBool())
                return fail(error, "共享用途只保存明确允许的true布尔项；未授权项省略");
    }
    if (values.value("peers").metaType().id() != QMetaType::QVariantList ||
        values.value("peers").toList().size() > 15)
        return fail(error, "最多保存15个其他可信队伍节点");
    static const QSet<QString> peerFields{"nodeId", "robotId", "label", "fingerprint", "certificateFile",
                                          "canSend", "canAggregate", "canVoice", "canHear"};
    QSet<QString> nodes{values.value("nodeId").toString()};
    QSet<int> robots;
    if (robotId) robots.insert(robotId);
    bool publisherAllowed = values.value("publisherId") == values.value("nodeId") &&
                            !values.value("nodeId").toString().isEmpty() && values.value("canAggregate").toBool();
    QSet<QString> voiceNodes;
    QSet<QString> hearNodes;
    for (const auto &item : values.value("peers").toList()) {
        if (item.metaType().id() != QMetaType::QVariantMap) return fail(error, "可信节点须为对象");
        const auto peer = item.toMap();
        if (peer.size() != peerFields.size()) return fail(error, "可信节点字段不完整或未知");
        for (auto it = peer.cbegin(); it != peer.cend(); ++it)
            if (!peerFields.contains(it.key())) return fail(error, "可信节点含未知字段");
        for (const auto &key : {"canSend", "canAggregate", "canVoice", "canHear"})
            if (peer.value(key).metaType().id() != QMetaType::Bool)
                return fail(error, "可信节点权限须为明确布尔值");
        const int peerRobot = peer.value("robotId").toInt();
        const auto node = peer.value("nodeId").toString();
        if (!identifier(peer.value("nodeId"), false) || nodes.contains(node) ||
            !number(peer.value("robotId"), 1, 109) || !RobotIdentity::valid(peerRobot) ||
            robots.contains(peerRobot) || (robotId && (peerRobot > 100) != (robotId > 100)) ||
            !line(peer.value("label")) || !line(peer.value("certificateFile")) ||
            !fingerprint(peer.value("fingerprint"), !enabled) ||
            (enabled && peer.value("certificateFile").toString().trimmed().isEmpty()))
            return fail(error, "可信节点身份／机器人重复、跨阵营或缺少SPKI指纹／证书引用");
        nodes.insert(node);
        robots.insert(peerRobot);
        if (peer.value("canAggregate").toBool() && node == values.value("publisherId").toString())
            publisherAllowed = true;
        if (peer.value("canVoice").toBool()) voiceNodes.insert(node);
        if (peer.value("canHear").toBool()) hearNodes.insert(node);
    }
    // Voice values are preferences only. The current aggregator never sends audio.
    const auto own = values.value("nodeId").toString();
    if ((!values.value("publisherId").toString().isEmpty() && !publisherAllowed) ||
        (values.value("selfListen").toBool() &&
         (values.value("voiceOutputGroup").toString().isEmpty() ||
          values.value("voiceOutputNodeId").toString().isEmpty())))
        return fail(error, "汇总发布节点须明确授权；队内收听须指定输出组和唯一播放节点");
    if ((!values.value("voiceNodeId").toString().isEmpty() &&
         values.value("voiceNodeId").toString() != own &&
         !voiceNodes.contains(values.value("voiceNodeId").toString())) ||
        (!values.value("voiceOutputNodeId").toString().isEmpty() &&
         values.value("voiceOutputNodeId").toString() != own &&
         !hearNodes.contains(values.value("voiceOutputNodeId").toString())))
        return fail(error, "语音播报／收听节点须在明确授权名单内；当前仅保存偏好");
    if (enabled) {
        for (const auto &key : {"teamId", "nodeId", "matchId", "epoch", "configurationRevision", "publisherId"})
            if (values.value(key).toString().isEmpty()) return fail(error, "启用前填写完整队伍、节点、比赛、全新轮次和配置版本");
        if (!robotId || values.value("caFile").toString().trimmed().isEmpty() ||
            values.value("certificateFile").toString().trimmed().isEmpty() || !publisherAllowed ||
            !values.value("clocksSynchronized").toBool() || !values.value("teamWideSharingConfirmed").toBool())
            return fail(error, "启用须明确机器人、证书引用、授权汇总节点、时钟同步和全队披露同意");
    }
    return true;
}

TeamConfiguration::TeamConfiguration(ClientBackend *backend, PluginRuntime *runtime,
                                       ServiceHub *services, OperatorPreferences *phase,
                                       QString file, QString protocol, QObject *parent)
    : QObject(parent), m_backend(backend), m_runtime(runtime), m_services(services), m_phase(phase),
      m_file(QFileInfo(std::move(file)).absoluteFilePath()), m_protocol(std::move(protocol)) {
    if (backend) {
        connect(backend, &ClientBackend::identityChanged, this, &TeamConfiguration::synchronize);
        connect(backend, &ClientBackend::connectionOptionsChanged, this, &TeamConfiguration::synchronize);
    }
    if (phase) connect(phase, &OperatorPreferences::stateChanged, this, &TeamConfiguration::stateChanged);
    if (services) connect(services, &ServiceHub::serviceStatusChanged, this, &TeamConfiguration::stateChanged);
    if (runtime) {
        QPointer<TeamConfiguration> alive(this);
        runtime->setOptionalActivationGuard("aggregation", [alive](const QVariantMap &configuration, QString *error) {
            return alive ? alive->authorizeActivation(configuration, error)
                         : fail(error, "队伍配置宿主已关闭，不能恢复旧节点");
        });
        connect(runtime, &PluginRuntime::changed, this, &TeamConfiguration::stateChanged);
    }
    synchronize();
}

QVariantMap TeamConfiguration::scope() const {
    return {{"robot_id", m_backend ? m_backend->clientId() : 0},
            {"host", m_backend ? m_backend->host().trimmed().toLower() : QString{}},
            {"port", m_backend ? m_backend->port() : 0}, {"protocol_id", m_protocol}};
}
QString TeamConfiguration::lockReason() const {
    if (!m_backend || !m_runtime || !m_services || !m_phase) return "队伍配置宿主不可用";
    if (m_saving) return "正在保存队伍配置";
    if (m_backend->clientId() == 0 && !m_backend->connected() && !m_backend->connecting()) return {};
    return m_phase->lockReason();
}
QVariantMap TeamConfiguration::state() const {
    const auto details = m_services ? m_services->aggregationDetails() : QVariantMap{};
    const bool active = details.value("active").toBool();
    return {{"status", !m_activationError.isEmpty() ? m_activationError : m_status},
            {"health", !m_activationError.isEmpty() ? "error" : active ? "configured" : "disabled"},
            {"scope", m_scope}, {"configuration_revision", qulonglong(m_revision)},
            {"plugin_id", m_runtime ? m_runtime->selectedPlugin("aggregation") : QString{}},
            {"service_status", m_services ? m_services->aggregationStatus() : QStringLiteral("宿主不可用")},
            {"active", active}, {"network_connected", details.value("connected", false)},
            {"saved_network_intent", m_values.value("networkEnabled", false)},
            {"activation_requires_save", !m_activationReady}, {"team_voice_available", false},
            {"credential_reference_only", true}, {"epoch_reuse_allowed", false}};
}

bool TeamConfiguration::readProfiles(QVariantList *profiles, QString *error) const {
    profiles->clear();
    if (!QFileInfo::exists(m_file)) return true;
    if (QFileInfo(m_file).isSymLink()) return fail(error, "队伍配置不可为符号链接，原文件保留");
    QFile input(m_file);
    if (!input.open(QIODevice::ReadOnly)) return fail(error, "队伍配置无法读取，原文件保留");
    const auto bytes = input.read(MaximumBytes + 1);
    QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(bytes, &parse);
    const auto root = document.object();
    if (bytes.size() > MaximumBytes || parse.error != QJsonParseError::NoError || !document.isObject() ||
        root.size() != 2 || !root.value("schema").isDouble() || root.value("schema").toDouble() != 1 ||
        !root.value("profiles").isArray() || root.value("profiles").toArray().size() > 32)
        return fail(error, "队伍配置版本／结构／容量无效，原文件保留");
    for (const auto &entry : root.value("profiles").toArray()) {
        if (!entry.isObject()) return fail(error, "队伍配置记录无效，原文件保留");
        const auto profile = entry.toObject().toVariantMap();
        const auto selected = profile.value("scope").toMap();
        if (profile.size() != 2 || !scopeValid(selected) ||
            profile.value("values").metaType().id() != QMetaType::QVariantMap ||
            !validate(profile.value("values").toMap(), selected.value("robot_id").toInt(), error))
            return fail(error, "队伍配置含非法范围／字段，原文件保留");
        for (const auto &previous : *profiles)
            if (previous.toMap().value("scope").toMap() == selected)
                return fail(error, "队伍配置含重复身份范围，原文件保留");
        profiles->append(profile);
    }
    return true;
}
bool TeamConfiguration::writeProfile(const QVariantMap &values, QString *error) {
    if (!scopeValid(m_scope) || !QDir().mkpath(QFileInfo(m_file).absolutePath()))
        return fail(error, "队伍配置范围／保存目录无效");
    QLockFile lock(m_file + ".lock");
    if (!lock.tryLock(0)) return fail(error, "另一实例正在保存队伍配置，请稍后重试");
    QVariantList profiles;
    if (!readProfiles(&profiles, error)) return false;
    const QVariantMap next{{"scope", m_scope}, {"values", values}};
    bool replaced = false;
    for (auto &entry : profiles)
        if (entry.toMap().value("scope").toMap() == m_scope) {
            entry = next;
            replaced = true;
            break;
        }
    if (!replaced) profiles.append(next);
    const auto bytes = QJsonDocument(QJsonObject{{"schema", 1},
                                                {"profiles", QJsonArray::fromVariantList(profiles)}}).toJson();
    if (profiles.size() > 32 || bytes.size() > MaximumBytes)
        return fail(error, "队伍配置容量已满，未覆盖原文件");
    return writeAtomic(m_file, bytes, error);
}

void TeamConfiguration::synchronize() {
    const auto selected = scope();
    if (selected == m_scope) return;
    m_scope = selected;
    m_activationReady = false;
    const auto revision = ++m_revision;
    QPointer<TeamConfiguration> alive(this);
    const auto selectedPlugin = m_runtime && !m_runtime->selectedPlugin("aggregation").isEmpty()
        ? m_runtime->selectedPlugin("aggregation") : QStringLiteral("team.aggregate.v2");
    if (m_runtime) m_runtime->retireOptional("aggregation");
    if (!alive || revision != m_revision) return;
    // Clear the retained native profile as well as stopping the endpoint. The
    // plugin manager must not revive a previously selected robot's credentials.
    if (m_runtime) m_runtime->configureOptional("aggregation", selectedPlugin, {}, false,
                                               "请在赛外保存当前身份的完整队伍配置后启用");
    if (!alive || revision != m_revision) return;
    QVariantList profiles;
    QString error;
    const bool read = readProfiles(&profiles, &error);
    m_values = defaults();
    if (read)
        for (const auto &entry : profiles)
            if (entry.toMap().value("scope").toMap() == selected)
                m_values = entry.toMap().value("values").toMap();
    m_activationError = read ? QString{} : error;
    m_status = read ? QStringLiteral("已载入本机器人／选手端范围的队伍配置；未连接网络，启用须赛外重新保存并使用全新共享轮次")
                    : error;
    emit currentChanged();
    if (!alive || revision != m_revision) return;
    emit scopeChanged();
    if (alive && revision == m_revision) emit stateChanged();
}

bool TeamConfiguration::nativeConfiguration(const QVariantMap &values, QVariantMap *native, QString *error) const {
    native->clear();
    const auto directory = QFileInfo(m_file).absoluteDir();
    const auto path = [&directory](const QString &reference) {
        return reference.isEmpty() ? QString{} : QDir::cleanPath(directory.absoluteFilePath(reference));
    };
    const auto key = qEnvironmentVariable(values.value("signingKeyFileEnv").toString().toLatin1().constData());
    if (values.value("networkEnabled").toBool() &&
        (key.isEmpty() || !line(QVariant(key), 4096)))
        return fail(error, "签名密钥文件路径环境变量缺失或无效；配置已保存，队内网络未启用");
    QVariantList peers;
    for (const auto &item : values.value("peers").toList()) {
        const auto peer = item.toMap();
        peers.append(QVariantMap{{"node_id", peer.value("nodeId")}, {"robot_id", peer.value("robotId").toInt()},
                                 {"certificate_file", path(peer.value("certificateFile").toString())},
                                 {"fingerprint", peer.value("fingerprint").toString().toLower()},
                                 {"can_send", peer.value("canSend")}, {"can_aggregate", peer.value("canAggregate")},
                                 {"can_voice", peer.value("canVoice")}, {"can_hear", peer.value("canHear")}});
    }
    QStringList categories, uses;
    QVariantMap categoryPermissions;
    const auto permissions = values.value("permissions").toMap();
    for (const auto &category : Categories) {
        if (category == "advice") continue; // No advisory peer messages in this data-source contract.
        const auto allowed = permissions.value(category).toMap();
        QVariantList granted;
        for (const auto &use : Uses)
            if (allowed.value(use).toBool()) {
                granted.append(use);
                if (!uses.contains(use)) uses.append(use);
            }
        if (!granted.isEmpty()) {
            categories.append(category);
            categoryPermissions[category] = granted;
        }
    }
    *native = {{"team_id", values.value("teamId")}, {"node_id", values.value("nodeId")},
               {"robot_id", m_scope.value("robot_id").toInt()}, {"match_id", values.value("matchId")},
               {"epoch", values.value("epoch")}, {"endpoint", values.value("endpoint")},
               {"ca_file", path(values.value("caFile").toString())},
               {"certificate_file", path(values.value("certificateFile").toString())},
               {"signing_key_file", path(key)}, {"peers", peers}, {"can_send", values.value("canSend")},
               {"can_aggregate", values.value("canAggregate")},
               {"heartbeat_ms", values.value("heartbeatMs").toString().toInt()},
               {"timeout_ms", values.value("timeoutMs").toString().toInt()},
               {"publisher_id", values.value("publisherId")},
               {"max_clock_skew_ms", values.value("maxClockSkewMs").toString().toInt()},
               {"clocks_synchronized", values.value("clocksSynchronized")},
               {"team_wide_sharing_confirmed", values.value("teamWideSharingConfirmed")},
               {"allowed_categories", categories}, {"allowed_uses", uses},
               {"category_permissions", categoryPermissions},
               {"configuration_revision", values.value("configurationRevision")}};
    return true;
}

bool TeamConfiguration::consumeEpoch(const QVariantMap &configuration, QString *error) {
    const auto path = m_file + ".epochs.json";
    if (!QDir().mkpath(QFileInfo(path).absolutePath())) return fail(error, "共享轮次账本目录不可写");
    QLockFile lock(path + ".lock");
    if (!lock.tryLock(0)) return fail(error, "共享轮次账本正在由另一实例使用，请稍后重试");
    QJsonArray used;
    if (QFileInfo(path).isSymLink()) return fail(error, "共享轮次账本不可为符号链接，未启用网络");
    if (QFileInfo::exists(path)) {
        QFile input(path);
        if (!input.open(QIODevice::ReadOnly)) return fail(error, "共享轮次账本无法读取，未启用网络");
        const auto bytes = input.read(JournalBytes + 1);
        QJsonParseError parse;
        const auto document = QJsonDocument::fromJson(bytes, &parse);
        const auto root = document.object();
        if (bytes.size() > JournalBytes || parse.error != QJsonParseError::NoError || !document.isObject() ||
            root.size() != 2 || !root.value("schema").isDouble() || root.value("schema").toDouble() != 1 ||
            !root.value("used").isArray() || root.value("used").toArray().size() > 256)
            return fail(error, "共享轮次账本无效，原文件保留；需人工恢复，禁止自动清空");
        used = root.value("used").toArray();
        QSet<QString> seen;
        for (const auto &item : used) {
            const auto digest = item.toString();
            if (!item.isString() || !fingerprint(QVariant(digest)) || seen.contains(digest))
                return fail(error, "共享轮次账本含非法或重复项，未启用网络");
            seen.insert(digest);
        }
    }
    // Length-delimited canonical JSON prevents ambiguous concatenated IDs. No
    // identity, credential reference or private data is needed in this journal.
    const QJsonArray identity{configuration.value("team_id").toString(),
                              configuration.value("match_id").toString(), configuration.value("epoch").toString()};
    const auto digest = QString::fromLatin1(QCryptographicHash::hash(
        QJsonDocument(identity).toJson(QJsonDocument::Compact), QCryptographicHash::Sha256).toHex());
    for (const auto &entry : used)
        if (entry.toString() == digest)
            return fail(error, "该队伍／比赛／共享轮次已使用；停用或重启后须与队友约定全新轮次，不能复用");
    if (used.size() >= 256)
        return fail(error, "共享轮次账本已满，未删除历史；请人工恢复或配置新的独立实例");
    used.append(digest);
    const auto bytes = QJsonDocument(QJsonObject{{"schema", 1}, {"used", used}}).toJson();
    if (bytes.size() > JournalBytes) return fail(error, "共享轮次账本容量已满，未启用网络");
    return writeAtomic(path, bytes, error);
}

bool TeamConfiguration::authorizeActivation(const QVariantMap &runtimeConfig, QString *error) {
    if (error) error->clear();
    QPointer<TeamConfiguration> alive(this);
    if (!m_runtime || !m_backend || !m_phase || !m_services || !m_activationReady ||
        m_scope != scope() || !m_values.value("networkEnabled").toBool() ||
        m_runtime->selectedPlugin("aggregation").isEmpty())
        return fail(error, "先在当前机器人／选手端范围赛外保存队伍配置；不能恢复旧范围节点");
    const auto revision = m_revision;
    // Do not call our own editable(): save() holds m_saving while Runtime invokes
    // this guard. The independent phase gate must still permit this activation.
    const auto phase = m_phase->lockReason();
    if (!alive) return false;
    if (revision != m_revision || !phase.isEmpty())
        return fail(error, phase.isEmpty() ? QStringLiteral("队伍范围已变化") : phase);
    QVariantMap expected;
    if (!validate(m_values, m_scope.value("robot_id").toInt(), error) ||
        !nativeConfiguration(m_values, &expected, error)) return false;
    if (runtimeConfig != expected)
        return fail(error, "插件参数与当前已保存身份／凭据引用不一致，未启用网络");
    return consumeEpoch(expected, error);
}

bool TeamConfiguration::save(const QVariantMap &values) {
    QPointer<TeamConfiguration> alive(this);
    auto error = lockReason();
    if (!alive) return false;
    if (!error.isEmpty() || !validate(values, m_scope.value("robot_id").toInt(), &error)) {
        m_status = error;
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
    m_activationReady = false;
    m_activationError.clear();
    emit currentChanged();
    if (!alive) return false;
    if (revision != m_revision) { m_saving = false; return false; }
    QVariantMap configuration;
    bool applied = nativeConfiguration(values, &configuration, &error);
    m_activationReady = applied;
    if (applied && m_runtime) {
        const auto selectedPlugin = m_runtime->selectedPlugin("aggregation");
        applied = m_runtime->replaceOptional("aggregation", selectedPlugin.isEmpty()
                                                ? QStringLiteral("team.aggregate.v2") : selectedPlugin, configuration,
                                              values.value("networkEnabled").toBool(), &error);
    } else if (m_runtime) {
        m_runtime->retireOptional("aggregation");
        if (!alive) return false;
        if (revision != m_revision) { m_saving = false; return false; }
        const auto selectedPlugin = m_runtime->selectedPlugin("aggregation");
        m_runtime->configureOptional("aggregation", selectedPlugin.isEmpty()
            ? QStringLiteral("team.aggregate.v2") : selectedPlugin, {}, false, error);
    }
    if (!alive) return false;
    m_saving = false;
    if (revision != m_revision) return false;
    m_activationError = applied ? QString{} : error;
    m_status = !applied ? QStringLiteral("队伍配置已保存，但未启用：") + error
               : values.value("networkEnabled").toBool()
                   ? QStringLiteral("队伍配置已保存并提交可选插件启动；TLS连接／来源验证状态另行显示，未确认消息送达")
                   : QStringLiteral("队伍配置已保存，队内网络已停用；本机选手端／HUD继续独立运行");
    emit stateChanged();
    return true; // Persisted intent and asynchronous connection health are distinct.
}
