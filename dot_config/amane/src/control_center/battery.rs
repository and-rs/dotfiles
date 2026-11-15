use std::{
    collections::HashMap,
    sync::{
        LazyLock, Mutex,
        mpsc::{self, Receiver, RecvTimeoutError, SyncSender},
    },
    time::Duration,
};

use amane::{
    Button, Center, Column, Cursor, Parent, Rectangle, Row, Service, Text, Widget, children,
};
use zbus::{blocking::Proxy, zvariant::OwnedValue};

use super::{
    backends::{self, Reading},
    indicators::Indicator,
    text,
};
use crate::{
    design::{self, padding, spacing},
    theme::Theme,
};

#[derive(Clone, Debug, PartialEq)]
pub(super) struct Details {
    pub state: u32,
    pub time_to_full: i64,
    pub time_to_empty: i64,
    pub rate: f64,
    pub energy: f64,
    pub energy_full: f64,
    pub health: Option<f64>,
}

pub(super) fn health(full: f64, design: f64) -> Option<f64> {
    if full.is_finite() && full > 0.0 && design.is_finite() && design > 0.0 {
        return Some((full / design * 100.0).clamp(0.0, 100.0));
    }
    None
}

fn duration(seconds: i64) -> Option<String> {
    if seconds <= 0 {
        return None;
    }
    let minutes = seconds / 60;
    let hours = minutes / 60;
    if hours == 0 {
        return Some(format!("{minutes}m"));
    }
    if minutes % 60 == 0 {
        return Some(format!("{hours}h"));
    }
    Some(format!("{hours}h {}m", minutes % 60))
}

impl Details {
    fn summary(&self) -> String {
        let state = match self.state {
            1 => "Charging",
            2 => "Discharging",
            3 => "Empty",
            4 => "Fully charged",
            5 => "Pending charge",
            6 => "Pending discharge",
            _ => "Unknown",
        };
        let mut lines = vec![state.to_string()];
        let eta = match self.state {
            1 | 5 => duration(self.time_to_full).map(|time| format!("{time} until full")),
            2 | 6 => duration(self.time_to_empty).map(|time| format!("{time} remaining")),
            _ => None,
        };
        if let Some(eta) = eta {
            lines.push(eta);
        }
        if self.rate.is_finite() && self.rate.abs() > 0.0 {
            lines.push(format!("Rate: {:.1} W", self.rate.abs()));
        }
        if self.energy.is_finite()
            && self.energy >= 0.0
            && self.energy_full.is_finite()
            && self.energy_full > 0.0
        {
            lines.push(format!(
                "Energy: {:.1} / {:.1} Wh",
                self.energy, self.energy_full
            ));
        }
        if let Some(health) = self.health {
            lines.push(format!("Health: {health:.0}%"));
        }
        lines.join("\n")
    }
}

const ENDPOINTS: [(&str, &str); 2] = [
    (
        "org.freedesktop.UPower.PowerProfiles",
        "/org/freedesktop/UPower/PowerProfiles",
    ),
    ("net.hadess.PowerProfiles", "/net/hadess/PowerProfiles"),
];
const REFRESH: Duration = Duration::from_secs(5);

static REQUESTS: LazyLock<(SyncSender<String>, Mutex<Receiver<String>>)> = LazyLock::new(|| {
    let (sender, receiver) = mpsc::sync_channel(1);
    (sender, Mutex::new(receiver))
});

#[derive(Debug, PartialEq)]
struct ProfileState {
    active: String,
    available: Vec<String>,
    degraded: String,
    inhibited: String,
    holds: Vec<String>,
}

impl ProfileState {
    fn can_select(&self, profile: &str) -> bool {
        self.available.iter().any(|available| available == profile)
            && (profile != "performance" || self.inhibited.is_empty())
    }
}

struct Profiles {
    state: Result<ProfileState, String>,
    pending: Option<String>,
    error: Option<String>,
}

impl Service for Profiles {
    fn new() -> Self {
        Self {
            state: Err("Checking power profiles…".into()),
            pending: None,
            error: None,
        }
    }

