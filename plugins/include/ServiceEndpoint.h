#pragma once
#include <QObject>
#include <QVariantMap>

// 桥接、模型建议与语音共用的异步服务边界。
// 宿主只交换带版本的参数映射，不依赖具体 socket、模型或音频实现。
class ServiceEndpoint : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QVariantMap details READ details NOTIFY statusChanged)
public:
    using QObject::QObject;
    // 初始化端点。耗时任务应在后台或事件循环中推进，不能阻塞界面。
    virtual bool start(const QVariantMap &configuration, QString *error) = 0;
    // 停止当前会话，并使旧任务的回调失效。
    virtual void stop() = 0;
    // 提交消息是否成功接纳，不等于网络送达、模型正确或音频播放完成。
    virtual bool submit(const QVariantMap &message, QString *error) = 0;
    virtual QString status() const = 0;
    virtual QVariantMap details() const = 0;
signals:
    // 状态或诊断变化。接收者可以在回调中停止或销毁端点。
    void statusChanged();
    // 输出消息沿各自服务契约解释，不能自动转成机器人控制指令。
    void messageReceived(const QVariantMap &message);
    void errorOccurred(const QString &message);
};
