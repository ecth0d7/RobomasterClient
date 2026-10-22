#include "ServiceHub.h"
#include "SeasonConfiguration.h"
#include "PacketObservation.h"
#include <QUuid>
#include <QDateTime>
#include "AdviceContract.h"
#include "DecisionContext.h"
#include "DecisionConfiguration.h"
#include "DataSourceHost.h"
#include "RobotIdentity.h"
#include <QJsonObject>
#include <QJsonDocument>
#include <QPointer>
#include <QScopeGuard>
#include <QSet>
#include <QThread>
#include <stdexcept>
#include <cmath>
#include <tuple>
#include <utility>
#include <chrono>

namespace {
// Endpoints can emit synchronously from stop(), and a consumer may delete the
// emitter. Release unique ownership first; the guarded pointer prevents a
// second delete while still stopping every normally owned endpoint explicitly.
void retireEndpoint(std::unique_ptr<ServiceEndpoint> owned) {
    QPointer<ServiceEndpoint> endpoint(owned.release());
    if (!endpoint) return;
    endpoint->stop();
    if (endpoint) delete endpoint.data();
}
bool speechLeaseActive(const QVariantMap &details) {
    const auto value = details.value("provider_active");
    return !details.contains("provider_active") ||
        (value.metaType().id() == QMetaType::Bool && value.toBool());
}
bool speechFlag(const QVariant &value, bool expected) {
    return value.metaType().id() == QMetaType::Bool && value.toBool() == expected;
}
bool bridgeInteger(const QVariant &value, double low, double high) {
    const auto type = value.metaType().id();
    if (type != QMetaType::Int && type != QMetaType::UInt && type != QMetaType::LongLong &&
        type != QMetaType::ULongLong && type != QMetaType::Double) return false;
    const auto number = value.toDouble();
    return std::isfinite(number) && std::floor(number) == number && number >= low && number <= high;
}
bool bridgeText(const QVariant &value, int maximum, bool empty = false) {
    if (value.metaType().id() != QMetaType::QString || value.toString().size() > maximum ||
        (!empty && value.toString().trimmed().isEmpty())) return false;
    for (const auto c : value.toString()) if (c.isNull() || c.category() == QChar::Other_Control) return false;
    return true;
}
bool bridgeJson(const QVariant &value, int depth, int *nodes, qsizetype *cost) {
    if (++*nodes > 8192 || depth > 8 || *cost > 256 * 1024) return false;
    if (!value.isValid() || value.isNull()) { *cost += 4; return true; }
    const auto type = value.metaType().id();
    if (type == QMetaType::QVariantMap) {
        const auto map = value.toMap(); if (map.size() > 256) return false;
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            if (!bridgeText(it.key(), 256)) return false;
            *cost += it.key().size() * 3 + 4;
            if (!bridgeJson(it.value(), depth + 1, nodes, cost)) return false;
        }
        return true;
    }
    if (type == QMetaType::QVariantList) {
        const auto list = value.toList(); if (list.size() > 2048) return false;
        for (const auto &entry : list) if (!bridgeJson(entry, depth + 1, nodes, cost)) return false;
        return true;
    }
    if (type == QMetaType::QString) {
        if (value.toString().size() > 65536) return false;
        *cost += value.toString().size() * 3 + 2; return *cost <= 256 * 1024;
    }
    if (type == QMetaType::Bool) { *cost += 5; return true; }
    if (type != QMetaType::Int && type != QMetaType::UInt && type != QMetaType::LongLong &&
        type != QMetaType::ULongLong && type != QMetaType::Double && type != QMetaType::Float) return false;
    *cost += 24; return std::isfinite(value.toDouble());
}
QVariant redactBridgeValue(const QVariant &value, const QString &token) {
    if (token.isEmpty()) return value;
    if (value.metaType().id() == QMetaType::QString) { auto text = value.toString(); return text.replace(token, "<bridge-token>"); }
    if (value.metaType().id() == QMetaType::QVariantMap) {
        QVariantMap result;
        const auto map = value.toMap();
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            auto key = it.key(); key.replace(token, "<bridge-token>"); result[key] = redactBridgeValue(it.value(), token);
        }
        return result;
    }
    if (value.metaType().id() == QMetaType::QVariantList) {
        QVariantList result; for (const auto &entry : value.toList()) result.append(redactBridgeValue(entry, token)); return result;
    }
    return value;
}
qint64 steadyMilliseconds() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}
QString spokenNumber(const QVariant &value) {
    if (value.metaType().id() == QMetaType::QString || value.metaType().id() == QMetaType::Bool)
        return {};
    bool ok = false;
    const auto number = value.toDouble(&ok);
    return ok && std::isfinite(number) && number >= 0 && number <= 1000000
               ? QString::number(number, 'f', std::floor(number) == number ? 0 : 1)
               : QString{};
}
QString spokenFacts(const QVariantMap &input) {
    const auto dynamic = input.value("groups").toMap().value("robotDynamic").toMap();
    const auto facts = input.value("computed_facts").toMap();
    QStringList parts;
    for (const auto &[label, field, ratio] :
         {std::tuple{"生命", "current_health", "health_percent"},
          std::tuple{"热量", "current_heat", "heat_percent"}}) {
        const auto percentage = spokenNumber(facts.value(ratio));
        const auto raw = spokenNumber(dynamic.value(field));
        parts.append(!percentage.isEmpty() ? QString("%1百分之%2").arg(label, percentage)
                     : !raw.isEmpty()      ? QString("%1%2，上限未收").arg(label, raw)
                                           : QString("%1未收").arg(label));
    }
    const auto ammo = spokenNumber(dynamic.value("remaining_ammo"));
    parts.append(ammo.isEmpty() ? QString("允许弹量未收") : QString("允许弹量%1").arg(ammo));
    return QString("本次输入快照。%1。").arg(parts.join("，"));
}
QVariant jsonValue(const QVariant &value) {
    if (value.metaType().id() == QMetaType::QByteArray)
        return QVariantMap{{"encoding", "base64"},
                           {"data", QString::fromLatin1(value.toByteArray().toBase64())}};
    if (value.metaType().id() == QMetaType::QVariantMap) {
        auto result = value.toMap();
        for (auto it = result.begin(); it != result.end(); ++it)
            it.value() = jsonValue(it.value());
        return result;
    }
    if (value.metaType().id() == QMetaType::QVariantList) {
        auto result = value.toList();
        for (auto &entry : result)
            entry = jsonValue(entry);
        return result;
    }
    return value;
}
}
ServiceHub::ServiceHub(ClientBackend *backend, QObject *parent)
    : QObject(parent), m_backend(backend),
      m_source(QUuid::createUuid().toString(QUuid::WithoutBraces)) {
    if (!backend)
        throw std::invalid_argument("ServiceHub requires a backend");
    m_clock.start();
    m_dataSources = std::make_unique<DataSourceHost>(backend, this);
    connect(m_dataSources.get(), &DataSourceHost::changed, this, &ServiceHub::sourceDataChanged);
    connect(this, &ServiceHub::decisionInputChanged, this, &ServiceHub::refreshInputValidity);
    connect(backend, &ClientBackend::identityChanged, this, [this] {
        QPointer<ServiceHub> lifetime(this);
        // A reconnect emits identityChanged even for the same robot. Independent
        // local/team sources must not lose their session for that reconnect.
        if (m_aggregation && m_backend && m_aggregationRobot != m_backend->clientId()) {
            disableOptionalService("aggregation");
            if (!lifetime) return;
        }
        m_dirty = true;
        cancelDecisionRequest();
        if (!lifetime)
            return;
        stopSpeech();
        if (!lifetime)
            return;
        m_advice.clear();
        m_decisionInput.clear();
        emit adviceChanged();
        if (!lifetime)
            return;
        emit decisionInputChanged();
        if (!lifetime)
            return;
        emit serviceStatusChanged();
    });
    connect(backend, &ClientBackend::connectionChanged, this, [this] {
        if (!m_backend)
            return;
        m_dirty = true;
        QPointer<ServiceHub> lifetime(this);
        if (!m_backend->connected()) {
            cancelDecisionRequest();
            if (!lifetime)
                return;
            stopSpeech();
            if (!lifetime)
                return;
            if (!m_advice.isEmpty()) {
                m_advice["fresh"] = false;
                emit adviceChanged();
            }
            if (!lifetime)
                return;
        }
        emit serviceStatusChanged();
    });
    connect(backend, &QObject::destroyed, this, [this] {
        QPointer<ServiceHub> lifetime(this);
        m_dirty = false;
        m_advice.clear();
        m_decisionInput.clear();
        cancelDecisionRequest();
        if (!lifetime)
            return;
        stopSpeech();
        if (!lifetime)
            return;
        disableOptionalService("bridge");
        if (!lifetime)
            return;
        disableOptionalService("aggregation");
        if (!lifetime) return;
        emit adviceChanged();
        if (!lifetime)
            return;
        emit decisionInputChanged();
        if (!lifetime)
            return;
        emit serviceStatusChanged();
    });
    auto *state = backend->telemetry();
    m_state = state;
#define RM_TELEMETRY_GROUP(name, type)                                                             \
    connect(state, &TelemetryEndpoint::name##Changed, this, [this] { m_dirty = true; });
#include "TelemetryGroups.def"
#undef RM_TELEMETRY_GROUP
    connect(state, &TelemetryEndpoint::freshnessChanged, this, [this] {
        m_dirty = true;
        QPointer<ServiceHub> lifetime(this);
        if (!decisionEvidenceFresh() && m_advice.value("fresh").toBool()) {
            m_advice["fresh"] = false;
            emit adviceChanged();
            if (!lifetime)
                return;
        }
        refreshInputValidity();
        if (!lifetime)
            return;
        emit serviceStatusChanged();
    });
    connect(
        state, &TelemetryEndpoint::eventReceived, this, [this](int id, const QString &parameter) {
            if (!m_backend || !m_bridge || !m_bridgeExportEvents || !bridgeBoundaryAllowed())
                return;
            QPointer<ServiceHub> alive(this); QPointer<ServiceEndpoint> endpoint(m_bridge.get());
            const auto generation = m_bridgeGeneration;
            QString error;
            const auto frame = message("event", {{"event_id", id}, {"param", parameter}});
            if (!alive || !endpoint || generation != m_bridgeGeneration) return;
            endpoint->submit(frame, &error);
        });
    m_timer.setInterval(100);
    connect(&m_timer, &QTimer::timeout, this, [this] {
        QPointer<ServiceHub> lifetime(this);
        if (m_backend && m_bridge && m_bridgeExportSnapshots && bridgeBoundaryAllowed() &&
            (m_dirty || m_clock.elapsed() - m_lastPublished >= 1000))
            publishSnapshot();
        if (!lifetime)
            return;
        bool changed = false;
        for (auto it = m_peerSeen.cbegin(); it != m_peerSeen.cend(); ++it) {
            auto peer = m_peers.value(it.key()).toMap();
            const bool fresh = m_clock.elapsed() - it.value() <= 3500;
            if (peer.value("fresh").toBool() != fresh) {
                peer["fresh"] = fresh;
                peer["arrival_fresh"] = fresh;
                m_peers[it.key()] = peer;
                changed = true;
                m_bridgeDiagnosticsDirty = true;
            }
        }
        if (changed || m_peersDirty) {
            m_peersDirty = false;
            emit peersChanged();
        }
        if (!lifetime)
            return;
        if (m_bridgeDiagnosticsDirty) {
            m_bridgeDiagnosticsDirty = false;
            emit serviceStatusChanged();
        }
        if (!lifetime) return;
        if (m_advice.value("fresh").toBool() &&
            (m_clock.elapsed() >= m_adviceExpires || !decisionEvidenceFresh())) {
            m_advice["fresh"] = false;
            emit adviceChanged();
        }
        if (!lifetime)
            return;
        refreshInputValidity();
        if (!lifetime)
            return;
        scheduleDecision();
        if (lifetime && !m_decisionTrace.isEmpty())
            emit decisionPolicyStatusChanged();
        if (!lifetime) return;
        publishSourceSnapshot();
        if (!lifetime) return;
        if (m_aggregation && m_clock.elapsed() - m_lastAggregationNotification >= 250) {
            m_lastAggregationNotification = m_clock.elapsed();
            emit aggregationChanged();
        }
    });
    m_timer.start();
}
ServiceHub::~ServiceHub() {
    blockSignals(true);
    m_timer.stop();
    if (m_backend)
        m_backend->disconnect(this);
    if (m_state)
        m_state->disconnect(this);
    // 端点析构停止任务时也可能通知；开始销毁成员前先断开转发回调。
    for (auto *endpoint : {m_bridge.get(), m_decision.get(), m_speech.get(), m_aggregation.get()})
        if (endpoint)
            endpoint->disconnect(this);
}
void ServiceHub::reportOptionalStartupFailure(const QString &role, const QString &error) {
    const QString reason = error.isEmpty() ? QStringLiteral("可选服务未能启动，未提供原因") : error;
    if (role == QStringLiteral("bridge") && !m_bridge) {
        m_bridgeError = QStringLiteral("可选原始桥启动失败：") + reason;
        m_bridgeStartupFailed = true;
    } else if (role == QStringLiteral("decision") && !m_decision) {
        m_decisionError = QStringLiteral("可选模型服务启动失败：") + reason;
        m_decisionStartupFailed = true;
    } else if (role == QStringLiteral("speech") && !m_speech) {
        m_speechError = QStringLiteral("可选语音服务启动失败：") + reason;
        m_speechStartupFailed = true;
    } else if (role == QStringLiteral("aggregation") && !m_aggregation) {
        m_aggregationError = QStringLiteral("可选队伍汇总启动失败：") + reason;
        m_aggregationStartupFailed = true;
    } else
        return;
    emit serviceStatusChanged();
}

void ServiceHub::setTeamConfiguration(QObject *configuration) {
    if (m_teamConfiguration) m_teamConfiguration->disconnect(this);
    m_teamConfiguration = configuration;
    if (configuration) {
        // Separate notify channel avoids a loop: TeamConfiguration already
        // listens to serviceStatusChanged to refresh its own runtime details.
        connect(configuration, SIGNAL(stateChanged()), this, SIGNAL(teamIdentityChanged()));
        connect(configuration, SIGNAL(currentChanged()), this, SIGNAL(teamIdentityChanged()));
    }
    emit teamIdentityChanged();
}
QString ServiceHub::aggregationStatus() const {
    if (!m_aggregationError.isEmpty()) return m_aggregationError;
    return m_aggregation ? m_aggregation->status()
                         : QStringLiteral("队伍汇总未启用；本机数据路径独立");
}
QVariantMap ServiceHub::aggregationDetails() const {
    auto result = m_aggregation ? m_aggregation->details()
        : optionalFailureDetails(m_aggregationError, m_aggregationStartupFailed);
    result["host_lifecycle_connected"] = true;
    result["host_input_connected"] = bool(m_dataSources);
    result["official_source_producer_connected"] = bool(m_dataSources);
    result["source_snapshot_submissions"] = qulonglong(m_sourceSubmissionCount);
    result["last_source_snapshot_id"] = m_lastSourceSnapshotId;
    result["source_submission_error"] = m_sourceSubmissionError;
    result["source_submission_is_delivery_ack"] = false;
    result["ai_input_ready"] = false;
    result["source_signatures_independently_verified_by_host"] = false;
    return result;
}
QObject *ServiceHub::sourceConfiguration() const { return m_dataSources.get(); }
QVariantMap ServiceHub::localDataView() const {
    auto result = m_dataSources ? m_dataSources->localView() : QVariantMap{};
    if (!result.isEmpty() && m_seasonConfiguration)
        result["rules_context"] = m_seasonConfiguration->context();
    return result;
}
QObject *ServiceHub::seasonConfiguration() const { return m_seasonConfiguration.data(); }
void ServiceHub::setSeasonConfiguration(SeasonConfiguration *configuration) {
    m_seasonConfiguration = configuration;
    if (!configuration) return;
    connect(configuration, &SeasonConfiguration::aboutToChange, this, [this] {
        disableOptionalService("bridge");
    });
    if (m_dataSources) m_dataSources->setRulesContext(configuration->context());
    connect(configuration, &SeasonConfiguration::contextChanged, this, [this] {
        if (m_dataSources && m_seasonConfiguration)
            m_dataSources->setRulesContext(m_seasonConfiguration->context());
        invalidateDecisionPolicy();
        emit sourceDataChanged();
        emit serviceStatusChanged();
    });
}
QString ServiceHub::optionalServiceBlockReason(const QString &role, const QString &pluginId) const {
    return m_seasonConfiguration
        ? m_seasonConfiguration->optionalServiceBlockReason(role, pluginId) : QString{};
}
void ServiceHub::addTerminalGateway(const QString &id, const QString &title, QObject *gateway) {
    if (gateway) m_terminalGateways.append({id, title, gateway});
}
QVariantList ServiceHub::terminalGateways() const {
    QVariantList result;
    for (const auto &entry : m_terminalGateways)
        if (entry.gateway)
            result.append(QVariantMap{{"id", entry.id}, {"title", entry.title},
                                       {"runtime", QVariant::fromValue(entry.gateway.data())}});
    return result;
}
void ServiceHub::setOperatorPreferences(QObject *preferences) {
    m_operatorPreferences = preferences;
    if (m_dataSources) m_dataSources->setPhaseGuard(preferences);
}
QVariantMap ServiceHub::aggregationView() const {
    const auto details = aggregationDetails();
    return m_teamView.view(QDateTime::currentMSecsSinceEpoch(), steadyMilliseconds(),
        details.value("active").toBool() && details.value("connected").toBool());
}
QVariantMap ServiceHub::teamIdentity() const {
    auto result = m_teamConfiguration ? m_teamConfiguration->property("state").toMap() : QVariantMap{};
    const auto details = aggregationDetails();
    result["status"] = aggregationStatus();
    result["health"] = details.value("state", "disabled");
    result["team_id"] = details.value("team_id", QString{});
    result["local_node"] = details.value("node_id", QString{});
    result["issuer"] = details.value("publisher_id", QString{});
    result["shared_configuration_revision"] = details.value("configuration_revision");
    result["broker_tls_connected"] = details.value("connected", false);
    // A connected broker and a module's 'verified' flag are not independent
    // host evidence for an original measurement or official export identity.
    result["authenticated"] = false;
    result["verified"] = false;
    result["voice_owner"] = QString{};
    result["rejection"] = details.value("error", m_aggregationError);
    result["capabilities"] = QVariantMap{{"inspectCertificate", false}, {"teamInput", false}, {"teamVoice", false}};
    QVariantList members;
    for (const auto &value : aggregationView().value("members").toList()) {
        auto member = value.toMap();
        member["state"] = member.value("state") == "offline" ? "offline" : "pending";
        members.append(member);
    }
    result["peers"] = members;
    return result;
}
bool ServiceHub::startAggregation(std::unique_ptr<ServiceEndpoint> aggregation,
                                   const QVariantMap &configuration, QString *error) {
    const auto blocked = optionalServiceBlockReason("aggregation", "team.aggregate.v2");
    if (!blocked.isEmpty()) {
        if (error) *error = blocked;
        return false;
    }
    if (!aggregation) {
        if (error) *error = QStringLiteral("队伍插件未能创建端点");
        return false;
    }
    const auto robot = configuration.value("robot_id");
    if (!m_backend || robot.metaType().id() == QMetaType::Bool || robot.metaType().id() == QMetaType::QString
        || robot.toDouble() != robot.toInt() || !RobotIdentity::valid(robot.toInt())
        || robot.toInt() != m_backend->clientId()) {
        if (error) *error = QStringLiteral("队伍插件身份与当前本机范围不匹配");
        return false;
    }
    QPointer<ServiceHub> alive(this);
    if (m_aggregation) {
        const auto retirement = m_aggregationGeneration + 1;
        disableOptionalService("aggregation");
        if (!alive || retirement != m_aggregationGeneration) return false;
    }
    const auto generation = ++m_aggregationGeneration;
    if (!aggregation->start(configuration, error)) return false;
    if (!alive || generation != m_aggregationGeneration) return false;
    auto previous = std::move(m_aggregation);
    if (previous) {
        previous->disconnect(this);
        previous->stop();
    }
    if (!alive || generation != m_aggregationGeneration) return false;
    m_aggregation = std::move(aggregation);
    m_aggregationRobot = robot.toInt();
    m_aggregationCanSend = configuration.value("can_send").metaType().id() == QMetaType::Bool
        && configuration.value("can_send").toBool();
    m_sourceWasConnected = false;
    m_lastSourceSnapshotId.clear(); m_sourceSubmissionError.clear(); m_sourceSubmissionCount = 0;
    m_teamView.reset(configuration);
    if (m_dataSources) {
        m_dataSources->resetTeamExport();
        m_dataSources->setSharingConfiguration(configuration);
    }
    if (!alive || generation != m_aggregationGeneration) return false;
    m_aggregationError.clear();
    m_aggregationStartupFailed = false;
    connect(m_aggregation.get(), &ServiceEndpoint::statusChanged, this, [this, generation] {
        if (generation != m_aggregationGeneration) return;
        QPointer<ServiceHub> lifetime(this);
        emit serviceStatusChanged();
        if (!lifetime || generation != m_aggregationGeneration) return;
        emit aggregationChanged();
        if (!lifetime || generation != m_aggregationGeneration) return;
        emit teamIdentityChanged();
    });
    connect(m_aggregation.get(), &ServiceEndpoint::messageReceived, this,
        [this, generation](const QVariantMap &message) {
            if (generation == m_aggregationGeneration) receiveAggregation(message);
        });
    connect(m_aggregation.get(), &ServiceEndpoint::errorOccurred, this, [this, generation](const QString &message) {
        if (generation != m_aggregationGeneration) return;
        m_aggregationError = message.left(200);
        emit serviceStatusChanged();
    });
    emit serviceStatusChanged();
    if (!alive || generation != m_aggregationGeneration) return false;
    emit aggregationChanged();
    if (!alive || generation != m_aggregationGeneration) return false;
    emit teamIdentityChanged();
    return alive && generation == m_aggregationGeneration;
}
void ServiceHub::publishSourceSnapshot() {
    if (!m_aggregation || !m_dataSources || !m_aggregationCanSend) return;
    QPointer<ServiceHub> alive(this);
    const auto generation = m_aggregationGeneration;
    const auto details = m_aggregation->details();
    if (!alive || generation != m_aggregationGeneration) return;
    if (!details.value("active").toBool() || !details.value("connected").toBool()) {
        m_sourceWasConnected = false;
        return;
    }
    if (!m_sourceWasConnected) {
        m_sourceWasConnected = true;
        m_lastSourceSnapshotId.clear();
    }
    if (m_clock.elapsed() - m_lastSourceSubmission < 100) return;
    m_lastSourceSubmission = m_clock.elapsed();
    QString error;
    const auto snapshot = m_dataSources->teamSnapshot(&error);
    if (snapshot.isEmpty()) {
        m_sourceSubmissionError = error.left(240);
        return;
    }
    if (snapshot.value("snapshot_id") == m_lastSourceSnapshotId) return;
    const bool accepted = m_aggregation->submit(snapshot, &error);
    if (!alive || generation != m_aggregationGeneration) return;
    if (accepted) {
        ++m_sourceSubmissionCount;
        m_lastSourceSnapshotId = snapshot.value("snapshot_id").toString();
        m_sourceSubmissionError.clear();
    } else m_sourceSubmissionError = error.left(240);
    // submit() accepts a bounded adapter queue. TLS delivery, original source
    // proof verification, committed team AI and robot execution are separate.
}
void ServiceHub::receiveAggregation(const QVariantMap &message) {
    if (!m_aggregation) return;
    QString error;
    if (!m_teamView.accept(message, QDateTime::currentMSecsSinceEpoch(), steadyMilliseconds(), &error)) {
        m_aggregationError = QStringLiteral("队伍完整视图未通过宿主结构／范围／时效核对：") + error.left(160);
        emit serviceStatusChanged();
        return;
    }
    m_aggregationError.clear();
    QPointer<ServiceHub> alive(this);
    emit aggregationChanged();
    if (!alive) return;
    emit teamIdentityChanged();
}

void ServiceHub::disableOptionalService(const QString &role) {
    // Disconnect before stopping: a plugin may synchronously emit while cancelling.
    // Retain the shared library in PluginHost until all endpoints have died.
    QPointer<ServiceHub> alive(this);
    if (role == QLatin1String("bridge")) {
        const auto generation = ++m_bridgeGeneration;
        disconnect(m_bridgeOwnerConnection); m_bridgeOwnerConnection = {}; m_bridgeOwner.clear();
        m_bridgeExportSnapshots = m_bridgeExportEvents = false;
        m_bridgeToken.clear(); m_bridgeSequences.clear(); m_bridgeReceived = m_bridgeRejected = 0;
        m_bridgeLastReceivedUtc = 0; m_bridgeLastReceivedTick = -1; m_bridgeDiagnosticsDirty = false;
        auto previous = std::move(m_bridge);
        if (previous) previous->disconnect(this);
        // Clear remote projection before any retired provider callback. A later
        // owner must never inherit peers from this laboratory activation.
        m_peers.clear();
        m_peerSeen.clear();
        m_peerOrder.clear();
        m_peersDirty = false;
        m_dirty = true;
        retireEndpoint(std::move(previous));
        if (!alive || generation != m_bridgeGeneration) return;
        m_bridgeError.clear(); m_bridgeStartupFailed = false;
        emit peersChanged();
    } else if (role == QLatin1String("decision")) {
        ++m_decisionGeneration;
        m_decisionRequestId.clear();
        auto previous = std::move(m_decision);
        if (previous) {
            previous->disconnect(this);
            previous->stop();
        }
        if (!alive)
            return;
        m_decisionError.clear();
        m_decisionStartupFailed = false;
        m_advice.clear();
        m_decisionInput.clear();
        m_decisionTrace.clear();
        m_inputExpires = 0;
        m_lastAutomaticEvidence.clear();
        cancelInputSpeech();
        if (!alive)
            return;
        emit adviceChanged();
        if (!alive)
            return;
        emit decisionInputChanged();
    } else if (role == QLatin1String("speech")) {
        const auto generation = ++m_speechGeneration;
        ++m_speechEndpointGeneration;
        disconnect(m_speechOwnerConnection);
        m_speechOwnerConnection = {};
        m_speechOwner.clear();
        m_inputSpeechOutstanding = false;
        m_adviceSpeechKey.clear();
        auto previous = std::move(m_speech);
        if (previous) {
            previous->disconnect(this);
        }
        retireEndpoint(std::move(previous));
        if (!alive || generation != m_speechGeneration)
            return;
        m_speechError.clear();
        m_speechStartupFailed = false;
        m_localAudioApplied = false;
    } else if (role == QLatin1String("aggregation")) {
        const auto generation = ++m_aggregationGeneration;
        auto previous = std::move(m_aggregation);
        if (previous) {
            previous->disconnect(this);
            previous->stop();
        }
        if (!alive || generation != m_aggregationGeneration) return;
        m_teamView.reset();
        m_aggregationRobot = 0;
        m_aggregationCanSend = false; m_sourceWasConnected = false;
        m_lastSourceSnapshotId.clear(); m_sourceSubmissionError.clear(); m_sourceSubmissionCount = 0;
        if (m_dataSources) m_dataSources->setSharingConfiguration({});
        if (!alive || generation != m_aggregationGeneration) return;
        m_aggregationError.clear();
        m_aggregationStartupFailed = false;
        emit aggregationChanged();
        if (!alive || generation != m_aggregationGeneration) return;
        emit teamIdentityChanged();
        if (!alive || generation != m_aggregationGeneration) return;
    } else
        return;
    if (alive)
        emit serviceStatusChanged();
}

bool ServiceHub::bridgeBoundaryAllowed() const {
    return !m_seasonConfiguration ||
        (m_seasonConfiguration->environment() == "training" &&
         speechFlag(m_seasonConfiguration->context().value("configuration_valid"), true));
}
QString ServiceHub::sanitizeBridge(const QString &value) const {
    // Include one full token beyond the public cut so truncation cannot expose
    // a credential prefix that straddles the visible boundary.
    auto result = value.left(512 + m_bridgeToken.size());
    if (!m_bridgeToken.isEmpty()) result.replace(m_bridgeToken, "<bridge-token>");
    return result.left(512);
}
QString ServiceHub::bridgeStatus() const {
    if (!m_bridgeError.isEmpty()) return sanitizeBridge(m_bridgeError);
    QPointer<const ServiceHub> alive(this); QPointer<ServiceEndpoint> endpoint(m_bridge.get());
    const auto generation = m_bridgeGeneration;
    const auto status = endpoint ? endpoint->status() : QStringLiteral("未启用");
    return alive && generation == m_bridgeGeneration ? sanitizeBridge(status) : QString{};
}
QVariantMap ServiceHub::bridgeDetails() const {
    QPointer<const ServiceHub> alive(this); QPointer<ServiceEndpoint> endpoint(m_bridge.get());
    const auto generation = m_bridgeGeneration;
    const auto reported = endpoint ? endpoint->details() : optionalFailureDetails(m_bridgeError, m_bridgeStartupFailed);
    if (!alive || generation != m_bridgeGeneration || (endpoint && m_bridge.get() != endpoint.data())) return {};
    int freshPeers = 0;
    for (const auto &peer : m_peers) if (speechFlag(peer.toMap().value("arrival_fresh"), true)) ++freshPeers;
    QVariantMap result{{"active", bool(endpoint) && speechFlag(reported.value("active"), true)},
        {"export_snapshots", m_bridgeExportSnapshots}, {"export_events", m_bridgeExportEvents},
        {"peer_count", m_peers.size()}, {"source_sequence_count", m_bridgeSequences.size()},
        {"arrival_fresh_peers", freshPeers}, {"arrival_stale_peers", m_peers.size() - freshPeers},
        {"last_received_at_ms", m_bridgeLastReceivedUtc ? QVariant(m_bridgeLastReceivedUtc) : QVariant{}},
        {"last_received_age_ms", m_bridgeLastReceivedTick >= 0 ? QVariant(qMax<qint64>(0, m_clock.elapsed() - m_bridgeLastReceivedTick)) : QVariant{}},
        {"maximum_peers", 16}, {"maximum_sequence_sources", 64}, {"maximum_frame_bytes", 65536},
        {"received_frames", qulonglong(m_bridgeReceived)}, {"rejected_frames", qulonglong(m_bridgeRejected)},
        {"freshness_basis", "local_arrival_only"}, {"source_time_verified", false},
        {"peer_authenticated", false}, {"source_identity_verified", false}, {"authoritative", false},
        {"ai_input_ready", false}, {"automatic_actions_allowed", false}, {"classification", "laboratory_unverified"}};
    for (const auto &key : {"listen_port", "connections", "dropped", "pending_input_bytes", "pending_output_bytes", "pending_reads",
                           "drain_batches", "drain_yields", "maximum_batch_messages", "connected", "state", "startup_failed", "health", "error"}) {
        const auto value = reported.value(QLatin1String(key));
        if (value.metaType().id() == QMetaType::Bool || bridgeInteger(value, 0, 9007199254740991.0)) result[QLatin1String(key)] = value;
        else if (value.metaType().id() == QMetaType::QString) result[QLatin1String(key)] = sanitizeBridge(value.toString());
    }
    return result;
}
bool ServiceHub::startBridge(std::unique_ptr<ServiceEndpoint> bridge,
                             const QVariantMap &configuration, QString *error, QObject *owner,
                             bool exportSnapshots, bool exportEvents) {
    if (error) error->clear();
    if (!bridge) {
        if (error)
            *error = "Bridge plugin returned an empty endpoint";
        return false;
    }
    if (QThread::currentThread() != thread() || bridge->thread() != thread() || bridge->parent() ||
        (owner && owner->thread() != thread())) {
        if (error) *error = "Bridge endpoint must be a new unparented UI-thread transfer with a UI-thread owner";
        auto *rejected = bridge.release();
        if (!rejected->parent()) {
            if (rejected->thread() != QThread::currentThread()) rejected->deleteLater(); else delete rejected;
        }
        return false;
    }
    const auto blocked = optionalServiceBlockReason("bridge", {});
    if (!blocked.isEmpty() || !bridgeBoundaryAllowed() ||
        (owner && m_seasonConfiguration && !m_seasonConfiguration->editable())) {
        if (error) *error = blocked.isEmpty() ? QStringLiteral("实验室桥接仅可在训练／准备范围启用") : blocked;
        return false;
    }
    if (configuration.contains("token") && !bridgeText(configuration.value("token"), 256, true)) {
        if (error) *error = "Bridge credential must be bounded text";
        return false;
    }
    QPointer<ServiceHub> lifetime(this);
    QPointer<QObject> ownerGuard(owner); QPointer<ServiceEndpoint> candidate(bridge.release());
    auto dispose = qScopeGuard([candidate] { if (candidate) { candidate->stop(); if (candidate) delete candidate.data(); } });
    const auto preparing = m_bridgeGeneration;
    const auto current = [this, lifetime, owner, ownerGuard, preparing] {
        return lifetime && (!owner || ownerGuard) && preparing == m_bridgeGeneration;
    };
    const auto token = configuration.value("token").metaType().id() == QMetaType::QString ? configuration.value("token").toString() : QString{};
    const auto hideError = qScopeGuard([error, token] {
        if (error && !token.isEmpty()) error->replace(token, "<bridge-token>");
    });
    const auto quiet = candidate->details();
    if (!current() || !candidate) return false;
    if (!speechFlag(quiet.value("active"), false) || !speechLeaseActive(quiet) ||
        (quiet.contains("busy") && !speechFlag(quiet.value("busy"), false))) {
        if (error) *error = "Bridge factory must return a quiet inactive endpoint with a current lease";
        return false;
    }
    const auto startupMessage = std::make_shared<bool>(false);
    const auto startupConnection = connect(candidate, &ServiceEndpoint::messageReceived, this, [startupMessage] { *startupMessage = true; });
    const auto disconnectStartup = qScopeGuard([startupConnection] { QObject::disconnect(startupConnection); });
    const bool started = candidate->start(configuration, error);
    if (!current() || !candidate) return false;
    const auto capabilities = candidate->details();
    if (!current() || !candidate) return false;
    if (!started || !speechFlag(capabilities.value("active"), true) || !speechLeaseActive(capabilities) || *startupMessage) {
        if (error && error->isEmpty()) *error = "Bridge did not start quietly with an active current lease";
        return false;
    }
    const auto generation = m_bridgeGeneration + 1;
    disableOptionalService("bridge");
    if (!lifetime || (owner && !ownerGuard) || generation != m_bridgeGeneration || !candidate) return false;
    const auto committing = candidate->details();
    if (!lifetime || (owner && !ownerGuard) || generation != m_bridgeGeneration || !candidate || !bridgeBoundaryAllowed() ||
        !speechFlag(committing.value("active"), true) || !speechLeaseActive(committing) || *startupMessage) return false;
    QObject::disconnect(startupConnection);
    m_bridge.reset(candidate.data()); dispose.dismiss();
    m_bridgeOwner = ownerGuard; m_bridgeToken = token;
    m_bridgeExportSnapshots = exportSnapshots; m_bridgeExportEvents = exportEvents;
    m_bridgeError.clear();
    m_bridgeStartupFailed = false;
    auto *endpoint = m_bridge.get();
    connect(endpoint, &QObject::destroyed, this, [this, generation, endpoint] {
        if (generation != m_bridgeGeneration || m_bridge.get() != endpoint) return;
        m_bridge.release(); disableOptionalService("bridge");
    });
    if (owner) m_bridgeOwnerConnection = connect(owner, &QObject::destroyed, this, [this, generation] {
        if (generation == m_bridgeGeneration) disableOptionalService("bridge");
    });
    connect(endpoint, &ServiceEndpoint::statusChanged, this, [this, generation] {
        if (generation != m_bridgeGeneration || !m_bridge) return;
        QPointer<ServiceHub> alive(this); QPointer<ServiceEndpoint> endpoint(m_bridge.get());
        const auto details = endpoint->details();
        if (!alive || !endpoint || generation != m_bridgeGeneration) return;
        if (!speechLeaseActive(details) || !speechFlag(details.value("active"), true) || !bridgeBoundaryAllowed()) {
            disableOptionalService("bridge"); return;
        }
        emit serviceStatusChanged();
    });
    connect(endpoint, &ServiceEndpoint::messageReceived, this, [this, generation](const QVariantMap &message) {
        if (generation == m_bridgeGeneration && m_bridge) receive(message);
    });
    emit serviceStatusChanged();
    if (!lifetime || generation != m_bridgeGeneration || (owner && !ownsBridge(owner))) return false;
    if (m_bridgeExportSnapshots) publishSnapshot();
    return lifetime && generation == m_bridgeGeneration && m_bridge && (!owner || ownsBridge(owner));
}
bool ServiceHub::ownsBridge(const QObject *owner) const { return owner && m_bridge && m_bridgeOwner.data() == owner; }
bool ServiceHub::releaseBridge(const QObject *owner) {
    if (!ownsBridge(owner)) return false;
    disableOptionalService("bridge"); return true;
}
QVariantMap ServiceHub::snapshot() const {
    if (!m_backend || !m_state)
        return {};
    QVariantMap groups;
    auto *state = m_state.data();
#define RM_TELEMETRY_GROUP(name, type) groups[QStringLiteral(#name)] = jsonValue(state->name());
#include "TelemetryGroups.def"
#undef RM_TELEMETRY_GROUP
    QVariantMap result{{"client_id", m_backend->clientId()},
                       {"connected", m_backend->connected()},
                       {"groups", groups},
                       {"freshness", state->freshness()},
                       {"robots", jsonValue(state->robotData())}};
    if (m_seasonConfiguration) result["rules_context"] = m_seasonConfiguration->context();
    const auto fields = state->group("fieldFreshness");
    if (!fields.isEmpty())
        result["field_freshness"] = fields;
    return result;
}
QVariantMap ServiceHub::message(const QString &kind, const QVariantMap &payload) {
    return {{"schema", 1},
            {"kind", kind},
            {"source", m_source},
            {"seq", qulonglong(++m_sequence)},
            {"sent_at_ms", QDateTime::currentMSecsSinceEpoch()},
            {"robot_id", m_backend ? m_backend->clientId() : 0},
            {"payload", payload}};
}
void ServiceHub::publishSnapshot() {
    if (!m_backend || !m_bridge || !m_bridgeExportSnapshots || !bridgeBoundaryAllowed())
        return;
    QPointer<ServiceHub> lifetime(this);
    const auto generation = m_bridgeGeneration;
    QPointer<ServiceEndpoint> endpoint(m_bridge.get());
    QString error;
    const auto frame = message("snapshot", snapshot());
    if (!lifetime || !endpoint || generation != m_bridgeGeneration) return;
    const bool accepted = endpoint->submit(frame, &error);
    if (!lifetime || generation != m_bridgeGeneration)
        return;
    const QString statusError = accepted ? QString{} : sanitizeBridge(error);
    m_dirty = false;
    m_lastPublished = m_clock.elapsed();
    if (m_bridgeError != statusError) {
        m_bridgeError = statusError;
        emit serviceStatusChanged();
    }
}
void ServiceHub::receive(const QVariantMap &received) {
    if (!m_bridge || !bridgeBoundaryAllowed()) return;
    int nodes = 0; qsizetype cost = 0;
    static const QSet<QString> keys{"schema", "kind", "source", "seq", "sent_at_ms", "robot_id", "payload"};
    bool valid = received.size() == keys.size();
    for (auto it = received.cbegin(); valid && it != received.cend(); ++it) valid = keys.contains(it.key());
    valid = valid && bridgeInteger(received.value("schema"), 1, 1) && bridgeText(received.value("source"), 96) &&
        received.value("kind").metaType().id() == QMetaType::QString && (received.value("kind") == "snapshot" || received.value("kind") == "event") &&
        bridgeInteger(received.value("seq"), 1, 9007199254740991.0) && bridgeInteger(received.value("sent_at_ms"), 1, 9007199254740991.0) &&
        bridgeInteger(received.value("robot_id"), 0, 65535) && received.value("payload").metaType().id() == QMetaType::QVariantMap &&
        bridgeJson(received, 0, &nodes, &cost) && QJsonDocument::fromVariant(received).toJson(QJsonDocument::Compact).size() + 1 <= 65536;
    if (!valid) { ++m_bridgeRejected; m_bridgeDiagnosticsDirty = true; return; }
    const auto source = received.value("source").toString();
    if (source == m_source)
        return;
    const auto sequence = received.value("seq").toULongLong();
    if ((m_bridgeSequences.contains(source) && sequence <= m_bridgeSequences.value(source)) ||
        (!m_bridgeSequences.contains(source) && m_bridgeSequences.size() >= 64)) { ++m_bridgeRejected; m_bridgeDiagnosticsDirty = true; return; }
    m_bridgeSequences[source] = sequence; ++m_bridgeReceived;
    const auto publicSource = sanitizeBridge(source);
    auto payload = redactBridgeValue(received.value("payload"), m_bridgeToken).toMap();
    const auto receivedUtc = QDateTime::currentMSecsSinceEpoch();
    m_bridgeLastReceivedUtc = receivedUtc; m_bridgeLastReceivedTick = m_clock.elapsed(); m_bridgeDiagnosticsDirty = true;
    if (received.value("kind") == "event") {
        // 远端状态与官方事件状态分开，不能调用机器人指令。
        payload["_bridge"] = QVariantMap{{"received_at_ms", receivedUtc}, {"source_sent_at_ms", received.value("sent_at_ms")},
            {"source_time_verified", false}, {"peer_authenticated", false}, {"authoritative", false}, {"ai_input_ready", false},
            {"freshness_basis", "local_arrival_only"}};
        emit peerEventReceived(publicSource, payload);
        return;
    }
    if (received.value("kind") != "snapshot")
        return;
    if (!m_peerSeen.contains(publicSource)) {
        if (m_peerOrder.size() >= 16) {
            const auto oldest = m_peerOrder.takeFirst();
            m_peerSeen.remove(oldest);
            m_peers.remove(oldest);
        }
        m_peerOrder.append(publicSource);
    }
    m_peerSeen[publicSource] = m_clock.elapsed();
    m_peers[publicSource] = QVariantMap{{"source", publicSource},
                                  {"robot_id", received.value("robot_id")},
                                  {"received_at_ms", receivedUtc},
                                  {"sent_at_ms", received.value("sent_at_ms")},
                                  {"fresh", true},
                                  {"arrival_fresh", true}, {"freshness_basis", "local_arrival_only"},
                                  {"source_time_verified", false}, {"source_freshness", "unverified"},
                                  {"peer_authenticated", false}, {"source_identity_verified", false}, {"authoritative", false}, {"ai_input_ready", false},
                                  {"payload", payload}};
    m_peersDirty = true;
}
bool ServiceHub::startDecision(std::unique_ptr<ServiceEndpoint> decision,
                               const QVariantMap &configuration, QString *error) {
    const auto blocked = optionalServiceBlockReason("decision", {});
    if (!blocked.isEmpty()) { if (error) *error = blocked; return false; }
    if (!decision) {
        if (error)
            *error = "Decision plugin returned an empty endpoint";
        return false;
    }
    QPointer<ServiceHub> lifetime(this);
    const auto preparingGeneration = m_decisionGeneration;
    if (!decision->start(configuration, error))
        return false;
    if (!lifetime || preparingGeneration != m_decisionGeneration)
        return false;
    const auto generation = m_decisionGeneration + 1;
    cancelDecisionRequest();
    if (!lifetime || generation != m_decisionGeneration)
        return false;
    auto previous = std::move(m_decision);
    if (previous)
        previous->disconnect(this);
    m_decision = std::move(decision);
    m_decisionError.clear();
    m_decisionStartupFailed = false;
    previous.reset();
    if (!lifetime || generation != m_decisionGeneration)
        return false;
    connect(m_decision.get(), &ServiceEndpoint::statusChanged, this,
            &ServiceHub::serviceStatusChanged);
    connect(m_decision.get(), &ServiceEndpoint::messageReceived, this,
            &ServiceHub::receiveDecision);
    m_advice.clear();
    m_decisionInput.clear();
    emit adviceChanged();
    if (!lifetime || generation != m_decisionGeneration)
        return false;
    emit decisionInputChanged();
    if (!lifetime || generation != m_decisionGeneration)
        return false;
    emit serviceStatusChanged();
    return true;
}
bool ServiceHub::decisionAvailable() const {
    QString reason;
    return m_decision && m_decisionRequestId.isEmpty() &&
           m_decision->details().value("active").toBool() &&
           !m_decision->details().value("busy").toBool() &&
           !prepareDecisionInput(&reason).isEmpty();
}
void ServiceHub::setDecisionConfiguration(DecisionConfiguration *configuration) {
    if (m_decisionConfiguration)
        m_decisionConfiguration->disconnect(this);
    m_decisionConfiguration = configuration;
    if (m_dataSources) m_dataSources->setDecisionConfiguration(configuration);
    if (configuration)
        connect(configuration, &DecisionConfiguration::currentChanged, this,
                &ServiceHub::invalidateDecisionPolicy);
    invalidateDecisionPolicy();
}
QObject *ServiceHub::decisionConfiguration() const {
    return m_decisionConfiguration.data();
}
QVariantMap ServiceHub::decisionCapabilities() const {
    return {{"local_input", true},
            {"team_input", false},
            {"automatic", true},
            {"team_voice", false},
            {"source_adapters", false},
            {"source_registry", bool(m_dataSources)},
            {"official_source_snapshots", bool(m_dataSources)}};
}
QVariantMap ServiceHub::decisionTrace() const {
    auto trace = m_decisionTrace;
    if (trace.isEmpty())
        return trace;
    trace["snapshot_age_ms"] = qMax<qint64>(0, m_clock.elapsed() - m_decisionStarted);
    trace["received_age_ms"] =
        m_advice.isEmpty() ? QVariant{}
                           : QVariant(qMax<qint64>(0, m_clock.elapsed() - m_adviceReceived));
    trace["remaining_ms"] = qMax<qint64>(
        0, (m_advice.isEmpty() ? m_inputExpires : qMin(m_inputExpires, m_adviceExpires)) -
               m_clock.elapsed());
    trace["input_revision_current"] = decisionEvidenceFresh();
    trace["export_cryptographically_authenticated"] = false;
    return trace;
}
void ServiceHub::invalidateDecisionPolicy() {
    QPointer<ServiceHub> alive(this);
    cancelDecisionRequest();
    if (!alive)
        return;
    cancelInputSpeech();
    if (!alive)
        return;
    cancelAdviceSpeech();
    if (!alive)
        return;
    m_advice.clear();
    m_decisionInput.clear();
    m_decisionTrace.clear();
    m_inputExpires = 0;
    m_lastAutomaticEvidence.clear();
    m_autoSuspended = false;
    emit adviceChanged();
    if (!alive)
        return;
    emit decisionInputChanged();
    if (!alive)
        return;
    emit decisionPolicyStatusChanged();
}
QVariantMap ServiceHub::prepareDecisionInput(QString *reason) const {
    auto unavailable = [reason](const QString &message) {
        if (reason)
            *reason = message;
        return QVariantMap{};
    };
    if (!m_decisionConfiguration || !m_decision)
        return unavailable("模型或已保存策略未接通");
    if (m_seasonConfiguration) {
        const auto blocked = m_seasonConfiguration->inferenceBlockReason(m_decision->details());
        if (!blocked.isEmpty()) return unavailable(blocked);
    }
    if (!m_backend || !m_state || !m_backend->connected() ||
        !RobotIdentity::valid(m_backend->clientId()))
        return unavailable("官方选手端连接或本机身份不可用");
    const auto policy = m_decisionConfiguration->current();
    if (!policy.value("playerSourceConfirmed").toBool())
        return unavailable("先在赛外核对并确认当前官方选手端导出来源");
    const auto fixed = m_state->robotStatic();
    const auto states = m_state->group("fieldFreshness");
    const auto id = fixed.value("robot_id");
    if (states.value("robotStatic").toMap().value("robot_id") != "fresh" ||
        id.metaType().id() == QMetaType::Bool || id.metaType().id() == QMetaType::QString ||
        id.toDouble() != m_backend->clientId())
        return unavailable("本机遥测身份缺失、旧或与当前机器人不符");
    const auto details = m_decision->details();
    const auto model = policy.value("modelId").toString();
    if (model.isEmpty() || details.value("model") != model)
        return unavailable("所选策略模型与活动提供者不一致，请在赛外保存配置");
    if (policy.value("inputMode") == "team" && policy.value("teamFallback") != "local")
        return unavailable("可信队伍整合插件未接通；本机功能继续，队伍建议暂停");
    // Loopback and a local CLI process can still proxy external inference.
    const bool local = details.value("inference_location") == "local" &&
                       details.value("fully_local_verified").toBool();
    const auto categories =
        policy.value(local ? "localAiFields" : "externalAiFields").toStringList();
    if (categories.isEmpty())
        return unavailable(local ? "未授权本地AI输入类别"
                                 : "未授权外部AI输入类别；未知推理地点也按外部处理");
    const auto captured = m_clock.elapsed();
    auto input = snapshot();
    input["field_observations"] = m_state->group("fieldObservations");
    auto result = DecisionContext::permitted(input, categories);
    if (result.value("groups").toMap().isEmpty())
        return unavailable("已授权类别没有可核对的新鲜字段；数据源草稿不作为真实输入");
    const auto identityObservation = input.value("field_observations")
                                         .toMap()
                                         .value("robotStatic")
                                         .toMap()
                                         .value("robot_id")
                                         .toMap();
    const auto identityBudget = DecisionContext::remainingLifetime(identityObservation);
    if (identityBudget <= 0)
        return unavailable("状态插件尚未提供本机身份的接收时效证据");
    result["valid_for_ms"] = qMin(result.value("valid_for_ms").toLongLong(), identityBudget);
    result["_capture_tick_ms"] = captured;
    result["captured_at_ms"] = QDateTime::currentMSecsSinceEpoch();
    result["source_node_id"] = m_source;
    result["source_verification"] = "operator_confirmation";
    if (m_seasonConfiguration) result["rules_context"] = m_seasonConfiguration->context();
    result["inference_purpose"] = local ? "localAi" : "externalAi";
    result["input_mode"] = "local";
    result["requested_input_mode"] = policy.value("inputMode");
    if (policy.value("inputMode") == "team")
        result["degradation_reason"] = "可信队伍汇总未接通；按已保存偏好明确降级本机";
    const QMap<QString, QString> team{{"balanced", "优先存活与任务完成，避免无依据冒进。"},
                                      {"resource", "关注弹量、热量、经济与补给，再判断交战时机。"},
                                      {"objective", "围绕队伍目标提供支援、压制与任务协同建议。"}};
    const QMap<QString, QString> role{
        {"assist", "按本机器人能力支援队友，优先规避失控与失效数据。"},
        {"task", "优先本角色的装配、机关、支援、部署或侦察任务。"},
        {"pressure", "资源与证据充分时提示压制机会，动作仍由操作手确认。"}};
    result["operator_policy"] =
        QVariantMap{{"team_strategy", policy.value("teamStrategy")},
                    {"role_strategy", policy.value("roleStrategy")},
                    {"team_intent", team.value(policy.value("teamStrategy").toString())},
                    {"role_intent", role.value(policy.value("roleStrategy").toString())},
                    {"revision", qulonglong(m_decisionConfiguration->revision())},
                    {"automatic_actions_allowed", false}};
    return result;
}
void ServiceHub::setAutomaticStatus(const QString &status) {
    if (status == m_automaticStatus)
        return;
    m_automaticStatus = status;
    emit decisionPolicyStatusChanged();
}
void ServiceHub::scheduleDecision() {
    if (!m_decisionConfiguration ||
        !m_decisionConfiguration->current().value("autoAdvice").toBool()) {
        setAutomaticStatus("自动建议未启用");
        return;
    }
    if (m_autoSuspended) {
        setAutomaticStatus("已手动暂停自动建议；赛外重新保存策略后恢复");
        return;
    }
    if (!m_backend || !m_backend->connected() || !m_state) {
        setAutomaticStatus("选手端失联；自动建议等待恢复");
        return;
    }
    const auto stage = m_state->gameStatus().value("current_stage");
    if (m_state->group("fieldFreshness").value("gameStatus").toMap().value("current_stage") !=
            "fresh" ||
        stage.metaType().id() == QMetaType::Bool || stage.metaType().id() == QMetaType::QString ||
        stage.toDouble() != 4) {
        setAutomaticStatus("自动建议等待新鲜比赛阶段；赛外可手动分析");
        return;
    }
    if (m_state->group("fieldFreshness").value("gameStatus").toMap().value("is_paused") ==
            "fresh" &&
        m_state->gameStatus().value("is_paused").metaType().id() == QMetaType::Bool &&
        m_state->gameStatus().value("is_paused").toBool()) {
        setAutomaticStatus("比赛暂停；自动请求暂停，本地设置仍可修改");
        return;
    }
    if (!m_decision || !m_decision->details().value("active").toBool()) {
        setAutomaticStatus("模型提供者未就绪");
        return;
    }
    if (!m_decisionRequestId.isEmpty() || m_decision->details().value("busy").toBool()) {
        setAutomaticStatus("模型分析中；后续变化合并为最新快照");
        return;
    }
    QString reason;
    const auto input = prepareDecisionInput(&reason);
    if (input.isEmpty()) {
        setAutomaticStatus(reason);
        return;
    }
    const auto evidence = input.value("groups").toMap();
    if (m_decisionConfiguration->current().value("trigger") == "event" &&
        evidence == m_lastAutomaticEvidence) {
        setAutomaticStatus("等待已授权字段变化；不重复请求旧事件");
        return;
    }
    if (m_clock.elapsed() - m_lastDecisionRequest < m_decisionMinimumInterval) {
        setAutomaticStatus("按已保存间隔合并请求");
        return;
    }
    QPointer<ServiceHub> alive(this);
    const bool accepted = submitDecision({}, true);
    if (!alive)
        return;
    if (accepted)
        m_lastAutomaticEvidence = evidence;
    setAutomaticStatus(accepted ? QStringLiteral("已提交最新自动建议请求") : m_decisionError);
}
bool ServiceHub::decisionEvidenceFresh() const {
    if (!m_backend || !m_state || !m_backend->connected() || !m_decisionConfiguration ||
        m_requestPolicyRevision != m_decisionConfiguration->revision() ||
        m_clock.elapsed() >= m_inputExpires)
        return false;
    const auto identityStates = m_state->group("fieldFreshness").value("robotStatic").toMap();
    if (identityStates.value("robot_id") != "fresh" ||
        m_state->robotStatic().value("robot_id").toInt() != m_backend->clientId())
        return false;
    const auto groups = m_decisionInput.value("groups").toMap();
    const auto freshness = m_state->freshness();
    const auto fieldFreshness = m_state->group("fieldFreshness");
    for (auto group = groups.cbegin(); group != groups.cend(); ++group) {
        if (freshness.value(group.key()) != "fresh")
            return false;
        if (!fieldFreshness.contains(group.key()))
            return false;
        const auto fields = group.value().toMap(),
                   states = fieldFreshness.value(group.key()).toMap(),
                   live = m_state->group(group.key());
        for (auto field = fields.cbegin(); field != fields.cend(); ++field)
            if (states.value(field.key()) != "fresh" || live.value(field.key()) != field.value())
                return false;
    }
    return true;
}
bool ServiceHub::decisionInputFresh() const {
    return m_backend && m_backend->connected() &&
           !m_decisionInput.value("groups").toMap().isEmpty() && decisionEvidenceFresh();
}
void ServiceHub::cancelInputSpeech() {
    if (!m_inputSpeechOutstanding)
        return;
    m_inputSpeechOutstanding = false;
    if (m_speech) {
        QString error;
        m_speech->submit({{"schema", 1}, {"kind", "cancel"}, {"key", "input-facts"}}, &error);
    }
}
void ServiceHub::cancelAdviceSpeech() {
    if (m_adviceSpeechKey.isEmpty())
        return;
    const auto key = std::exchange(m_adviceSpeechKey, QString{});
    if (m_speech) {
        QString error;
        m_speech->submit({{"schema", 1}, {"kind", "cancel"}, {"key", key}}, &error);
    }
}
void ServiceHub::refreshInputValidity() {
    const bool fresh = decisionInputFresh();
    if (fresh == m_inputWasFresh)
        return;
    m_inputWasFresh = fresh;
    QPointer<ServiceHub> lifetime(this);
    if (!fresh) {
        cancelInputSpeech();
        if (!lifetime)
            return;
        cancelAdviceSpeech();
    }
    if (lifetime)
        emit decisionInputValidityChanged();
}
bool ServiceHub::requestDecision(const QString &question) {
    if (!m_decisionConfiguration || !m_decisionConfiguration->editable()) {
        m_decisionError = "手动分析仅在赛外进行；比赛中使用已保存的自动建议策略";
        emit serviceStatusChanged();
        return false;
    }
    return submitDecision(question, false);
}
bool ServiceHub::submitDecision(const QString &question, bool automatic) {
    if (question.size() > 500) {
        m_decisionError = "关注点超过500字符";
        emit serviceStatusChanged();
        return false;
    }
    if (m_clock.elapsed() - m_lastDecisionRequest < m_decisionMinimumInterval) {
        m_decisionError = "模型请求已节流，请稍后重试";
        emit serviceStatusChanged();
        return false;
    }
    QString reason;
    const auto captured = prepareDecisionInput(&reason);
    if (!m_decision || !m_decision->details().value("active").toBool() ||
        !m_decisionRequestId.isEmpty() || m_decision->details().value("busy").toBool() ||
        captured.isEmpty()) {
        m_decisionError = reason.isEmpty() ? QStringLiteral("模型未启用或已有在途请求") : reason;
        emit serviceStatusChanged();
        return false;
    }
    QPointer<ServiceHub> lifetime(this);
    const auto generation = ++m_decisionGeneration;
    cancelInputSpeech();
    if (!lifetime || generation != m_decisionGeneration)
        return false;
    cancelAdviceSpeech();
    if (!lifetime || generation != m_decisionGeneration)
        return false;
    m_decisionRequestId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_decisionStarted = captured.value("_capture_tick_ms").toLongLong();
    m_lastDecisionRequest = m_decisionStarted;
    m_decisionError.clear();
    m_advice.clear();
    m_decisionInput = captured;
    m_decisionInput.remove("_capture_tick_ms");
    m_inputExpires = m_decisionStarted + captured.value("valid_for_ms").toLongLong();
    m_requestPolicyRevision = m_decisionConfiguration->revision();
    const auto policy = m_decisionConfiguration->current();
    const auto snapshotId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_decisionInput["snapshot_id"] = snapshotId;
    m_decisionTrace = {{"request_id", m_decisionRequestId},
                       {"snapshot_id", snapshotId},
                       {"sender_id", m_source},
                       {"sender_label", QStringLiteral("本机机器人%1").arg(m_backend->clientId())},
                       {"sender_verified", true},
                       {"sources_verified", true},
                       {"player_export_verified", policy.value("playerSourceConfirmed")},
                       {"source_verification", "operator_confirmation"},
                       {"source_trust", "operator_confirmed_endpoint"},
                       {"producer_timestamp_verified", false},
                       {"requires_player_client", true},
                       {"input_mode", captured.value("input_mode")},
                       {"degradation_reason", captured.value("degradation_reason")},
                       {"policy_revision", qulonglong(m_requestPolicyRevision)},
                       {"origin", "configured_player_endpoint"},
                       {"automatic", automatic},
                       {"requested_model", m_decision->details().value("model")}};
    emit adviceChanged();
    if (!lifetime || generation != m_decisionGeneration)
        return false;
    emit decisionInputChanged();
    if (!lifetime || generation != m_decisionGeneration)
        return false;
    QString error;
    const bool accepted = m_decision->submit({{"schema", 1},
                                              {"kind", "decision-request"},
                                              {"request_id", m_decisionRequestId},
                                              {"payload", m_decisionInput},
                                              {"question", question}},
                                             &error);
    if (!lifetime || generation != m_decisionGeneration)
        return false;
    if (!accepted) {
        m_decisionRequestId.clear();
        m_decisionError = error;
    }
    emit serviceStatusChanged();
    return accepted;
}
void ServiceHub::cancelDecision() {
    QPointer<ServiceHub> alive(this);
    m_autoSuspended = true;
    setAutomaticStatus("已手动暂停自动建议；赛外重新保存策略后恢复");
    if (alive)
        cancelDecisionRequest();
}
void ServiceHub::cancelDecisionRequest() {
    QPointer<ServiceHub> lifetime(this);
    const auto generation = ++m_decisionGeneration;
    const bool pending = !m_decisionRequestId.isEmpty();
    m_decisionRequestId.clear();
    m_decisionError.clear();
    if (m_decision && (pending || m_decision->details().value("busy").toBool())) {
        QString error;
        m_decision->submit({{"schema", 1}, {"kind", "cancel"}}, &error);
        if (!lifetime || generation != m_decisionGeneration)
            return;
    }
    emit serviceStatusChanged();
}
void ServiceHub::receiveDecision(const QVariantMap &message) {
    if (m_decisionRequestId.isEmpty() || message.value("request_id") != m_decisionRequestId)
        return;
    if (message.value("kind") != "decision-error" && message.value("kind") != "advice")
        return;
    QPointer<ServiceHub> lifetime(this);
    const auto generation = m_decisionGeneration;
    m_decisionRequestId.clear();
    if (message.value("kind") == "decision-error") {
        m_decisionError = message.value("error").toString();
        emit serviceStatusChanged();
        return;
    }
    if (message.value("kind") != "advice")
        return;
    const auto age = m_clock.elapsed() - m_decisionStarted;
    if (!m_backend || !m_state || !m_backend->connected() || !decisionEvidenceFresh() ||
        age > 10000) {
        m_decisionError = "输入遥测已失效，建议已丢弃";
        emit serviceStatusChanged();
        return;
    }
    m_advice = message.value("payload").toMap();
    // 可替换适配器的结果也要校验；即使新插件未检查有效期，
    // 错误的 TTL 也不能让建议无限保留。
    if (!AdviceContract::validate(QJsonObject::fromVariantMap(m_advice))) {
        m_advice.clear();
        m_decisionError = "模型插件返回了无效建议";
        emit adviceChanged();
        if (lifetime && generation == m_decisionGeneration)
            emit serviceStatusChanged();
        return;
    }
    const int ttl = m_advice.value("expires_in_ms").toInt();
    m_advice["fresh"] = true;
    m_advice["based_on_age_ms"] = age;
    m_adviceReceived = m_clock.elapsed();
    m_adviceExpires = qMin(m_clock.elapsed() + ttl, m_inputExpires);
    emit adviceChanged();
    if (lifetime && generation == m_decisionGeneration)
        emit serviceStatusChanged();
}
bool ServiceHub::startSpeech(std::unique_ptr<ServiceEndpoint> speech,
                             const QVariantMap &configuration, QString *error,
                             const QString &verifiedPluginId, QObject *owner) {
    if (error) error->clear();
    if (!speech) {
        if (error)
            *error = "Speech plugin returned an empty endpoint";
        return false;
    }
    if (QThread::currentThread() != thread() || speech->thread() != thread() || speech->parent() ||
        (owner && owner->thread() != thread())) {
        if (error) *error = "Speech endpoint must be unparented; endpoint and native owner must use the current UI thread";
        // A parented endpoint was not an ownership transfer; leave its existing
        // owner intact rather than deleting someone else's QObject.
        auto *rejected = speech.release();
        if (!rejected->parent()) {
            if (rejected->thread() != QThread::currentThread()) rejected->deleteLater();
            else delete rejected;
        }
        return false;
    }
    const auto blocked = optionalServiceBlockReason("speech", verifiedPluginId);
    if (!blocked.isEmpty()) { if (error) *error = blocked; return false; }
    QPointer<ServiceHub> lifetime(this);
    QPointer<QObject> ownerGuard(owner);
    QPointer<ServiceEndpoint> candidate(speech.release());
    auto dispose = qScopeGuard([candidate] {
        if (!candidate) return;
        candidate->stop();
        if (candidate) delete candidate.data();
    });
    const auto preparingGeneration = m_speechGeneration;
    const auto current = [this, lifetime, ownerGuard, owner, preparingGeneration] {
        return lifetime && (!owner || ownerGuard) && preparingGeneration == m_speechGeneration;
    };
    const auto quiet = candidate->details();
    if (!current() || !candidate) return false;
    if (!speechFlag(quiet.value("active"), false) || !speechLeaseActive(quiet) ||
        (quiet.contains("busy") && !speechFlag(quiet.value("busy"), false)) ||
        (quiet.contains("queued") && QJsonValue::fromVariant(quiet.value("queued")).toDouble(-1) != 0)) {
        if (error) *error = "Speech factory must return a quiet inactive endpoint with a current package lease";
        return false;
    }
    const bool started = candidate->start(configuration, error);
    if (!current() || !candidate) return false;
    const auto capabilities = candidate->details();
    if (!current() || !candidate) return false;
    if (!started || !speechFlag(capabilities.value("active"), true) || !speechLeaseActive(capabilities) ||
        (capabilities.contains("busy") && !speechFlag(capabilities.value("busy"), false)) ||
        (capabilities.contains("queued") && QJsonValue::fromVariant(capabilities.value("queued")).toDouble(-1) != 0)) {
        if (error && error->isEmpty()) *error = "Speech did not start quietly with an active current lease";
        return false;
    }
    const auto stillAllowed = optionalServiceBlockReason("speech", verifiedPluginId);
    if (!stillAllowed.isEmpty()) { if (error) *error = stillAllowed; return false; }
    const auto generation = m_speechGeneration + 1;
    disableOptionalService("speech");
    if (!lifetime || (owner && !ownerGuard) || generation != m_speechGeneration || !candidate) return false;
    const auto committing = candidate->details();
    if (!lifetime || (owner && !ownerGuard) || generation != m_speechGeneration || !candidate ||
        !speechFlag(committing.value("active"), true) || !speechLeaseActive(committing)) return false;
    // Disarm guarded local ownership only after all callback-bearing startup
    // checks. The hub is the sole owner from this point onward.
    m_speech.reset(candidate.data());
    dispose.dismiss();
    m_speechOwner = ownerGuard;
    m_speechError.clear();
    m_speechStartupFailed = false;
    auto *endpoint = m_speech.get();
    const auto endpointGeneration = ++m_speechEndpointGeneration;
    connect(endpoint, &QObject::destroyed, this, [this, endpointGeneration, endpoint] {
        if (endpointGeneration != m_speechEndpointGeneration || m_speech.get() != endpoint) return;
        m_speech.release(); // Provider self-destruction must not leave a dangling unique_ptr.
        ++m_speechGeneration; ++m_speechEndpointGeneration;
        disconnect(m_speechOwnerConnection); m_speechOwnerConnection = {}; m_speechOwner.clear();
        m_inputSpeechOutstanding = false; m_adviceSpeechKey.clear(); m_localAudioApplied = false;
        m_speechError = QStringLiteral("语音端点已销毁；未启用替代提供者");
        emit serviceStatusChanged();
    });
    if (owner) m_speechOwnerConnection = connect(owner, &QObject::destroyed, this, [this, endpointGeneration] {
        if (endpointGeneration == m_speechEndpointGeneration) disableOptionalService("speech");
    });
    connect(endpoint, &ServiceEndpoint::statusChanged, this, [this, endpointGeneration] {
        if (endpointGeneration != m_speechEndpointGeneration || !m_speech) return;
        QPointer<ServiceHub> alive(this); QPointer<ServiceEndpoint> endpoint(m_speech.get());
        const auto details = endpoint->details();
        if (!alive || !endpoint || endpointGeneration != m_speechEndpointGeneration) return;
        if (!speechLeaseActive(details) || !speechFlag(details.value("active"), true)) {
            disableOptionalService("speech");
            return;
        }
        emit serviceStatusChanged();
    });
    applyLocalAudio();
    if (!lifetime || generation != m_speechGeneration || !m_speech || (owner && !ownsSpeech(owner))) return false;
    emit serviceStatusChanged();
    return lifetime && generation == m_speechGeneration && bool(m_speech) && (!owner || ownsSpeech(owner));
}
bool ServiceHub::ownsSpeech(const QObject *owner) const {
    return owner && m_speech && m_speechOwner.data() == owner;
}
bool ServiceHub::releaseSpeech(const QObject *owner) {
    if (!ownsSpeech(owner)) return false;
    disableOptionalService("speech");
    return true;
}
void ServiceHub::setLocalAudioPreferences(int voice, int alert) {
    if (voice < 0 || voice > 100 || alert < 0 || alert > 100)
        return;
    m_voiceVolume = voice;
    m_alertVolume = alert;
    ++m_audioRevision;
    QPointer<ServiceHub> alive(this);
    applyLocalAudio();
    if (alive)
        emit serviceStatusChanged();
}
bool ServiceHub::applyLocalAudio() {
    m_localAudioApplied = false;
    if (!m_speech)
        return false;
    QPointer<ServiceHub> alive(this);
    QPointer<ServiceEndpoint> endpoint(m_speech.get());
    const auto revision = m_audioRevision, generation = m_speechGeneration;
    const auto details = endpoint->details();
    if (!alive || !endpoint || generation != m_speechGeneration || revision != m_audioRevision)
        return false;
    if (details.value("volume_control").metaType().id() != QMetaType::Bool ||
        !details.value("volume_control").toBool())
        return false;
    QString error;
    const bool accepted = endpoint->submit({{"schema", 1},
                                            {"kind", "audio-settings"},
                                            {"voice_volume", m_voiceVolume},
                                            {"alert_volume", m_alertVolume}},
                                           &error);
    if (!alive || !endpoint || generation != m_speechGeneration || revision != m_audioRevision)
        return false;
    const auto applied = endpoint->details();
    if (!alive || !endpoint || generation != m_speechGeneration || revision != m_audioRevision)
        return false;
    m_localAudioApplied =
        accepted &&
        QJsonValue::fromVariant(applied.value("voice_volume")).toDouble(-1) == m_voiceVolume &&
        QJsonValue::fromVariant(applied.value("alert_volume")).toDouble(-1) == m_alertVolume;
    return m_localAudioApplied;
}
QString ServiceHub::localAudioStatus() const {
    if (!m_speech)
        return "本机音量意向已记录；语音服务未启用，不播放";
    if (!m_localAudioApplied)
        return "当前提供者未接受本机音量；设备播放停用，仅可按能力合成";
    if (!m_speech->details().value("playback").toBool())
        return "音量偏好已接受；当前仅合成，不播放";
    return "本机0%立即静音；非零音量下一条生效。赛事自动提示音待来源核验接线";
}
bool ServiceHub::testAlertTone() {
    if (!m_speech || !m_localAudioApplied || !m_speech->details().value("active").toBool() ||
        !m_speech->details().value("playback").toBool() ||
        !m_speech->details().value("tone_control").toBool())
        return false;
    QString error;
    return m_speech->submit({{"schema", 1},
                             {"kind", "tone"},
                             {"priority", "info"},
                             {"request_id", QUuid::createUuid().toString(QUuid::WithoutBraces)},
                             {"key", "local-alert-test"},
                             {"expires_in_ms", 2000}},
                            &error);
}
bool ServiceHub::narrate(const QString &text, const QString &priority, const QString &key) {
    if (!m_speech || !m_backend || !m_backend->connected())
        return false;
    return submitSpeech(text, priority, key, 10000);
}
bool ServiceHub::submitTerminalSpeech(const QVariantMap &advice) {
    if (!m_speech || !m_seasonConfiguration ||
        m_seasonConfiguration->profileId() != "rmuc2027-regional-v1.0.0" ||
        advice.value("source") != "terminal-voice-coordinator" ||
        advice.value("fresh") != QVariant(true) || advice.value("voice_scope") != "local_only") return false;
    const auto request = advice.value("request_id");
    const auto text = advice.value("summary");
    const auto priority = advice.value("priority");
    const auto deadline = QJsonValue::fromVariant(advice.value("expires_at_tick_ms"));
    const auto reported = QJsonValue::fromVariant(advice.value("remaining_ms"));
    if (request.metaType().id() != QMetaType::QString || request.toString().isEmpty() || request.toString().size() > 80 ||
        text.metaType().id() != QMetaType::QString || text.toString().trimmed().isEmpty() || text.toString().size() > 180 ||
        priority.metaType().id() != QMetaType::QString || !QStringList{"info", "caution", "urgent"}.contains(priority.toString()) ||
        !deadline.isDouble() || !reported.isDouble() || !std::isfinite(deadline.toDouble()) ||
        !std::isfinite(reported.toDouble()) || std::floor(deadline.toDouble()) != deadline.toDouble() ||
        std::floor(reported.toDouble()) != reported.toDouble() || deadline.toDouble() < 0 || deadline.toDouble() > 9007199254740991.0 ||
        reported.toDouble() < 500 || reported.toDouble() > 10000) return false;
    const auto now = PacketObservation::steadyMilliseconds();
    const auto remaining = qMin<qint64>(qint64(reported.toDouble()), qint64(deadline.toDouble()) - now);
    if (remaining < 500) return false;
    const auto generation = m_speechGeneration;
    QPointer<ServiceHub> alive(this);
    const auto capabilities = m_speech->details();
    if (!alive || generation != m_speechGeneration || !m_speech || capabilities.value("keyed_cancellation") != QVariant(true)) return false;
    return submitSpeech(text.toString(), priority.toString(), "terminal." + request.toString(), int(remaining));
}
void ServiceHub::cancelTerminalSpeech(const QString &requestId) {
    if (!m_speech || requestId.isEmpty() || requestId.size() > 80) return;
    QString error;
    m_speech->submit({{"schema", 1}, {"kind", "cancel"}, {"key", "terminal." + requestId}}, &error);
}
bool ServiceHub::submitSpeech(const QString &text, const QString &priority, const QString &key,
                              int ttl) {
    // 未声明音量能力的替换服务不能绕过本机静音意向；仅合成没有设备输出。
    if (!m_speech) return false;
    QPointer<ServiceHub> alive(this); QPointer<ServiceEndpoint> endpoint(m_speech.get());
    const auto generation = m_speechGeneration, endpointGeneration = m_speechEndpointGeneration;
    const auto capabilities = endpoint->details();
    if (!alive || !endpoint || generation != m_speechGeneration || endpointGeneration != m_speechEndpointGeneration ||
        m_speech.get() != endpoint.data() || !speechLeaseActive(capabilities) ||
        !speechFlag(capabilities.value("active"), true) || (!m_localAudioApplied && capabilities.value("playback").toBool())) return false;
    QString error;
    const bool accepted = endpoint->submit({{"schema", 1},
                             {"kind", "speak"},
                             {"request_id", QUuid::createUuid().toString(QUuid::WithoutBraces)},
                             {"text", text.left(280)},
                             {"priority", priority},
                             {"key", key.left(96)},
                             {"expires_in_ms", ttl}},
                            &error);
    return alive && endpoint && generation == m_speechGeneration && endpointGeneration == m_speechEndpointGeneration && accepted;
}
bool ServiceHub::speakAdvice() {
    const auto remaining = qMin(m_adviceExpires, m_inputExpires) - m_clock.elapsed();
    if (!m_speech || !m_speech->details().value("keyed_cancellation").toBool() || !m_backend ||
        !m_backend->connected() || !m_advice.value("fresh").toBool() || !decisionEvidenceFresh() ||
        remaining < 500)
        return false;
    QPointer<ServiceHub> alive(this);
    const auto key = "advice:" + m_decisionTrace.value("request_id").toString();
    m_adviceSpeechKey = key;
    const bool accepted = submitSpeech(m_advice.value("summary").toString(),
                                       m_advice.value("priority").toString(), key, int(remaining));
    if (alive && !accepted && m_adviceSpeechKey == key)
        m_adviceSpeechKey.clear();
    return accepted;
}
bool ServiceHub::speakInputFacts() {
    const auto remaining = qMin<qint64>(10000 - (m_clock.elapsed() - m_decisionStarted),
                                        m_inputExpires - m_clock.elapsed());
    if (!m_speech || !m_speech->details().value("keyed_cancellation").toBool() ||
        !decisionInputFresh() || remaining < 500)
        return false;
    QPointer<ServiceHub> lifetime(this);
    const auto generation = m_decisionGeneration;
    m_inputSpeechOutstanding = true;
    const bool accepted =
        submitSpeech(spokenFacts(m_decisionInput), "info", "input-facts", int(remaining));
    if (lifetime && generation == m_decisionGeneration && !accepted)
        m_inputSpeechOutstanding = false;
    return accepted;
}
bool ServiceHub::testSpeech() {
    if (!m_speech)
        return false;
    return submitSpeech("RoboMaster 语音测试，注意观察遥测数据。", "info", "speech-test", 10000);
}
void ServiceHub::stopSpeech() {
    ++m_speechGeneration;
    m_inputSpeechOutstanding = false;
    m_adviceSpeechKey.clear();
    if (m_speech) {
        QString error;
        m_speech->submit({{"schema", 1}, {"kind", "cancel"}}, &error);
    }
}
