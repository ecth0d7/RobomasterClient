#include "ExtensionPlugin.h"
#include "TelemetryStore.h"
class TelemetryPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "telemetry.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override {
        return "state.telemetry";
    }
    QString role() const override {
        return "state";
    }
    TelemetryEndpoint *createTelemetry(const QVariantMap &) override {
        return new TelemetryStore;
    }
};
#include "TelemetryPlugin.moc"
