#include "LocalUiSettings.h"
#include "RobotIdentity.h"
#include "ServiceHub.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QLockFile>
#include <QSaveFile>
#include <QMetaProperty>
#include <cmath>

namespace {
bool robotId(int id) {
    return id == 0 || RobotIdentity::valid(id);
}
bool integer(const QVariant &value, int low, int high) {
    const auto json = QJsonValue::fromVariant(value);
    const double number = json.toDouble(-1);
    return json.isDouble() && std::isfinite(number) && number >= low && number <= high
           && std::floor(number) == number;
}
}
QVariantMap LocalUiSettings::defaults() {
    return {{"orientation",0}, {"sensitivity",100}, {"volume",80}, {"ambience",50}, {"windowMode",0}};
}
bool LocalUiSettings::valid(const QVariantMap &values) {
    return values.size() == 5 && integer(values.value("orientation"),0,1)
        && integer(values.value("sensitivity"),25,200) && integer(values.value("volume"),0,100)
        && integer(values.value("ambience"),0,100) && integer(values.value("windowMode"),0,2);
}
LocalUiSettings::LocalUiSettings(QObject *input, ServiceHub *services, const QString &file,
                               QObject *parent)
    : QObject(parent), m_input(input), m_services(services), m_file(file), m_values(defaults()) {
    selectRobot(0);
}
QVariantMap LocalUiSettings::capabilities() const {
    bool sensitivity = false;
    if (m_input) {
        const int index = m_input->metaObject()->indexOfProperty("mouseSensitivityPercent");
        if (index >= 0) {
            const auto property = m_input->metaObject()->property(index);
            sensitivity = property.isWritable() && property.metaType().id() == QMetaType::Int;
        }
    }
    return {{"localSettings",true}, {"orientation",true}, {"windowMode",true},
            {"sensitivity",sensitivity}, {"audioPreferences",true}};
}
bool LocalUiSettings::read(QVariantMap *robots, QString *error) const {
    robots->clear();
    QFile input(m_file);
    if (!QFileInfo::exists(m_file)) return true;
    if (!input.open(QIODevice::ReadOnly)) { *error = "本地偏好文件无法读取"; return false; }
    const auto bytes = input.read(16385);
    QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(bytes, &parse);
    const auto object = document.object();
    if (bytes.size() > 16384 || parse.error != QJsonParseError::NoError || !document.isObject()
        || !object.value("version").isDouble() || object.value("version").toDouble() != 1
        // Unselected defaults plus all nine red and nine blue seats, including darts.
        || !object.value("robots").isObject() || object.value("robots").toObject().size() > 19) {
        *error = "本地偏好格式／版本未通过，保留原文件"; return false;
    }
    const auto profiles = object.value("robots").toObject();
    for (auto it = profiles.begin(); it != profiles.end(); ++it) {
        bool ok = false; const int id = it.key().toInt(&ok);
        if (!ok || !robotId(id) || QString::number(id) != it.key() || !it.value().isObject()
            || !valid(it.value().toObject().toVariantMap())) {
            *error = "本地偏好含无效身份／字段，保留原文件"; return false;
        }
    }
    *robots = profiles.toVariantMap();
    return true;
}
bool LocalUiSettings::save(QString *error) {
    if (!QDir().mkpath(QFileInfo(m_file).absolutePath())) { *error = "偏好目录不可写"; return false; }
    QLockFile lock(m_file + ".lock");
    // 其他客户端正在保存时立即退化，不阻塞窗口或连接；成功时重新合并最新文件。
    if (!lock.tryLock(0)) { *error = "偏好文件正被另一个实例使用"; return false; }
    QVariantMap robots;
    if (!read(&robots, error)) return false;
    robots[QString::number(m_robot)] = m_values;
    const auto bytes = QJsonDocument(QJsonObject{{"version",1}, {"robots",QJsonObject::fromVariantMap(robots)}}).toJson(QJsonDocument::Compact);
    QSaveFile output(m_file);
    if (!output.open(QIODevice::WriteOnly)) { *error = "偏好文件不可写"; return false; }
    output.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    if (output.write(bytes) != bytes.size() || !output.commit()) { *error = "偏好文件未保存"; return false; }
    return true;
}
bool LocalUiSettings::applyInput(int sensitivity) {
    if (!capabilities().value("sensitivity").toBool()) return sensitivity == 100;
    auto input = m_input;
    return input && input->setProperty("mouseSensitivityPercent", sensitivity)
        && input && input->property("mouseSensitivityPercent").toInt() == sensitivity;
}
void LocalUiSettings::selectRobot(int id) {
    if (!robotId(id)) return;
    QPointer<LocalUiSettings> alive(this);
    const auto revision = ++m_revision;
    m_robot = id;
    QVariantMap robots; QString error;
    m_values = read(&robots, &error) ? robots.value(QString::number(id), defaults()).toMap() : defaults();
    const bool accepted = applyInput(m_values.value("sensitivity").toInt());
    if (!alive || revision != m_revision) return;
    if (!accepted) m_values["sensitivity"] = 100;
    if (m_services) m_services->setLocalAudioPreferences(m_values.value("volume").toInt(), m_values.value("ambience").toInt());
    if (!alive || revision != m_revision) return;
    m_status = error.isEmpty() ? "已载入本机身份偏好；未修改连接或遥测" : error + "；本窗口使用默认值";
    emit changed();
    if (alive && revision == m_revision) emit settingsApplied();
}
bool LocalUiSettings::apply(const QVariantMap &values) {
    QPointer<LocalUiSettings> alive(this);
    const auto revision = ++m_revision;
    if (!valid(values)) { m_status = "未应用：本地设置字段／范围无效"; emit changed(); return false; }
    const bool accepted = applyInput(values.value("sensitivity").toInt());
    if (!alive || revision != m_revision) return false;
    if (!accepted) {
        m_status = "未应用：当前输入插件未接受鼠标比例"; emit changed(); return false;
    }
    m_values = values;
    if (m_services) m_services->setLocalAudioPreferences(values.value("volume").toInt(), values.value("ambience").toInt());
    if (!alive || revision != m_revision) return false;
    QString error;
    m_status = save(&error) ? "本地设置已应用并保存；音频效果按服务能力显示" : "本地设置已应用，未保存：" + error;
    emit changed();
    if (!alive || revision != m_revision) return false;
    emit settingsApplied();
    return bool(alive);
}
