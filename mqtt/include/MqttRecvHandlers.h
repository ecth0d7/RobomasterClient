#ifndef MQTTRECVHANDLERS_H
#define MQTTRECVHANDLERS_H

#include <QObject>
#include <string>
#include <QVariantMap>
#include <QVector>
#include "IMqttHandler.h"
#include "robomaster_custom_client.pb.h"

// ===================== 基础接收处理器（封装通用逻辑） =====================
class BaseMqttRecvHandler : public IMqttRecvHandler
{
    Q_OBJECT
public:
    explicit BaseMqttRecvHandler(QObject *parent = nullptr) : IMqttRecvHandler(parent) {}
    ~BaseMqttRecvHandler() override = default;

protected:
    // 通用工具：Protobuf反序列化（子类复用）
    template <typename T>
    bool deserialize(const std::string& payload, T& msg) {
        return msg.ParseFromString(payload);
    }

    // 通用工具：将QVariantMap转为可读日志（调试用）
    std::string mapToString(const QVariantMap& map) const;

    // 通用工具：Protobuf RepeatedField转QVariantList
    template <typename T>
    QVariantList repeatedFieldToList(const google::protobuf::RepeatedField<T>& field) {
        QVariantList list;
        for (int i = 0; i < field.size(); ++i) {
            list.append(QVariant::fromValue(field.Get(i)));
        }
        return list;
    }
};

// ===================== 1. 比赛全局状态处理器 =====================
class GameStatusRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit GameStatusRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    // 原生Protobuf信号（C++层）
    void gameStatusReceived(const robomaster::custom_client::GameStatus& status);
    // QML专用信号（QVariantMap格式）
    void gameStatusUpdated(const QVariantMap& statusMap);

private:
    // Protobuf转QVariantMap（供QML调用）
    QVariantMap toQmlMap(const robomaster::custom_client::GameStatus& status);

private:
    robomaster::custom_client::GameStatus m_status;
    static constexpr const char* TOPIC = "GameStatus"; // 比赛全局状态消息名
};

// ===================== 2. 基地/前哨站/机器人全局状态处理器 =====================
class GlobalUnitStatusRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit GlobalUnitStatusRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void globalUnitStatusReceived(const robomaster::custom_client::GlobalUnitStatus& status);
    void globalUnitStatusUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::GlobalUnitStatus& status);

private:
    robomaster::custom_client::GlobalUnitStatus m_status;
    static constexpr const char* TOPIC = "GlobalUnitStatus"; // 全局单元状态消息名
};

// ===================== 3. 全局后勤信息处理器 =====================
class GlobalLogisticsRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit GlobalLogisticsRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void globalLogisticsReceived(const robomaster::custom_client::GlobalLogisticsStatus& status);
    void globalLogisticsUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::GlobalLogisticsStatus& status);

private:
    robomaster::custom_client::GlobalLogisticsStatus m_status;
    static constexpr const char* TOPIC = "GlobalLogisticsStatus"; // 全局后勤信息消息名
};

// ===================== 4. 全局特殊机制处理器 =====================
class GlobalSpecialMechanismRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit GlobalSpecialMechanismRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void globalSpecialMechanismReceived(const robomaster::custom_client::GlobalSpecialMechanism& status);
    void globalSpecialMechanismUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::GlobalSpecialMechanism& status);

private:
    robomaster::custom_client::GlobalSpecialMechanism m_status;
    static constexpr const char* TOPIC = "GlobalSpecialMechanism"; // 全局特殊机制消息名
};

// ===================== 5. 全局事件通知处理器 =====================
class EventRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit EventRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void eventReceived(const robomaster::custom_client::Event& event);
    void eventUpdated(const QVariantMap& eventMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::Event& event);

private:
    robomaster::custom_client::Event m_event;
    static constexpr const char* TOPIC = "Event"; // 全局事件通知消息名
};

// ===================== 6. 机器人受伤统计处理器 =====================
class RobotInjuryStatRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit RobotInjuryStatRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void robotInjuryStatReceived(const robomaster::custom_client::RobotInjuryStat& stat);
    void robotInjuryStatUpdated(const QVariantMap& statMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::RobotInjuryStat& stat);

private:
    robomaster::custom_client::RobotInjuryStat m_stat;
    static constexpr const char* TOPIC = "RobotInjuryStat"; // 机器人受伤统计消息名
};

