#include "UiViewController.h"
#include "UiPack.h"
#include <QQmlApplicationEngine>
#include <QWindow>
#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QUrl>
#include <QStringList>
#include <QtGlobal>
#include <utility>

UiViewController::UiViewController(const QString &directory, QObject *parent)
    : QObject(parent), m_directory(directory) {
    QString error;
    m_views = UiPack::viewCatalog(directory, &error);
    if (!error.isEmpty())
        m_status = error;
}

UiViewController::~UiViewController() {
    // Delete engines while our members still exist; window-close callbacks must
    // never reach a partially destroyed controller during QObject child cleanup.
    for (const auto &engine : std::as_const(m_engines)) {
        if (!engine)
            continue;
        engine->disconnect(this);
        for (auto *root : engine->rootObjects())
            root->disconnect(this);
        delete engine.data();
    }
}

void UiViewController::setStatus(const QString &value) {
    if (m_status == value)
        return;
    m_status = value;
    emit statusChanged();
}

QString UiViewController::qtRuntimeVersion() const {
    return QString::fromLatin1(qVersion());
}

bool UiViewController::assetsAvailable(const QVariantList &files) const {
    if (files.isEmpty() || files.size() > 256)
        return false;
    QStringList roots;
    for (const auto &directory : {QDir(m_directory).filePath("../extensions"),
                                  QDir(QCoreApplication::applicationDirPath()).filePath("extensions")}) {
        const QString path = QFileInfo(directory).canonicalFilePath();
        if (!path.isEmpty())
            roots.append(path + QLatin1Char('/'));
    }
    for (const auto &value : files) {
        const auto file = value.toMap();
        const QUrl url(file.value("url").toString());
        bool sizeValid = false;
        const qint64 expected = file.value("size").toLongLong(&sizeValid);
        if (!url.isLocalFile() || !sizeValid || expected <= 0)
            return false;
        const QFileInfo info(url.toLocalFile());
        const QString path = info.canonicalFilePath();
        // 只核对UI扩展目录中的本地资源；大小检查防止半份网格被当作完整场地。
        bool inside = false;
        for (const auto &root : roots)
            inside |= path.startsWith(root);
        if (!inside || !info.isFile() || !info.isReadable() || info.size() != expected)
            return false;
    }
    return true;
}

bool UiViewController::openReference(const QString &id) {
    QString error;
    // Re-read the small manifest before loading, so a changed descriptor cannot
    // retain the reference classification of an older catalog.
    const auto catalog = UiPack::viewCatalog(m_directory, &error);
    if (!error.isEmpty()) {
        setStatus(error);
        return false;
    }
    QVariantMap descriptor;
    for (const auto &value : catalog) {
        const auto candidate = value.toMap();
        if (candidate.value("id").toString() == id) {
            descriptor = candidate;
            break;
        }
    }
    if (descriptor.isEmpty() || descriptor.value("kind").toString() != "reference") {
        setStatus(QStringLiteral("This view is not a declared visual reference: ") + id);
        return false;
    }
    if (auto *existing = m_engines.value(id).data()) {
        for (auto *root : existing->rootObjects()) {
            if (auto *window = qobject_cast<QWindow *>(root)) {
                window->show();
                window->raise();
                window->requestActivate();
                setStatus(descriptor.value("title").toString());
                return true;
            }
        }
        m_engines.remove(id);
        existing->deleteLater();
    }
    auto *engine = new QQmlApplicationEngine(this);
    // Deliberately no host rootContext injection or native package activation.
    engine->load(descriptor.value("entry").toUrl());
    QWindow *window = nullptr;
    if (engine->rootObjects().size() == 1)
        window = qobject_cast<QWindow *>(engine->rootObjects().first());
    if (!window) {
        engine->deleteLater();
        setStatus(QStringLiteral("Reference UI did not create one window: ") + id);
        return false;
    }
    m_engines.insert(id, engine);
    const QPointer<QQmlApplicationEngine> guardedEngine(engine);
    QObject::connect(window, &QWindow::visibleChanged, this,
                     [this, id, guardedEngine](bool visible) {
        if (visible || !guardedEngine || m_engines.value(id) != guardedEngine)
            return;
        m_engines.remove(id);
        // Window close callbacks run in QML; defer engine destruction until the
        // callback stack has unwound, including package service callers.
        guardedEngine->deleteLater();
    });
    window->show();
    window->raise();
    window->requestActivate();
    setStatus(descriptor.value("title").toString());
    return true;
}
