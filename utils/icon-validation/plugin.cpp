#include <qqml.h>

#include <QQmlExtensionPlugin>

#include "iconvalidator.hpp"

class IconValidationPlugin final : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

   public:
    void registerTypes(const char* uri) override {
        Q_ASSERT(QString::fromLatin1(uri) == "IconValidation");
        qmlRegisterType<IconValidator>(uri, 1, 0, "IconValidator");
    }
};

#include "plugin.moc"
