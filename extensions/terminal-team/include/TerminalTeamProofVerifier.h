#pragma once
#include <QVariantMap>
#include <QtPlugin>

// Native host admission only. Never exposed as a QML injection method. A true
// result re-verifies an ORIGINAL source envelope against configured current
// certificates, SPKI pins, schema3 scope and sender role. It does not verify a
// sensor measurement, producer clock, coordinates or model recommendation.
class TerminalTeamProofVerifier {
public:
    virtual ~TerminalTeamProofVerifier() = default;
    virtual bool verifySourceProof(const QVariantMap &proof, QVariantMap *body,
                                   QString *error = nullptr) = 0;
    virtual bool verifyTeamViewProof(const QVariantMap &proof, QVariantMap *body,
                                     QString *error = nullptr) = 0;
};
#define TerminalTeamProofVerifier_iid "org.robomaster.client.TerminalTeamProofVerifier/1.0"
Q_DECLARE_INTERFACE(TerminalTeamProofVerifier, TerminalTeamProofVerifier_iid)
