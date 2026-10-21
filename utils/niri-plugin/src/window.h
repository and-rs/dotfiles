#pragma once

#include <QtQmlIntegration/qqmlintegration.h>
#include <QJsonObject>
#include <QObject>
#include <QSizeF>
#include <QString>

class Window : public QObject {
	Q_OBJECT
	QML_ELEMENT
	QML_UNCREATABLE("Windows are provided by the Niri type")

	Q_PROPERTY(qint64 id READ id NOTIFY changed)
	Q_PROPERTY(QString title READ title NOTIFY changed)
	Q_PROPERTY(QString appId READ appId NOTIFY changed)
	Q_PROPERTY(qint64 workspaceId READ workspaceId NOTIFY changed)
	Q_PROPERTY(bool isFocused READ isFocused NOTIFY changed)
	Q_PROPERTY(bool isFloating READ isFloating NOTIFY changed)
	Q_PROPERTY(bool isUrgent READ isUrgent NOTIFY changed)
	Q_PROPERTY(int column READ column NOTIFY changed)
	Q_PROPERTY(int row READ row NOTIFY changed)
	Q_PROPERTY(QSizeF tileSize READ tileSize NOTIFY changed)

   public:
	explicit Window(QObject* parent = nullptr);

	void applyJson(const QJsonObject& json);
	void applyLayout(const QJsonObject& layout);
	void setFocused(bool focused);
	void setUrgent(bool urgent);

	qint64 id() const;
	QString title() const;
	QString appId() const;
	qint64 workspaceId() const;
	bool isFocused() const;
	bool isFloating() const;
	bool isUrgent() const;
	int column() const;
	int row() const;
	QSizeF tileSize() const;

   signals:
	void changed();

   private:
	void readLayout(const QJsonObject& layout);

	qint64 m_id = -1;
	QString m_title;
	QString m_appId;
	qint64 m_workspaceId = -1;
	bool m_isFocused = false;
	bool m_isFloating = false;
	bool m_isUrgent = false;
	int m_column = -1;
	int m_row = -1;
	QSizeF m_tileSize;
};
