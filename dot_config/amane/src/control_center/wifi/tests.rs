use std::collections::HashMap;

use zbus::{
    blocking::connection::Builder,
    zvariant::{OwnedObjectPath, OwnedValue, Value},
};

use super::*;
use crate::control_center::dbus::Objects;

#[derive(Clone, Copy)]
struct Station {
    enabled: bool,
    connected: bool,
    strength: Option<u8>,
    name: &'static str,
}

const CONNECTED: Station = Station {
    enabled: true,
    connected: true,
    strength: Some(50),
    name: "Test Wi-Fi",
};

#[derive(Clone, Copy)]
enum Fault {
    Denied,
    Failed,
    MissingDevice,
}

fn check_fault(fault: Option<Fault>) -> zbus::fdo::Result<()> {
    match fault {
        Some(Fault::Denied) => Err(zbus::fdo::Error::AccessDenied("Test denial".into())),
        Some(Fault::Failed) => Err(zbus::fdo::Error::Failed("Test read failure".into())),
        _ => Ok(()),
    }
}

fn path(value: &str) -> OwnedObjectPath {
    OwnedObjectPath::try_from(value).unwrap()
}

fn device_path(index: usize) -> OwnedObjectPath {
    path(&format!("/test/device{index}"))
}

fn ap_path(index: usize) -> OwnedObjectPath {
    path(&format!("/test/ap{index}"))
}

struct NmManager {
    devices: Vec<OwnedObjectPath>,
    enabled: bool,
    fault: Option<Fault>,
}

#[zbus::interface(name = "org.freedesktop.NetworkManager")]
impl NmManager {
    #[zbus(property)]
    fn wireless_enabled(&self) -> bool {
        self.enabled
    }

    fn get_devices(&self) -> zbus::fdo::Result<Vec<OwnedObjectPath>> {
        check_fault(self.fault)?;
        Ok(self.devices.clone())
    }
}

struct NmDevice {
    station: Station,
    kind: u32,
}

#[zbus::interface(name = "org.freedesktop.NetworkManager.Device")]
impl NmDevice {
    #[zbus(property)]
    fn managed(&self) -> bool {
        true
    }

    #[zbus(property)]
    fn device_type(&self) -> u32 {
        self.kind
    }

    #[zbus(property)]
    fn active_connection(&self) -> OwnedObjectPath {
        if self.station.connected {
            return path("/test/connection");
        }
        path("/")
    }
}

struct NmWireless {
    station: Station,
    index: usize,
}

#[zbus::interface(name = "org.freedesktop.NetworkManager.Device.Wireless")]
impl NmWireless {
    #[zbus(property)]
    fn active_access_point(&self) -> OwnedObjectPath {
        if self.station.connected {
            return ap_path(self.index);
        }
        path("/")
    }
}

struct NmAccessPoint(Station);

#[zbus::interface(name = "org.freedesktop.NetworkManager.AccessPoint")]
impl NmAccessPoint {
    #[zbus(property)]
    fn strength(&self) -> zbus::fdo::Result<u8> {
        self.0
            .strength
            .ok_or_else(|| zbus::fdo::Error::UnknownProperty("Signal unavailable".into()))
    }

    #[zbus(property, name = "Ssid")]
    fn ssid(&self) -> Vec<u8> {
        self.0.name.as_bytes().to_vec()
    }
}

struct NmWired(bool);

#[zbus::interface(name = "org.freedesktop.NetworkManager.Device.Wired")]
impl NmWired {
    #[zbus(property)]
    fn carrier(&self) -> bool {
        self.0
    }
}

struct IwdManager {
    stations: Vec<Station>,
    fault: Option<Fault>,
}

