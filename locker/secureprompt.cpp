#include "secureprompt.hpp"

#include <QInputMethodEvent>
#include <QKeyEvent>
#include <QCoreApplication>

#include <security/pam_appl.h>
#include <sys/mman.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <cerrno>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <pwd.h>
#include <stdexcept>
#include <strings.h>
#include <system_error>

namespace sleepy::locker {
namespace {

constexpr std::size_t kSecretCapacity = 4096;
constexpr std::size_t kSecretSlotCount = 64;

struct SignalSecretSlot {
    std::atomic<char *> bytes{nullptr};
    std::atomic<bool> inUse{false};
};

static_assert(std::atomic<char *>::is_always_lock_free);
static_assert(std::atomic<bool>::is_always_lock_free);

std::array<SignalSecretSlot, kSecretSlotCount> signalSecretSlots;
std::once_flag signalHandlersInstalled;
#ifdef SLEEPY_LOCKER_TESTING
std::atomic<int> signalAuditFd{-1};
static_assert(std::atomic<int>::is_always_lock_free);
#endif

void wipeProcessSecrets() noexcept
{
    for (auto &slot : signalSecretSlots) {
        char *const bytes = slot.bytes.load(std::memory_order_relaxed);
        if (bytes == nullptr) {
            continue;
        }
        auto *volatile target = reinterpret_cast<volatile unsigned char *>(bytes);
        for (std::size_t index = 0; index < kSecretCapacity; ++index) {
            target[index] = 0;
        }
    }
}

void terminationSignalHandler(int signalNumber) noexcept
{
    wipeProcessSecrets();
#ifdef SLEEPY_LOCKER_TESTING
    unsigned char allZero = 1;
    for (auto &slot : signalSecretSlots) {
        const volatile char *const bytes = slot.bytes.load(std::memory_order_relaxed);
        if (bytes == nullptr) {
            continue;
        }
        for (std::size_t index = 0; index < kSecretCapacity; ++index) {
            if (bytes[index] != 0) {
                allZero = 0;
            }
        }
    }
    const int auditDescriptor = signalAuditFd.load(std::memory_order_relaxed);
    if (auditDescriptor >= 0) {
        static_cast<void>(::write(auditDescriptor, &allZero, sizeof(allZero)));
    }
#endif
    if (::kill(::getpid(), signalNumber) != 0) {
        ::_exit(128 + signalNumber);
    }
}

void installTerminationSignalHandlers()
{
    std::call_once(signalHandlersInstalled, [] {
        struct sigaction action {};
        action.sa_handler = terminationSignalHandler;
        ::sigemptyset(&action.sa_mask);
        action.sa_flags = static_cast<int>(SA_RESETHAND);
        for (const int signalNumber : {SIGTERM, SIGINT, SIGHUP}) {
            if (::sigaction(signalNumber, &action, nullptr) != 0) {
                throw std::system_error(errno, std::generic_category(),
                                        "failed to install locker termination handler");
            }
        }
    });
}

SignalSecretSlot *acquireSignalSecretSlot()
{
    installTerminationSignalHandlers();
    for (auto &slot : signalSecretSlots) {
        bool expected = false;
        if (!slot.inUse.compare_exchange_strong(expected, true,
                                                std::memory_order_acq_rel)) {
            continue;
        }
        char *bytes = slot.bytes.load(std::memory_order_acquire);
        if (bytes == nullptr) {
            void *mapping = ::mmap(nullptr, kSecretCapacity, PROT_READ | PROT_WRITE,
                                   MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
            if (mapping == MAP_FAILED) {
                slot.inUse.store(false, std::memory_order_release);
                throw std::runtime_error("failed to allocate secure input memory");
            }
            bytes = static_cast<char *>(mapping);
            if (::mlock(bytes, kSecretCapacity) != 0) {
                ::munmap(bytes, kSecretCapacity);
                slot.inUse.store(false, std::memory_order_release);
                throw std::runtime_error("failed to lock secure input memory");
            }
#ifdef MADV_DONTDUMP
            static_cast<void>(::madvise(bytes, kSecretCapacity, MADV_DONTDUMP));
#endif
            slot.bytes.store(bytes, std::memory_order_release);
        }
        return &slot;
    }
    throw std::runtime_error("secure input buffer pool exhausted");
}

struct PamConversationData { std::span<const char> secret; };

int pamConversation(int count, const pam_message **messages,
                    pam_response **responses, void *opaque)
{
    if (count <= 0 || messages == nullptr || responses == nullptr || opaque == nullptr) {
        return PAM_CONV_ERR;
    }
    auto *data = static_cast<PamConversationData *>(opaque);
    auto *result = static_cast<pam_response *>(
        std::calloc(static_cast<std::size_t>(count), sizeof(pam_response)));
    if (result == nullptr) {
        return PAM_BUF_ERR;
    }
    const auto discard = [result](int initialized) {
        for (int index = 0; index < initialized; ++index) {
            if (result[index].resp != nullptr) {
                explicit_bzero(result[index].resp, std::strlen(result[index].resp));
                std::free(result[index].resp);
            }
        }
        std::free(result);
    };
    for (int index = 0; index < count; ++index) {
        if (messages[index] == nullptr) {
            discard(index);
            return PAM_CONV_ERR;
        }
        if (messages[index]->msg_style == PAM_PROMPT_ECHO_OFF) {
            const std::size_t length = data->secret.size();
            result[index].resp = static_cast<char *>(std::malloc(length + 1));
            if (result[index].resp == nullptr) {
                discard(index);
                return PAM_BUF_ERR;
            }
            std::memcpy(result[index].resp, data->secret.data(), length);
            result[index].resp[length] = '\0';
        } else if (messages[index]->msg_style == PAM_PROMPT_ECHO_ON) {
            result[index].resp = ::strdup("");
            if (result[index].resp == nullptr) {
                discard(index);
                return PAM_BUF_ERR;
            }
        } else if (messages[index]->msg_style != PAM_ERROR_MSG
                   && messages[index]->msg_style != PAM_TEXT_INFO) {
            discard(index);
            return PAM_CONV_ERR;
        }
    }
    *responses = result;
    return PAM_SUCCESS;
}

class PamAuthenticator final : public Authenticator {
public:
    bool authenticate(std::span<const char> secret) override
    {
        const passwd *account = ::getpwuid(::getuid());
        if (account == nullptr || account->pw_name == nullptr) {
            return false;
        }
        PamConversationData data{secret};
        pam_conv conversation{pamConversation, &data};
        pam_handle_t *handle = nullptr;
        const int start = ::pam_start("sleepy-locker", account->pw_name,
                                      &conversation, &handle);
        if (start != PAM_SUCCESS || handle == nullptr) {
            return false;
        }
        const int auth = ::pam_authenticate(handle, PAM_SILENT | PAM_DISALLOW_NULL_AUTHTOK);
        // This process is the already-authenticated user's screen locker, not
        // a login authority. The default pam_unix account stack attempts a
        // privileged setuid transition and correctly fails in this
        // unprivileged process. Authentication still rejects disabled or
        // invalid password credentials; login-time account/session policy
        // remains owned by ReGreet.
        const bool accepted = auth == PAM_SUCCESS;
        ::pam_end(handle, auth);
        return accepted;
    }
};

std::size_t encodeUtf8(char *target, char32_t codePoint)
{
    if (codePoint <= 0x7f) {
        target[0] = static_cast<char>(codePoint);
        return 1;
    }
    if (codePoint <= 0x7ff) {
        target[0] = static_cast<char>(0xc0 | (codePoint >> 6));
        target[1] = static_cast<char>(0x80 | (codePoint & 0x3f));
        return 2;
    }
    if (codePoint <= 0xffff) {
        target[0] = static_cast<char>(0xe0 | (codePoint >> 12));
        target[1] = static_cast<char>(0x80 | ((codePoint >> 6) & 0x3f));
        target[2] = static_cast<char>(0x80 | (codePoint & 0x3f));
        return 3;
    }
    target[0] = static_cast<char>(0xf0 | (codePoint >> 18));
    target[1] = static_cast<char>(0x80 | ((codePoint >> 12) & 0x3f));
    target[2] = static_cast<char>(0x80 | ((codePoint >> 6) & 0x3f));
    target[3] = static_cast<char>(0x80 | (codePoint & 0x3f));
    return 4;
}

} // namespace

class LockedSecretBuffer final {
public:
    LockedSecretBuffer()
    {
        slot_ = acquireSignalSecretSlot();
        bytes_ = slot_->bytes.load(std::memory_order_acquire);
    }

