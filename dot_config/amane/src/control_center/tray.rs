use std::{thread, time::Duration};

use amane::{Column, Parent, Rectangle, Service, children};
use zbus::blocking::{Connection, Proxy};

use super::{
    dbus,
    ui::{icon, text},
};
use crate::{
    design::{control_center as layout, spacing},
    theme::Theme,
};

#[derive(Debug, PartialEq)]
struct State {
    items: usize,
    message: String,
}

impl State {
    fn unavailable(error: impl std::fmt::Display) -> Self {
        Self {
            items: 0,
            message: format!("Tray backend unavailable\n{error}"),
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
                    bus = Some(dbus::connection(true)?);
                }
                read(bus.as_ref().expect("connected tray bus"))
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
    if !dbus::owned(connection, "org.kde.StatusNotifierWatcher")? {
        return Ok(State {
            items: 0,
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
    Ok(State {
        items: items.len(),
        message: format!(
            "StatusNotifier watcher reachable.\n{} registered tray items.",
            items.len()
        ),
    })
}

fn glyph(items: usize) -> char {
    if items > 0 {
        return '\u{e136}';
    }
    '\u{ece0}'
}

pub(super) fn indicator(theme: &Theme) -> Rectangle {
    let state = State::read();
    let color = if state.items > 0 {
        theme.fg
    } else {
        theme.surface4
    };
    icon(glyph(state.items), color)
}

pub(super) fn view(theme: &Theme) -> Column {
    let state = State::read();
    Column::new(children![
        text("Tray", theme),
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
    fn empty_and_populated_trays_use_distinct_glyphs() {
        assert_eq!(glyph(0), '\u{ece0}');
        assert_eq!(glyph(2), '\u{e136}');
    }

    #[test]
    #[ignore = "read-only smoke check against the live session bus"]
    fn live_backend() {
        let state = read(&dbus::connection(true).unwrap()).unwrap();
        println!("{state:?}");
        assert!(!state.message.is_empty());
    }
}
