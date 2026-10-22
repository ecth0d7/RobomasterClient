#pragma once
#include <QString>

namespace RobotIdentity {
inline bool valid(int id) {
    const int type = id > 100 ? id - 100 : id;
    return (id < 100 || id > 100) && (type >= 1 && type <= 9);
}
inline QString mqttId(int id) {
    return valid(id) ? QString::number(id) : QString();
}
inline int unitIndex(int robotId) {
    const int ids[] = {1, 2, 3, 4, 7};
    const int base = robotId > 100 ? robotId - 100 : robotId;
    for (int i = 0; i < 5; ++i)
        if (ids[i] == base)
            return i;
    return -1;
}
inline int healthIndex(int robotId, int clientId) {
    const int index = unitIndex(robotId);
    return index < 0 ? -1 : index + ((robotId > 100) == (clientId > 100) ? 0 : 5);
}
} // RobotIdentity 命名空间