    ~LockedSecretBuffer()
    {
        clear(); // ZEROIZE_DESTRUCTION
        slot_->inUse.store(false, std::memory_order_release);
    }

    [[nodiscard]] std::span<const char> value() const noexcept { return {bytes_, size_}; }
    [[nodiscard]] int codePoints() const noexcept { return codePoints_; }
    [[nodiscard]] int utf16Units() const noexcept { return utf16Units_; }

    void append(QStringView text)
    {
        insertAt(size_, text);
    }

    void insertAt(std::size_t byteOffset, QStringView text)
    {
        std::array<char, 4> encoded{};
        for (auto iterator = text.begin(); iterator != text.end(); ++iterator) {
            char32_t codePoint = iterator->unicode();
            if (QChar::isHighSurrogate(iterator->unicode())) {
                const auto next = iterator + 1;
                if (next == text.end() || !QChar::isLowSurrogate(next->unicode())) {
                    continue;
                }
                codePoint = QChar::surrogateToUcs4(*iterator, *next);
                ++iterator;
            } else if (QChar::isLowSurrogate(iterator->unicode())) {
                continue;
            }
            if (codePoint == 0) {
                continue;
            }
            const std::size_t count = encodeUtf8(encoded.data(), codePoint);
            if (size_ + count > kSecretCapacity) {
                break;
            }
            std::memmove(bytes_ + byteOffset + count, bytes_ + byteOffset,
                         size_ - byteOffset);
            std::memcpy(bytes_ + byteOffset, encoded.data(), count);
            size_ += count;
            byteOffset += count;
            ++codePoints_;
            utf16Units_ += codePoint > 0xffff ? 2 : 1;
        }
        explicit_bzero(encoded.data(), encoded.size());
    }

