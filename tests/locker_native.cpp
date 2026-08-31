#include "secureprompt.hpp"

#include <QGuiApplication>
#include <QKeyEvent>
#include <QtTest>

using sleepy::locker::AuthState;
using sleepy::locker::Authenticator;
using sleepy::locker::SecurePrompt;

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
};

QTEST_MAIN(LockerNativeTest)
#include "locker_native.moc"
