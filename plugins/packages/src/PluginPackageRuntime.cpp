#include "PluginPackageRuntime.h"
#include "PluginContext.h"
#include "NativePackageLoader.h"
#include "PackageValidation.h"
#include "ExtensionServiceProvider.h"
#include "LeaseServiceEndpoint.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QLockFile>
#include <QMap>
#include <QPointer>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQueue>
#include <QScopeGuard>
#include <QSet>
#include <QThread>
#include <QTimer>
#include <QUuid>
#include <utility>
#include <exception>

namespace {
using namespace PackageValidation;
bool scopeValid(const QVariantMap &scope) {
    if (scope.isEmpty() || scope.size() > 8 || !bounded(scope, 2048)) return false;
    for (auto it = scope.cbegin(); it != scope.cend(); ++it)
        if (it.value().metaType().id() != QMetaType::QString || it.value().toString().isEmpty() || it.value().toString().size() > 128) return false;
    return true;
}
QString componentError(const QQmlComponent &component) {
    QStringList errors;
    for (const auto &error : component.errors()) errors.append(error.toString());
    return errors.join('\n').left(1024);
}
QVariantMap savedValues(const QVariantList &scopes, const QVariantMap &scope, const QString &id) {
    for (const auto &entry : scopes) {
        const auto row = entry.toMap();
        if (row.value("scope").toMap() == scope) return row.value("packages").toMap().value(id).toMap();
    }
    return {};
}
// A separate negative-intent journal protects Stop when the main settings file
// is corrupt, locked by another process, or fails its atomic replacement.
// The same exact native scope is used in both files; grants never migrate.
bool disableJournal(const QString &file, QVariantList *out, QString *error) {
    out->clear();
    if (file.isEmpty() || QFileInfo(file).isSymLink()) return fail(error, "Disable journal is unset or a symlink; restoration blocked");
    if (!QFileInfo::exists(file)) return true;
    QFile input(file);
    if (!input.open(QIODevice::ReadOnly)) return fail(error, "Disable journal cannot be read; restoration blocked");
    const auto bytes = input.read(MaximumStoreBytes + 1); QJsonParseError parse;
    const auto doc = QJsonDocument::fromJson(bytes, &parse); const auto value = doc.toVariant().toMap();
    if (input.error() != QFileDevice::NoError || bytes.size() > MaximumStoreBytes || parse.error != QJsonParseError::NoError || !doc.isObject() ||
        value.size() != 2 || (value.value("schema").metaType().id() != QMetaType::Double && value.value("schema").metaType().id() != QMetaType::LongLong &&
            value.value("schema").metaType().id() != QMetaType::Int) || value.value("schema").toDouble() != 1 ||
        value.value("scopes").metaType().id() != QMetaType::QVariantList || value.value("scopes").toList().size() > 16)
        return fail(error, "Invalid disable journal preserved; restoration blocked");
    QSet<QByteArray> seen;
    for (const auto &entry : value.value("scopes").toList()) {
        const auto row = entry.toMap(); const auto scope = row.value("scope").toMap(); const auto ids = row.value("ids").toList();
        if (entry.metaType().id() != QMetaType::QVariantMap || row.size() != 2 || row.value("scope").metaType().id() != QMetaType::QVariantMap ||
            !scopeValid(scope) || seen.contains(json(scope)) || row.value("ids").metaType().id() != QMetaType::QVariantList || ids.isEmpty() || ids.size() > MaximumPackages)
            return fail(error, "Invalid disable journal scope preserved; restoration blocked");
        QSet<QString> names;
        for (const auto &id : ids) {
            if (id.metaType().id() != QMetaType::QString || !identifier(id.toString()) || names.contains(id.toString()))
                return fail(error, "Invalid disable journal package identity preserved; restoration blocked");
            names.insert(id.toString());
        }
        seen.insert(json(scope)); out->append(row);
    }
    return true;
}
bool disabled(const QVariantList &rows, const QVariantMap &scope, const QString &id) {
    for (const auto &entry : rows) if (entry.toMap().value("scope").toMap() == scope)
        return entry.toMap().value("ids").toList().contains(id);
    return false;
}
bool changeDisabled(QVariantList *rows, const QVariantMap &scope, const QString &id, bool value, QString *error) {
    int index = -1; QVariantList ids;
    for (int i = 0; i < rows->size(); ++i) if (rows->at(i).toMap().value("scope").toMap() == scope) { index = i; ids = rows->at(i).toMap().value("ids").toList(); break; }
    if (value && !ids.contains(id)) {
        if (ids.size() >= MaximumPackages || (index < 0 && rows->size() >= 16)) return fail(error, "Disable journal scope/package capacity reached");
        ids.append(id);
    } else if (!value) ids.removeAll(id);
    if (ids.isEmpty()) { if (index >= 0) rows->removeAt(index); }
    else { const QVariantMap row{{"scope", scope}, {"ids", ids}}; if (index < 0) rows->append(row); else (*rows)[index] = row; }
    return true;
}
QVariantMap reviewedRecord(const QVariantMap &manifest, const QVariantMap &values, bool enabled) {
    return {{"version", manifest.value("version")}, {"values", values}, {"enabled", enabled}, {"fingerprint", manifest.value("_fingerprint")}};
}
}