    void removeLast() noexcept
    {
        if (size_ == 0) {
            return;
        }
        std::size_t first = size_ - 1;
        while (first > 0
               && (static_cast<unsigned char>(bytes_[first]) & 0xc0U) == 0x80U) {
            --first;
        }
        const std::size_t removedBytes = size_ - first;
        explicit_bzero(bytes_ + first, removedBytes);
        size_ = first;
        --codePoints_;
        utf16Units_ -= removedBytes == 4 ? 2 : 1;
    }

    bool replace(int replacementStart, int replacementLength, QStringView text)
    {
        if (replacementStart > 0 || replacementLength < 0) {
            return false;
        }
        const qint64 firstUtf16 = static_cast<qint64>(utf16Units_) + replacementStart;
        const qint64 lastUtf16 = firstUtf16 + replacementLength;
        if (firstUtf16 < 0 || lastUtf16 < firstUtf16 || lastUtf16 > utf16Units_) {
            return false;
        }

        const auto locateUtf16 = [this](int targetUtf16, std::size_t &byteOffset,
                                        int &codePointOffset) {
            int currentUtf16 = 0;
            int currentCodePoint = 0;
            std::size_t offset = 0;
            while (offset < size_ && currentUtf16 < targetUtf16) {
                const unsigned char lead = static_cast<unsigned char>(bytes_[offset]);
                const std::size_t byteCount = lead < 0x80U ? 1
                    : lead < 0xe0U ? 2 : lead < 0xf0U ? 3 : 4;
                const int characterUtf16 = byteCount == 4 ? 2 : 1;
                if (currentUtf16 + characterUtf16 > targetUtf16) {
                    return false;
                }
                offset += byteCount;
                currentUtf16 += characterUtf16;
                ++currentCodePoint;
            }
            if (currentUtf16 != targetUtf16) {
                return false;
            }
            byteOffset = offset;
            codePointOffset = currentCodePoint;
            return true;
        };
        std::size_t firstByte = 0;
        std::size_t lastByte = 0;
        int firstCodePoint = 0;
        int lastCodePoint = 0;
        if (!locateUtf16(static_cast<int>(firstUtf16), firstByte, firstCodePoint)
            || !locateUtf16(static_cast<int>(lastUtf16), lastByte, lastCodePoint)) {
            return false;
        }
        const std::size_t removedBytes = lastByte - firstByte;
        std::memmove(bytes_ + firstByte, bytes_ + lastByte, size_ - lastByte);
        size_ -= removedBytes;
        explicit_bzero(bytes_ + size_, removedBytes);
        codePoints_ -= lastCodePoint - firstCodePoint;
        utf16Units_ -= replacementLength;
        insertAt(firstByte, text);
        return true;
    }

