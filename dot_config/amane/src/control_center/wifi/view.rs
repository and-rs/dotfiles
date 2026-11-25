use amane::{Center, Column, End, Parent, Rectangle, Row, Service, Size, Start, Widget, children};

use super::{Error, State, glyph};
use crate::{
    control_center::ui,
    design::{padding, spacing, typography},
    theme::Theme,
};

impl State {
    fn network_label(&self) -> &str {
        if matches!(self.status, Some(Ok(_))) && self.wifi.enabled && self.wifi.connected {
            return self.wifi.network.as_deref().unwrap_or("Unknown network");
        }
        "Wi-Fi"
    }

    fn connection_label(&self) -> &'static str {
        match &self.status {
            None => "Checking Wi-Fi…",
            Some(Err(Error::PermissionDenied(_))) => "Permission denied",
            Some(Err(_)) => "Wi-Fi unavailable",
            Some(Ok(_)) if !self.wifi.present => "No Wi-Fi adapter",
            Some(Ok(_)) if !self.wifi.enabled => "Wi-Fi is off",
            Some(Ok(_)) if self.wifi.connected => "Connected",
            Some(Ok(_)) => "Not connected",
        }
    }

    fn signal_label(&self) -> Option<String> {
        if !matches!(self.status, Some(Ok(_))) || !self.wifi.enabled || !self.wifi.connected {
            return None;
        }
        Some(match self.wifi.strength {
            Some(strength) => format!("Signal {:.0}%", strength * 100.0),
            None => "Signal unknown".into(),
        })
    }

    fn troubleshooting(&self) -> Option<&'static str> {
        match &self.status {
            Some(Err(Error::Unavailable)) => {
                Some("NetworkManager or iwd must be running to read Wi-Fi status.")
            }
            Some(Err(Error::ReadFailed(_))) => {
                Some("Could not read Wi-Fi status. Retrying automatically.")
            }
            _ => None,
        }
    }

    fn detail_values(&self) -> [(&'static str, &'static str); 3] {
        let backend = match &self.status {
            None => "Checking…",
            Some(Ok(backend)) => backend.label(),
            Some(Err(_)) => "Unavailable",
        };
        let wireless = match &self.status {
            None => "Checking…",
            Some(Err(_)) => "Unknown",
            Some(Ok(_)) if !self.wifi.present => "No adapter",
            Some(Ok(_)) if self.wifi.enabled => "Enabled",
            Some(Ok(_)) => "Disabled",
        };
        let wired = match &self.status {
            _ if self.wired.link.is_some() => "Link detected",
            None => "Checking…",
            Some(Err(Error::PermissionDenied(_) | Error::ReadFailed(_))) => "Unknown",
            _ => "No link",
        };
        [
            ("Backend", backend),
            ("Wireless", wireless),
            ("Wired", wired),
        ]
    }

    fn diagnostics(&self) -> impl Iterator<Item = (&'static str, String)> {
        let adapter = self
            .wired
            .link
            .as_ref()
            .map_or(&self.wifi.adapter, |(adapter, _)| adapter);
        [
            ("Interface", adapter.interface.clone()),
            ("Adapter address", adapter.address.clone()),
            ("Wi-Fi security", self.wifi.security.map(str::to_owned)),
            (
                "Ethernet speed",
                self.wired
                    .link
                    .as_ref()
                    .and_then(|(_, speed)| *speed)
                    .map(|speed| format!("{speed} Mbps")),
            ),
            ("Host internet", self.connectivity.map(str::to_owned)),
        ]
        .into_iter()
        .filter_map(|(label, value)| Some((label, value?)))
    }
}

fn summary(state: &State, theme: &Theme) -> Column {
    let color = match &state.status {
        Some(Err(Error::PermissionDenied(_) | Error::ReadFailed(_))) => theme.destructive,
        Some(Ok(_)) if state.wifi.connected && state.wifi.enabled => theme.accent,
        _ => theme.surface4,
    };
    let mut content: Vec<Box<dyn Widget>> = children![
        Row::new(children![
            ui::icon(glyph(&state.wifi, false), color),
            ui::body(state.network_label(), theme)
                .weight(typography::HEADLINE_WEIGHT)
                .elide()
                .max_lines(1),
        ])
        .width(Parent)
        .align(Center)
        .gap(spacing::SMALL),
        ui::body(state.connection_label(), theme)
            .color(color)
            .elide()
            .max_lines(1),
    ];
    if let Some(signal) = state.signal_label() {
        content.push(Box::new(ui::supporting(signal, theme).elide().max_lines(1)));
    }
    Column::new(content).width(Parent).gap(spacing::EXTRA_SMALL)
}

