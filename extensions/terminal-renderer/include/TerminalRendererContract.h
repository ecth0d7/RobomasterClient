#pragma once

#include <QList>
#include <QString>
#include <QVariantMap>
#include <memory>

// Renderer input is a native host-prepared scene, never a sensor wire format.
// Geometry, source identity and clocks stay independent of QML, UE and codecs.
namespace TerminalRendererContract {
inline constexpr int Schema = 1;
inline constexpr int MaximumSceneBytes = 64 * 1024;
inline constexpr int MaximumItems = 128;

struct Frame {
    QString id, revision, origin, xAxis, yAxis, calibrationStatus;
    double widthM = 0, heightM = 0;
    bool manualCalibrationAcknowledged = false;
};
struct Origin {
    QString teamId, robotKey, sourceId, sensorId, sourceKind, sessionId, itemId;
    qint64 sequence = 0;
};
struct Point {
    Origin origin;
    QVariant producedAtMs, confidence;
    qint64 receivedAtMs = 0, receivedTickMs = 0, remainingMs = 0;
    QString state, label;
    bool hasSpatial = false, transformVerified = false;
    QString frameId, frameRevision, transformId, unit;
    double x = 0, y = 0;
    QVariant headingDegrees;
};
struct Scene {
    QVariantMap context;
    QString teamId, id;
    qint64 revision = 0, producedAtMs = 0, producedTickMs = 0;
    Frame frame;
    QList<Point> items;
};

QVariantMap capabilities();
bool validateConfiguration(const QVariantMap &, QString *error = nullptr);
bool parseScene(const QVariantMap &, Scene *, QString *error = nullptr);
QVariantMap projectScene(const QVariantMap &, qint64 utcMs, qint64 tickMs, QString *error = nullptr);
bool validateProjection(const QVariantMap &scene, const QVariantMap &projection,
                        qint64 utcMs, qint64 tickMs, QString *error = nullptr);

// A complete scene replaces its previous projection. Observation-version
// deadlines can only shrink, including across scene revisions and calibration
// changes. Old version history is bounded and is never silently evicted.
class Projector final {
public:
    Projector();
    ~Projector();
    bool configure(const QVariantMap &, QString *error = nullptr);
    QVariantMap project(const QVariantMap &scene, qint64 utcMs, qint64 tickMs,
                        QString *error = nullptr);
    QVariantMap view(qint64 utcMs, qint64 tickMs, QString *error = nullptr);
    void clear();
private:
    struct Private;
    std::unique_ptr<Private> d;
};
}
