#include "cutils.hpp"

#include <QtConcurrent/qtconcurrentrun.h>
#include <QtGui/qclipboard.h>
#include <QtGui/qguiapplication.h>
#include <QtQuick/qquickitemgrabresult.h>
#include <QtQuick/qquickwindow.h>
#include <qdir.h>
#include <qcoreapplication.h>
#include <qfileinfo.h>
#include <qfuturewatcher.h>
#include <qloggingcategory.h>
#include <qmetaobject.h>
#include <qregularexpression.h>
#include <qstandardpaths.h>
#include <quuid.h>
#include <qqmlengine.h>

#include "util/metaenum.hpp"

Q_LOGGING_CATEGORY(lcCUtils, "sleepy.cutils", QtInfoMsg)

namespace sleepy {

void CUtils::copyTextToClipboard(const QString& text) {
    QGuiApplication::clipboard()->setText(text);
}

namespace {

QRect scaledSelection(QQuickItem* target, const QRect& rect) {
    if (!rect.isValid() || !target || !target->window()) {
        return rect;
    }
    const qreal scale = target->window()->devicePixelRatio();
    if (qFuzzyCompare(scale + 1.0, 2.0)) {
        return rect;
    }
    return QRectF(rect.left() * scale, rect.top() * scale, rect.width() * scale, rect.height() * scale).toRect();
}

QImage selectedImage(const QSharedPointer<const QQuickItemGrabResult>& result, const QRect& rect) {
    QImage image = result->image();
    return rect.isValid() ? image.copy(rect) : image;
}

} // namespace

void CUtils::copyItemToClipboard(QQuickItem* target, const QRect& rect, QJSValue onCopied) {
    if (!target || !target->window()) {
        qCWarning(lcCUtils) << "copyItemToClipboard: a window-backed target is required";
        return;
    }

    const QRect selection = scaledSelection(target, rect);
    const QSharedPointer<const QQuickItemGrabResult> result = target->grabToImage();
    QObject::connect(result.data(), &QQuickItemGrabResult::ready, this, [result, selection, onCopied]() mutable {
        const QImage image = selectedImage(result, selection);
        if (image.isNull()) {
            qCWarning(lcCUtils) << "copyItemToClipboard: captured image is empty";
            return;
        }
        QGuiApplication::clipboard()->setImage(image);
        if (onCopied.isCallable()) {
            onCopied.call();
        }
    });
}

void CUtils::saveItemToTemp(QQuickItem* target, const QRect& rect, QJSValue onSaved) {
    if (!target || !target->window()) {
        qCWarning(lcCUtils) << "saveItemToTemp: a window-backed target is required";
        return;
    }

    const QString path = QDir(QStandardPaths::writableLocation(QStandardPaths::TempLocation))
                             .filePath(QStringLiteral("sleepy-picker-%1-%2.png")
                                           .arg(QCoreApplication::applicationPid())
                                           .arg(QUuid::createUuid().toString(QUuid::WithoutBraces)));
    const QRect selection = scaledSelection(target, rect);
    const QSharedPointer<const QQuickItemGrabResult> result = target->grabToImage();
    QObject::connect(result.data(), &QQuickItemGrabResult::ready, this,
        [result, selection, path, onSaved, this]() mutable {
            const auto future = QtConcurrent::run([result, selection, path]() {
                const QImage image = selectedImage(result, selection);
                return !image.isNull() && QDir().mkpath(QFileInfo(path).absolutePath()) && image.save(path);
            });
            auto* watcher = new QFutureWatcher<bool>(this);
            QObject::connect(watcher, &QFutureWatcher<bool>::finished, this, [watcher, path, onSaved]() mutable {
                if (watcher->result() && onSaved.isCallable()) {
                    onSaved.call({QJSValue(path)});
                } else if (!watcher->result()) {
                    qCWarning(lcCUtils) << "saveItemToTemp: failed to save selection";
                }
                watcher->deleteLater();
            });
            watcher->setFuture(future);
        });
}

QString CUtils::toLocalFile(const QUrl& url) {
    if (!url.isLocalFile()) {
        qCWarning(lcCUtils) << "toLocalFile: given url is not a local file" << url;
        return QString();
    }

    return url.toLocalFile();
}

qreal CUtils::clamp(qreal value, qreal min, qreal max) {
    return qBound(min, value, max);
}

QString CUtils::enumToString(QObject* target, const QString& property, const QVariant& value) {
    if (!target) {
        qCWarning(lcCUtils) << "enumToString: a target is required";
        return {};
    }

    const auto* meta = target->metaObject();
    const auto index = meta->indexOfProperty(property.toUtf8().constData());
    if (index < 0) {
        qCWarning(lcCUtils) << "enumToString:" << target << "has no property" << property;
        return {};
    }

    const auto prop = meta->property(index);
    const auto metaEnum = prop.isEnumType() ? prop.enumerator() : util::metaEnumFor(prop.metaType());
    if (!metaEnum.isValid() || metaEnum.is64Bit()) {
        qCWarning(lcCUtils) << "enumToString: property" << property << "of" << target << "is not a supported enum";
        return {};
    }

    const auto val = value.isValid() ? value : prop.read(target);
    const auto* key = util::enumKeyFor(metaEnum, val);
    if (!key) {
        qCWarning(lcCUtils, "enumToString: no enumerator of %s::%s has the value %lld", metaEnum.scope(),
            metaEnum.name(), val.toLongLong());
        return {};
    }

    return QString::fromUtf8(key);
}

namespace {

// DFS over the visual item tree (childItems), returning the first descendant matching the predicate. Unlike
// QObject::findChild, this walks parentItem/childItems relationships so it traverses the QML visual hierarchy.
template <typename Predicate> QQuickItem* findChildDfs(QQuickItem* root, Predicate&& match) {
    const auto children = root->childItems();
    for (QQuickItem* const child : children) {
        if (match(child)) {
            return child;
        }
        if (QQuickItem* const found = findChildDfs(child, match)) {
            return found;
        }
    }
    return nullptr;
}

// DFS over the visual item tree, appending every descendant matching the predicate to out.
template <typename Predicate> void findChildrenDfs(QQuickItem* root, Predicate&& match, QList<QQuickItem*>& out) {
    const auto children = root->childItems();
    for (QQuickItem* const child : children) {
        if (match(child)) {
            out.append(child);
        }
        findChildrenDfs(child, match, out);
    }
}

} // namespace

QQuickItem* CUtils::findChild(QQuickItem* root, const QString& name) {
    if (!root) {
        return nullptr;
    }

    return findChildDfs(root, [&name](const QQuickItem* item) {
        return item->objectName() == name;
    });
}

QList<QQuickItem*> CUtils::findChildren(QQuickItem* root, const QString& name) {
    QList<QQuickItem*> children;
    if (root) {
        findChildrenDfs(
            root,
            [&name](const QQuickItem* item) {
                return item->objectName() == name;
            },
            children);
    }
    return children;
}

QList<QQuickItem*> CUtils::findChildrenMatching(QQuickItem* root, const QString& pattern) {
    QList<QQuickItem*> children;
    if (root) {
        const QRegularExpression re(pattern);
        findChildrenDfs(
            root,
            [&re](const QQuickItem* item) {
                return re.match(item->objectName()).hasMatch();
            },
            children);
    }
    return children;
}

#ifndef SLEEPY_VERSION
#define SLEEPY_VERSION ""
#endif

QString CUtils::version() const {
    return QStringLiteral(SLEEPY_VERSION);
}

QString CUtils::qtVersion() const {
    return QStringLiteral(QT_VERSION_STR);
}

} // namespace sleepy
