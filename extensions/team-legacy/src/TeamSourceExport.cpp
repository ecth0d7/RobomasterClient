#include "TeamSourceExport.h"
#include "TeamDataContract.h"

#include <QCryptographicHash>
#include <QJsonDocument>
#include <QMap>
#include <QSet>
#include <algorithm>
#include <cmath>
#include <functional>
#include <utility>

namespace TeamSourceExport {
namespace {
constexpr qint64 SafeInteger = 9007199254740991LL;
constexpr qsizetype ExportLimit = 14 * 1024;
constexpr qsizetype LocalViewLimit = 512 * 1024;
const QSet<QString> Categories{"health", "resources", "position", "objective", "sensorEvents", "visionDiscoveries", "derived"};
const QSet<QString> Uses{"hud", "alerts", "localAi", "externalAi", "voice"};

QVariantMap fail(QString *error, const QString &reason) {
    if (error) *error = reason;
    return {};
}
bool numeric(const QVariant &v, double *out = nullptr) {
    switch (v.metaType().id()) {
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double: case QMetaType::Float:
    case QMetaType::Long: case QMetaType::ULong: case QMetaType::Short:
    case QMetaType::UShort: case QMetaType::Char: case QMetaType::UChar: break;
    default: return false;
    }
    const double n = v.toDouble();
    if (!std::isfinite(n) || std::abs(n) > double(SafeInteger)) return false;
    if (out) *out = n;
    return true;
}
bool integer(const QVariant &v, qint64 low, qint64 high, qint64 *out = nullptr) {
    double n = 0;
    if (!numeric(v, &n) || std::floor(n) != n || n < double(low) || n > double(high)) return false;
    if (out) *out = qint64(n);
    return true;
}
bool robot(qint64 id) {
    return (id >= 1 && id <= 7) || id == 9 || (id >= 101 && id <= 107) || id == 109;
}
bool asciiId(const QVariant &value, qsizetype maximum, bool sourceId = false) {
    if (value.metaType().id() != QMetaType::QString) return false;
    const auto id = value.toString();
    if (id.isEmpty() || id.size() > maximum) return false;
    for (qsizetype i = 0; i < id.size(); ++i) {
        const auto c = id[i].unicode();
        const bool alnum = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9');
        if (!alnum && !(c == '_' || c == '-') && (sourceId || !(c == '.' || c == ':' || c == '/'))) return false;
        if (sourceId && i == 0 && !alnum) return false;
    }
    return true;
}
bool json(const QVariant &v, int depth, qsizetype *cost, int *nodes) {
    if (depth > 8 || ++*nodes > 32768 || *cost > LocalViewLimit) return false;
    if (!v.isValid() || v.metaType().id() == QMetaType::Nullptr) { *cost += 4; return true; }
    switch (v.metaType().id()) {
    case QMetaType::QVariantMap:
        *cost += 2;
        {
            const auto map = v.toMap();
            for (auto it = map.cbegin(); it != map.cend(); ++it) {
                *cost += it.key().size() + 4;
                if (!json(it.value(), depth + 1, cost, nodes)) return false;
            }
        }
        break;
    case QMetaType::QVariantList:
        *cost += 2;
        for (const auto &entry : v.toList()) if (!json(entry, depth + 1, cost, nodes)) return false;
        break;
    case QMetaType::QString: *cost += v.toString().size() + 2; break;
    case QMetaType::Bool: *cost += 5; break;
    default: if (!numeric(v)) return false; *cost += 1;
    }
    return *cost <= LocalViewLimit;
}
bool boundedLocal(const QVariantMap &map) {
    qsizetype cost = 0; int nodes = 0;
    return json(map, 0, &cost, &nodes)
        && QJsonDocument::fromVariant(map).toJson(QJsonDocument::Compact).size() <= LocalViewLimit;
}
bool grants(const QVariant &value, QStringList *result, bool native = false) {
    QVariantList list;
    if (native && value.metaType().id() == QMetaType::QStringList) {
        for (const auto &use : value.toStringList()) list.append(use);
    } else if (value.metaType().id() == QMetaType::QVariantList) list = value.toList();
    else return false;
    for (const auto &use : list) {
        if (use.metaType().id() != QMetaType::QString || !Uses.contains(use.toString()) || result->contains(use.toString())) return false;
        result->append(use.toString());
    }
    result->sort();
    return true;
}
QVariantList array(const QStringList &values) {
    QVariantList list;
    for (const auto &value : values) list.append(value);
    return list;
}
QStringList intersect(const QStringList &left, const QStringList &right) {
    QStringList result;
    for (const auto &value : left) if (right.contains(value)) result.append(value);
    return result;
}
QVariantMap cut(const QVariantList &items, int robotId, QString *error) {
    // This content hash is the immutable wire-cut identity, not a claim that a
    // peer or sensor was verified. No wall/steady sample enters the identity.
    const QVariantMap identity{{"robot_id", robotId}, {"items", items}};
    const auto bytes = QJsonDocument::fromVariant(identity).toJson(QJsonDocument::Compact);
    const auto digest = QCryptographicHash::hash(bytes, QCryptographicHash::Sha256).toHex();
    QVariantMap result{{"schema", 2}, {"kind", "local-snapshot"},
        {"snapshot_id", QStringLiteral("local-") + QString::fromLatin1(digest)}, {"items", items}};
    if (QJsonDocument::fromVariant(result).toJson(QJsonDocument::Compact).size() > ExportLimit)
        return fail(error, QStringLiteral("Complete local team snapshot exceeds the 14 KiB host limit"));
    return result;
}
struct Candidate {
    QVariantMap item;
    QString source;
    QString originalId;
    QStringList uses;
    QStringList dependencies;
    bool eligible = false;
    int visiting = 0;
};
}

QVariantMap build(const QVariantMap &localView, const QVariantMap &categoryPermissions,
                  const QStringList &shareFields, int robotId, bool sharingEnabled,
                  bool canSend, QString *error) {
    if (error) error->clear();
    if (!robot(robotId)) return fail(error, QStringLiteral("Team export requires a current valid robot identity"));
    // A consent/role transition explicitly retires the entire previous cut.
    // It must not depend on any source remaining connected or well formed.
    if (!sharingEnabled || !canSend) return cut({}, robotId, error);

    QMap<QString, QStringList> permissions;
    for (auto it = categoryPermissions.cbegin(); it != categoryPermissions.cend(); ++it) {
        QStringList uses;
        if (!Categories.contains(it.key()) || !grants(it.value(), &uses, true))
            return fail(error, QStringLiteral("Team category permissions contain an unknown category or purpose"));
        permissions.insert(it.key(), uses);
    }
    QSet<QString> selectedCategories;
    for (const auto &category : shareFields) {
        // Advice has its own recommendation/speech boundary; selecting it in
        // the broader operator policy never manufactures a telemetry source.
        if ((!Categories.contains(category) && category != "advice") || selectedCategories.contains(category))
            return fail(error, QStringLiteral("Shared field categories contain an unknown or repeated category"));
        selectedCategories.insert(category);
    }
    qint64 producedUtc = 0;
    if (!boundedLocal(localView) || !integer(localView.value("schema"), 2, 2)
        || localView.value("kind").metaType().id() != QMetaType::QString || localView.value("kind") != "local-data-view"
        || !integer(localView.value("produced_at_ms"), 1, SafeInteger, &producedUtc)
        || !integer(localView.value("produced_tick_ms"), 0, SafeInteger)
        || localView.value("items").metaType().id() != QMetaType::QVariantList
        || localView.value("items").toList().size() > 512)
        return fail(error, QStringLiteral("Malformed or oversized local data view"));

    QMap<QString, Candidate> candidates;
    QMap<QString, QStringList> originalIds;
    QSet<QString> paths;
    for (const auto &value : localView.value("items").toList()) {
        if (value.metaType().id() != QMetaType::QVariantMap)
            return fail(error, QStringLiteral("Local data view entries must be objects"));
        const auto entry = value.toMap();
        qint64 sourceRobot = 0, remaining = 0;
        if (entry.value("item").metaType().id() != QMetaType::QVariantMap
            || !asciiId(entry.value("source_id"), 32, true)
            || !integer(entry.value("source_robot"), 1, 109, &sourceRobot) || !robot(sourceRobot)
            || !asciiId(entry.value("source_session_id"), 96)
            || !integer(entry.value("source_sequence"), 1, SafeInteger)
            || !integer(entry.value("remaining_ms"), 0, 60000, &remaining)
            || entry.value("state").metaType().id() != QMetaType::QString
            || !QSet<QString>{"fresh", "stale", "offline", "withdrawn", "conflict", "unmapped", "time_unverified"}.contains(entry.value("state").toString())
            || entry.value("share_enabled").metaType().id() != QMetaType::Bool
            || entry.value("clock_mapping_verified").metaType().id() != QMetaType::Bool
            || entry.value("authenticated").metaType().id() != QMetaType::Bool || entry.value("authenticated").toBool())
            return fail(error, QStringLiteral("Malformed local source identity, freshness or host boundary"));
        auto item = entry.value("item").toMap();
        // Mock sources are never admitted to production transport. Their UI
        // examples remain local, even if an operator enables sharing elsewhere.
        if (item.value("source_kind") == "mock") continue;
        QString itemError;
        if (!TeamDataContract::validateSourceItem(item, producedUtc, 0, &itemError))
            return fail(error, QStringLiteral("Malformed local source item: ") + itemError);
        const auto source = entry.value("source_id").toString();
        const auto originalId = item.value("item_id").toString();
        const auto id = source + ':' + originalId;
        const auto path = source + '.' + item.value("path").toString();
        if (id.size() > 96 || path.size() > 128 || candidates.contains(id) || paths.contains(path))
            return fail(error, QStringLiteral("Local source namespace exceeds limits or repeats an item/path"));
        const qint64 ttl = item.value("ttl_ms").toLongLong();
        const qint64 observed = item.value("observed_at_ms").toLongLong();
        const qint64 utcRemaining = observed > SafeInteger - ttl ? SafeInteger : observed + ttl - producedUtc;
        if (remaining > ttl || (entry.value("state") == "fresh" && (remaining <= 0 || utcRemaining < remaining)))
            return fail(error, QStringLiteral("Local source freshness exceeds its original item lifetime"));
        Candidate candidate;
        candidate.item = item; candidate.source = source; candidate.originalId = originalId;
        if (!grants(item.value("allowed_uses"), &candidate.uses))
            return fail(error, QStringLiteral("Malformed local source purpose grants"));
        if (entry.contains("source_allowed_uses")) {
            QStringList originalUses;
            if (!grants(entry.value("source_allowed_uses"), &originalUses)
                || intersect(candidate.uses, originalUses) != candidate.uses)
                return fail(error, QStringLiteral("Local projection expanded the original source purpose grants"));
        }
        candidate.uses = intersect(candidate.uses, permissions.value(item.value("category").toString()));
        for (const auto &dependency : item.value("dependencies").toList()) candidate.dependencies.append(dependency.toString());
        candidate.eligible = sourceRobot == robotId && entry.value("state") == "fresh" && remaining > 0
            && entry.value("share_enabled").toBool() && entry.value("clock_mapping_verified").toBool()
            && item.value("lifecycle") == "active" && selectedCategories.contains(item.value("category").toString())
            && !candidate.uses.isEmpty();
        // Dependency ambiguity includes unselected sources. Choosing only one
        // surviving candidate would reinterpret an originally ambiguous ID.
        if (sourceRobot == robotId) originalIds[originalId].append(id);
        paths.insert(path); candidates.insert(id, std::move(candidate));
    }
    std::function<bool(const QString &)> resolve = [&](const QString &id) {
        auto it = candidates.find(id);
        if (it == candidates.end() || !it->eligible) return false;
        if (it->visiting == 2) return true;
        if (it->visiting == 1) return false;
        it->visiting = 1;
        QStringList namespacedDependencies;
        for (const auto &dependency : std::as_const(it->dependencies)) {
            const auto matches = originalIds.value(dependency);
            if (matches.size() != 1 || !resolve(matches.front())) { it->eligible = false; break; }
            it->uses = intersect(it->uses, candidates.value(matches.front()).uses);
            namespacedDependencies.append(matches.front());
        }
        if (it->uses.isEmpty() || (it->item.value("source_kind") == "derived" && it->dependencies.isEmpty())) it->eligible = false;
        if (!it->eligible) { it->visiting = 2; return false; }
        it->item["item_id"] = id;
        it->item["path"] = it->source + '.' + it->item.value("path").toString();
        it->item["allowed_uses"] = array(it->uses);
        if (it->item.contains("dependencies")) {
            // Keep original observation/TTL immutable. The complete signed cut
            // carries every dependency so TeamDataContract can intersect their
            // original deadlines again after transport/queue delay; rewriting
            // TTL from a polled remaining_ms would create new item content.
            namespacedDependencies.sort(); it->item["dependencies"] = array(namespacedDependencies);
        }
        it->visiting = 2;
        return true;
    };
    QVariantList items;
    for (auto it = candidates.cbegin(); it != candidates.cend(); ++it) {
        if (!resolve(it.key())) continue;
        items.append(candidates.value(it.key()).item);
        if (items.size() > 64) return fail(error, QStringLiteral("Complete local team snapshot exceeds 64 items"));
    }
    return cut(items, robotId, error);
}

struct VersionLedger::Private {
    struct Entry { QByteArray sourceContent; qint64 revision = 0; bool active = false; };
    QMap<QString, Entry> entries;
    qint64 revision = 0;
    int robot = 0;
};

VersionLedger::VersionLedger() : d(std::make_unique<Private>()) {}
VersionLedger::~VersionLedger() = default;
VersionLedger::VersionLedger(const VersionLedger &other) : d(std::make_unique<Private>(*other.d)) {}
VersionLedger &VersionLedger::operator=(const VersionLedger &other) {
    if (this != &other) d = std::make_unique<Private>(*other.d);
    return *this;
}
VersionLedger::VersionLedger(VersionLedger &&) noexcept = default;
VersionLedger &VersionLedger::operator=(VersionLedger &&) noexcept = default;
void VersionLedger::reset() { d = std::make_unique<Private>(); }

QVariantMap VersionLedger::apply(const QVariantMap &candidate, const QVariantMap &localView, QString *error) {
    if (error) error->clear();
    const QSet<QString> required{"schema", "kind", "snapshot_id", "items"};
    for (const auto &key : required)
        if (!candidate.contains(key)) return fail(error, QStringLiteral("Host team versioning requires a complete candidate cut"));
    for (auto it = candidate.cbegin(); it != candidate.cend(); ++it)
        if (!required.contains(it.key())) return fail(error, QStringLiteral("Unknown candidate team cut field"));
    qint64 robotId = 0, producedUtc = 0;
    if (!boundedLocal(candidate) || !boundedLocal(localView)
        || QJsonDocument::fromVariant(candidate).toJson(QJsonDocument::Compact).size() > ExportLimit
        || !integer(candidate.value("schema"), 2, 2) || candidate.value("kind").metaType().id() != QMetaType::QString
        || candidate.value("kind") != "local-snapshot" || candidate.value("snapshot_id").metaType().id() != QMetaType::QString
        || candidate.value("items").metaType().id() != QMetaType::QVariantList || candidate.value("items").toList().size() > 64
        || !integer(localView.value("schema"), 2, 2) || localView.value("kind").metaType().id() != QMetaType::QString
        || localView.value("kind") != "local-data-view"
        || !integer(localView.value("robot_id"), 1, 109, &robotId) || !robot(robotId)
        || !integer(localView.value("produced_at_ms"), 1, SafeInteger, &producedUtc)
        || !integer(localView.value("produced_tick_ms"), 0, SafeInteger)
        || localView.value("items").metaType().id() != QMetaType::QVariantList || localView.value("items").toList().size() > 512
        || localView.value("sources").metaType().id() != QMetaType::QVariantList || localView.value("sources").toList().size() > 16
        || (d->robot != 0 && d->robot != robotId))
        return fail(error, QStringLiteral("Malformed host team cut, local view or changed node robot scope"));
    const auto candidateItems = candidate.value("items").toList();
    const auto originalCut = cut(candidateItems, int(robotId), error);
    if (originalCut.isEmpty() || originalCut != candidate)
        return fail(error, QStringLiteral("Candidate team snapshot identity does not bind its complete original content"));

    QMap<QString, QVariantMap> sources, wrappers;
    for (const auto &value : localView.value("sources").toList()) {
        if (value.metaType().id() != QMetaType::QVariantMap)
            return fail(error, QStringLiteral("Malformed registered source descriptor"));
        const auto source = value.toMap();
        if (!asciiId(source.value("source_id"), 32, true) || !asciiId(source.value("session_id"), 96)
            || !integer(source.value("generation"), 1, SafeInteger)
            || !integer(source.value("robot_id"), 1, 109) || !robot(source.value("robot_id").toLongLong())
            || sources.contains(source.value("source_id").toString()))
            return fail(error, QStringLiteral("Registered source generation/session is invalid or ambiguous"));
        sources.insert(source.value("source_id").toString(), source);
    }
    for (const auto &value : localView.value("items").toList()) {
        if (value.metaType().id() != QMetaType::QVariantMap)
            return fail(error, QStringLiteral("Malformed registered source item wrapper"));
        const auto wrapper = value.toMap();
        if (!asciiId(wrapper.value("source_id"), 32, true) || wrapper.value("item").metaType().id() != QMetaType::QVariantMap
            || !asciiId(wrapper.value("item").toMap().value("item_id"), 96))
            return fail(error, QStringLiteral("Malformed registered source item identity"));
        const auto id = wrapper.value("source_id").toString() + ':' + wrapper.value("item").toMap().value("item_id").toString();
        if (wrappers.contains(id)) return fail(error, QStringLiteral("Duplicate registered source item identity"));
        wrappers.insert(id, wrapper);
    }

    QMap<QString, QVariantMap> selected;
    QMap<QString, QByteArray> identities;
    QSet<QString> paths;
    for (const auto &value : candidateItems) {
        if (value.metaType().id() != QMetaType::QVariantMap)
            return fail(error, QStringLiteral("Candidate team item must be an object"));
        const auto item = value.toMap();
        QString reason;
        if (!TeamDataContract::validateSourceItem(item, producedUtc, 0, &reason))
            return fail(error, QStringLiteral("Invalid candidate team item: ") + reason);
        if (item.value("lifecycle") != "active"
            || (item.value("source_kind") == "derived" && item.value("dependencies").toList().isEmpty()))
            return fail(error, QStringLiteral("Candidate team item is withdrawn or lacks its derived dependencies"));
        const auto id = item.value("item_id").toString();
        const auto separator = id.indexOf(':');
        if (separator <= 0 || !wrappers.contains(id) || selected.contains(id) || paths.contains(item.value("path").toString()))
            return fail(error, QStringLiteral("Candidate item is absent, ambiguous or duplicated in the host view"));
        const auto sourceId = id.left(separator);
        const auto source = sources.value(sourceId);
        const auto wrapper = wrappers.value(id);
        const auto original = wrapper.value("item").toMap();
        qint64 remaining = 0;
        QStringList uses, originalUses;
        if (source.isEmpty() || !asciiId(wrapper.value("source_session_id"), 96)
            || source.value("session_id") != wrapper.value("source_session_id")
            || !integer(wrapper.value("source_robot"), robotId, robotId) || source.value("robot_id").toLongLong() != robotId
            || !integer(wrapper.value("source_sequence"), 1, SafeInteger)
            || wrapper.value("state").metaType().id() != QMetaType::QString || wrapper.value("state") != "fresh"
            || !integer(wrapper.value("remaining_ms"), 1, 60000, &remaining)
            || remaining > item.value("ttl_ms").toLongLong()
            || remaining > item.value("observed_at_ms").toLongLong() + item.value("ttl_ms").toLongLong() - producedUtc
            || wrapper.value("share_enabled").metaType().id() != QMetaType::Bool || !wrapper.value("share_enabled").toBool()
            || wrapper.value("clock_mapping_verified").metaType().id() != QMetaType::Bool || !wrapper.value("clock_mapping_verified").toBool()
            || wrapper.value("authenticated").metaType().id() != QMetaType::Bool || wrapper.value("authenticated").toBool()
            || !grants(item.value("allowed_uses"), &uses) || uses.isEmpty()
            || !grants(original.value("allowed_uses"), &originalUses) || intersect(uses, originalUses) != uses)
            return fail(error, QStringLiteral("Candidate item is outside its live registered source/session/grants"));
        auto restored = item;
        restored["item_id"] = id.mid(separator + 1);
        if (item.value("path") != sourceId + '.' + original.value("path").toString())
            return fail(error, QStringLiteral("Candidate item changed its original semantic path"));
        restored["path"] = original.value("path");
        restored["allowed_uses"] = original.value("allowed_uses");
        if (item.contains("dependencies") != original.contains("dependencies"))
            return fail(error, QStringLiteral("Candidate item changed its original dependency declaration"));
        if (item.contains("dependencies")) {
            QStringList rawDependencies, projectedDependencies;
            for (const auto &dependency : original.value("dependencies").toList()) rawDependencies.append(dependency.toString());
            for (const auto &dependency : item.value("dependencies").toList()) {
                const auto dependencyId = dependency.toString();
                if (!wrappers.contains(dependencyId))
                    return fail(error, QStringLiteral("Candidate dependency is absent from its host source view"));
                const auto rawId = wrappers.value(dependencyId).value("item").toMap().value("item_id").toString();
                int matches = 0;
                for (auto sourceItem = wrappers.cbegin(); sourceItem != wrappers.cend(); ++sourceItem)
                    if (integer(sourceItem->value("source_robot"), robotId, robotId)
                        && sourceItem->value("item").toMap().value("item_id") == rawId) ++matches;
                if (matches != 1) return fail(error, QStringLiteral("Candidate dependency has an ambiguous original source identity"));
                projectedDependencies.append(rawId);
            }
            rawDependencies.sort(); projectedDependencies.sort();
            if (rawDependencies != projectedDependencies)
                return fail(error, QStringLiteral("Candidate item changed its original dependency identity"));
            restored["dependencies"] = original.value("dependencies");
        }
        if (restored != original)
            return fail(error, QStringLiteral("Candidate item changed original observation/value/provenance"));
        const QVariantMap identity{{"item", item}, {"source_session_id", source.value("session_id")},
            {"source_generation", source.value("generation")}};
        identities.insert(id, QJsonDocument::fromVariant(identity).toJson(QJsonDocument::Compact));
        paths.insert(item.value("path").toString()); selected.insert(id, item);
    }
    QSet<QString> visiting, resolved;
    std::function<bool(const QString &)> dependencies = [&](const QString &id) {
        if (!selected.contains(id) || visiting.contains(id)) return false;
        if (resolved.contains(id)) return true;
        visiting.insert(id);
        QStringList childUses;
        grants(selected.value(id).value("allowed_uses"), &childUses);
        for (const auto &dependency : selected.value(id).value("dependencies").toList()) {
            const auto dependencyId = dependency.toString();
            if (!dependencies(dependencyId)) return false;
            QStringList parentUses;
            grants(selected.value(dependencyId).value("allowed_uses"), &parentUses);
            if (intersect(childUses, parentUses) != childUses) return false;
        }
        visiting.remove(id); resolved.insert(id); return true;
    };
    for (auto it = selected.cbegin(); it != selected.cend(); ++it)
        if (!dependencies(it.key())) return fail(error, QStringLiteral("Candidate dependency cut is incomplete, cyclic or widens purpose grants"));

    auto next = *d;
    next.robot = int(robotId);
    for (auto it = next.entries.begin(); it != next.entries.end(); ++it)
        if (!selected.contains(it.key())) it->active = false;
    QVariantList rewritten;
    for (auto it = selected.cbegin(); it != selected.cend(); ++it) {
        auto entry = next.entries.value(it.key());
        if (!entry.active || entry.sourceContent != identities.value(it.key())) {
            if (next.revision == SafeInteger) return fail(error, QStringLiteral("Host team item revision exhausted; start a new node session"));
            entry.revision = ++next.revision; entry.sourceContent = identities.value(it.key());
        }
        entry.active = true; next.entries.insert(it.key(), entry);
        if (next.entries.size() > 128)
            return fail(error, QStringLiteral("Host team item ledger exceeds 128 identities; start a new node session"));
        auto item = it.value(); item["revision"] = entry.revision; rewritten.append(item);
    }
    const auto result = cut(rewritten, int(robotId), error);
    if (result.isEmpty()) return {};
    *d = std::move(next);
    return result;
}
}
