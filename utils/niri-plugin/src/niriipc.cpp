#include "niriipc.h"
#include <QJsonDocument>
#include <QJsonParseError>

namespace {

constexpr int ReconnectIntervalMs = 1000;

}

NiriIpc::NiriIpc(QObject* parent) : QObject(parent) {
	m_reconnectTimer.setSingleShot(true);
	m_reconnectTimer.setInterval(ReconnectIntervalMs);
	connect(&m_reconnectTimer, &QTimer::timeout, this, &NiriIpc::start);

	connect(&m_eventSocket, &QLocalSocket::connected, this, [this]() {
		m_eventBuffer.clear();
		m_awaitingSubscribeReply = true;
		m_eventSocket.write("\"EventStream\"\n");
	});

	connect(&m_eventSocket, &QLocalSocket::readyRead, this, [this]() {
		m_eventBuffer.append(m_eventSocket.readAll());

		qsizetype start = 0;
		qsizetype newline = m_eventBuffer.indexOf('\n');
		while (newline != -1) {
			handleLine(m_eventBuffer.mid(start, newline - start));
			start = newline + 1;
			newline = m_eventBuffer.indexOf('\n', start);
		}
		m_eventBuffer.remove(0, start);
	});

	connect(&m_eventSocket, &QLocalSocket::errorOccurred, this, [this]() {
		if (!m_errorReported) {
			m_errorReported = true;
			emit errorOccurred(m_eventSocket.errorString());
		}
		if (!m_connected)
			scheduleReconnect();
	});

	connect(&m_eventSocket, &QLocalSocket::disconnected, this, [this]() {
		setConnected(false);
		scheduleReconnect();
	});
}

bool NiriIpc::isConnected() const {
	return m_connected;
}

void NiriIpc::start() {
	if (m_eventSocket.state() != QLocalSocket::UnconnectedState)
		return;

	const QString path = qEnvironmentVariable("NIRI_SOCKET");
	if (path.isEmpty()) {
		if (!m_errorReported) {
			m_errorReported = true;
			emit errorOccurred(QStringLiteral("NIRI_SOCKET is not set"));
		}
		scheduleReconnect();
		return;
	}

	m_eventSocket.connectToServer(path);
}

void NiriIpc::sendRequest(const QByteArray& request, ReplyHandler onReply) {
	auto* socket = new QLocalSocket(this);
	auto buffer = std::make_shared<QByteArray>();

	connect(socket, &QLocalSocket::connected, socket,
	        [socket, request]() { socket->write(request + "\n"); });

	connect(socket, &QLocalSocket::readyRead, socket, [this, socket, buffer, onReply]() {
		buffer->append(socket->readAll());

		const int newline = buffer->indexOf('\n');
		if (newline == -1)
			return;

		QJsonParseError error;
		const QJsonDocument document = QJsonDocument::fromJson(buffer->left(newline), &error);
		socket->disconnectFromServer();

		if (error.error != QJsonParseError::NoError || !document.isObject()) {
			emit errorOccurred(error.errorString());
			return;
		}

		if (onReply)
			onReply(document.object());
	});

	connect(socket, &QLocalSocket::errorOccurred, socket, [this, socket]() {
		emit errorOccurred(socket->errorString());
		socket->deleteLater();
	});

	connect(socket, &QLocalSocket::disconnected, socket, &QObject::deleteLater);

	socket->connectToServer(qEnvironmentVariable("NIRI_SOCKET"));
}

void NiriIpc::handleLine(const QByteArray& line) {
	if (line.trimmed().isEmpty())
		return;

	QJsonParseError error;
	const QJsonDocument document = QJsonDocument::fromJson(line, &error);
	if (error.error != QJsonParseError::NoError || !document.isObject()) {
		emit errorOccurred(error.errorString());
		if (m_awaitingSubscribeReply) {
			m_awaitingSubscribeReply = false;
			m_eventSocket.disconnectFromServer();
		}
		return;
	}

	if (m_awaitingSubscribeReply) {
		m_awaitingSubscribeReply = false;

		const QJsonObject reply = document.object();
		if (reply.contains("Err")) {
			emit errorOccurred(reply.value("Err").toString());
			m_eventSocket.disconnectFromServer();
			return;
		}

		setConnected(true);
		return;
	}

	emit eventReceived(document.object());
}

void NiriIpc::setConnected(bool connected) {
	if (m_connected == connected)
		return;

	m_connected = connected;
	if (connected)
		m_errorReported = false;
	emit connectedChanged(connected);
}

void NiriIpc::scheduleReconnect() {
	if (!m_reconnectTimer.isActive())
		m_reconnectTimer.start();
}
