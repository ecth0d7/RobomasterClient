#include "QueuedSpeech.h"
#include "WavAudio.h"
#include <QFileInfo>
#include <QStandardPaths>
#include <QFile>
#include <QUuid>
#include <QJsonValue>
#include <cmath>

namespace {
bool reject(QString *error, const QString &reason) {
    if (error)
        *error = reason;
    return false;
}
QString executable(const QString &configured, const QString &fallback) {
    const QString path =
        configured.isEmpty() ? QStandardPaths::findExecutable(fallback) : configured;
    const QFileInfo info(path);
    return info.isFile() && info.isExecutable() ? info.absoluteFilePath() : QString{};
}
}
QueuedSpeech::QueuedSpeech(QObject *parent) : ServiceEndpoint(parent) {
    m_clock.start();
    m_deadline.setSingleShot(true);
    m_deadline.setTimerType(Qt::PreciseTimer);
    m_gainTimer.setInterval(0);
    connect(&m_gainTimer, &QTimer::timeout, this, &QueuedSpeech::gainStep);
    connect(&m_deadline, &QTimer::timeout, this, [this] {
        finish(false,
               m_clock.elapsed() >= m_current.expires ? "语音已过期，已停止" : "语音任务超时");
    });
}
QueuedSpeech::~QueuedSpeech() {
    // 派生类在虚函数表仍有效时停止自己的合成器。
    m_deadline.stop();
    m_gainTimer.stop(); m_gainOutput.reset(); m_gainInput.reset();
    cancelProcess();
    // 最终退出时事件循环可能已停止，需要在 QObject 销毁前
    // 回收被结束的子进程；普通取消仍异步执行。
    for (const auto &process : m_retiring)
        if (process && process->state() != QProcess::NotRunning)
            process->waitForFinished(250);
}
bool QueuedSpeech::start(const QVariantMap &configuration, QString *error) {
    QPointer<QueuedSpeech> alive(this);
    stop();
    if (!alive)
        return reject(error, "Speech service was destroyed while restarting");
    if (error)
        error->clear();
    m_play = configuration.value("playback", false).toBool();
    m_player = m_play ? executable(configuration.value("player").toString(), "aplay") : QString{};
    bool timeoutOk = false;
    m_timeout = configuration.value("timeout_ms", 15000).toInt(&timeoutOk);
    if (m_play && m_player.isEmpty())
        return reject(error, "未找到音频播放器；请安装aplay或配置paplay的绝对路径");
    if (!m_directory.isValid() || !timeoutOk || m_timeout < 50 || m_timeout > 60000)
        return reject(error, "Invalid speech timeout or temporary directory");
    if (!configureSynthesizer(configuration, error))
        return false;
    m_active = true;
    m_status = m_play ? "语音就绪" : "语音合成就绪 · 静音模式";
    emit statusChanged();
    return true;
}
void QueuedSpeech::cancelActive() {
    ++m_generation;
    m_deadline.stop();
    m_gainTimer.stop(); m_gainOutput.reset(); m_gainInput.reset();
    cancelSynthesizer();
    cancelProcess();
    m_busy = false;
}
void QueuedSpeech::cancelProcess() {
    auto process = m_process;
    m_process = nullptr;
    if (process) {
        process->disconnect(this);
        connect(process, &QProcess::finished, process, &QObject::deleteLater);
        connect(process, &QProcess::started, process, [process] { process->kill(); });
        connect(process, &QProcess::errorOccurred, process,
                [process](QProcess::ProcessError error) {
                    if (error == QProcess::FailedToStart)
                        process->deleteLater();
                });
        m_retiring.removeIf([](const QPointer<QProcess> &entry) { return entry.isNull(); });
        if (process->state() == QProcess::NotRunning)
            process->deleteLater();
        else {
            m_retiring.append(process);
            process->kill();
        }
    }
}
void QueuedSpeech::stop() {
    cancelActive();
    m_queue.clear();
    m_recent.clear();
    m_active = false;
    if (!m_wave.isEmpty())
        QFile::remove(m_wave);
    m_wave.clear();
    m_audioDetails.clear();
    m_status = "未启用";
    emit statusChanged();
}
QVariantMap QueuedSpeech::details() const {
    auto result = synthesizerDetails();
    result.insert("active", m_active);
    result.insert("busy", m_busy);
    result.insert("queued", m_queue.size());
    result.insert("playback", m_play);
    result.insert("dropped", qulonglong(m_dropped));
    result.insert("keyed_cancellation", true);
    result.insert("volume_control", true);
    result.insert("tone_control", true);
    result.insert("voice_volume", m_voiceVolume);
    result.insert("alert_volume", m_alertVolume);
    result.insert("volume_apply", "next-utterance;mute-immediate");
    result.insert("last_audio", m_audioDetails);
    return result;
}
bool QueuedSpeech::submit(const QVariantMap &message, QString *error) {
    if (error)
        error->clear();
    if (message.value("kind") == "audio-settings") {
        const auto voice = QJsonValue::fromVariant(message.value("voice_volume"));
        const auto alert = QJsonValue::fromVariant(message.value("alert_volume"));
        const auto level = [](const QJsonValue &v) { return v.isDouble() && std::isfinite(v.toDouble()) && v.toDouble() >= 0 && v.toDouble() <= 100 && std::floor(v.toDouble()) == v.toDouble(); };
        if (QJsonValue::fromVariant(message.value("schema")).toDouble(-1) != 1 || !level(voice) || !level(alert))
            return reject(error, "Invalid local audio preferences");
        m_voiceVolume = voice.toInt(); m_alertVolume = alert.toInt();
        // 0必须立即停止当前类别的输出；非零调整在下一条生效，避免重复重播半句。
        if (m_busy && (m_current.tone ? m_alertVolume : m_voiceVolume) == 0) {
            m_partialPlayback = m_playing;
            m_muted = true;
            m_cancelledForMute = true;
            finish(true);
        } else emit statusChanged();
        return true;
    }
    if (!m_active)
        return reject(error, "Speech service is not active");
    if (message.value("kind") == "cancel") {
        if (message.contains("key")) {
            const auto key = message.value("key");
            if (key.metaType().id() != QMetaType::QString || key.toString().isEmpty() ||
                key.toString().size() > 96)
                return reject(error, "Invalid speech cancellation key");
            const auto match = key.toString();
            const auto removed =
                m_queue.removeIf([&match](const Utterance &entry) { return entry.key == match; });
            const bool cancelCurrent = m_busy && m_current.key == match;
            m_dropped += removed + (cancelCurrent ? 1 : 0);
            if (cancelCurrent)
                cancelActive();
            m_recent.remove(match);
            if (!removed && !cancelCurrent)
                return true;
            QPointer<QueuedSpeech> alive(this);
            const auto generation = m_generation;
            m_status = "已取消指定播报";
            emit statusChanged();
            if (alive && generation == m_generation && !m_busy)
                QTimer::singleShot(0, this, &QueuedSpeech::advance);
            return true;
        }
        cancelActive();
        m_queue.clear();
        m_status = "语音已停止";
        emit statusChanged();
        return true;
    }
    const bool tone = message.value("kind") == "tone";
    const auto text = tone ? QStringLiteral("本机提示音试听") : message.value("text").toString().trimmed();
    const auto id = message.value("request_id").toString(),
               key = message.value("key", id).toString();
    const auto priority = message.value("priority", "info").toString();
    const auto ttlValue = QJsonValue::fromVariant(message.value("expires_in_ms", 10000));
    const double ttlNumber = ttlValue.toDouble(-1);
    const int ttl = ttlNumber >= 500 && ttlNumber <= 60000 ? int(ttlNumber) : -1;
    const auto schema = QJsonValue::fromVariant(message.value("schema"));
    if (!schema.isDouble() || schema.toDouble() != 1 || (!tone && message.value("kind") != "speak") ||
        id.isEmpty() || id.size() > 96 || key.size() > 96 || text.isEmpty() || text.size() > 280 ||
        (!tone && message.value("text").metaType().id() != QMetaType::QString) ||
        message.value("request_id").metaType().id() != QMetaType::QString ||
        !QStringList{"info", "caution", "urgent"}.contains(priority) || !ttlValue.isDouble() ||
        !std::isfinite(ttlNumber) || std::floor(ttlNumber) != ttlNumber || ttl < 500)
        return reject(error, "Invalid speech request");
    const auto now = m_clock.elapsed();
    for (auto it = m_recent.begin(); it != m_recent.end();) {
        if (now - it.value() > 10000)
            it = m_recent.erase(it);
        else
            ++it;
    }
    if (m_recent.contains(key)) {
        ++m_dropped;
        emit statusChanged();
        return true;
    }
    Utterance entry{id, text, key,
                    priority == "urgent"    ? 2
                    : priority == "caution" ? 1
                                            : 0,
                    now + ttl, tone};
    if (m_queue.size() >= 8) {
        ++m_dropped;
        if (entry.priority > m_queue.last().priority)
            m_queue.removeLast();
        else {
            emit statusChanged();
            return reject(error, "语音队列已满");
        }
    }
    if (m_recent.size() >= 64)
        m_recent.erase(m_recent.begin());
    m_recent[key] = now;
    if (m_busy && entry.priority == 2 && m_current.priority < 2) {
        ++m_dropped;
        cancelActive();
    }
    auto position = m_queue.begin();
    while (position != m_queue.end() && position->priority >= entry.priority)
        ++position;
    m_queue.insert(position, entry);
    QPointer<QueuedSpeech> alive(this);
    advance();
    if (alive)
        emit statusChanged();
    return true;
}
void QueuedSpeech::advance() {
    if (!m_active || m_busy)
        return;
    m_retiring.removeIf([](const QPointer<QProcess> &entry) { return entry.isNull(); });
    if (m_retiring.size() >= 8) {
        QTimer::singleShot(10, this, &QueuedSpeech::advance);
        return;
    }
    while (!m_queue.isEmpty()) {
        m_current = m_queue.takeFirst();
        if (m_clock.elapsed() < m_current.expires) {
            if (!m_wave.isEmpty())
                QFile::remove(m_wave);
            if (!m_playWave.isEmpty() && m_playWave != m_wave) QFile::remove(m_playWave);
            m_playWave.clear();
            m_muted = m_partialPlayback = m_playing = m_didPlay = false;
            m_cancelledForMute = false;
            m_wave =
                m_directory.filePath(QUuid::createUuid().toString(QUuid::WithoutBraces) + ".wav");
            m_audioDetails.clear();
            if (m_play && (m_current.tone ? m_alertVolume : m_voiceVolume) == 0) {
                m_muted = true;
                finish(true); // 已静音的设备输出不再启动远端合成／播放器。
                return;
            }
            launch(false);
            return;
        }
        ++m_dropped;
    }
    emit statusChanged();
}
void QueuedSpeech::launch(bool playback) {
    const auto generation = ++m_generation;
    m_busy = true;
    m_deadline.start(
        qMax(1, qMin(playback ? 60000 : m_timeout, int(m_current.expires - m_clock.elapsed()))));
    m_status = playback ? "正在播报" : "正在合成语音";
    QPointer<QueuedSpeech> alive(this);
    emit statusChanged();
    if (!alive || !current(generation))
        return;
    if (playback) {
        launchProcess(true, m_player, {"-q", m_playWave.isEmpty() ? m_wave : m_playWave}, {}, generation);
    } else if (m_current.tone) {
        const auto audio = WavAudio::alertTone(m_current.priority == 2);
        QFile output(m_wave);
        if (!output.open(QIODevice::WriteOnly) || output.write(audio) != audio.size()) {
            finish(false, "本机提示音生成失败"); return;
        }
        output.close();
        synthesisCompleted(generation);
    } else
        launchSynthesizer(m_current.text, m_wave, generation);
}
void QueuedSpeech::launchSynthesisProcess(const QString &program, const QStringList &arguments,
                                          const QByteArray &input, quint64 generation) {
    launchProcess(false, program, arguments, input, generation);
}
void QueuedSpeech::launchProcess(bool playback, const QString &program,
                                 const QStringList &arguments, const QByteArray &input,
                                 quint64 generation) {
    auto *process = new QProcess(this);
    m_process = process;
    // 及时丢弃诊断输出，避免外部工具使日志缓冲无界增长。
    // 失败仍通过有界状态文本报告。
    process->setStandardOutputFile(QProcess::nullDevice());
    process->setStandardErrorFile(QProcess::nullDevice());
    if (playback) connect(process, &QProcess::started, this, [this, generation] {
        if (current(generation)) m_playing = true;
    });
    connect(process, &QProcess::errorOccurred, this,
            [this, generation](QProcess::ProcessError error) {
                if (current(generation) && error == QProcess::FailedToStart)
                    finish(false, "语音程序启动失败");
            });
    connect(process, &QProcess::finished, this,
            [this, process, generation, playback](int code, QProcess::ExitStatus exit) {
                if (!current(generation))
                    return;
                if (code != 0 || exit != QProcess::NormalExit) {
                    finish(false, playback ? "语音播放失败" : "语音合成失败");
                    return;
                }
                m_process = nullptr;
                process->deleteLater();
                if (!playback)
                    synthesisCompleted(generation);
                else {
                    m_didPlay = true;
                    finish(true);
                }
            });
    if (!playback) {
        connect(process, &QProcess::started, this, [this, process, generation, input] {
            if (!current(generation))
                return;
            process->write(input);
            process->closeWriteChannel();
        });
    }
    process->start(program, arguments);
}
void QueuedSpeech::synthesisCompleted(quint64 generation, const QString &error) {
    if (!current(generation) || m_gainInput || m_playing)
        return;
    if (!error.isEmpty()) {
        finish(false, error);
        return;
    }
    QFile wave(m_wave);
    if (!wave.open(QIODevice::ReadOnly) || !WavAudio::inspect(wave, &m_audioDetails)) {
        finish(false, "语音音频无效");
        return;
    }
    if (m_clock.elapsed() >= m_current.expires) {
        ++m_dropped;
        finish(false, "语音已过期，未播放");
        return;
    }
    if (m_play) {
        preparePlayback(generation);
        return;
    }
    finish(true);
}
void QueuedSpeech::preparePlayback(quint64 generation) {
    m_currentVolume = m_current.tone ? m_alertVolume : m_voiceVolume;
    m_audioDetails["gain_requested_percent"] = m_currentVolume;
    if (!m_currentVolume) { m_muted = true; finish(true); return; }
    if (m_currentVolume == 100) { m_audioDetails["gain_percent"] = 100; m_playWave = m_wave; m_deadline.stop(); launch(true); return; }
    m_playWave = m_wave + ".play.wav";
    m_gainInput = std::make_unique<QFile>(m_wave);
    m_gainOutput = std::make_unique<QSaveFile>(m_playWave);
    if (!m_gainInput->open(QIODevice::ReadOnly) || !m_gainOutput->open(QIODevice::WriteOnly)) {
        finish(false, "本地音量处理无法打开音频"); return;
    }
    m_pcmOffset = m_audioDetails.value("data_offset").toLongLong();
    m_pcmBytes = m_audioDetails.value("data_bytes").toLongLong();
    m_gainPosition = 0; m_gainGeneration = generation;
    m_gainTimer.start();
}
void QueuedSpeech::gainStep() {
    if (!current(m_gainGeneration) || !m_gainInput || !m_gainOutput) return;
    // 每轮最多64KiB；保留RIFF其他块，避免大PCM循环霸占GUI线程。
    const qint64 pcmEnd = m_pcmOffset + m_pcmBytes;
    const bool pcm = m_gainPosition >= m_pcmOffset && m_gainPosition < pcmEnd;
    const qint64 boundary = m_gainPosition < m_pcmOffset ? m_pcmOffset : pcm ? pcmEnd : m_gainInput->size();
    const qint64 amount = qMin(qint64(65536), boundary - m_gainPosition);
    auto bytes = m_gainInput->read(amount);
    if (amount <= 0 || bytes.size() != amount ||
        (pcm && !WavAudio::attenuate(&bytes, m_audioDetails.value("bit_depth").toInt(), m_currentVolume)) ||
        m_gainOutput->write(bytes) != bytes.size()) {
        finish(false, "本地音量处理失败，未播放"); return;
    }
    m_gainPosition += amount;
    if (m_gainPosition != m_gainInput->size()) return;
    if (!m_gainOutput->commit()) { finish(false, "本地音量音频未保存，未播放"); return; }
    m_audioDetails["gain_percent"] = m_currentVolume;
    m_gainTimer.stop(); m_gainInput.reset(); m_gainOutput.reset();
    m_deadline.stop(); launch(true);
}
void QueuedSpeech::finish(bool success, const QString &error) {
    const auto id = m_current.id;
    if (!success && m_playing) m_partialPlayback = true;
    const bool audioReady = !m_audioDetails.isEmpty();
    const bool gainReady = m_audioDetails.contains("gain_percent") && !m_playWave.isEmpty();
    const QString resultWave = gainReady ? m_playWave : m_wave;
    cancelActive();
    m_status = success ? m_muted ? "已静音 · 未继续播放" : m_play ? "播报完成" : "已合成语音 · 静音模式" : error;
    const auto generation = m_generation;
    const QVariantMap result{{"schema", 1},
                             {"kind", m_cancelledForMute ? "speech-cancelled" : success ? "speech-complete" : "speech-error"},
                             {"text", m_current.text},
                             {"key", m_current.key},
                             {"request_id", id},
                             {"played", success && m_didPlay},
                             {"muted", m_muted}, {"partial_playback", m_partialPlayback},
                             {"channel", m_current.tone ? "alert" : "voice"},
                             {"wave", success && audioReady ? resultWave : QString{}},
                             {"bytes", success && audioReady ? QFileInfo(resultWave).size() : 0},
                             {"audio", success ? m_audioDetails : QVariantMap{}},
                             {"error", error}};
    QPointer<QueuedSpeech> alive(this);
    emit statusChanged();
    if (!alive || generation != m_generation)
        return;
    if (!success)
        emit errorOccurred(error);
    if (!alive || generation != m_generation)
        return;
    emit messageReceived(result);
    if (!alive || generation != m_generation)
        return;
    QTimer::singleShot(0, this, &QueuedSpeech::advance);
}
