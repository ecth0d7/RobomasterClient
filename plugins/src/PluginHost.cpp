#include "PluginHost.h"

#include <QDir>
#include <QJsonObject>
#include <QRegularExpression>

namespace {

QVariantMap manifest(const QPluginLoader &loader) {
    const QJsonObject root = loader.metaData();
    const QString iid = root.value("IID").toString();

    // IID 区分工厂接口，apiVersion 区分元数据契约；两者都要匹配。
    const bool knownContract =
        iid == QLatin1String(ClientPlugin_iid) || iid == QLatin1String(ExtensionPlugin_iid);
    if (!knownContract) {
        return {};
    }

    const QJsonObject metadata = root.value("MetaData").toObject();
    if (metadata.value("apiVersion").toInt() != 1) {
        return {};
    }

    QVariantMap result = metadata.toVariantMap();
    result.insert("contract", iid);
    return result;
}

}

PluginHost::~PluginHost() {
    // 端点中可能还有插件定义的析构函数。宿主必须先销毁端点，
    // 最后才销毁 PluginHost，按逆序释放加载器。声明应用级异步清理的
    // 模块保留代码到进程退出，避免稍后的清理回调跳入已卸载代码。
    for (auto it = m_loaders.rbegin(); it != m_loaders.rend(); ++it) {
        (*it)->unload();
    }
}

QVariantList PluginHost::discover(const QString &directory) {
    QVariantList result;
    const QDir dir(directory);

    for (const QFileInfo &file : dir.entryInfoList(QDir::Files, QDir::Name)) {
        // 读取嵌入的元数据不创建工厂实例；展示模块清单不会启动服务。
        QPluginLoader loader(file.absoluteFilePath());
        QVariantMap metadata = manifest(loader);
        if (metadata.isEmpty()) {
            continue;
        }

        // 保留真实动态库位置，让符号链接插件仍从自身位置解析相对依赖。
        metadata.insert("path", file.canonicalFilePath());
        result.append(metadata);
    }
    return result;
}

QObject *PluginHost::loadObject(const QString &directory, const QString &id, const QString &role,
                                const QString &contract, QString *error) {
    if (error) {
        error->clear();
    }
    const auto fail = [error](const QString &message) -> QObject * {
        if (error) {
            *error = message;
        }
        return nullptr;
    };

    // 配置选择的是模块标识，不是任意文件路径。
    static const QRegularExpression identifier("^[A-Za-z0-9][A-Za-z0-9_.-]{0,95}$");
    if (!identifier.match(id).hasMatch()) {
        return fail("Invalid plugin id: " + id);
    }

    QString selected;
    for (const QVariant &entry : discover(directory)) {
        const QVariantMap info = entry.toMap();
        const bool matches = info.value("id").toString() == id &&
                             info.value("role").toString() == role &&
                             info.value("contract").toString() == contract;
        if (!matches) {
            continue;
        }
        if (!selected.isEmpty()) {
            return fail("Ambiguous plugin id: " + id);
        }
        selected = info.value("path").toString();
    }
    if (selected.isEmpty()) {
        return fail(QString("Missing %1 plugin '%2' in %3").arg(role, id, directory));
    }

    // Stop/start replaces service endpoints, not native library identities. Reuse
    // the factory to keep repeated UI toggles from accumulating loader references.
    const QString cacheKey = selected + "|" + contract + "|" + role + "|" + id;
    if (m_instances.contains(cacheKey))
        return m_instances.value(cacheKey);

    auto loader = std::make_unique<QPluginLoader>(selected);
    auto hints = QLibrary::LoadHints(QLibrary::ResolveAllSymbolsHint);
    // Optional metadata extension, no factory/endpoint ABI change. A process
    // reaper may outlive its endpoint and PluginHost while Qt exits. Pin only
    // modules that explicitly declare this lifetime; runtime selection still
    // replaces endpoints and reuses their already-cached factory.
    if (loader->metaData().value("MetaData").toObject().value("applicationOwnedCleanup").toBool())
        hints |= QLibrary::PreventUnloadHint;
    loader->setLoadHints(hints);
    QObject *object = loader->instance();
    if (!object) {
        return fail("Cannot load plugin: " + loader->errorString());
    }

    // 元数据只用于发现；创建实例后，再确认实际工厂接口与声明一致。
    if (contract == QLatin1String(ClientPlugin_iid)) {
        auto *plugin = qobject_cast<ClientPlugin *>(object);
        if (!plugin || plugin->id() != id || plugin->role() != role) {
            return fail("Plugin factory does not match its metadata");
        }
    } else {
        auto *plugin = qobject_cast<ExtensionPlugin *>(object);
        if (!plugin || plugin->id() != id || plugin->role() != role) {
            return fail("Extension factory does not match its metadata");
        }
    }

    // 加载器的生命周期要覆盖实例以及该实例创建的所有端点。
    m_loaders.push_back(std::move(loader));
    m_instances.insert(cacheKey, object);
    return object;
}

ClientPlugin *PluginHost::load(const QString &directory, const QString &id, const QString &role,
                               QString *error) {
    const QString contract = QString::fromLatin1(ClientPlugin_iid);
    return qobject_cast<ClientPlugin *>(loadObject(directory, id, role, contract, error));
}

ExtensionPlugin *PluginHost::loadExtension(const QString &directory, const QString &id,
                                           const QString &role, QString *error) {
    const QString contract = QString::fromLatin1(ExtensionPlugin_iid);
    return qobject_cast<ExtensionPlugin *>(loadObject(directory, id, role, contract, error));
}
