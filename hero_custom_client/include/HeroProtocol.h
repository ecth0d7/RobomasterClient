#pragma once

#include <QByteArray>
#include <QVariantMap>
#include <QtGlobal>

namespace HeroProtocol {

constexpr int TelemetrySize = 46;
constexpr int CommandSize = 30;
constexpr int VideoHeaderSize = 12;
constexpr int VideoSliceSize = 284;

quint16 crc16Mcrf4xx(const char *data, int size);
bool parseTelemetry(const QByteArray &payload, QVariantMap &telemetry);
QByteArray makeCommand(quint16 sequence, quint8 command, qint8 parameter = 0);

} // namespace HeroProtocol
