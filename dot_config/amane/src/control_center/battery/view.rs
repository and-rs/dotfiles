use amane::{
    Button, Center, Column, End, Parent, Rectangle, Row, Service, Size, Start, Widget, children,
};

use super::{Details, ProfileState, Profiles, Reading, Status, duration, request_profile};
use crate::{
    components::{Button as UiButton, Variant},
    control_center::ui,
    design::{battery as layout, spacing},
    theme::Theme,
};

impl Details {
    fn status(&self) -> String {
        let state = match self.state {
            1 => "Charging",
            2 => "On battery",
            3 => "Battery empty",
            4 => "Fully charged",
            5 => "Plugged in · Waiting to charge",
            6 => "Waiting to discharge",
            _ => "Battery status unknown",
        };
        let estimate = match self.state {
            1 => duration(self.time_to_full).map(|time| format!("{time} until full")),
            2 => duration(self.time_to_empty).map(|time| format!("{time} remaining")),
            _ => None,
        };
        if let Some(estimate) = estimate {
            return format!("{state} · {estimate}");
        }
        state.into()
    }

    fn metrics(&self) -> Vec<(&'static str, String)> {
        let mut metrics = Vec::new();
        if let Some(health) = self.health.filter(|health| health.is_finite()) {
            metrics.push(("Health", format!("{health:.0}%")));
        }
        if self.energy.is_finite()
            && self.energy >= 0.0
            && self.energy_full.is_finite()
            && self.energy_full > 0.0
        {
            metrics.push((
                "Energy",
                format!("{:.1} / {:.1} Wh", self.energy, self.energy_full),
            ));
        }
        if self.rate.is_finite() && self.rate.abs() > 0.0 {
            let label = if matches!(self.state, 1 | 5) {
                "Charge rate"
            } else {
                "Power draw"
            };
            metrics.push((label, format!("{:.1} W", self.rate.abs())));
        }
        metrics
    }
}

fn summary(reading: &Reading, theme: &Theme, width: f32) -> Column {
    let (title, subtitle, level) = match reading {
        Reading::Ready { battery, details } => (
            format!("{:.0}%", battery.level * 100.0),
            details.status(),
            Some(battery.level),
        ),
        Reading::Loading => ("Battery".into(), "Checking battery…".into(), None),
        Reading::Absent => (
            "No battery".into(),
            "No system battery detected.".into(),
            None,
        ),
        Reading::Unavailable(_) => (
            "Battery unavailable".into(),
            "Battery information couldn't be read.".into(),
            None,
        ),
    };
    let critical = level.is_some_and(|level| level < 0.2);
    let color = if critical {
        theme.destructive
    } else if level.is_some() {
        theme.accent
    } else {
        theme.surface4
    };
    let glyph = match level {
        Some(level) if level < 0.2 => '\u{e0c8}',
        Some(level) if level < 0.5 => '\u{e0c6}',
        Some(level) if level < 0.8 => '\u{e0c2}',
        Some(_) => '\u{e0c0}',
        None => '\u{e0be}',
    };
    let subtitle_color = if critical {
        theme.destructive
    } else {
        theme.surface4
    };
    let mut meter = Rectangle::new().width(Parent).height(layout::METER_HEIGHT);
    if let Some(level) = level {
        meter = meter
            .fill(theme.surface2)
            .radius(theme.radius.small)
            .clip()
            .child(
                Rectangle::new()
                    .width(width * level)
                    .height(Parent)
                    .fill(color),
            );
    }
    Column::new(children![
        Column::new(children![
            Row::new(children![
                ui::headline(title, theme).elide().max_lines(1),
                ui::icon(glyph, color),
            ])
            .width(Parent)
            .align(Center)
            .gap(spacing::SMALL),
            ui::supporting(subtitle, theme)
                .color(subtitle_color)
                .elide()
                .max_lines(1),
        ])
        .width(Parent)
        .gap(spacing::TINY),
        meter,
    ])
    .width(Parent)
    .gap(spacing::SMALL)
}

struct Mode {
    active: bool,
    available: bool,
    clickable: bool,
    status: &'static str,
}

impl Mode {
    fn new(profile: &str, profiles: &Profiles) -> Self {
        let state = profiles
            .state
            .as_ref()
            .and_then(|state| state.as_ref().ok());
        let active = state.is_some_and(|state| state.active == profile);
        let available = state.is_some_and(|state| state.can_select(profile));
        let status = if profiles.pending.as_deref() == Some(profile) {
            "Applying…"
        } else if active {
            "✓ Selected"
        } else if state.is_some() && !available {
            "Unavailable"
        } else {
            ""
        };
        Self {
            active,
            available,
            clickable: available && !active && profiles.pending.is_none(),
            status,
        }
    }
}

