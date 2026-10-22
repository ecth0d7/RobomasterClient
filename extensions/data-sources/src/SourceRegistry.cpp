#include "SourceRegistry.h"
#include "TeamDataContract.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QSet>
#include <QUuid>
#include <algorithm>
#include <cmath>

namespace {
constexpr qint64 SafeInteger = 9007199254740991LL;
constexpr qsizetype SnapshotLimit = 64 * 1024;
const QSet<QString> Purposes{"hud", "alerts", "localAi", "externalAi", "voice"};

bool fail(QString *error, const char *reason) {
    if (error) *error = QString::fromLatin1(reason);
    return false;
}
bool numeric(const QVariant &value, double *result = nullptr) {
    switch (value.metaType().id()) {
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double: case QMetaType::Float:
    case QMetaType::Long: case QMetaType::ULong: case QMetaType::Short:
    case QMetaType::UShort: case QMetaType::Char: case QMetaType::UChar: break;
    default: return false;
    }
    const double n = value.toDouble();
    if (!std::isfinite(n) || std::abs(n) > double(SafeInteger)) return false;
    if (result) *result = n;
    return true;
}
bool integer(const QVariant &value, qint64 low, qint64 high, qint64 *result = nullptr) {
    double n = 0;
    if (!numeric(value, &n) || n != std::floor(n) || n < double(low) || n > double(high)) return false;
    if (result) *result = qint64(n);
    return true;
}
bool text(const QVariant &value, qsizetype maximum, bool empty = false) {
    if (value.metaType().id() != QMetaType::QString) return false;
    const auto s = value.toString();
    if ((!empty && s.isEmpty()) || s.size() > maximum) return false;
    for (const auto ch : s) if (ch.isNull() || ch.category() == QChar::Other_Control) return false;
    return true;
}
bool id(const QVariant &value, qsizetype maximum = 96) {
    if (!text(value, maximum)) return false;
    for (const auto ch : value.toString()) {
        const auto u = ch.unicode();
        if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') || (u >= '0' && u <= '9') ||
              u == '_' || u == '-' || u == '.' || u == ':' || u == '/')) return false;
    }
    return true;
}
bool sourceId(const QVariant &value) {
    if (!text(value, 32)) return false;
    const auto s = value.toString();
    for (qsizetype i = 0; i < s.size(); ++i) {
        const auto u = s[i].unicode();
        const bool alphanumeric = (u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') || (u >= '0' && u <= '9');
        if (!alphanumeric && (i == 0 || (u != '_' && u != '-'))) return false;
    }
    return true;
}
bool keys(const QVariantMap &map, const QSet<QString> &required, const QSet<QString> &optional = {}) {
    for (const auto &key : required) if (!map.contains(key)) return false;
    for (auto it = map.cbegin(); it != map.cend(); ++it)
        if (!required.contains(it.key()) && !optional.contains(it.key())) return false;
    return true;
}
bool validRobot(const QVariant &value, qint64 *result = nullptr) {
    qint64 robot = 0;
    if (!integer(value, 1, 109, &robot) || !((robot <= 7) || robot == 9 ||
        (robot >= 101 && robot <= 107) || robot == 109)) return false;
    if (result) *result = robot;
    return true;
}
bool choices(const QVariant &value, QSet<QString> *result) {
    if (value.metaType().id() != QMetaType::QVariantList || value.toList().size() > Purposes.size()) return false;
    QSet<QString> values;
    for (const auto &v : value.toList()) {
        if (!text(v, 16) || !Purposes.contains(v.toString()) || values.contains(v.toString())) return false;
        values.insert(v.toString());
    }
    *result = std::move(values); return true;
}
QVariantList sorted(const QSet<QString> &values) {
    auto strings = values.values(); std::sort(strings.begin(), strings.end());
    QVariantList result; for (const auto &v : strings) result.append(v); return result;
}
bool shape(const QVariant &value, int depth, qsizetype *cost, int *nodes) {
    if (depth > 8 || ++*nodes > 8192 || *cost > SnapshotLimit) return false;
    if (!value.isValid() || value.metaType().id() == QMetaType::Nullptr) { *cost += 4; return true; }
    switch (value.metaType().id()) {
    case QMetaType::QVariantMap: {
        *cost += 2;
        const auto map = value.toMap();
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            *cost += it.key().size() + 4;
            if (!shape(it.value(), depth + 1, cost, nodes)) return false;
        }
        break;
    }
    case QMetaType::QVariantList:
        *cost += 2;
        for (const auto &entry : value.toList()) if (!shape(entry, depth + 1, cost, nodes)) return false;
        break;
    case QMetaType::QString: *cost += value.toString().size() + 2; break;
    case QMetaType::Bool: *cost += 5; break;
    default: if (!numeric(value)) return false; ++*cost;
    }
    return *cost <= SnapshotLimit;
}
QByteArray compact(const QVariantMap &map) {
    return QJsonDocument(QJsonObject::fromVariantMap(map)).toJson(QJsonDocument::Compact);
}
bool bounded(const QVariantMap &map) {
    qsizetype cost = 0; int nodes = 0;
    return shape(map, 0, &cost, &nodes) && compact(map).size() <= SnapshotLimit;
}
qint64 add(qint64 a, qint64 b) { return std::clamp(a + b, -SafeInteger, SafeInteger); }
bool times(qint64 utc, qint64 tick) { return utc > 0 && utc <= SafeInteger && tick >= 0 && tick <= SafeInteger; }

