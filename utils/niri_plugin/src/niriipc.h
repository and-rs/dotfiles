#pragma once

#include <QByteArray>
#include <QJsonObject>
#include <QLocalSocket>
#include <QObject>
#include <QString>
#include <QTimer>

#include <functional>

class NiriIpc : public QObject {
	Q_OBJECT

   public:
	using ReplyHandler = std::function<void(const QJsonObject& reply)>;

	explicit NiriIpc(QObject* parent = nullptr);
	~NiriIpc() override;

	bool isConnected() const;
	void start();
	void sendRequest(const QByteArray& request, ReplyHandler onReply = {});

   signals:
	void connectedChanged(bool connected);
	void eventReceived(const QJsonObject& event);
	void errorOccurred(const QString& message);

   private:
	void handleLine(const QByteArray& line);
	void setConnected(bool connected);
	void scheduleReconnect();

	QLocalSocket m_eventSocket;
	QByteArray m_eventBuffer;
	QTimer m_reconnectTimer;
	bool m_connected = false;
	bool m_awaitingSubscribeReply = false;
	bool m_errorReported = false;
};
