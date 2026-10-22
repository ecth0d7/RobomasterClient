#pragma once
#include "ClientPlugin.h"
#include "ExtensionPlugin.h"
#include <QPluginLoader>
#include <QMap>
#include <memory>
#include <vector>

class PluginHost {
public:
    ~PluginHost();
    // 目录发现只读取元数据；仅显式选择的插件会加载并执行。
    static QVariantList discover(const QString &directory);
    ClientPlugin *load(const QString &directory, const QString &id, const QString &role,
                       QString *error);
    ExtensionPlugin *loadExtension(const QString &directory, const QString &id, const QString &role,
                                   QString *error);

private:
    QObject *loadObject(const QString &directory, const QString &id, const QString &role,
                        const QString &contract, QString *error);
    std::vector<std::unique_ptr<QPluginLoader>> m_loaders;
    QMap<QString, QObject *> m_instances;
};