    fn listen() {
        let receiver = REQUESTS.1.lock().expect("power-profile receiver poisoned");
        loop {
            let fresh = read_profiles();
            let changed = Self::read().state != fresh;
            if changed {
                Self::write().state = fresh;
            }
            match receiver.recv_timeout(REFRESH) {
                Ok(profile) => {
                    let result = set_profile(&profile);
                    let fresh = read_profiles();
                    let mut status = Self::write();
                    status.state = fresh;
                    status.pending = None;
                    status.error = result.err();
                }
                Err(RecvTimeoutError::Timeout) => {}
                Err(RecvTimeoutError::Disconnected) => return,
            }
        }
    }
}

fn proxy(connection: &zbus::blocking::Connection) -> Result<Proxy<'_>, String> {
    for (name, path) in ENDPOINTS {
        if backends::owned(connection, name).map_err(|error| error.to_string())? {
            return zbus::blocking::proxy::Builder::new(connection)
                .destination(name)
                .and_then(|builder| builder.path(path))
                .and_then(|builder| builder.interface(name))
                .and_then(|builder| {
                    builder
                        .cache_properties(zbus::proxy::CacheProperties::No)
                        .build()
                })
                .map_err(|error| error.to_string());
        }
    }
    Err("Power-profile service unavailable".into())
}

fn read_profiles() -> Result<ProfileState, String> {
    let connection = backends::connection(false).map_err(|error| error.to_string())?;
    let proxy = proxy(&connection)?;
    read_profile_state(&proxy).map_err(|error| error.to_string())
}

fn read_profile_state(proxy: &Proxy<'_>) -> zbus::Result<ProfileState> {
    let profiles: Vec<HashMap<String, OwnedValue>> = proxy.get_property("Profiles")?;
    let holds: Vec<HashMap<String, OwnedValue>> = proxy.get_property("ActiveProfileHolds")?;
    Ok(ProfileState {
        active: proxy.get_property("ActiveProfile")?,
        available: profiles
            .iter()
            .filter_map(|profile| value_string(profile, "Profile"))
            .collect(),
        degraded: proxy.get_property("PerformanceDegraded")?,
        // Removed from newer versions of the API.
        inhibited: proxy
            .get_property("PerformanceInhibited")
            .unwrap_or_default(),
        holds: holds
            .iter()
            .filter_map(|hold| value_string(hold, "ApplicationId"))
            .collect(),
    })
}

fn value_string(values: &HashMap<String, OwnedValue>, key: &str) -> Option<String> {
    values
        .get(key)
        .and_then(|value| <&str>::try_from(value).ok())
        .map(str::to_string)
}

fn set_profile(profile: &str) -> Result<(), String> {
    let connection = backends::connection(false).map_err(|error| error.to_string())?;
    let proxy = proxy(&connection)?;
    apply_profile(&proxy, profile)
}

fn apply_profile(proxy: &Proxy<'_>, profile: &str) -> Result<(), String> {
    let state = read_profile_state(proxy).map_err(|error| error.to_string())?;
    if !state.can_select(profile) {
        return Err("This power profile is no longer available".into());
    }
    proxy
        .set_property("ActiveProfile", profile)
        .map_err(|error| error.to_string())?;
    let active: String = proxy
        .get_property("ActiveProfile")
        .map_err(|error| error.to_string())?;
    if active != profile {
        return Err(format!(
            "Requested profile was not applied; active profile: {active}"
        ));
    }
    Ok(())
}

fn request_profile(profile: &str) {
    let mut status = Profiles::write();
    let selectable = status
        .state
        .as_ref()
        .is_ok_and(|state| state.active != profile && state.can_select(profile));
    if status.pending.is_some() || !selectable {
        return;
    }
    status.pending = Some(profile.into());
    status.error = None;
    if REQUESTS.0.try_send(profile.into()).is_err() {
        status.pending = None;
        status.error = Some("Could not queue power-profile change".into());
    }
}

