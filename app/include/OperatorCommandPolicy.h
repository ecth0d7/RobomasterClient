#pragma once
#include "ExtensionPlugin.h"

// 所有发出数据包共用一个权限判断入口。模型和桥接只提供信息，
// 操作员接受建议后仍通过普通 operator 来源执行显式操作。
class OperatorCommandPolicy final : public CommandPolicyEndpoint {
public:
    bool allow(const QString &origin, const QString &messageType, const QVariantMap &, int robotId,
               QString *error) const override;
};
