#include "niriipc.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QLocalServer>
#include <QTemporaryDir>
#include <QThread>
#include <cstdio>

namespace {
bool check(bool condition, const char* message) {
	if (!condition)
		std::fprintf(stderr, "FAIL: %s\n", message);
	return condition;
}

bool waitFor(const std::function<bool()>& condition, int timeout = 3000) {
	QElapsedTimer elapsed;
	elapsed.start();
	while (!condition() && elapsed.elapsed() < timeout) {
		QCoreApplication::processEvents(QEventLoop::AllEvents, 10);
		QThread::msleep(1);
	}
	return condition();
}

void waitForTimers() {
	QElapsedTimer elapsed;
	elapsed.start();
	waitFor([&]() { return elapsed.elapsed() >= 1200; });
}
}  // namespace

int main(int argc, char** argv) {
	QCoreApplication app(argc, argv);
	QTemporaryDir directory;
	if (!check(directory.isValid(), "temporary socket directory"))
		return 1;

	QLocalServer server;
	const QString socketPath = directory.filePath("niri.sock");
	if (!check(server.listen(socketPath), "listen on fake compositor socket"))
		return 1;
	qputenv("NIRI_SOCKET", socketPath.toUtf8());

	QLocalSocket* peer = nullptr;
	int subscriptions = 0;
	QObject::connect(&server, &QLocalServer::newConnection, &app, [&]() {
		peer = server.nextPendingConnection();
		QObject::connect(peer, &QLocalSocket::readyRead, peer, [&, socket = peer]() {
			if (!socket->canReadLine())
				return;
			if (socket->readLine() == "\"EventStream\"\n") {
				++subscriptions;
				socket->write("{\"Ok\":\"Handled\"}\n");
			}
		});
	});

	bool destroying = false;
	int teardownSignals = 0;
	int events = 0;
	auto* client = new NiriIpc;
	QObject::connect(client, &NiriIpc::connectedChanged, &app, [&]() {
		if (destroying)
			++teardownSignals;
	});
	QObject::connect(client, &NiriIpc::eventReceived, &app, [&](const QJsonObject&) { ++events; });
	client->start();
	if (!check(waitFor([&]() { return client->isConnected(); }), "initial event subscription"))
		return 1;
	peer->write("{\"TestEvent\":{}}\n");
	if (!check(waitFor([&]() { return events == 1; }), "event forwarding"))
		return 1;

	peer->abort();
	if (!check(waitFor([&]() { return !client->isConnected(); }), "remote disconnect"))
		return 1;
	if (!check(waitFor([&]() { return client->isConnected() && subscriptions == 2; }), "reconnect after remote disconnect"))
		return 1;

	destroying = true;
	delete client;
	if (!check(teardownSignals == 0, "connected destruction must not run socket callbacks or schedule reconnect"))
		return 1;
	waitForTimers();
	if (!check(subscriptions == 2, "no reconnect after connected destruction"))
		return 1;

	client = new NiriIpc;
	client->start();
	if (!check(waitFor([&]() { return client->isConnected() && subscriptions == 3; }), "second client subscription"))
		return 1;
	peer->abort();
	if (!check(waitFor([&]() { return !client->isConnected(); }), "second client disconnect"))
		return 1;
	delete client;
	waitForTimers();
	if (!check(subscriptions == 3, "destruction cancels pending reconnect"))
		return 1;

	qputenv("NIRI_SOCKET", directory.filePath("missing.sock").toUtf8());
	client = new NiriIpc;
	int errors = 0;
	QObject::connect(client, &NiriIpc::errorOccurred, &app, [&](const QString&) { ++errors; });
	client->start();
	if (!check(waitFor([&]() { return errors == 1; }), "connection failure is reported"))
		return 1;
	delete client;
	waitForTimers();
	if (!check(errors == 1, "no callbacks after failed-client destruction"))
		return 1;

	std::puts("PASS: subscription, events, reconnect, and connected/pending/failed teardown");
	return 0;
}
