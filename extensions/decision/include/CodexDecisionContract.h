#pragma once

#include <QByteArray>
#include <QHash>
#include <QString>
#include <QVariantMap>

namespace CodexDecisionContract {

inline constexpr qsizetype MaximumPrompt = 65536;
inline constexpr qsizetype MaximumLine = 65536;
inline constexpr qsizetype MaximumStdout = 262144;
inline constexpr qsizetype MaximumStderr = 65536;
inline constexpr qsizetype MaximumFinal = 65536;

// This validates response integrity. Rejecting a tool event cannot undo a tool
// action; process permissions and configuration remain the adapter's boundary.
class Output final {
public:
    bool append(const QByteArray &bytes, QString *error);
    bool finish(const QByteArray &finalFile, QVariantMap *advice, QString *error);
    qsizetype totalBytes() const {
        return m_totalBytes;
    }

private:
    enum class Stage { AwaitThread, AwaitTurn, InTurn, Completed };
    struct Item {
        QString type;
        bool completed = false;
    };
    bool line(const QByteArray &, QString *error);
    bool fail(QString *error, const QString &reason);
    Stage m_stage = Stage::AwaitThread;
    QHash<QString, Item> m_items;
    QByteArray m_pending, m_lastMessage;
    QString m_error;
    qsizetype m_totalBytes = 0;
    int m_events = 0, m_messages = 0, m_openItems = 0;
    bool m_failed = false, m_finished = false;
};

} // namespace CodexDecisionContract
