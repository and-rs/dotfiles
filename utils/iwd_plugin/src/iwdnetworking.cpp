#include "iwdnetworking.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusError>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusReply>
#include <QDBusVariant>
#include <QDir>
#include <QFile>
#include <QList>
#include <QMap>
#include <QNetworkAddressEntry>
#include <QNetworkInterface>
#include <QTimer>
#include <QVariantList>

#include <algorithm>

namespace {

const QString IwdService = QStringLiteral("net.connman.iwd");
const QString ObjectManagerInterface = QStringLiteral("org.freedesktop.DBus.ObjectManager");
const QString PropertiesInterface = QStringLiteral("org.freedesktop.DBus.Properties");
const QString DeviceInterface = QStringLiteral("net.connman.iwd.Device");
const QString StationInterface = QStringLiteral("net.connman.iwd.Station");
const QString NetworkInterface = QStringLiteral("net.connman.iwd.Network");
const QString SystemBusName = QStringLiteral("org.freedesktop.DBus");
const QString SystemBusPath = QStringLiteral("/org/freedesktop/DBus");
const QString RootPath = QStringLiteral("/");
const QString NoPath = QStringLiteral("/");
const qint16 NoSignal = -10000;
const int CallTimeoutMs = 500;

using InterfaceMap = QMap<QString, QVariantMap>;
using ObjectMap = QMap<QString, InterfaceMap>;

struct OrderedNetwork {
	QString path;
	qint16 strength = NoSignal;
};

QDBusMessage createCall(const QString& path,
                        const QString& interface,
                        const QString& method,
                        const QVariantList& arguments = {}) {
	QDBusMessage message = QDBusMessage::createMethodCall(IwdService, path, interface, method);
	message.setArguments(arguments);
	return message;
}

QString pathOf(const QVariant& value) {
	if (value.typeId() == qMetaTypeId<QDBusObjectPath>())
		return value.value<QDBusObjectPath>().path();

	return value.toString();
}

bool isRealPath(const QString& path) {
	return !path.isEmpty() && path != NoPath;
}

QString readText(const QString& path) {
	QFile file(path);
	if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
		return {};

	return QString::fromUtf8(file.readAll()).trimmed();
}

double signalFromStrength(qint16 strength) {
	const double dbm = strength / 100.0;
	return std::clamp((dbm + 90.0) / 60.0, 0.0, 1.0);
}

ObjectMap readManagedObjects(QDBusArgument arg) {
	ObjectMap objects;
	arg.beginMap();
	while (!arg.atEnd()) {
		arg.beginMapEntry();
		QDBusObjectPath path;
		arg >> path;

		InterfaceMap interfaces;
		arg.beginMap();
		while (!arg.atEnd()) {
			arg.beginMapEntry();
			QString interface;
			QVariantMap properties;
			arg >> interface >> properties;
			arg.endMapEntry();
			interfaces.insert(interface, properties);
		}
		arg.endMap();
		arg.endMapEntry();

		objects.insert(path.path(), interfaces);
	}
	arg.endMap();
	return objects;
}

QList<OrderedNetwork> readOrderedNetworks(QDBusArgument arg) {
	QList<OrderedNetwork> networks;
	arg.beginArray();
	while (!arg.atEnd()) {
		QDBusObjectPath path;
		OrderedNetwork entry;
		arg.beginStructure();
		arg >> path >> entry.strength;
		arg.endStructure();
		entry.path = path.path();
		networks.append(entry);
	}
	arg.endArray();
	return networks;
}

ObjectMap fetchManagedObjects() {
	const QDBusMessage reply = QDBusConnection::systemBus().call(
	    createCall(RootPath, ObjectManagerInterface, QStringLiteral("GetManagedObjects")),
	    QDBus::Block, CallTimeoutMs);
	if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
		return {};

	return readManagedObjects(reply.arguments().constFirst().value<QDBusArgument>());
}

QList<OrderedNetwork> fetchOrderedNetworks(const QString& station) {
	const QDBusMessage reply = QDBusConnection::systemBus().call(
	    createCall(station, StationInterface, QStringLiteral("GetOrderedNetworks")), QDBus::Block,
	    CallTimeoutMs);
	if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
		return {};

	return readOrderedNetworks(reply.arguments().constFirst().value<QDBusArgument>());
}

QString findStation(const ObjectMap& objects) {
	for (auto it = objects.cbegin(); it != objects.cend(); ++it) {
		if (it.value().contains(StationInterface))
			return it.key();
	}

	return {};
}

bool hasIpv4(const QString& interfaceName) {
	const QNetworkInterface iface = QNetworkInterface::interfaceFromName(interfaceName);
	for (const QNetworkAddressEntry& entry : iface.addressEntries()) {
		if (entry.ip().protocol() == QAbstractSocket::IPv4Protocol && !entry.ip().isLoopback())
			return true;
	}

	return false;
}

QVariant wiredDevice() {
	const QString root = QStringLiteral("/sys/class/net/");
	QString chosen;
	bool chosenCarrier = false;

	for (const QString& name : QDir(root).entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
		if (name == QStringLiteral("lo"))
			continue;

		const QString base = root + name;
		if (QDir(base + QStringLiteral("/wireless")).exists())
			continue;
		if (readText(base + QStringLiteral("/type")) != QStringLiteral("1"))
			continue;

		const bool carrier = readText(base + QStringLiteral("/carrier")) == QStringLiteral("1");
		if (chosen.isEmpty() || (carrier && !chosenCarrier)) {
			chosen = name;
			chosenCarrier = carrier;
		}
	}

	if (chosen.isEmpty())
		return {};

	const QString base = root + chosen;
	const int speed = readText(base + QStringLiteral("/speed")).toInt();
	QVariantMap device;
	device.insert(QStringLiteral("name"), chosen);
	device.insert(QStringLiteral("type"), QStringLiteral("wired"));
	device.insert(QStringLiteral("state"), readText(base + QStringLiteral("/operstate")));
	device.insert(QStringLiteral("address"), readText(base + QStringLiteral("/address")));
	device.insert(QStringLiteral("hasLink"), chosenCarrier);
	device.insert(QStringLiteral("linkSpeed"), std::max(0, speed));
	device.insert(QStringLiteral("network"), QVariant());
	return device;
}

QVariantMap networkRow(const ObjectMap& objects,
                       const QString& path,
                       qint16 strength,
                       bool connected) {
	const QVariantMap properties = objects.value(path).value(NetworkInterface);
	const QString knownPath = pathOf(properties.value(QStringLiteral("KnownNetwork")));

	QVariantMap row;
	row.insert(QStringLiteral("id"), path);
	row.insert(QStringLiteral("name"), properties.value(QStringLiteral("Name")).toString());
	row.insert(QStringLiteral("connected"), connected);
	row.insert(QStringLiteral("known"), isRealPath(knownPath));
	row.insert(QStringLiteral("security"), properties.value(QStringLiteral("Type")).toString());
	row.insert(QStringLiteral("signalStrength"), signalFromStrength(strength));
	row.insert(QStringLiteral("bssid"), QString());
	return row;
}

QVariantMap buildSnapshot(bool available,
                          const ObjectMap& objects,
                          const QString& station,
                          const QList<OrderedNetwork>& ordered) {
	QVariantMap snapshot;
	snapshot.insert(QStringLiteral("backend"), QStringLiteral("iwd"));
	snapshot.insert(QStringLiteral("available"), available);
	snapshot.insert(QStringLiteral("connectivity"), QStringLiteral("Unknown"));
	snapshot.insert(QStringLiteral("wifiEnabled"), false);
	snapshot.insert(QStringLiteral("wifiDevice"), QVariant());
	snapshot.insert(QStringLiteral("wiredDevice"), wiredDevice());
	snapshot.insert(QStringLiteral("connectedNetwork"), QVariant());
	snapshot.insert(QStringLiteral("wifiNetworks"), QVariantList());

	if (station.isEmpty())
		return snapshot;

	const QVariantMap deviceProperties = objects.value(station).value(DeviceInterface);
	const QVariantMap stationProperties = objects.value(station).value(StationInterface);
	const QString name = deviceProperties.value(QStringLiteral("Name")).toString();
	const QString connectedPath =
	    pathOf(stationProperties.value(QStringLiteral("ConnectedNetwork")));
	const bool connected = isRealPath(connectedPath);

	QMap<QString, qint16> strengths;
	for (const OrderedNetwork& entry : ordered)
		strengths.insert(entry.path, entry.strength);

	QVariantList networks;
	for (const OrderedNetwork& entry : ordered) {
		if (!objects.value(entry.path).contains(NetworkInterface))
			continue;

		networks.append(
		    networkRow(objects, entry.path, entry.strength, entry.path == connectedPath));
	}

	QVariant connectedNetwork;
	if (connected && objects.value(connectedPath).contains(NetworkInterface))
		connectedNetwork =
		    networkRow(objects, connectedPath, strengths.value(connectedPath, NoSignal), true);

	QString connectivity = QStringLiteral("None");
	if (connected && hasIpv4(name))
		connectivity = QStringLiteral("Full");
	else if (connected)
		connectivity = QStringLiteral("Local");

	QVariantMap wifi;
	wifi.insert(QStringLiteral("name"), name);
	wifi.insert(QStringLiteral("type"), QStringLiteral("wifi"));
	wifi.insert(QStringLiteral("state"),
	            stationProperties.value(QStringLiteral("State")).toString());
	wifi.insert(QStringLiteral("address"),
	            deviceProperties.value(QStringLiteral("Address")).toString());
	wifi.insert(QStringLiteral("hasLink"), connected);
	wifi.insert(QStringLiteral("linkSpeed"), 0);
	wifi.insert(QStringLiteral("network"), connectedNetwork);

	snapshot.insert(QStringLiteral("connectivity"), connectivity);
	snapshot.insert(QStringLiteral("wifiEnabled"),
	                deviceProperties.value(QStringLiteral("Powered")).toBool());
	snapshot.insert(QStringLiteral("wifiDevice"), wifi);
	snapshot.insert(QStringLiteral("connectedNetwork"), connectedNetwork);
	snapshot.insert(QStringLiteral("wifiNetworks"), networks);
	return snapshot;
}

}  // namespace

