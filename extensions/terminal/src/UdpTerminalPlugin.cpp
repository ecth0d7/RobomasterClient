#include "ExtensionPlugin.h"
#include "TerminalLinks.h"

class UdpTerminalPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "udp.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override { return QStringLiteral("terminal.link.udp.v1"); }
    QString role() const override { return QStringLiteral("terminal-link"); }
    ServiceEndpoint *createService() override { return TerminalLinks::create(TerminalLinks::Kind::Udp); }
};

#include "UdpTerminalPlugin.moc"
