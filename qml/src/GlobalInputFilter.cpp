#include "GlobalInputFilter.h"
#include <QSysInfo>

GlobalInputFilter::GlobalInputFilter(QObject *parent)
    : QObject(parent)
{
    connect(&m_longPressTimer, &QTimer::timeout, this, &GlobalInputFilter::checkLongPress);
    m_longPressTimer.setInterval(50);
    
    connect(&m_warpCheckTimer, &QTimer::timeout, this, &GlobalInputFilter::checkMousePosition);
    m_warpCheckTimer.setInterval(WARP_INTERVAL);
}

bool GlobalInputFilter::eventFilter(QObject *watched, QEvent *event)
{
    Q_UNUSED(watched);

    // 1. 处理鼠标事件 - 只在捕获模式下处理
    if (m_mouseCaptureEnabled) {
        if (event->type() == QEvent::MouseMove) {
            QMouseEvent *mouseEvent = static_cast<QMouseEvent*>(event);
            QPoint currentPos;
            
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
            currentPos = QPoint(mouseEvent->position().x(), mouseEvent->position().y());
#else
            currentPos = QPoint(mouseEvent->x(), mouseEvent->y());
#endif
            
            processMouseMove(currentPos);
            return true; // 捕获模式下，阻止事件继续传递
        }
        else if (event->type() == QEvent::MouseButtonPress) {
            QMouseEvent *mouseEvent = static_cast<QMouseEvent*>(event);
            QPoint pos;
            
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
            pos = QPoint(mouseEvent->position().x(), mouseEvent->position().y());
#else
            pos = QPoint(mouseEvent->x(), mouseEvent->y());
#endif
            
            emit mousePressed(mouseButtonToInt(mouseEvent->button()), pos.x(), pos.y());
            return true;
        }
        else if (event->type() == QEvent::MouseButtonRelease) {
            QMouseEvent *mouseEvent = static_cast<QMouseEvent*>(event);
            QPoint pos;
            
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
            pos = QPoint(mouseEvent->position().x(), mouseEvent->position().y());
#else
            pos = QPoint(mouseEvent->x(), mouseEvent->y());
#endif
            
            emit mouseReleased(mouseButtonToInt(mouseEvent->button()), pos.x(), pos.y());
            return true;
        }
        else if (event->type() == QEvent::Wheel) {
            QWheelEvent *wheelEvent = static_cast<QWheelEvent*>(event);
            int direction = wheelDirectionToInt(wheelEvent);
            int delta = wheelEvent->angleDelta().y();
            
            int x = 0, y = 0;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
            x = wheelEvent->position().x();
            y = wheelEvent->position().y();
#else
            x = wheelEvent->pos().x();
            y = wheelEvent->pos().y();
#endif
            
            emit mouseWheelScrolled(direction, delta, x, y);
            return true;
        }
    }

    // 2. 处理键盘事件 - 始终处理，不受捕获模式影响
    if (event->type() == QEvent::KeyPress) {
        QKeyEvent *keyEvent = static_cast<QKeyEvent*>(event);
        int key = keyEvent->key();
        
        // 检测I键切换捕获模式
        if (key == Qt::Key_I && !keyEvent->isAutoRepeat()) {
            setMouseCaptureEnabled(!m_mouseCaptureEnabled);
            // 仍然发出I键的信号，让上层可以处理
        }
        
        // 过滤重复触发的KeyPress
        if (keyEvent->isAutoRepeat()) {
            return false;
        }

        QString keyName = keyToName(key);
        QString text = keyEvent->text();
        QStringList comboKeys = getComboKeysList();

        // 记录所有按下的键
        m_pressedKeys.insert(key);

        // 所有按键都启动长按计时
        if (!m_keyPressTimers.contains(key)) {
            m_keyPressTimers[key] = QElapsedTimer();
            m_keyPressTimers[key].restart();
            m_longPressedKeys.remove(key);
            if (!m_longPressTimer.isActive()) {
                m_longPressTimer.start();
            }
            emit keyPressed(key, keyName, text, false, comboKeys);
        }
        
        // 返回 false 让事件继续传递，这样其他组件也能收到按键事件
        return false;
    }
    else if (event->type() == QEvent::KeyRelease) {
        QKeyEvent *keyEvent = static_cast<QKeyEvent*>(event);
        int key = keyEvent->key();
        
        // 过滤重复触发的KeyRelease
        if (keyEvent->isAutoRepeat()) {
            return false;
        }

        QString keyName = keyToName(key);
        QString text = keyEvent->text();
        
        // 移除已释放的键
        m_pressedKeys.remove(key);
        QStringList comboKeys = getComboKeysList();

        // 停止该按键的长按计时
        m_keyPressTimers.remove(key);
        m_longPressedKeys.remove(key);
        if (m_keyPressTimers.isEmpty()) {
            m_longPressTimer.stop();
        }

        emit keyReleased(key, keyName, text, comboKeys);
        
        // 返回 false 让事件继续传递
        return false;
    }

    return false;
}
void GlobalInputFilter::setMouseCaptureEnabled(bool enabled)
{
    if (m_mouseCaptureEnabled == enabled) return;
    
    m_mouseCaptureEnabled = enabled;
    
    if (enabled) {
        QWindow *mainWindow = getMainWindow();
        if (mainWindow) {
            QPoint center = mainWindow->geometry().center();
            QCursor::setPos(center);
            m_lastMousePos = center;
            m_accumulatedDelta = QPoint(0, 0);
            
            QGuiApplication::setOverrideCursor(Qt::BlankCursor);
            m_warpCheckTimer.start();
            //qDebug() << "鼠标捕获模式已开启";
        }
    } else {
        QGuiApplication::restoreOverrideCursor();
        m_warpCheckTimer.stop();
        m_isWarping = false;
        m_accumulatedDelta = QPoint(0, 0);
        //qDebug() << "鼠标捕获模式已关闭";
    }
    
    emit mouseCaptureEnabledChanged();
}

