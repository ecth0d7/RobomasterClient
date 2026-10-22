#pragma once
#include "ClientPlugin.h"

// Deliberately non-operational. This is not a guessed 2027 codec: no topics,
// ports, fields, robot IDs or commands are invented while the spec is pending.
class UnavailableProtocol final : public ProtocolEndpoint {
public:
    QStringList receiveTopics() const override { return {}; }
    bool decode(const QString &, const QByteArray &, QString *type,
                QVariantMap *fields, QString *error) const override {
        if (type) type->clear();
        if (fields) fields->clear();
        if (error) *error = QStringLiteral("2027详细通信协议尚未取得，未解码数据");
        return false;
    }
    bool encode(const QString &, const QVariantMap &, QString *topic,
                QByteArray *bytes, QString *error) const override {
        if (topic) topic->clear();
        if (bytes) bytes->clear();
        if (error) *error = QStringLiteral("2027命令字段未核实，未编码或发送");
        return false;
    }
    int minimumIntervalMs(const QString &, int) const override { return 1; }
};

// Keeps the setup workspace usable without loading or opening a legacy network
// plugin. Real neutral I/O lives in explicitly configured terminal-link modules.
class ClosedTerminalTransport final : public MqttEndpoint {
public:
    using MqttEndpoint::MqttEndpoint;
    bool open(const QString &, const QString &, int, const QStringList &) override { return false; }
    void close() override {}
    bool publish(const QString &, const QByteArray &) override { return false; }
};
