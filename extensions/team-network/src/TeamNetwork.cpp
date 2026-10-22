#include "TeamNetwork.h"

#include <QCryptographicHash>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QMetaObject>
#include <QMutex>
#include <QMutexLocker>
#include <QPointer>
#include <QQueue>
#include <QSet>
#include <QThread>
#include <QUrl>
#include <mosquitto.h>
#include <openssl/crypto.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/rsa.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>
#include <atomic>
#include <chrono>
#include <QDateTime>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <limits>

namespace {
constexpr qsizetype SourceLimit = 16 * 1024;
constexpr qsizetype TerminalSourceLimit = 64 * 1024;
constexpr qsizetype ViewLimit = 256 * 1024;
constexpr qsizetype EnvelopeLimit = ((ViewLimit + 2) / 3) * 4 + 16 * 1024;
constexpr qsizetype QueueBytes = 1024 * 1024;
constexpr int QueueMessages = 32;
constexpr int ControlEvents = 64;
constexpr int MaxPeers = 15; // At most sixteen members including this node.
constexpr qint64 JsonSafeInteger = 9007199254740991LL;

qint64 receiveTick() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}

bool fail(QString *error, const QString &reason) {
    if (error) *error = reason;
    return false;
}

bool identifier(const QString &value) {
    if (value.isEmpty() || value.size() > 64) return false;
    for (const auto ch : value) {
        const auto u = ch.unicode();
        if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') ||
              (u >= '0' && u <= '9') || u == '-' || u == '_' || u == '.')) return false;
    }
    return true;
}

bool terminalContext(const QVariant &value) {
    if (value.metaType().id() != QMetaType::QVariantMap) return false;
    const auto map = value.toMap();
    if (map.size() != 3) return false;
    for (const auto &key : {"profile_id", "field_profile_id", "capability_revision"}) {
        const auto field = map.value(QLatin1String(key));
        if (field.metaType().id() != QMetaType::QString || field.toString().isEmpty() || field.toString().size() > 128)
            return false;
        for (const auto c : field.toString()) {
            const auto u = c.unicode();
            if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') ||
                  (u >= '0' && u <= '9') || u == '-' || u == '_' || u == '.' || u == ':' || u == '/')) return false;
        }
    }
    return true;
}
bool terminalRobot(const QVariant &value, QString *out = nullptr) {
    if (value.metaType().id() != QMetaType::QString || value.toString().size() > 64) return false;
    const auto parts = value.toString().split('/');
    if (parts.size() != 3 || (parts[0] != "red" && parts[0] != "blue") || !identifier(parts[1]) ||
        parts[1].size() > 32 || parts[2].isEmpty() || parts[2].size() > 3 || parts[2][0] < '1' || parts[2][0] > '9') return false;
    for (const auto c : parts[2]) if (c < '0' || c > '9') return false;
    if (out) *out = value.toString();
    return true;
}

bool plainString(const QVariant &value, QString *out, bool topicId = false) {
    if (value.metaType().id() != QMetaType::QString) return false;
    const auto text = value.toString();
    if (topicId ? !identifier(text) : text.isEmpty() || text.size() > 128) return false;
    if (out) *out = text;
    return true;
}

bool credentialPath(const QVariant &value, QString *out) {
    if (value.metaType().id() != QMetaType::QString) return false;
    const auto path = value.toString();
    if (path.isEmpty() || path.size() > 4096 || path.contains(QChar(u'\0'))) return false;
    *out = path;
    return true;
}

bool integer(const QVariant &value, qint64 low, qint64 high, qint64 *out = nullptr) {
    switch (value.metaType().id()) {
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double: case QMetaType::Float:
    case QMetaType::Long: case QMetaType::ULong: case QMetaType::Short:
    case QMetaType::UShort: case QMetaType::Char: case QMetaType::UChar:
        break;
    default: return false;
    }
    const auto number = value.toDouble();
    if (!std::isfinite(number) || std::floor(number) != number ||
        number < double(low) || number > double(high)) return false;
    if (out) *out = qint64(number);
    return true;
}

bool flag(const QVariantMap &map, const QString &key, bool *out) {
    if (!map.contains(key)) { *out = false; return true; }
    if (map.value(key).metaType().id() != QMetaType::Bool) return false;
    *out = map.value(key).toBool();
    return true;
}

// Inspect before serializing: QVariant permits arbitrary metatypes and deeply
// nested containers that must not become an unbounded serialization operation.
bool jsonValue(const QVariant &value, int depth, qsizetype limit,
               qsizetype *cost, int *nodes) {
    if (depth > 8 || ++*nodes > 32768 || *cost > limit) return false;
    if (!value.isValid() || value.isNull()) { *cost += 4; return *cost <= limit; }
    const auto type = value.metaType().id();
    if (type == QMetaType::QVariantMap) {
        const auto map = value.toMap();
        *cost += 2;
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            if (it.key().size() > 128) return false;
            *cost += it.key().toUtf8().size() + 4;
            if (!jsonValue(it.value(), depth + 1, limit, cost, nodes)) return false;
        }
    } else if (type == QMetaType::QVariantList || type == QMetaType::QStringList) {
        const auto list = value.toList();
        *cost += 2;
        if (list.size() > 32768) return false;
        for (const auto &entry : list) {
            ++*cost;
            if (!jsonValue(entry, depth + 1, limit, cost, nodes)) return false;
        }
    } else if (type == QMetaType::QString) {
        if (value.toString().size() > limit) return false;
        *cost += value.toString().toUtf8().size() + 2;
    } else if (type == QMetaType::Bool) {
        *cost += 5;
    } else {
        if (type != QMetaType::Double && type != QMetaType::Float &&
            !integer(value, -JsonSafeInteger, JsonSafeInteger)) return false;
        const auto number = value.toDouble();
        if (!std::isfinite(number) || std::abs(number) > double(JsonSafeInteger)) return false;
        *cost += 24;
    }
    return *cost <= limit;
}

