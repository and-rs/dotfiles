#include "workspacemodel.h"

#include <algorithm>

WorkspaceModel::WorkspaceModel(QObject* parent) : QAbstractListModel(parent) {}

int WorkspaceModel::rowCount(const QModelIndex& parent) const {
	if (parent.isValid())
		return 0;

	return m_workspaces.size();
}

QVariant WorkspaceModel::data(const QModelIndex& index, int role) const {
	if (!index.isValid() || index.row() >= m_workspaces.size())
		return {};

	const WorkspaceData& workspace = m_workspaces.at(index.row());
	switch (role) {
		case IdRole:
			return workspace.id;
		case IndexRole:
			return workspace.index;
		case NameRole:
			return workspace.name;
		case OutputRole:
			return workspace.output;
		case IsActiveRole:
			return workspace.isActive;
		case IsFocusedRole:
			return workspace.isFocused;
		case IsUrgentRole:
			return workspace.isUrgent;
		case IsEmptyRole:
			return workspace.isEmpty;
		case ActiveWindowIdRole:
			return workspace.activeWindowId;
	}

	return {};
}

QHash<int, QByteArray> WorkspaceModel::roleNames() const {
	return {
	    {IdRole, "id"},
	    {IndexRole, "index"},
	    {NameRole, "name"},
	    {OutputRole, "output"},
	    {IsActiveRole, "isActive"},
	    {IsFocusedRole, "isFocused"},
	    {IsUrgentRole, "isUrgent"},
	    {IsEmptyRole, "isEmpty"},
	    {ActiveWindowIdRole, "activeWindowId"},
	};
}

qint64 WorkspaceModel::focusedId() const {
	for (const WorkspaceData& workspace : m_workspaces) {
		if (workspace.isFocused)
			return workspace.id;
	}

	return -1;
}

void WorkspaceModel::reset(const QJsonArray& workspaces) {
	QList<WorkspaceData> next;
	for (const QJsonValue& value : workspaces) {
		const QJsonObject json = value.toObject();

		WorkspaceData workspace;
		workspace.id = json.value("id").toInteger(-1);
		workspace.index = json.value("idx").toInt(-1);
		workspace.name = json.value("name").toString();
		workspace.output = json.value("output").toString();
		workspace.isActive = json.value("is_active").toBool();
		workspace.isFocused = json.value("is_focused").toBool();
		workspace.isUrgent = json.value("is_urgent").toBool();
		workspace.activeWindowId = json.value("active_window_id").toInteger(-1);

		const int previous = rowOf(workspace.id);
		if (previous != -1)
			workspace.isEmpty = m_workspaces.at(previous).isEmpty;

		next.append(workspace);
	}

	std::sort(next.begin(), next.end(), [](const WorkspaceData& a, const WorkspaceData& b) {
		if (a.output != b.output)
			return a.output < b.output;

		return a.index < b.index;
	});

	beginResetModel();
	m_workspaces = next;
	endResetModel();
}

void WorkspaceModel::activate(qint64 id, bool focused) {
	const int row = rowOf(id);
	if (row == -1)
		return;

	const QString output = m_workspaces.at(row).output;
	for (int i = 0; i < m_workspaces.size(); ++i) {
		WorkspaceData& workspace = m_workspaces[i];
		const bool wasActive = workspace.isActive;
		const bool wasFocused = workspace.isFocused;

		if (workspace.output == output)
			workspace.isActive = workspace.id == id;

		if (focused)
			workspace.isFocused = workspace.id == id;

		if (workspace.isActive != wasActive || workspace.isFocused != wasFocused)
			emitRowChanged(i);
	}
}

void WorkspaceModel::setActiveWindow(qint64 id, qint64 windowId) {
	const int row = rowOf(id);
	if (row == -1 || m_workspaces[row].activeWindowId == windowId)
		return;

	m_workspaces[row].activeWindowId = windowId;
	emitRowChanged(row);
}

void WorkspaceModel::setUrgent(qint64 id, bool urgent) {
	const int row = rowOf(id);
	if (row == -1 || m_workspaces[row].isUrgent == urgent)
		return;

	m_workspaces[row].isUrgent = urgent;
	emitRowChanged(row);
}

void WorkspaceModel::setOccupied(const QSet<qint64>& occupied) {
	for (int row = 0; row < m_workspaces.size(); ++row) {
		const bool empty = !occupied.contains(m_workspaces.at(row).id);
		if (m_workspaces.at(row).isEmpty == empty)
			continue;

		m_workspaces[row].isEmpty = empty;
		emitRowChanged(row);
	}
}

int WorkspaceModel::rowOf(qint64 id) const {
	for (int row = 0; row < m_workspaces.size(); ++row) {
		if (m_workspaces.at(row).id == id)
			return row;
	}

	return -1;
}

void WorkspaceModel::emitRowChanged(int row) {
	emit dataChanged(index(row), index(row));
}