fn mode_button(
    profile: &'static str,
    label: &str,
    profiles: &Profiles,
    theme: &Theme,
) -> Rectangle {
    let mode = Mode::new(profile, profiles);
    let color = if mode.active {
        theme.accent
    } else if mode.available {
        theme.fg
    } else {
        theme.surface4
    };
    let content = Column::new(children![
        ui::body(label, theme).color(color).elide().max_lines(1),
        ui::supporting(mode.status, theme)
            .color(color)
            .elide()
            .max_lines(1),
    ])
    .width(Parent)
    .gap(spacing::TINY);
    let Size::Fixed(content_height) = Widget::height(&content) else {
        unreachable!("power mode labels have intrinsic heights");
    };
    UiButton::new(format!("power_mode:{profile}"), "", theme)
        .variant(Variant::Secondary)
        .selected(mode.active)
        .disabled(!mode.clickable)
        .width(Parent)
        .height(layout::MODE_HEIGHT.max(content_height + layout::MODE_PADDING * 2.0))
        .padding(layout::MODE_PADDING)
        .content(content)
        .on_click(move |button| {
            if button == Button::Left {
                request_profile(profile);
            }
        })
        .build()
}

fn mode_selector(profiles: &Profiles, theme: &Theme, width: f32) -> Column {
    let modes = [
        ("power-saver", "Power saver"),
        ("balanced", "Balanced"),
        ("performance", "Performance"),
    ];
    let minimum_width = modes
        .iter()
        .map(|(_, label)| {
            let Size::Fixed(width) = Widget::width(&ui::body(*label, theme)) else {
                unreachable!("unwrapped mode labels have intrinsic widths");
            };
            width + layout::MODE_PADDING * 2.0
        })
        .fold(0.0_f32, f32::max);
    let needed =
        minimum_width * modes.len() as f32 + spacing::EXTRA_SMALL * (modes.len() - 1) as f32;
    let buttons = modes
        .into_iter()
        .map(|(profile, label)| {
            Box::new(mode_button(profile, label, profiles, theme)) as Box<dyn Widget>
        })
        .collect();
    if width < needed {
        return Column::new(buttons).width(Parent).gap(spacing::EXTRA_SMALL);
    }
    Column::new(children![
        Row::new(buttons).width(Parent).gap(spacing::EXTRA_SMALL)
    ])
    .width(Parent)
}

fn restriction(reason: &str, inhibited: bool) -> &'static str {
    match reason {
        "lap-detected" => "Performance unavailable while the laptop is on your lap.",
        "high-operating-temperature" => "Performance limited to keep the system cool.",
        "power-supply" => "Connect a suitable power supply for full performance.",
        _ if inhibited => "Performance is unavailable on this system right now.",
        _ => "Performance is currently limited by the system.",
    }
}

fn action_error(error: &str) -> &'static str {
    let error = error.to_ascii_lowercase();
    if error.contains("accessdenied")
        || error.contains("notauthorized")
        || error.contains("permission")
    {
        return "Permission denied. Check your system's power settings.";
    }
    "Could not change power mode. Try again."
}

fn feedback(profiles: &Profiles) -> (&str, bool) {
    if let Some(error) = &profiles.error {
        return (action_error(error), true);
    }
    match &profiles.state {
        None => ("Checking available power modes…", false),
        Some(Err(_)) => ("Power modes aren't available on this system.", false),
        Some(Ok(state)) if !state.inhibited.is_empty() => {
            (restriction(&state.inhibited, true), false)
        }
        Some(Ok(state)) if !state.degraded.is_empty() => {
            (restriction(&state.degraded, false), false)
        }
        _ => ("", false),
    }
}

