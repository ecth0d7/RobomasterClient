#include "ProtocolCodec.h"
#include "robomaster_custom_client.pb.h"
#include <google/protobuf/descriptor.h>
#include <google/protobuf/message.h>
#include <cmath>
#include <algorithm>
#include <limits>
#include <memory>

namespace {
using google::protobuf::Message;
using Field = google::protobuf::FieldDescriptor;

std::unique_ptr<Message> createMessage(const QString &topic) {
    // 保留生成的 Protobuf 编译单元，避免静态库链接时被裁掉。
    const auto *file = robomaster::custom_client::GameStatus::descriptor()->file();
    const auto *descriptor = file->FindMessageTypeByName(topic.toStdString());
    if (!descriptor)
        return {};
    return std::unique_ptr<Message>(
        google::protobuf::MessageFactory::generated_factory()->GetPrototype(descriptor)->New());
}

bool finiteFields(const Message &message) {
    const auto *descriptor = message.GetDescriptor();
    const auto *reflection = message.GetReflection();
    for (int i = 0; i < descriptor->field_count(); ++i) {
        const auto *field = descriptor->field(i);
        if (field->cpp_type() == Field::CPPTYPE_FLOAT && reflection->HasField(message, field) &&
            !std::isfinite(reflection->GetFloat(message, field)))
            return false;
    }
    return true;
}
QVariant readField(const Message &message, const Field *field, int index = -1);
QVariantMap readMessage(const Message &message) {
    QVariantMap result;
    const auto *descriptor = message.GetDescriptor();
    const auto *reflection = message.GetReflection();
    for (int i = 0; i < descriptor->field_count(); ++i) {
        const auto *field = descriptor->field(i);
        const auto name = QString::fromStdString(field->name());
        if (field->is_repeated()) {
            QVariantList values;
            for (int j = 0; j < reflection->FieldSize(message, field); ++j)
                values.append(readField(message, field, j));
            result.insert(name, values);
        } else if (reflection->HasField(message, field)) {
            // 缺失的 optional 字段保持缺失；明确收到的 0 和 false 必须保留。
            result.insert(name, readField(message, field));
        }
    }
    return result;
}
QVariant readField(const Message &message, const Field *field, int index) {
    const auto *r = message.GetReflection();
    const bool repeated = index >= 0;
    switch (field->cpp_type()) {
    case Field::CPPTYPE_INT32:
        return repeated ? r->GetRepeatedInt32(message, field, index) : r->GetInt32(message, field);
    case Field::CPPTYPE_UINT32:
        return repeated ? r->GetRepeatedUInt32(message, field, index)
                        : r->GetUInt32(message, field);
    case Field::CPPTYPE_UINT64: {
        const quint64 value = repeated ? r->GetRepeatedUInt64(message, field, index) : r->GetUInt64(message, field);
        // QML numbers cannot preserve integers above 2^53-1. Keep the exact
        // decimal representation for those values; normal economy stays numeric.
        if (value > 9007199254740991ULL) return QString::number(value);
        return QVariant::fromValue<qulonglong>(value);
    }
    case Field::CPPTYPE_FLOAT:
        return repeated ? r->GetRepeatedFloat(message, field, index) : r->GetFloat(message, field);
    case Field::CPPTYPE_BOOL:
        return repeated ? r->GetRepeatedBool(message, field, index) : r->GetBool(message, field);
    case Field::CPPTYPE_STRING: {
        const auto value =
            repeated ? r->GetRepeatedString(message, field, index) : r->GetString(message, field);
        if (field->type() == Field::TYPE_BYTES)
            return QString::fromLatin1(QByteArray(value.data(), int(value.size())).toHex());
        return QString::fromStdString(value);
    }
    case Field::CPPTYPE_MESSAGE:
        return readMessage(repeated ? r->GetRepeatedMessage(message, field, index)
                                    : r->GetMessage(message, field));
    default:
        return {};
    }
}

struct Range {
    const char *field;
    qint64 min;
    qint64 max;
};
const QMap<QString, QList<Range>> commandRanges{
    {"KeyboardMouseControl",
     {{"mouse_x", -32768, 32767},
      {"mouse_y", -32768, 32767},
      {"mouse_z", -32768, 32767},
      {"keyboard_value", 0, 65535}}},
    {"CustomControl", {}},
    {"MapClickCmd",
     {{"is_send_all", 0, 2},
      {"mode", 1, 4},
      {"enemy_id", 0, 255},
      {"ascii", 0, 255},
      {"type", 1, 2}}},
    {"AssemblyCommand", {{"operation", 0, 2}, {"difficulty", 1, 4}}},
    {"RobotPerformanceSelectionCommand",
     {{"shooter", 1, 4}, {"chassis", 1, 4}, {"sentry_control", 0, 1}}},
    {"CommonCommand", {{"cmd_type", 1, 6}, {"param", 0, std::numeric_limits<quint32>::max()}}},
    {"HeroDeployModeEventCommand", {{"mode", 0, 1}}},
    {"RuneActivateCommand", {{"activate", 1, 1}}},
    {"DartCommand", {{"target_id", 1, 5}}},
    {"SentryCtrlCommand", {{"command_id", 1, 12}}},
    {"AirSupportCommand", {{"command_id", 0, 3}}}};

bool fail(QString *error, const QString &text) {
    if (error)
        *error = text;
    return false;
}
}

