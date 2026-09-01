#include "main.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLocalSocket>
#include <QTimer>

#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cerrno>
#include <stdexcept>
#include <utility>

namespace sleepy::locker {
namespace {

constexpr qsizetype kMaximumClients = 16;
constexpr qint64 kMaximumRequestBytes = 32;

bool peerIsCurrentUser(QLocalSocket *socket)
{
    ucred credentials{};
    socklen_t length = sizeof(credentials);
    const qintptr descriptor = socket->socketDescriptor();
    return descriptor >= 0
        && ::getsockopt(static_cast<int>(descriptor), SOL_SOCKET, SO_PEERCRED,
                        &credentials, &length) == 0
        && length == sizeof(credentials)
        && credentials.uid == ::getuid();
}

bool pathIsOwnedDirectory(const QString &path)
{
    if (path.isEmpty()) {
        return false;
    }
    const QByteArray encoded = QFile::encodeName(path);
    struct stat state {};
    return ::lstat(encoded.constData(), &state) == 0
        && S_ISDIR(state.st_mode)
        && !S_ISLNK(state.st_mode)
        && state.st_uid == ::getuid();
}

bool removeOwnedSocket(const QString &path)
{
    const QByteArray encoded = QFile::encodeName(path);
    struct stat state {};
    if (::lstat(encoded.constData(), &state) != 0) {
        return errno == ENOENT;
    }
    return S_ISSOCK(state.st_mode) && state.st_uid == ::getuid()
        && ::unlink(encoded.constData()) == 0;
}

} // namespace

LockerEndpoint::LockerEndpoint(QObject *parent)
    : QObject(parent)
{
    const QString runtime = qEnvironmentVariable("XDG_RUNTIME_DIR");
    if (!pathIsOwnedDirectory(runtime)) {
        throw std::runtime_error("XDG_RUNTIME_DIR is not an owned directory");
    }
    const QString directory = runtime + QStringLiteral("/sleepy");
    if (!QFileInfo::exists(directory) && !QDir().mkdir(directory)) {
        throw std::runtime_error("failed to create locker runtime directory");
    }
    if (!pathIsOwnedDirectory(directory)) {
        throw std::runtime_error("locker runtime path is not an owned directory");
    }
    const QByteArray encodedDirectory = QFile::encodeName(directory);
    if (::chmod(encodedDirectory.constData(), 0700) != 0) {
        throw std::runtime_error("failed to protect locker runtime directory");
    }

    path_ = qEnvironmentVariable("SLEEPY_LOCKER_SOCKET",
                                 directory + QStringLiteral("/locker.sock"));
    if (QFileInfo(path_).absolutePath() != directory || !removeOwnedSocket(path_)) {
        throw std::runtime_error("refusing unsafe locker endpoint path");
    }
    connect(&server_, &QLocalServer::newConnection,
            this, &LockerEndpoint::acceptConnections);
    if (!server_.listen(path_)) {
        throw std::runtime_error(
            QStringLiteral("failed to bind locker endpoint: %1")
                .arg(server_.errorString()).toStdString());
    }
    const QByteArray encodedPath = QFile::encodeName(path_);
    if (::chmod(encodedPath.constData(), 0600) != 0) {
        throw std::runtime_error("failed to protect locker endpoint");
    }
}

LockerEndpoint::~LockerEndpoint()
{
    for (QLocalSocket *socket : std::as_const(clients_)) {
        socket->abort();
    }
    server_.close();
    static_cast<void>(removeOwnedSocket(path_));
}

bool LockerEndpoint::secure() const noexcept
{
    return secure_;
}

bool LockerEndpoint::unlockAllowed() const noexcept
{
    return suspendHolds_.isEmpty();
}

void LockerEndpoint::setSecure(bool secure)
{
    if (secure_ == secure) {
        return;
    }
    secure_ = secure;
    emit secureChanged();
    if (secure_) {
        acknowledgePending();
    }
}

void LockerEndpoint::acceptConnections()
{
    while (server_.hasPendingConnections()) {
        QLocalSocket *socket = server_.nextPendingConnection();
        if (socket == nullptr) {
            continue;
        }
        socket->setParent(this);
        if (!peerIsCurrentUser(socket) || clients_.size() >= kMaximumClients) {
            socket->disconnectFromServer();
            socket->deleteLater();
            continue;
        }
        clients_.append(socket);
        socket->setProperty("requestAccepted", false);
        QTimer::singleShot(2000, socket, [socket] {
            if (!socket->property("requestAccepted").toBool()) {
                socket->disconnectFromServer();
            }
        });
        connect(socket, &QLocalSocket::readyRead, this,
                [this, socket] { readRequest(socket); });
        connect(socket, &QLocalSocket::disconnected, this, [this, socket] {
            const bool wasAllowed = unlockAllowed();
            clients_.removeAll(socket);
            pending_.removeAll(socket);
            suspendHolds_.removeAll(socket);
            if (wasAllowed != unlockAllowed()) {
                emit unlockAllowedChanged();
            }
            socket->deleteLater();
        });
        readRequest(socket);
    }
}

void LockerEndpoint::readRequest(QLocalSocket *socket)
{
    if (socket->bytesAvailable() > kMaximumRequestBytes) {
        socket->disconnectFromServer();
        return;
    }
    if (!socket->canReadLine()) {
        return;
    }
    const QByteArray request = socket->readLine(kMaximumRequestBytes + 1);
    if (socket->bytesAvailable() != 0) {
        socket->write("error\n");
        socket->disconnectFromServer();
        return;
    }
    disconnect(socket, &QLocalSocket::readyRead, nullptr, nullptr);
    socket->setProperty("requestAccepted", true);

    if (request == QByteArrayLiteral("status\n")) {
        socket->write(secure_ ? "locked\n" : "unlocked\n");
        socket->flush();
        socket->disconnectFromServer();
        return;
    }
    if (request != QByteArrayLiteral("lock\n")
        && request != QByteArrayLiteral("suspend\n")) {
        socket->write("error\n");
        socket->disconnectFromServer();
        return;
    }

    socket->setProperty("suspendHold", request == QByteArrayLiteral("suspend\n"));
    pending_.append(socket);
    QTimer::singleShot(5000, socket, [this, socket] {
        if (pending_.contains(socket)) {
            socket->disconnectFromServer();
        }
    });
    if (secure_) {
        acknowledgePending();
        return;
    }
    emit lockRequested();
}

void LockerEndpoint::acknowledgePending()
{
    const auto clients = pending_;
    for (QLocalSocket *socket : clients) {
        pending_.removeAll(socket);
        socket->write("locked\n");
        socket->flush();
        if (socket->property("suspendHold").toBool()) {
            const bool wasAllowed = unlockAllowed();
            suspendHolds_.append(socket);
            if (wasAllowed != unlockAllowed()) {
                emit unlockAllowedChanged();
            }
        } else {
            socket->disconnectFromServer();
        }
    }
}

} // namespace sleepy::locker