QWindow* GlobalInputFilter::getMainWindow()
{
    QObject *obj = parent();
    while (obj) {
        QQuickWindow *quickWindow = qobject_cast<QQuickWindow*>(obj);
        if (quickWindow) {
            return quickWindow;
        }
        if (obj->isWindowType()) {
            return qobject_cast<QWindow*>(obj);
        }
        obj = obj->parent();
    }
    
    QWindowList windows = QGuiApplication::topLevelWindows();
    for (QWindow *window : windows) {
        if (window->isVisible()) {
            return window;
        }
    }
    
    return nullptr;
}

void GlobalInputFilter::warpMouseToCenter()
{
    if (!m_mouseCaptureEnabled || m_isWarping) return;
    
    QWindow *mainWindow = getMainWindow();
    if (!mainWindow) return;
    
    m_isWarping = true;
    
    QPoint center = mainWindow->geometry().center();
    QCursor::setPos(center);
    m_lastMousePos = center;
    
    m_isWarping = false;
}

void GlobalInputFilter::processMouseMove(const QPoint &currentPos)
{
    if (!m_mouseCaptureEnabled) return;
    
    QWindow *mainWindow = getMainWindow();
    if (!mainWindow) return;
    
    QRect windowRect = mainWindow->geometry();
    
    if (m_isWarping) return;
    
    if (!m_lastMousePos.isNull()) {
        int deltaX = currentPos.x() - m_lastMousePos.x();
        int deltaY = currentPos.y() - m_lastMousePos.y();
        
        deltaX = qRound(deltaX * m_mouseSensitivity);
        deltaY = qRound(deltaY * m_mouseSensitivity);
        
        m_accumulatedDelta += QPoint(deltaX, deltaY);
        
        // 只发送相对位移信号
        emit mouseMovedRelative(deltaX, deltaY);
    }
    
    int margin = WARP_MARGIN;
    bool needWarp = false;
    
    if (currentPos.x() <= margin) {
        needWarp = true;
        m_accumulatedDelta.rx() += margin;
    } else if (currentPos.x() >= windowRect.width() - margin) {
        needWarp = true;
        m_accumulatedDelta.rx() -= margin;
    }
    
    if (currentPos.y() <= margin) {
        needWarp = true;
        m_accumulatedDelta.ry() += margin;
    } else if (currentPos.y() >= windowRect.height() - margin) {
        needWarp = true;
        m_accumulatedDelta.ry() -= margin;
    }
    
    if (needWarp) {
        warpMouseToCenter();
    } else {
        m_lastMousePos = currentPos;
    }
}

void GlobalInputFilter::checkMousePosition()
{
    if (!m_mouseCaptureEnabled) return;
    
    QWindow *mainWindow = getMainWindow();
    if (!mainWindow) return;
    
    QPoint globalPos = QCursor::pos();
    QRect windowRect = mainWindow->geometry();
    
    if (!windowRect.contains(globalPos)) {
        warpMouseToCenter();
    }
}

void GlobalInputFilter::checkLongPress()
{
    if (m_keyPressTimers.isEmpty()) {
        m_longPressTimer.stop();
        return;
    }

    QList<int> keys = m_keyPressTimers.keys();
    for (int key : keys) {
        QElapsedTimer &timer = m_keyPressTimers[key];
        if (timer.elapsed() >= m_longPressThreshold && !m_longPressedKeys.contains(key)) {
            QString keyName = keyToName(key);
            QString text = "";
            QStringList comboKeys = getComboKeysList();
            emit keyPressed(key, keyName, text, true, comboKeys);
            m_longPressedKeys.insert(key);
        }
    }
}

int GlobalInputFilter::wheelDirectionToInt(QWheelEvent *event)
{
    QPoint angleDelta = event->angleDelta();
    if (angleDelta.y() > 0) return 1;
    else if (angleDelta.y() < 0) return 2;
    if (angleDelta.x() > 0) return 3;
    else if (angleDelta.x() < 0) return 4;
    return 0;
}

