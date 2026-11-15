use std::{collections::HashMap, fs, thread, time::Duration};

use amane::{Animation, Service};

use zbus::{
    blocking::{Connection, Proxy, connection::Builder},
    zvariant::{ObjectPath, OwnedObjectPath, OwnedValue},
};

use super::{
    Section,
    indicators::{Battery, Bluetooth, Indicator, Network},
};

type Objects = HashMap<OwnedObjectPath, HashMap<String, HashMap<String, OwnedValue>>>;

pub(super) struct Status {
    pub readings: [Reading; 4],
    pub charge_opacity: Animation,
}

impl Service for Status {
    fn new() -> Self {
        Self {
            readings: Section::ALL
                .map(|section| Reading::unavailable(section, "Checking backend…")),
            charge_opacity: Animation::new(0.0).duration(crate::design::duration::NORMAL),
        }
    }

    fn listen() {
        thread::scope(|scope| {
            for (index, section) in Section::ALL.into_iter().enumerate() {
                scope.spawn(move || {
                    let mut bus = None;
                    loop {
                        let result = (|| {
                            if bus.is_none() {
                                bus = Some(connection(section == Section::Tray)?);
                            }
                            read(bus.as_ref().expect("connected bus"), section)
                        })();
                        let fresh = match result {
                            Ok(reading) => reading,
                            Err(error) => {
                                // Reconnect on failure; name ownership is checked on every refresh.
                                bus = None;
                                Reading::unavailable(section, error)
                            }
                        };
                        let changed = Self::read().readings[index] != fresh;
                        if changed {
                            let mut status = Self::write();
                            if let Indicator::Battery(battery) = fresh.indicator {
                                let opacity = if battery.is_some_and(|battery| battery.charging) {
                                    1.0
                                } else {
                                    0.0
                                };
                                status.charge_opacity.to(opacity);
                            }
                            status.readings[index] = fresh;
                        }
                        let interval = if section == Section::Battery {
                            Duration::from_secs(5)
                        } else {
                            Duration::from_secs(2)
                        };
                        thread::sleep(interval);
                    }
                });
            }
        });
    }
}

#[derive(Clone, Debug, PartialEq)]
pub(super) struct Reading {
    pub indicator: Indicator,
    pub message: String,
}

impl Reading {
    pub fn unavailable(section: Section, error: impl std::fmt::Display) -> Self {
        let indicator = match section {
            Section::Tray => Indicator::Tray(0),
            Section::Bluetooth => Indicator::Bluetooth(Bluetooth::default()),
            Section::Wifi => Indicator::Network(Network::default()),
            Section::Battery => Indicator::Battery(None),
        };
        Self {
            indicator,
            message: format!("{} backend unavailable\n{error}", section.label()),
        }
    }
}

pub(super) fn connection(session: bool) -> zbus::Result<Connection> {
    let builder = if session {
        Builder::session()?
    } else {
        Builder::system()?
    };
    builder.method_timeout(Duration::from_secs(2)).build()
}

fn owned(connection: &Connection, name: &str) -> zbus::Result<bool> {
    Proxy::new(
        connection,
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
    )?
    .call("NameHasOwner", &(name,))
}

fn objects(connection: &Connection, name: &str, path: &str) -> zbus::Result<Objects> {
    Proxy::new(connection, name, path, "org.freedesktop.DBus.ObjectManager")?
        .call("GetManagedObjects", &())
}

pub(super) fn read(connection: &Connection, section: Section) -> zbus::Result<Reading> {
    match section {
        Section::Tray => tray(connection),
        Section::Bluetooth => bluetooth(connection),
        Section::Wifi => network(connection),
        Section::Battery => battery(connection),
    }
}

fn tray(connection: &Connection) -> zbus::Result<Reading> {
    if !owned(connection, "org.kde.StatusNotifierWatcher")? {
        return Ok(Reading {
            indicator: Indicator::Tray(0),
            message: "No tray watcher is running.\nAmane tray hosting is not implemented yet."
                .into(),
        });
    }
    let watcher = Proxy::new(
        connection,
        "org.kde.StatusNotifierWatcher",
        "/StatusNotifierWatcher",
        "org.kde.StatusNotifierWatcher",
    )?;
    let items: Vec<String> = watcher.get_property("RegisteredStatusNotifierItems")?;
    Ok(Reading {
        indicator: Indicator::Tray(items.len()),
        message: format!(
            "StatusNotifier watcher reachable.\n{} registered tray items.",
            items.len()
        ),
    })
}

