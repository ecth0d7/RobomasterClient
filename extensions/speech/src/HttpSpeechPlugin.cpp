#include "ExtensionPlugin.h"
#include "HttpSpeech.h"
class HttpSpeechPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "http-speech.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override {
        return "speech.piper-http";
    }
    QString role() const override {
        return "speech";
    }
    ServiceEndpoint *createService() override {
        return new HttpSpeech;
    }
};
#include "HttpSpeechPlugin.moc"
