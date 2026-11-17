use zbus::{
    blocking::{Connection, Proxy},
    zvariant::{ObjectPath, OwnedObjectPath, OwnedValue},
};

use crate::control_center::dbus::{self, Objects, boolean};

pub(super) const BLUEZ: &str = "org.bluez";
pub(super) const ADAPTER: &str = "org.bluez.Adapter1";
pub(super) const DEVICE: &str = "org.bluez.Device1";

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) enum Error {
    Loading,
    Unavailable,
    NoAdapter,
    PermissionDenied,
    Failed,
    StateChanged,
}

impl Error {
    pub(super) fn message(&self) -> &'static str {
        match self {
            Self::Loading => "Checking Bluetooth…",
            Self::Unavailable => "Bluetooth is unavailable. Check that BlueZ is running.",
            Self::NoAdapter => "No Bluetooth adapter found.",
            Self::PermissionDenied => "Permission denied. Check Bluetooth access permissions.",
            Self::Failed => "Could not complete the Bluetooth request. Try again.",
            Self::StateChanged => "Device or adapter state changed. Try again.",
        }
    }
}

impl From<zbus::Error> for Error {
    fn from(error: zbus::Error) -> Self {
        if matches!(
            error,
            zbus::Error::InputOutput(_) | zbus::Error::Connection(_, _)
        ) {
            return Self::Unavailable;
        }
        match zbus::fdo::Error::from(error) {
            zbus::fdo::Error::AccessDenied(_) | zbus::fdo::Error::AuthFailed(_) => {
                Self::PermissionDenied
            }
            zbus::fdo::Error::ServiceUnknown(_)
            | zbus::fdo::Error::NameHasNoOwner(_)
            | zbus::fdo::Error::Disconnected(_) => Self::Unavailable,
            zbus::fdo::Error::ZBus(zbus::Error::MethodError(name, _, _))
                if name.as_str() == "org.bluez.Error.NotAuthorized" =>
            {
                Self::PermissionDenied
            }
            _ => Self::Failed,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct Adapter {
    pub path: OwnedObjectPath,
    pub name: String,
    pub powered: bool,
    pub discovering: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct Device {
    pub path: OwnedObjectPath,
    pub name: String,
    pub address: String,
    pub paired: bool,
    pub connected: bool,
    pub battery: Option<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct Snapshot {
    pub adapter: Adapter,
    pub devices: Vec<Device>,
}

#[derive(Clone, Debug, PartialEq)]
pub(super) struct Reading {
    pub connected: bool,
    pub error: Option<Error>,
    pub snapshot: Option<Snapshot>,
}

impl Reading {
    pub(super) fn unavailable(error: impl Into<Error>) -> Self {
        Self {
            connected: false,
            error: Some(error.into()),
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

pub(super) fn snapshot(objects: &Objects) -> Option<Snapshot> {
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

pub(super) fn read(connection: &Connection) -> zbus::Result<Reading> {
    if !dbus::owned(connection, BLUEZ)? {
        return Ok(Reading::unavailable(Error::Unavailable));
    }
    let objects = dbus::objects(connection, BLUEZ, "/")?;
    let Some(snapshot) = snapshot(&objects) else {
        return Ok(Reading::unavailable(Error::NoAdapter));
    };
    // Preserve the indicator's connected status across all adapters.
    let connected = objects
        .values()
        .filter_map(|interfaces| interfaces.get(DEVICE))
        .any(|properties| boolean(properties, "Connected"));
    Ok(Reading {
        connected,
        error: None,
        snapshot: Some(snapshot),
    })
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) enum Action {
    Power(OwnedObjectPath, bool),
    Scan,
    StopScan,
    Connect(OwnedObjectPath),
    Disconnect(OwnedObjectPath),
    Forget(OwnedObjectPath),
}

impl Action {
    pub(super) fn allowed(&self, snapshot: &Snapshot) -> bool {
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

pub(super) fn discovery(
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

pub(super) fn apply_action(
    connection: &Connection,
    destination: &str,
    action: &Action,
) -> Result<(), Error> {
    let objects = dbus::objects(connection, destination, "/")?;
    let snapshot = snapshot(&objects).ok_or(Error::NoAdapter)?;
    if !action.allowed(&snapshot) {
        return Err(Error::StateChanged);
    }
    match action {
        Action::Power(path, powered) => {
            Proxy::new(connection, destination, path.as_str(), ADAPTER)?
                .set_property("Powered", *powered)
                .map_err(zbus::Error::from)?;
        }
        Action::Connect(path) | Action::Disconnect(path) => {
            let method = if matches!(action, Action::Connect(_)) {
                "Connect"
            } else {
                "Disconnect"
            };
            Proxy::new(connection, destination, path.as_str(), DEVICE)?
                .call::<_, _, ()>(method, &())?;
        }
        Action::Forget(path) => {
            Proxy::new(
                connection,
                destination,
                snapshot.adapter.path.as_str(),
                ADAPTER,
            )?
            .call::<_, _, ()>("RemoveDevice", &(path,))?;
        }
        Action::Scan | Action::StopScan => {
            return Err(Error::StateChanged);
        }
    }
    Ok(())
}
