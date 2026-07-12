#include "HeroProtocol.h"

#include <QtEndian>
#include <cstring>

namespace {

quint16 u16le(const char *p) { return qFromLittleEndian<quint16>(p); }
quint32 u32le(const char *p) { return qFromLittleEndian<quint32>(p); }

float f32le(const char *p)
{
    const quint32 bits = u32le(p);
    float value = 0.0f;
    static_assert(sizeof(value) == sizeof(bits));
    std::memcpy(&value, &bits, sizeof(value));
    return value;
}

} // namespace

namespace HeroProtocol {

quint16 crc16Mcrf4xx(const char *data, int size)
{
    quint16 crc = 0xFFFF;
    for (int i = 0; i < size; ++i) {
        crc ^= static_cast<quint8>(data[i]);
        for (int bit = 0; bit < 8; ++bit)
            crc = (crc & 1U) ? static_cast<quint16>((crc >> 1U) ^ 0x8408U)
                             : static_cast<quint16>(crc >> 1U);
    }
    return crc;
}

bool parseTelemetry(const QByteArray &p, QVariantMap &out)
{
    if (p.size() != TelemetrySize || static_cast<quint8>(p[0]) != 0x5A
        || static_cast<quint8>(p[1]) != 0x01)
        return false;
    if (crc16Mcrf4xx(p.constData(), 44) != u16le(p.constData() + 44))
        return false;

    const quint8 modeForce = static_cast<quint8>(p[5]);
    const quint16 flags = u16le(p.constData() + 6);
    out["seq"] = u16le(p.constData() + 2);
    out["proto_ver"] = static_cast<quint8>(p[4]);
    out["mode"] = modeForce & 0x0F;
    out["force_deploy"] = (modeForce & 0x10) != 0;
    out["flags"] = flags;
    out["core_ok"] = (flags & (1U << 0)) != 0;
    out["radar_fresh"] = (flags & (1U << 1)) != 0;
    out["radar_hold"] = (flags & (1U << 2)) != 0;
    out["deploy_solved"] = (flags & (1U << 3)) != 0;
    out["yaw_converged"] = (flags & (1U << 4)) != 0;
    out["fire_allowed"] = (flags & (1U << 5)) != 0;
    out["phase_full_adjust"] = (flags & (1U << 6)) != 0;
    out["trim_active"] = (flags & (1U << 7)) != 0;
    out["solver_status"] = (flags >> 8) & 0x07;
    out["trim_at_limit"] = (flags & (1U << 11)) != 0;
    out["distance_m"] = f32le(p.constData() + 8);
    out["height_m"] = f32le(p.constData() + 12);
    out["bullet_speed_rx"] = f32le(p.constData() + 16);
    out["solver_v0"] = f32le(p.constData() + 20);
    out["tof_s"] = f32le(p.constData() + 24);
    out["pitch_trim_deg"] = f32le(p.constData() + 28);
    out["pitch_meas_deg"] = f32le(p.constData() + 32);
    out["yaw_err_deg"] = f32le(p.constData() + 36);
    out["pitch_err_deg"] = f32le(p.constData() + 40);
    return true;
}

QByteArray makeCommand(quint16 sequence, quint8 command, qint8 parameter)
{
    QByteArray p(CommandSize, '\0');
    qToLittleEndian<quint16>(0xA55A, p.data());
    qToLittleEndian<quint16>(sequence, p.data() + 2);
    p[4] = static_cast<char>(command);
    p[5] = static_cast<char>(parameter);
    qToLittleEndian<quint16>(crc16Mcrf4xx(p.constData(), 12), p.data() + 12);
    return p;
}

} // namespace HeroProtocol
