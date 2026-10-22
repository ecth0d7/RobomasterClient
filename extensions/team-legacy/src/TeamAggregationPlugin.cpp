#include "ExtensionPlugin.h"
#include "TeamAggregation.h"

class TeamAggregationPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "team-aggregation.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override { return QStringLiteral("team.aggregate.v2"); }
    QString role() const override { return QStringLiteral("aggregation"); }
    ServiceEndpoint *createService() override { return new TeamAggregation; }
};

#include "TeamAggregationPlugin.moc"