QByteArray compact(const QVariantMap &body, qsizetype limit, QString *error) {
    qsizetype cost = 0;
    int nodes = 0;
    if (!jsonValue(body, 0, limit, &cost, &nodes)) {
        fail(error, QStringLiteral("Team body exceeds JSON depth/size/type bounds"));
        return {};
    }
    const auto bytes = QJsonDocument(QJsonObject::fromVariantMap(body)).toJson(QJsonDocument::Compact);
    if (bytes.isEmpty() || bytes.size() > limit) {
        fail(error, QStringLiteral("Team body exceeds its byte limit"));
        return {};
    }
    return bytes;
}

bool readCredential(const QString &path, qsizetype limit, QByteArray *bytes) {
    const QFileInfo info(path);
    if (!info.isFile() || info.size() <= 0 || info.size() > limit) return false;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return false;
    *bytes = file.read(limit + 1);
    return !bytes->isEmpty() && bytes->size() <= limit && file.atEnd();
}

int noPassword(char *, int, int, void *) { return 0; }

using Certificate = std::shared_ptr<X509>;
using Key = std::shared_ptr<EVP_PKEY>;
using Store = std::shared_ptr<X509_STORE>;
using DigestContext = std::unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)>;

QString algorithm(EVP_PKEY *key) {
    switch (EVP_PKEY_base_id(key)) {
    case EVP_PKEY_ED25519: return QStringLiteral("Ed25519");
    case EVP_PKEY_ED448: return QStringLiteral("Ed448");
    case EVP_PKEY_EC: return QStringLiteral("ECDSA-SHA256");
    case EVP_PKEY_RSA: case EVP_PKEY_RSA_PSS: return QStringLiteral("RSA-PSS-SHA256");
    default: return {};
    }
}

QByteArray publicKeyDigest(EVP_PKEY *key) {
    unsigned char *der = nullptr;
    const int length = i2d_PUBKEY(key, &der);
    if (length <= 0) return {};
    const auto digest = QCryptographicHash::hash(
        QByteArrayView(reinterpret_cast<const char *>(der), length), QCryptographicHash::Sha256);
    OPENSSL_free(der);
    return digest;
}

QString certificateFingerprint(X509 *cert) {
    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int length = 0;
    if (X509_digest(cert, EVP_sha256(), digest, &length) != 1 || length != 32) return {};
    return QString::fromLatin1(QByteArray(reinterpret_cast<const char *>(digest), length).toHex());
}

bool currentCertificate(X509 *cert) {
    return X509_cmp_current_time(X509_get0_notBefore(cert)) < 0 &&
           X509_cmp_current_time(X509_get0_notAfter(cert)) > 0;
}

struct Identity {
    QString node;
    QString robotKey;
    qint64 robot = 0;
    Certificate certificate;
    Key key;
    QString fingerprint;
    QByteArray publicDigest;
    QList<Certificate> intermediates;
    bool send = false;
    bool aggregate = false;
    bool voice = false;
    bool hear = false;
};

bool chainTrusted(const Identity &identity, X509_STORE *store) {
    if (!identity.certificate || !store) return false;
    STACK_OF(X509) *chain = sk_X509_new_null();
    if (!chain) return false;
    for (const auto &cert : identity.intermediates) {
        if (!sk_X509_push(chain, cert.get())) { sk_X509_free(chain); return false; }
    }
    std::unique_ptr<X509_STORE_CTX, decltype(&X509_STORE_CTX_free)> context(X509_STORE_CTX_new(), X509_STORE_CTX_free);
    const bool initialized = context && X509_STORE_CTX_init(context.get(), store, identity.certificate.get(), chain) == 1;
    const bool purpose = initialized && X509_STORE_CTX_set_purpose(context.get(), X509_PURPOSE_SSL_CLIENT) == 1;
    const bool trusted = purpose && X509_verify_cert(context.get()) == 1;
    sk_X509_free(chain);
    return trusted && currentCertificate(identity.certificate.get());
}

bool loadIdentity(const QString &path, X509_STORE *store, Identity *identity, QString *error) {
    QByteArray pem;
    if (!readCredential(path, 1024 * 1024, &pem))
        return fail(error, QStringLiteral("Cannot read bounded node certificate file"));
    std::unique_ptr<BIO, decltype(&BIO_free)> bio(BIO_new_mem_buf(pem.constData(), int(pem.size())), BIO_free);
    if (!bio) return fail(error, QStringLiteral("Cannot allocate certificate reader"));
    Certificate leaf(PEM_read_bio_X509(bio.get(), nullptr, noPassword, nullptr), X509_free);
    if (!leaf) return fail(error, QStringLiteral("Invalid PEM node certificate"));
    QList<Certificate> intermediates;
    for (int i = 0; i < 16; ++i) {
        X509 *next = PEM_read_bio_X509(bio.get(), nullptr, noPassword, nullptr);
        if (!next) break;
        intermediates.append(Certificate(next, X509_free));
        if (i == 15) return fail(error, QStringLiteral("Certificate chain is too long"));
    }
    identity->certificate = leaf;
    identity->intermediates = std::move(intermediates);
    const bool trusted = chainTrusted(*identity, store);
    const auto usage = X509_get_key_usage(leaf.get());
    if (!trusted || !currentCertificate(leaf.get()) || X509_check_ca(leaf.get()) > 0 ||
        X509_check_purpose(leaf.get(), X509_PURPOSE_SSL_CLIENT, 0) != 1 ||
        (usage != std::numeric_limits<uint32_t>::max() && !(usage & KU_DIGITAL_SIGNATURE)))
        return fail(error, QStringLiteral("Node certificate chain/time/client/signing purpose is invalid"));
    Key key(X509_get_pubkey(leaf.get()), EVP_PKEY_free);
    if (!key || algorithm(key.get()).isEmpty() || EVP_PKEY_security_bits(key.get()) < 112)
        return fail(error, QStringLiteral("Unsupported or weak node signing key"));
    identity->certificate = std::move(leaf);
    identity->key = std::move(key);
    identity->fingerprint = certificateFingerprint(identity->certificate.get());
    identity->publicDigest = publicKeyDigest(identity->key.get());
    if (identity->fingerprint.isEmpty() || identity->publicDigest.isEmpty())
        return fail(error, QStringLiteral("Cannot fingerprint node certificate/public key"));
    return true;
}

