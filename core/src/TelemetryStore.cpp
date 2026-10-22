#include "TelemetryStore.h"
#include "RobotIdentity.h"
#include <QTimer>
#include <QPointer>
#include <QDateTime>
#include <QUuid>

namespace {
const QMap<QString, QString> groups{
#define RM_TELEMETRY_GROUP(name, type) {QStringLiteral(#type), QStringLiteral(#name)},
#include "TelemetryGroups.def"
#undef RM_TELEMETRY_GROUP
};
qint64 lifetime(const QString &group) {
    return group == "robotDynamic" ? 1000 : group == "gameStatus" ? 1500 : 3500;
}
}
TelemetryStore::TelemetryStore(QObject *parent) : TelemetryEndpoint(parent) {
    m_clock.start();
    m_observationSession = QUuid::createUuid().toString(QUuid::WithoutBraces);
    auto *timer = new QTimer(this);
    timer->setInterval(250);
    connect(timer, &QTimer::timeout, this, &TelemetryStore::updateFreshness);
    timer->start();
}
void TelemetryStore::apply(const QString &messageType, const QVariantMap &fields) {
    // Legacy/native fixtures have no transport callback proof. They remain
    // usable for local state, but cannot claim callback-verified freshness.
    const auto sample = PacketObservation::capture(
        QStringLiteral("local_direct"), m_observationSession, qint64(++m_directSequence));
    applySample(messageType, fields, sample, 0, false, nullptr);
}
bool TelemetryStore::rejectIngress(const QString &reason, QString *error) {
    m_ingressRejected = qMin<quint64>(m_ingressRejected + 1, PacketObservation::SafeInteger);
    m_ingressRejection = reason;
    if (error)
        *error = reason;
    return false;
}
bool TelemetryStore::applyObserved(const QString &messageType, const QVariantMap &fields,
                                   const QVariantMap &observation, QString *error) {
    if (error)
        error->clear();
    PacketObservation::Stamp sample;
    qint64 ageMs = 0;
    QString reason;
    // Validate again at the consumer: time spent decoding and waiting on the
    // GUI queue is part of the sample age, never a fresh receive operation.
    if (!PacketObservation::parse(observation, &sample, &reason) ||
        !PacketObservation::validateAt(sample, QDateTime::currentMSecsSinceEpoch(),
                                       PacketObservation::steadyMilliseconds(), &ageMs, &reason))
        return rejectIngress(reason, error);
    return applySample(messageType, fields, sample, ageMs, true, error);
}
bool TelemetryStore::applySample(const QString &messageType, const QVariantMap &fields,
                                 const PacketObservation::Stamp &sample, qint64 ageMs,
                                 bool observed, QString *error) {
    const QString group = groups.value(messageType);
    if (group.isEmpty() || fields.isEmpty())
        return observed ? rejectIngress(QStringLiteral("Unknown or empty telemetry packet"), error)
                        : false;
    // An observed stream is bound to one transport session until reset. In
    // particular, an adapter cannot relabel an old packet as a new session to
    // revive it. The native apply() fixture API does not bind that stream.
    if (observed && m_hasIngress) {
        if (sample.session != m_lastIngress.session)
            return rejectIngress(QStringLiteral("Telemetry ingress session changed without reset"), error);
        if (sample.sequence <= m_lastIngress.sequence || sample.receivedTick < m_lastIngress.receivedTick)
            return rejectIngress(QStringLiteral("Duplicate or regressed telemetry ingress"), error);
    }
    const auto previous = m_fieldIngress.value(group);
    for (auto it = fields.cbegin(); it != fields.cend(); ++it) {
        const auto existing = previous.constFind(it.key());
        if (existing == previous.cend())
            continue;
        const auto &prior = existing.value().stamp;
        if (sample.receivedTick < prior.receivedTick ||
            (sample.session == prior.session && sample.sequence <= prior.sequence))
            return rejectIngress(QStringLiteral("Telemetry field ingress moved backwards"), error);
    }
    QPointer<TelemetryStore> lifetime(this);
    const auto revision = ++m_revision;
    auto values = m_values.value(group).toMap();
    // 原始optional值继续保留用于协议查看；带身份/阶段的显示记录另记变化边界。
    // 相同类型/阶段心跳不重开上下文，相同数值在新上下文重收时仍须通知显示层。
    quint64 *contextRevision=group==QLatin1String("buff")?&m_buffContextRevision
        :group==QLatin1String("gameStatus")?&m_gameContextRevision:nullptr;
    bool contextChanged=false;
    if(contextRevision) {
        const QStringList contextKeys=group==QLatin1String("buff")
            ?QStringList{QStringLiteral("robot_id"),QStringLiteral("buff_type")}
            :QStringList{QStringLiteral("current_stage"),QStringLiteral("current_round")};
        for(const auto &key:contextKeys)
            if(fields.contains(key) && (!values.contains(key) || fields.value(key)!=values.value(key)))
                *contextRevision=revision;
        for(auto it=fields.cbegin();it!=fields.cend();++it)
            if(m_fieldObservationRevision.value(group).value(it.key())<*contextRevision)
                contextChanged=true;
    }
    ageMs = qMax(ageMs, PacketObservation::steadyMilliseconds() - sample.receivedTick);
    const auto receivedAt = m_clock.elapsed() - ageMs;
    if (observed) {
        m_lastIngress = sample;
        m_hasIngress = true;
    }
    m_ingressAccepted = qMin<quint64>(m_ingressAccepted + 1, PacketObservation::SafeInteger);
    m_lastQueueAge = ageMs;
    bool changed = false;
    for (auto it = fields.cbegin(); it != fields.cend(); ++it) {
        m_fieldSeen[group][it.key()] = receivedAt;
        // These identify an actual receive operation, including same-value
        // packets. Reading fieldObservations must never create a new sample.
        m_fieldReceivedUtc[group][it.key()] = sample.receivedUtc;
        m_fieldObservationRevision[group][it.key()] = revision;
        m_fieldIngress[group][it.key()] = {sample, ageMs};
        if (!values.contains(it.key()) || values.value(it.key()) != it.value()) {
            values.insert(it.key(), it.value());
            changed = true;
        }
    }
    if (changed)
        m_values[group] = values;
    m_lastSeen[group] = m_lastSeen.contains(group) ? qMax(m_lastSeen.value(group), receivedAt)
                                                 : receivedAt;
    const bool robotsChanged =
        changed && (group == "globalUnit" || group == "robotStatic" || group == "robotDynamic") &&
        rebuildRobotData();
    const bool freshnessUpdated = refreshFreshness();
    // 首次通知前先提交派生状态和时效，使接收者看到一致快照。
    // 若回调重入并提交新数据，外层剩余通知不再覆盖新的版本。
    if (changed || contextChanged || group == "event" || group == "penalty")
        notifyGroup(group);
    if (!lifetime || revision != m_revision)
        return true;
    if (group == "event" && ageMs < ::lifetime(group) && fields.contains("event_id"))
        emit eventReceived(fields.value("event_id").toInt(), fields.value("param").toString());
    if (!lifetime || revision != m_revision)
        return true;
    if (group == "penalty" && ageMs < ::lifetime(group) && fields.contains("penalty_type"))
        emit penaltyReceived(fields.value("penalty_type").toInt(),
                             fields.value("penalty_effect_sec").toInt(),
                             fields.value("total_penalty_num").toInt());
    if (!lifetime || revision != m_revision)
        return true;
    if (robotsChanged)
        emit robotDataChanged();
    if (!lifetime || revision != m_revision)
        return true;
    if (freshnessUpdated)
        emit freshnessChanged();
    return true;
}
void TelemetryStore::reset() {
    QPointer<TelemetryStore> lifetime(this);
    const auto revision = ++m_revision;
    m_values.clear();
    m_lastSeen.clear();
    m_fieldSeen.clear();
    m_fieldReceivedUtc.clear();
    m_fieldObservationRevision.clear();
    m_buffContextRevision=0;
    m_gameContextRevision=0;
    m_fieldIngress.clear();
    m_lastIngress = {};
    m_hasIngress = false;
    m_directSequence = 0;
    m_ingressAccepted = m_ingressRejected = 0;
    m_ingressRejection.clear();
    m_lastQueueAge = 0;
    m_observationSession = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_robotData.clear();
    const bool freshnessUpdated = refreshFreshness();
    // 任意分组通知都可能触发换身份或提交新数据。
    // 一旦重入，已中断的 reset 不应继续通知或覆盖新状态。
#define RM_TELEMETRY_GROUP(name, type)                                                             \
    notifyGroup(QStringLiteral(#name));                                                            \
    if (!lifetime || revision != m_revision)                                                       \
        return;
#include "TelemetryGroups.def"
#undef RM_TELEMETRY_GROUP
    emit robotDataChanged();
    if (!lifetime || revision != m_revision)
        return;
    if (freshnessUpdated)
        emit freshnessChanged();
}
void TelemetryStore::setClientId(int id) {
    m_clientId = id;
    reset();
}
void TelemetryStore::updateFreshness() {
    if (refreshFreshness())
        emit freshnessChanged();
}
bool TelemetryStore::refreshFreshness() {
    QVariantMap result, fieldResult;
    const auto now = m_clock.elapsed();
    for (auto it = groups.cbegin(); it != groups.cend(); ++it) {
        const QString group = it.value();
        // 全局遥测约 1 Hz、自身动态遥测约 10 Hz、比赛状态约 5 Hz。
        const qint64 threshold = lifetime(group);
        result[group] = !m_lastSeen.contains(group)                  ? "missing"
                        : now - m_lastSeen.value(group) < threshold ? "fresh"
                                                                     : "stale";
        QVariantMap fieldStates;
        const auto seen = m_fieldSeen.value(group);
        for (auto field = seen.cbegin(); field != seen.cend(); ++field)
            fieldStates[field.key()] = now - field.value() < threshold ? "fresh" : "stale";
        if (!fieldStates.isEmpty())
            fieldResult[group] = fieldStates;
    }
    if (result != m_freshness || fieldResult != m_fieldFreshness) {
        m_freshness = result;
        m_fieldFreshness = fieldResult;
        return true;
    }
    return false;
}
bool TelemetryStore::rebuildRobotData() {
    // 从当前分组派生机器人索引，避免再维护一份可修改的独立缓存。
    // optional 字段只在 apply 中合并一次；fieldFreshness 单独记录
    // 每个保留字段是否真的被本次消息更新。
    QVariantMap result;
    const auto health = globalUnit().value("robot_health").toList();
    const auto bullets = globalUnit().value("robot_bullets").toList();
    for (int id : {1, 2, 3, 4, 7, 101, 102, 103, 104, 107}) {
        QVariantMap robot;
        const int index = RobotIdentity::healthIndex(id, m_clientId);
        if (index >= 0 && index < health.size()) {
            robot["current_health"] = health[index];
            robot["current_health_source"] = "globalUnit";
        } else {
            robot.remove("current_health");
            robot.remove("current_health_source");
        }
        const int bulletIndex = RobotIdentity::unitIndex(id);
        if (m_clientId > 0 && (id > 100) == (m_clientId > 100) &&
            (bullets.size() == 5 || bullets.size() == 10) &&
            bulletIndex >= 0 && bulletIndex < bullets.size())
            robot["remaining_bullets"] = bullets[bulletIndex];
        else
            robot.remove("remaining_bullets");
        result[QString::number(id)] = robot;
    }
    // 静态与动态消息描述当前选择的机器人，不能覆盖任意队友。
    const int robotId = robotStatic().value("robot_id", m_clientId).toInt();
    if (robotId == m_clientId && RobotIdentity::valid(robotId)) {
        auto robot = result.value(QString::number(robotId)).toMap();
        const auto fixed = robotStatic();
        const auto dynamic = robotDynamic();
        for (auto it = fixed.cbegin(); it != fixed.cend(); ++it)
            robot[it.key()] = it.value();
        for (auto it = dynamic.cbegin(); it != dynamic.cend(); ++it)
            robot[it.key()] = it.value();
        if (dynamic.contains("current_health"))
            robot["current_health_source"] = "robotDynamic";
        if (dynamic.contains("remaining_ammo"))
            robot["remaining_bullets"] = dynamic.value("remaining_ammo");
        result[QString::number(robotId)] = robot;
    }
    if (result != m_robotData) {
        m_robotData = result;
        return true;
    }
    return false;
}

QVariantMap TelemetryStore::fieldObservation(const QString &groupName, const QString &fieldName) const {
    const auto group=m_fieldSeen.constFind(groupName);
    if(group==m_fieldSeen.cend())return {};
    const auto field=group->constFind(fieldName);
    if(field==group->cend())return {};
    return buildFieldObservation(groupName,fieldName,field.value(),m_clock.elapsed());
}

QVariantMap TelemetryStore::buildFieldObservation(const QString &groupName, const QString &fieldName,
                                                 qint64 seenAt, qint64 now) const {
    const qint64 age=qMax<qint64>(0,now-seenAt);
    const auto ingress=m_fieldIngress.value(groupName).value(fieldName);
    QVariantMap result{{"received_age_ms",age}, {"lifetime_ms",lifetime(groupName)},
            {"remaining_ms",qMax<qint64>(0,lifetime(groupName)-age)}, {"clock","local_monotonic"},
            {"observation_revision",m_fieldObservationRevision.value(groupName).value(fieldName)},
            {"received_at_ms",m_fieldReceivedUtc.value(groupName).value(fieldName)},
            {"observation_session_id",m_observationSession}, {"ingress_basis",ingress.stamp.basis},
            {"ingress_clock_verified",ingress.stamp.basis=="mqtt_callback"},
            {"ingress_session_id",ingress.stamp.session}, {"ingress_sequence",ingress.stamp.sequence},
            {"queue_age_ms_at_ingest",ingress.queueAge}};
    if(groupName==QLatin1String("buff"))
        result.insert(QStringLiteral("context_revision"),m_buffContextRevision);
    else if(groupName==QLatin1String("gameStatus"))
        result.insert(QStringLiteral("context_revision"),m_gameContextRevision);
    return result;
}

QVariantMap TelemetryStore::group(const QString &name) const {
    if (name == QLatin1String("fieldObservations")) {
        // Host-local receive age only: official messages do not supply a
        // trustworthy producer timestamp. A captured TTL never renews itself
        // merely because a later message refreshed the live store.
        QVariantMap observations;
        const auto now = m_clock.elapsed();
        for (auto group = m_fieldSeen.cbegin(); group != m_fieldSeen.cend(); ++group) {
            QVariantMap fields;
            for (auto field = group.value().cbegin(); field != group.value().cend(); ++field) {
                fields[field.key()] = buildFieldObservation(group.key(),field.key(),field.value(),now);
            }
            observations[group.key()] = fields;
        }
        return observations;
    }
    if (name == QLatin1String("ingressDiagnostics"))
        return {{"accepted_packets", m_ingressAccepted}, {"rejected_packets", m_ingressRejected},
                {"last_rejection", m_ingressRejection}, {"last_queue_age_ms", m_lastQueueAge},
                {"active_session_id", m_hasIngress ? m_lastIngress.session : QString{}},
                {"last_sequence", m_hasIngress ? m_lastIngress.sequence : 0}};
    if (name == QLatin1String("robotData"))
        return m_robotData;
    if (name == QLatin1String("freshness"))
        return m_freshness;
    if (name == QLatin1String("fieldFreshness"))
        return m_fieldFreshness;
    return m_values.value(name).toMap();
}
