use std::{
    sync::{
        LazyLock, Mutex,
        atomic::{AtomicBool, Ordering},
        mpsc::{self, Receiver, RecvTimeoutError, Sender},
    },
    thread,
    time::{Duration, Instant},
};

use amane::{Button, Center, Column, Cursor, Parent, Rectangle, Row, Service, Widget, children};
use zbus::{
    blocking::{Connection, Proxy, connection::Builder},
    zvariant::{ObjectPath, OwnedObjectPath, OwnedValue},
};

use super::{
    dbus::{self, Objects, boolean},
    ui::{icon, text},
};
use crate::{
    design::{control_center as layout, padding, spacing},
    theme::Theme,
};

const BLUEZ: &str = "org.bluez";
const ADAPTER: &str = "org.bluez.Adapter1";
const DEVICE: &str = "org.bluez.Device1";
const REFRESH: Duration = Duration::from_secs(2);
const SCAN_TIME: Duration = Duration::from_secs(15);
const ACTION_TIMEOUT: Duration = Duration::from_secs(30);

static VISIBLE: AtomicBool = AtomicBool::new(false);
static WANT_SCAN: AtomicBool = AtomicBool::new(false);
static REQUESTS: LazyLock<(Sender<Request>, Mutex<Receiver<Request>>)> = LazyLock::new(|| {
    let (sender, receiver) = mpsc::channel();
    (sender, Mutex::new(receiver))
});