pub(super) fn view(reading: &Reading, theme: &Theme) -> Column {
    let profiles = Profiles::read();
    let mut content: Vec<Box<dyn Widget>> = Vec::new();
    if let (Indicator::Battery(Some(battery)), Some(details)) =
        (&reading.indicator, &reading.battery)
    {
        content.push(Box::new(text(
            format!("Battery  {:.0}%", battery.level * 100.0),
            theme,
        )));
        content.push(Box::new(text(details.summary(), theme).wrap()));
    } else {
        content.push(Box::new(text(&reading.message, theme).wrap()));
    }
    content.push(Box::new(text("Power mode", theme)));
    match &profiles.state {
        Ok(state) => {
            for (profile, label, icon) in [
                ("power-saver", "Power Saver", '\u{e32c}'),
                ("balanced", "Balanced", '\u{e46e}'),
                ("performance", "Performance", '\u{e3d6}'),
            ] {
                let active = state.active == profile;
                let available = state.can_select(profile);
                let clickable = available && !active && profiles.pending.is_none();
                let color = if active {
                    theme.accent
                } else if available {
                    theme.fg
                } else {
                    theme.surface4
                };
                let mut label = label.to_string();
                if profiles.pending.as_deref() == Some(profile) {
                    label.push_str(" (applying…)");
                } else if active {
                    label.push_str(" (active)");
                } else if !available {
                    label.push_str(" (unavailable)");
                }
                let mut row = Rectangle::new()
                    .width(Parent)
                    .height(design::control_center::PROFILE_HEIGHT)
                    .padding(padding::NORMAL)
                    .fill(theme.surface2)
                    .radius(theme.radius.normal)
                    .child(
                        Row::new(children![
                            Text::new(icon.to_string())
                                .font(design::ICON_FONT)
                                .size(design::ICON_SIZE)
                                .color(color)
                                .tight(),
                            text(label, theme).color(color),
                        ])
                        .gap(spacing::SMALL)
                        .align(Center),
                    );
                if clickable {
                    row = row.cursor(Cursor::Pointer).on_click(move |button| {
                        if button == Button::Left {
                            request_profile(profile);
                        }
                    });
                }
                content.push(Box::new(row));
            }
            if !state.degraded.is_empty() {
                content.push(Box::new(
                    text(format!("Performance limited: {}", state.degraded), theme).wrap(),
                ));
            }
            if !state.inhibited.is_empty() {
                content.push(Box::new(
                    text(
                        format!("Performance unavailable: {}", state.inhibited),
                        theme,
                    )
                    .wrap(),
                ));
            }
            if !state.holds.is_empty() {
                content.push(Box::new(
                    text(format!("Held by: {}", state.holds.join(", ")), theme).wrap(),
                ));
            }
        }
        Err(error) => content.push(Box::new(text(error, theme).wrap())),
    }
    if let Some(error) = &profiles.error {
        content.push(Box::new(text(error, theme).color(theme.destructive).wrap()));
    }
    Column::new(content).width(Parent).gap(spacing::SMALL)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn durations_omit_unknown_estimates() {
        for (seconds, expected) in [
            (-1, None),
            (0, None),
            (60, Some("1m")),
            (3600, Some("1h")),
            (3660, Some("1h 1m")),
        ] {
            assert_eq!(duration(seconds).as_deref(), expected);
        }
    }

    #[test]
    fn health_requires_real_design_capacity() {
        assert_eq!(health(40.0, 50.0), Some(80.0));
        assert_eq!(health(55.0, 50.0), Some(100.0));
        for (full, design) in [
            (40.0, 0.0),
            (0.0, 50.0),
            (f64::NAN, 50.0),
            (40.0, f64::INFINITY),
        ] {
            assert_eq!(health(full, design), None);
        }
    }

    #[test]
    fn selection_requires_an_advertised_uninhibited_profile() {
        let mut state = ProfileState {
            active: "balanced".into(),
            available: vec!["balanced".into(), "power-saver".into()],
            degraded: String::new(),
            inhibited: String::new(),
            holds: vec![],
        };
        assert!(state.can_select("power-saver"));
        assert!(!state.can_select("performance"));
        assert!(!state.can_select("invalid"));
        state.available.push("performance".into());
        state.degraded = "high-operating-temperature".into();
        assert!(state.can_select("performance"));
        state.inhibited = "lap-detected".into();
        assert!(!state.can_select("performance"));
        assert!(state.can_select("balanced"));
    }

    #[test]
    fn summaries_use_state_specific_estimates_and_omit_invalid_readings() {
        let mut details = Details {
            state: 1,
            time_to_full: 3600,
            time_to_empty: 7200,
            rate: -5.5,
            energy: 30.0,
            energy_full: 40.0,
            health: Some(80.0),
        };
        assert_eq!(
            details.summary(),
            "Charging\n1h until full\nRate: 5.5 W\nEnergy: 30.0 / 40.0 Wh\nHealth: 80%"
        );
        details.state = 6;
        assert!(details.summary().contains("2h remaining"));
        details.state = 4;
        details.rate = f64::NAN;
        details.energy = f64::INFINITY;
        details.health = None;
        assert_eq!(details.summary(), "Fully charged");
    }

    struct FakeProfiles {
        active: String,
    }

    #[zbus::interface(name = "net.hadess.PowerProfiles")]
    impl FakeProfiles {
        #[zbus(property)]
        fn active_profile(&self) -> &str {
            &self.active
        }

        #[zbus(property)]
        fn set_active_profile(&mut self, profile: &str) -> zbus::fdo::Result<()> {
            if profile == "performance" {
                return Err(zbus::fdo::Error::AccessDenied("Not authorized".into()));
            }
            if profile != "balanced" {
                self.active = profile.into();
            }
            Ok(())
        }

        #[zbus(property)]
        fn profiles(&self) -> Vec<HashMap<String, OwnedValue>> {
            ["power-saver", "balanced", "performance"]
                .into_iter()
                .map(|profile| {
                    HashMap::from([(
                        "Profile".into(),
                        OwnedValue::try_from(zbus::zvariant::Value::from(profile)).unwrap(),
                    )])
                })
                .collect()
        }

        #[zbus(property)]
        fn performance_degraded(&self) -> &str {
            ""
        }

        #[zbus(property)]
        fn active_profile_holds(&self) -> Vec<HashMap<String, OwnedValue>> {
            vec![]
        }
    }

    #[test]
    #[ignore = "run under dbus-run-session; writes only to an isolated fake service"]
    fn fake_profiles_support_switching_denial_and_readback_validation() {
        let server = zbus::blocking::connection::Builder::session()
            .unwrap()
            .serve_at(
                "/net/hadess/PowerProfiles",
                FakeProfiles {
                    active: "balanced".into(),
                },
            )
            .unwrap()
            .build()
            .unwrap();
        let client = backends::connection(true).unwrap();
        // Address only this test connection, never a real power-profile service.
        let proxy = zbus::blocking::proxy::Builder::new(&client)
            .destination(server.unique_name().unwrap().as_str())
            .unwrap()
            .path("/net/hadess/PowerProfiles")
            .unwrap()
            .interface("net.hadess.PowerProfiles")
            .unwrap()
            .cache_properties(zbus::proxy::CacheProperties::No)
            .build()
            .unwrap();
        let state = read_profile_state(&proxy).unwrap();
        assert_eq!(state.active, "balanced");
        assert_eq!(state.available.len(), 3);
        assert!(state.inhibited.is_empty());
        apply_profile(&proxy, "power-saver").unwrap();
        assert_eq!(read_profile_state(&proxy).unwrap().active, "power-saver");
        assert!(
            apply_profile(&proxy, "performance")
                .unwrap_err()
                .contains("AccessDenied")
        );
        assert!(
            apply_profile(&proxy, "invalid")
                .unwrap_err()
                .contains("no longer available")
        );
        assert!(
            apply_profile(&proxy, "balanced")
                .unwrap_err()
                .contains("not applied")
        );
        assert_eq!(read_profile_state(&proxy).unwrap().active, "power-saver");
    }
}
