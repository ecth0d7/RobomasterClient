#pragma once

#include <QByteArray>
#include <QVariantMap>
#include <QtGlobal>

namespace HeroProtocol {

// 0x0310/0x0311 的 raw payload 固定尺寸，protobuf 只负责 MQTT 外层封装。
constexpr int TelemetrySize = 46;
constexpr int CommandSize = 30;
constexpr int VideoHeaderSize = 12;
constexpr int VideoSliceSize = 284;

// CRC16/MCRF4XX: init=0xFFFF, reflected polynomial=0x8408, no final xor.
quint16 crc16Mcrf4xx(const char *data, int size);

// 校验 HNU-TLM 的长度、magic、type 和 CRC 后再解析所有字段。
bool parseTelemetry(const QByteArray &payload, QVariantMap &telemetry);

// 生成固定 30B HNU-CMD；前 14B 为命令，后 16B 保留字节保持为零。
QByteArray makeCommand(quint16 sequence, quint8 command, qint8 parameter = 0);

} // namespace HeroProtocol
