#include "ExtensionPlugin.h"
#include "TcpBridge.h"
class TcpBridgePlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "tcp-bridge.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override {
        return "bridge.tcp";
    }
    QString role() const override {
        return "bridge";
    }
    ServiceEndpoint *createService() override {
        return new TcpBridge;
    }
};
#include "TcpBridgePlugin.moc"
