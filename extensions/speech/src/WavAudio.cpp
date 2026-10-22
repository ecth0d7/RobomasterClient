#include "WavAudio.h"
#include <QIODevice>
#include <QtEndian>
#include <cmath>
#include <algorithm>

bool WavAudio::inspect(QIODevice &input, QVariantMap *details) {
    if (details)
        details->clear();
    const auto size = input.size();
    if (size < 44 || size > 8 * 1024 * 1024 || !input.seek(0))
        return false;
    const auto header = input.read(12);
    if (!header.startsWith("RIFF") || header.mid(8, 4) != "WAVE" ||
        quint64(qFromLittleEndian<quint32>(header.constData() + 4)) + 8 != quint64(size))
        return false;
    qint64 position = 12;
    bool formatSeen = false, dataSeen = false;
    quint32 rate = 0, dataBytes = 0;
    qint64 dataOffset = 0;
    quint16 channels = 0, bits = 0, alignment = 0;
    for (int chunk = 0; chunk < 64 && position + 8 <= size; ++chunk) {
        if (!input.seek(position))
            return false;
        const auto block = input.read(8);
        if (block.size() != 8)
            return false;
        const quint32 length = qFromLittleEndian<quint32>(block.constData() + 4);
        const qint64 next = position + 8 + qint64(length) + (length & 1);
        if (next > size)
            return false;
        if (block.startsWith("fmt ")) {
            if (formatSeen || length < 16 || length > 40)
                return false;
            formatSeen = true;
            const auto format = input.read(16);
            if (format.size() != 16 || qFromLittleEndian<quint16>(format.constData()) != 1)
                return false;
            channels = qFromLittleEndian<quint16>(format.constData() + 2);
            rate = qFromLittleEndian<quint32>(format.constData() + 4);
            alignment = qFromLittleEndian<quint16>(format.constData() + 12);
            bits = qFromLittleEndian<quint16>(format.constData() + 14);
            if (channels < 1 || channels > 2 || rate < 8000 || rate > 96000 ||
                (bits != 8 && bits != 16 && bits != 24 && bits != 32) ||
                alignment != channels * (bits / 8) ||
                qFromLittleEndian<quint32>(format.constData() + 8) != rate * alignment)
                return false;
        } else if (block.startsWith("data")) {
            if (dataSeen || !length)
                return false;
            dataSeen = true;
            dataBytes = length;
            dataOffset = position + 8;
        }
        position = next;
    }
    if (position != size || !formatSeen || !dataSeen || dataBytes % alignment ||
        quint64(dataBytes) > quint64(rate) * alignment * 60)
        return false;
    if (details)
        *details = {{"format", "pcm"},
                    {"sample_rate", rate},
                    {"channels", channels},
                    {"bit_depth", bits},
                    {"frames", dataBytes / alignment},
                    {"data_offset", dataOffset}, {"data_bytes", dataBytes},
                    {"duration_ms", 1000.0 * dataBytes / alignment / rate}};
    return true;
}
bool WavAudio::attenuate(QByteArray *samples, int bits, int percent) {
    if (!samples || percent < 0 || percent > 100 ||
        (bits != 8 && bits != 16 && bits != 24 && bits != 32) || samples->size() % (bits / 8))
        return false;
    if (percent == 100) return true;
    char *data = samples->data();
    for (qsizetype i = 0; i < samples->size(); i += bits / 8) {
        qint64 value = 0;
        if (bits == 8) value = quint8(data[i]) - 128;
        else if (bits == 16) value = qFromLittleEndian<qint16>(data + i);
        else if (bits == 32) value = qFromLittleEndian<qint32>(data + i);
        else {
            const quint32 raw = quint8(data[i]) | quint32(quint8(data[i+1])) << 8 | quint32(quint8(data[i+2])) << 16;
            value = raw >= 0x800000 ? qint64(raw) - 0x1000000 : raw;
        }
        value = value * percent / 100; // qint64防止32位样本乘100溢出；零增益保持无符号PCM的128中心。
        if (bits == 8) data[i] = char(value + 128);
        else if (bits == 16) qToLittleEndian<qint16>(qint16(value), data + i);
        else if (bits == 32) qToLittleEndian<qint32>(qint32(value), data + i);
        else {
            const quint32 raw = quint32(value) & 0xffffff;
            data[i] = char(raw); data[i+1] = char(raw >> 8); data[i+2] = char(raw >> 16);
        }
    }
    return true;
}
QByteArray WavAudio::alertTone(bool urgent) {
    constexpr int rate = 16000, frames = 2560;
    QByteArray result(44 + frames * 2, '\0');
    char *data = result.data();
    std::copy_n("RIFF",4,data); qToLittleEndian<quint32>(result.size()-8,data+4);
    std::copy_n("WAVEfmt ",8,data+8); qToLittleEndian<quint32>(16,data+16);
    qToLittleEndian<quint16>(1,data+20); qToLittleEndian<quint16>(1,data+22);
    qToLittleEndian<quint32>(rate,data+24); qToLittleEndian<quint32>(rate*2,data+28);
    qToLittleEndian<quint16>(2,data+32); qToLittleEndian<quint16>(16,data+34);
    std::copy_n("data",4,data+36); qToLittleEndian<quint32>(frames*2,data+40);
    for (int i = 0; i < frames; ++i) {
        const double envelope = std::min(1.0, std::min(i, frames-1-i) / 320.0);
        const auto sample = qint16(10000 * envelope * std::sin(2 * 3.141592653589793 * (urgent ? 880 : 660) * i / rate));
        qToLittleEndian<qint16>(sample,data+44+i*2);
    }
    return result;
}
