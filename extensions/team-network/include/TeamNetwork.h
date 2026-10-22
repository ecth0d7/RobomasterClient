#pragma once

#include <QObject>
#include <QVariantMap>
#include <memory>

// Optional team-only transport. It never owns the official player connection,
// interprets measurements, forwards peer packets or submits robot commands.
// Call the API on the owning Qt thread; stop() also marshals an external caller
// to that thread. The owning event loop must therefore still exist during stop.
class TeamNetwork final : public QObject {
    Q_OBJECT
public:
    explicit TeamNetwork(QObject *parent = nullptr);
    ~TeamNetwork() override;

    // Local configuration/credential errors return false. A true result starts
    // an asynchronous TLS connection, not a successful connection or delivery.
    // contract_version=3 selects the independent terminal-team namespace,
    // signing domain, exact rules context and semantic robot_key identity.
    // Omitting it retains the historical v2 contract; versions never mix.
    bool start(const QVariantMap &configuration, QString *error = nullptr);
    // Host-side schema3 proof admission uses the same trust/signature code
    // without loading a signing private key, initializing MQTT or opening a
    // socket. The full native transport configuration is still validated;
    // signing_key_file is only a bounded reference and is never read here.
    bool configureVerification(const QVariantMap &configuration, QString *error = nullptr);
    void stop();
    bool publish(const QVariantMap &body, QString *error = nullptr);
    QVariantMap signedEnvelope(const QVariantMap &body, QString *error = nullptr) const;
    // Verification returns a body with transport-owned _network provenance.
    // The original body bytes and signature remain in _network.proof.
    bool verifyEnvelope(const QVariantMap &envelope, QVariantMap *body,
                        QString *error = nullptr) const;
    bool publishEnvelope(const QVariantMap &envelope, QString *error = nullptr);
    QVariantMap details() const;

signals:
    void messageReceived(const QVariantMap &body);
    void statusChanged();

private:
    bool configure(const QVariantMap &configuration, bool transport, QString *error);
    struct Private;
    std::unique_ptr<Private> d;
};
