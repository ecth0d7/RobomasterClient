#ifndef GLOBALINPUTFILTER_H
#define GLOBALINPUTFILTER_H

#include <QObject>
#include <QEvent>
#include <QMouseEvent>
#include <QKeyEvent>
#include <QElapsedTimer>
#include <QSet>
#include <QTimer>
#include <QWheelEvent>
#include <QMap>
#include <QCursor>
#include <QWindow>
#include <QGuiApplication>
#include <QPoint>
#include <QDebug>
#include <QWindowList>
#include <QQuickWindow>

class GlobalInputFilter : public QObject
{
    Q_OBJECT
public:
    explicit GlobalInputFilter(QObject *parent = nullptr);

    // 重写事件过滤函数
    bool eventFilter(QObject *watched, QEvent *event) override;

    // 鼠标捕获模式属性
    Q_PROPERTY(bool mouseCaptureEnabled READ mouseCaptureEnabled WRITE setMouseCaptureEnabled NOTIFY mouseCaptureEnabledChanged)
    bool mouseCaptureEnabled() const { return m_mouseCaptureEnabled; }
    void setMouseCaptureEnabled(bool enabled);

    // 鼠标灵敏度属性
    Q_PROPERTY(double mouseSensitivity READ mouseSensitivity WRITE setMouseSensitivity NOTIFY mouseSensitivityChanged)
    double mouseSensitivity() const { return m_mouseSensitivity; }
    void setMouseSensitivity(double sensitivity) {
        if (sensitivity != m_mouseSensitivity) {
            m_mouseSensitivity = qBound(0.1, sensitivity, 5.0);
            emit mouseSensitivityChanged();
        }
    }

signals:
    // 鼠标事件信号（只保留相对位移信号）
    void mouseMovedRelative(int deltaX, int deltaY);
    void mousePressed(int button, int x, int y);
    void mouseReleased(int button, int x, int y);
    void mouseWheelScrolled(int direction, int delta, int x, int y);
    
    // 键盘事件信号（保持原样）
    void keyPressed(int key, const QString& keyName, const QString& text, bool isLongPress, const QStringList& comboKeys);
    void keyReleased(int key, const QString& keyName, const QString& text, const QStringList& comboKeys);
    
    // 属性变化信号
    void mouseCaptureEnabledChanged();
    void mouseSensitivityChanged();

private:
    // 工具函数
    int mouseButtonToInt(Qt::MouseButton button);
    QString keyToName(int key);
    bool isModifierKey(int key);
    void checkLongPress();
    int wheelDirectionToInt(QWheelEvent *event);
    QWindow* getMainWindow();
    void warpMouseToCenter();
    void processMouseMove(const QPoint &currentPos);
    QStringList getComboKeysList();

    // 长按相关变量（保持原样）
    int m_longPressThreshold = 500;
    QTimer m_longPressTimer;
    QMap<int, QElapsedTimer> m_keyPressTimers;
    QSet<int> m_longPressedKeys;

    // 组合键相关（保持原样）
    QSet<int> m_pressedKeys;
    
    // 鼠标捕获模式相关变量
    bool m_mouseCaptureEnabled = false;
    bool m_isWarping = false;
    double m_mouseSensitivity = 1.0;
    QPoint m_lastMousePos;
    QPoint m_accumulatedDelta;
    QTimer m_warpCheckTimer;
    static constexpr int WARP_MARGIN = 20;
    static constexpr int WARP_INTERVAL = 16;
    
    // 新增：用于检测I键的变量
    bool m_iKeyPressed = false;
    
private slots:
    void checkMousePosition();
};

#endif // GLOBALINPUTFILTER_H