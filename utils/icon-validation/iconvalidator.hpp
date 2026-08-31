#pragma once

#include <QHash>
#include <QObject>
#include <QUrl>

class IconValidator : public QObject {
    Q_OBJECT

   public:
    explicit IconValidator(QObject* parent = nullptr);

    Q_INVOKABLE bool canValidate(const QUrl& source) const;
    Q_INVOKABLE bool isValid(const QUrl& source, int width, int height);
    Q_INVOKABLE void clearCache();

   private:
    QHash<QString, bool> cache;
};
