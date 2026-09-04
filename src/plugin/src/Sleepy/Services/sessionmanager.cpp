#include "sessionmanager.hpp"

#include <QtDBus/qdbusconnection.h>
#include <QtDBus/qdbuserror.h>
#include <QtDBus/qdbusmessage.h>
#include <QtDBus/qdbusreply.h>
#include <qloggingcategory.h>

Q_LOGGING_CATEGORY(lcSessionManager, "sleepy.services.sessionmanager", QtInfoMsg)

namespace sleepy::services {

namespace {

constexpr const char* LOGIN_SERVICE = "org.freedesktop.login1";
constexpr const char* LOGIN_PATH = "/org/freedesktop/login1";
constexpr const char* LOGIN_IFACE = "org.freedesktop.login1.Manager";
constexpr const char* SESSION_IFACE = "org.freedesktop.login1.Session";

} // namespace

SessionManager::SessionManager(QObject* parent)
    : QObject(parent) {
    auto bus = getSystemBus();
    if (!bus)
        return;

    bool ok = bus->connect(
        LOGIN_SERVICE, LOGIN_PATH, LOGIN_IFACE, "PrepareForSleep", this, SLOT(handlePrepareForSleep(bool)));
    if (!ok)
        qCWarning(lcSessionManager) << "Failed to connect to PrepareForSleep signal:" << bus->lastError().message();

    auto sessionMsg = QDBusMessage::createMethodCall(LOGIN_SERVICE, LOGIN_PATH, LOGIN_IFACE, "GetSession");
    sessionMsg.setArguments({ "auto" });
    const QDBusReply<QDBusObjectPath> sessionReply = bus->call(sessionMsg);
    if (!sessionReply.isValid()) {
        qCWarning(lcSessionManager) << "Failed to get session path:" << sessionReply.error().message();
        return;
    }
    m_sessionPath = sessionReply.value().path();

    ok = bus->connect(LOGIN_SERVICE, m_sessionPath, SESSION_IFACE, "Lock", this, SLOT(handleLockRequested()));
    if (!ok)
        qCWarning(lcSessionManager) << "Failed to connect to Lock signal:" << bus->lastError().message();

    ok = bus->connect(LOGIN_SERVICE, m_sessionPath, SESSION_IFACE, "Unlock", this, SLOT(handleUnlockRequested()));
    if (!ok)
        qCWarning(lcSessionManager) << "Failed to connect to Unlock signal:" << bus->lastError().message();
}

std::optional<QDBusConnection> SessionManager::getSystemBus() const {
    auto bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        qCWarning(lcSessionManager) << "Failed to connect to system bus:" << bus.lastError().message();
        return std::nullopt;
    }
    return bus;
}

void SessionManager::handlePrepareForSleep(bool sleep) {
    if (sleep) {
        emit aboutToSleep();
    } else {
        emit resumed();
    }
}

void SessionManager::handleLockRequested() {
    emit lockRequested();
}

void SessionManager::handleUnlockRequested() {
    emit unlockRequested();
}

} // namespace sleepy::services