struct Descriptor {
    QVariantMap wire;
    QString source, session, kind;
    qint64 robot = 0, ttl = 0;
    bool share = false, mapped = false;
    QSet<QString> uses;
};
bool descriptor(const QVariantMap &map, Descriptor *result, QString *error) {
    static const QSet<QString> required{"source_id", "session_id", "robot_id", "source_kind", "adapter_id", "sensor_id",
        "producer_version", "allowed_uses", "share_enabled", "clock_mapping_verified", "measurement_validation", "ttl_max_ms"};
    Descriptor out;
    if (!keys(map, required, {"player_export_id"}) || !bounded(map) || !sourceId(map.value("source_id")) ||
        !id(map.value("session_id")) || !validRobot(map.value("robot_id"), &out.robot) ||
        !id(map.value("adapter_id")) || !text(map.value("sensor_id"), 96, true) ||
        !text(map.value("producer_version"), 96) || !choices(map.value("allowed_uses"), &out.uses) ||
        map.value("share_enabled").metaType().id() != QMetaType::Bool ||
        map.value("clock_mapping_verified").metaType().id() != QMetaType::Bool ||
        !integer(map.value("ttl_max_ms"), 100, 60000, &out.ttl) || !text(map.value("source_kind"), 32) ||
        !text(map.value("measurement_validation"), 40)) return fail(error, "Invalid bounded native source descriptor");
    out.source = map.value("source_id").toString(); out.session = map.value("session_id").toString();
    out.kind = map.value("source_kind").toString(); out.share = map.value("share_enabled").toBool();
    out.mapped = map.value("clock_mapping_verified").toBool();
    const auto validation = map.value("measurement_validation").toString();
    if (out.kind == "official_player_client") {
        if (!out.mapped || !text(map.value("player_export_id"), 128) ||
            (validation != "unverified" && validation != "operator_confirmed_endpoint"))
            return fail(error, "Official source requires a host receive-clock mapping and explicit player export reference");
    } else if (out.kind == "local_sensor" || out.kind == "local_vision") {
        if (!text(map.value("sensor_id"), 96) || validation != "unverified" || map.contains("player_export_id"))
            return fail(error, "Local source must retain sensor provenance and unverified measurement status");
    } else if (out.kind == "derived") {
        if (validation != "derived" || map.contains("player_export_id"))
            return fail(error, "Derived source requires derived provenance without an official export claim");
    } else return fail(error, "Unsupported source kind; production registry never accepts mock registration");
    out.wire = map; *result = std::move(out); return true;
}