bool initSignature(EVP_MD_CTX *context, EVP_PKEY *key, bool signing) {
    const auto type = EVP_PKEY_base_id(key);
    const EVP_MD *digest = type == EVP_PKEY_ED25519 || type == EVP_PKEY_ED448 ? nullptr : EVP_sha256();
    EVP_PKEY_CTX *keyContext = nullptr;
    const int result = signing ? EVP_DigestSignInit(context, &keyContext, digest, nullptr, key)
                               : EVP_DigestVerifyInit(context, &keyContext, digest, nullptr, key);
    if (result != 1) return false;
    if (type == EVP_PKEY_RSA || type == EVP_PKEY_RSA_PSS)
        return EVP_PKEY_CTX_set_rsa_padding(keyContext, RSA_PKCS1_PSS_PADDING) > 0 &&
               EVP_PKEY_CTX_set_rsa_pss_saltlen(keyContext, RSA_PSS_SALTLEN_DIGEST) > 0 &&
               EVP_PKEY_CTX_set_rsa_mgf1_md(keyContext, EVP_sha256()) > 0;
    return true;
}

QByteArray signedBytes(const QByteArray &body, const QByteArray &topic, const QString &fingerprint, int version) {
    // NUL separators are unambiguous: IDs/topics are restricted ASCII, the
    // fingerprint is fixed hex, and body is the final exact byte string.
    QByteArray result = version == 3 ? QByteArrayLiteral("RoboMasterClient.TerminalTeam.signed-body.v3")
                                    : QByteArrayLiteral("RoboMasterClient.TeamNetwork.signed-body.v2");
    result += '\0';
    result += topic;
    result += '\0';
    result += fingerprint.toLatin1();
    result += '\0';
    result += body;
    return result;
}

bool base64(const QVariant &value, qsizetype maximum, QByteArray *decoded) {
    if (value.metaType().id() != QMetaType::QString) return false;
    const auto text = value.toString();
    if (text.isEmpty() || text.size() > ((maximum + 2) / 3) * 4) return false;
    const auto encoded = text.toLatin1();
    const auto result = QByteArray::fromBase64Encoding(encoded, QByteArray::AbortOnBase64DecodingErrors);
    if (!result || result.decoded.size() > maximum || result.decoded.toBase64() != encoded) return false;
    *decoded = result.decoded;
    return true;
}

bool flatEnvelope(const QJsonObject &object) {
    if (object.size() != 6 || !object.value("schema").isDouble()) return false;
    for (const auto &key : {"signer", "certificate_sha256", "algorithm", "body_b64", "signature_b64"})
        if (!object.value(QLatin1String(key)).isString()) return false;
    return true;
}

// Do not call global cleanup from an optional unloadable library: other MQTT
// instances may still be active. Core libmosquitto already uses a process-wide
// lifecycle; init here also permits this service to be used independently.
bool initializeMosquitto() {
    static const int result = mosquitto_lib_init();
    return result == MOSQ_ERR_SUCCESS;
}
} // namespace

struct TeamNetwork::Private {
    explicit Private(TeamNetwork *object) : owner(object) {}
    enum class Kind { Connected, Disconnected, Subscribed, Published };
    struct Control { Kind kind; int result; int id; };
    struct Incoming {
        QByteArray topic; QByteArray envelope; qsizetype cost;
        qint64 receivedAt, receivedTick;
    };
    struct Rate { qint64 tick = 0; int tokens = 8; };
    struct Callback {
        Private *self;
        quint64 generation;
        QByteArray ownTopic;
        QSet<QByteArray> peerTopics;
    };

    TeamNetwork *owner;
    mosquitto *client = nullptr;
    std::unique_ptr<Callback> callback;
    bool loopStarted = false;
    bool running = false;
    bool verificationOnly = false;
    std::atomic_bool connected{false};
    std::atomic<quint64> generation{0};
    QString team, match, epoch, session, endpoint, prefix, state = QStringLiteral("stopped"), error;
    int version = 2;
    QVariantMap rulesContext;
    Identity own;
    Key signingKey;
    Store trust;
    QHash<QString, Identity> peers;
    QSet<int> subscriptions;
    QHash<int, qsizetype> outgoing;
    qsizetype outgoingBytes = 0;
    int heartbeatMs = 1000, timeoutMs = 5000;
    mutable QMutex mutex;
    QQueue<Control> controls;
    QQueue<Incoming> inbox;
    QHash<QByteArray, Rate> rates;
    qsizetype inboxBytes = 0;
    bool scheduled = false;
    quint64 received = 0, delivered = 0, dropped = 0, rejected = 0, published = 0;

