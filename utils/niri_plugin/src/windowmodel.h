#pragma once

#include "window.h"

#include <QtQmlIntegration/qqmlintegration.h>
#include <QAbstractListModel>
#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QList>
#include <QVariant>

class WindowModel : public QAbstractListModel {
	Q_OBJECT
	QML_ELEMENT
	QML_UNCREATABLE("Windows are provided by the Niri type")

   public:
	enum Roles {
		WindowRole = Qt::UserRole + 1,
	};

	explicit WindowModel(QObject* parent = nullptr);

	int rowCount(const QModelIndex& parent = QModelIndex()) const override;
	QVariant data(const QModelIndex& index, int role) const override;
	QHash<int, QByteArray> roleNames() const override;

	QList<Window*> windows() const;
	Window* findById(qint64 id) const;

	void reset(const QJsonArray& windows);
	void upsert(const QJsonObject& json);
	void remove(qint64 id);
	void setFocusedId(qint64 id);
	void setUrgent(qint64 id, bool urgent);
	void applyLayouts(const QJsonArray& changes);

   private:
	Window* createWindow(const QJsonObject& json);
	void emitRowChanged(Window* window);

	QList<Window*> m_windows;
};