fn properties(values: Vec<(&str, Value<'_>)>) -> HashMap<String, OwnedValue> {
    values
        .into_iter()
        .map(|(key, value)| (key.into(), value.try_to_owned().unwrap()))
        .collect()
}

#[zbus::interface(name = "org.freedesktop.DBus.ObjectManager")]
impl IwdManager {
    fn get_managed_objects(&self) -> zbus::fdo::Result<Objects> {
        check_fault(self.fault)?;
        Ok(self
            .stations
            .iter()
            .enumerate()
            .map(|(index, station)| {
                let mut station_properties = HashMap::new();
                // iwd omits ConnectedNetwork while disconnected.
                if station.connected {
                    station_properties =
                        properties(vec![("ConnectedNetwork", Value::from(ap_path(index)))]);
                }
                (
                    device_path(index),
                    HashMap::from([
                        (
                            "net.connman.iwd.Device".into(),
                            properties(vec![("Powered", station.enabled.into())]),
                        ),
                        ("net.connman.iwd.Station".into(), station_properties),
                    ]),
                )
            })
            .collect())
    }
}

struct IwdStation {
    station: Station,
    index: usize,
}

struct IwdNetwork(&'static str);

#[zbus::interface(name = "net.connman.iwd.Network")]
impl IwdNetwork {
    #[zbus(property)]
    fn name(&self) -> &str {
        self.0
    }
}

#[zbus::interface(name = "net.connman.iwd.Station")]
impl IwdStation {
    fn get_ordered_networks(&self) -> Vec<(OwnedObjectPath, i16)> {
        if let Some(strength) = self.station.strength {
            return vec![(ap_path(self.index), -10000 + i16::from(strength) * 50)];
        }
        // A different cached network must not supply this connection's signal.
        vec![(path("/test/other_network"), -5000)]
    }
}

fn fixture(
    backend: Backend,
    stations: &[Station],
    fault: Option<Fault>,
    wired: Option<(bool, bool)>,
) -> Connection {
    let mut builder = Builder::session().unwrap().name(backend.service()).unwrap();
    match backend {
        Backend::NetworkManager => {
            let mut devices: Vec<_> = (0..stations.len()).map(device_path).collect();
            if let Some((active, carrier)) = wired {
                let wired_path = path("/test/wired");
                devices.push(wired_path.clone());
                builder = builder
                    .serve_at(
                        wired_path.clone(),
                        NmDevice {
                            station: Station {
                                connected: active,
                                ..CONNECTED
                            },
                            kind: 1,
                        },
                    )
                    .unwrap()
                    .serve_at(wired_path, NmWired(carrier))
                    .unwrap();
            }
            builder = builder
                .serve_at(
                    "/org/freedesktop/NetworkManager",
                    NmManager {
                        devices,
                        enabled: stations.iter().any(|station| station.enabled),
                        fault,
                    },
                )
                .unwrap();
            if !matches!(fault, Some(Fault::MissingDevice)) {
                for (index, station) in stations.iter().copied().enumerate() {
                    builder = builder
                        .serve_at(device_path(index), NmDevice { station, kind: 2 })
                        .unwrap()
                        .serve_at(device_path(index), NmWireless { station, index })
                        .unwrap()
                        .serve_at(ap_path(index), NmAccessPoint(station))
                        .unwrap();
                }
            }
        }
        Backend::Iwd => {
            builder = builder
                .serve_at(
                    "/",
                    IwdManager {
                        stations: stations.to_vec(),
                        fault,
                    },
                )
                .unwrap();
            if !matches!(fault, Some(Fault::MissingDevice)) {
                for (index, station) in stations.iter().copied().enumerate() {
                    builder = builder
                        .serve_at(device_path(index), IwdStation { station, index })
                        .unwrap()
                        .serve_at(ap_path(index), IwdNetwork(station.name))
                        .unwrap();
                }
            }
        }
    }
    builder.build().unwrap()
}

fn release(server: &Connection, backend: Backend) {
    assert!(server.release_name(backend.service()).unwrap());
}

#[test]
#[ignore = "run under dbus-run-session; uses fake NM and iwd services on the session bus only"]
fn fake_backends_share_the_snapshot_contract() {
    let client = dbus::connection(true).unwrap();
    let present = Snapshot {
        present: true,
        ..Snapshot::default()
    };
    let enabled = Snapshot {
        enabled: true,
        ..present.clone()
    };
    let connected = Snapshot {
        connected: true,
        network: Some(CONNECTED.name.into()),
        strength: Some(0.5),
        ..enabled.clone()
    };
    let scenarios = [
        ("no adapter", vec![], Snapshot::default()),
        (
            "disabled",
            vec![Station {
                enabled: false,
                connected: false,
                strength: None,
                ..CONNECTED
            }],
            present,
        ),
        (
            "disconnected",
            vec![Station {
                connected: false,
                ..CONNECTED
            }],
            enabled,
        ),
        ("connected", vec![CONNECTED], connected.clone()),
        (
            "unknown signal",
            vec![Station {
                strength: None,
                ..CONNECTED
            }],
            Snapshot {
                strength: None,
                ..connected.clone()
            },
        ),
        (
            "zero signal",
            vec![Station {
                strength: Some(0),
                ..CONNECTED
            }],
            Snapshot {
                strength: Some(0.0),
                ..connected.clone()
            },
        ),
        (
            "multiple adapters",
            vec![
                Station {
                    strength: Some(25),
                    name: "Other Wi-Fi",
                    ..CONNECTED
                },
                Station {
                    strength: Some(75),
                    name: "Strong Wi-Fi",
                    ..CONNECTED
                },
                Station {
                    strength: None,
                    ..CONNECTED
                },
            ],
            Snapshot {
                strength: Some(0.75),
                network: Some("Strong Wi-Fi".into()),
                ..connected.clone()
            },
        ),
        (
            "unicode network",
            vec![Station {
                name: "Café 家",
                ..CONNECTED
            }],
            Snapshot {
                network: Some("Café 家".into()),
                ..connected.clone()
            },
        ),
        (
            "hidden network name",
            vec![Station {
                name: "",
                ..CONNECTED
            }],
            Snapshot {
                network: None,
                ..connected.clone()
            },
        ),
        (
            "equal signals use a stable network",
            vec![
                Station {
                    name: "Zebra",
                    ..CONNECTED
                },
                Station {
                    name: "Alpha",
                    ..CONNECTED
                },
            ],
            Snapshot {
                network: Some("Alpha".into()),
                ..connected.clone()
            },
        ),
    ];
    for backend in [Backend::NetworkManager, Backend::Iwd] {
        for (name, stations, expected) in &scenarios {
            let server = fixture(backend, stations, None, None);
            assert_eq!(Backend::detect(&client).unwrap(), backend);
            assert_eq!(
                backend.read_snapshot(&client).unwrap(),
                *expected,
                "{backend:?}: {name}"
            );
            release(&server, backend);
        }
        for fault in [Fault::Denied, Fault::Failed, Fault::MissingDevice] {
            let server = fixture(backend, &[CONNECTED], Some(fault), None);
            let error = backend.read_snapshot(&client).unwrap_err();
            match fault {
                Fault::Denied => assert!(matches!(error, Error::PermissionDenied(_)), "{error:?}"),
                _ => assert!(matches!(error, Error::ReadFailed(_)), "{error:?}"),
            }
            release(&server, backend);
        }
        let server = fixture(backend, &[CONNECTED], None, None);
        assert_eq!(backend.read_snapshot(&client).unwrap(), connected);
        release(&server, backend);
        assert_eq!(backend.read_snapshot(&client), Err(Error::Unavailable));
        assert_eq!(Backend::detect(&client), Err(Error::Unavailable));
        server.request_name(backend.service()).unwrap();
        assert_eq!(
            Backend::detect(&client)
                .unwrap()
                .read_snapshot(&client)
                .unwrap(),
            connected
        );
        release(&server, backend);
    }

    // Selection depends on service presence, not managed Wi-Fi devices.
    let nm = fixture(Backend::NetworkManager, &[], Some(Fault::Failed), None);
    let iwd = fixture(Backend::Iwd, &[CONNECTED], None, None);
    let mut selected = None;
    assert!(matches!(
        read(&client, &mut selected),
        Err(Error::ReadFailed(_))
    ));
    assert_eq!(selected, Some(Backend::NetworkManager));
    assert_eq!(Backend::detect(&client).unwrap(), Backend::NetworkManager);
    release(&nm, Backend::NetworkManager);
    assert_eq!(Backend::detect(&client).unwrap(), Backend::Iwd);
    release(&iwd, Backend::Iwd);

    // Wired detection stays outside the Wi-Fi snapshot and retains NM semantics.
    for (active, carrier, expected) in [
        (false, true, false),
        (true, false, false),
        (true, true, true),
    ] {
        let server = fixture(Backend::NetworkManager, &[], None, Some((active, carrier)));
        assert_eq!(
            Backend::NetworkManager.read_snapshot(&client).unwrap(),
            Snapshot::default()
        );
        assert_eq!(network_manager::wired_connected(&client).unwrap(), expected);
        release(&server, Backend::NetworkManager);
    }
}

#[test]
fn thresholds_are_strict_and_wired_takes_precedence() {
    let mut state = Snapshot {
        connected: true,
        ..Snapshot::default()
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
        state.strength = Some(strength);
        assert_eq!(glyph(&state, false), expected);
    }
    state.strength = None;
    assert_eq!(glyph(&state, false), '\u{e4f0}');
    state.connected = false;
    assert_eq!(glyph(&state, false), '\u{e4f2}');
    assert_eq!(glyph(&state, true), '\u{edde}');
}

#[test]
#[ignore = "read-only smoke check against the live system bus"]
fn live_backend() {
    let state = read(&dbus::connection(false).unwrap(), &mut None).unwrap();
    println!("{state:?}");
    assert!(matches!(state.status, Some(Ok(_))));
}
