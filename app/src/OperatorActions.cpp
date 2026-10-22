#include "OperatorActions.h"
#include "ClientBackend.h"
#include "RobotIdentity.h"
#include <QDateTime>
#include <QMetaType>
#include <QRegularExpression>
#include <QSet>
#include <QTimer>
#include <cmath>

namespace {
bool reject(QString *error, const QString &reason) {
    if (error) *error = reason;
    return false;
}
bool number(const QVariant &value, double *result) {
    switch (value.metaType().id()) {
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double: case QMetaType::Float:
    case QMetaType::Long: case QMetaType::ULong: case QMetaType::Short:
    case QMetaType::UShort: case QMetaType::Char: case QMetaType::UChar:
        break;
    default: return false; // No string or boolean-to-number coercion.
    }
    bool ok = false;
    const double n = value.toDouble(&ok);
    if (!ok || !std::isfinite(n)) return false;
    if (result) *result = n;
    return true;
}
bool unsignedInteger(const QVariant &value, quint32 *result = nullptr) {
    double n = 0;
    if (!number(value, &n) || n < 0 || n > 4294967295.0 || std::floor(n) != n)
        return false;
    if (result) *result = quint32(n);
    return true;
}
bool flag(const QVariant &value, bool expected = true) {
    return value.metaType().id() == QMetaType::Bool && value.toBool() == expected;
}
bool boundedText(const QVariant &value, int maximum = 256) {
    if (value.metaType().id() != QMetaType::QString) return false;
    const auto text = value.toString();
    if (text.trimmed().isEmpty() || text.size() > maximum) return false;
    for (const auto ch : text) if (ch.category() == QChar::Other_Control) return false;
    return true;
}
bool fieldsOnly(const QVariantMap &fields, const QStringList &allowed,
                const QStringList &required, QString *error) {
    if (fields.isEmpty() || fields.size() > allowed.size())
        return reject(error, QStringLiteral("命令为空或字段数量不合法"));
    for (auto it = fields.cbegin(); it != fields.cend(); ++it)
        if (!allowed.contains(it.key()))
            return reject(error, QStringLiteral("该命令不接受字段：") + it.key().left(80));
    for (const auto &key : required)
        if (!fields.contains(key)) return reject(error, QStringLiteral("缺少命令字段：") + key);
    return true;
}
bool bytes(const QVariant &value, int maximum, QByteArray *result) {
    QByteArray data;
    if (value.metaType().id() == QMetaType::QByteArray) data = value.toByteArray();
    else if (value.metaType().id() == QMetaType::QString) {
        const QString hex = value.toString();
        static const QRegularExpression pattern(QStringLiteral("\\A(?:[0-9a-fA-F]{2})*\\z"));
        if (hex.size() > maximum * 2 || !pattern.match(hex).hasMatch()) return false;
        data = QByteArray::fromHex(hex.toLatin1());
    } else return false;
    if (data.size() > maximum) return false;
    if (result) *result = data;
    return true;
}

struct Facts {
    int id = 0, role = 0;
    bool connected = false;
    QVariantMap groups, freshness;
    QVariant value(const QString &group, const QString &key) const {
        return groups.value(group).toMap().value(key);
    }
    bool fresh(const QString &group, const QString &key) const {
        return value(group, key).isValid()
            && freshness.value(group).toMap().value(key) == QLatin1String("fresh");
    }
    bool integer(const QString &group, const QString &key, quint32 *out = nullptr) const {
        return fresh(group, key) && unsignedInteger(value(group, key), out);
    }
    bool equal(const QString &group, const QString &key, quint32 expected) const {
        quint32 n = 0;
        return integer(group, key, &n) && n == expected;
    }
    bool boolean(const QString &group, const QString &key, bool expected = true) const {
        return fresh(group, key) && flag(value(group, key), expected);
    }
    QString connectionReason() const {
        if (!RobotIdentity::valid(id)) return QStringLiteral("尚未选择合法机器人身份");
        return connected ? QString{} : QStringLiteral("官方选手端MQTT未连接");
    }
    QString actorReason() const {
        const auto reason = connectionReason();
        if (!reason.isEmpty()) return reason;
        quint32 actor = 0;
        if (!integer("robotStatic", "robot_id", &actor))
            return QStringLiteral("本机robot_id缺失、旧或逐字段时效待核");
        return actor == quint32(id) ? QString{} : QStringLiteral("遥测机器人与当前登录身份不一致");
    }
};
Facts facts(ClientBackend *backend) {
    Facts f;
    if (!backend) return f;
    f.id = backend->clientId(); f.role = f.id % 100; f.connected = backend->connected();
    QPointer<ClientBackend> lifetime(backend);
    QPointer<TelemetryEndpoint> state = backend->telemetry();
    if (!state) return f;
    f.freshness = state->group("fieldFreshness");
    if (!lifetime || !state) return {};
    for (const auto &group : {"robotStatic", "robotDynamic", "gameStatus", "globalLogistics",
             "globalUnit", "robotRespawn", "robotPerfSync", "deployMode", "runeStatus",
             "techCore", "sentryStatus", "dartTarget", "airSupport"})
    {
        f.groups.insert(group, state->group(QString::fromLatin1(group)));
        if (!lifetime || !state) return {};
    }
    // A replaceable endpoint may synchronously change the host's identity while
    // being read. Do not combine that callback's new context with old fields.
    if (backend->clientId() != f.id || backend->connected() != f.connected) return {};
    return f;
}
QString performanceReason(const Facts &f) {
    auto reason = f.actorReason();
    if (!reason.isEmpty()) return reason;
    if (!QList<int>{1,3,4,5,7}.contains(f.role)) return QStringLiteral("本兵种没有可选择的性能／控制配置");
    quint32 stage = 0;
    if (!f.integer("gameStatus", "current_stage", &stage)) return QStringLiteral("比赛阶段旧或未提供，无法确认赛前性能设置");
    // Rules V2.2.0 §5.4.2: selection starts in preparation and is locked when
    // the seven-minute match begins. No pause restriction is inferred here.
    return stage >= 1 && stage <= 3 ? QString{} : QStringLiteral("性能／控制配置请在赛前准备阶段提交");
}
QString reviveReason(const Facts &f, bool paid) {
    if (!f.equal("robotStatic", "alive_state", 2)) return QStringLiteral("尚未新鲜确认本机战亡");
    if (!f.boolean("robotRespawn", "is_pending_respawn")) return QStringLiteral("本机待复活状态未新鲜确认");
    if (!f.boolean("robotRespawn", paid ? "can_pay_for_respawn" : "can_free_respawn"))
        return QStringLiteral("当前复活资格旧、未提供或不允许");
    quint32 a = 0, b = 0;
    if (!paid) {
        if (!f.integer("robotRespawn", "current_respawn_progress", &a)
            || !f.integer("robotRespawn", "total_respawn_progress", &b) || a != b)
            return QStringLiteral("免费复活读条尚未新鲜确认完成");
    } else if (!f.integer("robotRespawn", "gold_cost_for_respawn", &a)
               || !f.integer("globalLogistics", "remaining_economy", &b) || a > b)
        return QStringLiteral("立即复活费用／金币未新鲜确认或金币不足");
    return {};
}
const QStringList commonNames{"buy17", "buy42", "free", "paid", "remote17", "remote42", "remoteHeal"};
int commonType(const QString &name) {
    if (name == "buy17") return 1;
    if (name == "buy42") return 2;
    if (name == "free") return 3;
    if (name == "paid") return 4;
    return name == "remoteHeal" ? 6 : 5;
}
QString commonReason(const Facts &f, const QString &name) {
    const auto reason = f.actorReason();
    if (!reason.isEmpty()) return reason;
    const bool ground = QList<int>{1,2,3,4,5,7}.contains(f.role);
    if (!ground || ((name == "buy42" || name == "remote42") && f.role != 1)
        || ((name == "buy17" || name == "remote17") && f.role == 2))
        return QStringLiteral("当前兵种不适用此通用操作");
    if (name == "free" || name == "paid") return reviveReason(f, name == "paid");
    if (!f.equal("robotStatic", "alive_state", 1)) return QStringLiteral("尚未新鲜确认本机存活");
    if (name.startsWith("remote")) {
        if (!f.boolean("robotDynamic", name == "remoteHeal" ? "can_remote_heal" : "can_remote_ammo"))
            return QStringLiteral("远程兑换资格未新鲜确认或不允许");
    } else {
        quint32 coins = 0;
        if (!f.integer("globalLogistics", "remaining_economy", &coins) || coins == 0)
            return QStringLiteral("队伍金币旧、未提供或不足");
    }
    return {};
}
QVariantMap commonOperation(const Facts &f, const QVariantMap &configuration, const QString &name) {
    const auto configured = configuration.value("common_controls").toMap().value(name).toMap();
    const bool quantity = name == "buy17" || name == "buy42";
    const bool mapped = flag(configured.value("param_verified")) && boundedText(configured.value("source"))
        && (configured.value("param_mode") == QLatin1String("none")
            || (configured.value("param_mode") == QLatin1String("mapped") && unsignedInteger(configured.value("param"))));
    QString reason = commonReason(f, name);
    if (reason.isEmpty() && configured.contains("allowed") && !flag(configured.value("allowed")))
        reason = QStringLiteral("宿主配置停用本项操作");
    if (reason.isEmpty() && !quantity && !mapped)
        reason = QStringLiteral("此命令param语义尚未由宿主提供已核验映射");
    QVariantMap result{{"allowed", reason.isEmpty()}, {"paramVerified", quantity || mapped},
        {"paramMode", quantity ? QStringLiteral("quantity") : configured.value("param_mode").toString()},
        {"reason", reason}, {"source", quantity ? QStringLiteral("官方V2.0.0 §2.2.25数量参数；费用／区域由选手端判定")
                                               : configured.value("source").toString()}};
    if (mapped && configured.value("param_mode") == QLatin1String("mapped")) result.insert("param", configured.value("param"));
    return result;
}
bool configuredOperation(const QVariantMap &configuration, const QString &key, bool fallback) {
    const auto operations = configuration.value("dart_operations").toMap();
    return operations.contains(key) ? flag(operations.value(key)) : fallback;
}
QString dartReason(const Facts &f, const QVariantMap &configuration, const QString &operation,
                   quint32 desiredTarget = 0) {
    auto reason = f.actorReason();
    if (!reason.isEmpty()) return reason;
    if (!flag(configuration.value("dart_operator_authorized"))) return QStringLiteral("宿主未确认云台手飞镖控制权限");
    const bool defaultPermission = operation == "target" || operation == "close";
    if (!configuredOperation(configuration, operation, defaultPermission))
        return QStringLiteral("本项飞镖资格／次数／冷却尚未由宿主允许");
    quint32 gate = 0;
    if (!f.integer("dartTarget", "open", &gate) || gate > 2) return QStringLiteral("飞镖闸门状态旧、缺失或未识别");
    if ((operation == "target" || operation == "open") ? gate != 0 : gate != 2)
        return QStringLiteral("飞镖闸门尚不满足此操作状态");
    if (operation == "close") return {};
    quint32 outpost = 0;
    if (!f.integer("globalUnit", "enemy_outpost_health", &outpost)) return QStringLiteral("对方前哨生命旧或未提供，目标资格未确认");
    quint32 target = desiredTarget;
    if (!target && !f.integer("dartTarget", "target_id", &target)) return QStringLiteral("当前飞镖目标旧或未提供");
    if (target < 1 || target > 5 || (outpost == 0 ? target == 1 : target != 1))
        return QStringLiteral("目标与当前前哨状态不一致");
    return {};
}
QString runeReason(const Facts &f, const QVariantMap &configuration) {
    auto reason = f.actorReason();
    if (!reason.isEmpty()) return reason;
    if (!QList<int>{3,4,5}.contains(f.role)) return QStringLiteral("本机不是步兵");
    if (!flag(configuration.value("rune_activation_allowed"))) return QStringLiteral("宿主未确认能量机关激活权限／场景");
    if (!f.equal("robotStatic", "alive_state", 1)) return QStringLiteral("尚未新鲜确认本机存活");
    return f.equal("runeStatus", "rune_status", 1) ? QString{} : QStringLiteral("机关不是新鲜未激活状态");
}
QVariantMap assemblyView(const Facts &f, const QVariantMap &configuration, qint64 elapsed,
                         bool generationMatches) {
    const auto c = configuration.value("assembly_context").toMap();
    quint32 actor = 0, difficulty = 0, round = 0, ttl = 0, currentRound = 0, core = 0;
    const bool valid = f.actorReason().isEmpty() && f.role == 2 && generationMatches
        && flag(c.value("confirmed")) && unsignedInteger(c.value("robot_id"), &actor) && actor == quint32(f.id)
        && unsignedInteger(c.value("difficulty"), &difficulty) && difficulty >= 1 && difficulty <= 4
        && unsignedInteger(c.value("round"), &round) && round > 0
        && f.integer("gameStatus", "current_round", &currentRound) && currentRound == round
        && f.integer("techCore", "basic_state", &core) && (core == 2 || core == 3)
        && unsignedInteger(c.value("ttl_ms"), &ttl) && ttl > 0 && ttl <= 60000
        && elapsed >= 0 && elapsed < ttl && boundedText(c.value("source"));
    QVariantMap result{{"valid", valid}, {"robotID", f.id},
        {"freshness", valid ? "fresh" : "missing"},
        {"reason", valid ? QString{} : QStringLiteral("请选择并确认本轮实际难度；官方同步不含当前难度，开始提交不等于执行确认")}};
    if (valid) {
        result.insert("difficulty", difficulty);
        result.insert("source", c.value("source"));
        result.insert("source_kind", c.value("source") == QLatin1String("operator_confirmation")
            ? QStringLiteral("operator_confirmation") : QStringLiteral("host_context"));
        result.insert("authoritative", false);
        result.insert("age_ms", elapsed);
        result.insert("remaining_ms", qMax<qint64>(0, ttl - elapsed));
    }
    return result;
}
QString assemblyReason(const Facts &f, const QVariantMap &context, quint32 operation, quint32 difficulty) {
    const auto reason = f.actorReason();
    if (!reason.isEmpty()) return reason;
    if (f.role != 2) return QStringLiteral("本机不是工程机器人");
    if (operation != 2 && (!f.equal("robotStatic", "alive_state", 1)
        || !f.equal("robotStatic", "connection_state", 1) || !f.equal("robotStatic", "field_state", 0)))
        return QStringLiteral("开始／确认装配前须新鲜确认机器人存活、连接且已上场");
    quint32 core = 0;
    if (!f.integer("techCore", "basic_state", &core) || core < 1 || core > 3)
        return QStringLiteral("科技核心基础状态旧、缺失或未识别");
    if (operation == 0) {
        quint32 maximum = 0;
        if (core != 1 || !f.integer("techCore", "maximum_difficulty_level", &maximum)
            || maximum < 1 || maximum > 4 || difficulty > maximum)
            return QStringLiteral("开始装配需要初始位置与新鲜可选难度");
    } else {
        if (!flag(context.value("valid")) || context.value("difficulty").toUInt() != difficulty)
            return QStringLiteral("当前装配难度尚未由宿主确认或已失效");
        if (operation == 1 && core != 3) return QStringLiteral("科技核心尚未到达确认位姿");
    }
    return {};
}
bool assemblyExitPending(const Facts &f, quint32 eventRound) {
    quint32 round=0,remaining=0,core=0;
    return eventRound>0 && f.role==2
        && f.equal("gameStatus","current_stage",4) && f.boolean("gameStatus","is_paused",false)
        && f.integer("gameStatus","current_round",&round) && round==eventRound
        && f.integer("techCore","basic_state",&core) && (core==2 || core==3)
        && f.integer("techCore","remain_time_all",&remaining) && remaining>0 && remaining<=45;
}
QString sentryReason(const Facts &f, quint32 command) {
    const auto reason = f.actorReason();
    if (!reason.isEmpty()) return reason;
    if (f.role != 7) return QStringLiteral("本机不是哨兵");
    if (command >= 7) {
        if (!f.equal("robotStatic", "alive_state", 1)) return QStringLiteral("尚未新鲜确认哨兵存活");
        quint32 posture = 0;
        if (!f.integer("sentryStatus", "posture_id", &posture) || posture < 1 || posture > 3
            || !f.fresh("sentryStatus", "is_powered") || !f.fresh("sentryStatus", "is_weakened")
            || f.value("sentryStatus", "is_powered").metaType().id() != QMetaType::Bool
            || f.value("sentryStatus", "is_weakened").metaType().id() != QMetaType::Bool)
            return QStringLiteral("哨兵姿态／强化／弱化字段旧、缺失或未识别");
    } else if (command == 5 || command == 6) return reviveReason(f, command == 6);
    else {
        if (!f.equal("robotStatic", "alive_state", 1)) return QStringLiteral("尚未新鲜确认哨兵存活");
        if (command == 3 && !f.boolean("robotDynamic", "can_remote_ammo")) return QStringLiteral("哨兵远程补弹资格未新鲜允许");
        if (command == 4 && !f.boolean("robotDynamic", "can_remote_heal")) return QStringLiteral("哨兵远程回血资格未新鲜允许");
    }
    return {};
}
bool localSupportConfigured(ClientBackend *backend,const QVariantMap &configuration) {
    return backend && backend->connected() && backend->port()==3333
        && QStringList{"127.0.0.1","localhost","::1"}.contains(backend->host())
        && flag(configuration.value("sentry_support_allowed"));
}
QVariantMap localSupportView(const Facts &f,ClientBackend *backend,const QVariantMap &configuration,
                            const QVariantMap &raw,bool checkPosture=true) {
    if(!localSupportConfigured(backend,configuration) || !f.actorReason().isEmpty())return {};
    quint32 actor=0,target=0,round=0,ttl=0,version=0;double produced=0,received=0;
    const double now=QDateTime::currentMSecsSinceEpoch();
    if(raw.value("source_kind")!="local_shark_server" || raw.value("validation")!="local_server"
        || raw.value("source_id")!="SharkDataSever" || raw.value("endpoint")!="http://127.0.0.1:2026/api/roster"
        || raw.value("lifecycle")!="active" || raw.value("state")!="fresh" || !unsignedInteger(raw.value("version"),&version) || version!=1
        || raw.value("operator_role")!="gimbal" || !boundedText(raw.value("snapshot_id"),128)
        || !unsignedInteger(raw.value("robot_id"),&actor) || actor!=quint32(f.id)
        || !unsignedInteger(raw.value("source_robot_id"),&actor) || actor!=quint32(f.id)
        || !unsignedInteger(raw.value("target_robot_id"),&target) || target!=quint32(f.id>100?107:7)
        || !unsignedInteger(raw.value("round"),&round) || !f.equal("gameStatus","current_round",round)
        || !unsignedInteger(raw.value("target_round"),&target) || target!=round
        || !unsignedInteger(raw.value("ttl_ms"),&ttl) || ttl==0 || ttl>3500
        || !number(raw.value("produced_at_ms"),&produced) || !number(raw.value("received_at_ms"),&received)
        || produced>received || received>now || now-produced<0 || now-produced>=ttl)return {};
    quint32 posture=0;
    if(!unsignedInteger(raw.value("posture_id"),&posture) || posture<1 || posture>3
        || raw.value("is_powered").metaType().id()!=QMetaType::Bool
        || raw.value("is_weakened").metaType().id()!=QMetaType::Bool)return {};
    if(checkPosture && (!f.equal("sentryStatus","posture_id",posture)
        || !f.boolean("sentryStatus","is_powered",raw.value("is_powered").toBool())
        || !f.boolean("sentryStatus","is_weakened",raw.value("is_weakened").toBool())))return {};
    const auto offers=raw.value("offers").toList();QSet<quint32> seen;
    if(offers.size()!=11)return {};
    for(const auto &value:offers){const auto o=value.toMap();quint32 id=0;
        if(!unsignedInteger(o.value("command_id"),&id) || id<1 || id>12 || id==2 || seen.contains(id)
            || o.value("enabled").metaType().id()!=QMetaType::Bool || !unsignedInteger(o.value("cost"))
            || o.value("reason").metaType().id()!=QMetaType::QString || o.value("reason").toString().size()>256)return {};
        seen.insert(id);
    }
    if(raw.value("map_offer").toMap().value("active").metaType().id()!=QMetaType::Bool)return {};
    return raw;
}
QString supportCommandReason(const QVariantMap &view,quint32 command) {
    if(view.isEmpty())return QStringLiteral("等待新鲜的本机云台手／己方哨兵上下文");
    for(const auto &value:view.value("offers").toList()) {const auto offer=value.toMap();
        if(offer.value("command_id").toUInt()==command)
            return flag(offer.value("enabled"))?QString{}:offer.value("reason").toString().isEmpty()?QStringLiteral("己方哨兵操作当前不可用"):offer.value("reason").toString();
    }
    return QStringLiteral("己方哨兵没有此指令的有效资格");
}
QString airReason(const Facts &f, quint32 command) {
    const auto reason = f.actorReason();
    if (!reason.isEmpty()) return reason;
    if (f.role != 6) return QStringLiteral("本机不是空中机器人");
    quint32 state = 0;
    if (!f.integer("airSupport", "airsupport_status", &state) || state > 1)
        return QStringLiteral("空中支援状态旧、缺失或未识别");
    if (command == 0 || command == 3) {
        if (state != 1) return QStringLiteral("本机当前未进行空中支援");
        if (command == 3 && !f.equal("airSupport", "shooter_status", 2))
            return QStringLiteral("尚未新鲜确认可以付费解除反制");
    } else {
        if (state != 0) return QStringLiteral("支援已在进行，不能重复呼叫");
        quint32 remaining = 0;
        if (command == 1 && (!f.integer("airSupport", "left_time", &remaining) || remaining == 0))
            return QStringLiteral("免费支援余量旧、缺失或为0");
    }
    // cost_coins is already-spent gold, NOT this request's price. The official
    // endpoint adjudicates payment; never invent a quote from that field.
    return {};
}
bool validateConfiguration(const QVariantMap &configuration, QString *error) {
    const QStringList allowed{"dart_operator_authorized", "dart_operations", "rune_activation_allowed", "map_team_mark_allowed", "sentry_support_allowed",
                             "rune_kind", "assembly_context", "common_controls"};
    if (configuration.size() > allowed.size()) return reject(error, QStringLiteral("操作策略配置过大"));
    for (auto it = configuration.cbegin(); it != configuration.cend(); ++it)
        if (!allowed.contains(it.key())) return reject(error, QStringLiteral("未知操作策略配置项：") + it.key().left(80));
    for (const auto &key : {"dart_operator_authorized", "rune_activation_allowed", "map_team_mark_allowed", "sentry_support_allowed"})
        if (configuration.contains(key) && configuration.value(key).metaType().id() != QMetaType::Bool)
            return reject(error, QStringLiteral("权限配置须为明确布尔值：") + key);
    if(flag(configuration.value("sentry_support_allowed")) && !flag(configuration.value("map_team_mark_allowed")))
        return reject(error,QStringLiteral("哨兵云台手须同时明确配置地图云台手权限"));
    if (configuration.contains("rune_kind") && !QStringList{"small", "large"}.contains(configuration.value("rune_kind").toString()))
        return reject(error, QStringLiteral("机关类型只接受small／large"));
    for (const auto &key : {"dart_operations", "common_controls", "assembly_context"})
        if (configuration.contains(key) && configuration.value(key).metaType().id() != QMetaType::QVariantMap)
            return reject(error, QStringLiteral("操作上下文须为对象：") + key);
    const auto dart = configuration.value("dart_operations").toMap();
    for (auto it = dart.cbegin(); it != dart.cend(); ++it)
        if (!QStringList{"target", "open", "close", "launch"}.contains(it.key()) || it.value().metaType().id() != QMetaType::Bool)
            return reject(error, QStringLiteral("飞镖操作配置不合法"));
    const auto common = configuration.value("common_controls").toMap();
    if (common.size() > commonNames.size()) return reject(error, QStringLiteral("通用操作配置过大"));
    for (auto it = common.cbegin(); it != common.cend(); ++it) {
        if (!commonNames.contains(it.key()) || it.value().metaType().id() != QMetaType::QVariantMap)
            return reject(error, QStringLiteral("通用操作映射不合法"));
        const auto entry = it.value().toMap();
        if (entry.size() > 5) return reject(error, QStringLiteral("通用参数映射过大"));
        for (auto field = entry.cbegin(); field != entry.cend(); ++field)
            if (!QStringList{"allowed", "param_verified", "param_mode", "param", "source"}.contains(field.key()))
                return reject(error, QStringLiteral("通用参数映射含未知字段"));
        for (const auto &key : {"allowed", "param_verified"})
            if (entry.contains(key) && entry.value(key).metaType().id() != QMetaType::Bool)
                return reject(error, QStringLiteral("通用参数确认须为明确布尔值"));
        if (entry.contains("param") && !unsignedInteger(entry.value("param"))) return reject(error, QStringLiteral("通用映射param须为uint32"));
        if (entry.contains("source") && !boundedText(entry.value("source"))) return reject(error, QStringLiteral("通用映射须提供有界来源说明"));
        if (entry.contains("param_mode") && !QStringList{"none", "mapped"}.contains(entry.value("param_mode").toString()))
            return reject(error, QStringLiteral("显式映射只支持none或mapped"));
        if (flag(entry.value("param_verified")) && (!boundedText(entry.value("source"))
            || !entry.contains("param_mode") || (entry.value("param_mode") == QLatin1String("mapped") && !entry.contains("param"))))
            return reject(error, QStringLiteral("已核验映射缺少参数模式、原值或来源"));
    }
    const auto context = configuration.value("assembly_context").toMap();
    if (!context.isEmpty()) {
        if (context.size() > 6) return reject(error, QStringLiteral("装配上下文过大"));
        for (auto it = context.cbegin(); it != context.cend(); ++it)
            if (!QStringList{"confirmed", "robot_id", "difficulty", "round", "ttl_ms", "source"}.contains(it.key()))
                return reject(error, QStringLiteral("装配上下文含未知字段"));
        if (context.contains("confirmed") && context.value("confirmed").metaType().id() != QMetaType::Bool)
            return reject(error, QStringLiteral("装配确认须为明确布尔值"));
        for (const auto &key : {"robot_id", "difficulty", "round", "ttl_ms"})
            if (context.contains(key) && !unsignedInteger(context.value(key)))
                return reject(error, QStringLiteral("装配上下文数值须为uint32"));
        if (context.contains("source") && !boundedText(context.value("source")))
            return reject(error, QStringLiteral("装配来源说明须为有界纯文字"));
        if (flag(context.value("confirmed"))) {
            quint32 actor=0, difficulty=0, round=0, ttl=0;
            if (!unsignedInteger(context.value("robot_id"), &actor) || actor > 109 || !RobotIdentity::valid(int(actor))
                || !unsignedInteger(context.value("difficulty"), &difficulty) || difficulty < 1 || difficulty > 4
                || !unsignedInteger(context.value("round"), &round) || round == 0
                || !unsignedInteger(context.value("ttl_ms"), &ttl) || ttl == 0 || ttl > 60000
                || !boundedText(context.value("source")))
                return reject(error, QStringLiteral("已确认装配上下文缺少合法主体、难度、局次、TTL或来源"));
        }
    }
    return true;
}
} // namespace