    void clear() noexcept
    {
        if (bytes_ != nullptr) {
            explicit_bzero(bytes_, kSecretCapacity);
        }
        size_ = 0;
        codePoints_ = 0;
        utf16Units_ = 0;
    }

#ifdef SLEEPY_LOCKER_TESTING
    [[nodiscard]] bool isZero() const noexcept
    {
        return std::all_of(bytes_, bytes_ + kSecretCapacity,
                           [](char byte) { return byte == '\0'; });
    }
#endif

private:
    SignalSecretSlot *slot_ = nullptr;
    char *bytes_ = nullptr;
    std::size_t size_ = 0;
    int codePoints_ = 0;
    int utf16Units_ = 0;
};

SecurePrompt::SecurePrompt(QQuickItem *parent)
    : QQuickItem(parent)
    , ownedAuthenticator_(std::make_unique<PamAuthenticator>())
    , authenticator_(ownedAuthenticator_.get())
    , secret_(std::make_unique<LockedSecretBuffer>())
{
    setFlag(ItemAcceptsInputMethod, true);
    setActiveFocusOnTab(true);
    retryClock_.start();
    connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit,
            this, &SecurePrompt::clearSecret, Qt::DirectConnection);
}

SecurePrompt::SecurePrompt(Authenticator *authenticator, QQuickItem *parent)
    : QQuickItem(parent)
    , authenticator_(authenticator)
    , secret_(std::make_unique<LockedSecretBuffer>())
{
    if (authenticator_ == nullptr) {
        throw std::invalid_argument("authenticator is required");
    }
    setFlag(ItemAcceptsInputMethod, true);
    setActiveFocusOnTab(true);
    retryClock_.start();
    connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit,
            this, &SecurePrompt::clearSecret, Qt::DirectConnection);
}

SecurePrompt::~SecurePrompt()
{
    clearSecret(); // ZEROIZE_SHUTDOWN
}

int SecurePrompt::inputLength() const noexcept { return inputLength_; }
AuthState SecurePrompt::authState() const noexcept { return authState_; }

bool SecurePrompt::authenticate()
{
    if (secret_->value().empty()) {
        clearSecret(); // ZEROIZE_SUBMIT
        setAuthState(AuthState::Rejected);
        return false;
    }
    if (retryClock_.elapsed() < retryAfterMs_) {
        clearSecret(); // ZEROIZE_FAILURE
        setAuthState(AuthState::Rejected);
        return false;
    }
    setAuthState(AuthState::Authenticating);
    bool accepted = false;
    try {
        accepted = authenticator_->authenticate(secret_->value());
    } catch (...) {
        clearSecret(); // ZEROIZE_FAILURE
        setAuthState(AuthState::Error);
        return false;
    }
    clearSecret(); // ZEROIZE_SUBMIT
    setAuthState(accepted ? AuthState::Accepted : AuthState::Rejected);
    if (accepted) {
        failureCount_ = 0;
        retryAfterMs_ = 0;
        emit authenticated();
    } else {
        failureCount_ = std::min(failureCount_ + 1U, 5U);
        const qint64 delay = std::min<qint64>(8000, 250LL << failureCount_);
        retryAfterMs_ = retryClock_.elapsed() + delay;
    }
    return accepted;
}

