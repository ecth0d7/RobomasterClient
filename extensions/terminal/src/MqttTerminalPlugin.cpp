#include "ExtensionPlugin.h"
#include "TerminalLinks.h"

class MqttTerminalPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "mqtt.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override { return QStringLiteral("terminal.link.mqtt.v1"); }
    QString role() const override { return QStringLiteral("terminal-link"); }
    ServiceEndpoint *createService() override { return TerminalLinks::create(TerminalLinks::Kind::Mqtt); }
};

#include "MqttTerminalPlugin.moc"
