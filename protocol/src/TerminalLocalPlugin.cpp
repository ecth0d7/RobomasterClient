#include "TerminalLocalCodec.h"
class TerminalLocalPlugin final : public QObject, public ClientPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ClientPlugin_iid FILE "terminal-local.json")
    Q_INTERFACES(ClientPlugin)
public:
    QString id() const override { return QStringLiteral("protocol.terminal.local.v1"); }
    QString role() const override { return QStringLiteral("protocol"); }
    ProtocolEndpoint *createProtocol() override { return new TerminalLocalCodec; }
};
#include "TerminalLocalPlugin.moc"
