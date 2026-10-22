#pragma once
#include <QByteArray>
#include <QStringList>
#include <QVariantMap>
#include <optional>

namespace Protocol {
struct Message {
    QString topic;
    QVariantMap fields;
};
struct Packet {
    QString topic;
    QByteArray payload;
};
QStringList receiveTopics();
std::optional<Message> decode(const QString &topic, const QByteArray &payload,
                              QString *error = nullptr);
std::optional<Packet> encode(const QString &topic, const QVariantMap &fields,
                             QString *error = nullptr);
} // Protocol 命名空间
