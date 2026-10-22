#pragma once
#include <QObject>
#include <QPointer>
#include <QVariantMap>
#include <QString>

class ServiceHub;

// 本地偏好独立于遥测、连接配置与机器人指令；输入插件通过可选Qt属性声明能力。
class LocalUiSettings : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap values READ values NOTIFY changed)
    Q_PROPERTY(QVariantMap capabilities READ capabilities NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString file READ file CONSTANT)
public:
    LocalUiSettings(QObject *input, ServiceHub *services, const QString &file,
                    QObject *parent = nullptr);
    QVariantMap values() const { return m_values; }
    QVariantMap capabilities() const;
    QString status() const { return m_status; }
    QString file() const { return m_file; }
    void selectRobot(int id);
    Q_INVOKABLE bool apply(const QVariantMap &values);
    static QVariantMap defaults();
    static bool valid(const QVariantMap &values);
signals:
    void changed();
    void settingsApplied();
private:
    bool read(QVariantMap *robots, QString *error) const;
    bool save(QString *error);
    bool applyInput(int sensitivity);
    QPointer<QObject> m_input;
    QPointer<ServiceHub> m_services;
    QString m_file, m_status;
    QVariantMap m_values;
    int m_robot = 0;
    quint64 m_revision = 0;
};