fn boolean(properties: &HashMap<String, OwnedValue>, name: &str) -> bool {
    properties
        .get(name)
        .and_then(|value| bool::try_from(value).ok())
        .unwrap_or(false)
}

fn bluetooth(connection: &Connection) -> zbus::Result<Reading> {
    if !owned(connection, "org.bluez")? {
        return Ok(Reading::unavailable(
            Section::Bluetooth,
            "BlueZ is not running.",
        ));
    }
    let objects = objects(connection, "org.bluez", "/")?;
    // Stable default adapter selection, with connected status across all devices.
    let adapter = objects
        .iter()
        .filter_map(|(path, interfaces)| interfaces.get("org.bluez.Adapter1").map(|p| (path, p)))
        .min_by_key(|(path, _)| path.as_str());
    let Some((_, properties)) = adapter else {
        return Ok(Reading::unavailable(
            Section::Bluetooth,
            "No Bluetooth adapter.",
        ));
    };
    let enabled = boolean(properties, "Powered");
    let connected = objects
        .values()
        .filter_map(|i| i.get("org.bluez.Device1"))
        .any(|device| boolean(device, "Connected"));
    Ok(Reading {
        indicator: Indicator::Bluetooth(Bluetooth { enabled, connected }),
        message: format!("BlueZ reachable.\nEnabled: {enabled}\nConnected devices: {connected}"),
    })
}

fn network(connection: &Connection) -> zbus::Result<Reading> {
    let nm = owned(connection, "org.freedesktop.NetworkManager")?;
    let iwd = owned(connection, "net.connman.iwd")?;
    let mut state = Network::default();
    let mut managed_wifi = false;
    if nm {
        let manager = Proxy::new(
            connection,
            "org.freedesktop.NetworkManager",
            "/org/freedesktop/NetworkManager",
            "org.freedesktop.NetworkManager",
        )?;
        state.enabled = manager.get_property("WirelessEnabled")?;
        let devices: Vec<OwnedObjectPath> = manager.call("GetDevices", &())?;
        for path in devices {
            let device = Proxy::new(
                connection,
                "org.freedesktop.NetworkManager",
                path.as_str(),
                "org.freedesktop.NetworkManager.Device",
            )?;
            if !device.get_property::<bool>("Managed")? {
                continue;
            }
            let kind: u32 = device.get_property("DeviceType")?;
            let active: OwnedObjectPath = device.get_property("ActiveConnection")?;
            if kind == 1 {
                let wired = Proxy::new(
                    connection,
                    "org.freedesktop.NetworkManager",
                    path.as_str(),
                    "org.freedesktop.NetworkManager.Device.Wired",
                )?;
                state.wired |= active.as_str() != "/" && wired.get_property::<bool>("Carrier")?;
            }
            if kind != 2 {
                continue;
            }
            managed_wifi = true;
            state.present = true;
            let wifi = Proxy::new(
                connection,
                "org.freedesktop.NetworkManager",
                path.as_str(),
                "org.freedesktop.NetworkManager.Device.Wireless",
            )?;
            let ap: OwnedObjectPath = wifi.get_property("ActiveAccessPoint")?;
            if active.as_str() != "/" && ap.as_str() != "/" {
                let ap = Proxy::new(
                    connection,
                    "org.freedesktop.NetworkManager",
                    ap,
                    "org.freedesktop.NetworkManager.AccessPoint",
                )?;
                let strength: u8 = ap.get_property("Strength")?;
                state.connected = true;
                state.strength = state.strength.max(f32::from(strength) / 100.0);
            }
        }
    }
    let backend = if use_iwd(managed_wifi, iwd) {
        let wired = state.wired;
        state = standalone_iwd(connection)?;
        state.wired |= wired;
        "Standalone iwd"
    } else if nm {
        "NetworkManager"
    } else {
        "No Wi-Fi backend"
    };
    // Standalone networkd has no NetworkManager device list.
    if !nm {
        state.wired = wired_carrier();
    }
    Ok(Reading {
        indicator: Indicator::Network(state),
        message: format!(
            "{backend}\nWired link: {}\nWi-Fi enabled: {}\nConnected: {}\nSignal: {:.0}%",
            state.wired,
            state.enabled,
            state.connected,
            state.strength * 100.0
        ),
    })
}

fn use_iwd(nm_manages_wifi: bool, iwd_running: bool) -> bool {
    !nm_manages_wifi && iwd_running
}

