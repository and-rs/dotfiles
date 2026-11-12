#pragma once

#include <QtQmlIntegration/qqmlintegration.h>
#include <QAbstractListModel>
#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QList>
#include <QSet>
#include <QString>
#include <QVariant>

struct WorkspaceData {
	qint64 id = -1;
	int index = -1;
	QString name;
	QString output;
	bool isActive = false;
	bool isFocused = false;
	bool isUrgent = false;
	bool isEmpty = true;
	qint64 activeWindowId = -1;
};

class WorkspaceModel : public QAbstractListModel {
	Q_OBJECT
	QML_ELEMENT
	QML_UNCREATABLE("Workspaces are provided by the Niri type")

   public:
	enum Roles {
		IdRole = Qt::UserRole + 1,
		IndexRole,
		NameRole,
		OutputRole,
		IsActiveRole,
		IsFocusedRole,
		IsUrgentRole,
		IsEmptyRole,
		ActiveWindowIdRole,
	};

	explicit WorkspaceModel(QObject* parent = nullptr);

	int rowCount(const QModelIndex& parent = QModelIndex()) const override;
	QVariant data(const QModelIndex& index, int role) const override;
	QHash<int, QByteArray> roleNames() const override;

	qint64 focusedId() const;

	void reset(const QJsonArray& workspaces);
	void activate(qint64 id, bool focused);
	void setActiveWindow(qint64 id, qint64 windowId);
	void setUrgent(qint64 id, bool urgent);
	void setOccupied(const QSet<qint64>& occupied);

   private:
	int rowOf(qint64 id) const;
	void emitRowChanged(int row);

	QList<WorkspaceData> m_workspaces;
};
