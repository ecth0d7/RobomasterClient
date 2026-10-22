#include "CodexDecision.h"
#include "ExtensionPlugin.h"

class CodexDecisionPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "codex-decision.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override { return "decision.codex"; }
    QString role() const override { return "decision"; }
    ServiceEndpoint *createService() override { return new CodexDecision; }
};
#include "CodexDecisionPlugin.moc"
