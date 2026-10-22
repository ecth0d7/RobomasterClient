#include "NativePackageLoader.h"
#include "ExtensionPackage.h"
#include "PackageValidation.h"
#include <QCoreApplication>
#include <QFileInfo>
#include <QJsonObject>
#include <QLibrary>
#include <QMap>
#include <QPluginLoader>
#include <QPointer>
#include <QThread>
#include <exception>
#include <memory>

namespace {
struct Module {
    QString fingerprint;
    std::unique_ptr<QPluginLoader> loader;
    QPointer<QObject> factory;
};
// Shared across runtime instances: Qt also caches libraries across loaders.
// No unload() is attempted while queued callbacks/metatypes can reference code.
QMap<QString, std::shared_ptr<Module>> &modules() {
    static QMap<QString, std::shared_ptr<Module>> value;
    return value;
}
bool onOwnerThread() {
    return QCoreApplication::instance() && QThread::currentThread() == QCoreApplication::instance()->thread();
}
}

bool NativePackageLoader::restartRequired(const QString &library, const QString &fingerprint) {
    if (!onOwnerThread()) return true;
    const auto module = modules().value(library);
    return module && module->fingerprint != fingerprint;
}

ExtensionPackagePlugin *NativePackageLoader::load(const QVariantMap &manifest, QString *error) {
    const auto reject = [error](const QString &message) -> ExtensionPackagePlugin * {
        PackageValidation::fail(error, message.left(1024)); return nullptr;
    };
    if (!onOwnerThread()) return reject(QStringLiteral("Native package loading requires the application thread"));
    const auto library = manifest.value("_native_library").toString();
    const auto fingerprint = manifest.value("_native_fingerprint").toString();
    if (library.isEmpty() || fingerprint.size() != 64 || QFileInfo(library).canonicalFilePath() != library)
        return reject(QStringLiteral("Native package entry was not validated"));
    if (restartRequired(library, fingerprint))
        return reject(QStringLiteral("原生库内容已更换；旧库仍由Qt保留，请重启应用后启用新版本"));
    auto module = modules().value(library);
    if (!module) {
        if (modules().size() >= PackageValidation::MaximumPackages)
            return reject(QStringLiteral("本进程已使用64个原生插件路径，请重启后装载其他原生包"));
        module = std::make_shared<Module>();
        module->loader = std::make_unique<QPluginLoader>(library);
        module->loader->setLoadHints(QLibrary::PreventUnloadHint | QLibrary::ResolveAllSymbolsHint);
        const auto metadata = module->loader->metaData();
        const auto details = metadata.value("MetaData").toObject();
        if (metadata.value("IID").toString() != QLatin1String(ExtensionPackagePlugin_iid) ||
            details.value("id").toString() != manifest.value("id").toString() || details.value("apiMajor").toDouble(-1) != 1)
            return reject(QStringLiteral("原生Qt插件元数据与包标识／接口版本不一致"));
        module->fingerprint = fingerprint;
        // Pin before instance(): native static/factory constructors can execute.
        modules().insert(library, module);
    }
    try {
        if (!module->factory) module->factory = module->loader->instance();
        if (!module->factory) return reject(module->loader->errorString());
        auto *factory = qobject_cast<ExtensionPackagePlugin *>(module->factory.data());
        if (!factory || factory->id() != manifest.value("id").toString() || factory->apiMajor() != 1)
            return reject(QStringLiteral("原生插件工厂未实现本包的ExtensionPackagePlugin接口"));
        return factory;
    } catch (const std::exception &exception) {
        return reject(QStringLiteral("Native package construction failed: ") + QString::fromUtf8(exception.what()).left(512));
    } catch (...) {
        return reject(QStringLiteral("Native package construction failed with an unknown exception"));
    }
}
