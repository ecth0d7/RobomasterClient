#include "VideoReceiver.h"
class FfmpegVideoPlugin final : public QObject, public ClientPlugin, public EncodedVideoFactory {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ClientPlugin_iid FILE "ffmpeg.json")
    Q_INTERFACES(ClientPlugin EncodedVideoFactory)
public:
    QString id() const override {
        return "video.ffmpeg";
    }
    QString role() const override {
        return "video";
    }
    VideoEndpoint *createVideo(const QVariantMap &config) override {
        // Preserve source/multicast settings and validate ports before narrowing.
        auto udp=config;udp["input_mode"]="udp";
        return new VideoReceiver(nullptr, udp);
    }
    VideoEndpoint *createEncodedVideo(const QVariantMap &config) override {
        auto encoded = config;
        encoded["input_mode"] = "encoded";
        return new VideoReceiver(nullptr, encoded);
    }
};
#include "FfmpegVideoPlugin.moc"
