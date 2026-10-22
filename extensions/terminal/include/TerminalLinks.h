#pragma once

#include "ServiceEndpoint.h"

// Neutral raw-byte transports. They contain no RoboMaster message schema,
// referee authentication, telemetry classification or automatic forwarding.
// start() takes schema:1 and context:{profile_id,field_profile_id,
// capability_revision}, plus the selected kind's explicit address/allowlists.
// submit() takes {schema:1,kind:"wire-send",request_id,channel,payload:QByteArray}.
// wire-received preserves the original SDK session, sequence and ingress
// UTC/steady timestamps. Wrapping a transport must not recapture that receipt.
// wire-submit-result means local submission only, never delivery/execution.
namespace TerminalLinks {
enum class Kind { Loopback, Mqtt, Udp };
// Pure shape/address/allowlist checks. This never creates a socket, resolves a
// hostname or claims that a peer is available or authenticated.
bool validateConfiguration(Kind kind, const QVariantMap &configuration, QString *error = nullptr);
ServiceEndpoint *create(Kind kind, QObject *parent = nullptr);
}
