#pragma once
#include "InputEndpoint.h"
#include "InputPolicy.h"
#include <QQuickWindow>
#include <QPointer>
#include <QTimer>
#include <QVariantMap>
#include <QCursor>
#include <QStringList>
#include <QElapsedTimer>

class InputController : public InputEndpoint {
    Q_OBJECT
    Q_PROPERTY(int mouseSensitivityPercent READ mouseSensitivityPercent WRITE setMouseSensitivityPercent NOTIFY sensitivityChanged)
    // 可选绘制快照留在具体插件上，不改变InputEndpoint的虚接口／旧插件ABI。
    Q_PROPERTY(QVariantMap monitorSnapshot READ monitorSnapshot NOTIFY stateChanged)
    Q_PROPERTY(bool captureDesired READ captureDesired NOTIFY stateChanged)
public:
    explicit InputController(QObject *parent = nullptr);
    void setConnected(bool connected) override;
    void completeSend(quint64 requestId, bool accepted) override;
    void attach(QWindow *window) override;
    ~InputController() override;
    bool eventFilter(QObject *, QEvent *) override;
    int mouseSensitivityPercent() const { return m_sensitivity; }
    void setMouseSensitivityPercent(int percent);
    QVariantMap monitorSnapshot() const;
    // Optional Qt input capability; keep the replaceable InputEndpoint vtable unchanged.
    Q_INVOKABLE bool requestMouseCapture(bool captured);
    Q_INVOKABLE void suspendMouseCapture();
    bool captureDesired() const { return m_captureDesired; }
signals:
    void sensitivityChanged();
    void keyReleased(int key);
    void captureMenuRequested();
public:
    bool enabled() const override {
        return m_enabled;
    }
    void setEnabled(bool enabled) override;
    bool mouseCaptureEnabled() const override {
        return m_captured;
    }
    int mouseX() const override {
        return m_x;
    }
    int mouseY() const override {
        return m_y;
    }
    int mouseZ() const override {
        return m_z;
    }
    bool leftButtonDown() const override {
        return m_left;
    }
    bool rightButtonDown() const override {
        return m_right;
    }
    bool middleButtonDown() const override {
        return m_middle;
    }
    QString keyText() const override {
        return QString("0x%1").arg(m_keyboard.mask(), 4, 16, QLatin1Char('0'));
    }
    QString wheelText() const override {
        return QString::number(m_z);
    }

private:
    bool captureAvailable() const;
    bool acquireCapture();
    void scheduleResume(int delayMs = 0);
    bool captureReady() const;
    void clearInput(bool sendNeutral);
    void releaseCapture();
    void flush();
    bool editingText() const;
    void markMonitorSample();
    QPointer<QQuickWindow> m_window;
    QMetaObject::Connection m_windowDestroyed;
    QMetaObject::Connection m_windowActive, m_windowFocus;
    QTimer m_timer;
    QTimer m_captureRetry;
    bool m_enabled = false, m_captured = false, m_dirty = false;
    bool m_captureDesired = false;
    quint64 m_resumeRevision = 0;
    bool m_mouseGrabbed = false, m_keyboardGrabbed = false, m_releasingCapture = false;
    QString m_captureFailure;
    QPoint m_restorePosition;
    QCursor m_restoreCursor;
    bool m_left = false, m_right = false, m_middle = false;
    InputPolicy::PressedKeys m_keyboard;
    int m_x = 0, m_y = 0, m_z = 0;
    InputPolicy::MotionQueue m_motion;
    QElapsedTimer m_motionClock;
    qint64 m_fractionX = 0, m_fractionY = 0;
    int m_sensitivity = 100;
    bool m_connected = false, m_requestPending = false;
    quint64 m_requestId = 0;
    bool m_submissionKnown = false, m_submissionAccepted = false;
    qint64 m_monitorAtMs = 0, m_motionAtMs = 0, m_wheelAtMs = 0, m_triggerAtMs = 0;
    quint64 m_monitorSequence = 0;
    QString m_lastTrigger;
};
