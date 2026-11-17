mod backend;
mod iwd;
mod network_manager;
#[cfg(test)]
mod tests;
mod view;

pub(super) use view::view;

use std::{fs, thread, time::Duration};

use amane::{Service, Stack, Widget};
use zbus::blocking::Connection;

use backend::{Backend, Error, Snapshot};

use super::{dbus, ui::icon};
use crate::{design::indicator as tokens, theme::Theme};

#[derive(Debug, PartialEq)]
struct State {
    wifi: Snapshot,
    wired: bool,
    status: Option<Result<Backend, Error>>,
}

impl State {
    fn unavailable(error: Error) -> Self {
        Self {
            wifi: Snapshot::default(),
            wired: false,
            status: Some(Err(error)),
        }
    }
}

impl Service for State {
    fn new() -> Self {
        Self {
            wifi: Snapshot::default(),
            wired: false,
            status: None,
        }
    }

    fn listen() {
        let mut bus = None;
        let mut backend = None;
        loop {
            let result = (|| {
                if bus.is_none() {
                    bus = Some(dbus::connection(false)?);
                }
                read(bus.as_ref().expect("connected Wi-Fi bus"), &mut backend)
            })();
            let fresh = match result {
                Ok(state) => state,
                Err(error) => {
                    let unavailable = error == Error::Unavailable;
                    let mut state = Self::unavailable(error);
                    if unavailable {
                        bus = None;
                        backend = None;
                        state.wired = wired_carrier();
                    }
                    state
                }
            };
            if *Self::read() != fresh {
                if let Some(Err(error)) = &fresh.status {
                    eprintln!("wifi: {error}");
                }
                *Self::write() = fresh;
            }
            thread::sleep(Duration::from_secs(2));
        }
    }
}

fn read(connection: &Connection, selected: &mut Option<Backend>) -> Result<State, Error> {
    let backend = match *selected {
        Some(backend) => backend,
        None => {
            let backend = Backend::detect(connection)?;
            *selected = Some(backend);
            backend
        }
    };
    let wifi = backend.read_snapshot(connection)?;
    let wired = match backend {
        Backend::NetworkManager => network_manager::wired_connected(connection)?,
        Backend::Iwd => wired_carrier(),
    };
    Ok(State {
        wifi,
        wired,
        status: Some(Ok(backend)),
    })
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

fn glyph(state: &Snapshot, wired: bool) -> char {
    if wired {
        return '\u{edde}';
    }
    if !state.connected {
        return '\u{e4f2}';
    }
    let strength = state.strength.unwrap_or(0.0);
    if strength > 0.75 {
        return '\u{e4ea}';
    }
    if strength > 0.50 {
        return '\u{e4ee}';
    }
    if strength > 0.25 {
        return '\u{e4ec}';
    }
    '\u{e4f0}'
}

pub(super) fn indicator(theme: &Theme) -> Stack {
    let state = State::read();
    let wifi = &state.wifi;
    let color = if state.wired || (wifi.connected && wifi.enabled) {
        theme.fg
    } else {
        theme.surface4
    };
    let mut layers: Vec<Box<dyn Widget>> = Vec::new();
    if !state.wired && wifi.present {
        layers.push(Box::new(
            icon('\u{e4ea}', theme.surface4).opacity(tokens::GHOST_OPACITY),
        ));
    }
    layers.push(Box::new(icon(glyph(wifi, state.wired), color)));
    Stack::new(layers)
}