// ===================== 7. 机器人复活状态处理器 =====================
class RobotRespawnRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit RobotRespawnRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void robotRespawnReceived(const robomaster::custom_client::RobotRespawnStatus& status);
    void robotRespawnUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::RobotRespawnStatus& status);

private:
    robomaster::custom_client::RobotRespawnStatus m_status;
    static constexpr const char* TOPIC = "RobotRespawnStatus"; // 机器人复活状态消息名
};

// ===================== 8. 机器人固定属性配置处理器 =====================
class RobotStaticStatusRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit RobotStaticStatusRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void robotStaticStatusReceived(const robomaster::custom_client::RobotStaticStatus& status);
    void robotStaticStatusUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::RobotStaticStatus& status);

private:
    robomaster::custom_client::RobotStaticStatus m_status;
    static constexpr const char* TOPIC = "RobotStaticStatus"; // 机器人固定属性消息名
};

// ===================== 9. 机器人实时动态数据处理器 =====================
class RobotDynamicStatusRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit RobotDynamicStatusRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void robotDynamicStatusReceived(const robomaster::custom_client::RobotDynamicStatus& status);
    void robotDynamicStatusUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::RobotDynamicStatus& status);

private:
    robomaster::custom_client::RobotDynamicStatus m_status;
    static constexpr const char* TOPIC = "RobotDynamicStatus"; // 机器人实时动态消息名
};

// ===================== 10. 机器人模块状态处理器 =====================
class RobotModuleStatusRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit RobotModuleStatusRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void robotModuleStatusReceived(const robomaster::custom_client::RobotModuleStatus& status);
    void robotModuleStatusUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::RobotModuleStatus& status);

private:
    robomaster::custom_client::RobotModuleStatus m_status;
    static constexpr const char* TOPIC = "RobotModuleStatus"; // 机器人模块状态消息名
};

// ===================== 11. 机器人位置与朝向处理器 =====================
class RobotPositionRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit RobotPositionRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void robotPositionReceived(const robomaster::custom_client::RobotPosition& pos);
    void robotPositionUpdated(const QVariantMap& posMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::RobotPosition& pos);

private:
    robomaster::custom_client::RobotPosition m_pos;
    static constexpr const char* TOPIC = "RobotPosition"; // 机器人位置朝向消息名
};

// ===================== 12. Buff效果信息处理器 =====================
class BuffRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit BuffRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void buffReceived(const robomaster::custom_client::Buff& buff);
    void buffUpdated(const QVariantMap& buffMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::Buff& buff);

private:
    robomaster::custom_client::Buff m_buff;
    static constexpr const char* TOPIC = "Buff"; // Buff效果信息消息名
};

// ===================== 13. 判罚信息处理器 =====================
class PenaltyInfoRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit PenaltyInfoRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void penaltyInfoReceived(const robomaster::custom_client::PenaltyInfo& info);
    void penaltyInfoUpdated(const QVariantMap& infoMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::PenaltyInfo& info);

private:
    robomaster::custom_client::PenaltyInfo m_info;
    static constexpr const char* TOPIC = "PenaltyInfo"; // 判罚信息消息名
};

// ===================== 14. 哨兵轨迹规划处理器 =====================
class RobotPathPlanRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit RobotPathPlanRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void robotPathPlanReceived(const robomaster::custom_client::RobotPathPlanInfo& info);
    void robotPathPlanUpdated(const QVariantMap& infoMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::RobotPathPlanInfo& info);

private:
    robomaster::custom_client::RobotPathPlanInfo m_info;
    static constexpr const char* TOPIC = "RobotPathPlanInfo"; // 哨兵轨迹规划消息名
};

// ===================== 15. 雷达位置信息处理器 =====================
class RadarInfoRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit RadarInfoRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void radarInfoReceived(const robomaster::custom_client::RadarInfoToClient& info);
    void radarInfoUpdated(const QVariantMap& infoMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::RadarInfoToClient& info);

private:
    robomaster::custom_client::RadarInfoToClient m_info;
    static constexpr const char* TOPIC = "RadarInfoToClient"; // 雷达位置信息消息名
};

// ===================== 16. 自定义数据流处理器 =====================
class CustomByteBlockRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit CustomByteBlockRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void customByteBlockReceived(const robomaster::custom_client::CustomByteBlock& data);
    void customByteBlockUpdated(const QVariantMap& dataMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::CustomByteBlock& data);

