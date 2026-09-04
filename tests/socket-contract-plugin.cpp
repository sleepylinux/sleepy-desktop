#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtQml/QQmlExtensionPlugin>
#include <QtQml/qqml.h>

// Behavioral mirror of Quickshell src/io/socket.cpp at the revision pinned in
// flake.nix. In particular, connected reads the live transport state while its
// setter updates a separate target state, a successful connection clears that
// target, and an error retains the transport until a later disconnect callback.
class ContractSocket : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected WRITE setConnected NOTIFY connectionStateChanged)
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(QObject* parser READ parser WRITE setParser)
    Q_PROPERTY(bool targetConnected READ targetConnected NOTIFY lifecycleChanged)
    Q_PROPERTY(bool hasTransport READ hasTransport NOTIFY lifecycleChanged)
    Q_PROPERTY(bool disconnecting READ disconnecting NOTIFY lifecycleChanged)
    Q_PROPERTY(int connectAttempts READ connectAttempts NOTIFY lifecycleChanged)
    Q_PROPERTY(int instanceId READ instanceId CONSTANT)
    Q_PROPERTY(int liveInstances READ liveInstances)

public:
    explicit ContractSocket(QObject* parent = nullptr)
        : QObject(parent), mInstanceId(++sNextInstanceId) { ++sLiveInstances; }
    ~ContractSocket() override { --sLiveInstances; }

    bool isConnected() const { return mConnected; }
    QString path() const { return mPath; }
    QObject* parser() const { return mParser; }
    bool targetConnected() const { return mTargetConnected; }
    bool hasTransport() const { return mHasTransport; }
    bool disconnecting() const { return mDisconnecting; }
    int connectAttempts() const { return mConnectAttempts; }
    int instanceId() const { return mInstanceId; }
    int liveInstances() const { return sLiveInstances; }

    void setPath(const QString& path) {
        if ((mConnected && !mDisconnecting) || path == mPath)
            return;
        mPath = path;
        emit pathChanged();
        if (mTargetConnected && !mHasTransport)
            beginAttempt();
    }

    void setParser(QObject* parser) {
        mParser = parser;
        if (parser && !parser->parent())
            parser->setParent(this);
    }

    void setConnected(bool connected) {
        mTargetConnected = connected;
        emit lifecycleChanged();
        if (!connected) {
            if (mHasTransport && !mDisconnecting) {
                mDisconnecting = true;
                emit lifecycleChanged();
            }
        } else if (!mHasTransport) {
            beginAttempt();
        }
    }

    Q_INVOKABLE void succeedAttempt() {
        if (!mHasTransport)
            return;
        mConnected = true;
        mTargetConnected = false;
        mDisconnecting = false;
        emit lifecycleChanged();
        emit connectionStateChanged();
    }

    Q_INVOKABLE void failAttempt() {
        if (!mHasTransport || mConnected)
            return;
        emit error(0);
    }

    Q_INVOKABLE void emitError() { emit error(0); }

    Q_INVOKABLE void peerCloseError() {
        if (!mHasTransport || !mConnected)
            return;
        emit error(1);
    }

    Q_INVOKABLE void acknowledgePeerClose() {
        if (!mHasTransport)
            return;
        mConnected = false;
        mDisconnecting = false;
        mHasTransport = false;
        emit lifecycleChanged();
        emit connectionStateChanged();
        if (mTargetConnected)
            beginAttempt();
    }

    Q_INVOKABLE void acknowledgeDisconnect() {
        if (!mHasTransport || !mDisconnecting)
            return;
        mConnected = false;
        mDisconnecting = false;
        mHasTransport = false;
        emit lifecycleChanged();
        emit connectionStateChanged();
        if (mTargetConnected)
            beginAttempt();
    }

    Q_INVOKABLE void emitConnectionState() { emit connectionStateChanged(); }

signals:
    void error(int errorCode);
    void connectionStateChanged();
    void pathChanged();
    void lifecycleChanged();
    void transportAttempted();

private:
    void beginAttempt() {
        if (mPath.isEmpty())
            return;
        mHasTransport = true;
        ++mConnectAttempts;
        emit lifecycleChanged();
        emit transportAttempted();
    }

    inline static int sNextInstanceId = 0;
    inline static int sLiveInstances = 0;
    bool mConnected = false;
    bool mTargetConnected = false;
    bool mHasTransport = false;
    bool mDisconnecting = false;
    int mConnectAttempts = 0;
    int mInstanceId = 0;
    QString mPath;
    QObject* mParser = nullptr;
};

class SleepySocketContractPlugin final : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface/1.0")

public:
    void registerTypes(const char* uri) override {
        qmlRegisterType<ContractSocket>(uri, 1, 0, "Socket");
    }
};

#include "socket-contract-plugin.moc"
