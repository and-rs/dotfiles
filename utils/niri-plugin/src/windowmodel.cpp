#include "windowmodel.h"

WindowModel::WindowModel(QObject* parent) : QAbstractListModel(parent) {}

int WindowModel::rowCount(const QModelIndex& parent) const {
	if (parent.isValid())
		return 0;

	return m_windows.size();
}

QVariant WindowModel::data(const QModelIndex& index, int role) const {
	if (!index.isValid() || index.row() >= m_windows.size() || role != WindowRole)
		return {};

	return QVariant::fromValue(m_windows.at(index.row()));
}

QHash<int, QByteArray> WindowModel::roleNames() const {
	return {{WindowRole, "window"}};
}

QList<Window*> WindowModel::windows() const {
	return m_windows;
}

Window* WindowModel::findById(qint64 id) const {
	for (Window* window : m_windows) {
		if (window->id() == id)
			return window;
	}

	return nullptr;
}

void WindowModel::reset(const QJsonArray& windows) {
	beginResetModel();
	for (Window* window : m_windows)
		window->deleteLater();
	m_windows.clear();

	for (const QJsonValue& value : windows)
		m_windows.append(createWindow(value.toObject()));

	endResetModel();
}

void WindowModel::upsert(const QJsonObject& json) {
	Window* existing = findById(json.value("id").toInteger(-1));
	if (existing) {
		existing->applyJson(json);
		return;
	}

	const int row = m_windows.size();
	beginInsertRows(QModelIndex(), row, row);
	m_windows.append(createWindow(json));
	endInsertRows();
}

void WindowModel::remove(qint64 id) {
	Window* window = findById(id);
	if (!window)
		return;

	const int row = m_windows.indexOf(window);
	beginRemoveRows(QModelIndex(), row, row);
	m_windows.removeAt(row);
	endRemoveRows();

	window->deleteLater();
}

void WindowModel::setFocusedId(qint64 id) {
	for (Window* window : m_windows)
		window->setFocused(window->id() == id);
}

void WindowModel::setUrgent(qint64 id, bool urgent) {
	Window* window = findById(id);
	if (window)
		window->setUrgent(urgent);
}

void WindowModel::applyLayouts(const QJsonArray& changes) {
	for (const QJsonValue& value : changes) {
		const QJsonArray change = value.toArray();
		if (change.size() < 2)
			continue;

		Window* window = findById(change.at(0).toInteger(-1));
		if (window)
			window->applyLayout(change.at(1).toObject());
	}
}

Window* WindowModel::createWindow(const QJsonObject& json) {
	auto* window = new Window(this);
	window->applyJson(json);
	connect(window, &Window::changed, this, [this, window]() { emitRowChanged(window); });
	return window;
}

void WindowModel::emitRowChanged(Window* window) {
	const int row = m_windows.indexOf(window);
	if (row == -1)
		return;

	emit dataChanged(index(row), index(row));
}
