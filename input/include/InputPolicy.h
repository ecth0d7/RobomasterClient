#pragma once
#include <Qt>
#include <QString>
#include <QStringList>
namespace InputPolicy {
inline QString keyLabel(int key) {
    if (key == Qt::Key_Shift) return QStringLiteral("Shift");
    if (key == Qt::Key_Control) return QStringLiteral("Ctrl");
    if (key >= Qt::Key_A && key <= Qt::Key_Z) return QString(QChar(key));
    return {};
}
inline unsigned keyBit(int key) {
    const int keys[] = {Qt::Key_W, Qt::Key_S, Qt::Key_A, Qt::Key_D, Qt::Key_Shift, Qt::Key_Control,
                        Qt::Key_Q, Qt::Key_E, Qt::Key_R, Qt::Key_F, Qt::Key_G,     Qt::Key_Z,
                        Qt::Key_X, Qt::Key_C, Qt::Key_V, Qt::Key_B};
    for (unsigned i = 0; i < 16; ++i)
        if (keys[i] == key)
            return 1u << i;
    return 0;
}
// The wire mask has a fixed official order; the HUD follows physical press
// order. Keep both representations together so release/repress cannot diverge.
class PressedKeys {
public:
    unsigned mask() const { return m_mask; }
    const QStringList &order() const { return m_order; }
    bool update(int key, bool pressed) {
        const unsigned bit = keyBit(key);
        if (!bit || bool(m_mask & bit) == pressed) return false;
        const auto label = keyLabel(key);
        if (pressed) {
            m_mask |= bit;
            m_order.append(label);
        } else {
            m_mask &= ~bit;
            m_order.removeAll(label);
        }
        return true;
    }
    void clear() { m_mask = 0; m_order.clear(); }
private:
    unsigned m_mask = 0;
    QStringList m_order;
};

struct Motion {
    int x = 0, y = 0, z = 0; // Qt screen Y; inversion belongs at the wire boundary.
};

// Movement is a short-lived delta, whereas held keys/buttons are current state.
// Take each batch once, including when a submission fails: replaying old mouse
// motion after a stall makes the robot respond to an obsolete operator action.
class MotionQueue {
public:
    static constexpr qint64 LifetimeMs = 100;
    void add(qint64 x, qint64 y, qint64 z, qint64 now) {
        expire(now);
        if (!(x || y || z)) return;
        if (m_started < 0) m_started = now;
        m_motion.x = bounded(m_motion.x, x, -32768, 32767);
        // -screenY must also fit the protocol's signed 16-bit range.
        m_motion.y = bounded(m_motion.y, y, -32767, 32768);
        m_motion.z = bounded(m_motion.z, z, -32768, 32767);
    }
    Motion take(qint64 now) {
        expire(now);
        const auto motion = m_motion;
        clear();
        return motion;
    }
    void clear() { m_motion = {}; m_started = -1; }
private:
    static int bounded(int current, qint64 delta, int minimum, int maximum) {
        // Bound before adding, without losing cancellation against current.
        const auto limited = qBound(qint64(minimum) - current, delta, qint64(maximum) - current);
        return current + int(limited);
    }
    void expire(qint64 now) {
        if (m_started >= 0 && (now < m_started || now - m_started >= LifetimeMs)) clear();
    }
    Motion m_motion;
    qint64 m_started = -1;
};
inline bool isPanelShortcut(int key) {
    return key == Qt::Key_H || key == Qt::Key_P || key == Qt::Key_Tab || key == Qt::Key_QuoteLeft;
}
} // InputPolicy 命名空间