IwdNetworking::IwdNetworking(QObject* parent) : QObject(parent) {
	m_iwdRunning =
	    QDBusConnection::systemBus().interface()->isServiceRegistered(IwdService).value();

	QDBusConnection::systemBus().connect(SystemBusName, SystemBusPath, SystemBusName,
	                                     QStringLiteral("NameOwnerChanged"), this,
	                                     SLOT(onNameOwnerChanged(QString, QString, QString)));
}

bool IwdNetworking::isActive() const {
	return m_active;
}

void IwdNetworking::setActive(bool active) {
	if (m_active == active)
		return;

	m_active = active;
	if (m_active) {
		subscribe();
		scheduleRefresh();
	} else {
		unsubscribe();
	}
	emit activeChanged();
}

bool IwdNetworking::iwdRunning() const {
	return m_iwdRunning;
}

QVariantMap IwdNetworking::snapshot() const {
	return m_snapshot;
}

void IwdNetworking::scan() {
	if (m_stationPath.isEmpty()) {
		emit operationFinished(QStringLiteral("scan"), false, QStringLiteral("No Wi-Fi device"));
		return;
	}

	m_scanPending = true;
	runCall(createCall(m_stationPath, StationInterface, QStringLiteral("Scan")),
	        QStringLiteral("scan"), false);
}

