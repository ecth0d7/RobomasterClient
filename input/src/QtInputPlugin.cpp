#include "ExtensionPlugin.h"
#include "InputController.h"
class QtInputPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "qt-input.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override {
        return "input.qt";
    }
    QString role() const override {
        return "input";
    }
    InputEndpoint *createInput(const QVariantMap &) override {
        return new InputController;
    }
};
#include "QtInputPlugin.moc"
