#include "CodexDecisionContract.h"

#include "AdviceContract.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>

namespace CodexDecisionContract {
namespace {
constexpr int MaximumEvents = 2048;
constexpr int MaximumItems = 256;
constexpr int MaximumMessages = 64;

bool unsuccessfulStatus(const QJsonValue &value, bool completedEvent) {
    if (value.isUndefined())
        return false;
    if (!value.isString())
        return true;
    const auto status = value.toString().trimmed().toLower();
    if (status == "failed" || status == "error" || status == "cancelled" ||
        status == "canceled" || status == "interrupted" || status == "incomplete")
        return true;
    return completedEvent && (status == "in_progress" || status == "pending" ||
                              status == "running" || status == "started");
}

bool jsonObject(const QByteArray &bytes, QJsonObject *object) {
    QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(bytes, &parse);
    if (parse.error != QJsonParseError::NoError || !document.isObject())
        return false;
    *object = document.object();
    return true;
}
}

bool Output::fail(QString *error, const QString &reason) {
    if (!m_failed)
        m_error = reason;
    m_failed = true;
    m_pending.clear();
    m_lastMessage.clear();
    if (error)
        *error = m_error;
    return false;
}

bool Output::append(const QByteArray &bytes, QString *error) {
    if (error)
        error->clear();
    if (m_failed)
        return fail(error, m_error);
    if (m_finished)
        return fail(error, QStringLiteral("Codex 输出结束后仍有数据"));
    if (bytes.size() > MaximumStdout - m_totalBytes)
        return fail(error, QStringLiteral("Codex 输出超过 256 KiB"));
    m_totalBytes += bytes.size();
    m_pending += bytes;
    qsizetype consumed = 0;
    while (true) {
        const auto newline = m_pending.indexOf('\n', consumed);
        if (newline < 0)
            break;
        if (newline - consumed > MaximumLine)
            return fail(error, QStringLiteral("Codex 单行输出超过 64 KiB"));
        const auto next = m_pending.mid(consumed, newline - consumed);
        consumed = newline + 1;
        if (!line(next, error))
            return false;
    }
    if (consumed)
        m_pending.remove(0, consumed);
    if (m_pending.size() > MaximumLine)
        return fail(error, QStringLiteral("Codex 单行输出超过 64 KiB"));
    return true;
}

bool Output::line(const QByteArray &bytes, QString *error) {
    const auto trimmed = bytes.trimmed();
    if (trimmed.isEmpty())
        return true;
    if (++m_events > MaximumEvents)
        return fail(error, QStringLiteral("Codex 输出事件过多"));
    QJsonObject event;
    if (!jsonObject(trimmed, &event) || !event.value("type").isString())
        return fail(error, QStringLiteral("Codex 输出事件格式无效"));
    if (m_stage == Stage::Completed)
        return fail(error, QStringLiteral("Codex 完成后仍有输出事件"));
    const auto type = event.value("type").toString();
    if (type == "error" || type == "turn.failed" ||
        (!event.value("error").isUndefined() && !event.value("error").isNull()))
        return fail(error, QStringLiteral("Codex 请求未成功完成"));
    if (type == "thread.started") {
        const auto id = event.value("thread_id");
        if (m_stage != Stage::AwaitThread || !id.isString() || id.toString().isEmpty() ||
            id.toString().size() > 128)
            return fail(error, QStringLiteral("Codex 会话事件顺序无效"));
        m_stage = Stage::AwaitTurn;
        return true;
    }
    if (type == "turn.started") {
        if (m_stage != Stage::AwaitTurn)
            return fail(error, QStringLiteral("Codex 请求事件顺序无效"));
        m_stage = Stage::InTurn;
        return true;
    }
    if (m_stage != Stage::InTurn)
        return fail(error, QStringLiteral("Codex 请求事件顺序无效"));
    if (type == "turn.completed") {
        if (m_openItems != 0 || unsuccessfulStatus(event.value("status"), true))
            return fail(error, QStringLiteral("Codex 请求包含未完成的输出"));
        m_stage = Stage::Completed;
        return true;
    }
    if (type != "item.started" && type != "item.updated" && type != "item.completed")
        return fail(error, QStringLiteral("Codex 返回了不支持的事件"));
    const auto itemValue = event.value("item");
    if (!itemValue.isObject())
        return fail(error, QStringLiteral("Codex 输出项目格式无效"));
    const auto item = itemValue.toObject();
    const auto idValue = item.value("id");
    const auto kind = item.value("type").toString();
    if (!idValue.isString() || idValue.toString().isEmpty() || idValue.toString().size() > 128)
        return fail(error, QStringLiteral("Codex 输出项目标识无效"));
    if (kind != "reasoning" && kind != "agent_message" && kind != "todo_list")
        return fail(error, QStringLiteral("Codex 请求包含工具或不支持的项目"));
    const bool complete = type == "item.completed";
    if (unsuccessfulStatus(item.value("status"), complete) ||
        (!item.value("error").isUndefined() && !item.value("error").isNull()))
        return fail(error, QStringLiteral("Codex 请求包含失败或未完成的项目"));
    auto found = m_items.find(idValue.toString());
    if (found != m_items.end()) {
        if (found->type != kind || found->completed || type == "item.started")
            return fail(error, QStringLiteral("Codex 输出项目重复或顺序无效"));
        if (complete) {
            found->completed = true;
            --m_openItems;
        }
    } else {
        if (m_items.size() >= MaximumItems)
            return fail(error, QStringLiteral("Codex 输出项目过多"));
        // The official JSONL example emits a completed agent message directly,
        // so a preceding item.started is not required for each completed item.
        m_items.insert(idValue.toString(), Item{kind, complete});
        if (!complete)
            ++m_openItems;
    }
    if (kind == "agent_message") {
        const auto text = item.value("text");
        if ((!text.isUndefined() && !text.isString()) || (complete && !text.isString()))
            return fail(error, QStringLiteral("Codex 建议文本格式无效"));
        const auto encoded = text.toString().toUtf8();
        if (encoded.size() > MaximumFinal)
            return fail(error, QStringLiteral("Codex 建议文本超过 64 KiB"));
        if (complete) {
            if (++m_messages > MaximumMessages)
                return fail(error, QStringLiteral("Codex 建议消息过多"));
            m_lastMessage = encoded;
        }
    }
    // Reasoning and todo contents are deliberately not retained or surfaced.
    return true;
}

bool Output::finish(const QByteArray &finalFile, QVariantMap *advice, QString *error) {
    if (error)
        error->clear();
    if (advice)
        advice->clear();
    if (m_failed)
        return fail(error, m_error);
    if (m_finished)
        return fail(error, QStringLiteral("Codex 输出已结束"));
    if (!m_pending.isEmpty()) {
        const auto trailing = m_pending;
        m_pending.clear();
        if (!line(trailing, error))
            return false;
    }
    if (m_stage != Stage::Completed || m_openItems != 0 || m_messages == 0)
        return fail(error, QStringLiteral("Codex 请求缺少完整的成功结果"));
    if (finalFile.size() > MaximumFinal)
        return fail(error, QStringLiteral("Codex 最终建议超过 64 KiB"));
    QJsonObject finalObject, messageObject;
    if (!jsonObject(finalFile.trimmed(), &finalObject) ||
        !jsonObject(m_lastMessage.trimmed(), &messageObject))
        return fail(error, QStringLiteral("Codex 最终建议不是有效 JSON 对象"));
    if (finalObject != messageObject)
        return fail(error, QStringLiteral("Codex 最终建议与输出事件不一致"));
    if (!AdviceContract::validate(finalObject))
        return fail(error, QStringLiteral("Codex 建议字段不符合契约"));
    m_finished = true;
    m_lastMessage.clear();
    if (advice)
        *advice = finalObject.toVariantMap();
    return true;
}

} // namespace CodexDecisionContract
