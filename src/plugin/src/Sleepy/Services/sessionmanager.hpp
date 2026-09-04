#pragma once

#include <qdbusconnection.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>

#include <optional>

namespace sleepy::services {

class SessionManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit SessionManager(QObject* parent = nullptr);

signals:
    void aboutToSleep();
    void resumed();
    void lockRequested();
    void unlockRequested();

private slots:
    void handlePrepareForSleep(bool sleep);
    void handleLockRequested();
    void handleUnlockRequested();

private:
    [[nodiscard]] std::optional<QDBusConnection> getSystemBus() const;
    QString m_sessionPath;
};

} // namespace sleepy::services