    bool ownThread(QString *out) const {
        return QThread::currentThread() == owner->thread() ||
               fail(out, QStringLiteral("TeamNetwork API requires its owning Qt thread"));
    }
    QByteArray topic(const QString &node) const { return (prefix + node + "/data").toUtf8(); }
    const Identity *identity(const QString &node) const {
        if (node == own.node) return &own;
        const auto it = peers.constFind(node);
        return it == peers.cend() ? nullptr : &it.value();
    }
    bool bodyScope(const QVariantMap &body, const Identity &sender, QString *out) const {
        qint64 schema = 0, robot = -1;
        QString node, teamId, matchId, epochId, sessionId, kind;
        const bool sourceMatches = version == 3
            ? terminalRobot(body.value("robot_key")) && body.value("robot_key").toString() == sender.robotKey &&
              !body.contains("robot_id") && terminalContext(body.value("context")) && body.value("context").toMap() == rulesContext
            : integer(body.value("robot_id"), 0, 4294967295LL, &robot) && robot == sender.robot &&
              !body.contains("robot_key") && !body.contains("context");
        if (body.contains("_network") || !integer(body.value("schema"), version, version, &schema) ||
            !plainString(body.value("source_node"), &node, true) || node != sender.node ||
            !plainString(body.value("team_id"), &teamId, true) || teamId != team ||
            !plainString(body.value("match_id"), &matchId, true) || matchId != match ||
            !plainString(body.value("epoch"), &epochId, true) || epochId != epoch ||
            !sourceMatches ||
            !plainString(body.value("session_id"), &sessionId) ||
            !integer(body.value("session_started_ms"), 1, JsonSafeInteger) ||
            !integer(body.value("sequence"), 1, JsonSafeInteger) ||
            !integer(body.value("sent_at_ms"), 1, JsonSafeInteger) ||
            !plainString(body.value("kind"), &kind))
            return fail(out, QStringLiteral("Signed body has invalid schema/source/team/match/epoch/identity fields"));
        if (kind == "node-snapshot") {
            if (!sender.send) return fail(out, QStringLiteral("Node has no data-send permission"));
        } else if (kind == "team-view") {
            if (!sender.aggregate) return fail(out, QStringLiteral("Node has no aggregate permission"));
        } else if (kind != "heartbeat") {
            return fail(out, QStringLiteral("Unsupported team message kind"));
        }
        return true;
    }
    void schedule(quint64 gen) {
        QMetaObject::invokeMethod(owner, [this, gen] { drain(gen); }, Qt::QueuedConnection);
    }
    void control(quint64 gen, Control event) {
        bool wake = false;
        {
            QMutexLocker lock(&mutex);
            if (gen != generation.load()) return;
            if (controls.size() >= ControlEvents) { controls.dequeue(); ++dropped; }
            controls.enqueue(event);
            if (!scheduled) { scheduled = true; wake = true; }
        }
        if (wake) schedule(gen);
    }
    void incoming(quint64 gen, const mosquitto_message *message, const Callback &context) {
        // Reject before allocating/copying payload, including retained packets
        // that could otherwise resurrect a previous match's signed message.
        if (!message || !message->topic || message->retain || message->payloadlen <= 0 ||
            message->payloadlen > EnvelopeLimit || !message->payload ||
            strnlen(message->topic, 513) > 512) return;
        const QByteArray wireTopic(message->topic);
        if (wireTopic == context.ownTopic || !context.peerTopics.contains(wireTopic)) return;
        const auto arrivalTick = receiveTick();
        const auto arrivalUtc = QDateTime::currentMSecsSinceEpoch();
        bool wake = false;
        {
            QMutexLocker lock(&mutex);
            if (gen != generation.load()) return;
            ++received;
            const qsizetype cost = message->payloadlen + wireTopic.size();
            // Per-member bursts cannot occupy every ingress slot. Signature and
            // source-proof work is additionally kept off the GUI thread.
            auto &rate = rates[wireTopic];
            const auto refill = qMin<qint64>(8, (arrivalTick - rate.tick) / 50);
            if (refill > 0) {
                rate.tokens = qMin(8, rate.tokens + int(refill));
                rate.tick = arrivalTick;
            }
            int queued = 0;
            for (const auto &entry : inbox) if (entry.topic == wireTopic) ++queued;
            const int workCost = message->payloadlen > 32 * 1024 ? 4 : 1;
            if (rate.tokens < workCost || queued >= 2 || inbox.size() >= QueueMessages
                || inboxBytes + cost > QueueBytes) { ++dropped; return; }
            rate.tokens -= workCost;
            inbox.enqueue({wireTopic, QByteArray(static_cast<const char *>(message->payload), message->payloadlen),
                           cost, arrivalUtc, arrivalTick});
            inboxBytes += cost;
            if (!scheduled) { scheduled = true; wake = true; }
        }
        if (wake) schedule(gen);
    }
    void drain(quint64 gen) {
        QPointer<TeamNetwork> lifetime(owner);
        if (gen != generation.load()) return;
        for (int count = 0; count < ControlEvents; ++count) {
            Control event;
            {
                QMutexLocker lock(&mutex);
                if (gen != generation.load()) return;
                if (controls.isEmpty()) break;
                event = controls.dequeue();
            }
            if (event.kind == Kind::Connected) {
                connected = false;
                subscriptions.clear();
                outgoing.clear(); outgoingBytes = 0;
                if (event.result != 0) {
                    state = "offline"; error = QStringLiteral("Team broker refused connection (%1)").arg(event.result);
                } else {
                    state = "subscribing"; error.clear();
                    for (auto it = peers.cbegin(); it != peers.cend(); ++it) {
                        int mid = 0;
                        const int result = mosquitto_subscribe(client, &mid, topic(it.key()).constData(), 0);
                        if (result != MOSQ_ERR_SUCCESS) { error = "Team subscription could not be queued"; break; }
                        subscriptions.insert(mid);
                    }
                    if (!error.isEmpty()) { state = "error"; mosquitto_disconnect(client); }
                    else if (subscriptions.isEmpty()) { connected = true; state = "connected"; }
                }
            } else if (event.kind == Kind::Disconnected) {
                connected = false; state = running ? "offline" : "stopped";
                error = running ? QStringLiteral("Team TLS/MQTT connection unavailable (%1)").arg(event.result) : QString();
                subscriptions.clear(); outgoing.clear(); outgoingBytes = 0;
            } else if (event.kind == Kind::Subscribed) {
                if (subscriptions.remove(event.id)) {
                    if (event.result != 0) {
                        connected = false; state = "error"; error = "Team broker denied a required subscription";
                        mosquitto_disconnect(client);
                    } else if (subscriptions.isEmpty() && state == "subscribing") {
                        connected = true; state = "connected";
                    }
                }
            } else {
                const auto it = outgoing.find(event.id);
                if (it != outgoing.end()) { outgoingBytes -= it.value(); outgoing.erase(it); }
            }
        }
        // Verification and JSON parsing are bounded and yield after two packets
        // rather than monopolising the UI/service thread under a peer flood.
        for (int count = 0; count < 2; ++count) {
            Incoming message;
            {
                QMutexLocker lock(&mutex);
                if (gen != generation.load()) return;
                if (inbox.isEmpty()) break;
                message = inbox.dequeue(); inboxBytes -= message.cost;
            }
            QJsonParseError parse;
            const auto json = QJsonDocument::fromJson(message.envelope, &parse);
            QVariantMap body;
            QString reason;
            const bool verified = connected && parse.error == QJsonParseError::NoError && json.isObject() && flatEnvelope(json.object()) &&
                owner->verifyEnvelope(json.object().toVariantMap(), &body, &reason) &&
                body.value("source_node").toString() != own.node &&
                message.topic == topic(body.value("source_node").toString());
            if (!verified) { ++rejected; continue; }
            auto provenance = body.value("_network").toMap();
            provenance["received_at_ms"] = message.receivedAt;
            provenance["received_tick_ms"] = message.receivedTick;
            body["_network"] = provenance;
            ++delivered;
            emit owner->messageReceived(body);
            if (!lifetime || gen != generation.load()) return;
        }
        bool pending;
        {
            QMutexLocker lock(&mutex);
            if (gen != generation.load()) return;
            pending = !controls.isEmpty() || !inbox.isEmpty();
            if (!pending) scheduled = false;
        }
        emit owner->statusChanged();
        if (!lifetime || gen != generation.load()) return;
        if (pending) schedule(gen);
    }

