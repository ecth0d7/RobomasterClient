#include "PluginContext.h"
#include "PluginPackageRuntime.h"
#include <QMap>
#include <QPointer>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlError>
#include <QTimer>
#include <QThread>
#include <QUuid>
#include <QUrl>
#include <utility>
#include <exception>

struct PluginContext::Private {
    struct Subscription { QString channel; QJSValue callback; };
    QPointer<PluginPackageRuntime> runtime;
    QString id;
    QVariantMap manifest, configuration;
    QPointer<QQmlEngine> engine;
    QPointer<QQmlContext> context;
    QPointer<QObject> nativeSession;
    QList<QPointer<QObject>> objects;
    QList<QPointer<QObject>> observationSources;
    QMap<QString, Subscription> subscriptions;
    QMap<QString, QPointer<QTimer>> timers;
    qulonglong servicesRevision = 1;
    bool active = true;
};
PluginContext::PluginContext(PluginPackageRuntime *runtime, QQmlEngine *source, QString id,
                             QVariantMap manifest, QVariantMap configuration)
    : QObject(runtime), d(std::make_unique<Private>()) {
    d->runtime = runtime; d->id = std::move(id); d->manifest = std::move(manifest); d->configuration = std::move(configuration);
    // Deliberately do not inherit the application's root context: a package
    // receives only pluginContext and the services its manifest declares.
    d->engine = new QQmlEngine(this);
    if (source) d->engine->setImportPathList(source->importPathList());
    connect(d->engine, &QQmlEngine::warnings, this, [this](const QList<QQmlError> &warnings) {
        if (!d->active || warnings.isEmpty()) return;
        QStringList messages;
        for (const auto &warning : warnings) messages.append(warning.toString());
        emit errorOccurred(messages.join('\n').left(1024));
    });
    d->context = new QQmlContext(d->engine, this);
    d->context->setContextProperty("pluginContext", this);
    d->context->setBaseUrl(QUrl::fromLocalFile(d->manifest.value("_directory").toString() + '/'));
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
}
PluginContext::~PluginContext() {
    dispose();
    // At process/engine teardown DeferredDelete may no longer run. Destroy
    // owned QML objects while their private engine still exists.
    const auto objects = d->objects;
    for (const auto &object : objects) if (object) delete object.data();
    if (d->context) delete d->context.data();
    if (d->engine) delete d->engine.data();
}
QString PluginContext::packageId() const { return d->id; }
QString PluginContext::packageDirectory() const { return d->manifest.value("_directory").toString(); }
QVariantMap PluginContext::configuration() const { return d->configuration; }
bool PluginContext::active() const { return d->active; }
qulonglong PluginContext::servicesRevision() const { return d->servicesRevision; }
QQmlContext *PluginContext::qmlContext() const { return d->context; }
bool PluginContext::declares(const QString &group, const QString &direction, const QString &name) const {
    return d->manifest.value(group).toMap().value(direction).toList().contains(name);
}
QObject *PluginContext::service(const QString &name) const {
    return QThread::currentThread() == thread() && d->active && d->runtime
        ? d->runtime->resolve(const_cast<PluginContext *>(this), name) : nullptr;
}
bool PluginContext::startNative(ExtensionPackagePlugin *factory, QString *error) {
    const auto reject = [error](const QString &message) {
        if (error) *error = message.left(1024);
        return false;
    };
    if (QThread::currentThread() != thread() || !d->active || !factory || d->nativeSession)
        return reject(QStringLiteral("Native package context is inactive or already started"));
    QPointer<PluginContext> alive(this);
    try {
        auto *object = factory->create(this, this);
        if (!alive || !d->active) return reject(QStringLiteral("Native package context retired during creation"));
        if (!object || object->thread() != thread() || object->parent() != this || !ownObject(object))
            return reject(QStringLiteral("Native factory must return an owning-thread QObject parented to its package context"));
        auto *session = qobject_cast<ExtensionPackageSession *>(object);
        if (!session) return reject(QStringLiteral("Native session does not implement ExtensionPackageSession"));
        d->nativeSession = object;
        const bool started = session->start(error);
        if (!alive || !d->active || !d->nativeSession)
            return reject(QStringLiteral("Native package session retired during startup"));
        return started || reject(error && !error->isEmpty() ? *error : QStringLiteral("Native package session rejected startup"));
    } catch (const std::exception &exception) {
        return reject(QStringLiteral("Native package session failed: ") + QString::fromUtf8(exception.what()).left(512));
    } catch (...) {
        return reject(QStringLiteral("Native package session failed with an unknown exception"));
    }
}
bool PluginContext::owns(QObject *object) const {
    if (!object || object == this || object == d->engine.data() || object == d->context.data()) return false;
    for (auto *parent = object->parent(); parent; parent = parent->parent()) if (parent == this) return true;
    return d->context && QQmlEngine::contextForObject(object) == d->context;
}
void PluginContext::remember(QObject *object) {
    if (!object) return;
    QQmlEngine::setObjectOwnership(object, QQmlEngine::CppOwnership);
    if (!d->objects.contains(object)) d->objects.append(object);
}
bool PluginContext::ownObject(QObject *object) {
    if (QThread::currentThread() != thread() || !d->active || !object || object->thread() != thread() || !owns(object)) return false;
    if (d->objects.contains(object)) return true;
    int live = 0;
    for (const auto &owned : std::as_const(d->objects)) live += bool(owned);
    if (live >= 64) return false;
    if (!object->parent()) object->setParent(this);
    remember(object); return true;
}
QObject *PluginContext::openObservationSource(const QVariantMap &descriptor, QString *error) {
    if (error) error->clear();
    const auto reject = [error](const QString &message) -> QObject * {
        if (error) *error = message;
        return nullptr;
    };
    if (QThread::currentThread() != thread() || !d->active || !d->runtime)
        return reject(QStringLiteral("Observation source registration requires an active owning-thread native package"));
    int live = 0;
    for (const auto &source : std::as_const(d->observationSources)) live += bool(source);
    if (live >= 16) return reject(QStringLiteral("Package observation-source limit reached"));
    QPointer<PluginContext> alive(this);
    QPointer<QObject> object = d->runtime->createObservationSource(this, descriptor, error);
    if (!alive || !d->active) return nullptr;
    auto *source = object ? qobject_cast<TerminalObservationSource *>(object.data()) : nullptr;
    if (!source || object->parent() != this || object->thread() != thread() || !ownObject(object)) {
        if (object && object->parent() == this && object->thread() == thread()) {
            if (source) source->close();
            if (object) object->deleteLater();
        }
        return object ? reject(QStringLiteral("Source factory did not return a package-owned native source")) : nullptr;
    }
    d->observationSources.append(object);
    return object.data();
}
bool PluginContext::registerService(const QString &name, QObject *object) {
    return QThread::currentThread() == thread() && d->active && d->runtime && declares("services", "exports", name) && ownObject(object) &&
        d->runtime->provide(this, name, object);
}
bool PluginContext::publish(const QString &channel, const QVariantMap &payload) {
    return QThread::currentThread() == thread() && d->active && d->runtime && declares("channels", "publish", channel) && d->runtime->publish(this, channel, payload);
}
QString PluginContext::subscribe(const QString &channel, const QJSValue &callback) {
    if (QThread::currentThread() != thread() || !d->active || !declares("channels", "subscribe", channel) || !callback.isCallable() || d->subscriptions.size() >= 32) return {};
    const auto token = QUuid::createUuid().toString(QUuid::WithoutBraces);
    d->subscriptions[token] = {channel, callback}; return token;
}
bool PluginContext::unsubscribe(const QString &token) { return QThread::currentThread() == thread() && d->subscriptions.remove(token) != 0; }
QString PluginContext::createTimer(int milliseconds, bool repeat, const QJSValue &callback) {
    if (QThread::currentThread() != thread() || !d->active || !callback.isCallable() || milliseconds < 10 || milliseconds > 60000 || d->timers.size() >= 32) return {};
    const auto token = QUuid::createUuid().toString(QUuid::WithoutBraces);
    auto *timer = new QTimer(this); timer->setInterval(milliseconds); timer->setSingleShot(!repeat); d->timers[token] = timer;
    connect(timer, &QTimer::timeout, this, [this, timer, token, callback, repeat] {
        if (!d->active) return;
        if (!repeat) { d->timers.remove(token); timer->deleteLater(); }
        QPointer<PluginContext> alive(this);
        const auto result = callback.call();
        if (alive && d->active && result.isError()) emit errorOccurred(result.toString().left(512));
    });
    timer->start(); return token;
}
bool PluginContext::cancelTimer(const QString &token) {
    if (QThread::currentThread() != thread()) return false;
    auto timer = d->timers.take(token);
    if (!timer) return false;
    timer->stop(); timer->disconnect(); timer->deleteLater(); return true;
}
void PluginContext::deliver(const QString &channel, const QVariantMap &message) {
    if (!d->active || !d->engine || !declares("channels", "subscribe", channel)) return;
    QPointer<PluginContext> alive(this);
    emit messageReceived(channel, message);
    if (!alive || !d->active) return;
    const auto subscribers = d->subscriptions;
    for (auto it = subscribers.cbegin(); it != subscribers.cend(); ++it) {
        if (it->channel != channel || !d->subscriptions.contains(it.key())) continue;
        const auto value = d->engine->toScriptValue(message);
        const auto result = it->callback.call({value});
        if (!alive || !d->active) return;
        if (result.isError()) {
            emit errorOccurred(result.toString().left(512));
            if (!alive || !d->active) return;
        }
    }
}
void PluginContext::notifyServices() { if (d->active) { ++d->servicesRevision; emit servicesChanged(); } }
void PluginContext::dispose() {
    if (!d->active) return;
    QPointer<PluginContext> alive(this);
    d->active = false;
    d->subscriptions.clear();
    for (const auto &timer : std::as_const(d->timers)) if (timer) { timer->stop(); timer->disconnect(); timer->deleteLater(); }
    d->timers.clear();
    const auto sources = d->observationSources;
    d->observationSources.clear();
    for (const auto &source : sources) {
        if (source) if (auto *native = qobject_cast<TerminalObservationSource *>(source.data())) native->close();
        if (!alive) return;
    }
    if (d->runtime) d->runtime->release(this);
    if (!alive) return;
    // Consumers retire while the provider's session still exists. Then the
    // provider stops all native work before owned QML/QObjects are destroyed.
    auto native = d->nativeSession;
    d->nativeSession = nullptr;
    if (native) {
        if (auto *session = qobject_cast<ExtensionPackageSession *>(native.data())) session->stop();
    }
    if (!alive) return;
    for (const auto &object : std::as_const(d->objects)) if (object) {
        // QML Timer children and SDK timers both stop before deferred object
        // destruction. Raw plugin code remains trusted, not sandboxed.
        for (auto *child : object->findChildren<QObject *>()) if (child->inherits("QQmlTimer")) child->setProperty("running", false);
        object->deleteLater();
    }
    emit activeChanged();
}