void IwdNetworking::connectNetwork(const QString& id) {
	if (!isKnownNetwork(id)) {
		emit operationFinished(QStringLiteral("connect"), false,
		                       QStringLiteral("Network is not saved"));
		return;
	}

	runCall(createCall(id, NetworkInterface, QStringLiteral("Connect")), QStringLiteral("connect"),
	        true);
}

void IwdNetworking::disconnectDevice() {
	if (m_stationPath.isEmpty()) {
		emit operationFinished(QStringLiteral("disconnect"), false,
		                       QStringLiteral("No Wi-Fi device"));
		return;
	}

	runCall(createCall(m_stationPath, StationInterface, QStringLiteral("Disconnect")),
	        QStringLiteral("disconnect"), true);
}

void IwdNetworking::setWifiEnabled(bool enabled) {
	if (m_stationPath.isEmpty()) {
		emit operationFinished(QStringLiteral("wifi"), false, QStringLiteral("No Wi-Fi device"));
		return;
	}

	const QVariantList arguments{DeviceInterface, QStringLiteral("Powered"),
	                             QVariant::fromValue(QDBusVariant(enabled))};
	runCall(createCall(m_stationPath, PropertiesInterface, QStringLiteral("Set"), arguments),
	        QStringLiteral("wifi"), true);
}