QString GlobalInputFilter::keyToName(int key)
{
    switch (key) {
        case Qt::Key_Control: return "Ctrl";
        case Qt::Key_Shift: return "Shift";
        case Qt::Key_Alt: return "Alt";
        case Qt::Key_Meta: return (QSysInfo::productType() == "windows") ? "Win" : "Cmd";
        case Qt::Key_CapsLock: return "CapsLock";
        case Qt::Key_NumLock: return "NumLock";
        case Qt::Key_ScrollLock: return "ScrollLock";
        case Qt::Key_Escape: return "Escape";
        case Qt::Key_Tab: return "Tab";
        case Qt::Key_Backspace: return "Backspace";
        case Qt::Key_Enter: return "Enter";
        case Qt::Key_Return: return "Return";
        case Qt::Key_Space: return "Space";
        case Qt::Key_Insert: return "Insert";
        case Qt::Key_Delete: return "Delete";
        case Qt::Key_Home: return "Home";
        case Qt::Key_End: return "End";
        case Qt::Key_PageUp: return "PageUp";
        case Qt::Key_PageDown: return "PageDown";
        case Qt::Key_Up: return "↑";
        case Qt::Key_Down: return "↓";
        case Qt::Key_Left: return "←";
        case Qt::Key_Right: return "→";
        case Qt::Key_0: return "0";
        case Qt::Key_1: return "1";
        case Qt::Key_2: return "2";
        case Qt::Key_3: return "3";
        case Qt::Key_4: return "4";
        case Qt::Key_5: return "5";
        case Qt::Key_6: return "6";
        case Qt::Key_7: return "7";
        case Qt::Key_8: return "8";
        case Qt::Key_9: return "9";
        case Qt::Key_A: return "A";
        case Qt::Key_B: return "B";
        case Qt::Key_C: return "C";
        case Qt::Key_D: return "D";
        case Qt::Key_E: return "E";
        case Qt::Key_F: return "F";
        case Qt::Key_G: return "G";
        case Qt::Key_H: return "H";
        case Qt::Key_I: return "I";  // I键用于切换捕获模式
        case Qt::Key_J: return "J";
        case Qt::Key_K: return "K";
        case Qt::Key_L: return "L";
        case Qt::Key_M: return "M";
        case Qt::Key_N: return "N";
        case Qt::Key_O: return "O";
        case Qt::Key_P: return "P";
        case Qt::Key_Q: return "Q";
        case Qt::Key_R: return "R";
        case Qt::Key_S: return "S";
        case Qt::Key_T: return "T";
        case Qt::Key_U: return "U";
        case Qt::Key_V: return "V";
        case Qt::Key_W: return "W";
        case Qt::Key_X: return "X";
        case Qt::Key_Y: return "Y";
        case Qt::Key_Z: return "Z";
        case Qt::Key_F1: return "F1";
        case Qt::Key_F2: return "F2";
        case Qt::Key_F3: return "F3";
        case Qt::Key_F4: return "F4";
        case Qt::Key_F5: return "F5";
        case Qt::Key_F6: return "F6";
        case Qt::Key_F7: return "F7";
        case Qt::Key_F8: return "F8";
        case Qt::Key_F9: return "F9";
        case Qt::Key_F10: return "F10";
        case Qt::Key_F11: return "F11";
        case Qt::Key_F12: return "F12";
        case Qt::Key_Comma: return ",";
        case Qt::Key_Period: return ".";
        case Qt::Key_Slash: return "/";
        case Qt::Key_Backslash: return "\\";
        case Qt::Key_Semicolon: return ";";
        case Qt::Key_Apostrophe: return "'";
        case Qt::Key_Equal: return "=";
        case Qt::Key_Minus: return "-";
        case Qt::Key_QuoteLeft: return "`";
        case Qt::Key_AsciiTilde: return "~";
        case 0x5B: return "[";
        case 0x5D: return "]";
        
        default: return QString("Unknown(%1)").arg(key);
    }
}

bool GlobalInputFilter::isModifierKey(int key)
{
    return (key == Qt::Key_Control || key == Qt::Key_Shift || key == Qt::Key_Alt ||
            key == Qt::Key_Meta || key == Qt::Key_CapsLock || key == Qt::Key_NumLock ||
            key == Qt::Key_ScrollLock);
}

QStringList GlobalInputFilter::getComboKeysList()
{
    QStringList combo;
    if (m_pressedKeys.contains(Qt::Key_Control)) combo << "Ctrl";
    if (m_pressedKeys.contains(Qt::Key_Shift)) combo << "Shift";
    if (m_pressedKeys.contains(Qt::Key_Alt)) combo << "Alt";
    if (m_pressedKeys.contains(Qt::Key_Meta)) combo << (QSysInfo::productType() == "windows" ? "Win" : "Cmd");
    if (m_pressedKeys.contains(Qt::Key_CapsLock)) combo << "CapsLock";
    
    for (int key : m_pressedKeys) {
        if (!isModifierKey(key)) {
            combo << keyToName(key);
        }
    }
    
    return combo;
}

int GlobalInputFilter::mouseButtonToInt(Qt::MouseButton button)
{
    switch (button) {
    case Qt::LeftButton: return 1;
    case Qt::RightButton: return 2;
    case Qt::MiddleButton: return 3;
    default: return 0;
    }
}