#pragma once
#include <QVariantMap>
#include <QStringList>

namespace DecisionContext {
// 将收到的快照整理为有界、有效的推理依据。
// 实验室桥接仍使用自己的完整快照契约。
QVariantMap build(const QVariantMap &snapshot);
// Production requests use a field whitelist and verified MQTT callback-arrival
// budget. Missing/dispatch/direct timing is not evidence of fresh production
// input; offline build() intentionally keeps its separate display semantics.
QVariantMap permitted(const QVariantMap &snapshot, const QStringList &categories);
// Returns zero unless callback provenance, bounded numeric clocks and the
// original queue-age charge are explicit and internally consistent.
qint64 remainingLifetime(const QVariantMap &observation);
} // DecisionContext 命名空间
