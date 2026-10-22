#include "TerminalRendererContract.h"

#include <QCryptographicHash>
#include <QJsonDocument>
#include <QMap>
#include <QSet>
#include <algorithm>
#include <cmath>

namespace TerminalRendererContract {
namespace {
constexpr qint64 Safe = 9007199254740991LL;
constexpr int MaximumHistory = 1024;
bool fail(QString *error, const QString &message) { if (error) *error = message; return false; }
QByteArray compact(const QVariant &value) { return QJsonDocument::fromVariant(value).toJson(QJsonDocument::Compact); }
bool number(const QVariant &value, double low, double high, double *out = nullptr) {
    const auto type = value.metaType().id();
    if (type != QMetaType::Int && type != QMetaType::UInt && type != QMetaType::LongLong &&
        type != QMetaType::ULongLong && type != QMetaType::Double && type != QMetaType::Float) return false;
    const auto n = value.toDouble();
    if (!std::isfinite(n) || n < low || n > high) return false;
    if (out) *out = n;
    return true;
}
bool integer(const QVariant &value, qint64 low, qint64 high, qint64 *out = nullptr) {
    double n = 0;
    if (!number(value, double(low), double(high), &n) || std::floor(n) != n) return false;
    if (out) *out = qint64(n);
    return true;
}
bool text(const QVariant &value, int limit, bool empty = false) {
    if (value.metaType().id() != QMetaType::QString || value.toString().size() > limit ||
        (!empty && value.toString().isEmpty())) return false;
    for (const auto c : value.toString())
        if (c.isNull() || c.category() == QChar::Other_Control || c.category() == QChar::Separator_Line ||
            c.category() == QChar::Separator_Paragraph) return false;
    return true;
}
bool id(const QVariant &value, int limit = 96) {
    if (!text(value, limit)) return false;
    for (const auto c : value.toString()) {
        const auto u = c.unicode();
        if (!((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') || (u >= '0' && u <= '9') ||
              u == '_' || u == '-' || u == '.' || u == ':' || u == '/')) return false;
    }
    return true;
}
bool keys(const QVariantMap &map, const QSet<QString> &required) {
    if (map.size() != required.size()) return false;
    for (auto it = map.cbegin(); it != map.cend(); ++it) if (!required.contains(it.key())) return false;
    return true;
}
bool null(const QVariant &value) { return !value.isValid() || value.isNull(); }
bool bounded(const QVariant &value, int depth = 0, int *nodes = nullptr, qsizetype *cost = nullptr) {
    int localNodes = 0; qsizetype localCost = 0;
    if (!nodes) nodes = &localNodes;
    if (!cost) cost = &localCost;
    if (++*nodes > 16384 || depth > 8 || *cost > 256 * 1024) return false;
    if (null(value)) { *cost += 4; return true; }
    const auto type = value.metaType().id();
    if (type == QMetaType::QVariantMap) {
        const auto map = value.toMap();
        if (map.size() > 64) return false;
        for (auto it = map.cbegin(); it != map.cend(); ++it) {
            if (!text(it.key(), 96)) return false;
            *cost += 2 * it.key().size() + 4;
            if (!bounded(it.value(), depth + 1, nodes, cost)) return false;
        }
    } else if (type == QMetaType::QVariantList) {
        const auto list = value.toList();
        if (list.size() > MaximumItems) return false;
        for (const auto &entry : list) if (!bounded(entry, depth + 1, nodes, cost)) return false;
    } else if (type == QMetaType::QString) {
        if (!text(value, 1024, true)) return false;
        *cost += 2 * value.toString().size() + 2;
    } else if (type == QMetaType::Bool) *cost += 5;
    else { if (!number(value, -double(Safe), double(Safe))) return false; *cost += 24; }
    return *cost <= 256 * 1024;
}
bool context(const QVariant &value) {
    if (value.metaType().id() != QMetaType::QVariantMap) return false;
    const auto map = value.toMap();
    return keys(map, {"profile_id", "field_profile_id", "capability_revision"}) && id(map.value("profile_id"), 128) &&
        id(map.value("field_profile_id"), 128) && id(map.value("capability_revision"), 128);
}
bool robot(const QVariant &value) {
    if (!text(value, 64)) return false;
    const auto parts = value.toString().split('/');
    if (parts.size() != 3 || (parts[0] != "red" && parts[0] != "blue") || parts[1].isEmpty() ||
        parts[1].size() > 32 || parts[2].isEmpty() || parts[2].size() > 3 || parts[2][0] < '1' || parts[2][0] > '9') return false;
    for (const auto c : parts[1]) if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '-')) return false;
    for (const auto c : parts[2]) if (c < '0' || c > '9') return false;
    return parts[1][0] >= 'a' && parts[1][0] <= 'z';
}
QVariantMap originMap(const Origin &o) {
    return {{"team_id", o.teamId}, {"robot_key", o.robotKey}, {"source_id", o.sourceId}, {"sensor_id", o.sensorId},
        {"source_kind", o.sourceKind}, {"session_id", o.sessionId}, {"sequence", o.sequence}, {"item_id", o.itemId}};
}
QString identity(const Origin &o) {
    const QVariantList parts{o.teamId, o.robotKey, o.sourceId, o.sessionId, o.itemId};
    return QString::fromLatin1(QCryptographicHash::hash(compact(parts), QCryptographicHash::Sha256).toHex());
}
QVariantMap frameMap(const Frame &f) {
    return {{"frame_id", f.id}, {"frame_revision", f.revision}, {"width_m", f.widthM}, {"height_m", f.heightM},
        {"unit", "m"}, {"origin", f.origin}, {"x_axis", f.xAxis}, {"y_axis", f.yAxis},
        {"calibration_status", f.calibrationStatus}, {"project_manual_calibration_acknowledged", f.manualCalibrationAcknowledged}};
}
QVariantMap baseRecord(const Point &p, qint64 remaining) {
    return {{"origin", originMap(p.origin)}, {"label", p.label}, {"produced_at_ms", p.producedAtMs},
        {"received_at_ms", p.receivedAtMs}, {"received_tick_ms", p.receivedTickMs}, {"remaining_ms", remaining},
        {"confidence", p.confidence}, {"diagnostic", p.origin.sourceKind == "mock" || p.state == "mock"},
        {"authoritative", false}, {"measurement_verified", false}, {"execution_allowed", false}};
}
QVariantMap textRecord(const Point &p, const QString &state, const QString &reason, qint64 remaining) {
    auto result = baseRecord(p, remaining); result["state"] = state; result["reason"] = reason; return result;
}
QByteArray measurement(const Point &p) {
    auto value = baseRecord(p, 0);
    value.remove("diagnostic");
    // Receipt clocks are host projection metadata, not part of the producer's
    // immutable measurement. Some adapters reconstruct a tick from receipt
    // age; its rounding must not manufacture a source-value conflict.
    value.remove("received_at_ms"); value.remove("received_tick_ms");
    if (p.hasSpatial) value["spatial"] = QVariantMap{{"frame_id", p.frameId}, {"frame_revision", p.frameRevision},
        {"transform_id", p.transformId}, {"unit", p.unit}, {"x", p.x}, {"y", p.y}, {"heading_deg", p.headingDegrees}};
    else value["spatial"] = QVariant{};
    return QCryptographicHash::hash(compact(value), QCryptographicHash::Sha256);
}
const QSet<QString> States{"fresh", "time_unverified", "expired", "offline", "conflict", "withdrawn", "mock",
    "superseded", "clock_invalid", "unverified", "quarantined"};
const QSet<QString> Reasons{"source_not_fresh", "freshness_expired", "clock_invalid", "mock_diagnostic", "source_unclassified",
    "time_unverified", "coordinates_missing", "unit_mismatch", "frame_mismatch", "frame_unverified", "manual_calibration_unacknowledged",
    "transform_unverified", "outside_frame", "quarantined"};
}