fn standalone_iwd(connection: &Connection) -> zbus::Result<Network> {
    let objects = objects(connection, "net.connman.iwd", "/")?;
    let mut state = Network::default();
    for (path, interfaces) in &objects {
        let Some(station) = interfaces.get("net.connman.iwd.Station") else {
            continue;
        };
        let powered = interfaces
            .get("net.connman.iwd.Device")
            .is_some_and(|p| boolean(p, "Powered"));
        state.present = true;
        state.enabled |= powered;
        if !powered {
            continue;
        }
        let Some(network) = station
            .get("ConnectedNetwork")
            .and_then(|value| <&ObjectPath>::try_from(value).ok())
        else {
            continue;
        };
        if network.as_str() == "/" {
            continue;
        }
        state.connected = true;
        let station = Proxy::new(
            connection,
            "net.connman.iwd",
            path.as_str(),
            "net.connman.iwd.Station",
        )?;
        // Reads the existing scan cache; never initiates discovery.
        let networks: Vec<(OwnedObjectPath, i16)> = station.call("GetOrderedNetworks", &())?;
        if let Some((_, rssi)) = networks
            .iter()
            .find(|(path, _)| path.as_str() == network.as_str())
        {
            state.strength = state.strength.max(rssi_strength(*rssi));
        }
    }
    Ok(state)
}

fn rssi_strength(hundredths_dbm: i16) -> f32 {
    ((f32::from(hundredths_dbm) / 100.0 + 100.0) / 50.0).clamp(0.0, 1.0)
}

fn wired_carrier() -> bool {
    let Ok(entries) = fs::read_dir("/sys/class/net") else {
        return false;
    };
    entries.flatten().any(|entry| {
        let path = entry.path();
        path.join("device").exists()
            && !path.join("wireless").exists()
            && fs::read_to_string(path.join("type")).is_ok_and(|value| value.trim() == "1")
            && fs::read_to_string(path.join("carrier")).is_ok_and(|value| value.trim() == "1")
    })
}

fn battery(connection: &Connection) -> zbus::Result<Reading> {
    if !owned(connection, "org.freedesktop.UPower")? {
        return Ok(Reading::unavailable(
            Section::Battery,
            "UPower is not running.",
        ));
    }
    let manager = Proxy::new(
        connection,
        "org.freedesktop.UPower",
        "/org/freedesktop/UPower",
        "org.freedesktop.UPower",
    )?;
    let devices: Vec<OwnedObjectPath> = manager.call("EnumerateDevices", &())?;
    let mut has_battery = false;
    for path in devices {
        let device = Proxy::new(
            connection,
            "org.freedesktop.UPower",
            path,
            "org.freedesktop.UPower.Device",
        )?;
        // UPower type 2 is a battery; PowerSupply excludes peripheral batteries.
        if device.get_property::<u32>("Type")? == 2
            && device.get_property::<bool>("PowerSupply")?
            && device.get_property::<bool>("IsPresent")?
        {
            has_battery = true;
            break;
        }
    }
    if !has_battery {
        return Ok(Reading {
            indicator: Indicator::Battery(None),
            message: "UPower reachable.\nNo system battery present.".into(),
        });
    }
    let device = Proxy::new(
        connection,
        "org.freedesktop.UPower",
        "/org/freedesktop/UPower/devices/DisplayDevice",
        "org.freedesktop.UPower.Device",
    )?;
    let percent: f64 = device.get_property("Percentage")?;
    let state: u32 = device.get_property("State")?;
    let battery = Battery::from_upower(percent, state);
    Ok(Reading {
        indicator: Indicator::Battery(Some(battery)),
        message: format!(
            "UPower reachable.\nBattery: {:.0}%\nCharging: {}",
            battery.level * 100.0,
            battery.charging
        ),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn nm_ownership_takes_precedence_over_its_iwd_backend() {
        assert!(!use_iwd(true, true));
        assert!(!use_iwd(true, false));
        assert!(use_iwd(false, true));
        assert!(!use_iwd(false, false));
    }

    #[test]
    fn iwd_signal_is_normalized_and_clamped() {
        for (rssi, expected) in [
            (-12000, 0.0),
            (-10000, 0.0),
            (-7500, 0.5),
            (-5000, 1.0),
            (-3000, 1.0),
        ] {
            assert_eq!(rssi_strength(rssi), expected);
        }
    }

    #[test]
    #[ignore = "read-only smoke check against the live system and session buses"]
    fn live_backends() {
        for section in Section::ALL {
            let connection = connection(section == Section::Tray).unwrap();
            let reading = read(&connection, section).unwrap();
            println!("{}: {reading:?}", section.label());
            assert!(!reading.message.is_empty());
        }
    }
}