fn detail_content(
    reading: &Reading,
    state: Option<&ProfileState>,
    theme: &Theme,
    width: f32,
) -> Column {
    let mut content: Vec<Box<dyn Widget>> = Vec::new();
    if let Reading::Ready { details, .. } = reading {
        let metrics: Vec<_> = details
            .metrics()
            .into_iter()
            .map(|(label, value)| (ui::supporting(label, theme), ui::body(value, theme)))
            .collect();
        let label_width = metrics
            .iter()
            .map(|(label, _)| {
                let Size::Fixed(width) = Widget::width(label) else {
                    unreachable!("unwrapped detail labels have intrinsic widths");
                };
                width
            })
            .fold(layout::DETAIL_LABEL_WIDTH, f32::max);
        let stacked = metrics.iter().any(|(_, value)| {
            let Size::Fixed(value_width) = Widget::width(value) else {
                unreachable!("unwrapped detail values have intrinsic widths");
            };
            label_width + spacing::SMALL + value_width > width
        });
        if !metrics.is_empty() {
            content.push(Box::new(ui::body("Details", theme)));
        }
        for (label, value) in metrics {
            if stacked {
                content.push(Box::new(
                    Column::new(children![
                        label.elide().max_lines(1),
                        value.elide().max_lines(1),
                    ])
                    .width(Parent)
                    .gap(spacing::TINY),
                ));
                continue;
            }
            content.push(Box::new(
                Row::new(children![
                    Rectangle::new()
                        .width(label_width)
                        .height(label.height_in(width))
                        .clip()
                        .child(label),
                    Rectangle::new()
                        .width(Parent)
                        .height(value.height_in(width))
                        .clip()
                        .align_child(End, Start)
                        .child(value),
                ])
                .width(Parent)
                .align(Center)
                .gap(spacing::SMALL),
            ));
        }
    }
    if let Some(state) = state.filter(|state| !state.holds.is_empty()) {
        let text = ui::supporting(
            format!("Power mode held by {}", state.holds.join(", ")),
            theme,
        )
        .wrap();
        let height = text.height_in(width);
        content.push(Box::new(
            Rectangle::new().width(Parent).height(height).child(text),
        ));
    }
    Column::new(content).width(Parent).gap(spacing::EXTRA_SMALL)
}

pub fn view(theme: &Theme, width: f32) -> Column {
    let status = Status::read();
    let profiles = Profiles::read();
    content(&status.reading, &profiles, theme, width)
}

fn content(reading: &Reading, profiles: &Profiles, theme: &Theme, width: f32) -> Column {
    let (feedback, failed) = feedback(profiles);
    let feedback_color = if failed {
        theme.destructive
    } else {
        theme.surface4
    };
    let overview = Column::new(children![
        summary(reading, theme, width),
        Column::new(children![
            ui::body("Power mode", theme),
            mode_selector(profiles, theme, width),
            ui::supporting(feedback, theme)
                .color(feedback_color)
                .elide()
                .max_lines(1),
        ])
        .width(Parent)
        .gap(spacing::EXTRA_SMALL),
    ])
    .width(Parent)
    .gap(spacing::SMALL);
    let state = profiles
        .state
        .as_ref()
        .and_then(|state| state.as_ref().ok());
    let details = detail_content(reading, state, theme, width);
    Column::new(children![overview, details])
        .width(width)
        .gap(spacing::SMALL)
}

#[cfg(test)]
mod tests {
    use amane::Color;

