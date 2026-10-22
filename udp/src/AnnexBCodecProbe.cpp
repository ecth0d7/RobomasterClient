#include "AnnexBCodecProbe.h"
#include <algorithm>

void AnnexBCodecProbe::reset() {
    m_bytes.clear(); m_scanned = 0; m_candidateStart = -1;
    m_candidate = Codec::Unknown; m_sps = false;
}

std::optional<AnnexBCodecProbe::Detection> AnnexBCodecProbe::observe(const QByteArray &bytes, Codec active) {
    m_bytes.append(bytes);
    for (qsizetype i = m_scanned; i + 2 < m_bytes.size(); ++i) {
        const auto *b = reinterpret_cast<const unsigned char *>(m_bytes.constData());
        if (b[i] || b[i + 1]) continue;
        const int prefix = b[i + 2] == 1 ? 3 : i + 3 < m_bytes.size() && !b[i + 2] && b[i + 3] == 1 ? 4 : 0;
        if (!prefix) continue;
        const qsizetype header = i + prefix;
        // H.264 SPS头需要profile/constraint/level；保留不完整的头等待后续传输块。
        if (header + 4 > m_bytes.size()) { m_scanned = i; compact(); return {}; }
        const auto type264 = b[header] & 31;
        const auto type265 = (b[header] >> 1) & 63;
        const bool valid265 = !(b[header] & 0x81) && !(b[header + 1] & 0xf8) && (b[header + 1] & 7);
        const auto profile = b[header + 1];
        static constexpr unsigned char profiles[]{44,66,77,83,86,88,100,110,118,122,128,134,135,138,139,244};
        const bool valid264Sps = !(b[header] & 0x80) && (b[header] & 0x60) && type264 == 7 &&
            std::find(std::begin(profiles), std::end(profiles), profile) != std::end(profiles) && !(b[header + 2] & 3);
        if (valid264Sps) {
            m_candidate = Codec::H264; m_candidateStart = i; m_sps = true;
        } else if (valid265 && type265 == 32) {
            m_candidate = Codec::Hevc; m_candidateStart = i; m_sps = false;
        } else if (valid265 && type265 == 33) {
            if (m_candidate != Codec::Hevc || m_sps) m_candidateStart = i;
            m_candidate = Codec::Hevc; m_sps = true;
        }
        const bool pps264 = !(b[header] & 0x80) && (b[header] & 0x60) && type264 == 8;
        const bool confirmed = m_sps && ((m_candidate == Codec::H264 && pps264) ||
            (m_candidate == Codec::Hevc && valid265 && type265 == 34));
        if (confirmed) {
            if (m_candidate != active) {
                Detection result{m_candidate, m_bytes.mid(m_candidateStart)};
                reset();
                return result;
            }
            m_candidate = Codec::Unknown;
            m_candidateStart = -1;
            m_sps = false;
        }
        i = header;
    }
    m_scanned = std::max<qsizetype>(0, m_bytes.size() - 7);
    compact();
    return {};
}

void AnnexBCodecProbe::compact() {
    const qsizetype keep = m_candidateStart >= 0 ? RetainedBytes : 7;
    if (m_bytes.size() > keep) {
        const auto removed = m_bytes.size() - keep;
        m_bytes.remove(0, removed);
        m_scanned = std::max<qsizetype>(0, m_scanned - removed);
        m_candidateStart -= removed;
        if (m_candidateStart < 0) { m_candidate = Codec::Unknown; m_sps = false; }
    }
}
