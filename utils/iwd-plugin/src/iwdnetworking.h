#pragma once

#include <QtQmlIntegration/qqmlintegration.h>
#include <QDBusMessage>
#include <QObject>
#include <QString>
#include <QVariantMap>

class IwdNetworking : public QObject {
	Q_OBJECT
	QML_ELEMENT

	Q_PROPERTY(bool active READ isActive WRITE setActive NOTIFY activeChanged)
	Q_PROPERTY(bool iwdRunning READ iwdRunning NOTIFY iwdRunningChanged)
	Q_PROPERTY(QVariantMap snapshot READ snapshot NOTIFY snapshotChanged)

   public:
	explicit IwdNetworking(QObject* parent = nullptr);

	bool isActive() const;
	void setActive(bool active);
	bool iwdRunning() const;
	QVariantMap snapshot() const;

	Q_INVOKABLE void scan();
	Q_INVOKABLE void connectNetwork(const QString& id);
	Q_INVOKABLE void disconnectDevice();
	Q_INVOKABLE void setWifiEnabled(bool enabled);

   signals:
	void activeChanged();
	void iwdRunningChanged();
	void snapshotChanged();
	void operationFinished(const QString& operation, bool ok, const QString& error);

   private slots:
	void onNameOwnerChanged(const QString& name, const QString& oldOwner, const QString& newOwner);
	void onPropertiesChanged(const QString& interface,
	                         const QVariantMap& changed,
	                         const QStringList& invalidated);
	void scheduleRefresh();
	void refresh();

   private:
	void subscribe();
	void unsubscribe();
	void runCall(const QDBusMessage& message, const QString& operation, bool finishOnReply);
	void setSnapshot(const QVariantMap& next);
	bool isKnownNetwork(const QString& id) const;

	bool m_active = false;
	bool m_iwdRunning = false;
	bool m_scanPending = false;
	bool m_refreshQueued = false;
	QString m_stationPath;
	QVariantMap m_snapshot;
};