struct Dependency {
    QString source, session, item;
    quint64 generation = 0;
    qint64 revision = 0;
};
struct Item {
    QVariantMap content;
    QByteArray bytes;
    qint64 revision = 0, acceptedUtc = 0, acceptedTick = 0, deadline = 0;
    bool conflict = false, omitted = false, dependenciesResolved = true;
    QList<Dependency> dependencies;
};
struct Source {
    Descriptor descriptor;
    quint64 generation = 0;
    qint64 sequence = 0, acceptedUtc = 0, acceptedTick = 0;
    QString snapshot;
    QByteArray bytes;
    QMap<QString, Item> highwater;
    QSet<QString> selected;
};
struct Registry {
    QMap<QString, Source> sources;
    // Generation never resets on clear: a queued callback cannot become current
    // merely because a new registration reused the same human-readable ID.
    quint64 generation = 0, revision = 0;
    QString identity = QUuid::createUuid().toString(QUuid::WithoutBraces);
};
QString key(const QString &source, const QString &item) { return source + QChar(0x1f) + item; }
struct Projection {
    QString state;
    QSet<QString> uses;
    qint64 remaining = 0;
    bool share = false;
};
Projection project(const Registry &registry, const QString &sourceId, const QString &itemId, qint64 utc, qint64 tick,
                   QMap<QString, Projection> *cache, QSet<QString> *visiting) {
    const auto name = key(sourceId, itemId);
    if (cache->contains(name)) return cache->value(name);
    Projection out; out.state = "stale";
    if (visiting->contains(name)) return out;
    const auto sourceIt = registry.sources.constFind(sourceId);
    if (sourceIt == registry.sources.cend() || !sourceIt->selected.contains(itemId)) return out;
    const auto &source = sourceIt.value(); const auto &item = source.highwater[itemId];
    if (item.conflict) out.state = "conflict";
    else if (item.content.value("lifecycle") == "withdrawn") out.state = "withdrawn";
    else if (!source.descriptor.mapped) out.state = "time_unverified";
    else if (!item.omitted && tick >= item.acceptedTick && utc >= item.acceptedUtc && tick < item.deadline &&
             utc < add(item.content.value("observed_at_ms").toLongLong(), item.content.value("ttl_ms").toLongLong())) {
        out.state = "fresh";
        out.remaining = std::min(item.deadline - tick,
            add(item.content.value("observed_at_ms").toLongLong(), item.content.value("ttl_ms").toLongLong()) - utc);
        choices(item.content.value("allowed_uses"), &out.uses);
        out.uses.intersect(source.descriptor.uses); out.share = source.descriptor.share;
    }
    if (out.state == "fresh" && source.descriptor.kind == "derived") {
        if (!item.dependenciesResolved || item.dependencies.isEmpty()) out.state = "stale";
        visiting->insert(name);
        for (const auto &dependency : item.dependencies) {
            int matchingSources = 0;
            for (auto it = registry.sources.cbegin(); it != registry.sources.cend(); ++it)
                if (it->descriptor.robot == source.descriptor.robot && it->selected.contains(dependency.item)) ++matchingSources;
            const auto parentSource = registry.sources.constFind(dependency.source);
            if (matchingSources != 1 || parentSource == registry.sources.cend() || parentSource->generation != dependency.generation ||
                parentSource->descriptor.session != dependency.session || !parentSource->selected.contains(dependency.item) ||
                parentSource->highwater.value(dependency.item).revision != dependency.revision) { out.state = "stale"; break; }
            const auto parent = project(registry, dependency.source, dependency.item, utc, tick, cache, visiting);
            if (parent.state != "fresh") { out.state = "stale"; break; }
            out.remaining = std::min(out.remaining, parent.remaining); out.uses.intersect(parent.uses);
            out.share = out.share && parent.share;
        }
        visiting->remove(name);
    }
    if (out.state != "fresh") { out.uses.clear(); out.remaining = 0; out.share = false; }
    cache->insert(name, out); return out;
}

void bindDependencies(Registry &registry, const QString &sourceId, const QSet<QString> &newItems) {
    auto &source = registry.sources[sourceId];
    if (source.descriptor.kind != "derived") return;
    for (const auto &name : newItems) {
        auto &item = source.highwater[name]; item.dependenciesResolved = true; item.dependencies.clear();
        for (const auto &dependencyValue : item.content.value("dependencies").toList()) {
            const auto dependencyId = dependencyValue.toString(); QList<Dependency> matches;
            for (auto it = registry.sources.cbegin(); it != registry.sources.cend(); ++it) {
                if (it->descriptor.robot != source.descriptor.robot || !it->selected.contains(dependencyId)) continue;
                matches.append({it.key(), it->descriptor.session, dependencyId, it->generation, it->highwater.value(dependencyId).revision});
            }
            if (matches.size() != 1) item.dependenciesResolved = false;
            else item.dependencies.append(matches.front());
        }
        if (item.dependencies.isEmpty()) item.dependenciesResolved = false;
    }
}
bool boundItem(const QVariantMap &item, const Descriptor &desc, qint64 utc, QString *error) {
    if (!TeamDataContract::validateSourceItem(item, utc, 0, error)) return false;
    for (const auto &field : {QStringLiteral("source_kind"), QStringLiteral("adapter_id"), QStringLiteral("sensor_id"),
                             QStringLiteral("producer_version"), QStringLiteral("measurement_validation")})
        if (item.value(field) != desc.wire.value(field)) return fail(error, "Source item cannot replace its registered provenance or validation status");
    if (item.value("ttl_ms").toLongLong() > desc.ttl) return fail(error, "Source item exceeds its registered lifetime bound");
    if (desc.kind == "official_player_client") {
        if (item.value("player_export_id") != desc.wire.value("player_export_id")) return fail(error, "Source item changed its official player export reference");
    } else if (item.contains("player_export_id")) return fail(error, "Nonofficial source cannot claim an official player export reference");
    QSet<QString> grants; choices(item.value("allowed_uses"), &grants);
    if (!desc.uses.contains(grants)) return fail(error, "Source item expanded its registered purpose grants");
    if (desc.kind == "derived" && item.value("dependencies").toList().isEmpty())
        return fail(error, "Derived item requires explicit dependencies");
    return true;
}
}