OperatorActions::OperatorActions(ClientBackend *backend, const QVariantMap &configuration, QObject *parent)
    : QObject(parent), m_backend(backend), m_telemetry(backend ? backend->telemetry() : nullptr) {
    m_clock.start();
    m_connectionWasReady = backend && backend->connected();
    if (backend) {
        connect(backend, &ClientBackend::identityChanged, this, [this] {
            ++m_generation; m_operatorAssembly.clear(); m_localSentry.clear(); m_assemblyEnded = false; m_assemblyExitRound=0; refresh();
        });
        connect(backend, &ClientBackend::connectionChanged, this, [this] {
            const bool ready = m_backend && m_backend->connected();
            // connectionChanged also carries status/error text. Only a connection
            // edge retires the context; a rejected edit must not invent a session.
            if (ready != m_connectionWasReady) {
                ++m_generation; m_operatorAssembly.clear(); m_localSentry.clear(); m_assemblyEnded = false; m_assemblyExitRound=0; m_connectionWasReady = ready;
            }
            refresh();
        });
        connect(backend, &ClientBackend::commandStatusChanged, this, [this] {
            if (!m_backend) return;
            m_feedback = m_backend->commandFeedback();
            emit commandFeedbackChanged();
        });
        connect(backend, &QObject::destroyed, this, [this] {refresh();});
    }
    if (m_telemetry) {
        connect(m_telemetry, &TelemetryEndpoint::freshnessChanged, this, &OperatorActions::refresh);
        connect(m_telemetry, &TelemetryEndpoint::eventReceived, this,
                [this](int id, const QString &parameter) {
            // Official event 15 belongs to this side's engineer. Do not use an
            // arbitrary string, a pending local command, or another team's event.
            static const QRegularExpression resultCode(QStringLiteral("\\A[0-8]\\z"));
            if (id == 15 && m_backend && m_backend->connected()
                && m_backend->clientId() % 100 == 2 && resultCode.match(parameter.trimmed()).hasMatch()) {
                m_operatorAssembly.clear();
                m_configuration.remove("assembly_context");
                m_assemblyEnded = true;
                m_assemblyExitRound=0;
                if(parameter.trimmed()==QLatin1String("5")) {
                    const auto f=facts(m_backend);
                    f.integer("gameStatus","current_round",&m_assemblyExitRound);
                }
                refresh();
            }
        });
#define RM_TELEMETRY_GROUP(name, type) \
        connect(m_telemetry, &TelemetryEndpoint::name##Changed, this, &OperatorActions::refresh);
#include "TelemetryGroups.def"
#undef RM_TELEMETRY_GROUP
    }
    auto *expiry = new QTimer(this);
    expiry->setInterval(250);
    connect(expiry, &QTimer::timeout, this, [this] {
        if (!m_configuration.value("assembly_context").toMap().isEmpty() || !m_operatorAssembly.isEmpty() || !m_localSentry.isEmpty()) refresh();
    });
    expiry->start();
    setConfiguration(configuration);
}
bool OperatorActions::setConfiguration(const QVariantMap &configuration, QString *error) {
    QString reason;
    if (!validateConfiguration(configuration, &reason)) {
        // Failed replacement retires privileged context rather than continuing
        // an old mapping after the host believes it has been replaced.
        m_configuration.clear(); m_configurationError = reason;
        m_operatorAssembly.clear();
        refresh();
        return reject(error, reason);
    }
    m_configuration = configuration; m_configurationError.clear();
    m_operatorAssembly.clear();
    m_configuredAt = m_clock.elapsed(); m_configurationGeneration = m_generation;
    if (error) error->clear();
    refresh(); return true;
}
bool OperatorActions::validatePreferences(const QVariantMap &configuration, QString *error) {
    if (configuration.contains("assembly_context"))
        return reject(error, QStringLiteral("装配上下文只能在运行中确认，不能作为赛前偏好保存"));
    return validateConfiguration(configuration, error);
}
bool OperatorActions::syncLocalSentrySupport(const QVariantMap &context) {
    const auto validated=localSupportView(facts(m_backend),m_backend,m_configuration,context,false);
    const bool accepted=!validated.isEmpty();
    if(m_localSentry==validated && m_localSentryGeneration==m_generation)return accepted;
    m_localSentry=validated;m_localSentryGeneration=m_generation;refresh();return accepted;
}
QVariantMap OperatorActions::effectiveAssemblyConfiguration() const {
    auto result = m_configuration;
    if (!m_operatorAssembly.isEmpty()) result.insert("assembly_context", m_operatorAssembly);
    return result;
}
bool OperatorActions::confirmAssemblyDifficulty(int difficulty) {
    const auto generation = m_generation;
    QPointer<OperatorActions> alive(this);
    const auto f = facts(m_backend);
    if (!alive) return false;
    QString reason = f.actorReason();
    quint32 core = 0, round = 0;
    if (reason.isEmpty() && f.role != 2) reason = QStringLiteral("本机不是工程机器人");
    const bool exitOnly=assemblyExitPending(f,m_assemblyExitRound);
    if (reason.isEmpty() && m_assemblyEnded && !exitOnly) reason = QStringLiteral("已收到装配结束事件，等待回到初始位置再开始下一轮");
    if (reason.isEmpty() && exitOnly && difficulty!=4) reason = QStringLiteral("协作超时后仅可确认四级退出参数");
    if (reason.isEmpty() && (difficulty < 1 || difficulty > 4)) reason = QStringLiteral("装配难度须为1–4级");
    if (reason.isEmpty() && (!f.integer("techCore", "basic_state", &core) || (core != 2 && core != 3)))
        reason = QStringLiteral("须先收到运动中／已到位状态，再确认本轮实际难度");
    if (reason.isEmpty() && (!f.integer("gameStatus", "current_round", &round) || !round))
        reason = QStringLiteral("当前局次旧或缺失，无法绑定本轮操作参数");
    if (reason.isEmpty() && generation != m_generation) reason = QStringLiteral("确认期间连接或身份已变化");
    if (!reason.isEmpty()) {feedback("AssemblyContext", false, reason); return false;}
    m_operatorAssembly = {{"confirmed", true}, {"robot_id", f.id}, {"difficulty", difficulty},
        {"round", round}, {"ttl_ms", 60000}, {"source", "operator_confirmation"}};
    m_operatorAssemblyAt = m_clock.elapsed();
    m_operatorAssemblyGeneration = m_generation;
    refresh();
    if (alive) feedback("AssemblyContext", true,
        QStringLiteral("已记录人工确认的%1级操作参数，有效60秒；未发送装配命令").arg(difficulty));
    return bool(alive);
}
void OperatorActions::refresh() {
    if (m_refreshing) {
        QTimer::singleShot(0, this, [this] {refresh();});
        return;
    }
    m_refreshing = true;
    QPointer<OperatorActions> lifetime(this);
    const auto f = facts(m_backend);
    if (!lifetime) return;
    if (f.equal("techCore", "basic_state", 1)) {m_assemblyEnded = false;m_assemblyExitRound=0;}
    quint32 currentRound = 0;
    const auto retireContext = [&f, &currentRound](const QVariantMap &context) {
        return f.equal("techCore", "basic_state", 1)
            || (f.integer("gameStatus", "current_round", &currentRound)
                && context.value("round").toUInt() != currentRound);
    };
    if (!m_operatorAssembly.isEmpty() && (m_operatorAssemblyGeneration != m_generation
        || m_clock.elapsed() - m_operatorAssemblyAt >= 60000 || retireContext(m_operatorAssembly)))
        m_operatorAssembly.clear();
    if (retireContext(m_configuration.value("assembly_context").toMap()))
        m_configuration.remove("assembly_context");
    const auto actorReason = f.actorReason();
    const bool actor = actorReason.isEmpty();
    const bool supportConfigured=localSupportConfigured(m_backend,m_configuration);
    const auto support=m_localSentryGeneration==m_generation?localSupportView(f,m_backend,m_configuration,m_localSentry):QVariantMap{};
    QVariantMap capabilities{{"globalPanelShortcuts", true}, {"mapMark", f.connectionReason().isEmpty()},
        {"mapTeamMark", flag(m_configuration.value("map_team_mark_allowed")) && f.connectionReason().isEmpty()},
        {"customBytes", f.connectionReason().isEmpty()}, {"performanceSelection", performanceReason(f).isEmpty()},
        {"commonControl", actor && QList<int>{1,2,3,4,5,7}.contains(f.role)},
        {"dartControl", actor}, {"runeActivate", actor && QList<int>{3,4,5}.contains(f.role)},
        {"engineerAssembly", actor && f.role == 2}, {"heroDeploy", actor && f.role == 1},
        {"sentrySupportConfigured",supportConfigured}, {"sentrySupport",!support.isEmpty()},
        {"sentryControl", flag(m_configuration.value("sentry_support_allowed"))?!support.isEmpty():actor && f.role == 7}, {"airSupport", actor && f.role == 6}};
    const auto freshness = actor ? QStringLiteral("fresh") : QStringLiteral("missing");
    QVariantMap operations;
    for (const auto &name : commonNames) operations.insert(name, commonOperation(f, m_configuration, name));
    QVariantMap common{{"robotID", f.id}, {"freshness", freshness}, {"operations", operations}};
    QVariantMap dartOperations, dartReasons;
    for (const auto &operation : {"target", "open", "close", "launch"}) {
        const auto action = QString::fromLatin1(operation);
        const auto reason = dartReason(f, m_configuration, action, action == QLatin1String("target") ? (f.equal("globalUnit", "enemy_outpost_health", 0) ? 2 : 1) : 0);
        dartOperations.insert(operation, reason.isEmpty()); dartReasons.insert(operation, reason);
    }
    QVariantMap dart{{"robotID", f.id}, {"freshness", freshness},
        {"operatorRole", flag(m_configuration.value("dart_operator_authorized")) ? "gimbal" : ""},
        {"operations", dartOperations}, {"reasons", dartReasons},
        {"display", QVariantMap{{"source", "官方协议仅提供目标／闸门；开闸次数及冷却源未提供"}}}};
    const auto runeReasonText = runeReason(f, m_configuration);
    QVariantMap rune{{"robotID", f.id}, {"freshness", freshness},
        {"allowed", runeReasonText.isEmpty()}, {"reason", runeReasonText}};
    QVariantMap runeContext{{"robotID", f.id}, {"freshness", freshness},
        {"kind", m_configuration.value("rune_kind").toString()}};
    const bool manualContext = !m_operatorAssembly.isEmpty();
    auto assembly = assemblyView(f, effectiveAssemblyConfiguration(),
        m_clock.elapsed() - (manualContext ? m_operatorAssemblyAt : m_configuredAt),
        (manualContext ? m_operatorAssemblyGeneration : m_configurationGeneration) == m_generation);
    const bool exitOnly=assemblyExitPending(f,m_assemblyExitRound);
    if (m_assemblyEnded && !exitOnly) {
        assembly.insert("valid", false);
        assembly.insert("freshness", "missing");
        assembly.insert("reason", QStringLiteral("收到装配结果事件，旧参数已退役；等待核心回到初始位置"));
    }
    quint32 coreState = 0, round = 0;
    assembly.insert("cancelOnly",exitOnly);
    assembly.insert("canConfirmDifficulty", actor && f.role == 2 && (!m_assemblyEnded || exitOnly)
        && f.integer("techCore", "basic_state", &coreState) && (coreState == 2 || coreState == 3)
        && f.integer("gameStatus", "current_round", &round) && round > 0);
    QVariantMap performance{{"robotID", f.id}, {"reason", performanceReason(f)},
        {"shooter", QList<int>{1,3,4,5}.contains(f.role)},
        {"chassis", QList<int>{1,3,4,5}.contains(f.role)}, {"sentry_control", f.role == 7}};
    QString heroReason = actorReason;
    quint32 deployment = 0;
    if (heroReason.isEmpty()) {
        if (f.role != 1) heroReason = QStringLiteral("本机不是英雄");
        else if (!f.integer("deployMode", "status", &deployment) || deployment > 1)
            heroReason = QStringLiteral("部署状态旧、缺失或未识别");
        else if (deployment == 0 && !f.equal("robotStatic", "alive_state", 1))
            heroReason = QStringLiteral("进入部署前须新鲜确认存活");
    }
    QVariantMap sentryCommands, airCommands;
    for (const int command : {1,3,4,5,6,7,8,9,10,11,12})
        sentryCommands.insert(QString::number(command), flag(m_configuration.value("sentry_support_allowed"))?supportCommandReason(support,quint32(command)):sentryReason(f, quint32(command)));
    for (quint32 command=0;command<=3;++command)
        airCommands.insert(QString::number(command), airReason(f,command));
    QVariantMap reasons{{"identity", actorReason}, {"configuration", m_configurationError},
        {"mapMark", f.connectionReason()}, {"customBytes", f.connectionReason()},
        {"commonControl", actorReason.isEmpty() ? QStringLiteral("当前兵种没有通用兑换操作") : actorReason},
        {"performanceSelection", performanceReason(f)}, {"runeActivate", runeReasonText},
        {"assemblyContext", assembly.value("reason")}, {"heroDeploy", heroReason},
        {"dartControl", actorReason.isEmpty() && !flag(m_configuration.value("dart_operator_authorized"))
            ? QStringLiteral("宿主未确认云台手飞镖控制权限") : actorReason},
        {"engineerAssembly", !actorReason.isEmpty() ? actorReason : f.role != 2 ? QStringLiteral("本机不是工程机器人") : QString{}},
        {"sentryControl", flag(m_configuration.value("sentry_support_allowed"))?(support.isEmpty()?QStringLiteral("等待新鲜的本机云台手／己方哨兵上下文"):QString{}):!actorReason.isEmpty() ? actorReason : f.role != 7 ? QStringLiteral("本机不是哨兵") : QString{}},
        {"airSupport", !actorReason.isEmpty() ? actorReason : f.role != 6 ? QStringLiteral("本机不是空中机器人") : QString{}},
        {"sentryCommands", sentryCommands}, {"airSupportCommands", airCommands}};
    const QString status = !f.connectionReason().isEmpty() ? f.connectionReason()
        : !actorReason.isEmpty() ? QStringLiteral("字节／地图通道可用；") + actorReason
        : QStringLiteral("操作入口已接通；逐次核验选手端数据，提交不等于机器人执行成功");
    const bool changed = capabilities != m_capabilities || common != m_common || dart != m_dart
        || rune != m_rune || runeContext != m_runeContext || assembly != m_assembly
        || performance != m_performance || reasons != m_reasons || status != m_status;
    m_capabilities = capabilities; m_common = common; m_dart = dart; m_rune = rune;
    m_runeContext = runeContext; m_assembly = assembly; m_performance = performance;
    m_reasons = reasons; m_status = status;
    m_refreshing = false;
    if (changed) emit stateChanged();
}

bool OperatorActions::allowCommand(const QString &topic, const QVariantMap &fields, QString *error) const {
    if (error) error->clear();
    const auto configuration = m_configuration;
    const bool manualContext = !m_operatorAssembly.isEmpty();
    const auto assemblyConfiguration = effectiveAssemblyConfiguration();
    const auto configuredElapsed = m_clock.elapsed() - (manualContext ? m_operatorAssemblyAt : m_configuredAt);
    const auto contextCurrent = (manualContext ? m_operatorAssemblyGeneration : m_configurationGeneration) == m_generation;
    QPointer<OperatorActions> lifetime(const_cast<OperatorActions *>(this));
    const auto f = facts(m_backend);
    if (!lifetime) return reject(error, QStringLiteral("操作宿主在检查期间关闭"));
    auto reason = f.connectionReason();
    if (!reason.isEmpty()) return reject(error, reason);
    if (topic == "KeyboardMouseControl") return reject(error, QStringLiteral("键鼠必须经输入捕获专用入口发送"));
    if (topic == "CustomControl") {
        QByteArray data;
        return fieldsOnly(fields, {"data"}, {"data"}, error)
            && (bytes(fields.value("data"), 30, &data) || reject(error, QStringLiteral("自定义字节必须为0–30字节合法十六进制或字节数组")));
    }
    if (topic == "MapClickCmd") {
        if (!fieldsOnly(fields, {"is_send_all","robot_id","mode","enemy_id","ascii","type","map_x","map_y"},
                        {"is_send_all","robot_id","mode","type"}, error)) return false;
        quint32 scope=0,mode=0,type=0;
        QByteArray recipients;
        if (!unsignedInteger(fields.value("is_send_all"), &scope) || scope > 2 || !unsignedInteger(fields.value("mode"), &mode)
            || mode < 1 || mode > 4 || !unsignedInteger(fields.value("type"), &type) || type < 1 || type > 2
            || !bytes(fields.value("robot_id"), 7, &recipients) || recipients.size() != 7)
            return reject(error, QStringLiteral("地图范围、标记、模式或七字节接收列表不合法"));
        QSet<int> seen; bool padding=false;
        for (const auto raw : recipients) {
            const int id = quint8(raw);
            if (!id) {padding=true; continue;}
            const int role=id > 100 ? id-100 : id;
            if (scope != 0 || padding || role < 1 || role > 9 || (id > 100) != (f.id > 100) || seen.contains(id))
                return reject(error, QStringLiteral("地图接收者须为不重复己方编号，零仅用于尾部填充"));
            seen.insert(id);
        }
        if (scope == 0 && seen.isEmpty()) return reject(error, QStringLiteral("指定范围须选择至少一名己方接收者"));
        if (!flag(configuration.value("map_team_mark_allowed")) && (scope != 0 || seen != QSet<int>{f.id}))
            return reject(error, QStringLiteral("普通操作手仅可给本机发送地图标记；全队标记须明确配置云台手权限"));
        if(flag(configuration.value("sentry_support_allowed")) && (scope==2 || seen.contains(f.id>100?107:7))){
            const auto support=m_localSentryGeneration==m_generation?localSupportView(f,m_backend,configuration,m_localSentry):QVariantMap{};
            if(support.isEmpty() || !flag(support.value("map_offer").toMap().value("active")))
                return reject(error,QStringLiteral("向哨兵转发地图标记前须确认并激活转发"));
        }
        quint32 ascii=0;
        if (mode == 4) {
            if (!unsignedInteger(fields.value("ascii"), &ascii) || !((ascii >= 'C' && ascii <= 'L') || ascii == 'N' || ascii == 'O' || (ascii >= 'Q' && ascii <= 'Z')))
                return reject(error, QStringLiteral("地图自定义字母不在官方允许范围"));
        } else if (fields.contains("ascii")) return reject(error, QStringLiteral("非自定义标记不发送ascii字段"));
        if (type == 1) {
            double x=0,y=0;
            if (fields.contains("enemy_id") || !number(fields.value("map_x"), &x) || !number(fields.value("map_y"), &y)
                || x < 0 || x > 28 || y < 0 || y > 15)
                return reject(error, QStringLiteral("地图坐标须在28×15米范围且不能混入敌方编号"));
        } else {
            quint32 enemy=0;
            if (fields.contains("map_x") || fields.contains("map_y") || !unsignedInteger(fields.value("enemy_id"), &enemy)
                || enemy > 109 || (enemy > 100) == (f.id > 100) || (enemy % 100) < 1 || (enemy % 100) > 9)
                return reject(error, QStringLiteral("机器人标记须为明确对方编号，不混入地图坐标"));
        }
        return true; // No unrelated GameStatus/telemetry prerequisite for user-authored markers.
    }
    reason = f.actorReason();
    if (!reason.isEmpty()) return reject(error, reason);
    if (topic == "RobotPerformanceSelectionCommand") {
        if (!fieldsOnly(fields, {"shooter","chassis","sentry_control"}, {}, error)) return false;
        reason = performanceReason(f);
        if (!reason.isEmpty()) return reject(error, reason);
        for (auto it=fields.cbegin();it!=fields.cend();++it) {
            quint32 value=0;
            if (!unsignedInteger(it.value(), &value)) return reject(error, QStringLiteral("性能选项须为明确整数"));
            if (it.key() == "sentry_control") {
                if (f.role != 7 || value > 1) return reject(error, QStringLiteral("哨兵控制方式仅接受0／1"));
            } else if (f.role == 1 ? value < 3 || value > 4 : !QList<int>{3,4,5}.contains(f.role) || value < 1 || value > 2)
                return reject(error, QStringLiteral("性能选项不适用于当前兵种"));
        }
        if (f.role == 1 && fields.contains("shooter") && fields.contains("chassis") && fields.value("shooter").toUInt() != fields.value("chassis").toUInt())
            return reject(error, QStringLiteral("英雄整机近战／远程选择不能互相矛盾"));
        return true;
    }
    if (topic == "CommonCommand") {
        if (!fieldsOnly(fields, {"cmd_type","param"}, {"cmd_type"}, error)) return false;
        quint32 type=0,param=0;
        if (!unsignedInteger(fields.value("cmd_type"), &type) || type < 1 || type > 6
            || (fields.contains("param") && !unsignedInteger(fields.value("param"), &param)))
            return reject(error, QStringLiteral("通用命令类型／参数须为合法uint32"));
        QString blocked = QStringLiteral("宿主未配置此命令的参数映射");
        for (const auto &name : commonNames) {
            if (commonType(name) != int(type)) continue;
            const auto operation = commonOperation(f, configuration, name);
            if (!flag(operation.value("allowed"))) {blocked=operation.value("reason").toString();continue;}
            const auto mode=operation.value("paramMode").toString();
            const bool matches=mode == "quantity" ? fields.contains("param") && param > 0 && (type != 1 || param%10 == 0)
                : mode == "none" ? !fields.contains("param")
                : fields.contains("param") && param == operation.value("param").toUInt();
            if (matches) return true;
            blocked=QStringLiteral("通用命令param与已核验映射／正整数数量不一致");
        }
        return reject(error, blocked);
    }
    if (topic == "HeroDeployModeEventCommand") {
        const auto actor = f.actorReason();
        if (!actor.isEmpty()) return reject(error, actor);
        if (!fieldsOnly(fields, {"mode"}, {"mode"}, error)) return false;
        quint32 mode=0;
        if (!unsignedInteger(fields.value("mode"), &mode) || mode > 1 || f.role != 1) return reject(error, QStringLiteral("英雄部署模式／兵种不合法"));
        if (!f.equal("robotStatic", "connection_state", 1)) return reject(error, QStringLiteral("部署操作须新鲜确认机器人连接"));
        if (mode == 1 && !f.equal("robotStatic", "field_state", 0)) return reject(error, QStringLiteral("进入部署前须新鲜确认机器人已上场"));
        if (!f.equal("deployMode", "status", 1-mode)) return reject(error, QStringLiteral("当前部署状态旧、缺失或不匹配请求"));
        return mode == 0 || f.equal("robotStatic", "alive_state", 1) || reject(error, QStringLiteral("进入部署前须新鲜确认存活"));
    }
    if (topic == "RuneActivateCommand") {
        if (!fieldsOnly(fields, {"activate"}, {"activate"}, error) || !unsignedInteger(fields.value("activate"))) return reject(error, QStringLiteral("机关命令只接受activate=1"));
        if (fields.value("activate").toUInt()!=1) return reject(error, QStringLiteral("官方协议没有取消机关动作"));
        reason=runeReason(f,configuration);
    } else if (topic == "AssemblyCommand") {
        if (!fieldsOnly(fields, {"operation","difficulty"}, {"operation","difficulty"}, error)) return false;
        quint32 operation=0,difficulty=0;
        if (!unsignedInteger(fields.value("operation"), &operation) || operation > 2 || !unsignedInteger(fields.value("difficulty"), &difficulty) || difficulty < 1 || difficulty > 4)
            return reject(error, QStringLiteral("装配操作／难度超出官方范围"));
        const auto context=assemblyView(f,assemblyConfiguration,configuredElapsed,contextCurrent);
        const bool exitOnly=assemblyExitPending(f,m_assemblyExitRound);
        if (operation != 0 && m_assemblyEnded && !(operation==2 && difficulty==4 && exitOnly))
            return reject(error, QStringLiteral("已收到装配结束事件，旧操作上下文已失效"));
        reason=assemblyReason(f,context,operation,difficulty);
    } else if (topic == "DartCommand") {
        if (!fieldsOnly(fields, {"target_id","open","launch_confirm"}, {}, error) || fields.size()!=1)
            return reject(error, QStringLiteral("每次飞镖请求只提交一个明确操作"));
        quint32 target=0;
        QString operation;
        if (fields.contains("target_id")) {
            if (!unsignedInteger(fields.value("target_id"), &target) || target < 1 || target > 5) return reject(error, QStringLiteral("飞镖目标编号须为1–5"));
            operation="target";
        } else if (fields.contains("open")) {
            if (fields.value("open").metaType().id()!=QMetaType::Bool) return reject(error, QStringLiteral("飞镖闸门须为明确布尔值"));
            operation=fields.value("open").toBool() ? "open" : "close";
        } else {
            if (!flag(fields.value("launch_confirm"))) return reject(error, QStringLiteral("发射须由操作手明确确认true"));
            operation="launch";
        }
        reason=dartReason(f,configuration,operation,target);
    } else if (topic == "SentryCtrlCommand") {
        if (!fieldsOnly(fields, {"command_id"}, {"command_id"}, error)) return false;
        quint32 command=0;
        if (!unsignedInteger(fields.value("command_id"), &command) || command < 1 || command > 12 || command == 2)
            return reject(error, QStringLiteral("官方哨兵指令仅定义1、3–12"));
        reason=flag(configuration.value("sentry_support_allowed"))
            ?supportCommandReason(m_localSentryGeneration==m_generation?localSupportView(f,m_backend,configuration,m_localSentry):QVariantMap{},command)
            :sentryReason(f,command);
    } else if (topic == "AirSupportCommand") {
        if (!fieldsOnly(fields, {"command_id"}, {"command_id"}, error)) return false;
        quint32 command=0;
        if (!unsignedInteger(fields.value("command_id"), &command) || command > 3) return reject(error, QStringLiteral("空中支援指令须为0–3"));
        reason=airReason(f,command);
    } else return reject(error, QStringLiteral("未连接的操作主题：")+topic.left(80));
    return reason.isEmpty() || reject(error, reason);
}
void OperatorActions::feedback(const QString &topic, bool accepted, const QString &reason) {
    m_feedback={{"topic",topic.left(128)},{"accepted",accepted},{"reason",reason.left(256)},
        {"client_id",m_backend ? m_backend->clientId() : 0},
        {"recorded_at",QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)}};
    emit commandFeedbackChanged();
}
bool OperatorActions::sendCommand(const QString &topic, const QVariantMap &fields) {
    QPointer<OperatorActions> alive(this);
    QString reason;
    if (!allowCommand(topic,fields,&reason)) {
        if (alive) {
            if (m_backend) m_backend->rejectOperatorCommand(topic, reason);
            else feedback(topic, false, reason);
        }
        return false;
    }
    if (!alive) return false;
    auto *backend=m_backend.data();
    if (!backend) {feedback(topic,false,QStringLiteral("客户端后端已关闭"));return false;}
    // Backend repeats the host guard immediately before encode/publish and owns
    // rate limits/history. Never mutate telemetry or manufacture an execution ACK.
    const bool accepted=backend->sendCommand(topic,fields);
    if (!alive) return accepted;
    const auto current=m_backend ? m_backend->commandFeedback() : QVariantMap{};
    if (current.isEmpty()) feedback(topic,accepted,accepted ? QString{} : QStringLiteral("发送未被后端接受"));
    else if (current!=m_feedback) {m_feedback=current;emit commandFeedbackChanged();}
    return accepted;
}
