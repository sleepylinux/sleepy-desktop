#pragma once

#include <QLocalServer>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QVector>

class QLocalSocket;

namespace sleepy::locker {

class LockerEndpoint : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool secure READ secure WRITE setSecure NOTIFY secureChanged FINAL)
    Q_PROPERTY(bool unlockAllowed READ unlockAllowed NOTIFY unlockAllowedChanged FINAL)

public:
    explicit LockerEndpoint(QObject *parent = nullptr);
    ~LockerEndpoint() override;

    [[nodiscard]] bool secure() const noexcept;
    [[nodiscard]] bool unlockAllowed() const noexcept;
    void setSecure(bool secure);

signals:
    void secureChanged();
    void unlockAllowedChanged();
    void lockRequested();

private slots:
    void acceptConnections();

private:
    void readRequest(QLocalSocket *socket);
    void acknowledgePending();

    QLocalServer server_;
    QVector<QLocalSocket *> clients_;
    QVector<QLocalSocket *> pending_;
    QVector<QLocalSocket *> suspendHolds_;
    QString path_;
    bool secure_ = false;
};

} // namespace sleepy::locker
