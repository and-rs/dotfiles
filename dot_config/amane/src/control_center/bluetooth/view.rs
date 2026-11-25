use amane::{Button, Center, Column, Parent, Rectangle, Row, Service, Size, Widget, children};

use super::{
    Action, Error, State,
    backend::{Device, Snapshot},
    request,
};
use crate::{
    components::{Button as UiButton, Variant},
    control_center::ui,
    design::{self, padding, spacing, typography},
    theme::Theme,
};

impl State {
    fn status_label(&self) -> String {
        let Some(snapshot) = &self.reading.snapshot else {
            return match &self.reading.error {
                Some(Error::Loading) => "Checking Bluetooth…",
                Some(Error::NoAdapter) => "No Bluetooth adapter",
                Some(Error::PermissionDenied) => "Permission denied",
                _ => "Bluetooth unavailable",
            }
            .into();
        };
        if !snapshot.adapter.powered {
            return "Bluetooth is off".into();
        }
        let names: Vec<_> = snapshot
            .devices
            .iter()
            .filter(|device| device.connected)
            .map(|device| device.name.as_str())
            .collect();
        if names.is_empty() {
            return "Not connected".into();
        }
        format!("Connected to {}", names.join(", "))
    }

    fn feedback(&self) -> Option<(&str, bool)> {
        if let Some(error) = &self.error {
            return Some((error.message(), true));
        }
        if let Some(error) = &self.reading.error {
            return match error {
                Error::Loading => None,
                Error::Failed => Some((
                    "Could not read Bluetooth status. Retrying automatically.",
                    true,
                )),
                _ => Some((error.message(), !matches!(error, Error::NoAdapter))),
            };
        }
        if let Some(action) = &self.pending {
            let label = match action {
                Action::Power(_, true) => "Turning on…",
                Action::Power(_, false) => "Turning off…",
                Action::Scan => "Starting scan…",
                Action::StopScan => unreachable!("stop requests do not become pending actions"),
                Action::Connect(_) => "Connecting…",
                Action::Disconnect(_) => "Disconnecting…",
                Action::Forget(_) => "Forgetting device…",
            };
            return Some((label, false));
        }
        if self.scanning {
            return Some(("Scanning for nearby devices…", false));
        }
        if self
            .reading
            .snapshot
            .as_ref()
            .is_some_and(|s| s.adapter.discovering)
        {
            return Some(("Another application is scanning.", false));
        }
        None
    }
}

fn fixed_height(widget: &impl Widget) -> f32 {
    let Size::Fixed(height) = widget.height() else {
        unreachable!("Bluetooth content has intrinsic height");
    };
    height
}

fn paragraph(label: &str, theme: &Theme, width: f32, error: bool) -> Rectangle {
    let mut text = ui::supporting(label, theme).wrap();
    if error {
        text = text.color(theme.destructive);
    }
    Rectangle::new()
        .width(Parent)
        .height(text.height_in(width))
        .child(text)
}

fn action_button(label: &str, action: Option<Action>, theme: &Theme) -> Rectangle {
    let variant = if matches!(action, Some(Action::Forget(_))) {
        Variant::Destructive
    } else {
        Variant::Secondary
    };
    UiButton::new(format!("bluetooth:{action:?}:{label}"), label, theme)
        .variant(variant)
        .compact()
        .width(Parent)
        .disabled(action.is_none())
        .on_click(move |button| {
            if button == Button::Left
                && let Some(action) = &action
            {
                request(action.clone());
            }
        })
        .build()
}

fn controls(actions: Vec<(&str, Option<Action>)>, theme: &Theme, width: f32) -> Column {
    let minimum_width = actions
        .iter()
        .map(|(label, _)| UiButton::compact_label_width(label, theme))
        .fold(0.0_f32, f32::max);
    let needed = minimum_width * actions.len() as f32
        + spacing::SMALL * actions.len().saturating_sub(1) as f32;
    let buttons = actions
        .into_iter()
        .map(|(label, action)| Box::new(action_button(label, action, theme)) as Box<dyn Widget>)
        .collect();
    if width < needed {
        return Column::new(buttons).width(Parent).gap(spacing::SMALL);
    }
    Column::new(children![
        Row::new(buttons).width(Parent).gap(spacing::SMALL)
    ])
    .width(Parent)
}

