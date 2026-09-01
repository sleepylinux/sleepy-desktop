#pragma once

#include <QQuickItem>
#include <QElapsedTimer>

#include <memory>
#include <span>

namespace sleepy::locker {

Q_NAMESPACE
QML_NAMED_ELEMENT(AuthState)

enum class AuthState { Idle, Authenticating, Accepted, Rejected, Error };
Q_ENUM_NS(AuthState)

class Authenticator {
public:
    virtual ~Authenticator() = default;
    virtual bool authenticate(std::span<const char> secret) = 0;
};

class LockedSecretBuffer;

class SecurePrompt : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int inputLength READ inputLength NOTIFY inputLengthChanged FINAL)
    Q_PROPERTY(AuthState authState READ authState NOTIFY authStateChanged FINAL)

public:
    explicit SecurePrompt(QQuickItem *parent = nullptr);
    explicit SecurePrompt(Authenticator *authenticator, QQuickItem *parent = nullptr);
    ~SecurePrompt() override;

    [[nodiscard]] int inputLength() const noexcept;
    [[nodiscard]] AuthState authState() const noexcept;
    Q_INVOKABLE bool authenticate();
    Q_INVOKABLE void clearSecret() noexcept;
    [[nodiscard]] QVariant inputMethodQuery(Qt::InputMethodQuery query) const override;

#ifdef SLEEPY_LOCKER_TESTING
    [[nodiscard]] bool secretStorageIsZeroForTesting() const noexcept;
    static void zeroizeProcessSecretsForTesting() noexcept;
    static void setSignalAuditFdForTesting(int descriptor) noexcept;
#endif

signals:
    void inputLengthChanged();
    void authStateChanged();
    void authenticated();

protected:
    void keyPressEvent(QKeyEvent *event) override;
    void inputMethodEvent(QInputMethodEvent *event) override;

private:
    void appendText(QStringView text);
    void removeLastCodePoint() noexcept;
    void setAuthState(AuthState state) noexcept;

    std::unique_ptr<Authenticator> ownedAuthenticator_;
    Authenticator *authenticator_ = nullptr;
    std::unique_ptr<LockedSecretBuffer> secret_;
    QElapsedTimer retryClock_;
    qint64 retryAfterMs_ = 0;
    unsigned int failureCount_ = 0;
    int inputLength_ = 0;
    AuthState authState_ = AuthState::Idle;
};

} // namespace sleepy::locker