struct PluginPackageRuntime::Private {
    struct Package {
        QVariantMap manifest, configuration;
        QPointer<PluginContext> context;
        QMap<QString, QPointer<QObject>> panels;
        QSet<QString> creatingPanels;
        QString path, error, persistenceError;
        bool enabled = false, configured = false, blocked = false, installed = true;
        bool restorePending = false, restored = false, attested = false, ready = false;
    };
    struct Service {
        QPointer<QObject> object; QPointer<PluginContext> owner;
        quint64 token = 0; bool foundation = false;
        QVariantMap providerIdentity;
    };
    struct Lease { QPointer<LeaseServiceEndpoint> object; quint64 providerToken = 0; };
    struct Message { QPointer<PluginContext> sender; QVariantMap envelope; qsizetype bytes = 0; bool foundation = false; };
    QPointer<QQmlEngine> engine;
    QString directory, file, status = QStringLiteral("本地QML插件保持停用；基础MQTT／UI／UDP解码独立运行"), lockedReason;
    QVariantMap scope;
    QVariantList scopes, disabledScopes;
    ObservationSourceFactory observationFactory;
    QMap<QString, Package> packages;
    QMap<QString, Service> services;
    QList<Lease> leases;
    QSet<QString> foundationNames;
    QQueue<Message> messages;
    qsizetype messageBytes = 0;
    quint64 generation = 1, serviceToken = 0, sequence = 0;
    bool locked = false, fileValid = true, journalValid = true, scheduled = false, messageScheduled = false;
    bool reconciling = false, invalidating = false, destroying = false, serviceDirty = false;
    QStringList missing(const Package &p) const {
        QStringList result;
        for (const auto &name : p.manifest.value("services").toMap().value("required").toList()) {
            const auto service = services.value(name.toString());
            if (!service.object || (!service.foundation && (!service.owner || !service.owner->active() || !packages.value(service.owner->packageId()).ready))) result.append(name.toString());
        }
        return result;
    }
    QString journalFile() const { return file + ".disabled.json"; }
    // Negative intent is committed first. Enabling commits the reviewed record
    // first and only then removes the negative latch, under the same lock order.
    bool persist(const QString &id, const QVariantMap &record, bool explicitEnable,
                 bool *durablyDisabled, QString *error) {
        if (durablyDisabled) *durablyDisabled = false;
        if (!scopeValid(scope) || file.isEmpty() || !identifier(id)) return fail(error, "No valid native scope/package/configuration path for persistent plugin state");
        if (!QDir().mkpath(QFileInfo(file).absolutePath())) return fail(error, "Plugin configuration directory is not writable");
        QLockFile intentLock(journalFile() + ".lock");
        if (!intentLock.tryLock(0)) return fail(error, "Plugin disable journal is in use by another instance");
        const bool enabling = record.value("enabled").toBool();
        QVariantList blocks; QString journalError;
        journalValid = disableJournal(journalFile(), &blocks, &journalError);
        if (journalValid) disabledScopes = blocks;
        if (enabling && (!journalValid || (!explicitEnable && disabled(blocks, scope, id))))
            return fail(error, journalValid ? "A persistent Stop blocks automatic reactivation; enable explicitly" : journalError);
        bool negativeSaved = false;
        if (journalValid) {
            negativeSaved = changeDisabled(&blocks, scope, id, true, &journalError) &&
                PackageValidation::write(journalFile(), json(QVariantMap{{"schema", 1}, {"scopes", blocks}}), &journalError);
            if (negativeSaved) { disabledScopes = blocks; if (!enabling && durablyDisabled) *durablyDisabled = true; }
        }
        if (enabling && !negativeSaved) return fail(error, journalError);
        if (record.isEmpty()) return negativeSaved || fail(error, journalError);
        QLockFile settingsLock(file + ".lock");
        if (!settingsLock.tryLock(0)) return fail(error, "Plugin configuration is in use by another instance");
        QVariantList fresh; QString settingsError;
        if (!PackageValidation::store(file, &fresh, &settingsError)) { fileValid = false; return fail(error, settingsError); }
        QVariantMap selected; int index = -1;
        for (int i = 0; i < fresh.size(); ++i) if (fresh[i].toMap().value("scope").toMap() == scope) { selected = fresh[i].toMap(); index = i; break; }
        if (index < 0) {
            if (fresh.size() >= 16) return fail(error, "Plugin configuration reached16 scopes; old scopes were preserved");
            selected = {{"scope", scope}, {"packages", QVariantMap{}}};
        }
        auto records = selected.value("packages").toMap();
        if (!records.contains(id) && records.size() >= MaximumPackages) return fail(error, "Plugin configuration reached64 packages in this scope");
        records[id] = record; selected["packages"] = records;
        if (index < 0) fresh.append(selected); else fresh[index] = selected;
        if (!PackageValidation::write(file, json(QVariantMap{{"schema", 1}, {"scopes", fresh}}), &settingsError)) return fail(error, settingsError);
        fileValid = true; scopes = fresh;
        if (!enabling) { if (durablyDisabled) *durablyDisabled = true; return true; }
        if (!changeDisabled(&blocks, scope, id, false, &journalError) ||
            !PackageValidation::write(journalFile(), json(QVariantMap{{"schema", 1}, {"scopes", blocks}}), &journalError)) return fail(error, journalError);
        disabledScopes = blocks;
        return true;
    }
};

