#pragma once
#include <QList>
#include <QMutex>
#include <QVariantMap>
extern "C" {
#include <libavutil/frame.h>
}

// 每个解码端点独立持有；QImage的最后一个引用可以在UI线程或端点退出后归还帧。
class DecodedFramePool final {
public:
    ~DecodedFramePool();
    AVFrame *acquire(int width, int height);
    void release(AVFrame *frame);
    QVariantMap diagnostics() const;
private:
    static constexpr qsizetype MaximumCachedBytes = 64 * 1024 * 1024;
    static constexpr qsizetype MaximumCachedFrames = 3;
    mutable QMutex m_mutex;
    QList<AVFrame *> m_frames;
    qsizetype m_cachedBytes = 0;
    quint64 m_allocations = 0, m_reuses = 0;
};
