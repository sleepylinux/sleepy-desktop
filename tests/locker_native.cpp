#include "secureprompt.hpp"
#include "main.hpp"

#include <QGuiApplication>
#include <QKeyEvent>
#include <QLocalSocket>
#include <QTemporaryDir>
#include <QtTest>

#include <csignal>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

using sleepy::locker::AuthState;
using sleepy::locker::Authenticator;
using sleepy::locker::SecurePrompt;
using sleepy::locker::LockerEndpoint;

class FakeAuthenticator final : public Authenticator {
public:
    QByteArray expected{"correct horse"};
    QByteArray observed;
    bool called = false;
    int callCount = 0;

    bool authenticate(std::span<const char> secret) override
    {
        called = true;
        ++callCount;
        observed = QByteArray(secret.data(), static_cast<qsizetype>(secret.size()));
        return observed == expected;
    }
};

class LockerNativeTest final : public QObject {
    Q_OBJECT

private:
    static void type(SecurePrompt &prompt, const QString &text)
    {
        QKeyEvent event(QEvent::KeyPress, Qt::Key_unknown, Qt::NoModifier, text);
        QCoreApplication::sendEvent(&prompt, &event);
    }

private slots:
    void correctSecretAuthenticatesAndZeroizes()
    {
        FakeAuthenticator auth;
        SecurePrompt prompt(&auth);
        type(prompt, QStringLiteral("correct horse"));
        QCOMPARE(prompt.inputLength(), 13);

        QSignalSpy accepted(&prompt, &SecurePrompt::authenticated);
        QVERIFY(prompt.authenticate());
        QCOMPARE(prompt.authState(), AuthState::Accepted);
        QCOMPARE(accepted.count(), 1);
        QCOMPARE(prompt.inputLength(), 0);
        QVERIFY(prompt.secretStorageIsZeroForTesting());
    }

    void incorrectAndEmptySecretsNeverAuthenticate()
    {
        FakeAuthenticator auth;
        SecurePrompt prompt(&auth);
        QSignalSpy accepted(&prompt, &SecurePrompt::authenticated);

        QVERIFY(!prompt.authenticate());
        QVERIFY(!auth.called);
        QCOMPARE(prompt.authState(), AuthState::Rejected);

        type(prompt, QStringLiteral("wrong"));
        QVERIFY(!prompt.authenticate());
        QCOMPARE(auth.callCount, 1);
        type(prompt, QStringLiteral("wrong again"));
        QVERIFY(!prompt.authenticate());
        QCOMPARE(auth.callCount, 1);
        QCOMPARE(accepted.count(), 0);
        QCOMPARE(prompt.inputLength(), 0);
        QVERIFY(prompt.secretStorageIsZeroForTesting());
    }

    void cancelBackspaceAndDestructionClearNativeStorage()
    {
        FakeAuthenticator auth;
        auto prompt = std::make_unique<SecurePrompt>(&auth);
        type(*prompt, QStringLiteral("secret"));

        QKeyEvent backspace(QEvent::KeyPress, Qt::Key_Backspace, Qt::NoModifier);
        QCoreApplication::sendEvent(prompt.get(), &backspace);
        QCOMPARE(prompt->inputLength(), 5);

        QKeyEvent escape(QEvent::KeyPress, Qt::Key_Escape, Qt::NoModifier);
        QCoreApplication::sendEvent(prompt.get(), &escape);
        QCOMPARE(prompt->inputLength(), 0);
        QVERIFY(prompt->secretStorageIsZeroForTesting());
        prompt.reset();
    }

    void shiftedCharactersAndShutdownAreHandledNatively()
    {
        FakeAuthenticator auth;
        SecurePrompt prompt(&auth);
        QKeyEvent shifted(QEvent::KeyPress, Qt::Key_Exclam, Qt::ShiftModifier,
                          QStringLiteral("!"));
        QCoreApplication::sendEvent(&prompt, &shifted);
        QCOMPARE(prompt.inputLength(), 1);

        QVERIFY(QMetaObject::invokeMethod(QCoreApplication::instance(), "aboutToQuit",
                                          Qt::DirectConnection));
        QCOMPARE(prompt.inputLength(), 0);
        QVERIFY(prompt.secretStorageIsZeroForTesting());
    }

    void terminationSignalZeroizesBeforeImmediateExit()
    {
        FakeAuthenticator auth;
        {
            SecurePrompt prompt(&auth);
            type(prompt, QStringLiteral("signal secret"));
            QVERIFY(!prompt.secretStorageIsZeroForTesting());

            SecurePrompt::zeroizeProcessSecretsForTesting();
            QVERIFY(prompt.secretStorageIsZeroForTesting());
        }

        SecurePrompt signalPrompt(&auth);
        type(signalPrompt, QStringLiteral("second secret"));
        int auditPipe[2] = {-1, -1};
        QCOMPARE(::pipe(auditPipe), 0);
        SecurePrompt::setSignalAuditFdForTesting(auditPipe[1]);
        const pid_t child = ::fork();
        QVERIFY(child >= 0);
        if (child == 0) {
            ::close(auditPipe[0]);
            ::raise(SIGTERM);
            ::_exit(99);
        }
        ::close(auditPipe[1]);

        int status = 0;
        QCOMPARE(::waitpid(child, &status, 0), child);
        QVERIFY(WIFSIGNALED(status));
        QCOMPARE(WTERMSIG(status), SIGTERM);
        unsigned char signalWipedStorage = 0;
        QCOMPARE(::read(auditPipe[0], &signalWipedStorage, sizeof(signalWipedStorage)), 1);
        QCOMPARE(signalWipedStorage, static_cast<unsigned char>(1));
        ::close(auditPipe[0]);
        SecurePrompt::setSignalAuditFdForTesting(-1);
    }