enum Request {
    Wake,
    Scan,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Adapter {
    path: OwnedObjectPath,
    name: String,
    powered: bool,
    discovering: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Device {
    path: OwnedObjectPath,
    name: String,
    address: String,
    paired: bool,
    connected: bool,
    battery: Option<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Snapshot {
    adapter: Adapter,
    devices: Vec<Device>,
}

#[derive(Clone, Debug, PartialEq)]
struct Reading {
    enabled: bool,
    connected: bool,
    message: String,
    snapshot: Option<Snapshot>,
}

impl Reading {
    fn unavailable(error: impl std::fmt::Display) -> Self {
        Self {
            enabled: false,
            connected: false,
            message: format!("Bluetooth backend unavailable\n{error}"),
            snapshot: None,
        }
    }
}

fn string(properties: &std::collections::HashMap<String, OwnedValue>, name: &str) -> String {
    properties
        .get(name)
        .and_then(|value| <&str>::try_from(value).ok())
        .unwrap_or_default()
        .to_string()
}

fn snapshot(objects: &Objects) -> Option<Snapshot> {
    let (path, properties) = objects
        .iter()
        .filter_map(|(path, interfaces)| {
            interfaces.get(ADAPTER).map(|properties| (path, properties))
        })
        .min_by_key(|(path, _)| path.as_str())?;
    let adapter = Adapter {
        path: path.clone(),
        name: string(properties, "Alias"),
        powered: boolean(properties, "Powered"),
        discovering: boolean(properties, "Discovering"),
    };
    let mut devices: Vec<_> = objects
        .iter()
        .filter_map(|(device_path, interfaces)| {
            let properties = interfaces.get(DEVICE)?;
            let parent = properties
                .get("Adapter")
                .and_then(|value| <&ObjectPath>::try_from(value).ok())?;
            if parent.as_str() != path.as_str() {
                return None;
            }
            let address = string(properties, "Address");
            let mut name = string(properties, "Alias");
            if name.is_empty() {
                name = string(properties, "Name");
            }
            if name.is_empty() {
                name.clone_from(&address);
            }
            if name.is_empty() {
                name = device_path.to_string();
            }
            let battery = interfaces
                .get("org.bluez.Battery1")
                .and_then(|properties| properties.get("Percentage"))
                .and_then(|value| u8::try_from(value).ok())
                .filter(|percent| *percent <= 100);
            Some(Device {
                path: device_path.clone(),
                name,
                address,
                paired: boolean(properties, "Paired") || boolean(properties, "Bonded"),
                connected: boolean(properties, "Connected"),
                battery,
            })
        })
        .collect();
    devices.sort_by_key(|device| {
        (
            !device.connected,
            !device.paired,
            device.name.to_lowercase(),
            device.path.to_string(),
        )
    });
    Some(Snapshot { adapter, devices })
}

fn read(connection: &Connection) -> zbus::Result<Reading> {
    if !dbus::owned(connection, BLUEZ)? {
        return Ok(Reading::unavailable("BlueZ is not running."));
    }
    let objects = dbus::objects(connection, BLUEZ, "/")?;
    let Some(snapshot) = snapshot(&objects) else {
        return Ok(Reading::unavailable("No Bluetooth adapter."));
    };
    // Preserve the indicator's connected status across all adapters.
    let connected = objects
        .values()
        .filter_map(|interfaces| interfaces.get(DEVICE))
        .any(|properties| boolean(properties, "Connected"));
    Ok(Reading {
        enabled: snapshot.adapter.powered,
        connected,
        message: format!("Bluetooth: {}", snapshot.adapter.name),
        snapshot: Some(snapshot),
    })
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum Action {
    Power(OwnedObjectPath, bool),
    Scan,
    StopScan,
    Connect(OwnedObjectPath),
    Disconnect(OwnedObjectPath),
    Forget(OwnedObjectPath),
}

impl Action {
    fn allowed(&self, snapshot: &Snapshot) -> bool {
        match self {
            Self::Power(path, powered) => {
                *path == snapshot.adapter.path && *powered != snapshot.adapter.powered
            }
            Self::Scan => snapshot.adapter.powered,
            Self::StopScan => true,
            Self::Connect(path) => {
                snapshot.adapter.powered
                    && snapshot
                        .devices
                        .iter()
                        .any(|device| device.path == *path && device.paired && !device.connected)
            }
            Self::Disconnect(path) => snapshot
                .devices
                .iter()
                .any(|device| device.path == *path && device.connected),
            Self::Forget(path) => snapshot
                .devices
                .iter()
                .any(|device| device.path == *path && device.paired && !device.connected),
        }
    }
}

struct State {
    reading: Reading,
    pending: Option<Action>,
    error: Option<String>,
    scanning: bool,
}

struct Discovery {
    path: OwnedObjectPath,
    until: Instant,
}

impl Discovery {
    fn should_stop(&self, visible: bool, wanted: bool, now: Instant) -> bool {
        !visible || !wanted || now >= self.until
    }

    fn valid_for(&self, snapshot: Option<&Snapshot>) -> bool {
        snapshot
            .is_some_and(|snapshot| snapshot.adapter.powered && snapshot.adapter.path == self.path)
    }
}

impl Service for State {
    fn new() -> Self {
        Self {
            reading: Reading::unavailable("Checking backend…"),
            pending: None,
            error: None,
            scanning: false,
        }
    }

    fn listen() {
        let receiver = REQUESTS.1.lock().expect("Bluetooth receiver poisoned");
        let mut bus = None;
        let mut scan: Option<Discovery> = None;
        loop {
            let result = (|| {
                if bus.is_none() {
                    bus = Some(dbus::connection(false)?);
                }
                let connection = bus.as_ref().expect("connected Bluetooth bus");
                if scan.as_ref().is_some_and(|scan| {
                    scan.should_stop(
                        VISIBLE.load(Ordering::SeqCst),
                        WANT_SCAN.load(Ordering::SeqCst),
                        Instant::now(),
                    )
                }) {
                    WANT_SCAN.store(false, Ordering::SeqCst);
                    let result = stop_discovery(connection, BLUEZ, &mut scan);
                    Self::write().scanning = false;
                    result?;
                }
                read(connection)
            })();
            let fresh = match result {
                Ok(reading) => {
                    if scan
                        .as_ref()
                        .is_some_and(|scan| !scan.valid_for(reading.snapshot.as_ref()))
                    {
                        // Power-off, adapter removal or daemon loss invalidates the lease.
                        // Close its connection rather than stopping another adapter's scan.
                        bus = None;
                        scan = None;
                        WANT_SCAN.store(false, Ordering::SeqCst);
                        Self::write().scanning = false;
                    }
                    reading
                }
                Err(error) => {
                    // Dropping our connection also releases its discovery session.
                    bus = None;
                    scan = None;
                    WANT_SCAN.store(false, Ordering::SeqCst);
                    Self::write().scanning = false;
                    Reading::unavailable(error)
                }
            };
            publish(fresh);
            match receiver.recv_timeout(REFRESH) {
                Ok(Request::Wake) => {}
                Ok(Request::Scan) => {
                    let result = (|| {
                        if !VISIBLE.load(Ordering::SeqCst) || !WANT_SCAN.load(Ordering::SeqCst) {
                            return Ok(());
                        }
                        let connection = bus.as_ref().ok_or("Bluetooth backend unavailable")?;
                        let objects =
                            dbus::objects(connection, BLUEZ, "/").map_err(|e| e.to_string())?;
                        let snapshot = snapshot(&objects).ok_or("No Bluetooth adapter")?;
                        if !snapshot.adapter.powered {
                            return Err("Bluetooth is disabled".into());
                        }
                        discovery(connection, BLUEZ, &snapshot.adapter.path, true)
                            .map_err(|e| e.to_string())?;
                        scan = Some(Discovery {
                            path: snapshot.adapter.path,
                            until: Instant::now() + SCAN_TIME,
                        });
                        Ok::<_, String>(())
                    })();
                    if result.is_err() {
                        bus = None;
                        scan = None;
                        WANT_SCAN.store(false, Ordering::SeqCst);
                    }
                    let mut state = Self::write();
                    state.scanning = scan.is_some();
                    state.pending = None;
                    state.error = result.err();
                }
                Err(RecvTimeoutError::Timeout) => {}
                Err(RecvTimeoutError::Disconnected) => return,
            }
        }
    }
}

pub(super) fn set_active(visible: bool) {
    VISIBLE.store(visible, Ordering::SeqCst);
    if !visible {
        WANT_SCAN.store(false, Ordering::SeqCst);
    }
    let _ = REQUESTS.0.send(Request::Wake);
}

fn publish(reading: Reading) {
    let changed = State::read().reading != reading;
    if changed {
        State::write().reading = reading;
    }
}

fn discovery(
    connection: &Connection,
    destination: &str,
    path: &OwnedObjectPath,
    start: bool,
) -> zbus::Result<()> {
    let method = if start {
        "StartDiscovery"
    } else {
        "StopDiscovery"
    };
    Proxy::new(connection, destination, path.as_str(), ADAPTER)?.call(method, &())
}

fn stop_discovery(
    connection: &Connection,
    destination: &str,
    scan: &mut Option<Discovery>,
) -> zbus::Result<()> {
    if let Some(scan) = scan.take() {
        discovery(connection, destination, &scan.path, false)?;
    }
    Ok(())
}

fn apply_action(connection: &Connection, destination: &str, action: &Action) -> Result<(), String> {
    let objects = dbus::objects(connection, destination, "/").map_err(|e| e.to_string())?;
    let snapshot = snapshot(&objects).ok_or("No Bluetooth adapter")?;
    if !action.allowed(&snapshot) {
        return Err("Device or adapter state changed; try again".into());
    }
    let result = match action {
        Action::Power(path, powered) => Proxy::new(connection, destination, path.as_str(), ADAPTER)
            .map_err(|e| e.to_string())?
            .set_property("Powered", *powered)
            .map_err(zbus::Error::from),
        Action::Connect(path) | Action::Disconnect(path) => {
            let method = if matches!(action, Action::Connect(_)) {
                "Connect"
            } else {
                "Disconnect"
            };
            Proxy::new(connection, destination, path.as_str(), DEVICE)
                .map_err(|e| e.to_string())?
                .call::<_, _, ()>(method, &())
        }
        Action::Forget(path) => Proxy::new(
            connection,
            destination,
            snapshot.adapter.path.as_str(),
            ADAPTER,
        )
        .map_err(|e| e.to_string())?
        .call::<_, _, ()>("RemoveDevice", &(path,)),
        Action::Scan | Action::StopScan => {
            return Err("Discovery must use its owning connection".into());
        }
    };
    result.map_err(|e| e.to_string())
}

fn request(action: Action) {
    if action == Action::StopScan {
        WANT_SCAN.store(false, Ordering::SeqCst);
        let _ = REQUESTS.0.send(Request::Wake);
        return;
    }
    let allowed = State::read()
        .reading
        .snapshot
        .as_ref()
        .is_some_and(|snapshot| action.allowed(snapshot));
    if !allowed || !VISIBLE.load(Ordering::SeqCst) {
        return;
    }
    {
        let mut state = State::write();
        if state.pending.is_some() {
            return;
        }
        state.pending = Some(action.clone());
        state.error = None;
    }
    if action == Action::Scan {
        WANT_SCAN.store(true, Ordering::SeqCst);
        if REQUESTS.0.send(Request::Scan).is_err() {
            let mut state = State::write();
            state.pending = None;
            state.error = Some("Could not queue discovery".into());
            WANT_SCAN.store(false, Ordering::SeqCst);
        }
        return;
    }
    // One action at a time, on a separate connection so a slow Connect cannot
    // delay discovery cleanup or prevent background state updates.
    thread::spawn(move || {
        let result = (|| {
            let connection = Builder::system()
                .and_then(|builder| builder.method_timeout(ACTION_TIMEOUT).build())
                .map_err(|e| e.to_string())?;
            let result = apply_action(&connection, BLUEZ, &action);
            if let Ok(reading) = read(&connection) {
                publish(reading);
            }
            result
        })();
        {
            let mut state = State::write();
            state.pending = None;
            state.error = result.err();
        }
        let _ = REQUESTS.0.send(Request::Wake);
    });
}

fn action_button(label: &str, action: Option<Action>, theme: &Theme) -> Rectangle {
    let color = if action.is_some() {
        theme.fg
    } else {
        theme.surface4
    };
    let mut button = Rectangle::new()
        .width(Parent)
        .height(layout::ROW_HEIGHT)
        .padding(padding::NORMAL)
        .fill(theme.surface2)
        .radius(theme.radius.normal)
        .align_child(Center, Center)
        .child(text(label, theme).color(color).elide().max_lines(1));
    if let Some(action) = action {
        button = button.cursor(Cursor::Pointer).on_click(move |button| {
            if button == Button::Left {
                request(action.clone());
            }
        });
    }
    button
}

pub(super) fn indicator(theme: &Theme) -> Rectangle {
    let state = State::read();
    let reading = &state.reading;
    let (glyph, color) = if !reading.enabled {
        ('\u{e0de}', theme.surface4)
    } else if reading.connected {
        ('\u{e0dc}', theme.accent)
    } else {
        ('\u{e0da}', theme.fg)
    };
    icon(glyph, color)
}

pub(super) fn view(theme: &Theme) -> Column {
    let state = State::read();
    let reading = &state.reading;
    let mut content: Vec<Box<dyn Widget>> = Vec::new();
    if let Some(snapshot) = &reading.snapshot {
        let adapter = &snapshot.adapter;
        let idle = state.pending.is_none();
        let power = Action::Power(adapter.path.clone(), !adapter.powered);
        let power_label = if adapter.powered {
            "Turn off"
        } else {
            "Turn on"
        };
        content.push(Box::new(
            text(format!("Bluetooth  {}", adapter.name), theme)
                .elide()
                .max_lines(1),
        ));
        let mut controls = children![action_button(power_label, idle.then_some(power), theme)];
        if state.scanning {
            controls.push(Box::new(action_button(
                "Stop scan",
                Some(Action::StopScan),
                theme,
            )));
        } else {
            controls.push(Box::new(action_button(
                "Scan",
                (idle && adapter.powered).then_some(Action::Scan),
                theme,
            )));
        }
        content.push(Box::new(
            Row::new(controls).width(Parent).gap(spacing::SMALL),
        ));
        let feedback = if let Some(action) = &state.pending {
            match action {
                Action::Power(_, true) => "Turning on…",
                Action::Power(_, false) => "Turning off…",
                Action::Scan => "Starting scan…",
                Action::StopScan => "Stopping scan…",
                Action::Connect(_) => "Connecting…",
                Action::Disconnect(_) => "Disconnecting…",
                Action::Forget(_) => "Forgetting device…",
            }
        } else if state.scanning {
            "Scanning…"
        } else if !adapter.powered {
            "Bluetooth is disabled"
        } else if adapter.discovering {
            "Another application is scanning"
        } else {
            "Scan to find nearby devices"
        };
        content.push(Box::new(text(feedback, theme).elide().max_lines(1)));
        for device in &snapshot.devices {
            let name_color = if device.connected {
                theme.accent
            } else {
                theme.fg
            };
            content.push(Box::new(
                text(&device.name, theme)
                    .color(name_color)
                    .elide()
                    .max_lines(1),
            ));
            let mut status = if device.connected {
                "Connected".to_string()
            } else if device.paired {
                "Paired".to_string()
            } else {
                format!("Not paired  {}", device.address)
            };
            if device.connected
                && let Some(battery) = device.battery
            {
                status.push_str(&format!("  {battery}%"));
            }
            content.push(Box::new(text(status, theme).elide().max_lines(1)));
            let (label, action) = if device.connected {
                ("Disconnect", Action::Disconnect(device.path.clone()))
            } else {
                ("Connect", Action::Connect(device.path.clone()))
            };
            let mut actions = children![action_button(
                label,
                Some(action.clone()).filter(|action| idle && action.allowed(snapshot)),
                theme
            )];
            if device.paired {
                let forget = Action::Forget(device.path.clone());
                actions.push(Box::new(action_button(
                    "Forget",
                    Some(forget.clone()).filter(|action| idle && action.allowed(snapshot)),
                    theme,
                )));
            }
            content.push(Box::new(
                Row::new(actions).width(Parent).gap(spacing::SMALL),
            ));
        }
        if snapshot.devices.is_empty() {
            content.push(Box::new(text("No devices found", theme)));
        }
        if snapshot.devices.iter().any(|device| !device.paired) {
            content.push(Box::new(
                text("Pair new devices in Bluetooth settings.", theme).wrap(),
            ));
        }
    } else {
        content.push(Box::new(text(&reading.message, theme).wrap()));
    }
    if let Some(error) = &state.error {
        content.push(Box::new(text(error, theme).color(theme.destructive).wrap()));
    }
    Column::new(content).width(Parent).gap(spacing::SMALL)
}

#[cfg(test)]
mod tests {
    use std::{
        collections::HashMap,
        sync::{Arc, atomic::AtomicUsize},
    };

    use zbus::zvariant::Value;

    use super::*;

    #[test]
    #[ignore = "read-only smoke check against the live system bus"]
    fn live_backend() {
        let reading = read(&dbus::connection(false).unwrap()).unwrap();
        println!("{reading:?}");
        assert!(!reading.message.is_empty());
    }

    fn path(path: &str) -> OwnedObjectPath {
        OwnedObjectPath::try_from(path).unwrap()
    }

    fn properties(values: Vec<(&str, Value<'_>)>) -> HashMap<String, OwnedValue> {
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

        fn connect(&mut self) {
            self.connected = true;
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
            .serve_at("/org/bluez/hci0/dev_test", FakeDevice { connected: false })
            .unwrap()
            .build()
            .unwrap();
        let client = dbus::connection(true).unwrap();
        let destination = server.unique_name().unwrap().as_str();
        let adapter = path("/org/bluez/hci0");
        let device = path("/org/bluez/hci0/dev_test");
        assert!(apply_action(&client, destination, &Action::Connect(device.clone())).is_err());
        apply_action(&client, destination, &Action::Power(adapter.clone(), true)).unwrap();
        apply_action(&client, destination, &Action::Connect(device.clone())).unwrap();
        assert!(apply_action(&client, destination, &Action::Forget(device.clone())).is_err());
        apply_action(&client, destination, &Action::Disconnect(device.clone())).unwrap();
        apply_action(&client, destination, &Action::Forget(device.clone())).unwrap();
        assert_eq!(*removed.lock().unwrap(), [device]);
        denied.store(true, Ordering::SeqCst);
        assert!(
            apply_action(&client, destination, &Action::Power(adapter.clone(), false))
                .unwrap_err()
                .contains("AccessDenied")
        );

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
        assert!(owned.is_none());
        assert_eq!(starts.load(Ordering::SeqCst), 2);
        assert_eq!(stops.load(Ordering::SeqCst), 1);
    }
}