fn detail_row(label: &str, value: &str, theme: &Theme, width: f32) -> Box<dyn Widget> {
    let label = ui::supporting(label, theme);
    let value = ui::body(value, theme);
    let (Size::Fixed(label_width), Size::Fixed(value_width)) =
        (Widget::width(&label), Widget::width(&value))
    else {
        unreachable!("detail text has intrinsic width");
    };
    let column_width = (width - spacing::SMALL).max(0.0) / 2.0;
    if label_width.max(value_width) > column_width {
        return Box::new(
            Column::new(children![
                label.elide().max_lines(1),
                value.elide().max_lines(1)
            ])
            .width(Parent)
            .gap(spacing::TINY),
        );
    }
    Box::new(
        Row::new(children![
            label.elide().max_lines(1),
            Rectangle::new()
                .width(Parent)
                .height(value.height_in(width))
                .align_child(End, Start)
                .child(value),
        ])
        .width(Parent)
        .align(Center)
        .gap(spacing::SMALL),
    )
}

fn details(state: &State, theme: &Theme, width: f32) -> Column {
    let inner_width = (width - padding::NORMAL * 2.0).max(0.0);
    let rows = Column::new(
        state
            .detail_values()
            .into_iter()
            .map(|(label, value)| (label, value.into()))
            .chain(state.diagnostics())
            .map(|(label, value)| detail_row(label, &value, theme, inner_width))
            .collect(),
    )
    .width(Parent)
    .gap(spacing::SMALL);
    let Size::Fixed(rows_height) = Widget::height(&rows) else {
        unreachable!("detail rows have intrinsic height");
    };
    let mut content = children![
        ui::body("Details", theme).weight(typography::HEADLINE_WEIGHT),
        Rectangle::new()
            .width(Parent)
            .height(rows_height + padding::NORMAL * 2.0)
            .padding(padding::NORMAL)
            .fill(theme.surface2)
            .radius(theme.radius.normal)
            .child(rows),
    ];
    if let Some(message) = state.troubleshooting() {
        let guidance = ui::supporting(message, theme).wrap();
        content.push(Box::new(
            Rectangle::new()
                .width(Parent)
                .height(guidance.height_in(width))
                .child(guidance),
        ));
    }
    Column::new(content).width(Parent).gap(spacing::SMALL)
}

pub fn view(theme: &Theme, width: f32) -> Column {
    content(&State::read(), theme, width)
}

