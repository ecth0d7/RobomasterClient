#pragma once
#include <QByteArray>
#include <optional>

// 自动模式只根据同一候选序列中的参数集确认编码，不根据任意切片字节猜测。
class AnnexBCodecProbe {
public:
    enum class Codec { Unknown, H264, Hevc };
    struct Detection { Codec codec; QByteArray bootstrap; };
    std::optional<Detection> observe(const QByteArray &bytes, Codec active);
    void reset();
    qsizetype retainedBytes() const { return m_bytes.size(); }
private:
    static constexpr qsizetype RetainedBytes = 256 * 1024;
    void compact();
    QByteArray m_bytes;
    qsizetype m_scanned = 0, m_candidateStart = -1;
    Codec m_candidate = Codec::Unknown;
    bool m_sps = false;
};