QVariantMap capabilities() {
    return {{"scene_schema", Schema}, {"projection_schema", Schema}, {"projection", "normalized-2d"},
        {"coordinate_convention", "screen-top-left-y-down-heading-clockwise"}, {"maximum_scene_bytes", MaximumSceneBytes},
        {"maximum_projection_bytes", 128 * 1024}, {"maximum_items", MaximumItems}, {"maximum_version_history", MaximumHistory},
        {"unknown_coordinates", "text-only"}, {"mock", "diagnostic-text-only"}, {"calibration_evidence", "native-host-only"},
        {"sensor_wire_format", false}, {"official_protocol", false}, {"robot_actions", false}, {"ue_dependency", false}};
}
bool validateConfiguration(const QVariantMap &configuration, QString *error) {
    if (error) error->clear();
    return (keys(configuration, {"schema", "context"}) && integer(configuration.value("schema"), Schema, Schema) &&
        context(configuration.value("context"))) || fail(error, "Renderer configuration requires exact schema1 and native context");
}
bool parseScene(const QVariantMap &input, Scene *out, QString *error) {
    if (error) error->clear();
    if (out) *out = {};
    if (!out || !keys(input, {"schema", "kind", "context", "team_id", "scene_id", "revision", "produced_at_ms", "produced_tick_ms", "frame", "items"}) ||
        !bounded(input) || compact(input).size() > MaximumSceneBytes || !integer(input.value("schema"), Schema, Schema) ||
        input.value("kind") != "renderer-scene" || !context(input.value("context")) || !id(input.value("team_id")) ||
        !id(input.value("scene_id"), 128) || !integer(input.value("revision"), 1, Safe) ||
        !integer(input.value("produced_at_ms"), 1, Safe) || !integer(input.value("produced_tick_ms"), 0, Safe) ||
        input.value("frame").metaType().id() != QMetaType::QVariantMap ||
        input.value("items").metaType().id() != QMetaType::QVariantList || input.value("items").toList().size() > MaximumItems)
        return fail(error, "Malformed, oversized or unversioned renderer scene");
    Scene scene;
    scene.context = input.value("context").toMap(); scene.teamId = input.value("team_id").toString();
    scene.id = input.value("scene_id").toString(); scene.revision = input.value("revision").toLongLong();
    scene.producedAtMs = input.value("produced_at_ms").toLongLong(); scene.producedTickMs = input.value("produced_tick_ms").toLongLong();
    const auto f = input.value("frame").toMap();
    if (!keys(f, {"frame_id", "frame_revision", "width_m", "height_m", "unit", "origin", "x_axis", "y_axis", "calibration_status", "project_manual_calibration_acknowledged"}) ||
        !id(f.value("frame_id"), 128) || !id(f.value("frame_revision"), 128) ||
        !number(f.value("width_m"), 0.001, 10000, &scene.frame.widthM) || !number(f.value("height_m"), 0.001, 10000, &scene.frame.heightM) ||
        f.value("unit") != "m" || f.value("x_axis") != "right" ||
        !((f.value("origin") == "lower_left" && f.value("y_axis") == "up") || (f.value("origin") == "upper_left" && f.value("y_axis") == "down")) ||
        (f.value("calibration_status") != "unverified" && f.value("calibration_status") != "project_manual" && f.value("calibration_status") != "verified") ||
        f.value("project_manual_calibration_acknowledged").metaType().id() != QMetaType::Bool)
        return fail(error, "Invalid explicit frame dimensions, axes, units or native calibration status");
    scene.frame.id = f.value("frame_id").toString(); scene.frame.revision = f.value("frame_revision").toString();
    scene.frame.origin = f.value("origin").toString(); scene.frame.xAxis = f.value("x_axis").toString(); scene.frame.yAxis = f.value("y_axis").toString();
    scene.frame.calibrationStatus = f.value("calibration_status").toString();
    scene.frame.manualCalibrationAcknowledged = f.value("project_manual_calibration_acknowledged").toBool();
    QSet<QString> seen;
    static const QSet<QString> kinds{"official_engine", "official_player_client", "local_sensor", "local_vision", "derived", "mock", "unclassified"};
    for (const auto &entry : input.value("items").toList()) {
        const auto item = entry.toMap(); Point p;
        if (entry.metaType().id() != QMetaType::QVariantMap ||
            !keys(item, {"origin", "produced_at_ms", "received_at_ms", "received_tick_ms", "remaining_ms", "state", "confidence", "label", "spatial"}) ||
            item.value("origin").metaType().id() != QMetaType::QVariantMap ||
            (!null(item.value("produced_at_ms")) && !integer(item.value("produced_at_ms"), 0, Safe)) ||
            !integer(item.value("received_at_ms"), 1, scene.producedAtMs, &p.receivedAtMs) ||
            !integer(item.value("received_tick_ms"), 0, scene.producedTickMs, &p.receivedTickMs) ||
            !integer(item.value("remaining_ms"), 0, 60000, &p.remainingMs) || !text(item.value("state"), 32) ||
            !States.contains(item.value("state").toString()) || (!null(item.value("confidence")) && !number(item.value("confidence"), 0, 1)) ||
            !text(item.value("label"), 128, true)) return fail(error, "Invalid bounded point provenance, timestamps, state or confidence");
        const auto o = item.value("origin").toMap();
        if (!keys(o, {"team_id", "robot_key", "source_id", "sensor_id", "source_kind", "session_id", "sequence", "item_id"}) ||
            o.value("team_id") != scene.teamId || !robot(o.value("robot_key")) || !id(o.value("source_id")) ||
            !text(o.value("sensor_id"), 96, true) || !text(o.value("source_kind"), 32) || !kinds.contains(o.value("source_kind").toString()) ||
            !id(o.value("session_id")) || !integer(o.value("sequence"), 1, Safe, &p.origin.sequence) || !id(o.value("item_id")))
            return fail(error, "Invalid canonical source identity or mixed team scope");
        p.origin.teamId = scene.teamId; p.origin.robotKey = o.value("robot_key").toString(); p.origin.sourceId = o.value("source_id").toString();
        p.origin.sensorId = o.value("sensor_id").toString(); p.origin.sourceKind = o.value("source_kind").toString();
        p.origin.sessionId = o.value("session_id").toString(); p.origin.itemId = o.value("item_id").toString();
        const auto key = identity(p.origin);
        if (seen.contains(key)) return fail(error, "Duplicate canonical source item in complete scene");
        seen.insert(key);
        p.producedAtMs = null(item.value("produced_at_ms")) ? QVariant{} : item.value("produced_at_ms");
        p.confidence = null(item.value("confidence")) ? QVariant{} : item.value("confidence");
        p.state = item.value("state").toString(); p.label = item.value("label").toString();
        if (!null(item.value("spatial"))) {
            const auto spatial = item.value("spatial").toMap();
            if (item.value("spatial").metaType().id() != QMetaType::QVariantMap ||
                !keys(spatial, {"frame_id", "frame_revision", "transform_id", "unit", "x", "y", "heading_deg", "transform_verified"}) ||
                !id(spatial.value("frame_id"), 128) || !id(spatial.value("frame_revision"), 128) ||
                (!spatial.value("transform_id").toString().isEmpty() && !id(spatial.value("transform_id"), 128)) || !text(spatial.value("transform_id"), 128, true) ||
                !text(spatial.value("unit"), 16) || !number(spatial.value("x"), -1000000, 1000000, &p.x) ||
                !number(spatial.value("y"), -1000000, 1000000, &p.y) ||
                (!null(spatial.value("heading_deg")) && !number(spatial.value("heading_deg"), -36000, 36000)) ||
                spatial.value("transform_verified").metaType().id() != QMetaType::Bool)
                return fail(error, "Invalid finite spatial data, frame references or transform evidence");
            p.hasSpatial = true; p.transformVerified = spatial.value("transform_verified").toBool();
            p.frameId = spatial.value("frame_id").toString(); p.frameRevision = spatial.value("frame_revision").toString();
            p.transformId = spatial.value("transform_id").toString(); p.unit = spatial.value("unit").toString();
            p.headingDegrees = null(spatial.value("heading_deg")) ? QVariant{} : spatial.value("heading_deg");
        }
        scene.items.append(p);
    }
    *out = std::move(scene); return true;
}

