#pragma once

#include <QObject>
#include <QVariantMap>
#include <memory>

class SeasonConfiguration;
class ServiceHub;
class TerminalAdviceHost;
class TerminalDataBus;
class TerminalTeamHost;

// Coordinates admitted advice and optional team announcements. It does not
// expose arbitrary speech, observation injection, transport or robot actions.
class TerminalVoiceCoordinator final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap current READ current NOTIFY changed)
    Q_PROPERTY(bool editable READ editable NOTIFY changed)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QVariantMap details READ details NOTIFY changed)
public:
    TerminalVoiceCoordinator(SeasonConfiguration *, TerminalDataBus *, TerminalTeamHost *,
                             TerminalAdviceHost *, ServiceHub *, QString settingsFile,
                             QObject *parent = nullptr);
    ~TerminalVoiceCoordinator() override;
    static QVariantMap defaults();
    static bool validatePublic(const QVariantMap &, QString *error = nullptr);
    QVariantMap current() const;
    bool editable() const;
    QString lockReason() const;
    QString status() const;
    QVariantMap details() const;
    Q_INVOKABLE bool save(const QVariantMap &values);
signals:
    void changed();
private:
    void load();
    void scheduleTick();
    void tick();
    void handleOwn(const QString &requestId);
    void retire();
    void withdraw();
    bool reject(const QString &reason);
    struct Private;
    std::unique_ptr<Private> d;
};
