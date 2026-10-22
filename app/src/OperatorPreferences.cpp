#include "OperatorPreferences.h"
#include "OperatorActions.h"
#include "ClientBackend.h"
#include "RobotIdentity.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QLockFile>
#include <QSaveFile>
#include <QSet>
#include <cmath>

namespace {
constexpr int MaximumProfiles = 32;
constexpr int MaximumBytes = 64 * 1024;
bool integer(const QVariant &value, int low, int high) {
    if (value.metaType().id() == QMetaType::Bool || value.metaType().id() == QMetaType::QString)
        return false;
    bool ok = false;
    const double n = value.toDouble(&ok);
    return ok && std::isfinite(n) && std::floor(n) == n && n >= low && n <= high;
}
QVariantMap scopeOf(const QVariantMap &profile) {
    return {{"robot_id", profile.value("robot_id")}, {"host", profile.value("host")},
            {"port", profile.value("port")}, {"protocol_id", profile.value("protocol_id")}};
}
bool scopeValid(const QVariantMap &scope) {
    return scope.size() == 4 && integer(scope.value("robot_id"), 1, 109)
        && RobotIdentity::valid(scope.value("robot_id").toInt())
        && integer(scope.value("port"), 1, 65535)
        && scope.value("host").metaType().id() == QMetaType::QString
        && !scope.value("host").toString().trimmed().isEmpty() && scope.value("host").toString().size() <= 253
        && scope.value("protocol_id").metaType().id() == QMetaType::QString
        && !scope.value("protocol_id").toString().isEmpty() && scope.value("protocol_id").toString().size() <= 128;
}
bool fail(QString *error, const QString &reason) {
    if (error) *error = reason;
    return false;
}
}