    void inputMethodIsPrivateAndHonorsReplacementRanges()
    {
        FakeAuthenticator auth;
        auth.expected = QByteArray("a\xc3\xa7Xb");
        SecurePrompt prompt(&auth);

        QCOMPARE(prompt.inputMethodQuery(Qt::ImEnabled).toBool(), true);
        const auto hints = prompt.inputMethodQuery(Qt::ImHints).value<Qt::InputMethodHints>();
        QVERIFY(hints.testFlag(Qt::ImhHiddenText));
        QVERIFY(hints.testFlag(Qt::ImhSensitiveData));
        QVERIFY(hints.testFlag(Qt::ImhNoPredictiveText));

        type(prompt, QStringLiteral("a😀b"));
        QCOMPARE(prompt.inputLength(), 3);
        QCOMPARE(prompt.inputMethodQuery(Qt::ImCursorPosition).toInt(), 4);

        QInputMethodEvent insertion;
        insertion.setCommitString(QStringLiteral("X"), -1, 0);
        QCoreApplication::sendEvent(&prompt, &insertion);
        QCOMPARE(prompt.inputLength(), 4);
        QCOMPARE(prompt.inputMethodQuery(Qt::ImCursorPosition).toInt(), 5);

        QInputMethodEvent replacement;
        replacement.setCommitString(QStringLiteral("ç"), -4, 2);
        QCoreApplication::sendEvent(&prompt, &replacement);
        QCOMPARE(prompt.inputLength(), 4);
        QCOMPARE(prompt.inputMethodQuery(Qt::ImCursorPosition).toInt(), 4);
        QVERIFY(prompt.authenticate());
        QCOMPARE(auth.observed, auth.expected);
        QVERIFY(prompt.secretStorageIsZeroForTesting());
    }

    void qmlMetaObjectExposesNoPlaintextProperty()
    {
        FakeAuthenticator auth;
        SecurePrompt prompt(&auth);
        const QMetaObject *meta = prompt.metaObject();
        for (int index = meta->propertyOffset(); index < meta->propertyCount(); ++index) {
            const QByteArray name = QByteArray(meta->property(index).name()).toLower();
            QVERIFY(!name.contains("password"));
            QVERIFY(!name.contains("secret"));
            QVERIFY(!name.contains("text"));
            QVERIFY(!name.contains("buffer"));
        }
    }

    void privateEndpointHandlesFragmentedLockAndSecureAck()
    {
        QTemporaryDir runtime;
        QVERIFY(runtime.isValid());
        const QByteArray oldRuntime = qgetenv("XDG_RUNTIME_DIR");
        const QByteArray oldSocket = qgetenv("SLEEPY_LOCKER_SOCKET");
        qputenv("XDG_RUNTIME_DIR", runtime.path().toUtf8());
        qunsetenv("SLEEPY_LOCKER_SOCKET");

        {
            LockerEndpoint endpoint;
            QSignalSpy requested(&endpoint, &LockerEndpoint::lockRequested);
            QLocalSocket client;
            client.connectToServer(runtime.path() + QStringLiteral("/sleepy/locker.sock"));
            QVERIFY(client.waitForConnected(1000));
            QCOMPARE(client.write("lo"), 2);
            QVERIFY(client.waitForBytesWritten(1000));
            QTest::qWait(10);
            QCOMPARE(requested.count(), 0);
            QCOMPARE(client.state(), QLocalSocket::ConnectedState);

            QCOMPARE(client.write("ck\n"), 3);
            QVERIFY(client.waitForBytesWritten(1000));
            QTRY_COMPARE(requested.count(), 1);
            endpoint.setSecure(true);
            QTRY_VERIFY(client.canReadLine());
            QCOMPARE(client.readLine(), QByteArrayLiteral("locked\n"));
        }

        if (oldRuntime.isNull()) qunsetenv("XDG_RUNTIME_DIR");
        else qputenv("XDG_RUNTIME_DIR", oldRuntime);
        if (oldSocket.isNull()) qunsetenv("SLEEPY_LOCKER_SOCKET");
        else qputenv("SLEEPY_LOCKER_SOCKET", oldSocket);
    }