struct Projector::Private {
    struct Version { qint64 sequence = 0, deadline = 0; QByteArray measurement; };
    QVariantMap configuration;
    Scene scene;
    QMap<QString, Version> history;
    qint64 lastUtc = 0, lastTick = 0;
    bool configured = false, hasScene = false, clockInvalid = false;
    bool observe(qint64 utc, qint64 tick, QString *error) {
        if (utc < 1 || utc > Safe || tick < 0 || tick > Safe) return fail(error, "Invalid native renderer clock");
        if (lastUtc && (utc < lastUtc || tick < lastTick || std::abs((utc - lastUtc) - (tick - lastTick)) > 250)) clockInvalid = true;
        lastUtc = utc; lastTick = tick;
        return true;
    }
};
Projector::Projector() : d(std::make_unique<Private>()) {}
Projector::~Projector() = default;
void Projector::clear() { d = std::make_unique<Private>(); }
bool Projector::configure(const QVariantMap &configuration, QString *error) {
    clear();
    if (!validateConfiguration(configuration, error)) return false;
    d->configuration = configuration; d->configured = true; return true;
}
QVariantMap Projector::project(const QVariantMap &input, qint64 utc, qint64 tick, QString *error) {
    if (error) error->clear();
    Scene scene;
    if (!d->configured || !parseScene(input, &scene, error)) {
        if (error && error->isEmpty()) *error = "Renderer is not configured";
        return {};
    }
    if (scene.context != d->configuration.value("context").toMap() || (d->hasScene && scene.revision <= d->scene.revision) ||
        scene.producedAtMs > utc || scene.producedTickMs > tick ||
        std::abs((utc - scene.producedAtMs) - (tick - scene.producedTickMs)) > 250) {
        fail(error, "Renderer scene scope, revision or original host clocks are invalid"); return {};
    }
    if (!d->observe(utc, tick, error)) return {};
    auto history = d->history;
    for (const auto &p : scene.items) {
        const auto key = identity(p.origin);
        const auto bytes = measurement(p);
        const auto found = history.constFind(key);
        const auto deadline = scene.producedTickMs + p.remainingMs;
        if (found == history.cend()) {
            if (history.size() >= MaximumHistory) { fail(error, "Renderer version history is full; old identity tombstones were not evicted"); return {}; }
            history[key] = {p.origin.sequence, deadline, bytes};
        } else {
            if (p.origin.sequence < found->sequence || (p.origin.sequence == found->sequence && bytes != found->measurement)) {
                fail(error, "Regressed or mutated original observation at its existing sequence"); return {};
            }
            if (p.origin.sequence == found->sequence) history[key].deadline = std::min(found->deadline, deadline);
            else history[key] = {p.origin.sequence, deadline, bytes};
        }
    }
    d->history = std::move(history); d->scene = std::move(scene); d->hasScene = true;
    return view(utc, tick, error);
}
QVariantMap Projector::view(qint64 utc, qint64 tick, QString *error) {
    if (error) error->clear();
    if (!d->configured || !d->hasScene) return {};
    if (!d->observe(utc, tick, error)) return {};
    const auto &scene = d->scene;
    QVariantList markers, texts;
    int diagnostic = 0;
    for (const auto &p : scene.items) {
        const auto version = d->history.value(identity(p.origin));
        const auto remaining = qMax<qint64>(0, std::min(version.deadline, scene.producedTickMs + p.remainingMs) - tick);
        QString state = p.state, reason;
        const bool mock = p.origin.sourceKind == "mock" || p.state == "mock";
        if (mock) ++diagnostic;
        if (d->clockInvalid) { state = "clock_invalid"; reason = "clock_invalid"; }
        else if (mock) { state = "mock"; reason = "mock_diagnostic"; }
        else if (p.state != "fresh") reason = "source_not_fresh";
        else if (!remaining) { state = "expired"; reason = "freshness_expired"; }
        else if (p.origin.sourceKind == "unclassified") reason = "source_unclassified";
        else if (null(p.producedAtMs) || p.producedAtMs.toLongLong() <= 0 || p.producedAtMs.toLongLong() > scene.producedAtMs) {
            state = "time_unverified"; reason = "time_unverified";
        } else if (!p.hasSpatial) reason = "coordinates_missing";
        else if (p.unit != "m") reason = "unit_mismatch";
        else if (p.frameId != scene.frame.id || p.frameRevision != scene.frame.revision) reason = "frame_mismatch";
        else if (scene.frame.calibrationStatus == "unverified") reason = "frame_unverified";
        else if (scene.frame.calibrationStatus == "project_manual" && !scene.frame.manualCalibrationAcknowledged) reason = "manual_calibration_unacknowledged";
        else if (!p.transformVerified || p.transformId.isEmpty()) reason = "transform_unverified";
        else if (p.x < 0 || p.y < 0 || p.x > scene.frame.widthM || p.y > scene.frame.heightM) reason = "outside_frame";
        if (!reason.isEmpty()) {
            texts.append(textRecord(p, state, reason, d->clockInvalid ? 0 : remaining));
            continue;
        }
        auto marker = baseRecord(p, remaining);
        marker["state"] = "fresh"; marker["x_norm"] = p.x / scene.frame.widthM;
        marker["y_norm"] = scene.frame.origin == "lower_left" ? 1 - p.y / scene.frame.heightM : p.y / scene.frame.heightM;
        QVariant heading;
        if (!null(p.headingDegrees)) {
            auto normalized = std::fmod((scene.frame.yAxis == "up" ? -1 : 1) * p.headingDegrees.toDouble(), 360.0);
            if (normalized < 0) normalized += 360.0;
            heading = normalized == 0 ? 0.0 : normalized;
        }
        marker["heading_deg"] = heading; marker["heading_known"] = !null(heading);
        marker["transform_id"] = p.transformId; marker["transform_verified"] = true;
        marker["calibration_status"] = scene.frame.calibrationStatus;
        markers.append(marker);
    }
    QVariantMap result{{"schema", Schema}, {"kind", "renderer-projection"}, {"context", scene.context}, {"team_id", scene.teamId},
        {"scene_id", scene.id}, {"revision", scene.revision}, {"produced_at_ms", utc}, {"produced_tick_ms", tick},
        {"source_scene_produced_at_ms", scene.producedAtMs}, {"source_scene_age_ms", qMax<qint64>(0, tick - scene.producedTickMs)},
        {"frame", frameMap(scene.frame)}, {"markers", markers}, {"text_records", texts},
        {"counts", QVariantMap{{"received_items", scene.items.size()}, {"projected_items", markers.size()},
            {"text_items", texts.size()}, {"diagnostic_items", diagnostic}}},
        {"renderer", QVariantMap{{"id", "renderer.terminal.2d.v1"}, {"projection", "normalized-2d"},
            {"coordinate_convention", "screen-top-left-y-down-heading-clockwise"}, {"scene_schema", Schema}}},
        {"clock_valid", !d->clockInvalid}, {"authoritative", false}, {"execution_allowed", false}};
    if (compact(result).size() > 128 * 1024) { fail(error, "Complete projection exceeds 128 KiB; no records were truncated"); return {}; }
    return result;
}