QStringList Protocol::receiveTopics() {
    return {"GameStatus",
            "GlobalUnitStatus",
            "GlobalLogisticsStatus",
            "GlobalSpecialMechanism",
            "Event",
            "RobotInjuryStat",
            "RobotRespawnStatus",
            "RobotStaticStatus",
            "RobotDynamicStatus",
            "RobotModuleStatus",
            "RobotPosition",
            "Buff",
            "PenaltyInfo",
            "RobotPathPlanInfo",
            "MapClickInfo",
            "RadarInfoToClient",
            "CustomByteBlock",
            "TechCoreMotionStateSync",
            "RobotPerformanceSelectionSync",
            "DeployModeStatusSync",
            "RuneStatusSync",
            "SentryStatusSync",
            "DartSelectTargetStatusSync",
            "SentryCtrlResult",
            "AirSupportStatusSync"};
}

std::optional<Protocol::Message> Protocol::decode(const QString &topic, const QByteArray &payload,
                                                  QString *error) {
    if (error)
        error->clear();
    if (!receiveTopics().contains(topic) || payload.size() > 64 * 1024) {
        fail(error, "Unsupported topic or oversized protobuf packet");
        return {};
    }
    auto message = createMessage(topic);
    if (!message || !message->ParseFromArray(payload.constData(), payload.size())) {
        fail(error, "Malformed protobuf packet: " + topic);
        return {};
    }
    if (!finiteFields(*message)) {
        fail(error, "Non-finite telemetry value");
        return {};
    }
    if (topic == "GlobalUnitStatus") {
        const auto &status =
            static_cast<const robomaster::custom_client::GlobalUnitStatus &>(*message);
        if (status.robot_health_size() > 10) {
            fail(error, "GlobalUnitStatus health array exceeds 10 robots");
            return {};
        }
    }
    if (topic == "RobotPathPlanInfo") {
        const auto &path =
            static_cast<const robomaster::custom_client::RobotPathPlanInfo &>(*message);
        if (path.offset_x_size() != path.offset_y_size() || path.offset_x_size() > 49) {
            fail(error, "Invalid robot path arrays");
            return {};
        }
    }
    if (topic == "RadarInfoToClient" &&
        static_cast<const robomaster::custom_client::RadarInfoToClient &>(*message)
                .radar_single_robot_info_size() > 12) {
        fail(error, "Radar array exceeds 12 robots");
        return {};
    }
    if (topic == "CustomByteBlock" &&
        static_cast<const robomaster::custom_client::CustomByteBlock &>(*message).data().size() >
            300) {
        fail(error, "CustomByteBlock exceeds 300 bytes");
        return {};
    }
    return Protocol::Message{topic, readMessage(*message)};
}

