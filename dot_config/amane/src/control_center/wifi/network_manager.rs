use zbus::{
    blocking::{Connection, Proxy},
    zvariant::OwnedObjectPath,
};

use super::backend::{Backend, Snapshot};

const SERVICE: &str = Backend::NetworkManager.service();
const ROOT: &str = "/org/freedesktop/NetworkManager";
const DEVICE: &str = "org.freedesktop.NetworkManager.Device";

fn manager(connection: &Connection) -> zbus::Result<Proxy<'_>> {
    Proxy::new(connection, SERVICE, ROOT, SERVICE)
}

pub(super) fn read_snapshot(connection: &Connection) -> zbus::Result<Snapshot> {
    let manager = manager(connection)?;
    let enabled: bool = manager.get_property("WirelessEnabled")?;
    let paths: Vec<OwnedObjectPath> = manager.call("GetDevices", &())?;
    let mut snapshot = Snapshot::default();
    for path in paths {
        let device = Proxy::new(connection, SERVICE, path.as_str(), DEVICE)?;
        if !device.get_property::<bool>("Managed")?
            || device.get_property::<u32>("DeviceType")? != 2
        {
            continue;
        }
        snapshot.present = true;
        snapshot.enabled = enabled;
        if !enabled {
            continue;
        }
        let active: OwnedObjectPath = device.get_property("ActiveConnection")?;
        let wireless = Proxy::new(
            connection,
            SERVICE,
            path.as_str(),
            "org.freedesktop.NetworkManager.Device.Wireless",
        )?;
        let ap: OwnedObjectPath = wireless.get_property("ActiveAccessPoint")?;
        if active.as_str() == "/" || ap.as_str() == "/" {
            continue;
        }
        let ap = Proxy::new(
            connection,
            SERVICE,
            ap,
            "org.freedesktop.NetworkManager.AccessPoint",
        )?;
        let ssid: Vec<u8> = ap.get_property("Ssid")?;
        let strength = match ap.get_property::<u8>("Strength") {
            Ok(strength) => Some((f32::from(strength) / 100.0).clamp(0.0, 1.0)),
            Err(error) => match zbus::fdo::Error::from(error) {
                zbus::fdo::Error::UnknownProperty(_) => None,
                error => return Err(error.into()),
            },
        };
        snapshot.record_connection(String::from_utf8_lossy(&ssid).into_owned(), strength);
    }
    Ok(snapshot)
}

/// Keep NM's existing active-connection plus carrier semantics outside the Wi-Fi API.
pub(super) fn wired_connected(connection: &Connection) -> zbus::Result<bool> {
    let paths: Vec<OwnedObjectPath> = manager(connection)?.call("GetDevices", &())?;
    let mut connected = false;
    for path in paths {
        let device = Proxy::new(connection, SERVICE, path.as_str(), DEVICE)?;
        if !device.get_property::<bool>("Managed")?
            || device.get_property::<u32>("DeviceType")? != 1
        {
            continue;
        }
        let active: OwnedObjectPath = device.get_property("ActiveConnection")?;
        let wired = Proxy::new(
            connection,
            SERVICE,
            path.as_str(),
            "org.freedesktop.NetworkManager.Device.Wired",
        )?;
        connected |= active.as_str() != "/" && wired.get_property::<bool>("Carrier")?;
    }
    Ok(connected)
}
