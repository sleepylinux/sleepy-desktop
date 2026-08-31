#include "secureprompt.hpp"

#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QLocalServer>
#include <QLocalSocket>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSocketNotifier>
#include <QVector>

#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cerrno>

namespace {

constexpr qsizetype kMaximumPendingClients = 16;
constexpr qint64 kMaximumRequestBytes = 32;

bool peerIsCurrentUser(QLocalSocket *socket)
{
    ucred credentials{};
    socklen_t length = sizeof(credentials);
    const qintptr descriptor = socket->socketDescriptor();
    if (descriptor < 0) {
        return false;
    }
    return ::getsockopt(static_cast<int>(descriptor), SOL_SOCKET, SO_PEERCRED,
                        &credentials, &length) == 0
        && length == sizeof(credentials)
        && credentials.uid == ::getuid();
}

bool removeOwnedSocket(const QString &path)
{
    const QByteArray encoded = QFile::encodeName(path);
    struct stat state {};
    if (::lstat(encoded.constData(), &state) != 0) {
        return errno == ENOENT;
    }
    if (!S_ISSOCK(state.st_mode) || state.st_uid != ::getuid()) {
        return false;
    }
    return ::unlink(encoded.constData()) == 0;
}

class LockerEndpoint final : public QObject {
    Q_OBJECT

public:
    explicit LockerEndpoint(QObject *qmlRoot, QObject *parent = nullptr)
        : QObject(parent), qmlRoot_(qmlRoot)
    {
        const QString runtime = qEnvironmentVariable("XDG_RUNTIME_DIR");
        if (runtime.isEmpty()) {
            throw std::runtime_error("XDG_RUNTIME_DIR is required");
        }
        const QString directory = runtime + QStringLiteral("/sleepy");
        if (!QDir().mkpath(directory)) {
            throw std::runtime_error("failed to create locker runtime directory");
        }
        const QByteArray encodedDirectory = QFile::encodeName(directory);
        if (::chmod(encodedDirectory.constData(), 0700) != 0) {
            throw std::runtime_error("failed to protect locker runtime directory");
        }
        path_ = qEnvironmentVariable("SLEEPY_LOCKER_SOCKET",
                                     directory + QStringLiteral("/locker.sock"));
        if (!removeOwnedSocket(path_)) {
            throw std::runtime_error("refusing to replace unsafe locker endpoint");
        }
        connect(&server_, &QLocalServer::newConnection,
                this, &LockerEndpoint::acceptConnections);
        if (!server_.listen(path_)) {
            throw std::runtime_error("failed to bind locker endpoint");
        }
        const QByteArray encodedPath = QFile::encodeName(path_);
        if (::chmod(encodedPath.constData(), 0600) != 0) {
            throw std::runtime_error("failed to protect locker endpoint");
        }
        connect(qmlRoot_, SIGNAL(secureChanged()), this, SLOT(secureChanged()));
    }

    ~LockerEndpoint() override
    {
        for (QLocalSocket *socket : std::as_const(pending_)) {
            socket->abort();
        }
        server_.close();
        static_cast<void>(removeOwnedSocket(path_));
    }

private slots:
    void acceptConnections()
    {
        while (server_.hasPendingConnections()) {
            QLocalSocket *socket = server_.nextPendingConnection();
            if (socket == nullptr) {
                continue;
            }
            socket->setParent(this);
            if (!peerIsCurrentUser(socket) || pending_.size() >= kMaximumPendingClients) {
                socket->disconnectFromServer();
                socket->deleteLater();
                continue;
            }
            connect(socket, &QLocalSocket::readyRead, this, [this, socket] {
                readRequest(socket);
            });
            connect(socket, &QLocalSocket::disconnected, this, [this, socket] {
                pending_.removeAll(socket);
                socket->deleteLater();
            });
            readRequest(socket);
        }
    }

    void secureChanged()
    {
        if (!qmlRoot_->property("secure").toBool()) {
            return;
        }
        const auto clients = pending_;
        pending_.clear();
        for (QLocalSocket *socket : clients) {
            socket->write("locked\n");
            socket->flush();
            socket->disconnectFromServer();
        }
    }

private:
    void readRequest(QLocalSocket *socket)
    {
        if (socket->bytesAvailable() > kMaximumRequestBytes) {
            socket->disconnectFromServer();
            return;
        }
        const QByteArray request = socket->readLine(kMaximumRequestBytes + 1);
        if (request.isEmpty() && !socket->canReadLine()) {
            return;
        }
        if (request != QByteArrayLiteral("lock\n") || socket->bytesAvailable() != 0) {
            socket->write("error\n");
            socket->disconnectFromServer();
            return;
        }
        if (!pending_.contains(socket)) {
            pending_.append(socket);
        }
        if (qmlRoot_->property("secure").toBool()) {
            secureChanged();
            return;
        }
        if (!QMetaObject::invokeMethod(qmlRoot_, "requestLock", Qt::QueuedConnection)) {
            pending_.removeAll(socket);
            socket->write("error\n");
            socket->disconnectFromServer();
        }
    }

    QObject *qmlRoot_;
    QLocalServer server_;
    QVector<QLocalSocket *> pending_;
    QString path_;
};

} // namespace

int main(int argc, char **argv)
{
    QGuiApplication application(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("sleepy-locker"));
    QCoreApplication::setOrganizationName(QStringLiteral("Sleepy Linux"));
    qmlRegisterType<sleepy::locker::SecurePrompt>("Sleepy.Locker", 1, 0, "SecurePrompt");
    qmlRegisterUncreatableMetaObject(sleepy::locker::staticMetaObject,
                                     "Sleepy.Locker", 1, 0, "AuthState",
                                     QStringLiteral("AuthState is an enum"));

    QQmlApplicationEngine engine;
    engine.loadFromModule(QStringLiteral("Sleepy.Locker"), QStringLiteral("LockRoot"));
    if (engine.rootObjects().size() != 1) {
        return 1;
    }

    try {
        LockerEndpoint endpoint(engine.rootObjects().constFirst());
        return application.exec();
    } catch (const std::exception &error) {
        qCritical("sleepy-locker startup failed: %s", error.what());
        return 1;
    }
}

#include "main.moc"