void IwdNetworking::onNameOwnerChanged(const QString& name,
                                       const QString& oldOwner,
                                       const QString& newOwner) {
	Q_UNUSED(oldOwner);
	if (name != IwdService)
		return;

	const bool running = !newOwner.isEmpty();
	if (m_iwdRunning != running) {
		m_iwdRunning = running;
		emit iwdRunningChanged();
	}

	scheduleRefresh();
}

void IwdNetworking::onPropertiesChanged(const QString& interface,
                                        const QVariantMap& changed,
                                        const QStringList& invalidated) {
	Q_UNUSED(invalidated);
	if (interface == StationInterface && m_scanPending &&
	    changed.contains(QStringLiteral("Scanning")) &&
	    !changed.value(QStringLiteral("Scanning")).toBool()) {
		m_scanPending = false;
		emit operationFinished(QStringLiteral("scan"), true, QString());
	}

	scheduleRefresh();
}

void IwdNetworking::scheduleRefresh() {
	if (m_refreshQueued || !m_active)
		return;

	m_refreshQueued = true;
	QTimer::singleShot(0, this, [this]() {
		m_refreshQueued = false;
		refresh();
	});
}

void IwdNetworking::refresh() {
	if (!m_active)
		return;

	if (!m_iwdRunning) {
		m_stationPath.clear();
		setSnapshot(buildSnapshot(false, {}, {}, {}));
		return;
	}

	const ObjectMap objects = fetchManagedObjects();
	m_stationPath = findStation(objects);
	QList<OrderedNetwork> ordered;
	if (!m_stationPath.isEmpty())
		ordered = fetchOrderedNetworks(m_stationPath);

	setSnapshot(buildSnapshot(true, objects, m_stationPath, ordered));
}

void IwdNetworking::subscribe() {
	QDBusConnection bus = QDBusConnection::systemBus();
	bus.connect(IwdService, QString(), ObjectManagerInterface, QStringLiteral("InterfacesAdded"),
	            this, SLOT(scheduleRefresh()));
	bus.connect(IwdService, QString(), ObjectManagerInterface, QStringLiteral("InterfacesRemoved"),
	            this, SLOT(scheduleRefresh()));
	bus.connect(IwdService, QString(), PropertiesInterface, QStringLiteral("PropertiesChanged"),
	            this, SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));
}

void IwdNetworking::unsubscribe() {
	QDBusConnection bus = QDBusConnection::systemBus();
	bus.disconnect(IwdService, QString(), ObjectManagerInterface, QStringLiteral("InterfacesAdded"),
	               this, SLOT(scheduleRefresh()));
	bus.disconnect(IwdService, QString(), ObjectManagerInterface,
	               QStringLiteral("InterfacesRemoved"), this, SLOT(scheduleRefresh()));
	bus.disconnect(IwdService, QString(), PropertiesInterface, QStringLiteral("PropertiesChanged"),
	               this, SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));
}

void IwdNetworking::runCall(const QDBusMessage& message,
                            const QString& operation,
                            bool finishOnReply) {
	auto* watcher =
	    new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message), this);
	connect(watcher, &QDBusPendingCallWatcher::finished, this,
	        [this, operation, finishOnReply](QDBusPendingCallWatcher* call) {
		        const QDBusError error = call->error();
		        call->deleteLater();

		        if (error.isValid()) {
			        if (operation == QStringLiteral("scan"))
				        m_scanPending = false;

			        emit operationFinished(operation, false, error.message());
			        return;
		        }

		        if (finishOnReply)
			        emit operationFinished(operation, true, QString());
	        });
}

void IwdNetworking::setSnapshot(const QVariantMap& next) {
	if (m_snapshot == next)
		return;

	m_snapshot = next;
	emit snapshotChanged();
}

bool IwdNetworking::isKnownNetwork(const QString& id) const {
	for (const QVariant& value : m_snapshot.value(QStringLiteral("wifiNetworks")).toList()) {
		const QVariantMap network = value.toMap();
		if (network.value(QStringLiteral("id")).toString() == id)
			return network.value(QStringLiteral("known")).toBool();
	}

	return false;
}
