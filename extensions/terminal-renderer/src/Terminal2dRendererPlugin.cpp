#include "ExtensionPlugin.h"
#include "Terminal2dRenderer.h"

class Terminal2dRendererPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "renderer-2d.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override { return QStringLiteral("renderer.terminal.2d.v1"); }
    QString role() const override { return QStringLiteral("terminal-renderer"); }
    ServiceEndpoint *createService() override { return new Terminal2dRenderer; }
};
#include "Terminal2dRendererPlugin.moc"
