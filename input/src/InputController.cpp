#include "InputController.h"
#include "InputPolicy.h"
#include <QCursor>
#include <QGuiApplication>
#include <QDateTime>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QQuickItem>
#include <QWheelEvent>

InputController::InputController(QObject *parent) : InputEndpoint(parent) {
    m_motionClock.start();
    markMonitorSample();
    m_timer.setInterval(14); // 不超过 75 Hz，包括最后的中立键鼠包。
    m_timer.setTimerType(Qt::PreciseTimer);
    connect(&m_timer, &QTimer::timeout, this, &InputController::flush);
    m_timer.start();
    m_captureRetry.setInterval(250);
    connect(&m_captureRetry,&QTimer::timeout,this,[this]{
        if(!m_captureDesired || !m_enabled || !m_connected || !m_window || !m_window->isActive() || editingText()) {
            m_captureRetry.stop();return;
        }
        acquireCapture();
    });
}
void InputController::markMonitorSample() {
    m_monitorAtMs = QDateTime::currentMSecsSinceEpoch();
    ++m_monitorSequence;
}
QVariantMap InputController::monitorSnapshot() const {
    const QString captureState = !captureAvailable() ? QStringLiteral("unavailable")
        : m_captureDesired && (!m_connected || !m_enabled || !m_window->isActive()) ? QStringLiteral("paused")
        : !m_connected || !m_enabled ? QStringLiteral("blocked")
        : m_captured ? QStringLiteral("captured")
        : !m_captureFailure.isEmpty() ? QStringLiteral("failed")
        : m_captureDesired ? QStringLiteral("paused") : QStringLiteral("released");
    const QString reason = !captureAvailable() ? QStringLiteral("当前窗口平台不支持鼠标抓取及回中；可替换输入插件")
        : !m_connected ? QStringLiteral("官方选手端连接未就绪")
        : !m_enabled ? QStringLiteral("捕获暂挂：面板关闭且窗口激活后自动恢复，捕获快捷键彻底退出")
        : !m_captureFailure.isEmpty() ? m_captureFailure
        : m_captured ? QStringLiteral("捕获已开启；面板临时释放，关闭后自动恢复；捕获快捷键彻底退出，Esc打开设置")
        : m_captureDesired ? QStringLiteral("持续捕获已开启，等待窗口激活／显示或结束文本编辑后恢复；捕获快捷键彻底退出")
        : QStringLiteral("Ctrl+Shift+I 或点击捕获；I/O保留为角色补弹面板入口");
    return {{"version",1},{"source_kind","local_input"},{"source_id","input.qt"},{"validation","observed_local"},
            {"sampled_at_ms",m_monitorAtMs},{"sequence",m_monitorSequence},{"enabled",m_enabled},
            {"capture_desired",m_captureDesired},{"keyboard_order",m_keyboard.order()},{"capture_state",captureState},{"capture_reason",reason},{"capture_available",captureAvailable()},
            {"submission_state",!m_submissionKnown ? "idle" : m_submissionAccepted ? "submitted" : "rejected"},
            {"keyboard_value",m_keyboard.mask()},{"left_button_down",m_left},{"right_button_down",m_right},
            {"mid_button_down",m_middle},{"last_trigger",m_lastTrigger},{"trigger_at_ms",m_triggerAtMs},
            {"axis_basis","qt_screen_delta"},{"screen_dx",m_x},{"screen_dy",m_y},
            {"motion_at_ms",m_motionAtMs},{"wheel_delta",m_z},{"wheel_at_ms",m_wheelAtMs}};
}
void InputController::setConnected(bool connected) {
    m_connected = connected;
    if (!connected) {
        releaseCapture();
        markMonitorSample();
        emit stateChanged();
    } else {
        markMonitorSample();
        QPointer<InputController> alive(this);
        emit stateChanged();
        if(alive)scheduleResume();
    }
}
InputController::~InputController() {
    blockSignals(true);
    m_timer.stop();
    m_captureRetry.stop();
    attach(nullptr);
}
void InputController::attach(QWindow *window) {
    auto *next = qobject_cast<QQuickWindow *>(window);
    if (next == m_window) {
        scheduleResume();
        return;
    }
    // Replacing/recreating a window is a temporary interruption, just like a
    // panel. Only the explicit capture toggle clears the operator's intent.
    ++m_resumeRevision;
    releaseCapture();
    if (m_window)
        m_window->removeEventFilter(this);
    disconnect(m_windowDestroyed);
    disconnect(m_windowActive);
    disconnect(m_windowFocus);
    m_window = next;
    if (m_window) {
        m_window->installEventFilter(this);
        m_windowActive=connect(m_window,&QWindow::activeChanged,this,[this]{
            if(m_window && m_window->isActive())scheduleResume();
        });
        m_windowFocus=connect(m_window,&QQuickWindow::activeFocusItemChanged,this,[this]{scheduleResume();});
        m_windowDestroyed = connect(m_window, &QObject::destroyed, this, [this] {
            const bool sendNeutral = m_captured || m_dirty || m_requestPending;
            m_window = nullptr;
            m_captured = false;
            ++m_resumeRevision;
            m_captureRetry.stop();
            m_mouseGrabbed = m_keyboardGrabbed = false;
            clearInput(sendNeutral);
            QPointer<InputController> lifetime(this);
            const auto requestId = m_requestId;
            markMonitorSample();
            emit stateChanged();
            if (!lifetime || requestId != m_requestId)
                return;
            emit helpVisibilityRequested(false);
        });
    }
    QPointer<InputController> alive(this);
    markMonitorSample();
    emit stateChanged();
    if (alive) scheduleResume();
}
void InputController::setEnabled(bool enabled) {
    if (enabled == m_enabled)
        return;
    m_enabled = enabled;
    if (!enabled) {
        releaseCapture();
        QPointer<InputController> lifetime(this);
        markMonitorSample();
        emit stateChanged();
        if (!lifetime || m_enabled != enabled)
            return;
    }
    QPointer<InputController> lifetime(this);
    emit enabledChanged();
    if (lifetime && enabled) {
        markMonitorSample();
        emit stateChanged();
        if(lifetime)scheduleResume();
    }
}
bool InputController::editingText() const {
    if (!m_window)
        return false;
    auto *focus = m_window->activeFocusItem();
    return focus && focus->isVisible() && focus->isEnabled() && (focus->inherits("QQuickTextInput") || focus->inherits("QQuickTextEdit"));
}
bool InputController::captureAvailable() const {
    // Absolute cursor recentering is not a relative-pointer implementation on Wayland.
    const auto platform = QGuiApplication::platformName();
    return m_window && (platform == QLatin1String("xcb") || platform == QLatin1String("windows")
                        || platform == QLatin1String("cocoa"));
}
bool InputController::captureReady() const {
    return captureAvailable() && m_enabled && m_connected && m_window->isActive()
        && m_window->isExposed() && editingText() == false;
}
bool InputController::requestMouseCapture(bool captured) {
    m_captureDesired=captured;
    ++m_resumeRevision;
    m_captureFailure.clear();
    if (!captured) {
        releaseCapture();
        emit stateChanged();
        return true;
    }
    // Record explicit intent even while a panel temporarily disables actual grab.
    if(!captureAvailable()) {
        m_captureFailure=QStringLiteral("当前平台不支持此鼠标捕获实现");
        emit stateChanged();return false;
    }
    if (!captureReady()) {
        QPointer<InputController> alive(this);
        markMonitorSample();
        emit stateChanged();
        if (alive) scheduleResume();
        return true;
    }
    return acquireCapture();
}
void InputController::suspendMouseCapture() {
    releaseCapture();
    QPointer<InputController> alive(this);
    emit stateChanged();
    if(alive)scheduleResume(100);
}
void InputController::scheduleResume(int delayMs) {
    if(!m_captureDesired)return;
    const auto revision=++m_resumeRevision;
    QTimer::singleShot(delayMs,this,[this,revision]{
        if(revision==m_resumeRevision && m_captureDesired && !m_captured)acquireCapture();
    });
}
bool InputController::acquireCapture() {
    if(!m_captureDesired)return false;
    if (m_captured) return true;
    if (!captureReady()) {
        // Activation and exposure are separate events. A window may already be
        // active when a modal closes/fullscreen changes, but not exposed yet.
        // Keep a bounded retry instead of losing that one resume opportunity.
        if (captureAvailable() && m_enabled && m_connected && m_window->isActive() && !editingText())
            m_captureRetry.start();
        return false;
    }
    m_captureFailure.clear();
    m_restorePosition = QCursor::pos();
    m_restoreCursor = m_window->cursor();
    if (!m_window->setMouseGrabEnabled(true)) {
        m_captureFailure = QStringLiteral("平台拒绝鼠标抓取；未启动控制输入");
        m_captureRetry.start();
        markMonitorSample();
        emit stateChanged();
        return false;
    }
    m_mouseGrabbed = true;
    // Mouse grab is mandatory. Keyboard input remains bounded by the active window
    // even on platforms that do not implement the optional keyboard grab.
    m_keyboardGrabbed = m_window->setKeyboardGrabEnabled(true);
    clearInput(false);
    m_captured = true;
    m_captureRetry.stop();
    m_window->setCursor(Qt::BlankCursor);
    QCursor::setPos(m_window->mapToGlobal(QPoint(m_window->width()/2, m_window->height()/2)));
    markMonitorSample();
    emit stateChanged();
    return true;
}
void InputController::releaseCapture() {
    if (m_releasingCapture) return;
    m_releasingCapture = true;
    m_captureRetry.stop();
    const bool wasCaptured = m_captured;
    m_captured = false;
    if (m_window) {
        if (m_mouseGrabbed) m_window->setMouseGrabEnabled(false);
        if (m_keyboardGrabbed) m_window->setKeyboardGrabEnabled(false);
        if (wasCaptured) {
            m_window->setCursor(m_restoreCursor);
            if (m_window->isActive()) QCursor::setPos(m_restorePosition);
        }
    }
    m_mouseGrabbed = m_keyboardGrabbed = false;
    // 仅退役真实捕获或重试尚未送达的中立包；普通界面切换不能凭空上传键鼠消息。
    clearInput(wasCaptured || m_dirty || m_requestPending);
    m_releasingCapture = false;
}
void InputController::clearInput(bool sendNeutral) {
    ++m_requestId;
    m_requestPending = false;
    m_keyboard.clear();
    m_left = m_right = m_middle = false;
    m_motion.clear();
    m_submissionKnown = false;
    m_fractionX = m_fractionY = 0;
    m_x = m_y = m_z = 0;
    m_motionAtMs = m_wheelAtMs = m_triggerAtMs = 0;
    m_lastTrigger.clear();
    markMonitorSample();
    m_dirty = sendNeutral;
}
void InputController::setMouseSensitivityPercent(int percent) {
    if (percent < 25 || percent > 200 || percent == m_sensitivity) return;
    // 比例变化释放捕获及旧请求，不能按新比例续发之前积累的移动／小数余量。
    m_sensitivity = percent;
    releaseCapture();
    QPointer<InputController> alive(this);
    emit stateChanged();
    if (alive) {emit sensitivityChanged();if(alive)scheduleResume();}
}
bool InputController::eventFilter(QObject *, QEvent *event) {
    if (event->type() == QEvent::Resize && m_captured) {
        // Recenter only after Qt has applied the new geometry. Otherwise a
        // fullscreen/maximize resize can turn cursor warping into control delta.
        releaseCapture();
        QPointer<InputController> alive(this);
        emit stateChanged();
        if (alive) scheduleResume();
        return false;
    }
    if(event->type()==QEvent::Expose || event->type()==QEvent::WindowActivate
        || event->type()==QEvent::Show || event->type()==QEvent::FocusIn) scheduleResume();
    if (event->type() == QEvent::WindowDeactivate || event->type() == QEvent::FocusOut
        || event->type() == QEvent::Hide) {
        releaseCapture();
        QPointer<InputController> lifetime(this);
        const auto requestId = m_requestId;
        emit stateChanged();
        if (!lifetime || requestId != m_requestId)
            return false;
        emit helpVisibilityRequested(false);
        if(lifetime)scheduleResume(100);
        return false;
    }
    if ((event->type() == QEvent::UngrabMouse || event->type() == QEvent::UngrabKeyboard)
        && m_captured && !m_releasingCapture) {
        releaseCapture();
        QPointer<InputController> alive(this);
        emit stateChanged();
        if(alive)scheduleResume(100);
        return false;
    }
    if (event->type() == QEvent::ShortcutOverride) {
        auto *key = static_cast<QKeyEvent *>(event);
        if (m_captured && key->key() == Qt::Key_Escape) {
            // Suppress the host menu shortcut here; open the menu on KeyPress.
            // Opening it during ShortcutOverride would deliver the same Escape
            // to the new panel and immediately close it again.
            key->accept();
            return true;
        }
        const auto modifiers = key->modifiers();
        const bool uiChord = modifiers.testFlag(Qt::ControlModifier)
            && (modifiers.testFlag(Qt::ShiftModifier) || modifiers.testFlag(Qt::AltModifier));
        if (m_captured && !uiChord && InputPolicy::keyBit(key->key())) {
            key->accept();
            return true;
        }
        return false;
    }
    if (event->type() == QEvent::KeyPress || event->type() == QEvent::KeyRelease) {
        const auto *key = static_cast<QKeyEvent *>(event);
        const bool pressed = event->type() == QEvent::KeyPress;
        if (key->isAutoRepeat()) return m_captured && InputPolicy::keyBit(key->key());
        if (!pressed) {
            QPointer<InputController> lifetime(this);
            emit keyReleased(key->key()); // Holds release even after opening a modal disables input.
            if (!lifetime) return false;
        }
        if (pressed && key->key() == Qt::Key_Escape && m_captured) {
            releaseCapture();QPointer<InputController> alive(this);emit stateChanged();if(alive)emit captureMenuRequested();
            return true;
        }
        if (m_enabled && m_captured && !editingText()) {
            const auto bit = InputPolicy::keyBit(key->key());
            const auto modifiers = key->modifiers();
            const bool uiChord = modifiers.testFlag(Qt::ControlModifier)
                && (modifiers.testFlag(Qt::ShiftModifier) || modifiers.testFlag(Qt::AltModifier));
            // Chords reserved for UI may not become robot movement. Releases still
            // clear a bit pressed before a modifier was added.
            if (!bit || (pressed && uiChord)) return false;
            if (!m_keyboard.update(key->key(), pressed)) return true;
            if (pressed) {
                m_lastTrigger = InputPolicy::keyLabel(key->key());
                m_triggerAtMs = QDateTime::currentMSecsSinceEpoch();
            }
            m_dirty = true;
            markMonitorSample();
            emit stateChanged();
            return true;
        }
        return false;
    }
    if (!m_enabled || !m_captured || !m_window)
        return false;
    if (event->type() == QEvent::MouseMove) {
        const auto *mouse = static_cast<QMouseEvent *>(event);
        const QPoint center(m_window->width() / 2, m_window->height() / 2);
        const QPoint delta = mouse->position().toPoint() - center;
        if (!delta.isNull()) {
            const qint64 x = qint64(delta.x()) * m_sensitivity + m_fractionX;
            const qint64 y = qint64(delta.y()) * m_sensitivity + m_fractionY;
            const qint64 dx = x / 100, dy = y / 100;
            m_fractionX = x % 100; m_fractionY = y % 100;
            m_x = int(qBound(qint64(-32768), dx, qint64(32767)));
            m_y = int(qBound(qint64(-32768), dy, qint64(32767)));
            m_motion.add(dx, dy, 0, m_motionClock.elapsed());
            m_dirty = true;
            m_motionAtMs = QDateTime::currentMSecsSinceEpoch();
            QCursor::setPos(m_window->mapToGlobal(center));
            markMonitorSample();
            emit stateChanged();
        }
        return true;
    }
    if (event->type() == QEvent::MouseButtonPress || event->type() == QEvent::MouseButtonDblClick
        || event->type() == QEvent::MouseButtonRelease) {
        const auto button = static_cast<QMouseEvent *>(event)->button();
        const bool down = event->type() != QEvent::MouseButtonRelease;
        if (button == Qt::LeftButton)
            m_left = down;
        if (button == Qt::RightButton)
            m_right = down;
        if (button == Qt::MiddleButton)
            m_middle = down;
        if (down && (button == Qt::LeftButton || button == Qt::RightButton || button == Qt::MiddleButton)) {
            m_lastTrigger = button == Qt::LeftButton ? QStringLiteral("鼠标左键")
                : button == Qt::RightButton ? QStringLiteral("鼠标右键") : QStringLiteral("鼠标中键");
            m_triggerAtMs = QDateTime::currentMSecsSinceEpoch();
        }
        m_dirty = true;
        markMonitorSample();
        emit stateChanged();
        return true;
    }
    if (event->type() == QEvent::Wheel) {
        m_z = static_cast<QWheelEvent *>(event)->angleDelta().y();
        m_motion.add(0, 0, m_z, m_motionClock.elapsed());
        m_wheelAtMs = QDateTime::currentMSecsSinceEpoch();
        m_dirty = true;
        markMonitorSample();
        emit stateChanged();
        return true;
    }
    return false;
}
void InputController::flush() {
    if (!m_connected || m_requestPending)
        return;
    if (m_captured && editingText()) {
        releaseCapture();
        QPointer<InputController> lifetime(this);
        const auto requestId = m_requestId;
        emit stateChanged();
        if (!lifetime || requestId != m_requestId || !m_connected || m_requestPending)
            return;
    }
    if (!m_dirty && !m_captured)
        return;
    const auto motion = m_motion.take(m_motionClock.elapsed());
    // Retire movement before emitting: a replaceable host may complete later or
    // reenter with a new input event. Neither failure nor reentrancy replays it.
    m_dirty = false;
    m_requestPending = true;
    emit inputReady(++m_requestId, {{"mouse_x", motion.x},
                                    {"mouse_y", -motion.y},
                                    {"mouse_z", motion.z},
                                    {"keyboard_value", m_keyboard.mask()},
                                    {"left_button_down", m_left},
                                    {"right_button_down", m_right},
                                    {"mid_button_down", m_middle}});
}
void InputController::completeSend(quint64 requestId, bool accepted) {
    if (!m_requestPending || requestId != m_requestId)
        return;
    m_requestPending = false;
    // Retry current held/neutral state; expired or rejected motion is never
    // added back. A successful local submission is not a robot execution ACK.
    if (!accepted) m_dirty = true;
    const bool changed = !m_submissionKnown || m_submissionAccepted != accepted;
    m_submissionKnown = true;
    m_submissionAccepted = accepted;
    if (changed) {
        markMonitorSample();
        emit stateChanged();
    }
}
