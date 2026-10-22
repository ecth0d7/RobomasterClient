#include "OperatorCommandPolicy.h"
#include "RobotIdentity.h"

bool OperatorCommandPolicy::allow(const QString &origin, const QString &messageType,
                                  const QVariantMap &, int robotId, QString *error) const {
    if (error)
        error->clear();
    QString reason;
    if (!RobotIdentity::valid(robotId))
        reason = QStringLiteral("尚未选择机器人身份");
    else if (origin != QLatin1String("operator") && origin != QLatin1String("input"))
        reason = QStringLiteral("请由操作手确认服务建议");
    else if ((messageType == QLatin1String("KeyboardMouseControl")) !=
             (origin == QLatin1String("input")))
        reason = QStringLiteral("输入指令来源不匹配");
    if (error)
        *error = reason;
    return reason.isEmpty();
}
