#pragma once
#include "ClientPlugin.h"
#include "TelemetryEndpoint.h"
#include "InputEndpoint.h"
#include "ServiceEndpoint.h"

// 增量扩展契约：不修改原 ClientPlugin/1.0 的二进制接口。
class CommandPolicyEndpoint {
public:
    virtual ~CommandPolicyEndpoint() = default;
    virtual bool allow(const QString &origin, const QString &messageType, const QVariantMap &fields,
                       int robotId, QString *error) const = 0;
};

class ExtensionPlugin {
public:
    virtual ~ExtensionPlugin() = default;
    virtual QString id() const = 0;
    virtual QString role() const = 0;
    virtual TelemetryEndpoint *createTelemetry(const QVariantMap &) {
        return nullptr;
    }
    virtual InputEndpoint *createInput(const QVariantMap &) {
        return nullptr;
    }
    virtual CommandPolicyEndpoint *createCommandPolicy(const QVariantMap &) {
        return nullptr;
    }
    virtual ServiceEndpoint *createService() {
        return nullptr;
    }
};
#define ExtensionPlugin_iid "org.robomaster.client.ExtensionPlugin/1.0"
Q_DECLARE_INTERFACE(ExtensionPlugin, ExtensionPlugin_iid)