    use super::*;

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
            radius: crate::theme::Radius {
                small: 2.0,
                normal: 6.0,
                large: 10.0,
            },
        }
    }

    fn profiles() -> Profiles {
        Profiles {
            state: Some(Ok(ProfileState {
                active: "balanced".into(),
                available: vec![
                    "power-saver".into(),
                    "balanced".into(),
                    "performance".into(),
                ],
                degraded: String::new(),
                inhibited: String::new(),
                holds: Vec::new(),
            })),
            pending: None,
            error: None,
        }
    }

    fn details(state: u32) -> Details {
        Details {
            state,
            time_to_full: 3600,
            time_to_empty: 7200,
            rate: -5.5,
            energy: 30.0,
            energy_full: 40.0,
            health: Some(80.0),
        }
    }

    #[test]
    fn estimates_are_only_shown_while_actually_charging_or_discharging() {
        assert_eq!(details(1).status(), "Charging · 1h until full");
        assert_eq!(details(2).status(), "On battery · 2h remaining");
        assert_eq!(details(5).status(), "Plugged in · Waiting to charge");
        assert_eq!(details(6).status(), "Waiting to discharge");
        assert_eq!(details(4).status(), "Fully charged");
        let mut unknown = details(2);
        unknown.time_to_empty = 0;
        assert_eq!(unknown.status(), "On battery");
    }

    #[test]
    fn metrics_omit_unknown_values_and_do_not_repeat_summary_information() {
        let mut details = details(1);
        assert_eq!(
            details.metrics(),
            [
                ("Health", "80%".into()),
                ("Energy", "30.0 / 40.0 Wh".into()),
                ("Charge rate", "5.5 W".into()),
            ]
        );
        details.rate = f64::NAN;
        details.energy = f64::INFINITY;
        details.health = None;
        assert!(details.metrics().is_empty());
    }

    #[test]
    fn feedback_translates_backend_errors_and_restrictions() {
        assert_eq!(
            restriction("high-operating-temperature", false),
            "Performance limited to keep the system cool."
        );
        assert_eq!(
            restriction("unknown-code", true),
            "Performance is unavailable on this system right now."
        );
        assert_eq!(
            action_error("org.freedesktop.DBus.Error.AccessDenied"),
            "Permission denied. Check your system's power settings."
        );
        let profiles = Profiles {
            state: None,
            pending: None,
            error: None,
        };
        assert_eq!(
            feedback(&profiles),
            ("Checking available power modes…", false)
        );
        let profiles = Profiles {
            state: Some(Err("raw D-Bus error".into())),
            ..profiles
        };
        assert_eq!(
            feedback(&profiles),
            ("Power modes aren't available on this system.", false)
        );
    }

    #[test]
    fn pending_selection_preserves_the_confirmed_mode_and_disables_further_actions() {
        let mut profiles = profiles();
        assert!(Mode::new("power-saver", &profiles).clickable);
        assert!(!Mode::new("balanced", &profiles).clickable);
        profiles.pending = Some("power-saver".into());
        let pending = Mode::new("power-saver", &profiles);
        assert_eq!(pending.status, "Applying…");
        assert!(!pending.active);
        assert!(!pending.clickable);
        let confirmed = Mode::new("balanced", &profiles);
        assert!(confirmed.active);
        assert_eq!(confirmed.status, "✓ Selected");
        assert!(!Mode::new("performance", &profiles).clickable);
        profiles.pending = None;
        profiles.state = Some(Err("offline".into()));
        assert!(!Mode::new("power-saver", &profiles).clickable);
    }

    #[test]
    fn battery_states_have_intrinsic_content_heights() {
        let theme = theme();
        let profiles = profiles();
        for reading in [
            Reading::Loading,
            Reading::Absent,
            Reading::Unavailable("offline".into()),
            Reading::Ready {
                battery: super::super::Battery::from_upower(82.0, 5),
                details: details(5),
            },
        ] {
            for width in [380.0, 240.0] {
                let panel = content(&reading, &profiles, &theme, width);
                assert_eq!(Widget::width(&panel), Size::Fixed(width));
                let Size::Fixed(height) = Widget::height(&panel) else {
                    panic!("battery content must request its full height");
                };
                assert!(height > 0.0);
            }
        }
    }

    #[test]
    fn stacked_controls_grow_the_panel_instead_of_hiding_content() {
        let theme = theme();
        let profiles = profiles();
        let reading = Reading::Ready {
            battery: super::super::Battery::from_upower(82.0, 5),
            details: details(5),
        };
        let wide = content(&reading, &profiles, &theme, 380.0);
        let narrow = content(&reading, &profiles, &theme, 160.0);
        let Size::Fixed(wide_height) = Widget::height(&wide) else {
            panic!("expected intrinsic height");
        };
        let Size::Fixed(narrow_height) = Widget::height(&narrow) else {
            panic!("expected intrinsic height");
        };
        assert!(narrow_height > wide_height);
        let Size::Fixed(details_height) =
            Widget::height(&detail_content(&reading, None, &theme, 380.0))
        else {
            panic!("expected intrinsic details height");
        };
        assert!(
            wide_height
                >= ui::body("Power mode", &theme).height_in(380.0)
                    + layout::MODE_HEIGHT
                    + details_height
        );
    }

    #[test]
    fn mode_controls_fit_labels_and_stack_on_narrow_layouts() {
        let theme = theme();
        let button = mode_button("power-saver", "Power saver", &profiles(), &theme);
        let Size::Fixed(height) = Widget::height(&button) else {
            panic!("expected fixed control height")
        };
        let required = ui::body("Power saver", &theme).height_in(120.0)
            + ui::supporting("Applying…", &theme).height_in(120.0)
            + spacing::TINY
            + layout::MODE_PADDING * 2.0;
        assert!(height >= required);
        let selector = mode_selector(&profiles(), &theme, 160.0);
        let Size::Fixed(selector_height) = Widget::height(&selector) else {
            panic!("expected intrinsic selector height");
        };
        assert!(selector_height >= height * 3.0);
    }
}