std::optional<Protocol::Packet> Protocol::encode(const QString &topic, const QVariantMap &fields,
                                                 QString *error) {
    if (error)
        error->clear();
    if (!commandRanges.contains(topic) || fields.isEmpty()) {
        fail(error, "操作为空或协议未支持：" + topic);
        return {};
    }
    if (topic == "SentryCtrlCommand" && fields.value("command_id").toInt() == 2) {
        fail(error, "哨兵指令2未在V2.0.0中定义");
        return {};
    }
    if (topic == "CommonCommand" && fields.value("cmd_type").toInt() == 1 &&
        fields.value("param").toUInt() % 10) {
        fail(error, "17 mm兑换数量须为10的倍数");
        return {};
    }
    if (topic == "MapClickCmd" && fields.value("mode").toInt() == 4) {
        const int ascii = fields.value("ascii").toInt();
        if (!((ascii >= 'C' && ascii <= 'L') || ascii == 'N' || ascii == 'O' ||
              (ascii >= 'Q' && ascii <= 'Z'))) {
            fail(error, "地图标记字母不合法");
            return {};
        }
    }
    auto message = createMessage(topic);
    const auto *descriptor = message->GetDescriptor();
    const auto *reflection = message->GetReflection();
    for (auto it = fields.cbegin(); it != fields.cend(); ++it) {
        const auto *field = descriptor->FindFieldByName(it.key().toStdString());
        if (!field) {
            fail(error, "协议未支持的操作字段：" + it.key());
            return {};
        }
        bool valid = false;
        const double number = it.value().toDouble(&valid);
        for (const auto &range : commandRanges.value(topic)) {
            if (it.key() == QLatin1String(range.field) &&
                (!valid || !std::isfinite(number) || std::floor(number) != number ||
                 number < range.min || number > range.max)) {
                fail(error, "操作参数超出范围或类型不符：" + it.key());
                return {};
            }
        }
        switch (field->cpp_type()) {
        case Field::CPPTYPE_INT32:
            reflection->SetInt32(message.get(), field, it.value().toInt());
            break;
        case Field::CPPTYPE_UINT32:
            reflection->SetUInt32(message.get(), field, it.value().toUInt());
            break;
        case Field::CPPTYPE_BOOL:
            if (it.value().metaType().id() != QMetaType::Bool) {
                fail(error, "操作参数须为布尔值：" + it.key());
                return {};
            }
            reflection->SetBool(message.get(), field, it.value().toBool());
            break;
        case Field::CPPTYPE_FLOAT:
            if (!valid || !std::isfinite(number) || number < 0 ||
                number > (it.key() == "map_x" ? 28 : 15)) {
                fail(error, "地图坐标不合法");
                return {};
            }
            reflection->SetFloat(message.get(), field, float(number));
            break;
        case Field::CPPTYPE_STRING: {
            QByteArray bytes;
            if (it.value().metaType().id() == QMetaType::QByteArray) {
                // Native adapters already hold binary data. Never convert it to
                // text: embedded NUL/non-UTF8 bytes are valid protocol content.
                bytes = it.value().toByteArray();
            } else if (it.value().metaType().id() == QMetaType::QString) {
                const auto text = it.value().toString();
                if (text.size() > 60 || text.size() % 2 || std::any_of(text.cbegin(), text.cend(), [](QChar c) {
                        return !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') ||
                                 (c >= 'A' && c <= 'F'));
                    })) {
                    fail(error, "十六进制数据不合法");
                    return {};
                }
                bytes = QByteArray::fromHex(text.toLatin1());
            } else {
                fail(error, "字节数据须为十六进制文本或二进制字节数组");
                return {};
            }
            if ((topic == "CustomControl" && bytes.size() > 30) ||
                (topic == "MapClickCmd" && bytes.size() != 7)) {
                fail(error, "操作数据字节数不符合协议");
                return {};
            }
            reflection->SetString(message.get(), field, bytes.toStdString());
            break;
        }
        default:
            fail(error, "协议未支持的字段类型");
            return {};
        }
    }
    // 每条无状态命令只包含本次调用者指定的字段。
    // 本次省略的 optional 字段不能继承上次命令的值。
    std::string payload;
    if (!message->SerializeToString(&payload)) {
        fail(error, "操作编码失败");
        return {};
    }
    return Protocol::Packet{topic, QByteArray(payload.data(), int(payload.size()))};
}
