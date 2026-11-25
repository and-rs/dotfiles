use zbus::{
    blocking::{Connection, Proxy},
    zvariant::OwnedObjectPath,
};

use super::{
    State,
    backend::{Adapter, Backend, Snapshot, Wired},
    wired_status,
};

const SERVICE: &str = Backend::NetworkManager.service();
const ROOT: &str = "/org/freedesktop/NetworkManager";
const DEVICE: &str = "org.freedesktop.NetworkManager.Device";

fn adapter(device: &Proxy<'_>) -> Adapter {
    let property = |key| {
        device
            .get_property::<String>(key)
            .ok()
            .filter(|value| !value.is_empty())
    };
    Adapter {
        interface: property("Interface"),
        address: property("HwAddress"),
    }
}

fn security(flags: u32, wpa: u32, rsn: u32) -> Option<&'static str> {
    let keys = wpa | rsn;
    if keys & 0x2000 != 0 {
        return Some("WPA3 Enterprise");
    }
    if keys & 0x200 != 0 {
        return Some("WPA Enterprise");
    }
    if keys & 0x400 != 0 && keys & 0x100 != 0 {
        return Some("WPA2/WPA3 Personal");
    }
    if keys & 0x400 != 0 {
        return Some("WPA3 Personal");
    }
    if keys & 0x1800 != 0 {
        return Some("Enhanced Open");
    }
    if rsn & 0x100 != 0 {
        return Some("WPA2 Personal");
    }
    if wpa & 0x100 != 0 {
        return Some("WPA Personal");
    }
    if keys != 0 {
        return None;
    }
    if flags & 1 != 0 {
        return Some("WEP");
    }
    Some("Open")
}

fn connectivity(manager: &Proxy<'_>) -> Option<&'static str> {
    connectivity_label(
        manager
            .get_property::<bool>("ConnectivityCheckEnabled")
            .ok(),
        manager
            .get_property::<bool>("ConnectivityCheckAvailable")
            .ok(),
        manager.get_property::<u32>("Connectivity").ok(),
    )
}

fn connectivity_label(
    enabled: Option<bool>,
    available: Option<bool>,
    state: Option<u32>,
) -> Option<&'static str> {
    if enabled == Some(false) || available == Some(false) {
        return Some("Not checked");
    }
    match state? {
        0 => Some("Unknown"),
        1 => Some("Offline"),
        2 => Some("Captive portal"),
        3 => Some("Limited"),
        4 if enabled == Some(true) && available == Some(true) => Some("Online"),
        4 => Some("Unknown"),
        _ => None,
    }
}

pub(super) fn read(connection: &Connection) -> zbus::Result<State> {
    let manager = Proxy::new(connection, SERVICE, ROOT, SERVICE)?;
    let enabled: bool = manager.get_property("WirelessEnabled")?;
    let paths: Vec<OwnedObjectPath> = manager.call("GetDevices", &())?;
    let mut snapshot = Snapshot::default();
    let mut wired = Some(Wired::default());
    for path in paths {
        let device = Proxy::new(connection, SERVICE, path.as_str(), DEVICE)?;
        if !device.get_property::<bool>("Managed")? {
            continue;
        }
        match device.get_property::<u32>("DeviceType")? {
            1 => {
                if let Some(status) = wired.as_mut()
                    && read_wired(&device, status).is_err()
                {
                    wired = None;
                }
                continue;
            }
            2 => {}
            _ => continue,
        }
        if !snapshot.present {
            snapshot.adapter = adapter(&device);
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
        if snapshot.record_connection(String::from_utf8_lossy(&ssid).into_owned(), strength) {
            snapshot.adapter = adapter(&device);
            snapshot.security = (|| {
                security(
                    ap.get_property("Flags").ok()?,
                    ap.get_property("WpaFlags").ok()?,
                    ap.get_property("RsnFlags").ok()?,
                )
            })();
        }
    }
    Ok(State {
        wifi: snapshot,
        wired: wired.unwrap_or_else(wired_status),
        connectivity: connectivity(&manager),
        status: Some(Ok(Backend::NetworkManager)),
    })
}

fn read_wired(device: &Proxy<'_>, status: &mut Wired) -> zbus::Result<()> {
    let active: OwnedObjectPath = device.get_property("ActiveConnection")?;
    let wired = Proxy::new(
        device.connection(),
        SERVICE,
        device.path().as_str(),
        "org.freedesktop.NetworkManager.Device.Wired",
    )?;
    if wired.get_property::<bool>("Carrier")? {
        let connected = active.as_str() != "/";
        if status.link.is_none() || (connected && !status.connected) {
            let speed = wired
                .get_property::<u32>("Speed")
                .ok()
                .filter(|speed| *speed > 0);
            status.link = Some((adapter(device), speed));
        }
        status.connected |= connected;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn security_and_connectivity_do_not_guess_missing_states() {
        assert_eq!(security(0, 0, 0), Some("Open"));
        assert_eq!(security(1, 0, 0x500), Some("WPA2/WPA3 Personal"));
        assert_eq!(security(1, 0, 0x800), Some("Enhanced Open"));
        assert_eq!(security(1, 0, 0x10), None);
        assert_eq!(
            connectivity_label(Some(true), Some(true), Some(2)),
            Some("Captive portal")
        );
        assert_eq!(
            connectivity_label(Some(false), Some(true), Some(4)),
            Some("Not checked")
        );
        assert_eq!(
            connectivity_label(Some(true), Some(false), Some(4)),
            Some("Not checked")
        );
        assert_eq!(connectivity_label(None, None, Some(4)), Some("Unknown"));
        assert_eq!(connectivity_label(None, None, None), None);
    }
}
