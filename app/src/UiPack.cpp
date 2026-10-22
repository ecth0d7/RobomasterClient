#include "UiPack.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSet>
#include <QRegularExpression>
#include <QVariantMap>
#include <optional>

namespace {
bool validViewId(const QString &id) {
    static const QRegularExpression pattern(QStringLiteral("^[a-z][a-z0-9]*(?:[.-][a-z0-9]+)*$"));
    return !id.isEmpty() && id.size() <= 64 && pattern.match(id).hasMatch();
}

struct Metadata {
    QUrl entry;
    QVariantList views;
};

std::optional<Metadata> readMetadata(const QString &directory, QString *error) {
    if (error)
        error->clear();
    const auto fail = [error](const QString &message) -> std::optional<Metadata> {
        if (error)
            *error = message;
        return {};
    };
    QFile manifest(QDir(directory).filePath("manifest.json"));
    if (!manifest.open(QIODevice::ReadOnly))
        return fail("Cannot read UI pack manifest: " + manifest.fileName());
    const auto bytes = manifest.read(64 * 1024 + 1);
    if (bytes.size() > 64 * 1024)
        return fail("UI pack manifest is too large");
    QJsonParseError parse;
    const auto doc = QJsonDocument::fromJson(bytes, &parse);
    if (parse.error != QJsonParseError::NoError || !doc.isObject())
        return fail("Invalid UI pack JSON");
    const auto metadata = doc.object();
    const auto api = metadata.value("apiVersion");
    if (!api.isDouble() || api.toDouble() != 1)
        return fail("Unsupported UI pack API version");
    if (metadata.contains("context")) {
        const auto declared = metadata.value("context");
        if (!declared.isArray())
            return fail("UI pack context must be an array");
        const QSet<QString> available{"clientBackend", "inputController", "videoReceiver",
                                      "extensionServices", "localUiSettings", "uiViewController", "battlefieldHost"};
        QSet<QString> requested;
        for (const auto &value : declared.toArray()) {
            const auto name = value.toString();
            if (!value.isString())
                return fail("UI pack context names must be strings");
            if (!available.contains(name))
                return fail("UI pack declares an unsupported context: " + name);
            if (requested.contains(name))
                return fail("UI pack declares a duplicate context: " + name);
            requested.insert(name);
        }
    }
    auto base = QFileInfo(directory).canonicalFilePath();
    if (base.isEmpty() || !QFileInfo(directory).isDir())
        return fail("UI pack directory is missing");
    if (!base.endsWith('/'))
        base += '/';
    const auto resolveEntry = [&](const QJsonValue &value) {
        const QString relative = value.toString();
        if (!value.isString() || relative.isEmpty() || relative.size() > 512 ||
            QDir::isAbsolutePath(relative))
            return QUrl{};
        const QFileInfo info(QDir(directory).filePath(relative));
        const auto canonical = info.canonicalFilePath();
        if (!info.isFile() || !canonical.startsWith(base))
            return QUrl{};
        return QUrl::fromLocalFile(canonical);
    };
    Metadata result;
    result.entry = resolveEntry(metadata.value("entry"));
    if (result.entry.isEmpty())
        return fail("UI pack entry is missing, invalid or outside the pack");
    if (!metadata.contains("views")) {
        // Older packs continue to expose their original operator entry.
        result.views.append(QVariantMap{{"id", "terminal-2027"}, {"title", "2027 terminal"},
                                       {"kind", "operator"}, {"entry", result.entry}});
        return result;
    }
    if (!metadata.value("views").isObject())
        return fail("UI pack views must be an object");
    const auto views = metadata.value("views").toObject();
    if (views.isEmpty() || views.size() > 8)
        return fail("UI pack must declare between one and eight views");
    for (auto it = views.begin(); it != views.end(); ++it) {
        if (!validViewId(it.key()) || !it.value().isObject())
            return fail("UI pack declares an invalid view identifier or descriptor");
        const auto view = it.value().toObject();
        if (view.size() != 3 || !view.contains("entry") || !view.contains("title") ||
            !view.contains("kind"))
            return fail("UI view must contain exactly entry, title and kind");
        const auto title = view.value("title").toString();
        if (!view.value("title").isString() || title.trimmed().isEmpty() || title.size() > 96)
            return fail("UI view title is missing or too long");
        const auto kind = view.value("kind").toString();
        if (!view.value("kind").isString() || (kind != "operator" && kind != "reference"))
            return fail("UI view kind must be operator or reference");
        const auto entry = resolveEntry(view.value("entry"));
        if (entry.isEmpty())
            return fail("UI view entry is missing, invalid or outside the pack: " + it.key());
        result.views.append(QVariantMap{{"id", it.key()}, {"title", title},
                                       {"kind", kind}, {"entry", entry}});
    }
    return result;
}
}

QUrl UiPack::entry(const QString &directory, QString *error, const QString &viewId) {
    const auto metadata = readMetadata(directory, error);
    if (!metadata)
        return {};
    if (viewId.isEmpty())
        return metadata->entry;
    for (const auto &value : metadata->views) {
        const auto view = value.toMap();
        if (view.value("id").toString() == viewId)
            return view.value("entry").toUrl();
    }
    if (error)
        *error = "Unknown UI view: " + viewId;
    return {};
}

QVariantList UiPack::viewCatalog(const QString &directory, QString *error) {
    const auto metadata = readMetadata(directory, error);
    return metadata ? metadata->views : QVariantList{};
}