struct SourceRegistry::Private : Registry {};
SourceRegistry::SourceRegistry() : d(std::make_unique<Private>()) {}
SourceRegistry::~SourceRegistry() = default;
SourceRegistry::SourceRegistry(const SourceRegistry &other) : d(std::make_unique<Private>(*other.d)) {}
SourceRegistry &SourceRegistry::operator=(const SourceRegistry &other) {
    if (this != &other) d = std::make_unique<Private>(*other.d);
    return *this;
}
SourceRegistry::SourceRegistry(SourceRegistry &&) noexcept = default;
SourceRegistry &SourceRegistry::operator=(SourceRegistry &&) noexcept = default;

quint64 SourceRegistry::registerSource(const QVariantMap &map, QString *error) {
    if (error) error->clear();
    Descriptor desc;
    if (!descriptor(map, &desc, error)) return 0;
    const auto previous = d->sources.constFind(desc.source);
    if (previous == d->sources.cend() && d->sources.size() >= 16) {
        fail(error, "At most 16 native source registrations are permitted"); return 0;
    }
    if (previous != d->sources.cend() && previous->descriptor.session == desc.session) {
        fail(error, "Replacing a native source requires a new session ID"); return 0;
    }
    if (d->generation >= quint64(SafeInteger) || d->revision >= quint64(SafeInteger)) {
        fail(error, "Native source generation or view revision exhausted"); return 0;
    }
    Source source; source.descriptor = std::move(desc); source.generation = ++d->generation;
    d->sources.insert(source.descriptor.source, source); ++d->revision; return source.generation;
}

bool SourceRegistry::accept(const QString &sourceId, quint64 generation, const QVariantMap &message,
                            qint64 utc, qint64 tick, QString *error) {
    if (error) error->clear();
    auto sourceIt = d->sources.find(sourceId);
    if (sourceIt == d->sources.end() || generation == 0 || sourceIt->generation != generation)
        return fail(error, "Native source registration is absent or its generation has retired");
    auto &source = sourceIt.value(); qint64 sequence = 0;
    if (!times(utc, tick) || (source.sequence > 0 && (utc < source.acceptedUtc || tick < source.acceptedTick)))
        return fail(error, "Invalid or regressing native source clock sample");
    static const QSet<QString> required{"schema", "kind", "source_id", "session_id", "robot_id", "sequence", "snapshot_id", "items"};
    if (!keys(message, required) || !bounded(message) || !integer(message.value("schema"), 2, 2) ||
        message.value("kind") != "source-snapshot" || message.value("source_id") != sourceId ||
        message.value("session_id") != source.descriptor.session ||
        !validRobot(message.value("robot_id")) || message.value("robot_id").toLongLong() != source.descriptor.robot ||
        !integer(message.value("sequence"), 1, SafeInteger, &sequence) || !id(message.value("snapshot_id")) ||
        message.value("items").metaType().id() != QMetaType::QVariantList || message.value("items").toList().size() > 64)
        return fail(error, "Invalid bounded complete native source snapshot or source/session binding");
    QMap<QString, QVariantMap> parsed; QSet<QString> paths;
    for (const auto &value : message.value("items").toList()) {
        if (value.metaType().id() != QMetaType::QVariantMap) return fail(error, "Native source item must be a JSON object");
        const auto item = value.toMap();
        if (!boundItem(item, source.descriptor, utc, error)) return false;
        const auto name = item.value("item_id").toString(), path = item.value("path").toString();
        if (parsed.contains(name) || paths.contains(path)) return fail(error, "Native source repeats an item ID or semantic path");
        parsed.insert(name, item); paths.insert(path);
    }
    // A valid, same-version mutation is evidence against the old value, even
    // when another admission rule rejects the new cut. Quarantine is the only
    // non-atomic side effect; no new values or receive deadlines are installed.
    bool quarantined = false;
    for (auto it = parsed.cbegin(); it != parsed.cend(); ++it) {
        auto known = source.highwater.find(it.key());
        if (known != source.highwater.end() && known->revision == it->value("revision").toLongLong() &&
            known->bytes != compact(it.value())) {
            if (!known->conflict) { known->conflict = true; quarantined = true; }
        }
    }
    if (quarantined && d->revision < quint64(SafeInteger)) ++d->revision;
    if (quarantined) return fail(error, "Same-revision source mutation quarantined the previous value");
    const auto bytes = compact(message);
    if (sequence <= source.sequence) {
        if (sequence == source.sequence && bytes == source.bytes) return true;
        return fail(error, "Native source sequence is old or its complete cut was mutated");
    }
    if (d->revision == quint64(SafeInteger)) return fail(error, "Native source view revision exhausted");
    auto candidate = *d; auto &next = candidate.sources[sourceId]; QSet<QString> selected, newItems;
    for (auto it = parsed.cbegin(); it != parsed.cend(); ++it) {
        const auto revision = it->value("revision").toLongLong();
        auto known = next.highwater.find(it.key());
        if (known != next.highwater.end() && (revision < known->revision ||
            (revision == known->revision && (known->conflict || known->omitted))))
            return fail(error, "Old, omitted or quarantined native item requires a higher revision");
        if (known == next.highwater.end() || revision > known->revision) {
            Item item; item.content = it.value(); item.bytes = compact(it.value()); item.revision = revision;
            item.acceptedUtc = utc; item.acceptedTick = tick;
            item.deadline = add(tick, add(add(item.content.value("observed_at_ms").toLongLong(),
                item.content.value("ttl_ms").toLongLong()), -utc));
            next.highwater.insert(it.key(), std::move(item)); newItems.insert(it.key());
        }
        selected.insert(it.key());
    }
    if (next.highwater.size() > 128) return fail(error, "Native source item highwater exceeded 128 identities; start a new source session");
    for (auto it = next.highwater.begin(); it != next.highwater.end(); ++it)
        if (!selected.contains(it.key())) it->omitted = true;
    next.selected = std::move(selected); next.sequence = sequence; next.snapshot = message.value("snapshot_id").toString();
    next.bytes = bytes; next.acceptedUtc = utc; next.acceptedTick = tick;
    qsizetype count = 0;
    for (const auto &registered : candidate.sources) count += registered.selected.size();
    if (count > 512) return fail(error, "Complete local source view exceeds 512 items; no items were truncated");
    bindDependencies(candidate, sourceId, newItems); ++candidate.revision;
    *d = std::move(candidate); return true;
}

