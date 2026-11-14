mod minimap;
mod niri;
mod theme;
mod window_title;
mod workspaces;

use std::time::Duration;

use amane::{
    App, Center, Full, Layer, LayerWindow, Monitor, Padding, Parent, Rectangle, Row, Service, Text,
    Vertical, Zone, children,
};
use chrono::Local;
use niri::Niri;
use theme::ThemeState;

struct Clock(String);

impl Service for Clock {
    fn new() -> Self {
        Self(Local::now().format("%a %-d %b %H:%M").to_string())
    }

    fn interval() -> Duration {
        Duration::from_secs(1)
    }

    fn update(&mut self) -> bool {
        let time = Self::new().0;
        if self.0 == time {
            return false;
        }
        self.0 = time;
        true
    }
}

fn main() {
    // Load before opening any windows, so a bad initial config fails clearly.
    drop(ThemeState::read());
    App::new().window_per_monitor(bar).run();
}

fn bar(monitor: &Monitor) -> LayerWindow {
    let state = ThemeState::read();
    let theme = &state.theme;
    let clock = Clock::read();
    let niri = Niri::read();

    LayerWindow::new()
        .width(Full)
        .height(32.0)
        .anchor_vertical(Vertical::Top)
        .layer(Layer::Top)
        .space(Zone::Reserve)
        .namespace("amane_shell")
        .child(
            Rectangle::new()
                .width(Parent)
                .height(Parent)
                .fill(theme.bg)
                .padding(Padding {
                    left: 12.0,
                    right: 12.0,
                    top: 0.0,
                    bottom: 0.0,
                })
                .child(
                    Row::new(children![
                        workspaces::view(&niri, &monitor.name, theme),
                        window_title::view(&niri, &monitor.name, theme),
                        Text::new(&clock.0)
                            .font(&theme.font)
                            .size(theme.font_size)
                            .color(theme.fg),
                    ])
                    .width(Parent)
                    .height(Parent)
                    .align(Center)
                    .gap(12.0),
                ),
        )
}