PluginPackageRuntime::PluginPackageRuntime(QQmlEngine *engine, QString directory, QString file, QObject *parent)
    : QObject(parent), d(std::make_unique<Private>()) {
    d->engine = engine; d->directory = directory.trimmed().isEmpty() ? QString{} : QDir::cleanPath(QFileInfo(directory).absoluteFilePath()); d->file = std::move(file);
    QString error;
    if (!PackageValidation::store(d->file, &d->scopes, &error)) { d->fileValid = false; d->status = error; }
    if (!disableJournal(d->journalFile(), &d->disabledScopes, &error)) { d->journalValid = false; d->status = error; }
    if (engine) connect(engine, &QObject::destroyed, this, [this] {
        ++d->generation; d->scheduled = d->messageScheduled = false;
        d->reconciling = false;
        const auto ids = d->packages.keys();
        for (const auto &id : ids) { d->packages[id].enabled = d->packages[id].restorePending = d->packages[id].restored = false; retirePackage(id); }
        d->messages.clear(); d->messageBytes = 0;
        d->status = QStringLiteral("应用QML引擎已退役；第三方插件已停"); emit changed();
    });
    rescan(); // Metadata only; never executes an unknown package.
}
PluginPackageRuntime::~PluginPackageRuntime() {
    d->destroying = true; ++d->generation;
    const auto ids = d->packages.keys();
    for (const auto &id : ids) retirePackage(id);
    // Finish QML object destruction before the private engines are released.
    const auto contexts = findChildren<PluginContext *>(QString{}, Qt::FindDirectChildrenOnly);
    for (auto *context : contexts) delete context;
}
QString PluginPackageRuntime::status() const { return d->status; }
QVariantMap PluginPackageRuntime::scope() const { return d->scope; }
QString PluginPackageRuntime::configFile() const { return d->file; }
QString PluginPackageRuntime::lockReason() const {
    if (d->destroying || !d->engine) return QStringLiteral("插件宿主或QML引擎不可用");
    if (d->locked) return d->lockedReason.isEmpty() ? QStringLiteral("比赛中插件配置只读") : d->lockedReason;
    if (d->directory.isEmpty()) return QStringLiteral("本地插件根目录未配置");
    if (!d->fileValid) return QStringLiteral("插件配置损坏；保留原文件，未启用插件");
    if (!d->journalValid) return QStringLiteral("插件持久停用记录无效；保留原文件并阻止恢复");
    if (!scopeValid(d->scope)) return QStringLiteral("原生规则／用途／机器人范围尚未设置");
    return {};
}
bool PluginPackageRuntime::editable() const { return lockReason().isEmpty(); }
bool PluginPackageRuntime::reject(const QString &reason) { d->status = reason.left(1024); emit changed(); return false; }
void PluginPackageRuntime::setConfigurationLocked(bool locked, const QString &reason) {
    if (d->locked == locked && d->lockedReason == reason) return;
    d->locked = locked; d->lockedReason = reason.left(512);
    if (!locked) schedule();
    emit changed();
}
bool PluginPackageRuntime::setScope(const QVariantMap &scope) {
    if (scope.isEmpty()) { retireAll(QStringLiteral("插件旧范围已退役，等待原生新范围")); return true; }
    if (!scopeValid(scope)) return reject(QStringLiteral("插件范围须为最多8个非空字符串标识，不接受运行时数据或权限标记"));
    if (d->scope == scope) return true;
    QPointer<PluginPackageRuntime> alive(this); const auto generation = d->generation + 1;
    retireAll();
    if (!alive || generation != d->generation) return false;
    d->scope = scope;
    QString error;
    d->fileValid = PackageValidation::store(d->file, &d->scopes, &error);
    d->journalValid = disableJournal(d->journalFile(), &d->disabledScopes, &error);
    for (auto it = d->packages.begin(); it != d->packages.end(); ++it) {
        auto &p = it.value(); p.blocked = p.manifest.isEmpty(); p.configured = false;
        if (!p.manifest.isEmpty()) p.error.clear();
        p.restorePending = p.restored = false; p.persistenceError.clear();
        p.configuration = p.manifest.value("configuration").toMap().value("defaults").toMap();
        const auto saved = savedValues(d->scopes, d->scope, it.key());
        if (!saved.isEmpty() && !p.manifest.isEmpty() && saved.value("version") == p.manifest.value("version") && PackageValidation::configuration(p.manifest.value("configuration").toMap().value("schema").toMap(), saved.value("values").toMap())) {
            p.configuration = saved.value("values").toMap(); p.configured = true;
            p.restorePending = d->fileValid && d->journalValid && saved.value("enabled").toBool() &&
                saved.value("fingerprint") == p.manifest.value("_fingerprint") && !disabled(d->disabledScopes, scope, it.key());
        }
    }
    d->status = !d->fileValid || !d->journalValid ? error : QStringLiteral("已加载本范围的保存配置；仅恢复内容未变且曾显式启用的插件，锁定中暂缓恢复");
    schedule(); emit changed(); return d->fileValid && d->journalValid;
}
void PluginPackageRuntime::retireAll(const QString &reason) {
    ++d->generation; d->scheduled = d->messageScheduled = false; d->reconciling = false;
    d->messages.clear(); d->messageBytes = 0; d->scope.clear();
    const auto ids = d->packages.keys();
    for (const auto &id : ids) { d->packages[id].enabled = false; d->packages[id].restorePending = d->packages[id].restored = false; retirePackage(id); }
    d->status = reason.isEmpty() ? QStringLiteral("插件范围与异步任务已退役；基础功能继续") : reason.left(1024);
    if (!d->destroying) emit changed();
}
QVariantList PluginPackageRuntime::packages() const {
    QVariantList result;
    for (auto it = d->packages.cbegin(); it != d->packages.cend(); ++it) {
        const auto &p = it.value(); const auto m = p.manifest; const auto services = m.value("services").toMap();
        const auto missing = d->missing(p);
        const auto saved = savedValues(d->scopes, d->scope, it.key());
        const bool active = p.ready && p.context && p.context->active();
        const QString state = !p.error.isEmpty() || p.blocked ? "error" : active ? "active" : p.context ? "loading" : (p.enabled || p.restorePending) && !missing.isEmpty() ? "waiting-dependency" : (p.enabled || p.restorePending) && d->locked ? "waiting-unlock" : p.configured ? "configured" : "installed";
        result.append(QVariantMap{{"id", it.key()}, {"version", m.value("version")}, {"apiMajor", m.value("apiMajor", 1)},
            {"title", m.value("title", it.key())}, {"description", m.value("description")}, {"path", p.path},
            {"entry_url", QUrl::fromLocalFile(QDir(p.path).filePath(m.value("entry").toString()))},
            {"discovered", true}, {"installed", p.installed}, {"configured", p.configured}, {"enabled", p.enabled}, {"active", active},
            {"state", state}, {"error", p.error}, {"missing_services", missing}, {"required_services", services.value("required")},
            {"optional_services", services.value("optional")}, {"exports", services.value("exports")}, {"panels", m.value("panels")},
            {"configuration", p.configuration}, {"configuration_schema", m.value("configuration").toMap().value("schema")},
            {"defaults", m.value("configuration").toMap().value("defaults")}, {"fingerprint", m.value("_fingerprint")},
            {"native", m.contains("native")}, {"native_library", m.value("native").toMap().value("library")},
            {"native_restart_required", m.contains("native") && NativePackageLoader::restartRequired(m.value("_native_library").toString(), m.value("_native_fingerprint").toString())},
            {"persisted_enabled", saved.value("enabled", false)}, {"restoration_pending", p.restorePending}, {"restored", p.restored},
            {"restart_restore_blocked", !d->journalValid || disabled(d->disabledScopes, d->scope, it.key())}, {"persistence_error", p.persistenceError}});
    }
    return result;
}
QVariantList PluginPackageRuntime::availablePanels() const {
    QVariantList result;
    for (auto it = d->packages.cbegin(); it != d->packages.cend(); ++it) {
        const auto &p = it.value(); if (!p.ready || !p.context || !p.context->active()) continue;
        for (const auto &entry : p.manifest.value("panels").toList()) {
            const auto panel = entry.toMap();
            result.append(QVariantMap{{"package_id", it.key()}, {"panel_id", panel.value("id")}, {"title", panel.value("title")},
                {"entry_url", QUrl::fromLocalFile(QDir(p.path).filePath(panel.value("entry").toString()))}});
        }
    }
    return result;
}
QVariantList PluginPackageRuntime::serviceProviders(const QString &role, const QString &contract) const {
    QVariantList result;
    if (QThread::currentThread() != thread() || d->destroying) return result;
    for (const auto &service : d->services) {
        const auto identity = service.providerIdentity;
        if (service.foundation || !service.object || !service.owner || !service.owner->active() || identity.isEmpty() ||
            identity.value("role") != role || identity.value("contract_id") != contract) continue;
        const auto package = d->packages.value(service.owner->packageId());
        if (package.ready && package.context == service.owner) result.append(identity);
    }
    return result;
}
ServiceEndpoint *PluginPackageRuntime::createProviderService(const QString &packageId, const QString &serviceName,
        const QString &role, const QString &contract, QString *error, QVariantMap *identity) {
    if (error) error->clear();
    if (identity) identity->clear();
    const auto fail = [error](const QString &reason) -> ServiceEndpoint * {
        if (error) *error = reason.left(1024);
        return nullptr;
    };
    if (QThread::currentThread() != thread() || d->destroying) return fail(QStringLiteral("插件能力只能由当前界面线程原生宿主创建"));
    const auto service = d->services.value(serviceName);
    const auto context = service.owner;
    const auto providerObject = service.object;
    const auto selected = service.providerIdentity;
    const auto package = d->packages.value(packageId);
    if (!context || !context->active() || !providerObject || service.foundation || selected.isEmpty() ||
        context->packageId() != packageId || package.context != context || !package.ready ||
        selected.value("role") != role || selected.value("contract_id") != contract)
        return fail(QStringLiteral("所选插件能力未运行、契约不符或依赖已失效"));
    auto *provider = qobject_cast<ExtensionServiceProvider *>(providerObject.data());
    if (!provider) return fail(QStringLiteral("所选导出未实现原生能力工厂接口"));
    QPointer<PluginPackageRuntime> alive(this);
    const auto generation = d->generation;
    const auto current = [this, alive, generation, context, providerObject, packageId, serviceName, token = service.token] {
        if (!alive || generation != d->generation || !context || !context->active() || !providerObject) return false;
        const auto now = d->services.value(serviceName);
        const auto package = d->packages.value(packageId);
        return now.token == token && now.object == providerObject && now.owner == context &&
            package.context == context && package.ready;
    };
    QPointer<ServiceEndpoint> inner;
    try { inner = provider->createService(); }
    catch (const std::exception &exception) { return fail(QStringLiteral("插件能力创建失败：") + QString::fromUtf8(exception.what()).left(512)); }
    catch (...) { return fail(QStringLiteral("插件能力创建失败：未知原生异常")); }
    if (!inner) return fail(QStringLiteral("插件能力工厂未返回端点"));
    if (alive) for (const auto &lease : d->leases)
        if (lease.object && lease.object->transferredEndpoint() == inner)
            return fail(QStringLiteral("能力工厂重复返回已转交给宿主的端点，未改变原租约"));
    if (inner->thread() != QThread::currentThread() || inner->parent() || inner.data() == providerObject.data()) {
        // An already owned object belongs to its existing owner. Do not stop or
        // delete it on rejection; only an unparented transfer can be accepted.
        if (!inner->parent() && inner.data() != providerObject.data()) inner->deleteLater();
        return fail(QStringLiteral("能力工厂须返回新的、无父对象且位于界面线程的静止端点"));
    }
    if (!current()) {
        inner->stop(); if (inner) delete inner.data();
        return fail(QStringLiteral("插件能力在创建期间退役，未保留旧端点"));
    }
    auto *lease = new LeaseServiceEndpoint(inner, selected);
    if (!current()) {
        lease->revoke(QStringLiteral("插件能力已退役")); delete lease;
        return fail(QStringLiteral("插件能力在创建期间退役"));
    }
    for (auto it = d->leases.begin(); it != d->leases.end();)
        if (!it->object) it = d->leases.erase(it); else ++it;
    d->leases.append({lease, service.token});
    if (identity) *identity = selected;
    return lease;
}
void PluginPackageRuntime::revokeProvider(quint64 token, const QString &reason) {
    QList<QPointer<LeaseServiceEndpoint>> retiring;
    for (auto it = d->leases.begin(); it != d->leases.end();) {
        if (!it->object || it->providerToken == token) {
            if (it->object) retiring.append(it->object);
            it = d->leases.erase(it);
        } else ++it;
    }
    QPointer<PluginPackageRuntime> alive(this);
    for (const auto &lease : retiring) {
        if (lease) lease->revoke(reason);
        if (!alive) return;
    }
}
bool PluginPackageRuntime::registerService(const QString &name, QObject *object) {
    if (QThread::currentThread() != thread() || !PackageValidation::serviceName(name) || !object || object->thread() != thread() || d->destroying || d->services.value(name).object) return false;
    const auto token = ++d->serviceToken;
    QQmlEngine::setObjectOwnership(object, QQmlEngine::CppOwnership);
    d->foundationNames.insert(name);
    d->services[name] = {object, {}, token, true, {}};
    connect(object, &QObject::destroyed, this, [this, name, token] {
        if (d->services.value(name).token != token) return;
        d->services.remove(name); d->serviceDirty = true; invalidateDependencies(); schedule();
    });
    d->serviceDirty = true; schedule(); return true;
}
bool PluginPackageRuntime::unregisterService(const QString &name) {
    const auto service = d->services.value(name);
    if (!service.foundation) return false;
    d->services.remove(name); d->serviceDirty = true; invalidateDependencies(); schedule(); return true;
}
bool PluginPackageRuntime::setObservationSourceFactory(ObservationSourceFactory factory) {
    if (QThread::currentThread() != thread() || d->destroying) return false;
    for (const auto &package : std::as_const(d->packages))
        if (package.context) return reject(QStringLiteral("Compose the observation source factory before enabling packages"));
    d->observationFactory = std::move(factory);
    return true;
}
QObject *PluginPackageRuntime::createObservationSource(PluginContext *context, const QVariantMap &descriptor, QString *error) {
    const auto rejectSource = [error](const QString &message) -> QObject * {
        if (error) *error = message;
        return nullptr;
    };
    if (QThread::currentThread() != thread() || !context || !context->active() || !editable())
        return rejectSource(QStringLiteral("Native observation sources can only be registered outside competition"));
    const auto package = d->packages.value(context->packageId());
    if (package.context != context || !package.manifest.contains("native") ||
        !(context->declares("services", "required", "terminal.sources@3") || context->declares("services", "optional", "terminal.sources@3")) ||
        !resolve(context, "terminal.sources@3") || !d->observationFactory)
        return rejectSource(QStringLiteral("Declare the available terminal.sources@3 service in a native package before source registration"));
    const QVariantMap metadata{{"id", context->packageId()}, {"version", package.manifest.value("version")},
        {"fingerprint", package.manifest.value("_fingerprint")}, {"configuration", package.configuration}};
    return d->observationFactory(context, metadata, d->scope, descriptor, error);
}
QObject *PluginPackageRuntime::resolve(PluginContext *context, const QString &name) const {
    if (!context || !context->active()) return nullptr;
    const auto service = d->services.value(name);
    const bool dependency = context->declares("services", "required", name) || context->declares("services", "optional", name);
    const bool ownExport = context->declares("services", "exports", name) && service.owner == context;
    if (!dependency && !ownExport) return nullptr;
    return service.object && (service.foundation || ownExport || (service.owner && service.owner->active() && d->packages.value(service.owner->packageId()).ready)) ? service.object.data() : nullptr;
}
bool PluginPackageRuntime::provide(PluginContext *context, const QString &name, QObject *object) {
    if (!context || !context->active() || !object || object->thread() != thread() || d->destroying ||
        d->foundationNames.contains(name) || d->services.value(name).object || !PackageValidation::serviceName(name)) return false;
    const auto token = ++d->serviceToken;
    QQmlEngine::setObjectOwnership(object, QQmlEngine::CppOwnership);
    d->services[name] = {object, context, token, false, {}};
    connect(object, &QObject::destroyed, this, [this, name, token] {
        if (d->services.value(name).token != token) return;
        d->services.remove(name); d->serviceDirty = true;
        QPointer<PluginPackageRuntime> alive(this);
        revokeProvider(token, QStringLiteral("插件能力提供者已销毁，旧租约已撤销"));
        if (!alive) return;
        invalidateDependencies(); schedule();
    });
    if (auto *provider = qobject_cast<ExtensionServiceProvider *>(object)) {
        QPointer<PluginPackageRuntime> alive(this); QPointer<PluginContext> owner(context); QPointer<QObject> providerObject(object);
        const auto current = [this, alive, owner, providerObject, name, token] {
            if (!alive || !owner || !owner->active() || !providerObject) return false;
            const auto service = d->services.value(name);
            return service.token == token && service.owner == owner && service.object == providerObject &&
                d->packages.value(owner->packageId()).context == owner;
        };
        const auto rejectProvider = [this, alive, name, token] {
            if (alive && d->services.value(name).token == token) {
                d->services.remove(name); d->serviceDirty = true; schedule();
            }
            return false;
        };
        const auto package = d->packages.value(context->packageId());
        if (!package.manifest.contains("native")) return rejectProvider();
        QString role, contract;
        try {
            role = provider->role();
            if (!current()) return rejectProvider();
            contract = provider->contractId();
        } catch (...) { return rejectProvider(); }
        if (!current() || !PackageValidation::identifier(role) || !PackageValidation::serviceName(contract)) return rejectProvider();
        d->services[name].providerIdentity = {{"package_id", context->packageId()}, {"service_name", name},
            {"role", role}, {"contract_id", contract}, {"package_version", package.manifest.value("version")},
            {"package_fingerprint", package.manifest.value("_fingerprint")},
            {"configuration_fingerprint", QString::fromLatin1(QCryptographicHash::hash(
                PackageValidation::json(package.configuration), QCryptographicHash::Sha256).toHex())},
            {"title", package.manifest.value("title", context->packageId())}};
    }
    d->serviceDirty = true; schedule(); return true;
}
void PluginPackageRuntime::release(PluginContext *context) {
    QList<quint64> retiredTokens;
    for (auto it = d->services.begin(); it != d->services.end();) {
        if (!it->foundation && it->owner == context) {
            retiredTokens.append(it->token); it = d->services.erase(it); d->serviceDirty = true;
        }
        else ++it;
    }
    // The context is already inactive, but its native session still exists.
    // Stop every transferred endpoint before provider session.stop() can run.
    QPointer<PluginPackageRuntime> alive(this);
    for (const auto token : retiredTokens) {
        revokeProvider(token, QStringLiteral("插件能力已停用或作用域退役；旧租约不能重新启用"));
        if (!alive) return;
    }
    if (!d->destroying) { invalidateDependencies(); schedule(); }
}
void PluginPackageRuntime::retirePackage(const QString &id) {
    auto context = d->packages[id].context;
    d->packages[id].context = nullptr; d->packages[id].panels.clear(); d->packages[id].creatingPanels.clear();
    d->packages[id].attested = d->packages[id].ready = false;
    if (context) { context->dispose(); if (context) context->deleteLater(); }
}
void PluginPackageRuntime::invalidateDependencies() {
    if (d->destroying || d->invalidating) return;
    d->invalidating = true;
    // Every pass retires at least one context; at most64 packages participate.
    for (int pass = 0; pass < PackageValidation::MaximumPackages; ++pass) {
        QStringList retire;
        for (auto it = d->packages.cbegin(); it != d->packages.cend(); ++it)
            if (it->context && !d->missing(it.value()).isEmpty()) retire.append(it.key());
        if (retire.isEmpty()) break;
        for (const auto &id : retire) retirePackage(id);
    }
    d->invalidating = false;
}
void PluginPackageRuntime::schedule() {
    if (d->destroying || d->scheduled) return;
    d->scheduled = true; const auto generation = d->generation;
    QTimer::singleShot(0, this, [this, generation] {
        if (generation != d->generation) return;
        d->scheduled = false; reconcile();
    });
}
void PluginPackageRuntime::reconcile() {
    if (d->destroying || d->reconciling) return;
    d->reconciling = true;
    invalidateDependencies();
    QPointer<PluginPackageRuntime> alive(this); const auto generation = d->generation;
    const auto ids = d->packages.keys();
    for (const auto &id : ids) {
        auto p = d->packages.value(id);
        if (p.context || p.blocked || !p.installed || (!p.enabled && !p.restorePending)) continue;
        if (d->locked || !d->missing(p).isEmpty()) { d->packages[id].attested = false; continue; }
        if (!d->engine || !d->fileValid || !d->journalValid || !scopeValid(d->scope)) continue;
        QVariantList freshScopes, freshBlocks; QString attestationError;
        d->fileValid = PackageValidation::store(d->file, &freshScopes, &attestationError);
        d->journalValid = disableJournal(d->journalFile(), &freshBlocks, &attestationError);
        const auto saved = savedValues(freshScopes, d->scope, id);
        const bool authorized = d->fileValid && d->journalValid && saved.value("enabled").toBool() &&
            saved.value("version") == p.manifest.value("version") && saved.value("fingerprint") == p.manifest.value("_fingerprint") &&
            saved.value("values").toMap() == p.configuration && !disabled(freshBlocks, d->scope, id);
        if (d->fileValid) d->scopes = freshScopes;
        if (d->journalValid) d->disabledScopes = freshBlocks;
        QVariantMap currentManifest;
        const bool attestAtActivation = !p.attested || p.manifest.contains("native");
        if (!authorized || (attestAtActivation && (!PackageValidation::manifest(p.path, &currentManifest, &attestationError) ||
            currentManifest.value("_fingerprint") != p.manifest.value("_fingerprint")))) {
            auto &failed = d->packages[id]; failed.enabled = failed.restorePending = failed.restored = failed.attested = false;
            failed.blocked = true; failed.error = attestationError.isEmpty() ? QStringLiteral("插件内容或保存授权已改变；重新扫描、查看配置并显式启用") : attestationError;
            continue;
        }
        d->packages[id].enabled = true; d->packages[id].attested = false;
        if (p.restorePending) { d->packages[id].restored = true; d->packages[id].restorePending = false; }
        auto *context = new PluginContext(this, d->engine, id, p.manifest, p.configuration);
        d->packages[id].context = context;
        connect(context, &PluginContext::errorOccurred, this, [this, id, context](const QString &message) {
            if (d->packages.value(id).context != context) return;
            d->packages[id].error = message.left(1024); emit changed();
        });
        QString error;
        if (p.manifest.contains("native")) {
            auto *factory = NativePackageLoader::load(p.manifest, &error);
            if (!alive || generation != d->generation) return;
            if (d->packages.value(id).context != context || !context->active()) continue;
            const bool started = factory && context->startNative(factory, &error);
            if (!alive || generation != d->generation) return;
            if (d->packages.value(id).context != context || !context->active()) continue;
            if (!started) {
                d->packages[id].error = error.isEmpty() ? QStringLiteral("Native package startup failed") : error;
                d->packages[id].blocked = true; retirePackage(id);
                continue;
            }
        }
        QQmlComponent component(context->qmlContext()->engine(), QUrl::fromLocalFile(QDir(p.path).filePath(p.manifest.value("entry").toString())), QQmlComponent::PreferSynchronous);
        QPointer<QObject> root;
        if (component.isReady()) {
            root = component.beginCreate(context->qmlContext());
            if (root) { root->setParent(context); context->remember(root); }
            if (root) component.completeCreate();
        }
        if (!alive || generation != d->generation) return;
        if (d->packages.value(id).context != context || !context->active()) continue;
        if (!root || component.isError() || !component.isReady()) error = componentError(component).isEmpty() ? QStringLiteral("QML entry must load synchronously from the installed package") : componentError(component);
        if (!d->packages.value(id).error.isEmpty()) error = d->packages.value(id).error;
        for (const auto &exported : p.manifest.value("services").toMap().value("exports").toList())
            if (d->services.value(exported.toString()).owner != context) error = QStringLiteral("Entry did not register its declared export: ") + exported.toString();
        if (!error.isEmpty()) {
            d->packages[id].error = error; d->packages[id].blocked = true; retirePackage(id);
        } else d->packages[id].ready = true;
    }
    if (!alive || generation != d->generation) return;
    d->reconciling = false;
    if (d->serviceDirty) {
        d->serviceDirty = false;
        QList<QPointer<PluginContext>> contexts;
        for (const auto &p : std::as_const(d->packages)) if (p.context) contexts.append(p.context);
        for (const auto &context : contexts) {
            if (context) context->notifyServices();
            if (!alive || generation != d->generation) return;
        }
    }
    emit changed();
}
bool PluginPackageRuntime::rescan() {
    // Discovery is read-only and remains available while match settings lock.
    if (d->destroying) return false;
    if (d->directory.isEmpty()) return reject(QStringLiteral("本地插件根目录未配置，未扫描工作目录"));
    const QFileInfo root(d->directory);
    if (root.isSymLink()) return reject(QStringLiteral("插件目录不能为符号链接"));
    QStringList seen;
    const auto directories = QDir(d->directory).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    if (directories.size() > PackageValidation::MaximumPackages) return reject(QStringLiteral("本地插件目录超过64项，未截断加载"));
    for (const auto &entry : directories) {
        if (entry.fileName().startsWith('.')) continue;
        QVariantMap manifest; QString error;
        const bool valid = !entry.isSymLink() && PackageValidation::manifest(entry.absoluteFilePath(), &manifest, &error);
        const auto id = valid ? manifest.value("id").toString() : entry.fileName();
        if (seen.contains(id)) return reject(QStringLiteral("发现重复插件标识：") + id);
        seen.append(id);
        auto old = d->packages.value(id);
        if (!valid || (!old.manifest.isEmpty() && old.manifest.value("_fingerprint") != manifest.value("_fingerprint"))) {
            d->packages[id].enabled = d->packages[id].restorePending = d->packages[id].restored = false;
            retirePackage(id); old = d->packages.value(id);
        }
        Private::Package p = old; p.path = entry.canonicalFilePath(); p.installed = true;
        if (!valid) { p.path = entry.absoluteFilePath(); p.error = error.isEmpty() ? QStringLiteral("无效的本地插件目录") : error; p.blocked = true; p.manifest = {}; }
        else {
            p.manifest = manifest;
            if (!old.context) { p.error.clear(); p.blocked = false; }
            p.configuration = manifest.value("configuration").toMap().value("defaults").toMap(); p.configured = false;
            const auto saved = savedValues(d->scopes, d->scope, id);
            if (!saved.isEmpty() && saved.value("version") == manifest.value("version") && PackageValidation::configuration(manifest.value("configuration").toMap().value("schema").toMap(), saved.value("values").toMap())) {
                p.configuration = saved.value("values").toMap(); p.configured = true;
            }
            if (old.context && (p.configuration != old.configuration || !p.configured)) {
                d->packages[id].enabled = d->packages[id].restorePending = d->packages[id].restored = false;
                retirePackage(id); p.context = nullptr; p.panels.clear(); p.enabled = p.restorePending = p.restored = p.attested = p.ready = false;
            }
        }
        d->packages[id] = p;
    }
    const auto ids = d->packages.keys();
    for (const auto &id : ids) if (!seen.contains(id)) {
        d->packages[id].enabled = d->packages[id].restorePending = false; retirePackage(id); d->packages.remove(id);
    }
    if (d->fileValid && d->journalValid) d->status = QStringLiteral("已读取本地插件清单；未知／新增／变更包均未自动启用");
    schedule(); emit changed(); return true;
}
bool PluginPackageRuntime::saveConfiguration(const QString &id, const QVariantMap &values) {
    if (!editable()) return reject(lockReason());
    const auto package = d->packages.value(id); QString error;
    if (package.manifest.isEmpty() || !package.installed || !PackageValidation::configuration(package.manifest.value("configuration").toMap().value("schema").toMap(), values, &error))
        return reject(error.isEmpty() ? QStringLiteral("插件未安装或清单无效") : error);
    const bool keepEnabled = package.enabled || package.restorePending;
    if (!d->persist(id, reviewedRecord(package.manifest, values, keepEnabled), false, nullptr, &error)) {
        d->packages[id].persistenceError = error; return reject(error);
    }
    QPointer<PluginPackageRuntime> alive(this); const auto generation = d->generation;
    retirePackage(id);
    if (!alive || generation != d->generation || !d->packages.contains(id)) return false;
    d->packages[id].configuration = values; d->packages[id].configured = true; d->packages[id].blocked = false; d->packages[id].error.clear(); d->packages[id].persistenceError.clear();
    d->status = QStringLiteral("当前范围的插件配置已原子保存；已启用的包按依赖重新装配");
    schedule(); emit changed(); return true;
}
bool PluginPackageRuntime::setEnabled(const QString &id, bool enabled) {
    if (!d->packages.contains(id)) return reject(QStringLiteral("未知插件标识；原生基础服务不属于可移除插件列表"));
    if (!enabled) {
        const auto package = d->packages.value(id); bool durable = false; QString error;
        const auto record = package.configured && !package.manifest.isEmpty() ? reviewedRecord(package.manifest, package.configuration, false) : QVariantMap{};
        const bool saved = d->persist(id, record, false, &durable, &error);
        QPointer<PluginPackageRuntime> alive(this); const auto generation = d->generation;
        d->packages[id].enabled = d->packages[id].restorePending = d->packages[id].restored = false;
        retirePackage(id);
        if (!alive || generation != d->generation || !d->packages.contains(id)) return false;
        d->packages[id].blocked = false; d->packages[id].error.clear(); d->packages[id].persistenceError = saved ? QString{} : error;
        d->status = saved ? QStringLiteral("插件停用状态已保存；其必需消费者等待依赖，基础功能继续运行") :
            durable ? QStringLiteral("插件已停止；主保存失败，持久停用记录已阻止重启恢复：") + error :
                      QStringLiteral("插件本进程已停止，但无法保存停用状态；下次启动前须修复配置写入：") + error;
        schedule(); emit changed(); return saved;
    }
    if (!editable()) return reject(lockReason());
    auto package = d->packages.value(id); QString error;
    if (package.manifest.isEmpty() || !package.installed) return reject(QStringLiteral("先修复或安装有效插件包"));
    if (!package.configured) return reject(QStringLiteral("先查看并保存当前范围的插件配置，再显式启用"));
    QVariantMap current;
    if (!PackageValidation::manifest(package.path, &current, &error) || current.value("_fingerprint") != package.manifest.value("_fingerprint"))
        return reject(error.isEmpty() ? QStringLiteral("插件内容已改变；先重新扫描并查看配置，再显式启用") : error);
    if (current.contains("native") && NativePackageLoader::restartRequired(current.value("_native_library").toString(), current.value("_native_fingerprint").toString()))
        return reject(QStringLiteral("原生库已更新；Qt仍保留旧库，重启应用后才能启用此版本"));
    if (!d->persist(id, reviewedRecord(current, package.configuration, true), true, nullptr, &error)) {
        d->packages[id].persistenceError = error; return reject(error);
    }
    d->packages[id].enabled = true; d->packages[id].restorePending = d->packages[id].restored = false;
    d->packages[id].attested = true; d->packages[id].blocked = false; d->packages[id].error.clear(); d->packages[id].persistenceError.clear();
    d->status = QStringLiteral("本范围的启用请求与完整内容指纹已保存；仅在必需服务满足且配置解锁后装配");
    schedule(); emit changed(); return true;
}
QObject *PluginPackageRuntime::contextFor(const QString &id) const {
    const auto package = d->packages.value(id); const auto context = package.context;
    return package.ready && context && context->active() ? context.data() : nullptr;
}
QObject *PluginPackageRuntime::createPanel(const QString &id, const QString &panelId, QObject *owner) {
    if (QThread::currentThread() != thread()) return nullptr;
    const auto package = d->packages.value(id); auto context = package.context;
    if (package.manifest.isEmpty() || !package.installed) {
        reject(QStringLiteral("未发现有效的本地插件包，无法打开其面板")); return nullptr;
    }
    if (!package.ready || !context || !context->active()) {
        reject(QStringLiteral("插件尚未运行或依赖已失效；面板未打开")); return nullptr;
    }
    if (package.panels.value(panelId) || package.creatingPanels.contains(panelId)) {
        reject(QStringLiteral("该插件面板正在创建或已由另一个宿主持有；先关闭现有面板")); return nullptr;
    }
    QVariantMap panel;
    for (const auto &entry : package.manifest.value("panels").toList()) if (entry.toMap().value("id") == panelId) panel = entry.toMap();
    if (panel.isEmpty()) {
        reject(QStringLiteral("插件清单未声明此面板，未加载任意QML路径")); return nullptr;
    }
    if (owner && owner->thread() != thread()) {
        reject(QStringLiteral("插件面板宿主须位于界面线程")); return nullptr;
    }
    QPointer<PluginPackageRuntime> alive(this); QPointer<QObject> parentGuard(owner); const auto generation = d->generation;
    // Component construction/completion can synchronously call host services.
    // Reserve before either step so a reentrant open cannot create a second
    // instance and overwrite the outer call's eventual recorded panel.
    d->packages[id].creatingPanels.insert(panelId);
    const auto finishCreation = qScopeGuard([this, alive, id, panelId, context] {
        if (!alive || !context) return;
        auto current = d->packages.find(id);
        if (current != d->packages.end() && current->context == context)
            current->creatingPanels.remove(panelId);
    });
    QQmlComponent component(context->qmlContext()->engine(), QUrl::fromLocalFile(QDir(package.path).filePath(panel.value("entry").toString())), QQmlComponent::PreferSynchronous);
    if (!alive || generation != d->generation || !context || !context->active() || (owner && !parentGuard)) return nullptr;
    if (!component.isReady()) {
        const auto error = componentError(component);
        reject(error.isEmpty() ? QStringLiteral("插件面板未能从本地包同步加载") : error); return nullptr;
    }
    QPointer<QObject> object = component.beginCreate(context->qmlContext());
    if (object) { object->setParent(owner ? owner : context.data()); context->remember(object); }
    if (object) component.completeCreate();
    if (!alive || generation != d->generation || !context || !context->active() || (owner && !parentGuard)) { if (object) object->deleteLater(); return nullptr; }
    if (!object || component.isError() || !object->inherits("QQuickItem")) {
        if (object)
            object->deleteLater();
        reject(QStringLiteral("插件面板须为有效的QQuickItem：") + componentError(component));
        return nullptr;
    }
    d->packages[id].panels[panelId] = object; return object.data();
}
bool PluginPackageRuntime::releasePanel(const QString &id, const QString &panelId, QObject *owner) {
    if (QThread::currentThread() != thread() || !owner || owner->thread() != thread()) return false;
    auto package = d->packages.find(id);
    if (package == d->packages.end()) return false;
    QPointer<QObject> panel = package->panels.value(panelId);
    if (!panel || panel->parent() != owner) return false;
    // Property changes can synchronously reopen/retire a package. Remove only
    // this lease before calling QML, and never touch the map after callbacks.
    package->panels.remove(panelId);
    panel->setProperty("enabled", false);
    if (panel) panel->setProperty("visible", false);
    if (panel) panel->deleteLater();
    return true;
}
bool PluginPackageRuntime::installDirectory(const QString &directory) {
    if (!editable()) return reject(lockReason());
    QVariantMap manifest; QStringList files; QString error;
    if (!PackageValidation::manifest(directory, &manifest, &error) || !PackageValidation::files(directory, &files, &error)) return reject(error);
    const auto id = manifest.value("id").toString();
    if (d->packages.value(id).enabled || d->packages.value(id).restorePending || d->packages.value(id).context) return reject(QStringLiteral("先停用该插件，再更新本地安装"));
    if (QFileInfo(d->directory).isSymLink() || !QDir().mkpath(d->directory)) return reject(QStringLiteral("插件根目录无效或不可写"));
    QLockFile lock(QDir(d->directory).filePath(".packages.lock")); if (!lock.tryLock(0)) return reject(QStringLiteral("另一个插件安装操作正在进行"));
    const QDir root(d->directory); const auto destination = root.filePath(id);
    if (QFileInfo(destination).isSymLink() || QFileInfo(directory).canonicalFilePath() == QFileInfo(destination).canonicalFilePath()) return reject(QStringLiteral("安装源不能是目标目录或符号链接"));
    if (QFileInfo::exists(destination)) {
        QVariantMap previous;
        if (!PackageValidation::manifest(destination, &previous, &error) || previous.value("id") != id)
            return reject(QStringLiteral("目标不是有效的同名插件包，未覆盖其原文件"));
    }
    const auto staging = root.filePath(".install-" + QUuid::createUuid().toString(QUuid::WithoutBraces));
    if (!QDir().mkpath(staging)) return reject(QStringLiteral("插件临时安装目录不可写"));
    qsizetype copied = 0;
    for (const auto &name : files) {
        const auto source = QDir(directory).filePath(name), target = QDir(staging).filePath(name); const QFileInfo info(source);
        QFile input(source), output(target);
        if (info.isSymLink() || !info.isFile() || !info.canonicalFilePath().startsWith(QFileInfo(directory).canonicalFilePath() + '/') ||
            !QDir().mkpath(QFileInfo(target).absolutePath()) || !input.open(QIODevice::ReadOnly) || !output.open(QIODevice::WriteOnly | QIODevice::NewOnly)) {
            QDir(staging).removeRecursively(); return reject(QStringLiteral("插件复制遇到路径变化或不可读文件，未替换安装"));
        }
        const auto bytes = input.read(8 * 1024 * 1024 + 1);
        if (bytes.size() > 8 * 1024 * 1024 || (copied += bytes.size()) > 32 * 1024 * 1024 || output.write(bytes) != bytes.size()) {
            output.close(); QDir(staging).removeRecursively(); return reject(QStringLiteral("插件复制超过限额或写入失败"));
        }
        output.close();
    }
    QVariantMap installed;
    if (!PackageValidation::manifest(staging, &installed, &error) || installed.value("id") != id || installed.value("version") != manifest.value("version") ||
        installed.value("_fingerprint") != manifest.value("_fingerprint")) {
        QDir(staging).removeRecursively(); return reject(error.isEmpty() ? QStringLiteral("复制期间插件清单改变") : error);
    }
    // Installing/replacing is not execution approval, even if an old record has
    // the same id/version. The explicit Enable operation clears this latch.
    if (!d->persist(id, {}, false, nullptr, &error)) { QDir(staging).removeRecursively(); return reject(error); }
    const auto backup = root.filePath(".rollback-" + QUuid::createUuid().toString(QUuid::WithoutBraces)); const bool previous = QFileInfo::exists(destination);
    if ((previous && !QDir().rename(destination, backup)) || !QDir().rename(staging, destination)) {
        if (previous && QFileInfo::exists(backup)) QDir().rename(backup, destination);
        QDir(staging).removeRecursively(); return reject(QStringLiteral("插件原子安装失败，已保留或恢复原目录"));
    }
    if (previous) QDir(backup).removeRecursively();
    if (!rescan()) return false;
    d->status = QStringLiteral("插件已本地安装，未启用；没有执行安装脚本或下载依赖"); emit changed(); return true;
}
bool PluginPackageRuntime::uninstall(const QString &id) {
    if (!editable()) return reject(lockReason());
    const auto package = d->packages.value(id);
    const QFileInfo root(d->directory), destination(QDir(d->directory).filePath(id));
    if (!d->packages.contains(id) || package.manifest.isEmpty() || package.manifest.value("id") != id ||
        !PackageValidation::identifier(id) || package.enabled || package.restorePending || package.context ||
        root.isSymLink() || destination.isSymLink() || !destination.isDir() ||
        !destination.canonicalFilePath().startsWith(root.canonicalFilePath() + '/') ||
        QFileInfo(package.path).canonicalFilePath() != destination.canonicalFilePath())
        return reject(QStringLiteral("只能移除已停用的本地插件包；基础服务不能移除"));
    QLockFile lock(QDir(d->directory).filePath(".packages.lock"));
    if (!lock.tryLock(0)) return reject(QStringLiteral("另一个插件安装操作正在进行"));
    if (!QDir(destination.absoluteFilePath()).removeRecursively()) return reject(QStringLiteral("插件目录移除失败"));
    return rescan();
}
bool PluginPackageRuntime::publish(PluginContext *context, const QString &channel, const QVariantMap &payload) {
    if (!context || !context->active() || !PackageValidation::bounded(payload, 4096) || d->messages.size() >= 64 || d->sequence >= 9007199254740991ULL) return false;
    QVariantMap envelope{{"schema", 1}, {"channel", channel}, {"publisher", context->packageId()}, {"sequence", qulonglong(++d->sequence)},
        {"produced_at_ms", QDateTime::currentMSecsSinceEpoch()}, {"payload", payload}, {"authoritative", false}, {"execution_allowed", false}};
    const auto bytes = PackageValidation::json(envelope).size(); if (d->messageBytes + bytes > 256 * 1024) return false;
    d->messages.enqueue({context, envelope, bytes, false}); d->messageBytes += bytes;
    if (!d->messageScheduled) {
        d->messageScheduled = true; const auto generation = d->generation;
        QTimer::singleShot(0, this, [this, generation] { if (generation == d->generation) drainMessages(); });
    }
    return true;
}
bool PluginPackageRuntime::publishFoundation(const QString &channel, const QVariantMap &payload) {
    if (QThread::currentThread() != thread() || !PackageValidation::serviceName(channel) || !PackageValidation::bounded(payload, 4096) || d->messages.size() >= 64 || d->sequence >= 9007199254740991ULL) return false;
    QVariantMap envelope{{"schema", 1}, {"channel", channel}, {"publisher", "native-foundation"}, {"sequence", qulonglong(++d->sequence)},
        {"produced_at_ms", QDateTime::currentMSecsSinceEpoch()}, {"payload", payload}, {"authoritative", false}, {"execution_allowed", false}};
    const auto bytes = PackageValidation::json(envelope).size(); if (d->messageBytes + bytes > 256 * 1024) return false;
    d->messages.enqueue({{}, envelope, bytes, true}); d->messageBytes += bytes;
    if (!d->messageScheduled) {
        d->messageScheduled = true; const auto generation = d->generation;
        QTimer::singleShot(0, this, [this, generation] { if (generation == d->generation) drainMessages(); });
    }
    return true;
}
void PluginPackageRuntime::drainMessages() {
    d->messageScheduled = false;
    QPointer<PluginPackageRuntime> alive(this); const auto generation = d->generation;
    for (int quota = 0; quota < 16 && !d->messages.isEmpty(); ++quota) {
        const auto message = d->messages.dequeue(); d->messageBytes -= message.bytes;
        if (!message.foundation && (!message.sender || !message.sender->active())) continue;
        QList<QPointer<PluginContext>> contexts;
        for (const auto &p : std::as_const(d->packages)) if (p.context) contexts.append(p.context);
        for (const auto &context : contexts) {
            if (!message.foundation && (!message.sender || !message.sender->active())) break;
            if (context) context->deliver(message.envelope.value("channel").toString(), message.envelope);
            if (!alive || generation != d->generation) return;
        }
    }
    if (!d->messages.isEmpty() && !d->messageScheduled) {
        d->messageScheduled = true;
        QTimer::singleShot(0, this, [this, generation] { if (generation == d->generation) drainMessages(); });
    }
}
