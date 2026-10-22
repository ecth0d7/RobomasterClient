#include "ExtensionPlugin.h"
#include "HttpDecision.h"
class HttpDecisionPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "http-decision.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override {
        return "decision.http";
    }
    QString role() const override {
        return "decision";
    }
    ServiceEndpoint *createService() override {
        return new HttpDecision;
    }
};
#include "HttpDecisionPlugin.moc"