fn summary(state: &State, theme: &Theme, width: f32) -> Column {
    let powered = state
        .reading
        .snapshot
        .as_ref()
        .is_some_and(|s| s.adapter.powered);
    let connected = powered
        && state
            .reading
            .snapshot
            .as_ref()
            .is_some_and(|s| s.devices.iter().any(|d| d.connected));
    let (glyph, color) = if connected {
        ('\u{e0dc}', theme.accent)
    } else if powered {
        ('\u{e0da}', theme.fg)
    } else {
        ('\u{e0de}', theme.surface4)
    };
    let mut content = children![
        Row::new(children![
            ui::icon(glyph, color),
            ui::body("Bluetooth", theme).weight(typography::HEADLINE_WEIGHT),
        ])
        .width(Parent)
        .align(Center)
        .gap(spacing::SMALL),
        ui::body(state.status_label(), theme)
            .color(color)
            .elide()
            .max_lines(1),
    ];
    if let Some(snapshot) = &state.reading.snapshot {
        let adapter = &snapshot.adapter;
        let name = if adapter.name.is_empty() {
            "Bluetooth adapter"
        } else {
            &adapter.name
        };
        content.push(Box::new(ui::supporting(name, theme).elide().max_lines(1)));
        let idle = state.pending.is_none();
        let power_label = if powered { "Turn off" } else { "Turn on" };
        let power = Action::Power(adapter.path.clone(), !powered);
        let scan = if state.scanning {
            ("Stop scan", Some(Action::StopScan))
        } else {
            ("Scan", (idle && powered).then_some(Action::Scan))
        };
        content.push(Box::new(controls(
            vec![(power_label, idle.then_some(power)), scan],
            theme,
            width,
        )));
    }
    if let Some((label, error)) = state.feedback() {
        content.push(Box::new(paragraph(label, theme, width, error)));
    }
    if let Some(snapshot) = &state.reading.snapshot
        && snapshot.devices.is_empty()
    {
        let label = if !snapshot.adapter.powered {
            "Turn on Bluetooth to use your devices."
        } else if state.scanning {
            "No devices found yet."
        } else {
            "No saved devices. Scan to find nearby devices."
        };
        content.push(Box::new(paragraph(label, theme, width, false)));
    }
    Column::new(content).width(Parent).gap(spacing::EXTRA_SMALL)
}

fn device_status(device: &Device, pending: Option<&Action>) -> String {
    match pending {
        Some(Action::Connect(path)) if *path == device.path => return "Connecting…".into(),
        Some(Action::Disconnect(path)) if *path == device.path => return "Disconnecting…".into(),
        Some(Action::Forget(path)) if *path == device.path => return "Forgetting…".into(),
        _ => {}
    }
    if device.connected {
        return match device.battery {
            Some(battery) => format!("Connected · Battery {battery}%"),
            None => "Connected".into(),
        };
    }
    if device.paired {
        return "Not connected".into();
    }
    "Not paired".into()
}

fn device_actions(
    device: &Device,
    snapshot: &Snapshot,
    idle: bool,
) -> Vec<(&'static str, Option<Action>)> {
    let mut actions = Vec::new();
    if device.connected {
        actions.push((
            "Disconnect",
            idle.then(|| Action::Disconnect(device.path.clone())),
        ));
    } else if device.paired {
        let action = Action::Connect(device.path.clone());
        actions.push((
            "Connect",
            (idle && action.allowed(snapshot)).then_some(action),
        ));
    }
    if device.paired {
        let action = Action::Forget(device.path.clone());
        actions.push((
            "Forget",
            (idle && action.allowed(snapshot)).then_some(action),
        ));
    }
    actions
}

fn device_card(
    device: &Device,
    snapshot: &Snapshot,
    state: &State,
    theme: &Theme,
    width: f32,
) -> Rectangle {
    let inner_width = (width - padding::NORMAL * 2.0).max(0.0);
    let color = if device.connected {
        theme.accent
    } else {
        theme.fg
    };
    let mut content = children![
        ui::body(&device.name, theme)
            .weight(typography::HEADLINE_WEIGHT)
            .color(color)
            .elide()
            .max_lines(1),
        ui::supporting(device_status(device, state.pending.as_ref()), theme)
            .elide()
            .max_lines(1),
    ];
    if !device.paired && !device.address.is_empty() {
        content.push(Box::new(
            ui::supporting(&device.address, theme).elide().max_lines(1),
        ));
    }
    let actions = device_actions(device, snapshot, state.pending.is_none());
    if !actions.is_empty() {
        content.push(Box::new(controls(actions, theme, inner_width)));
    }
    let content = Column::new(content).width(Parent).gap(spacing::EXTRA_SMALL);
    Rectangle::new()
        .width(Parent)
        .height(fixed_height(&content) + padding::NORMAL * 2.0)
        .padding(padding::NORMAL)
        .fill(theme.surface2)
        .border(design::BORDER_WIDTH, theme.surface2)
        .radius(theme.radius.normal)
        .child(content)
}

