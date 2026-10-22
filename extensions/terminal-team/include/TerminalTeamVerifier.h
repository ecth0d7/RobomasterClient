#pragma once

#include "TerminalTeamProofVerifier.h"
#include <memory>

// Independent native-host verifier for the project schema3 team contract. It
// shares TeamNetwork's actual certificate/signature implementation, but never
// connects to MQTT, signs a message or reads the private signing-key file.
// Configuration, certificate parsing and proof verification run on a private
// worker. Calls are synchronous and serialized; stop() revokes and joins it.
// This authenticates an envelope's configured source, not its measurements,
// producer clock, coordinates or an official referee/server relationship.
class TerminalTeamVerifier final : public TerminalTeamProofVerifier {
public:
    TerminalTeamVerifier();
    ~TerminalTeamVerifier() override;
    TerminalTeamVerifier(const TerminalTeamVerifier &) = delete;
    TerminalTeamVerifier &operator=(const TerminalTeamVerifier &) = delete;

    // Accepts the exact full native TerminalTeamContract configuration. A bad
    // reconfiguration retires the old trust context and fails closed.
    bool configure(const QVariantMap &configuration, QString *error = nullptr);
    void stop();
    bool verifySourceProof(const QVariantMap &proof, QVariantMap *body,
                           QString *error = nullptr) override;
    bool verifyTeamViewProof(const QVariantMap &proof, QVariantMap *body,
                             QString *error = nullptr) override;

private:
    bool verify(const QVariantMap &proof, QVariantMap *body,
                const QString &kind, QString *error);
    struct Private;
    std::unique_ptr<Private> d;
};
