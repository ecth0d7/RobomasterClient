#pragma once
#include "ClientPlugin.h"
#include "ProtocolCodec.h"
class BuiltinProtocolCodec final : public ProtocolEndpoint {
public:
    QStringList receiveTopics() const override {
        return Protocol::receiveTopics();
    }
    bool decode(const QString &topic, const QByteArray &bytes, QString *messageType,
                QVariantMap *fields, QString *error) const override {
        const auto message = Protocol::decode(topic, bytes, error);
        if (!message)
            return false;
        *fields = message->fields;
        *messageType = message->topic;
        return true;
    }
    bool encode(const QString &topic, const QVariantMap &fields, QString *wireTopic,
                QByteArray *bytes, QString *error) const override {
        const auto packet = Protocol::encode(topic, fields, error);
        if (!packet)
            return false;
        *bytes = packet->payload;
        *wireTopic = packet->topic;
        return true;
    }
    int minimumIntervalMs(const QString &topic, int robotId) const override {
        if (topic == "KeyboardMouseControl" || topic == "CustomControl")
            return 14;
        if (topic == "MapClickCmd")
            return (robotId == 6 || robotId == 106) ? 500 : 3000;
        return 100;
    }
};
