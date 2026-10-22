#pragma once
#include <QByteArray>
#include <QString>
#include <optional>

namespace HeroLob {
// CustomByteBlock defines a byte limit, not a video envelope. Select the
// sender's format explicitly; the two layouts cannot be identified reliably.
enum class PacketFormat { AnnexBStream, CompactH264 };
enum class PacketStatus { Accepted, Duplicate, Invalid };
struct PacketResult {
    PacketStatus status = PacketStatus::Invalid;
    QByteArray bytes;
    bool discontinuity = false;
    QString error;
};

// Only framing and continuity live here. The bounded decoder owns Annex B
// assembly/SPS/PPS/IDR recovery; the host owns identity and deployment gating.
class PacketStream {
public:
    explicit PacketStream(PacketFormat format) : m_format(format) {}
    PacketResult receive(const QByteArray &packet);
    void reset();
    void setFormat(PacketFormat format);
private:
    PacketResult invalid(const QString &reason);
    PacketFormat m_format;
    std::optional<quint8> m_sequence;
    QByteArray m_lastPayload;
    bool m_lastReset = false;
    bool m_started = false;
};
}
