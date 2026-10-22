#include "ExtensionPlugin.h"
#include "TerminalLinks.h"

class LoopbackTerminalPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "loopback.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override { return QStringLiteral("terminal.link.loopback.v1"); }
    QString role() const override { return QStringLiteral("terminal-link"); }
    ServiceEndpoint *createService() override { return TerminalLinks::create(TerminalLinks::Kind::Loopback); }
};

#include "LoopbackTerminalPlugin.moc"
