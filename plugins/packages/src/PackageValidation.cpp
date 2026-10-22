#include "PackageValidation.h"
#include "ExtensionPackage.h"
#include <QCryptographicHash>
#include <QDir>
#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLibrary>
#include <QPluginLoader>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <cmath>

namespace PackageValidation {
bool fail(QString *error, const QString &message) { if (error) *error = message; return false; }
QByteArray json(const QVariant &value) { return QJsonDocument::fromVariant(value).toJson(QJsonDocument::Compact); }
namespace {
bool text(const QVariant &v, int limit, bool empty = false) {
    if (v.metaType().id() != QMetaType::QString || v.toString().size() > limit || (!empty && v.toString().isEmpty())) return false;
    for (const auto c : v.toString()) if (c.isNull() || c.category() == QChar::Other_Control) return false;
    return true;
}
bool number(const QVariant &v, double *out = nullptr) {
    const auto t = v.metaType().id();
    if (t != QMetaType::Int && t != QMetaType::UInt && t != QMetaType::LongLong && t != QMetaType::ULongLong && t != QMetaType::Double && t != QMetaType::Float) return false;
    const auto n = v.toDouble(); if (!std::isfinite(n) || std::abs(n) > 9007199254740991.0) return false;
    if (out) *out = n;
    return true;
}
bool integer(const QVariant &v, int low, int high) { double n = 0; return number(v, &n) && std::floor(n) == n && n >= low && n <= high; }
bool keys(const QVariantMap &m, const QSet<QString> &required, const QSet<QString> &optional = {}) {
    for (const auto &k : required) if (!m.contains(k)) return false;
    for (auto it = m.cbegin(); it != m.cend(); ++it) if (!required.contains(it.key()) && !optional.contains(it.key())) return false;
    return true;
}
bool primitive(const QVariant &v, int depth, int *nodes, qsizetype *cost, qsizetype maximum) {
    if (++*nodes > 8192 || depth > 10 || *cost > maximum * 2) return false;
    if (!v.isValid() || v.isNull()) { *cost += 4; return true; }
    const auto t = v.metaType().id();
    if (t == QMetaType::QVariantMap) {
        const auto m = v.toMap(); if (m.size() > 128) return false;
        for (auto it = m.cbegin(); it != m.cend(); ++it) {
            if (!text(it.key(), 128)) return false;
            *cost += it.key().size() * 2 + 4;
            if (!primitive(it.value(), depth + 1, nodes, cost, maximum)) return false;
        }
    } else if (t == QMetaType::QVariantList) {
        const auto list = v.toList(); if (list.size() > 128) return false;
        for (const auto &x : list) if (!primitive(x, depth + 1, nodes, cost, maximum)) return false;
    } else if (t == QMetaType::QString) {
        if (!text(v, 8192, true)) return false;
        *cost += v.toString().size() * 2 + 2;
    } else if (t == QMetaType::Bool) *cost += 5;
    else { if (!number(v)) return false; *cost += 24; }
    return *cost <= maximum * 2;
}
bool names(const QVariant &v, bool versioned) {
    if (v.metaType().id() != QMetaType::QVariantList || v.toList().size() > 32) return false;
    QSet<QString> seen;
    for (const auto &x : v.toList()) {
        if (!text(x, 96) || !(versioned ? serviceName(x.toString()) : identifier(x.toString())) || seen.contains(x.toString())) return false;
        seen.insert(x.toString());
    }
    return true;
}
bool schemaNode(const QVariantMap &s, int depth, int *nodes) {
    if (++*nodes > 128 || depth > 6 || !text(s.value("type"), 16)) return false;
    const auto type = s.value("type").toString();
    QSet<QString> optional{"title", "description"};
    if (s.contains("title") && !text(s.value("title"), 128)) return false;
    if (s.contains("description") && !text(s.value("description"), 512, true)) return false;
    if (type == "object") {
        if (!keys(s, {"type", "properties", "required", "additionalProperties"}, optional) || s.value("properties").metaType().id() != QMetaType::QVariantMap ||
            s.value("properties").toMap().size() > 32 || s.value("required").metaType().id() != QMetaType::QVariantList ||
            s.value("additionalProperties").metaType().id() != QMetaType::Bool || s.value("additionalProperties") != QVariant(false)) return false;
        const auto properties = s.value("properties").toMap(); QSet<QString> seen;
        for (const auto &r : s.value("required").toList()) {
            if (!text(r, 96) || !properties.contains(r.toString()) || seen.contains(r.toString())) return false;
            seen.insert(r.toString());
        }
        for (auto it = properties.cbegin(); it != properties.cend(); ++it)
            if (!text(it.key(), 96) || it.value().metaType().id() != QMetaType::QVariantMap || !schemaNode(it.value().toMap(), depth + 1, nodes)) return false;
        return true;
    }
    if (type == "array") {
        optional.unite({"minItems"});
        return keys(s, {"type", "items", "maxItems"}, optional) && s.value("items").metaType().id() == QMetaType::QVariantMap &&
            integer(s.value("maxItems"), 0, 64) && (!s.contains("minItems") || integer(s.value("minItems"), 0, s.value("maxItems").toInt())) &&
            schemaNode(s.value("items").toMap(), depth + 1, nodes);
    }
    optional.insert("enum");
    if (type == "string") optional.unite({"minLength", "maxLength"});
    else if (type == "number" || type == "integer") optional.unite({"minimum", "maximum"});
    else if (type != "boolean") return false;
    if (!keys(s, {"type"}, optional)) return false;
    if (s.contains("enum") && (s.value("enum").metaType().id() != QMetaType::QVariantList || s.value("enum").toList().isEmpty() || s.value("enum").toList().size() > 32)) return false;
    if (s.contains("minLength") && !integer(s.value("minLength"), 0, 4096)) return false;
    if (s.contains("maxLength") && !integer(s.value("maxLength"), s.value("minLength", 0).toInt(), 4096)) return false;
    if (s.contains("minimum") && !number(s.value("minimum"))) return false;
    if (s.contains("maximum") && (!number(s.value("maximum")) || (s.contains("minimum") && s.value("maximum").toDouble() < s.value("minimum").toDouble()))) return false;
    return true;
}
bool configNode(const QVariantMap &s, const QVariant &v, int depth) {
    if (depth > 6) return false;
    const auto type = s.value("type").toString();
    if (type == "object") {
        if (v.metaType().id() != QMetaType::QVariantMap) return false;
        const auto m = v.toMap(), properties = s.value("properties").toMap();
        for (const auto &r : s.value("required").toList()) if (!m.contains(r.toString())) return false;
        for (auto it = m.cbegin(); it != m.cend(); ++it)
            if (!properties.contains(it.key()) || !configNode(properties.value(it.key()).toMap(), it.value(), depth + 1)) return false;
    } else if (type == "array") {
        if (v.metaType().id() != QMetaType::QVariantList || v.toList().size() < s.value("minItems", 0).toInt() || v.toList().size() > s.value("maxItems").toInt()) return false;
        for (const auto &x : v.toList()) if (!configNode(s.value("items").toMap(), x, depth + 1)) return false;
    } else if (type == "string") {
        if (!text(v, s.value("maxLength", 4096).toInt(), true) || v.toString().size() < s.value("minLength", 0).toInt()) return false;
    } else if (type == "boolean") { if (v.metaType().id() != QMetaType::Bool) return false; }
    else {
        double n = 0;
        if (!number(v, &n) || (type == "integer" && std::floor(n) != n) ||
            (s.contains("minimum") && n < s.value("minimum").toDouble()) || (s.contains("maximum") && n > s.value("maximum").toDouble())) return false;
    }
    if (s.contains("enum")) {
        bool found = false;
        for (const auto &candidate : s.value("enum").toList()) found = found || json(QVariantList{v}) == json(QVariantList{candidate});
        if (!found) return false;
    }
    return true;
}
bool relativeQml(const QString &directory, const QVariant &value) {
    if (!text(value, 256) || !value.toString().endsWith(".qml") || QDir::isAbsolutePath(value.toString()) || value.toString().contains('\\') || value.toString().contains(':')) return false;
    for (const auto &part : value.toString().split('/')) if (part.isEmpty() || part == "." || part == "..") return false;
    const auto root = QFileInfo(directory).canonicalFilePath();
    const QFileInfo file(QDir(directory).filePath(value.toString()));
    return file.isFile() && !file.isSymLink() && file.canonicalFilePath().startsWith(root + '/');
}
bool readManifest(const QString &directory, QByteArray *bytes, QVariantMap *manifest, QString *error) {
    const auto path = QDir(directory).filePath("rmplugin.json");
    const QFileInfo info(path); QFile input(path);
    if (!info.isFile() || info.isSymLink() || !input.open(QIODevice::ReadOnly)) return fail(error, "rmplugin.json cannot be read");
    *bytes = input.read(MaximumManifestBytes + 1);
    QJsonParseError parse; const auto document = QJsonDocument::fromJson(*bytes, &parse);
    if (input.error() != QFileDevice::NoError || bytes->size() > MaximumManifestBytes || parse.error != QJsonParseError::NoError ||
        !document.isObject() || !bounded(document.toVariant())) return fail(error, "Invalid or oversized rmplugin.json");
    *manifest = document.toVariant().toMap();
    return true;
}
bool nativeLibrary(const QString &directory, const QVariantMap &manifest, QString *relative, QString *error) {
    relative->clear();
    if (!manifest.contains("native")) return true;
    const auto value = manifest.value("native");
    const auto native = value.toMap();
    if (value.metaType().id() != QMetaType::QVariantMap || !keys(native, {"library"}) || !text(native.value("library"), 256))
        return fail(error, "native must contain exactly one local shared-library path");
    const auto path = native.value("library").toString();
    if (QDir::isAbsolutePath(path) || path.contains('\\') || path.contains(':') || !QLibrary::isLibrary(path))
        return fail(error, "native.library must name a shared library for this platform");
    for (const auto &part : path.split('/')) if (part.isEmpty() || part == "." || part == "..")
        return fail(error, "native.library cannot contain an escaping or ambiguous path");
    const auto root = QFileInfo(directory).canonicalFilePath();
    const QFileInfo library(QDir(directory).filePath(path));
    if (root.isEmpty() || !library.isFile() || library.isSymLink() || !library.canonicalFilePath().startsWith(root + '/'))
        return fail(error, "native.library must be a real file inside its package");
    *relative = path;
    return true;
}
bool nativeMetadata(const QString &library, const QString &id, QString *error) {
    // metaData() inspects Qt's embedded metadata without loading the library or
    // constructing a plugin. Discovery/install must never execute native code.
    const auto metadata = QPluginLoader(library).metaData();
    const auto plugin = metadata.value("MetaData").toObject();
    if (metadata.value("IID").toString() != QString::fromLatin1(ExtensionPackagePlugin_iid) ||
        !plugin.value("id").isString() || plugin.value("id").toString() != id ||
        !plugin.value("apiMajor").isDouble() || plugin.value("apiMajor").toDouble() != 1)
        return fail(error, "Native Qt plugin metadata does not match the package id/API/interface");
    return true;
}
}
bool bounded(const QVariant &v, qsizetype maximum) { int nodes = 0; qsizetype cost = 0; return primitive(v, 0, &nodes, &cost, maximum) && json(v).size() <= maximum; }
bool identifier(const QString &value) {
    static const QRegularExpression re("\\A[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*\\z");
    return value.size() <= 64 && re.match(value).hasMatch();
}
bool serviceName(const QString &value) {
    static const QRegularExpression re("\\A[a-z][a-z0-9_.-]{0,79}@[1-9][0-9]{0,3}\\z");
    return value.size() <= 96 && re.match(value).hasMatch();
}
bool schema(const QVariantMap &value, QString *error) { int nodes = 0; return (bounded(value) && value.value("type") == "object" && schemaNode(value, 0, &nodes)) || fail(error, "Unsupported bounded configuration schema"); }
bool configuration(const QVariantMap &s, const QVariantMap &values, QString *error) {
    return (schema(s, error) && bounded(values) && configNode(s, values, 0)) || fail(error, "Configuration does not match its declared schema");
}
bool files(const QString &directory, QStringList *out, QString *error) {
    out->clear();
    const QFileInfo info(directory); const auto root = info.canonicalFilePath();
    if (!info.isDir() || info.isSymLink() || root.isEmpty()) return fail(error, "Package root must be a real local directory");
    // Read only the bounded declaration before allowing a native file through
    // the installer. The complete manifest/metadata check remains in manifest().
    QByteArray manifestBytes; QVariantMap declaration; QString native;
    if (!readManifest(root, &manifestBytes, &declaration, error) || !nativeLibrary(root, declaration, &native, error)) return false;
    qsizetype bytes = 0; int directories = 0;
    const QSet<QString> ignored{".git", ".hg", ".svn", "node_modules", "build", ".cache"};
    const QSet<QString> extensions{"qml", "js", "mjs", "json", "svg", "png", "jpg", "jpeg", "webp", "gif", "ttf", "otf", "txt", "md", "qsb"};
    const auto walk = [&](auto &&self, const QString &path, int depth) -> bool {
        if (depth > 8 || ++directories > 64) return fail(error, "Package directory depth/count exceeds its limit");
        for (const auto &entry : QDir(path).entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System, QDir::Name)) {
            if (entry.isSymLink()) return fail(error, "Package symlinks are not accepted");
            if (!entry.canonicalFilePath().startsWith(root + '/')) return fail(error, "Package path escapes its root");
            if (entry.isDir()) { if (!ignored.contains(entry.fileName()) && !self(self, entry.absoluteFilePath(), depth + 1)) return false; continue; }
            const auto relative = QDir(root).relativeFilePath(entry.absoluteFilePath());
            const bool declaredNative = !native.isEmpty() && relative == native;
            if (!entry.isFile() || (!declaredNative &&
                (QLibrary::isLibrary(entry.fileName()) || (entry.fileName() != "qmldir" && entry.fileName() != "LICENSE" && entry.fileName() != "NOTICE" &&
                entry.fileName() != "AUTHORS" && !extensions.contains(entry.suffix().toLower()))))) return fail(error, "Package contains unsupported executable/native files");
            if (entry.size() > 8 * 1024 * 1024 || (bytes += entry.size()) > 32 * 1024 * 1024 || out->size() >= 256) return fail(error, "Package exceeds256 files/32MiB or an8MiB file");
            out->append(relative);
        }
        return true;
    };
    return walk(walk, root, 0);
}
bool manifest(const QString &directory, QVariantMap *out, QString *error) {
    out->clear(); QStringList entries;
    if (!files(directory, &entries, error)) return false;
    QByteArray bytes; QVariantMap m; QString native;
    if (!readManifest(directory, &bytes, &m, error) || !nativeLibrary(directory, m, &native, error)) return false;
    static const QRegularExpression version("\\A(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)(?:-[A-Za-z0-9.-]+)?(?:\\+[A-Za-z0-9.-]+)?\\z");
    if (!keys(m, {"schema", "id", "version", "apiMajor", "entry", "services", "channels", "panels", "configuration"}, {"title", "description", "license", "author", "native"}) ||
        !integer(m.value("schema"), 1, 1) || !integer(m.value("apiMajor"), 1, 1) || !text(m.value("id"), 64) || !identifier(m.value("id").toString()) ||
        m.value("id").toString().startsWith("core.") || m.value("id").toString().startsWith("foundation.") ||
        !text(m.value("version"), 96) || !version.match(m.value("version").toString()).hasMatch() || !relativeQml(directory, m.value("entry")))
        return fail(error, "Invalid package identity/API/entry or unsupported rmplugin.json schema");
    for (const auto &key : {"title", "description", "license", "author"}) if (m.contains(QLatin1String(key)) && !text(m.value(QLatin1String(key)), 512, true)) return fail(error, "Invalid package display metadata");
    const auto services = m.value("services").toMap(), channels = m.value("channels").toMap(), config = m.value("configuration").toMap();
    if (m.value("services").metaType().id() != QMetaType::QVariantMap || !keys(services, {"exports", "required", "optional"}) ||
        !names(services.value("exports"), true) || !names(services.value("required"), true) || !names(services.value("optional"), true) ||
        m.value("channels").metaType().id() != QMetaType::QVariantMap || !keys(channels, {"publish", "subscribe"}) ||
        !names(channels.value("publish"), true) || !names(channels.value("subscribe"), true) ||
        m.value("configuration").metaType().id() != QMetaType::QVariantMap || !keys(config, {"defaults", "schema"}) ||
        config.value("defaults").metaType().id() != QMetaType::QVariantMap || config.value("schema").metaType().id() != QMetaType::QVariantMap ||
        !configuration(config.value("schema").toMap(), config.value("defaults").toMap(), error)) return fail(error, "Invalid service/channel declarations or configuration defaults");
    for (const auto &name : services.value("required").toList()) if (services.value("optional").toList().contains(name) || services.value("exports").toList().contains(name)) return fail(error, "Required services must be distinct external dependencies");
    for (const auto &name : services.value("exports").toList()) if (name.toString().startsWith("core.") || name.toString().startsWith("foundation.")) return fail(error, "Packages cannot export native foundation names");
    for (const auto &name : channels.value("publish").toList()) if (name.toString().startsWith("core.") || name.toString().startsWith("foundation.")) return fail(error, "Packages cannot publish reserved foundation channels");
    if (m.value("panels").metaType().id() != QMetaType::QVariantList || m.value("panels").toList().size() > 16) return fail(error, "Invalid bounded panel descriptors");
    QSet<QString> panels;
    for (const auto &entry : m.value("panels").toList()) {
        const auto p = entry.toMap();
        if (entry.metaType().id() != QMetaType::QVariantMap || !keys(p, {"id", "title", "entry"}) || !identifier(p.value("id").toString()) ||
            !text(p.value("title"), 128) || !relativeQml(directory, p.value("entry")) || panels.contains(p.value("id").toString())) return fail(error, "Invalid, duplicated or escaping panel entry");
        panels.insert(p.value("id").toString());
    }
    // Hash the portable installed artifact, not timestamps or absolute paths.
    // Framed names/sizes avoid ambiguous concatenation; exact bytes also catch
    // same-size edits with preserved mtime. This runs only on package operations.
    entries.sort(Qt::CaseSensitive);
    QCryptographicHash digest(QCryptographicHash::Sha256);
    digest.addData(QByteArrayLiteral("RoboMasterQmlPackageSHA256/v1\n"));
    qsizetype total = 0;
    QString nativeFingerprint;
    const auto root = QFileInfo(directory).canonicalFilePath();
    for (const auto &name : entries) {
        const auto file = QDir(root).filePath(name); const QFileInfo info(file); QFile content(file);
        if (info.isSymLink() || !info.isFile() || !info.canonicalFilePath().startsWith(root + '/') ||
            !content.open(QIODevice::ReadOnly)) return fail(error, "Package changed or became unreadable during content attestation");
        const auto data = content.read(8 * 1024 * 1024 + 1);
        if (content.error() != QFileDevice::NoError || data.size() > 8 * 1024 * 1024 || (total += data.size()) > 32 * 1024 * 1024 ||
            (name == "rmplugin.json" && data != bytes)) return fail(error, "Package changed or exceeded its limit during content attestation");
        digest.addData(json(QVariantList{name, qlonglong(data.size())}));
        digest.addData(QByteArrayLiteral("\n")); digest.addData(data);
        if (name == native) nativeFingerprint = QString::fromLatin1(QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex());
    }
    const auto nativePath = native.isEmpty() ? QString() : QFileInfo(QDir(root).filePath(native)).canonicalFilePath();
    if (!native.isEmpty()) {
        if (nativeFingerprint.isEmpty()) return fail(error, "Native library was not included in the package artifact");
        if (!nativeMetadata(nativePath, m.value("id").toString(), error)) return false;
    }
    *out = m;
    (*out)["_fingerprint"] = QString::fromLatin1(digest.result().toHex());
    (*out)["_directory"] = root;
    if (!native.isEmpty()) {
        (*out)["_native_library"] = nativePath;
        (*out)["_native_fingerprint"] = nativeFingerprint;
    }
    return true;
}
bool store(const QString &file, QVariantList *scopes, QString *error) {
    scopes->clear();
    if (file.isEmpty() || QFileInfo(file).isSymLink()) return fail(error, "Package configuration file is unset or a symlink; original preserved");
    if (!QFileInfo::exists(file)) return true;
    QFile input(file); if (!input.open(QIODevice::ReadOnly)) return fail(error, "Package configuration cannot be read");
    const auto bytes = input.read(MaximumStoreBytes + 1); QJsonParseError parse; const auto doc = QJsonDocument::fromJson(bytes, &parse); const auto m = doc.toVariant().toMap();
    if (bytes.size() > MaximumStoreBytes || parse.error != QJsonParseError::NoError || !doc.isObject() || !keys(m, {"schema", "scopes"}) ||
        !integer(m.value("schema"), 1, 1) || m.value("scopes").metaType().id() != QMetaType::QVariantList || m.value("scopes").toList().size() > 16)
        return fail(error, "Corrupt/unknown package configuration preserved; no automatic reset");
    QSet<QByteArray> seen;
    for (const auto &entry : m.value("scopes").toList()) {
        const auto row = entry.toMap(), scope = row.value("scope").toMap(), packages = row.value("packages").toMap();
        if (!keys(row, {"scope", "packages"}) || row.value("scope").metaType().id() != QMetaType::QVariantMap || scope.isEmpty() || scope.size() > 8 ||
            row.value("packages").metaType().id() != QMetaType::QVariantMap || packages.size() > MaximumPackages || seen.contains(json(scope)))
            return fail(error, "Invalid/duplicate package configuration scope preserved");
        for (auto it = scope.cbegin(); it != scope.cend(); ++it) if (!text(it.key(), 96) || !text(it.value(), 128)) return fail(error, "Invalid package scope identity");
        for (auto it = packages.cbegin(); it != packages.cend(); ++it) {
            const auto value = it.value().toMap();
            const bool legacy = keys(value, {"version", "values"});
            static const QRegularExpression fingerprint("\\A[0-9a-f]{64}\\z");
            const bool reviewed = keys(value, {"version", "values", "enabled", "fingerprint"}) &&
                value.value("enabled").metaType().id() == QMetaType::Bool &&
                value.value("fingerprint").metaType().id() == QMetaType::QString && fingerprint.match(value.value("fingerprint").toString()).hasMatch();
            if (it.value().metaType().id() != QMetaType::QVariantMap || !identifier(it.key()) || (!legacy && !reviewed) || !text(value.value("version"), 96) ||
                value.value("values").metaType().id() != QMetaType::QVariantMap || !bounded(value.value("values"))) return fail(error, "Invalid bounded stored package configuration");
        }
        seen.insert(json(scope)); scopes->append(row);
    }
    return true;
}
bool write(const QString &file, const QByteArray &bytes, QString *error) {
    if (bytes.size() > MaximumStoreBytes || QFileInfo(file).isSymLink()) return fail(error, "Package configuration exceeds capacity or is a symlink");
    QSaveFile output(file);
    if (!output.open(QIODevice::WriteOnly) || !output.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner) ||
        output.write(bytes) != bytes.size() || !output.commit()) return fail(error, "Atomic package configuration save failed; original preserved");
    return true;
}
}