    static void onConnect(mosquitto *, void *opaque, int result) {
        auto *context = static_cast<Callback *>(opaque);
        if (context->generation != context->self->generation.load()) return;
        context->self->connected = false;
        context->self->control(context->generation, {Kind::Connected, result, 0});
    }
    static void onDisconnect(mosquitto *, void *opaque, int result) {
        auto *context = static_cast<Callback *>(opaque);
        if (context->generation != context->self->generation.load()) return;
        context->self->connected = false;
        context->self->control(context->generation, {Kind::Disconnected, result, 0});
    }
    static void onSubscribe(mosquitto *, void *opaque, int mid, int count, const int *granted) {
        auto *context = static_cast<Callback *>(opaque);
        bool accepted = count == 1 && granted && granted[0] == 0;
        context->self->control(context->generation, {Kind::Subscribed, accepted ? 0 : 1, mid});
    }
    static void onPublish(mosquitto *, void *opaque, int mid) {
        auto *context = static_cast<Callback *>(opaque);
        context->self->control(context->generation, {Kind::Published, 0, mid});
    }
    static void onMessage(mosquitto *, void *opaque, const mosquitto_message *message) {
        auto *context = static_cast<Callback *>(opaque);
        if (context->generation != context->self->generation.load()) return;
        context->self->incoming(context->generation, message, *context);
    }
};

TeamNetwork::TeamNetwork(QObject *parent) : QObject(parent), d(std::make_unique<Private>(this)) {}
TeamNetwork::~TeamNetwork() { blockSignals(true); stop(); }

bool TeamNetwork::start(const QVariantMap &config, QString *error) {
    return configure(config, true, error);
}

bool TeamNetwork::configureVerification(const QVariantMap &config, QString *error) {
    return configure(config, false, error);
}

