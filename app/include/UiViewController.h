#pragma once

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QVariantList>

class QQmlApplicationEngine;

// View navigation and read-only availability checks for optional UI asset bundles.
// A visual reference gets its own engine and no operational context objects.
// In particular, opening the retained HUD cannot create transport or input hosts.
class UiViewController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList views READ views CONSTANT)
    Q_PROPERTY(QString qtRuntimeVersion READ qtRuntimeVersion CONSTANT)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
public:
    explicit UiViewController(const QString &directory, QObject *parent = nullptr);
    ~UiViewController() override;
    QVariantList views() const { return m_views; }
    QString qtRuntimeVersion() const;
    QString status() const { return m_status; }
    Q_INVOKABLE bool assetsAvailable(const QVariantList &files) const;
    Q_INVOKABLE bool openReference(const QString &id = QStringLiteral("player-2026"));
signals:
    void statusChanged();
private:
    void setStatus(const QString &value);
    QString m_directory;
    QVariantList m_views;
    QString m_status;
    QHash<QString, QPointer<QQmlApplicationEngine>> m_engines;
};
