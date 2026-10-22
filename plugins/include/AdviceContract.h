#pragma once
#include <QJsonObject>
#include <QString>

// 适配器与宿主共用的建议契约。校验不依赖具体模型服务，
// 也不会把建议转换成机器人指令。
namespace AdviceContract {
QJsonObject schema();
bool validate(const QJsonObject &advice, QString *error = nullptr);
} // AdviceContract 命名空间
