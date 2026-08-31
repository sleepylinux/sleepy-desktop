#pragma once

#include <QtQuick/qquickitem.h>
#include <qlist.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qvariant.h>

namespace sleepy {

class CUtils : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(QString qtVersion READ qtVersion CONSTANT)

public:
    Q_INVOKABLE static QString toLocalFile(const QUrl& url);

    Q_INVOKABLE static qreal clamp(qreal value, qreal min, qreal max);

    Q_INVOKABLE static QString enumToString(
        QObject* target, const QString& property, const QVariant& value = QVariant());

    Q_INVOKABLE static QQuickItem* findChild(QQuickItem* root, const QString& name);
    Q_INVOKABLE static QList<QQuickItem*> findChildren(QQuickItem* root, const QString& name);
    Q_INVOKABLE static QList<QQuickItem*> findChildrenMatching(QQuickItem* root, const QString& pattern);

    [[nodiscard]] QString version() const;
    [[nodiscard]] QString qtVersion() const;
};

} // namespace sleepy
