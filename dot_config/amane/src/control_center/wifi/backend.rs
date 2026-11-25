use std::fmt;

use zbus::blocking::Connection;

use super::{State, iwd, network_manager, wired_status};
use crate::control_center::dbus;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(super) struct Adapter {
    pub interface: Option<String>,
    pub address: Option<String>,
}

#[derive(Debug, Default, PartialEq, Eq)]
pub(super) struct Wired {
    pub connected: bool,
    pub link: Option<(Adapter, Option<u32>)>,
}

/// Aggregate Wi-Fi association status, not internet reachability.
#[derive(Clone, Debug, Default, PartialEq)]
pub(super) struct Snapshot {
    pub present: bool,
    pub enabled: bool,
    pub connected: bool,
    /// Name of the connected network with the strongest known signal.
    pub network: Option<String>,
    /// Strongest known signal among connected devices, normalized to 0..=1.
    pub strength: Option<f32>,
    pub adapter: Adapter,
    pub security: Option<&'static str>,
}

impl Snapshot {
    pub(super) fn record_connection(&mut self, name: String, strength: Option<f32>) -> bool {
        let name = Some(name).filter(|name| !name.is_empty());
        let prefer_name = match (&name, &self.network) {
            (Some(name), Some(current)) => name < current,
            (Some(_), None) => true,
            _ => false,
        };
        let preferred = !self.connected
            || strength > self.strength
            || (strength == self.strength && prefer_name);
        if preferred {
            self.network = name;
            self.strength = strength;
        }
        self.connected = true;
        preferred
    }
}

#[derive(Debug, PartialEq)]
pub(super) enum Error {
    Unavailable,
    PermissionDenied(String),
    ReadFailed(String),
}

impl From<zbus::Error> for Error {
    fn from(error: zbus::Error) -> Self {
        if matches!(
            error,
            zbus::Error::InputOutput(_) | zbus::Error::Connection(_, _)
        ) {
            return Self::Unavailable;
        }
        let error = zbus::fdo::Error::from(error);
        match error {
            zbus::fdo::Error::ServiceUnknown(_)
            | zbus::fdo::Error::NameHasNoOwner(_)
            | zbus::fdo::Error::Disconnected(_) => Self::Unavailable,
            zbus::fdo::Error::AccessDenied(_) | zbus::fdo::Error::AuthFailed(_) => {
                Self::PermissionDenied(error.to_string())
            }
            _ => Self::ReadFailed(error.to_string()),
        }
    }
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Unavailable => f.write_str("No Wi-Fi backend is available."),
            Self::PermissionDenied(detail) => write!(f, "Permission denied: {detail}"),
            Self::ReadFailed(detail) => write!(f, "Could not read Wi-Fi status: {detail}"),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum Backend {
    NetworkManager,
    Iwd,
}

impl Backend {
    pub fn detect(connection: &Connection) -> Result<Self, Error> {
        for backend in [Self::NetworkManager, Self::Iwd] {
            if dbus::owned(connection, backend.service())? {
                return Ok(backend);
            }
        }
        Err(Error::Unavailable)
    }

    pub fn label(self) -> &'static str {
        match self {
            Self::NetworkManager => "NetworkManager",
            Self::Iwd => "Standalone iwd",
        }
    }

    pub(super) const fn service(self) -> &'static str {
        match self {
            Self::NetworkManager => "org.freedesktop.NetworkManager",
            Self::Iwd => "net.connman.iwd",
        }
    }

    pub(super) fn read(self, connection: &Connection) -> Result<State, Error> {
        if !dbus::owned(connection, self.service())? {
            return Err(Error::Unavailable);
        }
        match self {
            Self::NetworkManager => Ok(network_manager::read(connection)?),
            Self::Iwd => Ok(State {
                wifi: iwd::read_snapshot(connection)?,
                wired: wired_status(),
                connectivity: None,
                status: Some(Ok(self)),
            }),
        }
    }
}
