#include "niri.h"

#include <QJsonDocument>
#include <QJsonValue>
#include <QMap>
#include <QSet>
#include <QTimer>
#include <QVariantMap>

#include <algorithm>
#include <cmath>

namespace {
constexpr int ColumnGap = 2;
constexpr int TileGap = 1;
constexpr int MinColumnWidth = 8;

double sourceTileHeight(const Window* window) {
	if (window->tileSize().height() > 0)
		return window->tileSize().height();

	return 1;
}

double sourceColumnWidth(const QList<Window*>& column) {
	double width = 1;
	for (const Window* window : column)
		width = qMax(width, window->tileSize().width());

	return width;
}

double sourceColumnHeight(const QList<Window*>& column) {
	double total = 0;
	for (const Window* window : column)
		total += sourceTileHeight(window);

	return qMax(1.0, total);
}

QList<int> tileHeights(const QList<Window*>& column, int mapHeight) {
	QList<int> heights;
	const int count = column.size();
	if (count == 0)
		return heights;

	const int available = qMax(count, mapHeight - TileGap * (count - 1));
	const double total = sourceColumnHeight(column);
	QList<double> fractions;
	int used = 0;

	for (const Window* window : column) {
		const double raw = available * sourceTileHeight(window) / total;
		const int height = qMax(1, static_cast<int>(std::floor(raw)));
		heights.append(height);
		fractions.append(raw - std::floor(raw));
		used += height;
	}

	while (used < available) {
		int index = 0;
		for (int i = 1; i < fractions.size(); ++i) {
			if (fractions.at(i) > fractions.at(index))
				index = i;
		}

		heights[index]++;
		fractions[index] = 0;
		used++;
	}

	while (used > available) {
		int index = -1;
		for (int i = 0; i < heights.size(); ++i) {
			if (heights.at(i) > 1 && (index == -1 || fractions.at(i) < fractions.at(index)))
				index = i;
		}

		if (index == -1)
			break;

		heights[index]--;
		used--;
	}

	return heights;
}

QVariantList miniTiles(const QList<Window*>& column, int mapHeight) {
	const QList<int> heights = tileHeights(column, mapHeight);

	int columnHeight = 0;
	for (int height : heights)
		columnHeight += height;
	columnHeight += TileGap * qMax(0, static_cast<int>(heights.size()) - 1);

	int y = qRound((mapHeight - columnHeight) / 2.0);
	QVariantList tiles;
	for (int i = 0; i < column.size(); ++i) {
		tiles.append(QVariantMap{
		    {"windowId", column.at(i)->id()},
		    {"focused", column.at(i)->isFocused()},
		    {"y", y},
		    {"height", heights.at(i)},
		});
		y += heights.at(i) + TileGap;
	}

	return tiles;
}

}  // namespace

Niri::Niri(QObject* parent)
    : QObject(parent),
      m_ipc(new NiriIpc(this)),
      m_windows(new WindowModel(this)),
      m_workspaces(new WorkspaceModel(this)) {
	connect(m_ipc, &NiriIpc::connectedChanged, this, [this]() { emit connectedChanged(); });
	connect(m_ipc, &NiriIpc::eventReceived, this, &Niri::handleEvent);
	connect(m_ipc, &NiriIpc::errorOccurred, this, &Niri::errorOccurred);

	watchModel(m_windows);
	watchModel(m_workspaces);

	m_ipc->start();
}

bool Niri::isConnected() const {
	return m_ipc->isConnected();
}

WindowModel* Niri::windows() const {
	return m_windows;
}

WorkspaceModel* Niri::workspaces() const {
	return m_workspaces;
}

Window* Niri::focusedWindow() const {
	return m_focusedWindow.data();
}

qint64 Niri::focusedWorkspaceId() const {
	return m_focusedWorkspaceId;
}

int Niri::miniMapHeight() const {
	return m_miniMapHeight;
}

void Niri::setMiniMapHeight(int height) {
	if (m_miniMapHeight == height)
		return;

	m_miniMapHeight = height;
	emit miniMapHeightChanged();
	scheduleRefresh();
}

QVariantList Niri::miniMapColumns() const {
	return m_miniMapColumns;
}

int Niri::miniMapWidth() const {
	return m_miniMapWidth;
}

void Niri::focusWindow(qint64 id) {
	sendAction(QJsonObject{{"FocusWindow", QJsonObject{{"id", id}}}});
}

void Niri::focusWorkspace(int index) {
	sendAction(
	    QJsonObject{{"FocusWorkspace", QJsonObject{{"reference", QJsonObject{{"Index", index}}}}}});
}

void Niri::focusWorkspaceById(qint64 id) {
	sendAction(
	    QJsonObject{{"FocusWorkspace", QJsonObject{{"reference", QJsonObject{{"Id", id}}}}}});
}

void Niri::focusWorkspaceByName(const QString& name) {
	sendAction(
	    QJsonObject{{"FocusWorkspace", QJsonObject{{"reference", QJsonObject{{"Name", name}}}}}});
}

void Niri::closeWindow(qint64 id) {
	QJsonValue idValue(QJsonValue::Null);
	if (id >= 0)
		idValue = id;

	sendAction(QJsonObject{{"CloseWindow", QJsonObject{{"id", idValue}}}});
}

