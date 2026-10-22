#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <memory>

class SeasonConfiguration;
class TerminalDataBus;
class TerminalPluginSourceLease;
namespace PacketObservation { struct Stamp; }

// Admission of observations produced by reviewed native package sessions. QML
// receives diagnostics only; source registration and submissions stay native.
class TerminalPluginSourceHost final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QVariantList sources READ sources NOTIFY changed)
    Q_PROPERTY(QVariantMap diagnostics READ diagnostics NOTIFY changed)
public:
    TerminalPluginSourceHost(SeasonConfiguration *, TerminalDataBus *, QObject *parent = nullptr);
    ~TerminalPluginSourceHost() override;
    QString status() const;
    QVariantList sources() const;
    QVariantMap diagnostics() const;

    // The package runtime supplies its immutable reviewed package and scope.
    // No Q_INVOKABLE registration path or producer-controlled trust flags.
    QObject *createSource(QObject *owner, const QVariantMap &package,
                          const QVariantMap &scope, const QVariantMap &descriptor,
                          QString *error = nullptr);
signals:
    void changed();
private:
    friend class TerminalPluginSourceLease;
    bool submit(TerminalPluginSourceLease *, const QVariantMap &sample,
                const PacketObservation::Stamp &, QString *error);
    void retire(TerminalPluginSourceLease *) noexcept;
    void retireAll() noexcept;
    bool reject(const QString &, QString *error);
    struct Private;
    std::unique_ptr<Private> d;
};