fn content(state: &State, theme: &Theme, width: f32) -> Column {
    Column::new(children![
        summary(state, theme),
        details(state, theme, width),
    ])
    .width(width)
    .gap(spacing::SMALL)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        control_center::wifi::backend::{Backend, Snapshot},
        theme::Radius,
    };
    use amane::Color;

    fn theme() -> Theme {
        Theme {
            bg: Color::BLACK,
            fg: Color::WHITE,
            accent: Color::BLUE,
            success: Color::GREEN,
            destructive: Color::RED,
            surface1: Color::rgb(25, 25, 25),
            surface2: Color::rgb(50, 50, 50),
            surface3: Color::rgb(90, 90, 90),
            surface4: Color::rgb(180, 180, 180),
            font: "sans-serif".into(),
            radius: Radius {
                small: 2.0,
                normal: 6.0,
                large: 10.0,
            },
        }
    }

    fn connected(backend: Backend) -> State {
        State {
            wifi: Snapshot {
                present: true,
                enabled: true,
                connected: true,
                network: Some("Home Wi-Fi".into()),
                strength: Some(0.75),
                ..Snapshot::default()
            },
            wired: Default::default(),
            connectivity: None,
            status: Some(Ok(backend)),
        }
    }

    #[test]
    fn presentation_distinguishes_connection_states_without_claiming_internet_access() {
        let mut state = State::new();
        assert_eq!(state.connection_label(), "Checking Wi-Fi…");
        assert_eq!(state.signal_label(), None);
        assert_eq!(state.troubleshooting(), None);
        state.status = Some(Ok(Backend::Iwd));
        assert_eq!(state.connection_label(), "No Wi-Fi adapter");
        state.wifi.present = true;
        assert_eq!(state.connection_label(), "Wi-Fi is off");
        state.wifi.enabled = true;
        assert_eq!(state.connection_label(), "Not connected");
        for backend in [Backend::NetworkManager, Backend::Iwd] {
            let mut state = connected(backend);
            assert_eq!(state.connection_label(), "Connected");
            assert_eq!(state.troubleshooting(), None);
            assert_eq!(state.network_label(), "Home Wi-Fi");
            assert_eq!(state.signal_label().as_deref(), Some("Signal 75%"));
            state.wifi.strength = None;
            assert_eq!(state.signal_label().as_deref(), Some("Signal unknown"));
            state.wifi.enabled = false;
            assert_eq!(state.connection_label(), "Wi-Fi is off");
            assert_eq!(state.network_label(), "Wi-Fi");
            assert_eq!(state.signal_label(), None);
        }
    }

    #[test]
    fn errors_are_readable_and_do_not_expose_raw_bus_messages() {
        for (error, label, guidance) in [
            (
                Error::Unavailable,
                "Wi-Fi unavailable",
                Some("NetworkManager or iwd must be running to read Wi-Fi status."),
            ),
            (
                Error::PermissionDenied("raw D-Bus error".into()),
                "Permission denied",
                None,
            ),
            (
                Error::ReadFailed("raw D-Bus error".into()),
                "Wi-Fi unavailable",
                Some("Could not read Wi-Fi status. Retrying automatically."),
            ),
        ] {
            let state = State::unavailable(error);
            assert_eq!(state.connection_label(), label);
            assert_eq!(state.troubleshooting(), guidance);
            assert_eq!(state.signal_label(), None);
            assert_eq!(state.detail_values()[0], ("Backend", "Unavailable"));
        }
        let mut state = State::unavailable(Error::Unavailable);
        state.wired.link = Some((Default::default(), None));
        assert_eq!(state.detail_values()[2], ("Wired", "Link detected"));
        assert_eq!(state.connection_label(), "Wi-Fi unavailable");
    }

    #[test]
    fn diagnostics_only_show_known_values_and_keep_ethernet_details_together() {
        let mut state = connected(Backend::NetworkManager);
        assert_eq!(state.diagnostics().count(), 0);
        state.wifi.adapter.interface = Some("wlan0".into());
        state.wifi.security = Some("WPA2 Personal");
        state.wired.link = Some((
            super::super::backend::Adapter {
                interface: Some("eth0".into()),
                address: None,
            },
            Some(1000),
        ));
        state.connectivity = Some("Captive portal");
        assert_eq!(
            state.diagnostics().collect::<Vec<_>>(),
            [
                ("Interface", "eth0".into()),
                ("Wi-Fi security", "WPA2 Personal".into()),
                ("Ethernet speed", "1000 Mbps".into()),
                ("Host internet", "Captive portal".into()),
            ]
        );
    }

    #[test]
    fn panel_grows_to_fit_summary_and_details_without_a_scroll_viewport() {
        let theme = theme();
        let states = [
            State::new(),
            connected(Backend::Iwd),
            connected(Backend::NetworkManager),
            State::unavailable(Error::Unavailable),
            State::unavailable(Error::ReadFailed("offline".into())),
        ];
        for state in &states {
            for width in [380.0, 160.0] {
                let panel = content(state, &theme, width);
                assert_eq!(Widget::width(&panel), Size::Fixed(width));
                let Size::Fixed(summary_height) = Widget::height(&summary(state, &theme)) else {
                    panic!("intrinsic summary height");
                };
                let Size::Fixed(details_height) = Widget::height(&details(state, &theme, width))
                else {
                    panic!("intrinsic details height");
                };
                assert_eq!(
                    Widget::height(&panel),
                    Size::Fixed(summary_height + spacing::SMALL + details_height),
                );
            }
        }
        let state = connected(Backend::NetworkManager);
        let Size::Fixed(wide) = Widget::height(&content(&state, &theme, 380.0)) else {
            panic!("intrinsic height")
        };
        let Size::Fixed(narrow) = Widget::height(&content(&state, &theme, 160.0)) else {
            panic!("intrinsic height")
        };
        assert!(narrow > wide);
    }
}
