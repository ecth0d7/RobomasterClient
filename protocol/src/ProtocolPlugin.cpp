#include "BuiltinProtocolCodec.h"
class ProtocolPlugin final : public QObject, public ClientPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ClientPlugin_iid FILE "rm2026.json")
    Q_INTERFACES(ClientPlugin)
public:
    QString id() const override {
        return "protocol.rm2026.v2";
    }
    QString role() const override {
        return "protocol";
    }
    ProtocolEndpoint *createProtocol() override {
        return new BuiltinProtocolCodec;
    }
};
#include "ProtocolPlugin.moc"
