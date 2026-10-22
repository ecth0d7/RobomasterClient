#pragma once
#include "ClientPlugin.h"

// Project-defined JSON for local/terminal transport development. This is NOT
// the official RMU2027 wire protocol and grants no official source authority.
class TerminalLocalCodec final : public ProtocolEndpoint {
public:
    QStringList receiveTopics() const override { return {}; }
    bool decode(const QString &channel, const QByteArray &payload, QString *type,
                QVariantMap *fields, QString *error) const override;
    bool encode(const QString &type, const QVariantMap &fields, QString *channel,
                QByteArray *payload, QString *error) const override;
    int minimumIntervalMs(const QString &, int) const override { return 1; }
};
