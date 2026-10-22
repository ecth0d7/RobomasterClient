#pragma once
#include <QByteArray>
#include <QString>
#include <QVariantMap>

// Project-local unclassified terminal-link contract, never an official season
// protocol. Public configurations have no credential or TLS-private-key input.
namespace TerminalGatewayContract {
constexpr int MaximumPayloadBytes = 64 * 1024;
QString loopbackId();
QVariantMap context(const QVariantMap &seasonContext);
bool configuration(const QString &pluginId, const QVariantMap &publicConfiguration,
                   const QVariantMap &context, QVariantMap *normalized, QString *error = nullptr);
bool decodeObservation(const QByteArray &payload, const QVariantMap &context, bool allowMock,
                       QVariantMap *observation, QString *error = nullptr);
bool encodeObservation(const QVariantMap &observation, const QVariantMap &context, bool allowMock,
                       QByteArray *payload, QString *error = nullptr);
bool wireReceived(const QVariantMap &message, const QVariantMap &context,
                  QVariantMap *normalized, QString *error = nullptr);
QVariantMap wireSend(const QString &channel, const QByteArray &payload, const QString &requestId);
bool token(const QVariant &value, int maximum = 96);
}