QVariantMap projectScene(const QVariantMap &scene, qint64 utc, qint64 tick, QString *error) {
    Projector projector;
    if (!projector.configure({{"schema", Schema}, {"context", scene.value("context")}}, error)) return {};
    return projector.project(scene, utc, tick, error);
}
bool validateProjection(const QVariantMap &scene, const QVariantMap &projection, qint64 utc, qint64 tick, QString *error) {
    if (error) error->clear();
    qint64 producedUtc = 0, producedTick = 0;
    if (!bounded(projection) || compact(projection).size() > 128 * 1024 ||
        !integer(projection.value("produced_at_ms"), 1, utc, &producedUtc) ||
        !integer(projection.value("produced_tick_ms"), 0, tick, &producedTick) ||
        std::abs((utc - producedUtc) - (tick - producedTick)) > 250 ||
        projection.value("markers").metaType().id() != QMetaType::QVariantList ||
        projection.value("text_records").metaType().id() != QMetaType::QVariantList) return fail(error, "Invalid bounded renderer output or native projection clocks");
    Scene parsed;
    if (!parseScene(scene, &parsed, error)) return false;
    auto expected = projectScene(scene, producedUtc, producedTick, error);
    if (expected.isEmpty() && projection.value("clock_valid") == QVariant(false)) {
        // A real wall/steady-clock discontinuity must still be admissible as
        // a complete text-only retirement, never as current spatial guidance.
        Projector reference;
        if (reference.configure({{"schema", Schema}, {"context", parsed.context}}, error) &&
            !reference.project(scene, parsed.producedAtMs, parsed.producedTickMs, error).isEmpty())
            expected = reference.view(producedUtc, producedTick, error);
    }
    if (expected.isEmpty()) return false;
    QMap<QString, Point> originals;
    QMap<QByteArray, QString> originKeys;
    for (const auto &p : parsed.items) {
        const auto key = identity(p.origin);
        originals[key] = p; originKeys[compact(originMap(p.origin))] = key;
    }
    QMap<QString, QVariantMap> expectedMarkers;
    for (const auto &entry : expected.value("markers").toList()) {
        const auto row = entry.toMap();
        // Find by the exact canonical origin, not an assumed robot wire ID.
        expectedMarkers[originKeys.value(compact(row.value("origin")))] = row;
    }
    QMap<QString, QVariantMap> expectedTexts;
    for (const auto &entry : expected.value("text_records").toList()) {
        const auto row = entry.toMap();
        expectedTexts[originKeys.value(compact(row.value("origin")))] = row;
    }
    QSet<QString> seen;
    int diagnostic = 0;
    for (const auto &entry : projection.value("markers").toList()) {
        const auto row = entry.toMap();
        const auto key = originKeys.value(compact(row.value("origin")));
        auto reference = expectedMarkers.value(key); qint64 remaining = 0;
        if (entry.metaType().id() != QMetaType::QVariantMap || key.isEmpty() || seen.contains(key) || reference.isEmpty() ||
            !integer(row.value("remaining_ms"), 1, reference.value("remaining_ms").toLongLong(), &remaining))
            return fail(error, "Projection invented, duplicated or revived a marker");
        reference["remaining_ms"] = remaining;
        if (compact(row) != compact(reference)) return fail(error, "Marker geometry, provenance or verification status differs from the native scene");
        seen.insert(key);
    }
    for (const auto &entry : projection.value("text_records").toList()) {
        const auto row = entry.toMap();
        const auto key = originKeys.value(compact(row.value("origin")));
        qint64 remaining = 0;
        if (entry.metaType().id() != QMetaType::QVariantMap || key.isEmpty() || seen.contains(key) ||
            !text(row.value("state"), 32) || !States.contains(row.value("state").toString()) ||
            !text(row.value("reason"), 64) || !Reasons.contains(row.value("reason").toString()) ||
            !integer(row.value("remaining_ms"), 0, qMax<qint64>(0, parsed.producedTickMs + originals.value(key).remainingMs - producedTick), &remaining))
            return fail(error, "Projection text record has invalid provenance, state or lifetime");
        const auto expectedText = expectedTexts.value(key);
        const bool sameState = !expectedText.isEmpty() && row.value("state") == expectedText.value("state") && row.value("reason") == expectedText.value("reason");
        const bool expired = remaining == 0 && row.value("state") == "expired" && row.value("reason") == "freshness_expired";
        const bool invalidClock = remaining == 0 && projection.value("clock_valid") == QVariant(false) &&
            row.value("state") == "clock_invalid" && row.value("reason") == "clock_invalid";
        if (!sameState && !expired && !invalidClock) return fail(error, "Renderer text state is not the source result or a conservative expiry");
        const auto reference = textRecord(originals.value(key), row.value("state").toString(), row.value("reason").toString(), remaining);
        if (compact(row) != compact(reference)) return fail(error, "Text-only projection changed an original label or source metadata");
        if (row.value("diagnostic") == QVariant(true)) ++diagnostic;
        seen.insert(key);
    }
    if (seen.size() != originals.size()) return fail(error, "Projection is incomplete; no source records may be truncated");
    const QVariantMap counts{{"received_items", originals.size()}, {"projected_items", projection.value("markers").toList().size()},
        {"text_items", projection.value("text_records").toList().size()}, {"diagnostic_items", diagnostic}};
    if (projection.value("counts").toMap() != counts) return fail(error, "Projection counters do not describe its complete record set");
    auto normalized = projection;
    normalized["markers"] = expected.value("markers"); normalized["text_records"] = expected.value("text_records");
    normalized["counts"] = expected.value("counts");
    // A renderer may conservatively quarantine its clock; it cannot turn an
    // invalid clock into live marker output or acquire any command authority.
    if (projection.value("clock_valid") == QVariant(false)) {
        if (!projection.value("markers").toList().isEmpty()) return fail(error, "Invalid renderer clock produced live markers");
        for (const auto &entry : projection.value("text_records").toList())
            if (entry.toMap().value("state") != "clock_invalid" || entry.toMap().value("remaining_ms").toLongLong() != 0)
                return fail(error, "Invalid renderer clock failed to retire all spatial records");
        normalized["clock_valid"] = expected.value("clock_valid");
    }
    return compact(normalized) == compact(expected) || fail(error, "Projection context, frame or contract metadata differs from its source scene");
}
}