OperatorPreferences::OperatorPreferences(ClientBackend *backend, OperatorActions *actions,
    QVariantMap startupValues, QString protocolId, QString file, QObject *parent)
    : QObject(parent), m_backend(backend), m_actions(actions), m_startupValues(std::move(startupValues)),
      m_protocol(std::move(protocolId)), m_file(std::move(file)) {
    // Live assembly context is never persisted or restored by this setup surface.
    m_startupValues.remove("assembly_context");
    if (backend) {
        m_startupHost = backend->host().trimmed().toLower();
        m_startupPort = backend->port();
        connect(backend, &ClientBackend::identityChanged, this, &OperatorPreferences::synchronize);
        connect(backend, &ClientBackend::connectionOptionsChanged, this, &OperatorPreferences::synchronize);
        connect(backend, &ClientBackend::connectionChanged, this, &OperatorPreferences::synchronize);
        connect(backend, &QObject::destroyed, this, &OperatorPreferences::synchronize);
    }
    if (actions) connect(actions, &QObject::destroyed, this, &OperatorPreferences::stateChanged);
    synchronize();
}
QVariantMap OperatorPreferences::currentScope() const {
    return {{"robot_id", m_backend ? m_backend->clientId() : 0},
            {"host", m_backend ? m_backend->host().trimmed().toLower() : QString{}},
            {"port", m_backend ? m_backend->port() : 0}, {"protocol_id", m_protocol}};
}
QString OperatorPreferences::targetLabel() const {
    const auto host = m_scope.value("host").toString();
    return QStringLiteral("%1:%2 · %3")
        .arg(host.contains(':') ? '[' + host + ']' : host)
        .arg(m_scope.value("port").toInt()).arg(m_protocol);
}
QString OperatorPreferences::lockReason() const {
    if (!m_backend || !m_actions) return QStringLiteral("操作配置宿主不可用");
    if (m_saving) return QStringLiteral("正在保存操作配置");
    if (!scopeValid(m_scope)) return QStringLiteral("先在身份页选择机器人，再配置本机操作");
    // 只限制宿主、范围与保存重入；比赛阶段不再禁止本地调试配置。
    return {};
}
void OperatorPreferences::synchronize() {
    const auto scope = currentScope();
    if (scope != m_scope) {
        m_scope = scope;
        if (!m_startupRobot && scopeValid(scope) && scope.value("host") == m_startupHost
            && scope.value("port").toInt() == m_startupPort)
            m_startupRobot = scope.value("robot_id").toInt();
        loadScope(true);
        return;
    }
    QPointer<OperatorPreferences> alive(this);
    if (alive) emit stateChanged();
}
bool OperatorPreferences::readProfiles(QVariantList *profiles, QString *error) const {
    profiles->clear();
    if (!QFileInfo::exists(m_file)) return true;
    QFile input(m_file);
    if (!input.open(QIODevice::ReadOnly)) return fail(error, "操作配置文件无法读取，原文件保留");
    const auto bytes = input.read(MaximumBytes + 1);
    QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(bytes, &parse);
    const auto object = document.object();
    if (bytes.size() > MaximumBytes || parse.error != QJsonParseError::NoError
        || !document.isObject() || object.size() != 2 || !object.value("schema").isDouble()
        || object.value("schema").toDouble() != 1 || !object.value("profiles").isArray()
        || object.value("profiles").toArray().size() > MaximumProfiles)
        return fail(error, "操作配置格式／版本无效，原文件保留");
    QVariantList result;
    for (const auto &value : object.value("profiles").toArray()) {
        if (!value.isObject()) return fail(error, "操作配置项不是对象");
        const auto item = value.toObject().toVariantMap();
        const auto scope = scopeOf(item);
        if (item.size() != 5 || !scopeValid(scope) || item.value("values").metaType().id() != QMetaType::QVariantMap
            || !OperatorActions::validatePreferences(item.value("values").toMap(), error))
            return fail(error, "操作配置含无效身份、目标或参数，原文件保留");
        for (const auto &existing : result)
            if (scopeOf(existing.toMap()) == scope) return fail(error, "操作配置存在重复目标／身份，未采用");
        result.append(item);
    }
    *profiles = result;
    return true;
}
bool OperatorPreferences::writeProfile(const QVariantMap &scope, const QVariantMap &values, QString *error) {
    if (m_file.isEmpty() || !QDir().mkpath(QFileInfo(m_file).absolutePath())) return fail(error, "操作配置目录不可写");
    QLockFile lock(m_file + ".lock");
    if (!lock.tryLock(0)) return fail(error, "另一客户端正在保存配置，请稍后再试");
    QVariantList profiles;
    if (!readProfiles(&profiles, error)) return false;
    QVariantMap item = scope;
    item.insert("values", values);
    bool replaced = false;
    for (auto &entry : profiles) {
        if (scopeOf(entry.toMap()) == scope) {entry = item; replaced = true; break;}
    }
    if (!replaced) profiles.append(item);
    if (profiles.size() > MaximumProfiles) return fail(error, "已保存32个操作配置范围，请先整理配置文件");
    const auto bytes = QJsonDocument(QJsonObject{{"schema", 1}, {"profiles", QJsonArray::fromVariantList(profiles)}})
                           .toJson(QJsonDocument::Indented);
    if (bytes.size() > MaximumBytes) return fail(error, "操作配置超过64KiB，未覆盖文件");
    QSaveFile output(m_file);
    if (!output.open(QIODevice::WriteOnly)) return fail(error, "操作配置文件不可写");
    output.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    if (output.write(bytes) != bytes.size() || !output.commit()) return fail(error, "操作配置保存失败，未应用草稿");
    return true;
}
bool OperatorPreferences::loadScope(bool notifyScope) {
    const auto revision = ++m_revision;
    QPointer<OperatorPreferences> alive(this);
    QVariantMap next;
    QString error;
    QVariantList profiles;
    bool loaded = readProfiles(&profiles, &error);
    if (loaded && scopeValid(m_scope)) {
        // A startup mapping belongs to the startup endpoint's first selected robot.
        // It must not silently follow the operator to another broker or robot.
        if (clientId() == m_startupRobot && m_scope.value("host") == m_startupHost
            && m_scope.value("port").toInt() == m_startupPort) next = m_startupValues;
        for (const auto &profile : profiles)
            if (scopeOf(profile.toMap()) == m_scope) {next = profile.toMap().value("values").toMap(); break;}
        loaded = OperatorActions::validatePreferences(next, &error);
    }
    if (!loaded) next.clear();
    m_values = next;
    if (m_actions) m_actions->setConfiguration(next);
    if (!alive || revision != m_revision) return false;
    m_status = !loaded ? error + QStringLiteral("；本范围操作授权保持停用")
        : !scopeValid(m_scope) ? QStringLiteral("未选身份；没有载入其他机器人的操作权限")
        : QStringLiteral("已载入本身份／MQTT目标／协议的操作配置；未发送指令");
    if (!alive || revision != m_revision) return false;
    if (notifyScope) emit scopeChanged();
    if (!alive || revision != m_revision) return false;
    emit valuesChanged();
    if (!alive || revision != m_revision) return false;
    emit stateChanged();
    return loaded && alive;
}
bool OperatorPreferences::reload() {
    QPointer<OperatorPreferences> alive(this);
    const auto revision = m_revision;
    const auto reason = lockReason();
    if (!alive || revision != m_revision) return false;
    if (!reason.isEmpty()) {m_status = reason; emit stateChanged(); return false;}
    return loadScope(false);
}
bool OperatorPreferences::apply(const QVariantMap &values) {
    QPointer<OperatorPreferences> alive(this);
    const auto previousRevision = m_revision;
    const auto scope = m_scope;
    auto reason = lockReason();
    if (!alive || previousRevision != m_revision) return false;
    if (!reason.isEmpty() || !OperatorActions::validatePreferences(values, &reason)) {
        m_status = reason; emit stateChanged(); return false;
    }
    // Filesystem operations are synchronous and bounded. No event loop is pumped
    // between validation and commit, and the runtime only changes on success.
    if (!writeProfile(scope, values, &reason)) {m_status = reason; emit stateChanged(); return false;}
    const auto revision = ++m_revision;
    m_saving = true;
    m_values = values;
    const bool applied = m_actions && m_actions->setConfiguration(values, &reason);
    if (!alive) return false;
    m_saving = false;
    if (revision != m_revision) {emit stateChanged(); return false;}
    m_status = applied ? QStringLiteral("已保存并应用本身份／MQTT目标的操作配置；未发送命令")
        : QStringLiteral("配置已保存，但宿主未应用：") + reason;
    emit valuesChanged();
    if (!alive || revision != m_revision) return false;
    emit stateChanged();
    return applied && alive;
}
