#pragma once

#include "niriipc.h"
#include "windowmodel.h"
#include "workspacemodel.h"

#include <QtQmlIntegration/qqmlintegration.h>
#include <QAbstractItemModel>
#include <QJsonObject>
#include <QPointer>

#include <QVariantList>

class Niri : public QObject {
	Q_OBJECT
	QML_ELEMENT

	Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
	Q_PROPERTY(WindowModel* windows READ windows CONSTANT)
	Q_PROPERTY(WorkspaceModel* workspaces READ workspaces CONSTANT)
	Q_PROPERTY(Window* focusedWindow READ focusedWindow NOTIFY focusedWindowChanged)
	Q_PROPERTY(qint64 focusedWorkspaceId READ focusedWorkspaceId NOTIFY focusedWorkspaceIdChanged)
	Q_PROPERTY(
	    int miniMapHeight READ miniMapHeight WRITE setMiniMapHeight NOTIFY miniMapHeightChanged)
	Q_PROPERTY(QVariantList miniMapColumns READ miniMapColumns NOTIFY miniMapChanged)
	Q_PROPERTY(int miniMapWidth READ miniMapWidth NOTIFY miniMapChanged)

   public:
	explicit Niri(QObject* parent = nullptr);

	bool isConnected() const;
	WindowModel* windows() const;
	WorkspaceModel* workspaces() const;
	Window* focusedWindow() const;
	qint64 focusedWorkspaceId() const;
	int miniMapHeight() const;
	void setMiniMapHeight(int height);
	QVariantList miniMapColumns() const;
	int miniMapWidth() const;

	Q_INVOKABLE void focusWindow(qint64 id);
	Q_INVOKABLE void focusWorkspace(int index);
	Q_INVOKABLE void focusWorkspaceById(qint64 id);
	Q_INVOKABLE void focusWorkspaceByName(const QString& name);
	Q_INVOKABLE void closeWindow(qint64 id);

   signals:
	void connectedChanged();
	void focusedWindowChanged();
	void focusedWorkspaceIdChanged();
	void miniMapHeightChanged();
	void miniMapChanged();
	void errorOccurred(const QString& message);

   private:
	void handleEvent(const QJsonObject& event);
	void sendAction(const QJsonObject& action);
	void watchModel(const QAbstractItemModel* model);
	void scheduleRefresh();
	void refresh();
	void updateFocusedWindow();
	void updateFocusedWorkspace();
	void updateMiniMap();

	NiriIpc* m_ipc;
	WindowModel* m_windows;
	WorkspaceModel* m_workspaces;
	QPointer<Window> m_focusedWindow;
	qint64 m_focusedWorkspaceId = -1;
	int m_miniMapHeight = 0;
	QVariantList m_miniMapColumns;
	int m_miniMapWidth = 0;
	bool m_refreshQueued = false;
};