bool TeamNetwork::configure(const QVariantMap &config, bool transport, QString *error) {
    if (error) error->clear();
    if (!d->ownThread(error)) return false;
    QPointer<TeamNetwork> lifetime(this);
    const auto expected = d->generation.load() + 1;
    stop();
    if (!lifetime || d->generation.load() != expected)
        return fail(error, QStringLiteral("Team start was superseded"));
    static const QSet<QString> configurationKeys{"team_id", "node_id", "robot_id", "robot_key", "context", "contract_version", "match_id", "epoch", "session_id",
        "endpoint", "ca_file", "certificate_file", "signing_key_file", "can_send", "can_aggregate", "heartbeat_ms", "timeout_ms", "peers"};
    for (auto it = config.cbegin(); it != config.cend(); ++it)
        if (!configurationKeys.contains(it.key()))
            return fail(error, QStringLiteral("Unknown team transport configuration key"));
    QString team, node, match, epoch, session, caFile, certificateFile, keyFile, endpoint, robotKey;
    qint64 robot = 0, heartbeat = 1000, timeout = 5000;
    qint64 version = 2;
    if (config.contains("contract_version") && !integer(config.value("contract_version"), 2, 3, &version))
        return fail(error, QStringLiteral("Unknown team signing contract version"));
    if (!transport && version != 3)
        return fail(error, QStringLiteral("Independent terminal-team verification requires schema3"));
    const bool identityValid = version == 3
        ? terminalRobot(config.value("robot_key"), &robotKey) && terminalContext(config.value("context")) && !config.contains("robot_id")
        : integer(config.value("robot_id"), 0, 4294967295LL, &robot) && !config.contains("robot_key") && !config.contains("context");
    bool send = false, aggregate = false;
    if (!plainString(config.value("team_id"), &team, true) || !plainString(config.value("node_id"), &node, true) ||
        !plainString(config.value("match_id"), &match, true) || !plainString(config.value("epoch"), &epoch, true) ||
        !plainString(config.value("session_id"), &session) || !identityValid ||
        !plainString(config.value("endpoint"), &endpoint) || !credentialPath(config.value("ca_file"), &caFile) ||
        !credentialPath(config.value("certificate_file"), &certificateFile) || !credentialPath(config.value("signing_key_file"), &keyFile) ||
        !flag(config, "can_send", &send) || !flag(config, "can_aggregate", &aggregate) ||
        (config.contains("heartbeat_ms") && !integer(config.value("heartbeat_ms"), 250, 10000, &heartbeat)) ||
        (config.contains("timeout_ms") && !integer(config.value("timeout_ms"), 750, 60000, &timeout)) || timeout < 3 * heartbeat)
        return fail(error, QStringLiteral("Invalid bounded team identity/credential/permission/heartbeat configuration"));
    const QUrl url(endpoint, QUrl::StrictMode);
    if (!url.isValid() || url.scheme() != "mqtts" || url.host().isEmpty() || url.port(version == 3 ? -1 : 8883) <= 0 ||
        url.port(8883) > 65535 || !url.userInfo().isEmpty() || !url.query().isEmpty() || !url.fragment().isEmpty() ||
        (!url.path().isEmpty() && url.path() != "/"))
        return fail(error, QStringLiteral("Team endpoint must be mqtts://host:port without credentials/path/query"));
    if (config.value("peers").metaType().id() != QMetaType::QVariantList || config.value("peers").toList().size() > MaxPeers)
        return fail(error, QStringLiteral("Team peers must list at most 15 other pinned nodes (16 members total)"));
    QByteArray caBytes;
    if (!readCredential(caFile, 2 * 1024 * 1024, &caBytes))
        return fail(error, QStringLiteral("Cannot read bounded team CA file"));
    Store trust(X509_STORE_new(), X509_STORE_free);
    if (!trust || X509_STORE_load_locations(trust.get(), QFile::encodeName(caFile).constData(), nullptr) != 1)
        return fail(error, QStringLiteral("Cannot load team CA trust"));
    Identity own;
    own.node = node; own.robot = robot; own.robotKey = robotKey; own.send = send; own.aggregate = aggregate;
    if (!loadIdentity(certificateFile, trust.get(), &own, error)) return false;
    Key signing;
    if (transport) {
        QByteArray privatePem;
        if (!readCredential(keyFile, 128 * 1024, &privatePem))
            return fail(error, QStringLiteral("Cannot read bounded private signing key"));
        {
            std::unique_ptr<BIO, decltype(&BIO_free)> bio(BIO_new_mem_buf(privatePem.constData(), int(privatePem.size())), BIO_free);
            if (bio) signing = Key(PEM_read_bio_PrivateKey(bio.get(), nullptr, noPassword, nullptr), EVP_PKEY_free);
        }
        OPENSSL_cleanse(privatePem.data(), size_t(privatePem.size()));
        privatePem.clear();
        if (!signing || X509_check_private_key(own.certificate.get(), signing.get()) != 1)
            return fail(error, QStringLiteral("Private signing key does not match the configured TLS certificate"));
    }
    QHash<QString, Identity> peers;
    QSet<QByteArray> publicKeys{own.publicDigest};
    for (const auto &value : config.value("peers").toList()) {
        if (value.metaType().id() != QMetaType::QVariantMap)
            return fail(error, QStringLiteral("Invalid team peer entry"));
        const auto entry = value.toMap();
        static const QSet<QString> peerKeys{"node_id", "robot_id", "robot_key", "certificate_file", "fingerprint", "can_send", "can_aggregate", "can_voice", "can_hear"};
        for (auto it = entry.cbegin(); it != entry.cend(); ++it)
            if (!peerKeys.contains(it.key()))
                return fail(error, QStringLiteral("Unknown team peer configuration key"));
        Identity peer;
        QString file, fingerprint;
        const bool peerIdentity = version == 3
            ? terminalRobot(entry.value("robot_key"), &peer.robotKey) && !entry.contains("robot_id")
            : integer(entry.value("robot_id"), 0, 4294967295LL, &peer.robot) && !entry.contains("robot_key");
        if (!plainString(entry.value("node_id"), &peer.node, true) || peer.node == node || peers.contains(peer.node) || !peerIdentity ||
            !credentialPath(entry.value("certificate_file"), &file) || !plainString(entry.value("fingerprint"), &fingerprint) ||
            !flag(entry, "can_send", &peer.send) || !flag(entry, "can_aggregate", &peer.aggregate) ||
            !flag(entry, "can_voice", &peer.voice) || !flag(entry, "can_hear", &peer.hear))
            return fail(error, QStringLiteral("Invalid or duplicate team peer identity/permissions"));
        if (!loadIdentity(file, trust.get(), &peer, error)) return false;
        fingerprint = fingerprint.toLower();
        if (fingerprint.size() != 64 || fingerprint != QString::fromLatin1(peer.publicDigest.toHex())
            || publicKeys.contains(peer.publicDigest))
            return fail(error, QStringLiteral("Peer SPKI public-key pin mismatches or a signing key is reused across nodes"));
        publicKeys.insert(peer.publicDigest);
        peers.insert(peer.node, std::move(peer));
    }
    if (transport && !initializeMosquitto()) return fail(error, QStringLiteral("Cannot initialize optional MQTT library"));
    d->team = team; d->match = match; d->epoch = epoch; d->session = session; d->endpoint = endpoint;
    d->version = int(version); d->rulesContext = config.value("context").toMap();
    const auto contextHash = QString::fromLatin1(QCryptographicHash::hash(
        QJsonDocument::fromVariant(d->rulesContext).toJson(QJsonDocument::Compact), QCryptographicHash::Sha256).toHex());
    d->prefix = version == 3 ? "rmclient/terminal-team/v3/" + team + "/" + match + "/" + epoch + "/" + contextHash + "/node/"
                            : "rmclient/v2/" + team + "/" + match + "/" + epoch + "/node/";
    d->own = std::move(own); d->signingKey = std::move(signing); d->trust = std::move(trust); d->peers = std::move(peers);
    d->heartbeatMs = int(heartbeat); d->timeoutMs = int(timeout);
    d->verificationOnly = !transport;
    if (!transport) {
        // Verification has no network identity/session of its own and cannot
        // sign or publish. It is deliberately independent of an optional
        // aggregation provider's sockets, counters and authentication flags.
        d->running = true; d->state = "verification-only"; d->error.clear();
        emit statusChanged();
        return lifetime && d->generation.load() == expected;
    }
    d->callback = std::make_unique<Private::Callback>();
    d->callback->self = d.get(); d->callback->generation = expected; d->callback->ownTopic = d->topic(node);
    for (auto it = d->peers.cbegin(); it != d->peers.cend(); ++it) d->callback->peerTopics.insert(d->topic(it.key()));
    const QByteArray clientId = "rmteam-" + QCryptographicHash::hash((team + "/" + node + "/" + session).toUtf8(), QCryptographicHash::Sha256).toHex().left(40);
    d->client = mosquitto_new(clientId.constData(), true, d->callback.get());
    if (!d->client) { stop(); return fail(error, QStringLiteral("Cannot allocate optional MQTT client")); }
    mosquitto_connect_callback_set(d->client, Private::onConnect);
    mosquitto_disconnect_callback_set(d->client, Private::onDisconnect);
    mosquitto_subscribe_callback_set(d->client, Private::onSubscribe);
    mosquitto_publish_callback_set(d->client, Private::onPublish);
    mosquitto_message_callback_set(d->client, Private::onMessage);
    int result = mosquitto_int_option(d->client, MOSQ_OPT_PROTOCOL_VERSION, MQTT_PROTOCOL_V311);
    if (result == MOSQ_ERR_SUCCESS) result = mosquitto_tls_set(d->client, QFile::encodeName(caFile).constData(), nullptr,
        QFile::encodeName(certificateFile).constData(), QFile::encodeName(keyFile).constData(), noPassword);
    if (result == MOSQ_ERR_SUCCESS) result = mosquitto_tls_opts_set(d->client, 1, "tlsv1.2", nullptr);
    if (result == MOSQ_ERR_SUCCESS) result = mosquitto_tls_insecure_set(d->client, false);
    if (result == MOSQ_ERR_SUCCESS) result = mosquitto_reconnect_delay_set(d->client, 1, 5, true);
    QHostAddress address;
    const QByteArray host = address.setAddress(url.host()) ? url.host().toUtf8() : QUrl::toAce(url.host());
    if (host.isEmpty()) result = MOSQ_ERR_INVAL;
    if (result == MOSQ_ERR_SUCCESS) result = mosquitto_connect_async(d->client, host.constData(), url.port(8883), 15);
    if (result == MOSQ_ERR_SUCCESS) {
        result = mosquitto_loop_start(d->client);
        d->loopStarted = result == MOSQ_ERR_SUCCESS;
    }
    if (result != MOSQ_ERR_SUCCESS) {
        stop();
        return fail(error, QStringLiteral("Cannot start strict team TLS/MQTT transport (%1)").arg(result));
    }
    d->running = true; d->state = "connecting"; d->error.clear();
    emit statusChanged();
    return lifetime && d->generation.load() == expected;
}

