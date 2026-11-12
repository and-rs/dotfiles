#include "window.h"

#include <QJsonArray>

namespace {

QSizeF sizeFrom(const QJsonValue& value) {
	const QJsonArray pair = value.toArray();
	if (pair.size() < 2)
		return {};

	return QSizeF(pair.at(0).toDouble(), pair.at(1).toDouble());
}

}  // namespace

Window::Window(QObject* parent) : QObject(parent) {}

void Window::applyJson(const QJsonObject& json) {
	m_id = json.value("id").toInteger(-1);
	m_title = json.value("title").toString();
	m_appId = json.value("app_id").toString();
	m_workspaceId = json.value("workspace_id").toInteger(-1);
	m_isFocused = json.value("is_focused").toBool();
	m_isFloating = json.value("is_floating").toBool();
	m_isUrgent = json.value("is_urgent").toBool();
	readLayout(json.value("layout").toObject());
	emit changed();
}

void Window::applyLayout(const QJsonObject& layout) {
	readLayout(layout);
	emit changed();
}

void Window::setFocused(bool focused) {
	if (m_isFocused == focused)
		return;

	m_isFocused = focused;
	emit changed();
}

void Window::setUrgent(bool urgent) {
	if (m_isUrgent == urgent)
		return;

	m_isUrgent = urgent;
	emit changed();
}

qint64 Window::id() const {
	return m_id;
}

QString Window::title() const {
	return m_title;
}

QString Window::appId() const {
	return m_appId;
}

qint64 Window::workspaceId() const {
	return m_workspaceId;
}

bool Window::isFocused() const {
	return m_isFocused;
}

bool Window::isFloating() const {
	return m_isFloating;
}

bool Window::isUrgent() const {
	return m_isUrgent;
}

int Window::column() const {
	return m_column;
}

int Window::row() const {
	return m_row;
}

QSizeF Window::tileSize() const {
	return m_tileSize;
}

void Window::readLayout(const QJsonObject& layout) {
	const QJsonArray position = layout.value("pos_in_scrolling_layout").toArray();

	m_column = -1;
	m_row = -1;
	if (position.size() == 2) {
		m_column = position.at(0).toInt(-1);
		m_row = position.at(1).toInt(-1);
	}

	m_tileSize = sizeFrom(layout.value("tile_size"));
}
