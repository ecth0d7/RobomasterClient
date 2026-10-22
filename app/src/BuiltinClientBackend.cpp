#include "ClientBackend.h"
#include "MqttTransport.h"
#include "TelemetryStore.h"
#include "BuiltinProtocolCodec.h"
#include "OperatorCommandPolicy.h"

// 供进程内工具与检查使用的便捷构造函数。具体实现放在独立
// 静态库编译单元，正式程序使用完全注入的构造函数，
// 因而不会强制链接未选择的协议实现。
ClientBackend::ClientBackend(const QString &host, int port, QObject *parent)
    : ClientBackend(host, port, std::make_unique<MqttTransport>(),
                    std::make_unique<BuiltinProtocolCodec>(), parent) {
}

ClientBackend::ClientBackend(const QString &host, int port, std::unique_ptr<MqttEndpoint> transport,
                             std::unique_ptr<ProtocolEndpoint> protocol, QObject *parent)
    : ClientBackend(host, port, std::move(transport), std::move(protocol),
                    std::make_unique<TelemetryStore>(), std::make_unique<OperatorCommandPolicy>(),
                    parent) {
}