private:
    robomaster::custom_client::CustomByteBlock m_data;
    static constexpr const char* TOPIC = "CustomByteBlock"; // 自定义数据流消息名
    static constexpr int MAX_DATA_LEN = 300; // 协议限制最大300字节
};

// ===================== 17. 科技核心运动状态处理器 =====================
class TechCoreMotionRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit TechCoreMotionRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void techCoreMotionReceived(const robomaster::custom_client::TechCoreMotionStateSync& status);
    void techCoreMotionUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::TechCoreMotionStateSync& status);

private:
    robomaster::custom_client::TechCoreMotionStateSync m_status;
    static constexpr const char* TOPIC = "TechCoreMotionStateSync"; // 科技核心运动状态消息名
};

// ===================== 18. 机器人性能体系状态处理器 =====================
class RobotPerformanceSyncRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit RobotPerformanceSyncRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void robotPerformanceSyncReceived(const robomaster::custom_client::RobotPerformanceSelectionSync& status);
    void robotPerformanceSyncUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::RobotPerformanceSelectionSync& status);

private:
    robomaster::custom_client::RobotPerformanceSelectionSync m_status;
    static constexpr const char* TOPIC = "RobotPerformanceSelectionSync"; // 性能体系状态同步消息名
};

// ===================== 19. 英雄部署模式状态处理器 =====================
class DeployModeStatusRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit DeployModeStatusRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void deployModeStatusReceived(const robomaster::custom_client::DeployModeStatusSync& status);
    void deployModeStatusUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::DeployModeStatusSync& status);

private:
    robomaster::custom_client::DeployModeStatusSync m_status;
    static constexpr const char* TOPIC = "DeployModeStatusSync"; // 英雄部署模式状态消息名
};

// ===================== 20. 能量机关状态处理器 =====================
class RuneStatusRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit RuneStatusRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void runeStatusReceived(const robomaster::custom_client::RuneStatusSync& status);
    void runeStatusUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::RuneStatusSync& status);

private:
    robomaster::custom_client::RuneStatusSync m_status;
    static constexpr const char* TOPIC = "RuneStatusSync"; // 能量机关状态同步消息名
};

// ===================== 21. 哨兵状态处理器 =====================
class SentryStatusRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit SentryStatusRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void sentryStatusReceived(const robomaster::custom_client::SentryStatusSync& status);
    void sentryStatusUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::SentryStatusSync& status);

private:
    robomaster::custom_client::SentryStatusSync m_status;
    static constexpr const char* TOPIC = "SentryStatusSync"; // 哨兵状态同步消息名
};

// ===================== 22. 飞镖目标选择状态处理器 =====================
class DartTargetStatusRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit DartTargetStatusRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void dartTargetStatusReceived(const robomaster::custom_client::DartSelectTargetStatusSync& status);
    void dartTargetStatusUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::DartSelectTargetStatusSync& status);

private:
    robomaster::custom_client::DartSelectTargetStatusSync m_status;
    static constexpr const char* TOPIC = "DartSelectTargetStatusSync"; // 飞镖目标选择状态消息名
};

// ===================== 23. 哨兵控制结果处理器 =====================
class SentryCtrlResultRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit SentryCtrlResultRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void sentryCtrlResultReceived(const robomaster::custom_client::SentryCtrlResult& result);
    void sentryCtrlResultUpdated(const QVariantMap& resultMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::SentryCtrlResult& result);

private:
    robomaster::custom_client::SentryCtrlResult m_result;
    static constexpr const char* TOPIC = "SentryCtrlResult"; // 哨兵控制结果消息名
};

// ===================== 24. 空中支援状态处理器 =====================
class AirSupportStatusRecvHandler : public BaseMqttRecvHandler
{
    Q_OBJECT
public:
    explicit AirSupportStatusRecvHandler(QObject *parent = nullptr);
    std::string getTopicName() const override;
    void handleMessage(const std::string& topic, const std::string& payload) override;

signals:
    void airSupportStatusReceived(const robomaster::custom_client::AirSupportStatusSync& status);
    void airSupportStatusUpdated(const QVariantMap& statusMap);

private:
    QVariantMap toQmlMap(const robomaster::custom_client::AirSupportStatusSync& status);

private:
    robomaster::custom_client::AirSupportStatusSync m_status;
    static constexpr const char* TOPIC = "AirSupportStatusSync"; // 空中支援状态同步消息名
};

#endif // MQTTRECVHANDLERS_H