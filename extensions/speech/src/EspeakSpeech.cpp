#include "EspeakSpeech.h"
#include <QFileInfo>
#include <QStandardPaths>
#include <QRegularExpression>

bool EspeakSpeech::configureSynthesizer(const QVariantMap &configuration, QString *error) {
    const auto configured = configuration.value("executable").toString();
    const QFileInfo executable(configured.isEmpty() ? QStandardPaths::findExecutable("espeak-ng")
                                                    : configured);
    m_executable = executable.isFile() && executable.isExecutable() ? executable.absoluteFilePath()
                                                                    : QString{};
    m_voice = configuration.value("voice", "cmn").toString();
    bool speedOk = false;
    m_speed = configuration.value("speed", 175).toInt(&speedOk);
    if (m_executable.isEmpty()) {
        if (error)
            *error = "未找到语音合成程序；请安装espeak-ng或配置已有程序的绝对路径";
        return false;
    }
    if (!QRegularExpression("^[A-Za-z0-9_+.-]{1,48}$").match(m_voice).hasMatch() || !speedOk ||
        m_speed < 80 || m_speed > 350) {
        if (error)
            *error = "Invalid speech voice or speed";
        return false;
    }
    return true;
}
QVariantMap EspeakSpeech::synthesizerDetails() const {
    return {{"engine", "espeak"}, {"voice", m_voice}};
}
void EspeakSpeech::launchSynthesizer(const QString &text, const QString &wave, quint64 generation) {
    launchSynthesisProcess(
        m_executable,
        {"--stdin", "-b", "1", "-v", m_voice, "-s", QString::number(m_speed), "-w", wave},
        text.toUtf8(), generation);
}
