#pragma once
#include <QByteArray>
#include <QMap>
#include <QVector>
#include <array>
#include <optional>

// 固定8字节大端头：块序号u16、分片序号u16、整块字节数u32。
// 块可以切开或合并编码访问单元，画面边界仍由FFmpeg解析器判断。
class DatagramAssembler {
public:
    static constexpr quint32 MaxFrameBytes = 4 * 1024 * 1024;
    static constexpr qsizetype MaxDatagramBytes = 65535;
    static constexpr qint64 ReorderWaitMs = 20;
    std::optional<QByteArray> push(const QByteArray &packet, qint64 nowMs);
    std::optional<QByteArray> takeReady(qint64 nowMs);
    bool expire(qint64 nowMs);
    qint64 nextDeadlineMs() const;
    quint64 discontinuityCount() const noexcept { return m_discontinuities; }
    quint64 reorderedFragments() const noexcept { return m_reordered; }
    quint64 duplicateFragments() const noexcept { return m_duplicates; }
    quint16 lastDeliveredChunk() const noexcept { return m_lastDelivered; }
    void reset();

private:
    static constexpr qint64 FragmentTimeoutMs = 250;
    static constexpr quint16 WindowChunks = 3;
    static constexpr std::size_t RecentFrameCount = 64;
    struct Span { qsizetype offset, length; };
    struct Chunk {
        QByteArray bytes;
        QMap<quint16, QByteArray> future;
        QVector<Span> spans;
        quint32 expected = 0, received = 0, nextFragment = 0;
        qint64 started = 0;
        bool complete() const { return quint32(bytes.size()) == expected; }
    };
    void rememberFrame(quint16 frame);
    bool recentlyFinished(quint16 frame) const;
    void invalidate();
    void advancePastGap();
    void refreshGap(qint64 nowMs);
    QMap<quint16, Chunk> m_chunks;
    quint16 m_nextChunk = 0, m_lastDelivered = 0;
    bool m_haveNext = false;
    qint64 m_gapSince = -1;
    quint64 m_discontinuities = 0, m_reordered = 0, m_duplicates = 0;
    std::array<quint16, RecentFrameCount> m_recentFrames{};
    std::size_t m_recentCount = 0, m_recentNext = 0;
};
