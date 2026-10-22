#include "DecodedFramePool.h"
#include <QMutexLocker>
extern "C" {
#include <libavutil/buffer.h>
#include <libavutil/pixfmt.h>
}

DecodedFramePool::~DecodedFramePool() {
    for (auto *frame : m_frames)
        av_frame_free(&frame);
}

AVFrame *DecodedFramePool::acquire(int width, int height) {
    {
        QMutexLocker lock(&m_mutex);
        for (qsizetype i = m_frames.size(); i > 0; --i) {
            auto *frame = m_frames.at(i - 1);
            if (frame->width != width || frame->height != height)
                continue;
            m_frames.removeAt(i - 1);
            m_cachedBytes -= qsizetype(frame->buf[0]->size);
            ++m_reuses;
            return frame;
        }
    }
    auto *frame = av_frame_alloc();
    if (!frame)
        return nullptr;
    frame->format = AV_PIX_FMT_BGRA;
    frame->width = width;
    frame->height = height;
    if (av_frame_get_buffer(frame, 64) < 0) {
        av_frame_free(&frame);
        return nullptr;
    }
    QMutexLocker lock(&m_mutex);
    ++m_allocations;
    return frame;
}

void DecodedFramePool::release(AVFrame *frame) {
    if (!frame)
        return;
    QList<AVFrame *> retired;
    const qsizetype bytes = frame->buf[0] ? qsizetype(frame->buf[0]->size) : 0;
    {
        QMutexLocker lock(&m_mutex);
        if (bytes > 0 && bytes <= MaximumCachedBytes) {
            while (!m_frames.isEmpty() && (m_frames.size() >= MaximumCachedFrames ||
                   m_cachedBytes + bytes > MaximumCachedBytes)) {
                auto *old = m_frames.takeFirst();
                m_cachedBytes -= qsizetype(old->buf[0]->size);
                retired.append(old);
            }
            m_frames.append(frame);
            m_cachedBytes += bytes;
            frame = nullptr;
        }
    }
    // FFmpeg释放和分配都放在锁外，不让GUI归还像素时等待大块内存操作。
    for (auto *old : retired)
        av_frame_free(&old);
    av_frame_free(&frame);
}

QVariantMap DecodedFramePool::diagnostics() const {
    QMutexLocker lock(&m_mutex);
    return {{"output_buffer_allocations", m_allocations}, {"output_buffer_reuses", m_reuses},
            {"cached_output_buffers", m_frames.size()}, {"cached_output_bytes", m_cachedBytes},
            {"output_cache_limit_bytes", MaximumCachedBytes}};
}
