use std::{fs, thread, time::Duration};

use amane::{Column, Parent, Service, Stack, Widget, children};
use zbus::{
    blocking::{Connection, Proxy},
    zvariant::{ObjectPath, OwnedObjectPath},
};

use super::{
    dbus,
    ui::{icon, text},
};
use crate::{
    design::{control_center as layout, indicator as tokens, spacing},
    theme::Theme,
};

#[derive(Clone, Copy, Debug, Default, PartialEq)]
struct Network {
    wired: bool,
    present: bool,
    enabled: bool,
    connected: bool,
    strength: f32,
}

#[derive(Debug, PartialEq)]
struct State {
    network: Network,
    message: String,
}

impl State {
    fn unavailable(error: impl std::fmt::Display) -> Self {
        Self {
            network: Network::default(),
            message: format!("Wi-Fi backend unavailable\n{error}"),
        }
    }
}

impl Service for State {
    fn new() -> Self {
        Self::unavailable("Checking backend…")
    }

    fn listen() {
        let mut bus = None;
        loop {
            let result = (|| {
                if bus.is_none() {
                    bus = Some(dbus::connection(false)?);
                }
                read(bus.as_ref().expect("connected Wi-Fi bus"))
            })();
            let fresh = match result {
                Ok(state) => state,
                Err(error) => {
                    bus = None;
                    Self::unavailable(error)
                }
            };
            if *Self::read() != fresh {
                *Self::write() = fresh;
            }
            thread::sleep(Duration::from_secs(2));
        }
    }
}

fn read(connection: &Connection) -> zbus::Result<State> {
    let nm = dbus::owned(connection, "org.freedesktop.NetworkManager")?;
    let iwd = dbus::owned(connection, "net.connman.iwd")?;
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
    Ok(State {
        network: state,
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
    let objects = dbus::objects(connection, "net.connman.iwd", "/")?;
    let mut state = Network::default();
    for (path, interfaces) in &objects {
        let Some(station) = interfaces.get("net.connman.iwd.Station") else {
            continue;
        };
        let powered = interfaces
            .get("net.connman.iwd.Device")
            .is_some_and(|p| dbus::boolean(p, "Powered"));
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

fn glyph(state: Network) -> char {
    if state.wired {
        return '\u{edde}';
    }
    if !state.connected {
        return '\u{e4f2}';
    }
    if state.strength > 0.75 {
        return '\u{e4ea}';
    }
    if state.strength > 0.50 {
        return '\u{e4ee}';
    }
    if state.strength > 0.25 {
        return '\u{e4ec}';
    }
    '\u{e4f0}'
}

pub(super) fn indicator(theme: &Theme) -> Stack {
    let state = State::read().network;
    let color = if state.wired || (state.connected && state.enabled) {
        theme.fg
    } else {
        theme.surface4
    };
    let mut layers: Vec<Box<dyn Widget>> = Vec::new();
    if !state.wired && state.present {
        layers.push(Box::new(
            icon('\u{e4ea}', theme.surface4).opacity(tokens::GHOST_OPACITY),
        ));
    }
    layers.push(Box::new(icon(glyph(state), color)));
    Stack::new(layers)
}

pub(super) fn view(theme: &Theme) -> Column {
    let state = State::read();
    Column::new(children![
        text("Wi-Fi", theme),
        text(&state.message, theme)
            .wrap()
            .max_lines(layout::PREVIEW_LINES)
            .elide(),
        text("Read-only backend preview", theme),
    ])
    .width(Parent)
    .gap(spacing::SMALL)
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
    fn thresholds_are_strict_and_wired_takes_precedence() {
        let mut state = Network {
            connected: true,
            ..Network::default()
        };
        for (strength, expected) in [
            (0.0, '\u{e4f0}'),
            (0.25, '\u{e4f0}'),
            (0.251, '\u{e4ec}'),
            (0.50, '\u{e4ec}'),
            (0.501, '\u{e4ee}'),
            (0.75, '\u{e4ee}'),
            (0.751, '\u{e4ea}'),
            (1.0, '\u{e4ea}'),
        ] {
            state.strength = strength;
            assert_eq!(glyph(state), expected);
        }
        state.connected = false;
        assert_eq!(glyph(state), '\u{e4f2}');
        state.wired = true;
        assert_eq!(glyph(state), '\u{edde}');
    }

    #[test]
    #[ignore = "read-only smoke check against the live system bus"]
    fn live_backend() {
        let state = read(&dbus::connection(false).unwrap()).unwrap();
        println!("{state:?}");
        assert!(!state.message.is_empty());
    }
}
