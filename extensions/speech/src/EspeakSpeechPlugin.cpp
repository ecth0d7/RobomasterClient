#include "ExtensionPlugin.h"
#include "EspeakSpeech.h"
class EspeakSpeechPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "espeak-speech.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override {
        return "speech.espeak";
    }
    QString role() const override {
        return "speech";
    }
    ServiceEndpoint *createService() override {
        return new EspeakSpeech;
    }
};
#include "EspeakSpeechPlugin.moc"
