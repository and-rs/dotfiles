use std::{
    collections::HashMap,
    sync::{Arc, atomic::AtomicUsize},
};

use zbus::zvariant::Value;

use super::*;
use crate::control_center::dbus::Objects;
use backend::{ADAPTER, DEVICE};

#[test]
#[ignore = "read-only smoke check against the live system bus"]
fn live_backend() {
    let reading = read(&dbus::connection(false).unwrap()).unwrap();
    println!("{reading:?}");
    assert!(reading.snapshot.is_some() || reading.error.is_some());
}

fn path(path: &str) -> OwnedObjectPath {
    OwnedObjectPath::try_from(path).unwrap()
}

fn properties(values: Vec<(&str, Value<'_>)>) -> HashMap<String, zbus::zvariant::OwnedValue> {
    values
        .into_iter()
        .map(|(key, value)| (key.to_string(), value.try_to_owned().unwrap()))
        .collect()
}

fn test_objects() -> Objects {
    let adapter = path("/org/bluez/hci0");
    let other = path("/org/bluez/hci1");
    let mut objects = Objects::new();
    for adapter in [&adapter, &other] {
        objects.insert(
            adapter.clone(),
            HashMap::from([(
                ADAPTER.into(),
                properties(vec![
                    ("Alias", "Test adapter".into()),
                    ("Powered", true.into()),
                    ("Discovering", false.into()),
                ]),
            )]),
        );
    }
    for (id, name, paired, connected, parent) in [
        ("a", "Zulu", true, false, &adapter),
        ("b", "Alpha", false, false, &adapter),
        ("c", "Connected", true, true, &adapter),
        ("d", "Other adapter", true, true, &other),
    ] {
        objects.insert(
            path(&format!("{parent}/dev_{id}")),
            HashMap::from([(
                DEVICE.into(),
                properties(vec![
                    ("Alias", name.into()),
                    ("Address", id.into()),
                    ("Adapter", Value::from(parent.as_ref())),
                    ("Paired", paired.into()),
                    ("Connected", connected.into()),
                ]),
            )]),
        );
    }
    objects
}

#[test]
fn snapshots_filter_adapters_and_sort_connected_then_paired_devices() {
    let mut objects = test_objects();
    let device = objects.get_mut(&path("/org/bluez/hci0/dev_c")).unwrap();
    device.insert(
        "org.bluez.Battery1".into(),
        properties(vec![("Percentage", 73_u8.into())]),
    );
    let snapshot = snapshot(&objects).unwrap();
    assert_eq!(snapshot.adapter.path, path("/org/bluez/hci0"));
    assert_eq!(
        snapshot
            .devices
            .iter()
            .map(|device| device.name.as_str())
            .collect::<Vec<_>>(),
        ["Connected", "Zulu", "Alpha"]
    );
    assert_eq!(snapshot.devices[0].battery, Some(73));
    assert_eq!(snapshot.devices[1].battery, None);
    let battery = objects.get_mut(&path("/org/bluez/hci0/dev_c")).unwrap();
    battery.insert(
        "org.bluez.Battery1".into(),
        properties(vec![("Percentage", 255_u8.into())]),
    );
    assert_eq!(super::snapshot(&objects).unwrap().devices[0].battery, None);
    assert!(super::snapshot(&Objects::new()).is_none());
}

#[test]
fn actions_reject_unpaired_connected_missing_and_wrong_adapter_targets() {
    let mut snapshot = snapshot(&test_objects()).unwrap();
    let paired = path("/org/bluez/hci0/dev_a");
    let unpaired = path("/org/bluez/hci0/dev_b");
    let connected = path("/org/bluez/hci0/dev_c");
    assert!(Action::Connect(paired.clone()).allowed(&snapshot));
    assert!(!Action::Connect(unpaired).allowed(&snapshot));
    assert!(!Action::Connect(connected.clone()).allowed(&snapshot));
    assert!(Action::Disconnect(connected.clone()).allowed(&snapshot));
    assert!(!Action::Forget(connected).allowed(&snapshot));
    assert!(Action::Forget(paired.clone()).allowed(&snapshot));
    assert!(!Action::Forget(path("/org/bluez/hci1/dev_d")).allowed(&snapshot));
    assert!(!Action::Connect(path("/org/bluez/hci0/missing")).allowed(&snapshot));
    snapshot.adapter.powered = false;
    assert!(!Action::Connect(paired.clone()).allowed(&snapshot));
    assert!(!Action::Scan.allowed(&snapshot));
    assert!(Action::Forget(paired).allowed(&snapshot));
    assert!(Action::Power(snapshot.adapter.path.clone(), true).allowed(&snapshot));
    assert!(!Action::Power(path("/org/bluez/hci1"), true).allowed(&snapshot));
}

#[test]
fn discovery_stops_on_close_tab_switch_cancellation_and_timeout() {
    let now = Instant::now();
    let scan = Discovery {
        path: path("/org/bluez/hci0"),
        until: now + SCAN_TIME,
    };
    assert!(!scan.should_stop(true, true, now));
    assert!(scan.should_stop(false, true, now));
    // Closing and immediately reopening must not resurrect a cancelled scan.
    assert!(scan.should_stop(true, false, now));
    assert!(scan.should_stop(true, true, now + SCAN_TIME));
    let mut snapshot = snapshot(&test_objects()).unwrap();
    assert!(scan.valid_for(Some(&snapshot)));
    snapshot.adapter.powered = false;
    assert!(!scan.valid_for(Some(&snapshot)));
    snapshot.adapter.powered = true;
    snapshot.adapter.path = path("/org/bluez/hci1");
    assert!(!scan.valid_for(Some(&snapshot)));
    assert!(!scan.valid_for(None));
}

struct FakeAdapter {
    powered: bool,
    starts: Arc<AtomicUsize>,
    stops: Arc<AtomicUsize>,
    removed: Arc<Mutex<Vec<OwnedObjectPath>>>,
    denied: Arc<AtomicBool>,
}

#[derive(Debug, zbus::DBusError)]
#[zbus(prefix = "org.bluez.Error")]
enum BluezError {
    NotAuthorized(String),
}

#[zbus::interface(name = "org.bluez.Adapter1")]
impl FakeAdapter {
    #[zbus(property)]
    fn alias(&self) -> &str {
        "Test adapter"
    }

    #[zbus(property)]
    fn powered(&self) -> bool {
        self.powered
    }

    #[zbus(property)]
    fn set_powered(&mut self, powered: bool) -> zbus::fdo::Result<()> {
        if self.denied.load(Ordering::SeqCst) {
            return Err(zbus::fdo::Error::AccessDenied("Not authorized".into()));
        }
        self.powered = powered;
        Ok(())
    }

    #[zbus(property)]
    fn discovering(&self) -> bool {
        self.starts.load(Ordering::SeqCst) > self.stops.load(Ordering::SeqCst)
    }

    fn start_discovery(&self) {
        self.starts.fetch_add(1, Ordering::SeqCst);
    }

    fn stop_discovery(&self) {
        self.stops.fetch_add(1, Ordering::SeqCst);
    }

    fn remove_device(&self, device: OwnedObjectPath) {
        self.removed.lock().unwrap().push(device);
    }
}

struct FakeDevice {
    connected: bool,
    denied: Arc<AtomicBool>,
}

#[zbus::interface(name = "org.bluez.Device1")]
impl FakeDevice {
    #[zbus(property)]
    fn adapter(&self) -> OwnedObjectPath {
        path("/org/bluez/hci0")
    }

    #[zbus(property)]
    fn alias(&self) -> &str {
        "Test headphones"
    }

    #[zbus(property)]
    fn paired(&self) -> bool {
        true
    }

    #[zbus(property)]
    fn connected(&self) -> bool {
        self.connected
    }

    fn connect(&mut self) -> Result<(), BluezError> {
        if self.denied.load(Ordering::SeqCst) {
            return Err(BluezError::NotAuthorized("Not authorized".into()));
        }
        self.connected = true;
        Ok(())
    }

    fn disconnect(&mut self) {
        self.connected = false;
    }
}

#[test]
#[ignore = "run under dbus-run-session; writes only to this test's unique D-Bus connection"]
fn fake_bluez_actions_and_discovery_ownership() {
    let starts = Arc::new(AtomicUsize::new(0));
    let stops = Arc::new(AtomicUsize::new(0));
    let removed = Arc::new(Mutex::new(Vec::new()));
    let denied = Arc::new(AtomicBool::new(false));
    let server = Builder::session()
        .unwrap()
        .name(BLUEZ)
        .unwrap()
        .serve_at("/", zbus::fdo::ObjectManager)
        .unwrap()
        .serve_at(
            "/org/bluez/hci0",
            FakeAdapter {
                powered: false,
                starts: starts.clone(),
                stops: stops.clone(),
                removed: removed.clone(),
                denied: denied.clone(),
            },
        )
        .unwrap()
        .serve_at(
            "/org/bluez/hci0/dev_test",
            FakeDevice {
                connected: false,
                denied: denied.clone(),
            },
        )
        .unwrap()
        .build()
        .unwrap();
    let client = dbus::connection(true).unwrap();
    let destination = server.unique_name().unwrap().as_str();
    let adapter = path("/org/bluez/hci0");
    let device = path("/org/bluez/hci0/dev_test");
    assert!(!read(&client).unwrap().snapshot.unwrap().adapter.powered);
    assert!(apply_action(&client, destination, &Action::Connect(device.clone())).is_err());
    apply_action(&client, destination, &Action::Power(adapter.clone(), true)).unwrap();
    apply_action(&client, destination, &Action::Connect(device.clone())).unwrap();
    assert!(read(&client).unwrap().connected);
    assert!(apply_action(&client, destination, &Action::Forget(device.clone())).is_err());
    apply_action(&client, destination, &Action::Disconnect(device.clone())).unwrap();
    assert!(!read(&client).unwrap().connected);
    denied.store(true, Ordering::SeqCst);
    assert_eq!(
        apply_action(&client, destination, &Action::Connect(device.clone())),
        Err(Error::PermissionDenied),
    );
    denied.store(false, Ordering::SeqCst);
    apply_action(&client, destination, &Action::Forget(device.clone())).unwrap();
    assert_eq!(*removed.lock().unwrap(), [device]);
    denied.store(true, Ordering::SeqCst);
    assert_eq!(
        apply_action(&client, destination, &Action::Power(adapter.clone(), false)),
        Err(Error::PermissionDenied)
    );
    denied.store(false, Ordering::SeqCst);
    apply_action(&client, destination, &Action::Power(adapter.clone(), false)).unwrap();
    apply_action(&client, destination, &Action::Power(adapter.clone(), true)).unwrap();

    // An existing discovery flag is not ownership of a discovery session.
    discovery(&client, destination, &adapter, true).unwrap();
    let mut owned = None;
    stop_discovery(&client, destination, &mut owned).unwrap();
    assert_eq!(stops.load(Ordering::SeqCst), 0);
    discovery(&client, destination, &adapter, true).unwrap();
    owned = Some(Discovery {
        path: adapter,
        until: Instant::now() + SCAN_TIME,
    });
    stop_discovery(&client, destination, &mut owned).unwrap();
    stop_discovery(&client, destination, &mut owned).unwrap();
    assert_eq!(starts.load(Ordering::SeqCst), 2);
    assert_eq!(stops.load(Ordering::SeqCst), 1);

    // Adapter disappearance is a normal, recoverable reading.
    assert!(
        server
            .object_server()
            .remove::<FakeAdapter, _>("/org/bluez/hci0")
            .unwrap()
    );
    assert_eq!(
        read(&client).unwrap(),
        Reading::unavailable(Error::NoAdapter)
    );
    server
        .object_server()
        .at(
            "/org/bluez/hci0",
            FakeAdapter {
                powered: true,
                starts,
                stops,
                removed,
                denied,
            },
        )
        .unwrap();
    assert!(read(&client).unwrap().snapshot.unwrap().adapter.powered);
    server.release_name(BLUEZ).unwrap();
    assert_eq!(
        read(&client).unwrap(),
        Reading::unavailable(Error::Unavailable)
    );
    server.request_name(BLUEZ).unwrap();
    assert!(read(&client).unwrap().snapshot.is_some());
}

#[test]
fn errors_classify_bus_denial_and_service_loss() {
    assert_eq!(
        Error::from(zbus::Error::from(zbus::fdo::Error::AccessDenied(
            "raw detail".into()
        ))),
        Error::PermissionDenied,
    );
    assert_eq!(
        Error::from(zbus::Error::from(zbus::fdo::Error::ServiceUnknown(
            "raw detail".into()
        ))),
        Error::Unavailable,
    );
    assert_eq!(
        Error::from(zbus::Error::from(zbus::fdo::Error::Failed(
            "raw detail".into()
        ))),
        Error::Failed,
    );
}