fn device_list(state: &State, theme: &Theme, width: f32) -> Column {
    let mut content = Vec::new();
    if let Some(snapshot) = &state.reading.snapshot {
        for (label, paired) in [("Paired devices", true), ("Nearby devices", false)] {
            let devices: Vec<_> = snapshot
                .devices
                .iter()
                .filter(|d| d.paired == paired)
                .collect();
            if devices.is_empty() {
                continue;
            }
            content.push(
                Box::new(ui::body(label, theme).weight(typography::HEADLINE_WEIGHT))
                    as Box<dyn Widget>,
            );
            for device in devices {
                content.push(Box::new(device_card(device, snapshot, state, theme, width)));
            }
        }
    }
    Column::new(content).width(Parent).gap(spacing::SMALL)
}

pub fn view(theme: &Theme, width: f32, height: f32) -> Column {
    content(&State::read(), theme, width, height)
}

fn content(state: &State, theme: &Theme, width: f32, height: f32) -> Column {
    let summary = summary(state, theme, width);
    let list = device_list(state, theme, width);
    let summary_height = fixed_height(&summary);
    let list_height = fixed_height(&list);
    let mut content = children![summary];
    if list_height > 0.0 {
        let available = (height - summary_height - spacing::SMALL).max(0.0);
        if list_height > available {
            content.push(Box::new(crate::components::scroll_area(
                "bluetooth_devices",
                "",
                list,
                width,
                available,
            )));
        } else {
            content.push(Box::new(list));
        }
    }
    Column::new(content).width(width).gap(spacing::SMALL)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        control_center::bluetooth::backend::{Adapter, Reading},
        theme::Radius,
    };
    use amane::Color;
    use zbus::zvariant::OwnedObjectPath;

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

    fn device(name: &str, paired: bool, connected: bool) -> Device {
        Device {
            path: OwnedObjectPath::try_from(format!("/org/bluez/hci0/dev_{}", name.len())).unwrap(),
            name: name.into(),
            address: "00:11:22:33:44:55".into(),
            paired,
            connected,
            battery: None,
        }
    }

    fn state(devices: Vec<Device>) -> State {
        State {
            reading: Reading {
                connected: devices.iter().any(|d| d.connected),
                error: None,
                snapshot: Some(Snapshot {
                    adapter: Adapter {
                        path: OwnedObjectPath::try_from("/org/bluez/hci0").unwrap(),
                        name: "Test adapter".into(),
                        powered: true,
                        discovering: false,
                    },
                    devices,
                }),
            },
            pending: None,
            error: None,
            scanning: false,
        }
    }

    #[test]
    fn summary_reports_loading_off_disconnected_and_all_connected_names() {
        assert_eq!(State::new().status_label(), "Checking Bluetooth…");
        let mut state = state(vec![]);
        assert_eq!(state.status_label(), "Not connected");
        let snapshot = state.reading.snapshot.as_mut().unwrap();
        snapshot.devices = vec![
            device("Headphones", true, true),
            device("Mouse", true, true),
        ];
        assert_eq!(state.status_label(), "Connected to Headphones, Mouse");
        state.reading.snapshot.as_mut().unwrap().adapter.powered = false;
        assert_eq!(state.status_label(), "Bluetooth is off");
    }

    #[test]
    fn cards_show_known_batteries_and_targeted_pending_status() {
        let mut device = device("Headphones", true, true);
        assert_eq!(device_status(&device, None), "Connected");
        device.battery = Some(0);
        assert_eq!(device_status(&device, None), "Connected · Battery 0%");
        let pending = Action::Disconnect(device.path.clone());
        assert_eq!(device_status(&device, Some(&pending)), "Disconnecting…");
        let other = Action::Connect(OwnedObjectPath::try_from("/other").unwrap());
        assert_eq!(
            device_status(&device, Some(&other)),
            "Connected · Battery 0%"
        );
    }

    #[test]
    fn unpaired_devices_have_no_connect_button_and_pending_disables_actions() {
        let state = state(vec![]);
        let snapshot = state.reading.snapshot.as_ref().unwrap();
        assert!(device_actions(&device("Nearby", false, false), snapshot, true).is_empty());
        let paired = device("Saved", true, false);
        let mut snapshot = snapshot.clone();
        snapshot.devices.push(paired.clone());
        assert!(
            device_actions(&paired, &snapshot, true)
                .iter()
                .all(|(_, a)| a.is_some())
        );
        assert!(
            device_actions(&paired, &snapshot, false)
                .iter()
                .all(|(_, a)| a.is_none())
        );
        snapshot.adapter.powered = false;
        assert!(device_actions(&paired, &snapshot, true)[0].1.is_none());
    }

    #[test]
    fn errors_are_readable_and_scanning_has_explicit_feedback() {
        let mut state = state(vec![]);
        state.scanning = true;
        assert_eq!(
            state.feedback(),
            Some(("Scanning for nearby devices…", false))
        );
        state.error = Some(Error::PermissionDenied);
        assert_eq!(
            state.feedback(),
            Some((Error::PermissionDenied.message(), true))
        );
        for error in [
            Error::Unavailable,
            Error::NoAdapter,
            Error::PermissionDenied,
        ] {
            state.reading = Reading::unavailable(error.clone());
            state.error = None;
            assert_eq!(state.feedback().unwrap().0, error.message());
            assert!(!state.feedback().unwrap().0.contains("org."));
        }
        state.reading = Reading::unavailable(Error::Failed);
        assert_eq!(
            state.feedback(),
            Some((
                "Could not read Bluetooth status. Retrying automatically.",
                true
            ))
        );
    }

    #[test]
    fn short_lists_grow_intrinsically_and_only_overflowing_lists_use_the_budget() {
        let theme = theme();
        for state in [
            State::new(),
            state(vec![]),
            state(vec![device("Headphones", true, true)]),
        ] {
            for width in [380.0, 160.0] {
                let summary_height = fixed_height(&summary(&state, &theme, width));
                let list_height = fixed_height(&device_list(&state, &theme, width));
                let gap = if list_height > 0.0 {
                    spacing::SMALL
                } else {
                    0.0
                };
                let full_height = summary_height + gap + list_height;
                assert_eq!(
                    fixed_height(&content(&state, &theme, width, full_height)),
                    full_height
                );
                if list_height > 0.0 {
                    let budget = full_height - list_height / 2.0;
                    assert_eq!(
                        fixed_height(&content(&state, &theme, width, budget)),
                        budget
                    );
                }
            }
        }
    }

    #[test]
    fn actions_keep_parent_width_at_compact_height() {
        let theme = theme();
        let button = action_button("Connect", None, &theme);
        assert_eq!(Widget::width(&button), Parent);
        assert_eq!(fixed_height(&button), design::button::COMPACT_HEIGHT);
        let actions = || vec![("Connect", None), ("Forget", None)];
        assert_eq!(
            fixed_height(&controls(actions(), &theme, 380.0)),
            design::button::COMPACT_HEIGHT
        );
        assert_eq!(
            fixed_height(&controls(actions(), &theme, 100.0)),
            2.0 * design::button::COMPACT_HEIGHT + spacing::SMALL
        );
    }

    #[test]
    fn narrow_controls_stack_and_long_names_do_not_increase_card_height() {
        let theme = theme();
        let state = state(vec![]);
        let snapshot = state.reading.snapshot.as_ref().unwrap();
        let normal = device("Headphones", true, true);
        let long = device(&"Long device name ".repeat(20), true, true);
        assert_eq!(
            fixed_height(&device_card(&normal, snapshot, &state, &theme, 380.0)),
            fixed_height(&device_card(&long, snapshot, &state, &theme, 380.0))
        );
        assert!(
            fixed_height(&device_card(&normal, snapshot, &state, &theme, 160.0))
                > fixed_height(&device_card(&normal, snapshot, &state, &theme, 380.0))
        );
    }
}
