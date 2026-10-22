#include "ExtensionPlugin.h"
#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QPointer>
#include <QTimer>

class BattlefieldProcess final : public ServiceEndpoint {
    Q_OBJECT
public:
    BattlefieldProcess() {
        inputPump.setInterval(5);
        connect(&inputPump, &QTimer::timeout, this, [this] {
            if (process.state()!=QProcess::Running || !process.bytesToWrite()) {inputPump.stop();return;}
            // 原生交互期间曾观测到可写管道的通知未推进。0ms仅轮询，不能在GUI线程等待子进程。
            process.waitForBytesWritten(0);
        });
        connect(&process, &QProcess::readyReadStandardOutput, this, [this] {
            bytes += process.readAllStandardOutput();
            if (bytes.size() > 2*1024*1024) { process.kill(); emit errorOccurred("态势进程输出超过限制"); return; }
            while (true) {
                const auto newline = bytes.indexOf('\n');
                if (newline < 0) break;
                const auto line = bytes.left(newline); bytes.remove(0, newline+1);
                const auto json = QJsonDocument::fromJson(line);
                if (json.isObject()) {
                    QPointer<BattlefieldProcess> alive(this);
                    emit messageReceived(json.object().toVariantMap());
                    if (!alive) return;
                }
            }
        });
        connect(&process, &QProcess::readyReadStandardError, this, [this] { process.readAllStandardError(); });
        connect(&process, &QProcess::started, this, [this] {
            process.write(configuration); inputPump.start(); configuration.clear(); m_status = "态势进程已启动"; emit statusChanged();
        });
        connect(&process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
            if(error==QProcess::Timedout)return; // 非阻塞轮询暂时无进展不代表进程失联。
            inputPump.stop();
            m_status = "态势进程不可用；基础客户端继续运行"; emit errorOccurred(m_status); emit statusChanged();
        });
        connect(&process, qOverload<int,QProcess::ExitStatus>(&QProcess::finished), this, [this](int, QProcess::ExitStatus) {
            m_status = "态势进程已结束"; emit errorOccurred(m_status); emit statusChanged();
        });
    }
    ~BattlefieldProcess() override { blockSignals(true); stop(); }
    bool start(const QVariantMap &input, QString *error) override {
        stop();
        auto config = input;
        const auto python = config.take("python").toString();
        const QFileInfo interpreter(python);
        if (!interpreter.isAbsolute() || !interpreter.isFile() || !interpreter.isExecutable()) { if(error)*error="请配置可用的Python解释器绝对路径"; return false; }
        QString runtime;
        const auto app = QCoreApplication::applicationDirPath();
        for (const auto &candidate : {app+"/extensions/battlefield/runtime/runtime.py",
                app+"/../share/robomaster/extensions/battlefield/runtime/runtime.py", QString(BATTLEFIELD_SOURCE_RUNTIME)})
            if (QFileInfo::exists(candidate)) { runtime = candidate; break; }
        if (runtime.isEmpty()) { if(error)*error="可选态势运行文件缺失"; return false; }
        configuration = QJsonDocument::fromVariant(config).toJson(QJsonDocument::Compact)+"\n";
        if (configuration.size() > 49152) { if(error)*error="态势配置超过48 KiB"; return false; }
        process.start(python, {"-B", "-u", runtime});
        m_status = "正在启动态势进程";
        return true;
    }
    void stop() override {
        inputPump.stop();
        if (process.state() != QProcess::NotRunning) {
            process.write("{\"kind\":\"stop\"}\n");
            process.closeWriteChannel();
            if (!process.waitForFinished(1000)) { process.terminate(); if (!process.waitForFinished(250)) { process.kill(); process.waitForFinished(250); } }
        }
        configuration.clear(); bytes.clear(); m_status="态势进程已停止";
    }
    bool submit(const QVariantMap &message, QString *error) override {
        if (process.state() != QProcess::Running) return false;
        const auto kind=message.value("kind").toString();
        if ((kind=="frame" || kind=="hero_frame") && process.bytesToWrite()>128*1024) {++dropped;return false;}
        if (process.bytesToWrite() > 768*1024) { ++dropped; return false; }
        const auto json = QJsonDocument::fromVariant(message).toJson(QJsonDocument::Compact)+"\n";
        if (json.size() > 1024*1024) { if(error)*error="态势输入超过限制"; return false; }
        const bool accepted=process.write(json)==json.size();
        if(accepted) {
            QPointer<BattlefieldProcess> alive(this);
            process.waitForBytesWritten(0);
            if(!alive)return false;
            if(process.bytesToWrite() && !inputPump.isActive())inputPump.start();
        }
        return accepted;
    }
    QString status() const override { return m_status; }
    QVariantMap details() const override { return {{"active", process.state()==QProcess::Running}, {"pid", process.processId()}, {"dropped", dropped}, {"pending_bytes", process.bytesToWrite()}}; }
private:
    QProcess process;
    QTimer inputPump;
    QByteArray configuration, bytes;
    QString m_status;
    quint64 dropped = 0;
};
class BattlefieldPlugin final : public QObject, public ExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID ExtensionPlugin_iid FILE "battlefield.json")
    Q_INTERFACES(ExtensionPlugin)
public:
    QString id() const override { return "situation.process.v1"; }
    QString role() const override { return "battlefield"; }
    ServiceEndpoint *createService() override { return new BattlefieldProcess; }
};
#include "BattlefieldPlugin.moc"
