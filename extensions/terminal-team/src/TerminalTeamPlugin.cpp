#include "ExtensionPlugin.h"
#include "TerminalTeamAggregation.h"
class TerminalTeamPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "terminal-team.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override { return QStringLiteral("terminal.team.aggregate.v3"); }
    QString role() const override { return QStringLiteral("terminal-team"); }
    ServiceEndpoint *createService() override { return new TerminalTeamAggregation; }
};
#include "TerminalTeamPlugin.moc"