void TeamNetwork::stop() {
    if (QThread::currentThread() != thread()) {
        QMetaObject::invokeMethod(this, [this] { stop(); }, Qt::BlockingQueuedConnection);
        return;
    }
    ++d->generation;
    d->connected = false; d->running = false; d->verificationOnly = false;
    if (d->client) {
        mosquitto_disconnect(d->client);
        // Join before destroying the callback context or the owning QObject.
        if (d->loopStarted) mosquitto_loop_stop(d->client, true);
        mosquitto_destroy(d->client);
    }
    d->client = nullptr; d->loopStarted = false; d->callback.reset();
    d->signingKey.reset(); d->trust.reset(); d->peers.clear(); d->own = Identity{};
    d->subscriptions.clear(); d->outgoing.clear(); d->outgoingBytes = 0;
    d->state = "stopped"; d->error.clear();
    {
        QMutexLocker lock(&d->mutex);
        d->controls.clear(); d->inbox.clear(); d->rates.clear(); d->inboxBytes = 0; d->scheduled = false;
        d->received = d->delivered = d->dropped = d->rejected = d->published = 0;
    }
    emit statusChanged();
}

QVariantMap TeamNetwork::signedEnvelope(const QVariantMap &body, QString *error) const {
    if (error) error->clear();
    if (!d->ownThread(error) || !d->running || !d->signingKey) {
        fail(error, QStringLiteral("Team signing configuration is not active")); return {};
    }
    if (!d->bodyScope(body, d->own, error) || body.value("session_id").toString() != d->session ||
        !chainTrusted(d->own, d->trust.get())) {
        if (error && error->isEmpty()) *error = "Own signing session/certificate is invalid";
        return {};
    }
    const auto limit = body.value("kind").toString() == "team-view" ? ViewLimit : d->version == 3 ? TerminalSourceLimit : SourceLimit;
    const auto bytes = compact(body, limit, error);
    if (bytes.isEmpty()) return {};
    const auto data = signedBytes(bytes, d->topic(d->own.node), d->own.fingerprint, d->version);
    DigestContext context(EVP_MD_CTX_new(), EVP_MD_CTX_free);
    size_t length = 0;
    if (!context || !initSignature(context.get(), d->signingKey.get(), true) ||
        EVP_DigestSign(context.get(), nullptr, &length, reinterpret_cast<const unsigned char *>(data.constData()), size_t(data.size())) != 1 ||
        length == 0 || length > 8192) {
        fail(error, QStringLiteral("Cannot initialize node signature")); return {};
    }
    QByteArray signature(qsizetype(length), Qt::Uninitialized);
    if (EVP_DigestSign(context.get(), reinterpret_cast<unsigned char *>(signature.data()), &length,
        reinterpret_cast<const unsigned char *>(data.constData()), size_t(data.size())) != 1) {
        fail(error, QStringLiteral("Cannot sign node message")); return {};
    }
    signature.resize(qsizetype(length));
    return {{"schema", d->version}, {"signer", d->own.node}, {"certificate_sha256", d->own.fingerprint},
        {"algorithm", algorithm(d->signingKey.get())}, {"body_b64", QString::fromLatin1(bytes.toBase64())},
        {"signature_b64", QString::fromLatin1(signature.toBase64())}};
}

