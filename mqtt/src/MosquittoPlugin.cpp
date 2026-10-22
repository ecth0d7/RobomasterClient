#include "ClientPlugin.h"
#include "MqttTransport.h"
class MosquittoPlugin final : public QObject, public ClientPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ClientPlugin_iid FILE "mosquitto.json")
    Q_INTERFACES(ClientPlugin)
public:
    QString id() const override {
        return "mqtt.mosquitto";
    }
    QString role() const override {
        return "mqtt";
    }
    MqttEndpoint *createMqtt() override {
        return new MqttTransport;
    }
};
#include "MosquittoPlugin.moc"
