#include "iconvalidator.hpp"

#include <QIcon>
#include <QPixmap>
#include <QSize>
#include <QUrlQuery>
#include <algorithm>

namespace {
QString iconId(const QUrl& source) {
    return source.path().sliced(1);
}

QSize requestedSize(int width, int height) {
    return QSize(std::max(width, 2), std::max(height, 2));
}
}  // namespace

IconValidator::IconValidator(QObject* parent) : QObject(parent) {}

bool IconValidator::canValidate(const QUrl& source) const {
    return source.scheme() == "image" && source.host() == "icon" && !iconId(source).isEmpty();
}

bool IconValidator::isValid(const QUrl& source, int width, int height) {
    if (!canValidate(source))
        return true;

    const QSize size = requestedSize(width, height);
    const QString cacheKey = QStringLiteral("%1:%2x%3")
                                 .arg(source.toString(QUrl::FullyEncoded))
                                 .arg(size.width())
                                 .arg(size.height());
    const auto cached = cache.constFind(cacheKey);
    if (cached != cache.cend())
        return *cached;

    const QUrlQuery query(source);
    const QString name = iconId(source);
    QIcon icon = QIcon::fromTheme(name);

    // Keep the fallback precedence identical to Quickshell's IconImageProvider.
    if (icon.isNull() && query.hasQueryItem("fallback")) {
        icon = QIcon::fromTheme(query.queryItemValue("fallback"));
    } else if (icon.isNull() && query.hasQueryItem("path")) {
        const QString path = query.queryItemValue("path");
        const QString fileName = name.sliced(name.lastIndexOf('/') + 1);
        icon = QIcon(path + '/' + fileName);
    }

    const bool valid = !icon.pixmap(size).isNull();
    cache.insert(cacheKey, valid);
    return valid;
}

void IconValidator::clearCache() {
    cache.clear();
}
