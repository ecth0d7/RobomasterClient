#pragma once
#include <QObject>
#include <QWindow>
#include <QVariantMap>

class InputEndpoint : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool mouseCaptureEnabled READ mouseCaptureEnabled NOTIFY stateChanged)
    Q_PROPERTY(int mouseX READ mouseX NOTIFY stateChanged)
    Q_PROPERTY(int mouseY READ mouseY NOTIFY stateChanged)
    Q_PROPERTY(int mouseZ READ mouseZ NOTIFY stateChanged)
    Q_PROPERTY(bool leftButtonDown READ leftButtonDown NOTIFY stateChanged)
    Q_PROPERTY(bool rightButtonDown READ rightButtonDown NOTIFY stateChanged)
    Q_PROPERTY(bool middleButtonDown READ middleButtonDown NOTIFY stateChanged)
    Q_PROPERTY(QString keyText READ keyText NOTIFY stateChanged)
    Q_PROPERTY(QString wheelText READ wheelText NOTIFY stateChanged)
public:
    using QObject::QObject;
    virtual void attach(QWindow *window) = 0;
    virtual void setConnected(bool connected) = 0;
    virtual void completeSend(quint64 requestId, bool accepted) = 0;
    virtual bool enabled() const = 0;
    virtual void setEnabled(bool enabled) = 0;
    virtual bool mouseCaptureEnabled() const = 0;
    virtual int mouseX() const = 0;
    virtual int mouseY() const = 0;
    virtual int mouseZ() const = 0;
    virtual bool leftButtonDown() const = 0;
    virtual bool rightButtonDown() const = 0;
    virtual bool middleButtonDown() const = 0;
    virtual QString keyText() const = 0;
    virtual QString wheelText() const = 0;
signals:
    void enabledChanged();
    void stateChanged();
    void shortcutRequested(int key);
    void helpVisibilityRequested(bool visible);
    void inputReady(quint64 requestId, const QVariantMap &fields);
};