void SecurePrompt::clearSecret() noexcept
{
    secret_->clear(); // ZEROIZE_CANCEL
    if (inputLength_ != 0) {
        inputLength_ = 0;
        emit inputLengthChanged();
    }
}

QVariant SecurePrompt::inputMethodQuery(Qt::InputMethodQuery query) const
{
    switch (query) {
    case Qt::ImEnabled:
        return true;
    case Qt::ImHints:
        return QVariant::fromValue(Qt::InputMethodHints(
            Qt::ImhHiddenText | Qt::ImhSensitiveData | Qt::ImhNoPredictiveText));
    case Qt::ImCursorPosition:
    case Qt::ImAnchorPosition:
        return secret_->utf16Units();
    case Qt::ImSurroundingText:
    case Qt::ImCurrentSelection:
        return QString();
    default:
        return QQuickItem::inputMethodQuery(query);
    }
}

#ifdef SLEEPY_LOCKER_TESTING
bool SecurePrompt::secretStorageIsZeroForTesting() const noexcept
{
    return secret_->isZero();
}

void SecurePrompt::zeroizeProcessSecretsForTesting() noexcept
{
    wipeProcessSecrets();
}

void SecurePrompt::setSignalAuditFdForTesting(int descriptor) noexcept
{
    signalAuditFd.store(descriptor, std::memory_order_relaxed);
}
#endif

void SecurePrompt::keyPressEvent(QKeyEvent *event)
{
    if (event->key() == Qt::Key_Return || event->key() == Qt::Key_Enter) {
        static_cast<void>(authenticate());
        event->accept();
    } else if (event->key() == Qt::Key_Backspace) {
        removeLastCodePoint();
        event->accept();
    } else if (event->key() == Qt::Key_Escape) {
        clearSecret();
        setAuthState(AuthState::Idle);
        event->accept();
    } else if (!event->text().isEmpty()
               && !(event->modifiers()
                    & (Qt::ControlModifier | Qt::AltModifier | Qt::MetaModifier))) {
        appendText(event->text());
        event->accept();
    } else {
        QQuickItem::keyPressEvent(event);
    }
}

void SecurePrompt::inputMethodEvent(QInputMethodEvent *event)
{
    if (!event->commitString().isEmpty() || event->replacementLength() != 0) {
        const int previous = secret_->codePoints();
        if (secret_->replace(event->replacementStart(), event->replacementLength(),
                             event->commitString())) {
            inputLength_ = secret_->codePoints();
            if (inputLength_ != previous) {
                setAuthState(AuthState::Idle);
                emit inputLengthChanged();
            }
        }
    }
    event->accept();
}

void SecurePrompt::appendText(QStringView text)
{
    const int previous = secret_->codePoints();
    secret_->append(text);
    inputLength_ = secret_->codePoints();
    if (inputLength_ != previous) {
        setAuthState(AuthState::Idle);
        emit inputLengthChanged();
    }
}

void SecurePrompt::removeLastCodePoint() noexcept
{
    const int previous = inputLength_;
    secret_->removeLast();
    inputLength_ = secret_->codePoints();
    if (inputLength_ != previous) {
        setAuthState(AuthState::Idle);
        emit inputLengthChanged();
    }
}

void SecurePrompt::setAuthState(AuthState state) noexcept
{
    if (authState_ != state) {
        authState_ = state;
        emit authStateChanged();
    }
}

} // namespace sleepy::locker