    void privateEndpointReportsAuthoritativeStatusAndHoldsSuspendAcrossSleep()
    {
        QTemporaryDir runtime;
        QVERIFY(runtime.isValid());
        const QByteArray oldRuntime = qgetenv("XDG_RUNTIME_DIR");
        const QByteArray oldSocket = qgetenv("SLEEPY_LOCKER_SOCKET");
        qputenv("XDG_RUNTIME_DIR", runtime.path().toUtf8());
        qunsetenv("SLEEPY_LOCKER_SOCKET");

        {
            LockerEndpoint endpoint;
            const QString socketPath = runtime.path() + QStringLiteral("/sleepy/locker.sock");

            QLocalSocket initialStatus;
            initialStatus.connectToServer(socketPath);
            QVERIFY(initialStatus.waitForConnected(1000));
            QCOMPARE(initialStatus.write("status\n"), 7);
            QVERIFY(initialStatus.waitForBytesWritten(1000));
            QTRY_VERIFY(initialStatus.canReadLine());
            QCOMPARE(initialStatus.readLine(), QByteArrayLiteral("unlocked\n"));

            QSignalSpy requested(&endpoint, &LockerEndpoint::lockRequested);
            QSignalSpy holdChanged(&endpoint, &LockerEndpoint::unlockAllowedChanged);
            QLocalSocket suspend;
            suspend.connectToServer(socketPath);
            QVERIFY(suspend.waitForConnected(1000));
            QCOMPARE(suspend.write("suspend\n"), 8);
            QVERIFY(suspend.waitForBytesWritten(1000));
            QTRY_COMPARE(requested.count(), 1);
            QVERIFY(endpoint.unlockAllowed());

            endpoint.setSecure(true);
            QTRY_VERIFY(suspend.canReadLine());
            QCOMPARE(suspend.readLine(), QByteArrayLiteral("locked\n"));
            QCOMPARE(suspend.state(), QLocalSocket::ConnectedState);
            QVERIFY(!endpoint.unlockAllowed());
            QCOMPARE(holdChanged.count(), 1);

            QLocalSocket lockedStatus;
            lockedStatus.connectToServer(socketPath);
            QVERIFY(lockedStatus.waitForConnected(1000));
            QCOMPARE(lockedStatus.write("status\n"), 7);
            QVERIFY(lockedStatus.waitForBytesWritten(1000));
            QTRY_VERIFY(lockedStatus.canReadLine());
            QCOMPARE(lockedStatus.readLine(), QByteArrayLiteral("locked\n"));

            suspend.disconnectFromServer();
            QTRY_VERIFY(endpoint.unlockAllowed());
            QCOMPARE(holdChanged.count(), 2);
        }

        if (oldRuntime.isNull()) qunsetenv("XDG_RUNTIME_DIR");
        else qputenv("XDG_RUNTIME_DIR", oldRuntime);
        if (oldSocket.isNull()) qunsetenv("SLEEPY_LOCKER_SOCKET");
        else qputenv("SLEEPY_LOCKER_SOCKET", oldSocket);
    }

    void privateEndpointRejectsUnlockAndBoundsIdleClients()
    {
        QTemporaryDir runtime;
        QVERIFY(runtime.isValid());
        const QByteArray oldRuntime = qgetenv("XDG_RUNTIME_DIR");
        const QByteArray oldSocket = qgetenv("SLEEPY_LOCKER_SOCKET");
        qputenv("XDG_RUNTIME_DIR", runtime.path().toUtf8());
        qunsetenv("SLEEPY_LOCKER_SOCKET");

        {
            LockerEndpoint endpoint;
            QSignalSpy requested(&endpoint, &LockerEndpoint::lockRequested);
            const QString socketPath = runtime.path() + QStringLiteral("/sleepy/locker.sock");
            QLocalSocket invalid;
            invalid.connectToServer(socketPath);
            QVERIFY(invalid.waitForConnected(1000));
            invalid.write("unlock\n");
            QVERIFY(invalid.waitForBytesWritten(1000));
            QTRY_VERIFY(invalid.canReadLine());
            QCOMPARE(invalid.readLine(), QByteArrayLiteral("error\n"));
            QCOMPARE(requested.count(), 0);

            std::vector<std::unique_ptr<QLocalSocket>> idle;
            for (int index = 0; index < 16; ++index) {
                auto client = std::make_unique<QLocalSocket>();
                client->connectToServer(socketPath);
                QVERIFY(client->waitForConnected(1000));
                idle.push_back(std::move(client));
                QCoreApplication::processEvents();
            }
            QLocalSocket overflow;
            overflow.connectToServer(socketPath);
            QVERIFY(overflow.waitForConnected(1000));
            QTRY_COMPARE(overflow.state(), QLocalSocket::UnconnectedState);
        }

        if (oldRuntime.isNull()) qunsetenv("XDG_RUNTIME_DIR");
        else qputenv("XDG_RUNTIME_DIR", oldRuntime);
        if (oldSocket.isNull()) qunsetenv("SLEEPY_LOCKER_SOCKET");
        else qputenv("SLEEPY_LOCKER_SOCKET", oldSocket);
    }
};

QTEST_MAIN(LockerNativeTest)
#include "locker_native.moc"