bool TeamNetwork::verifyEnvelope(const QVariantMap &envelope, QVariantMap *body, QString *error) const {
    if (error) error->clear();
    if (body) body->clear();
    if (!d->ownThread(error) || !d->running || !body)
        return fail(error, QStringLiteral("Team verification configuration/output is unavailable"));
    static const QSet<QString> keys{"schema", "signer", "certificate_sha256", "algorithm", "body_b64", "signature_b64"};
    if (envelope.size() != keys.size()) return fail(error, QStringLiteral("Invalid signed envelope fields"));
    for (auto it = envelope.cbegin(); it != envelope.cend(); ++it)
        if (!keys.contains(it.key())) return fail(error, QStringLiteral("Unknown signed envelope field"));
    QString signer;
    if (!integer(envelope.value("schema"), d->version, d->version) || !plainString(envelope.value("signer"), &signer, true))
        return fail(error, QStringLiteral("Invalid signed envelope schema/signer"));
    const auto *identity = d->identity(signer);
    if (!identity || !chainTrusted(*identity, d->trust.get()) ||
        envelope.value("certificate_sha256").metaType().id() != QMetaType::QString ||
        envelope.value("certificate_sha256").toString() != identity->fingerprint ||
        envelope.value("algorithm").metaType().id() != QMetaType::QString ||
        envelope.value("algorithm").toString() != algorithm(identity->key.get()))
        return fail(error, QStringLiteral("Unpinned, expired or mismatched sender certificate/algorithm"));
    QByteArray bytes, signature;
    if (!base64(envelope.value("body_b64"), ViewLimit, &bytes) ||
        !base64(envelope.value("signature_b64"), 8192, &signature))
        return fail(error, QStringLiteral("Invalid bounded canonical base64 envelope"));
    const auto signedData = signedBytes(bytes, d->topic(signer), identity->fingerprint, d->version);
    DigestContext context(EVP_MD_CTX_new(), EVP_MD_CTX_free);
    if (!context || !initSignature(context.get(), identity->key.get(), false) ||
        EVP_DigestVerify(context.get(), reinterpret_cast<const unsigned char *>(signature.constData()), size_t(signature.size()),
            reinterpret_cast<const unsigned char *>(signedData.constData()), size_t(signedData.size())) != 1)
        return fail(error, QStringLiteral("Invalid node message signature"));
    QJsonParseError parse;
    const auto json = QJsonDocument::fromJson(bytes, &parse);
    if (parse.error != QJsonParseError::NoError || !json.isObject())
        return fail(error, QStringLiteral("Signed body is not a JSON object"));
    auto decoded = json.object().toVariantMap();
    if (!d->bodyScope(decoded, *identity, error)) return false;
    const auto limit = decoded.value("kind").toString() == "team-view" ? ViewLimit : d->version == 3 ? TerminalSourceLimit : SourceLimit;
    qsizetype cost = 0; int nodes = 0;
    if (bytes.size() > limit || !jsonValue(decoded, 0, limit, &cost, &nodes))
        return fail(error, QStringLiteral("Signed body violates its kind/depth/size/type bound"));
    decoded.insert("_network", QVariantMap{{"authenticated", true}, {"sender_node", signer},
        {"fingerprint", QString::fromLatin1(identity->publicDigest.toHex())},
        {"certificate_sha256", identity->fingerprint}, {"proof", envelope},
        {"received_at_ms", QDateTime::currentMSecsSinceEpoch()}, {"received_tick_ms", receiveTick()}});
    *body = std::move(decoded);
    return true;
}

bool TeamNetwork::publish(const QVariantMap &body, QString *error) {
    const auto envelope = signedEnvelope(body, error);
    return !envelope.isEmpty() && publishEnvelope(envelope, error);
}

bool TeamNetwork::publishEnvelope(const QVariantMap &envelope, QString *error) {
    if (error) error->clear();
    if (!d->ownThread(error) || !d->client || !d->connected)
        return fail(error, QStringLiteral("Team transport is not connected/subscribed"));
    QVariantMap body;
    if (!verifyEnvelope(envelope, &body, error)) return false;
    if (body.value("source_node").toString() != d->own.node || body.value("session_id").toString() != d->session)
        return fail(error, QStringLiteral("Cannot forward another node's envelope or a retired own session"));
    const auto bytes = QJsonDocument(QJsonObject::fromVariantMap(envelope)).toJson(QJsonDocument::Compact);
    if (bytes.size() > EnvelopeLimit || d->outgoing.size() >= QueueMessages || d->outgoingBytes + bytes.size() > QueueBytes)
        return fail(error, QStringLiteral("Bounded team outbound queue is full"));
    int mid = 0;
    // QoS0 + non-retained prevents libmosquitto from replaying a QoS1 backlog
    // after reconnect. Aggregation owns signed sequence/lifetime/replay checks.
    const int result = mosquitto_publish(d->client, &mid, d->topic(d->own.node).constData(), int(bytes.size()), bytes.constData(), 0, false);
    if (result != MOSQ_ERR_SUCCESS) return fail(error, QStringLiteral("Team publish was not accepted (%1)").arg(result));
    d->outgoing.insert(mid, bytes.size()); d->outgoingBytes += bytes.size(); ++d->published;
    // Acceptance only queues bytes locally; it is not broker or peer receipt.
    return true;
}

QVariantMap TeamNetwork::details() const {
    if (!d->ownThread(nullptr)) return {{"active", false}, {"state", "wrong_thread"}};
    QMutexLocker lock(&d->mutex);
    return {{"active", d->running}, {"connected", d->connected.load()}, {"state", d->state}, {"error", d->error},
        {"verification_only", d->verificationOnly},
        {"team_id", d->team}, {"node_id", d->own.node}, {"robot_id", d->own.robot}, {"robot_key", d->own.robotKey},
        {"contract_version", d->version}, {"context", d->rulesContext}, {"topic_prefix", d->prefix}, {"match_id", d->match},
        {"epoch", d->epoch}, {"session_id", d->session}, {"endpoint", d->endpoint},
        {"fingerprint_kind", "sha256-spki-public-key"},
        {"own_fingerprint", QString::fromLatin1(d->own.publicDigest.toHex())},
        {"own_certificate_sha256", d->own.fingerprint},
        {"can_send", d->own.send}, {"can_aggregate", d->own.aggregate}, {"pinned_peers", d->peers.size()},
        {"heartbeat_ms", d->heartbeatMs}, {"timeout_ms", d->timeoutMs},
        {"tls_verify_peer", true}, {"tls_verify_hostname", true}, {"tls_minimum", "1.2"},
        {"certificate_revocation_checked", false}, {"measurement_verified", false}, {"clock_sync_verified", false},
        {"received", qulonglong(d->received)}, {"delivered", qulonglong(d->delivered)},
        {"rejected", qulonglong(d->rejected)}, {"dropped", qulonglong(d->dropped)}, {"published", qulonglong(d->published)},
        {"pending_messages", d->inbox.size()}, {"pending_bytes", d->inboxBytes},
        {"pending_outbound_messages", d->outgoing.size()}, {"pending_outbound_bytes", d->outgoingBytes},
        {"maximum_queue_messages", QueueMessages}, {"maximum_queue_bytes", QueueBytes},
        {"maximum_queued_per_peer", 2}, {"peer_rate_tokens_per_second", 20}, {"peer_burst_tokens", 8},
        {"source_body_limit", d->version == 3 ? TerminalSourceLimit : SourceLimit}, {"team_view_body_limit", ViewLimit}};
}