void SourceRegistry::retire(const QString &sourceId, quint64 generation) {
    const auto it = d->sources.constFind(sourceId);
    if (it == d->sources.cend() || generation == 0 || it->generation != generation) return;
    d->sources.remove(sourceId); if (d->revision < quint64(SafeInteger)) ++d->revision;
}
void SourceRegistry::clear() {
    if (d->sources.isEmpty()) return;
    d->sources.clear(); if (d->revision < quint64(SafeInteger)) ++d->revision;
}
QVariantMap SourceRegistry::view(qint64 utc, qint64 tick) const {
    if (!times(utc, tick)) return {};
    QVariantList sources, items; QMap<QString, Projection> cache; QSet<QString> visiting;
    for (auto it = d->sources.cbegin(); it != d->sources.cend(); ++it) {
        const auto &source = it.value(); auto metadata = source.descriptor.wire;
        metadata.insert("generation", QVariant::fromValue<qulonglong>(source.generation));
        metadata.insert("sequence", source.sequence); metadata.insert("snapshot_id", source.snapshot);
        metadata.insert("state", source.sequence == 0 ? "waiting" : "registered");
        metadata.insert("authenticated", false); sources.append(metadata);
        auto selected = source.selected.values(); std::sort(selected.begin(), selected.end());
        for (const auto &name : selected) {
            const auto &item = source.highwater[name]; auto value = item.content;
            const auto projection = project(*d, it.key(), name, utc, tick, &cache, &visiting);
            value.insert("allowed_uses", sorted(projection.uses));
            items.append(QVariantMap{{"item", value}, {"source_id", it.key()}, {"source_robot", source.descriptor.robot},
                {"source_session_id", source.descriptor.session}, {"source_sequence", source.sequence},
                {"state", projection.state}, {"remaining_ms", projection.remaining}, {"share_enabled", projection.share},
                {"clock_mapping_verified", source.descriptor.mapped}, {"authenticated", false},
                {"source_allowed_uses", item.content.value("allowed_uses")}});
        }
    }
    return {{"schema", 2}, {"kind", "local-data-view"},
        {"view_id", QStringLiteral("local-%1-%2").arg(d->identity).arg(d->revision)},
        {"revision", QVariant::fromValue<qulonglong>(d->revision)}, {"produced_at_ms", utc}, {"produced_tick_ms", tick},
        {"sources", sources}, {"items", items}};
}