void Niri::sendAction(const QJsonObject& action) {
	const QJsonObject request{{"Action", action}};
	m_ipc->sendRequest(QJsonDocument(request).toJson(QJsonDocument::Compact),
	                   [this](const QJsonObject& reply) {
		                   if (reply.contains("Err"))
			                   emit errorOccurred(reply.value("Err").toString());
	                   });
}

void Niri::handleEvent(const QJsonObject& event) {
	if (event.isEmpty())
		return;

	const QString type = event.begin().key();
	const QJsonObject body = event.begin().value().toObject();

	if (type == "WorkspacesChanged") {
		m_workspaces->reset(body.value("workspaces").toArray());
	} else if (type == "WorkspaceActivated") {
		m_workspaces->activate(body.value("id").toInteger(-1), body.value("focused").toBool());
	} else if (type == "WorkspaceActiveWindowChanged") {
		m_workspaces->setActiveWindow(body.value("workspace_id").toInteger(-1),
		                              body.value("active_window_id").toInteger(-1));
	} else if (type == "WorkspaceUrgencyChanged") {
		m_workspaces->setUrgent(body.value("id").toInteger(-1), body.value("urgent").toBool());
	} else if (type == "WindowsChanged") {
		m_windows->reset(body.value("windows").toArray());
	} else if (type == "WindowOpenedOrChanged") {
		m_windows->upsert(body.value("window").toObject());
	} else if (type == "WindowClosed") {
		m_windows->remove(body.value("id").toInteger(-1));
	} else if (type == "WindowFocusChanged") {
		m_windows->setFocusedId(body.value("id").toInteger(-1));
	} else if (type == "WindowLayoutsChanged") {
		m_windows->applyLayouts(body.value("changes").toArray());
	} else if (type == "WindowUrgencyChanged") {
		m_windows->setUrgent(body.value("id").toInteger(-1), body.value("urgent").toBool());
	}
}

void Niri::watchModel(const QAbstractItemModel* model) {
	connect(model, &QAbstractItemModel::dataChanged, this, &Niri::scheduleRefresh);
	connect(model, &QAbstractItemModel::rowsInserted, this, &Niri::scheduleRefresh);
	connect(model, &QAbstractItemModel::rowsRemoved, this, &Niri::scheduleRefresh);
	connect(model, &QAbstractItemModel::modelReset, this, &Niri::scheduleRefresh);
}

void Niri::scheduleRefresh() {
	if (m_refreshQueued)
		return;

	m_refreshQueued = true;
	QTimer::singleShot(0, this, [this]() {
		m_refreshQueued = false;
		refresh();
	});
}

void Niri::refresh() {
	updateFocusedWindow();
	updateFocusedWorkspace();

	QSet<qint64> occupied;
	for (const Window* window : m_windows->windows())
		occupied.insert(window->workspaceId());
	m_workspaces->setOccupied(occupied);

	updateMiniMap();
}

void Niri::updateFocusedWindow() {
	Window* focused = nullptr;
	for (Window* window : m_windows->windows()) {
		if (window->isFocused()) {
			focused = window;
			break;
		}
	}

	if (m_focusedWindow.data() == focused)
		return;

	m_focusedWindow = focused;
	emit focusedWindowChanged();
}

void Niri::updateFocusedWorkspace() {
	const qint64 focusedId = m_workspaces->focusedId();
	if (focusedId == -1 || focusedId == m_focusedWorkspaceId)
		return;

	m_focusedWorkspaceId = focusedId;
	emit focusedWorkspaceIdChanged();
}

void Niri::updateMiniMap() {
	QMap<int, QList<Window*>> columnMap;
	for (Window* window : m_windows->windows()) {
		if (window->workspaceId() != m_focusedWorkspaceId || window->isFloating() ||
		    window->column() < 0)
			continue;

		columnMap[window->column()].append(window);
	}

	QList<QList<Window*>> columns;
	for (auto it = columnMap.cbegin(); it != columnMap.cend(); ++it) {
		QList<Window*> tiles = it.value();
		std::sort(tiles.begin(), tiles.end(),
		          [](const Window* a, const Window* b) { return a->row() < b->row(); });
		columns.append(tiles);
	}

	double layoutHeight = 1;
	for (const QList<Window*>& column : columns)
		layoutHeight = qMax(layoutHeight, sourceColumnHeight(column));

	const double scale = m_miniMapHeight / layoutHeight;
	QVariantList miniColumns;
	int x = 0;
	for (const QList<Window*>& column : columns) {
		const int width = qMax(MinColumnWidth, qRound(sourceColumnWidth(column) * scale));
		miniColumns.append(QVariantMap{
		    {"x", x},
		    {"width", width},
		    {"tiles", miniTiles(column, m_miniMapHeight)},
		});
		x += width + ColumnGap;
	}

	int totalWidth = 0;
	if (!miniColumns.isEmpty())
		totalWidth = x - ColumnGap;

	if (miniColumns == m_miniMapColumns && totalWidth == m_miniMapWidth)
		return;

	m_miniMapColumns = miniColumns;
	m_miniMapWidth = totalWidth;
	emit miniMapChanged();
}
