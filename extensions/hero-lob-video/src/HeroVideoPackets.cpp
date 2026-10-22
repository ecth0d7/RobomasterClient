#include "HeroVideoPackets.h"

// Independently implemented from the published wire layouts:
// github.com/wele0612/Pacific_doorlock_sniper (consecutive H.264 bytes)
// github.com/dkjsiogu/minimal_hik_gimbal_bridge (compact 300-byte envelope).
namespace HeroLob {
void PacketStream::reset() {
    m_sequence.reset();
    m_lastPayload.clear();
    m_lastReset = false;
    m_started = false;
}
void PacketStream::setFormat(PacketFormat format) {
    m_format = format;
    reset();
}
PacketResult PacketStream::invalid(const QString &reason) {
    reset();
    return {PacketStatus::Invalid, {}, true, reason};
}
PacketResult PacketStream::receive(const QByteArray &packet) {
    if (packet.isEmpty() || packet.size() > 300)
        return invalid(QStringLiteral("CustomByteBlock视频数据需为1至300字节"));
    if (m_format == PacketFormat::AnnexBStream) {
        const bool first = !m_started;
        m_started = true;
        // Equal raw chunks may be distinct consecutive pieces of the stream.
        // ROS sequence_id is not part of the official MQTT bytes field.
        return {PacketStatus::Accepted, packet, first, {}};
    }
    if (packet.size() != 300)
        return invalid(QStringLiteral("紧凑视频分片需恰好300字节"));
    const auto flags = quint8(packet.at(0));
    if (flags & 0xfc)
        return invalid(QStringLiteral("紧凑视频分片保留位必须为0"));
    const int size = int(quint8(packet.at(2))) + ((flags & 2) ? 256 : 0);
    if (size > 297)
        return invalid(QStringLiteral("紧凑视频净荷不能超过297字节"));
    const auto sequence = quint8(packet.at(1));
    const bool restart = (flags & 1) != 0;
    const auto payload = packet.mid(3, size);
    if (!restart && m_sequence && sequence == *m_sequence) {
        // Padding has no video meaning. An explicit reset is always honored:
        // this envelope has no generation ID to distinguish two equal resets.
        if (payload == m_lastPayload && !m_lastReset)
            return {PacketStatus::Duplicate, {}, false, {}};
        return invalid(QStringLiteral("同一视频序号出现不同内容，等待重新同步"));
    }
    const bool gap = m_sequence && sequence != quint8(*m_sequence + 1);
    const bool discontinuity = !m_started || restart || gap;
    m_started = true;
    m_sequence = sequence;
    m_lastPayload = payload;
    m_lastReset = restart;
    return {PacketStatus::Accepted, payload, discontinuity, {}};
}
}
