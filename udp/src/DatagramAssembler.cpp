#include "DatagramAssembler.h"
#include <QtEndian>
#include <algorithm>
#include <cstring>
#include <utility>

void DatagramAssembler::reset() {
    m_chunks.clear();
    m_haveNext = false;
    m_gapSince = -1;
    m_recentCount = m_recentNext = 0;
}

void DatagramAssembler::rememberFrame(quint16 frame) {
    if (recentlyFinished(frame)) return;
    m_recentFrames[m_recentNext] = frame;
    m_recentNext = (m_recentNext + 1) % RecentFrameCount;
    m_recentCount = std::min(m_recentCount + 1, RecentFrameCount);
}

bool DatagramAssembler::recentlyFinished(quint16 frame) const {
    return std::find(m_recentFrames.begin(), m_recentFrames.begin() + m_recentCount, frame) !=
           m_recentFrames.begin() + m_recentCount;
}

void DatagramAssembler::invalidate() {
    ++m_discontinuities;
    for (auto it = m_chunks.cbegin(); it != m_chunks.cend(); ++it) rememberFrame(it.key());
    m_chunks.clear();
    m_haveNext = false;
    m_gapSince = -1;
}

void DatagramAssembler::refreshGap(qint64 nowMs) {
    const auto current = m_chunks.constFind(m_nextChunk);
    if (m_chunks.isEmpty() || (current != m_chunks.cend() && current->complete()) ||
        (m_chunks.size() == 1 && current != m_chunks.cend())) {
        m_gapSince = -1;
    } else if (m_gapSince < 0) {
        m_gapSince = nowMs;
    }
}

qint64 DatagramAssembler::nextDeadlineMs() const {
    if (!m_haveNext || m_chunks.isEmpty()) return -1;
    const auto current = m_chunks.constFind(m_nextChunk);
    if (current != m_chunks.cend() && current->complete()) return -1;
    qint64 deadline = current == m_chunks.cend() ? -1 : current->started + FragmentTimeoutMs;
    if (m_gapSince >= 0 && (deadline < 0 || m_gapSince + ReorderWaitMs < deadline))
        deadline = m_gapSince + ReorderWaitMs;
    return deadline;
}

void DatagramAssembler::advancePastGap() {
    ++m_discontinuities;
    rememberFrame(m_nextChunk);
    m_chunks.remove(m_nextChunk);
    quint16 distance = 0xffff;
    for (auto it = m_chunks.cbegin(); it != m_chunks.cend(); ++it)
        distance = std::min(distance, quint16(it.key() - m_nextChunk));
    m_nextChunk = quint16(m_nextChunk + (distance == 0xffff ? 1 : distance));
    m_gapSince = -1;
}

bool DatagramAssembler::expire(qint64 nowMs) {
    bool changed = false;
    qint64 deadline;
    while ((deadline = nextDeadlineMs()) >= 0 && nowMs >= deadline) {
        advancePastGap();
        changed = true;
        refreshGap(nowMs);
    }
    return changed;
}

std::optional<QByteArray> DatagramAssembler::takeReady(qint64 nowMs) {
    expire(nowMs);
    auto current = m_chunks.find(m_nextChunk);
    if (current == m_chunks.end() || !current->complete()) return {};
    QByteArray result = std::move(current->bytes);
    m_chunks.erase(current);
    m_lastDelivered = m_nextChunk;
    rememberFrame(m_nextChunk++);
    refreshGap(nowMs);
    return result;
}

std::optional<QByteArray> DatagramAssembler::push(const QByteArray &packet, qint64 nowMs) {
    expire(nowMs);
    if (packet.size() <= 8 || packet.size() > MaxDatagramBytes) {
        invalidate();
        return {};
    }
    const auto *header = reinterpret_cast<const uchar *>(packet.constData());
    const auto frame = qFromBigEndian<quint16>(header);
    const auto fragment = qFromBigEndian<quint16>(header + 2);
    const auto size = qFromBigEndian<quint32>(header + 4);
    const qsizetype payload = packet.size() - 8;
    if (!size || size > MaxFrameBytes || quint32(payload) > size) {
        invalidate();
        rememberFrame(frame);
        return {};
    }
    if (recentlyFinished(frame)) return takeReady(nowMs);
    if (!m_haveNext) {
        m_haveNext = true;
        m_nextChunk = frame;
    }
    const quint16 distance = quint16(frame - m_nextChunk);
    if (distance >= 0x8000) return takeReady(nowMs);
    if (distance >= WindowChunks) {
        // 只保留三个传输块；大跳号说明已失去实时性，不积压到下一个关键帧。
        invalidate();
        m_haveNext = true;
        m_nextChunk = frame;
    }
    auto &chunk = m_chunks[frame];
    if (!chunk.expected) {
        chunk.expected = size;
        chunk.started = nowMs;
        chunk.bytes.reserve(int(size));
    }
    if (chunk.expected != size) {
        invalidate(); rememberFrame(frame); return {};
    }
    const char *data = packet.constData() + 8;
    if (quint32(fragment) < chunk.nextFragment) {
        const auto &span = chunk.spans.at(fragment);
        if (span.length != payload || std::memcmp(chunk.bytes.constData() + span.offset, data, size_t(payload))) {
            invalidate(); rememberFrame(frame); return {};
        }
        ++m_duplicates;
    } else if (auto found = chunk.future.constFind(fragment); found != chunk.future.cend()) {
        if (found->size() != payload || std::memcmp(found->constData(), data, size_t(payload))) {
            invalidate(); rememberFrame(frame); return {};
        }
        ++m_duplicates;
    } else {
        if (chunk.received + quint32(payload) > size) {
            invalidate(); rememberFrame(frame); return {};
        }
        chunk.received += quint32(payload);
        if (quint32(fragment) == chunk.nextFragment) {
            chunk.spans.append({chunk.bytes.size(), payload});
            chunk.bytes.append(data, payload);
            ++chunk.nextFragment;
        } else {
            ++m_reordered;
            chunk.future.insert(fragment, QByteArray(data, payload));
        }
        while (chunk.nextFragment <= 0xffff) {
            auto next = chunk.future.find(quint16(chunk.nextFragment));
            if (next == chunk.future.end()) break;
            chunk.spans.append({chunk.bytes.size(), next->size()});
            chunk.bytes.append(*next);
            chunk.future.erase(next);
            ++chunk.nextFragment;
        }
    }
    refreshGap(nowMs);
    return takeReady(nowMs);
}
