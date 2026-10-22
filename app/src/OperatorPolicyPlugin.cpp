#include "OperatorCommandPolicy.h"
class OperatorPolicyPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "operator-policy.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override {
        return "policy.operator";
    }
    QString role() const override {
        return "policy";
    }
    CommandPolicyEndpoint *createCommandPolicy(const QVariantMap &) override {
        return new OperatorCommandPolicy;
    }
};
#include "OperatorPolicyPlugin.moc"
