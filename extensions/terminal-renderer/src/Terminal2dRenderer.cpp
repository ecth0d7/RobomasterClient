#include "Terminal2dRenderer.h"
#include "TerminalRendererContract.h"

#include <QDateTime>
#include <QPointer>
#include <QThread>
#include <QTimer>
#include <QUuid>
#include <chrono>
#include <cmath>

namespace {
qint64 tickNow() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
}
bool fail(QString *error, const QString &message) { if (error) *error = message; return false; }
}
struct Terminal2dRenderer::Private {
    TerminalRendererContract::Projector projector;
    QVariantMap configuration, pending, counts;
    QTimer timer;
    QString session, status = QStringLiteral("二维渲染器未启用"), lastError;
    quint64 generation = 0, accepted = 0, coalesced = 0, projected = 0, rejected = 0;
    qint64 acceptedRevision = 0;
    bool active = false, scheduled = false;
};
Terminal2dRenderer::Terminal2dRenderer(QObject *parent) : ServiceEndpoint(parent), d(std::make_unique<Private>()) {
    d->timer.setInterval(100);
    connect(&d->timer, &QTimer::timeout, this, &Terminal2dRenderer::refresh);
}
Terminal2dRenderer::~Terminal2dRenderer() { blockSignals(true); stop(); }
bool Terminal2dRenderer::start(const QVariantMap &configuration, QString *error) {
    if (error) error->clear();
    if (QThread::currentThread() != thread()) return fail(error, "Renderer requires its owning thread");
    QPointer<Terminal2dRenderer> alive(this);
    const auto generation = d->generation + 1;
    stop();
    if (!alive || generation != d->generation) return false;
    if (!d->projector.configure(configuration, error)) return false;
    d->configuration = configuration;
    d->session = QUuid::createUuid().toString(QUuid::WithoutBraces);
    d->active = true; d->timer.start();
    d->status = QStringLiteral("二维渲染器已启用；等待宿主完整场景，未知坐标与mock只列文字");
    emit statusChanged();
    return alive && generation == d->generation;
}
void Terminal2dRenderer::stop() {
    if (QThread::currentThread() != thread()) return;
    ++d->generation;
    d->timer.stop(); d->active = false; d->scheduled = false;
    d->pending.clear(); d->counts.clear(); d->configuration.clear(); d->session.clear();
    d->projector.clear(); d->lastError.clear(); d->acceptedRevision = 0;
    d->accepted = d->coalesced = d->projected = d->rejected = 0;
    d->status = QStringLiteral("仅二维渲染器已停；数据源、共享与其他通信不受影响");
    emit statusChanged();
}
bool Terminal2dRenderer::submit(const QVariantMap &message, QString *error) {
    if (error) error->clear();
    if (QThread::currentThread() != thread() || !d->active) return fail(error, "Renderer is not active on its owning thread");
    TerminalRendererContract::Scene scene;
    if (!TerminalRendererContract::parseScene(message, &scene, error)) return false;
    const auto utc = QDateTime::currentMSecsSinceEpoch(), tick = tickNow();
    if (scene.context != d->configuration.value("context").toMap() || scene.revision <= d->acceptedRevision ||
        scene.producedAtMs > utc || scene.producedTickMs > tick ||
        std::abs((utc - scene.producedAtMs) - (tick - scene.producedTickMs)) > 250)
        return fail(error, "Renderer scene has wrong context, regressed revision or invalid original host clocks");
    // Full scenes supersede pending full scenes. One scheduled drain and one
    // <=64 KiB pending scene bound both storage and the GUI event queue.
    if (!d->pending.isEmpty()) ++d->coalesced;
    d->pending = message; d->acceptedRevision = scene.revision; ++d->accepted;
    schedule();
    return true; // Local bounded queue acceptance, not projection or execution.
}
void Terminal2dRenderer::schedule() {
    if (d->scheduled || !d->active || d->pending.isEmpty()) return;
    d->scheduled = true;
    const auto generation = d->generation;
    QTimer::singleShot(0, this, [this, generation] { drain(generation); });
}
void Terminal2dRenderer::drain(quint64 generation) {
    if (generation != d->generation || !d->active) return;
    d->scheduled = false;
    const auto scene = std::move(d->pending); d->pending.clear();
    if (scene.isEmpty()) return;
    QString error;
    const auto output = d->projector.project(scene, QDateTime::currentMSecsSinceEpoch(), tickNow(), &error);
    QPointer<Terminal2dRenderer> alive(this);
    if (output.isEmpty()) {
        ++d->rejected; d->lastError = error.left(512); d->status = d->lastError;
        emit errorOccurred(d->lastError);
        if (!alive || generation != d->generation) return;
        emit statusChanged();
    } else {
        d->counts = output.value("counts").toMap(); d->lastError.clear(); ++d->projected;
        d->status = output.value("clock_valid") != QVariant(true) ? QStringLiteral("时钟异常，所有空间记录退为文字")
            : d->counts.value("projected_items").toInt() ? QStringLiteral("已投影新鲜且通过坐标标定接纳的来源点；无自动控制")
            : QStringLiteral("当前场景无可落图的有效来源点；未知／过期／mock保持文字");
        emit messageReceived(output);
        if (!alive || generation != d->generation) return;
        emit statusChanged();
    }
    if (!alive || generation != d->generation) return;
    schedule();
}
void Terminal2dRenderer::refresh() {
    if (!d->active) return;
    const auto generation = d->generation;
    QString error;
    const auto output = d->projector.view(QDateTime::currentMSecsSinceEpoch(), tickNow(), &error);
    if (output.isEmpty()) return;
    d->counts = output.value("counts").toMap();
    if (output.value("clock_valid") != QVariant(true)) d->status = QStringLiteral("时钟异常，所有空间记录退为文字");
    else if (!d->counts.value("projected_items").toInt())
        d->status = QStringLiteral("当前无新鲜且满足标定条件的来源点；过期／未知／mock只列文字");
    QPointer<Terminal2dRenderer> alive(this);
    emit messageReceived(output);
    if (!alive || generation != d->generation) return;
    emit statusChanged();
}
QString Terminal2dRenderer::status() const { return d->status; }
QVariantMap Terminal2dRenderer::details() const {
    auto result = TerminalRendererContract::capabilities();
    result["id"] = "renderer.terminal.2d.v1"; result["role"] = "terminal-renderer";
    result["active"] = d->active; result["state"] = !d->active ? "stopped" : d->projected ? "projecting" : "waiting_scene";
    result["context"] = d->configuration.value("context"); result["session_id"] = d->session;
    result["pending_scenes"] = d->pending.isEmpty() ? 0 : 1;
    result["accepted_scenes"] = qulonglong(d->accepted); result["coalesced_scenes"] = qulonglong(d->coalesced);
    result["projected_scenes"] = qulonglong(d->projected); result["rejected_scenes"] = qulonglong(d->rejected);
    result["counts"] = d->counts; result["last_error"] = d->lastError;
    result["automatic_actions_allowed"] = false; result["network_connection"] = false;
    return result;
}
