#pragma once
#include <QObject>
#include <QByteArray>
#include <QStringList>
#include <QVariantMap>
#include <QImage>
#include <QtPlugin>

// 共享 QObject 基类位于 client_plugin_sdk，确保所有插件使用同一元对象。
// 端点由宿主管理，插件工厂由加载器管理。
class MqttEndpoint : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;
    virtual bool open(const QString &id, const QString &host, int port,
                      const QStringList &topics) = 0;
    virtual void close() = 0;
    virtual bool publish(const QString &topic, const QByteArray &payload) = 0;
signals:
    void connected();
    void disconnected();
    void errorOccurred(const QString &message);
    void packetReceived(const QString &topic, const QByteArray &payload);
};

class ProtocolEndpoint {
public:
    virtual ~ProtocolEndpoint() = default;
    virtual QStringList receiveTopics() const = 0;
    virtual bool decode(const QString &topic, const QByteArray &payload, QString *messageType,
                        QVariantMap *fields, QString *error) const = 0;
    virtual bool encode(const QString &messageType, const QVariantMap &fields, QString *wireTopic,
                        QByteArray *payload, QString *error) const = 0;
    virtual int minimumIntervalMs(const QString &messageType, int robotId) const = 0;
};

class VideoEndpoint : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY statisticsChanged)
    Q_PROPERTY(double fps READ fps NOTIFY statisticsChanged)
public:
    using QObject::QObject;
    virtual QString status() const = 0;
    virtual double fps() const = 0;
signals:
    void frameDecoded(const QImage &image);
    void frameReady();
    void statisticsChanged();
};

class ClientPlugin {
public:
    virtual ~ClientPlugin() = default;
    virtual QString id() const = 0;
    virtual QString role() const = 0;
    virtual MqttEndpoint *createMqtt() {
        return nullptr;
    }
    virtual ProtocolEndpoint *createProtocol() {
        return nullptr;
    }
    virtual VideoEndpoint *createVideo(const QVariantMap &) {
        return nullptr;
    }
};
#define ClientPlugin_iid "org.robomaster.client.ClientPlugin/1.0"
Q_DECLARE_INTERFACE(ClientPlugin, ClientPlugin_iid)
